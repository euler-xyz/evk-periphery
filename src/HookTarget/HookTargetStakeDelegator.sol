// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import "evk/EVault/shared/Constants.sol";

/// @title IRewardVaultFactory Interface
/// @dev Based on https://github.com/berachain/contracts/blob/main/src/pol/interfaces/IRewardVaultFactory.sol
interface IRewardVaultFactory {
    /// @notice Predicts the address for a given staking token
    /// @param stakingToken The address of the staking token
    /// @return The address of the reward vault
    function predictRewardVaultAddress(address stakingToken) external view returns (address);
}

/// @title IRewardVault Interface
/// @dev Based on https://github.com/berachain/contracts/blob/main/src/pol/interfaces/IRewardVault.sol
interface IRewardVault {
    /// @notice Get the amount staked by a delegate on behalf of an account
    /// @param account The account address to check
    /// @param delegate The delegate address to check
    /// @return The amount staked by the delegate for the account
    function getDelegateStake(address account, address delegate) external view returns (uint256);

    /// @notice Stake tokens on behalf of another account
    /// @param account The account to stake for
    /// @param amount The amount of tokens to stake
    function delegateStake(address account, uint256 amount) external;

    /// @notice Withdraw tokens staked on behalf of another account
    /// @param account The account to withdraw for
    /// @param amount The amount of tokens to withdraw
    function delegateWithdraw(address account, uint256 amount) external;
}

/// @title ERC20ShareRepresentation
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice ERC20 token representing EVault shares which is automatically delegate staked in a reward vault.
/// This token is minted and burned in sync with EVault share operations (deposit, mint, withdraw, redeem).
/// When minted, the tokens are automatically delegate staked on behalf of the user by the HookTarget, allowing users to
/// participate in Berachain's Proof of Liquidity (POL) while still being able to use the EVault shares as collateral.
/// The token is owned and controlled exclusively by the HookTarget contract.
contract ERC20ShareRepresentation is Ownable, ERC20 {
    /// @notice Creates a new share representation token for an EVault
    /// @param _eVault The address of the EVault this token is associated with
    /// @dev The token name and symbol are derived from the EVault's name and symbol with "-STAKE" suffix
    constructor(address _eVault)
        Ownable(msg.sender)
        ERC20(
            string(abi.encodePacked(ERC20(_eVault).name(), "-STAKE")),
            string(abi.encodePacked(ERC20(_eVault).symbol(), "-STAKE"))
        )
    {}

    /// @notice Mints new share representation tokens
    /// @dev Only callable by the owner (HookTarget contract)
    /// @param _amount Amount of tokens to mint
    function mint(uint256 _amount) external onlyOwner {
        if (_amount == 0) return;
        _mint(owner(), _amount);
    }

    /// @notice Burns share representation tokens
    /// @dev Only callable by the owner (HookTarget contract)
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _amount) external onlyOwner {
        if (_amount == 0) return;
        _burn(owner(), _amount);
    }
}

/// @title HookTargetStakeDelegator
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Hook target that automatically delegate stakes representation of EVault shares in Berachain's reward vault
/// system. This hook target intercepts EVault share operations (i.e. deposit, mint, withdraw, redeem) and automatically
/// delegate stakes the shares in a Berachain reward vault. This allows EVault users to participate in Berachain's Proof
/// of Liquidity (POL) system while still being able to use their shares as collateral.
contract HookTargetStakeDelegator is Ownable, IHookTarget {
    /// @notice Maximum protocol fee share as defined in the EVault GovernanceModule
    uint16 internal constant MAX_PROTOCOL_FEE_SHARE = 0.5e4;

    /// @notice Reference to the Ethereum Vault Connector contract
    /// @dev Used to resolve account ownership for proper reward delegation
    IEVC public immutable evc;

    /// @notice Reference to the EVault this hook target is attached to
    /// @dev Source of share balances and operations that trigger staking
    IEVault public immutable eVault;

    /// @notice The token representing EVault shares
    /// @dev Minted/burned in sync with EVault operations and automatically staked
    ERC20ShareRepresentation public immutable erc20;

    /// @notice Reference to the Berachain reward vault where shares are delegate staked
    /// @dev Handles the actual staking of shares and reward distribution
    IRewardVault public immutable rewardVault;

    /// @notice Creates a new HookTargetStakeDelegator
    /// @param _eVault The EVault this hook target will be attached to
    /// @param _rewardVaultFactory Factory contract that creates reward vaults for stake tokens
    constructor(address _eVault, address _rewardVaultFactory) Ownable(_eVault) {
        evc = IEVC(IEVault(_eVault).EVC());
        eVault = IEVault(_eVault);
        erc20 = new ERC20ShareRepresentation(_eVault);
        rewardVault = IRewardVault(IRewardVaultFactory(_rewardVaultFactory).predictRewardVaultAddress(address(erc20)));
        erc20.approve(address(rewardVault), type(uint256).max);
    }

    /// @notice Intercepts EVault deposit operations to handle creation of share representation tokens and stake
    /// delegation. Called by EVault when a user deposits assets
    /// @param amount The amount of assets being deposited, or type(uint256).max to deposit the caller's entire balance
    /// @param receiver The address who's EVC owner will receive the delegated stake
    /// @return Always returns 0 (irrelevant for hook targets)
    function deposit(uint256 amount, address receiver) external onlyOwner returns (uint256) {
        if (amount == type(uint256).max) {
            amount = ERC20(eVault.asset()).balanceOf(_eVaultCaller());
        }

        amount = eVault.previewDeposit(amount);

        erc20.mint(amount);
        _delegateStake(receiver, amount);
        return 0;
    }

    /// @notice Intercepts EVault mint operations to handle creation of share representation tokens and stake
    /// delegation.
    /// Called by EVault when a user mints shares
    /// @param amount The exact amount of shares being minted
    /// @param receiver The address who's EVC owner will receive the delegated stake
    /// @return Always returns 0 (irrelevant for hook targets)
    function mint(uint256 amount, address receiver) external onlyOwner returns (uint256) {
        erc20.mint(amount);
        _delegateStake(receiver, amount);
        return 0;
    }

    /// @notice Intercepts EVault withdraw operations to handle undelegation of stake and burning of share
    /// representation tokens. Called by EVault when a user withdraws assets.
    /// @param amount The amount of assets being withdrawn
    /// @param owner The address whose delegated stake will be withdrawn
    /// @return Always returns 0 (irrelevant for hook targets)
    function withdraw(uint256 amount, address, address owner) external onlyOwner returns (uint256) {
        amount = eVault.previewWithdraw(amount);

        erc20.burn(_delegateWithdraw(owner, amount));
        return 0;
    }

    /// @notice Intercepts EVault redeem operations to handle undelegation of stake and burning of share representation
    /// tokens. Called by EVault when a user redeems shares
    /// @param amount The amount of shares being redeemed, or type(uint256).max to redeem all shares
    /// @param owner The address whose delegated stake will be withdrawn
    /// @return Always returns 0 (irrelevant for hook targets)
    function redeem(uint256 amount, address, address owner) external onlyOwner returns (uint256) {
        if (amount == type(uint256).max) {
            amount = eVault.balanceOf(owner);
        }

        erc20.burn(_delegateWithdraw(owner, amount));
        return 0;
    }

    /// @notice Intercepts EVault skim operations to handle creation of share representation tokens and stake
    /// delegation. Called by EVault when a user skims excess asset
    /// @param amount The amount of excess assets to convert to shares, or type(uint256).max to convert all excess
    /// @param receiver The address who's EVC owner will receive the delegated stake
    /// @return Always returns 0 (irrelevant for hook targets)
    function skim(uint256 amount, address receiver) external onlyOwner returns (uint256) {
        if (amount == type(uint256).max) {
            uint256 balance = ERC20(eVault.asset()).balanceOf(address(eVault));
            uint256 cash = eVault.cash();
            amount = balance > cash ? balance - cash : 0;
        }

        amount = eVault.previewDeposit(amount);

        erc20.mint(amount);
        _delegateStake(receiver, amount);
        return 0;
    }

    /// @notice Intercepts EVault repayWithShares operations to handle undelegation of stake and burning of share
    /// representation tokens. Called by EVault when a user repays debt using their shares
    /// @param amount The amount of shares to use for repayment, or type(uint256).max to use all shares
    /// @return shares Always returns 0 (irrelevant for hook targets)
    /// @return debt Always returns 0 (irrelevant for hook targets)
    function repayWithShares(uint256 amount, address) external onlyOwner returns (uint256 shares, uint256 debt) {
        address owner = _eVaultCaller();

        if (amount == type(uint256).max) {
            amount = eVault.balanceOf(owner);
        }

        amount = eVault.previewWithdraw(amount);

        erc20.burn(_delegateWithdraw(owner, amount));
        return (0, 0);
    }

    /// @notice Intercepts EVault transfer operations to handle delegation of stake between accounts. Called by EVault
    /// when a user transfers shares
    /// @param to The address who's EVC owner will receive the delegated stake
    /// @param amount The amount of shares being transferred
    /// @return Always returns false (irrelevant for hook targets)
    function transfer(address to, uint256 amount) external onlyOwner returns (bool) {
        _delegateStake(to, _delegateWithdraw(_eVaultCaller(), amount));
        return false;
    }

    /// @notice Intercepts EVault transferFrom operations to handle delegation of stake between accounts. Called by
    /// EVault
    /// when a user transfers shares on behalf of another
    /// @param from The address whose delegated stake will be withdrawn
    /// @param to The address who's EVC owner will receive the delegated stake
    /// @param amount The amount of shares being transferred
    /// @return Always returns false (irrelevant for hook targets)
    function transferFrom(address from, address to, uint256 amount) external onlyOwner returns (bool) {
        _delegateStake(to, _delegateWithdraw(from, amount));
        return false;
    }

    /// @notice Intercepts EVault transferFromMax operations to handle delegation of stake between accounts. Called by
    /// EVault when a user transfers all shares from another account
    /// @param from The address whose delegated stake will be withdrawn
    /// @param to The address who's EVC owner will receive the delegated stake
    /// @return Always returns false (irrelevant for hook targets)
    function transferFromMax(address from, address to) external onlyOwner returns (bool) {
        uint256 amount = eVault.balanceOf(from);

        _delegateStake(to, _delegateWithdraw(from, amount));
        return false;
    }

    /// @notice Intercepts EVault convertFees operations to handle creation and delegation of share representation
    /// tokens when accumulated fees are converted to shares. Called by EVault when converting accumulated fees to
    /// shares
    /// @dev The algorithm follows the same logic as the EVault's convertFees function.
    function convertFees() external onlyOwner {
        (address protocolReceiver, uint16 protocolFee) =
            ProtocolConfig(eVault.protocolConfigAddress()).protocolFeeConfig(address(eVault));
        address governorReceiver = eVault.feeReceiver();

        if (governorReceiver == address(0)) {
            protocolFee = CONFIG_SCALE;
        } else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) {
            protocolFee = MAX_PROTOCOL_FEE_SHARE;
        }

        uint256 accumulatedFees = eVault.accumulatedFees();
        uint256 governorShares = accumulatedFees * (CONFIG_SCALE - protocolFee) / CONFIG_SCALE;
        uint256 protocolShares = accumulatedFees - governorShares;

        erc20.mint(governorShares + protocolShares);
        _delegateStake(governorReceiver, governorShares);
        _delegateStake(protocolReceiver, protocolShares);
    }

    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @notice Retrieves the caller address in the context of the calling EVault.
    /// @return _caller The address of the account on which given EVault operation is performed.
    function _eVaultCaller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    /// @notice Delegates stake to an account's EVC owner
    /// @dev Stakes are always delegated to the EVC owner of the account, not the account itself. If the account has no
    /// registered EVC owner (owner is address(0)), the stake is delegated to the account directly, assuming it is its
    /// own owner.
    /// @param account The account whose EVC owner will receive the delegated stake
    /// @param amount The amount of shares to delegate stake
    function _delegateStake(address account, uint256 amount) internal {
        if (amount == 0) return;

        address owner = evc.getAccountOwner(account);
        rewardVault.delegateStake(owner == address(0) ? account : owner, amount);
    }

    /// @notice Withdraws delegated stake from an account and handles stake migration between account and its EVC owner
    /// @dev Handles stake migration and withdrawal with the following considerations:
    /// - When an account first receives stake, its EVC owner might not be registered yet, causing the stake to be
    /// delegated directly to the account. Once the owner is registered and is different from the account, we need to
    /// migrate this stake.
    /// - The amount to withdraw is capped by the available stake because the hook target might not have been installed
    /// since the EVault's creation, meaning not all shares are necessarily staked.
    /// @param account The account whose stake (or whose EVC owner's stake) should be withdrawn
    /// @param amount The requested amount of stake to withdraw
    /// @return The actual amount of stake withdrawn (may be less than requested if insufficient stake)
    function _delegateWithdraw(address account, uint256 amount) internal returns (uint256) {
        address owner = evc.getAccountOwner(account);

        // If account has a registered owner different from itself, migrate any stake that was delegated directly to the
        // account (from before owner registration)
        if (owner != address(0) && owner != account) {
            uint256 delegateStakeAccount = rewardVault.getDelegateStake(account, address(this));

            if (delegateStakeAccount > 0) {
                rewardVault.delegateWithdraw(account, delegateStakeAccount);
                rewardVault.delegateStake(owner, delegateStakeAccount);
            }
        }

        if (owner == address(0)) owner = account;

        uint256 delegateStakeOwner = rewardVault.getDelegateStake(owner, address(this));

        // Cap withdrawal at available stake (might be less than shares if hook target wasn't installed from EVault
        // creation)
        if (amount > delegateStakeOwner) {
            amount = delegateStakeOwner;
        }

        if (amount == 0) return 0;

        rewardVault.delegateWithdraw(owner, amount);
        return amount;
    }
}
