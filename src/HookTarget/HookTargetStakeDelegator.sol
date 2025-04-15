// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";

/// @title IRewardVaultFactory Interface
/// @dev Based on https://github.com/berachain/contracts/blob/main/src/pol/interfaces/IRewardVaultFactory.sol
interface IRewardVaultFactory {
    /// @notice Creates a new reward vault vault for the given staking token.
    /// @dev Reverts if the staking token is not a contract.
    /// @param stakingToken The address of the staking token.
    /// @return The address of the new vault.
    function createRewardVault(address stakingToken) external returns (address);

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
        _mint(owner(), _amount);
    }

    /// @notice Burns share representation tokens
    /// @dev Only callable by the owner (HookTarget contract)
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _amount) external onlyOwner {
        _burn(owner(), _amount);
    }
}

/// @title HookTargetStakeDelegator
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Hook target that automatically delegate stakes representation of EVault shares in Berachain's reward vault
/// system. This hook target uses a batched processing approach where it:
/// 1. Tracks accounts affected by EVault operations by snapshotting their initial share balances
/// 2. Processes all balance changes at the end of the EVC checks deferred context
/// 3. Mints/burns share representation tokens and updates stake delegations based on the net balance changes
/// This allows EVault users to participate in Berachain's Proof of Liquidity (POL) system while still being able
/// to use their shares as collateral.
contract HookTargetStakeDelegator is Ownable, IHookTarget {
    using EnumerableSet for EnumerableSet.AddressSet;

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

    /// @notice Set of accounts that have been affected by operations in the current EVC checks deferred context
    /// @dev Used to track which accounts need their balances processed in the checkVaultStatus hook
    EnumerableSet.AddressSet internal touchedAccounts;

    /// @notice Mapping of initial share balances for accounts affected in the current EVC checks deferred context
    /// @dev Used to calculate net balance changes when processing the EVC checks deferred context
    mapping(address account => uint256 amount) internal initialBalances;

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

    /// @notice Intercepts EVault deposit operations to track affected accounts
    /// @param receiver The address that will receive shares and needs balance tracking
    /// @return Always returns 0 (irrelevant for hook targets)
    function deposit(uint256, address receiver) external onlyOwner returns (uint256) {
        _snapshotAccount(receiver);
        return 0;
    }

    /// @notice Intercepts EVault mint operations to track affected accounts
    /// @param receiver The address that will receive shares and needs balance tracking
    /// @return Always returns 0 (irrelevant for hook targets)
    function mint(uint256, address receiver) external onlyOwner returns (uint256) {
        _snapshotAccount(receiver);
        return 0;
    }

    /// @notice Intercepts EVault withdraw operations to track affected accounts
    /// @param owner The address whose balance will change and needs tracking
    /// @return Always returns 0 (irrelevant for hook targets)
    function withdraw(uint256, address, address owner) external onlyOwner returns (uint256) {
        _snapshotAccount(owner);
        return 0;
    }

    /// @notice Intercepts EVault redeem operations to track affected accounts
    /// @param owner The address whose balance will change and needs tracking
    /// @return Always returns 0 (irrelevant for hook targets)
    function redeem(uint256, address, address owner) external onlyOwner returns (uint256) {
        _snapshotAccount(owner);
        return 0;
    }

    /// @notice Intercepts EVault skim operations to track affected accounts
    /// @param receiver The address that will receive shares and needs balance tracking
    /// @return Always returns 0 (irrelevant for hook targets)
    function skim(uint256, address receiver) external onlyOwner returns (uint256) {
        _snapshotAccount(receiver);
        return 0;
    }

    /// @notice Intercepts EVault repayWithShares operations to track affected accounts
    /// @return shares Always returns 0 (irrelevant for hook targets)
    /// @return debt Always returns 0 (irrelevant for hook targets)
    function repayWithShares(uint256, address) external onlyOwner returns (uint256 shares, uint256 debt) {
        _snapshotAccount(_eVaultCaller());
        return (0, 0);
    }

    /// @notice Intercepts EVault transfer operations to track affected accounts
    /// @param to The address receiving shares that needs balance tracking
    /// @return Always returns false (irrelevant for hook targets)
    function transfer(address to, uint256) external onlyOwner returns (bool) {
        _snapshotAccount(_eVaultCaller());
        _snapshotAccount(to);
        return false;
    }

    /// @notice Intercepts EVault transferFrom operations to track affected accounts
    /// @param from The address sending shares that needs balance tracking
    /// @param to The address receiving shares that needs balance tracking
    /// @return Always returns false (irrelevant for hook targets)
    function transferFrom(address from, address to, uint256) external onlyOwner returns (bool) {
        _snapshotAccount(from);
        _snapshotAccount(to);
        return false;
    }

    /// @notice Intercepts EVault transferFromMax operations to track affected accounts
    /// @param from The address sending shares that needs balance tracking
    /// @param to The address receiving shares that needs balance tracking
    /// @return Always returns false (irrelevant for hook targets)
    function transferFromMax(address from, address to) external onlyOwner returns (bool) {
        _snapshotAccount(from);
        _snapshotAccount(to);
        return false;
    }

    /// @notice Intercepts EVault convertFees operations to track affected accounts
    function convertFees() external onlyOwner {
        (address protocolReceiver,) = ProtocolConfig(eVault.protocolConfigAddress()).protocolFeeConfig(address(eVault));
        address governorReceiver = eVault.feeReceiver();

        _snapshotAccount(protocolReceiver);
        _snapshotAccount(governorReceiver);
    }

    /// @notice Processes all balance changes for accounts affected in the current EVC checks deferred context
    /// @dev Called at the end of the EVC checks deferred context to:
    /// 1. Calculate net balance changes for all affected accounts
    /// 2. Mint share representation tokens and delegate stake for balance increases
    /// 3. Withdraw delegated stake and burn tokens for balance decreases
    /// 4. Reset tracking state for the next EVC checks deferred context
    /// @return Always returns 0 (irrelevant for hook targets)
    function checkVaultStatus() external onlyOwner returns (bytes4) {
        address[] memory accounts = touchedAccounts.values();

        for (uint256 i = 0; i < accounts.length; ++i) {
            address account = accounts[i];
            uint256 initialBalance = initialBalances[account];
            uint256 currentBalance = eVault.balanceOf(account);

            if (currentBalance > initialBalance) {
                uint256 amount = currentBalance - initialBalance;
                erc20.mint(amount);
                _delegateStake(account, amount);
            } else if (currentBalance < initialBalance) {
                uint256 amount = initialBalance - currentBalance;
                erc20.burn(_delegateWithdraw(account, amount));
            }

            initialBalances[account] = 0;
            touchedAccounts.remove(account);
        }

        return 0;
    }

    /// @inheritdoc IHookTarget
    /// @dev This function returns the expected magic value only if the reward vault is already deployed.
    function isHookTarget() external view override returns (bytes4) {
        if (address(rewardVault).code.length == 0) return 0;
        return this.isHookTarget.selector;
    }

    /// @notice Retrieves the caller address in the context of the calling EVault.
    /// @return _caller The address of the account on which given EVault operation is performed.
    function _eVaultCaller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    /// @notice Records an account's current balance before it's affected by an operation
    /// @dev Only snapshots the first time an account is touched in an EVC checks deferred context
    /// @param account The account to snapshot
    function _snapshotAccount(address account) internal {
        if (touchedAccounts.add(account)) {
            initialBalances[account] = eVault.balanceOf(account);
        }
    }

    /// @notice Delegates stake to an account's EVC owner and handles stake migration between account and its EVC owner
    /// @dev Handles stake delegation and migration with the following considerations:
    /// - Stakes are always delegated to the EVC owner of the account, not the account itself
    /// - If an account has no registered EVC owner, the stake is delegated to the account directly
    /// - When an account first receives stake, its EVC owner might not be registered yet, causing the stake to be
    /// delegated directly to the account. Once the owner is registered and is different from the account, we need to
    /// migrate this stake.
    /// @param account The account whose EVC owner will receive the delegated stake
    /// @param amount The amount of shares to delegate stake
    function _delegateStake(address account, uint256 amount) internal {
        address owner = evc.getAccountOwner(account);
        _migrateStake(owner, account);
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

        _migrateStake(owner, account);

        if (owner == address(0)) owner = account;

        uint256 stake = rewardVault.getDelegateStake(owner, address(this));

        // Cap withdrawal at available stake (might be less than shares if hook target wasn't installed from EVault
        // creation)
        if (amount > stake) {
            amount = stake;
        }

        if (amount > 0) {
            rewardVault.delegateWithdraw(owner, amount);
        }

        return amount;
    }

    /// @notice Migrates any stake delegated directly to an account to its registered EVC owner
    /// @dev If an account has a registered owner different from itself, this function migrates any stake that was
    /// delegated directly to the account (from before owner registration) to the owner
    /// @param owner The registered EVC owner address of the account
    /// @param account The account address to check and migrate stake from
    function _migrateStake(address owner, address account) internal {
        if (owner != address(0) && owner != account) {
            uint256 stake = rewardVault.getDelegateStake(account, address(this));

            if (stake > 0) {
                rewardVault.delegateWithdraw(account, stake);
                rewardVault.delegateStake(owner, stake);
            }
        }
    }
}
