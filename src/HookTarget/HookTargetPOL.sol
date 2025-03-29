// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import "evk/EVault/shared/Constants.sol";

interface IRewardVaultFactory {
    function predictRewardVaultAddress(address stakingToken) external view returns (address);
}

interface IRewardVault {
    function getDelegateStake(address account, address delegate) external view returns (uint256);
    function delegateStake(address account, uint256 amount) external;
    function delegateWithdraw(address account, uint256 amount) external;
}

contract ERC20POL is Ownable, ERC20 {
    constructor(address _eVault)
        Ownable(msg.sender)
        ERC20(
            string(abi.encodePacked(ERC20(_eVault).name(), "-POL")),
            string(abi.encodePacked(ERC20(_eVault).symbol(), "-POL"))
        )
    {}

    function mint(uint256 _amount) external onlyOwner {
        if (_amount == 0) return;
        _mint(owner(), _amount);
    }

    function burn(uint256 _amount) external onlyOwner {
        if (_amount == 0) return;
        _burn(owner(), _amount);
    }
}

contract HookTargetPOL is Ownable, IHookTarget {
    uint16 internal constant MAX_PROTOCOL_FEE_SHARE = 0.5e4;

    IEVC public immutable evc;
    IEVault public immutable eVault;
    ERC20POL public immutable erc20;
    IRewardVault public immutable rewardVault;

    constructor(address _eVault, address _rewardVaultFactory) Ownable(_eVault) {
        evc = IEVC(IEVault(_eVault).EVC());
        eVault = IEVault(_eVault);
        erc20 = new ERC20POL(_eVault);
        rewardVault = IRewardVault(IRewardVaultFactory(_rewardVaultFactory).predictRewardVaultAddress(address(erc20)));
        erc20.approve(address(rewardVault), type(uint256).max);
    }

    function deposit(uint256 amount, address receiver) external onlyOwner returns (uint256) {
        amount = eVault.previewDeposit(
            amount == type(uint256).max ? ERC20(eVault.asset()).balanceOf(_eVaultCaller()) : amount
        );

        erc20.mint(amount);
        _delegateStake(receiver, amount);
        return 0;
    }

    function mint(uint256 amount, address receiver) external onlyOwner returns (uint256) {
        erc20.mint(amount);
        _delegateStake(receiver, amount);
        return 0;
    }

    function withdraw(uint256 amount, address, address owner) external onlyOwner returns (uint256) {
        amount = eVault.previewWithdraw(amount);

        erc20.burn(_delegateWithdraw(owner, amount));
        return 0;
    }

    function redeem(uint256 amount, address, address owner) external onlyOwner returns (uint256) {
        if (amount == type(uint256).max) {
            amount = eVault.balanceOf(owner);
        }

        erc20.burn(_delegateWithdraw(owner, amount));
        return 0;
    }

    function skim(uint256 amount, address receiver) external onlyOwner returns (uint256) {
        amount = eVault.previewDeposit(
            amount == type(uint256).max ? ERC20(eVault.asset()).balanceOf(address(eVault)) - eVault.cash() : amount
        );

        erc20.mint(amount);
        _delegateStake(receiver, amount);
        return 0;
    }

    function repayWithShares(uint256 amount, address) external onlyOwner returns (uint256 shares, uint256 debt) {
        address owner = _eVaultCaller();
        amount = eVault.previewWithdraw(amount == type(uint256).max ? eVault.balanceOf(owner) : amount);

        erc20.burn(_delegateWithdraw(owner, amount));
        return (0, 0);
    }

    function transfer(address to, uint256 amount) external onlyOwner returns (bool) {
        _delegateStake(to, _delegateWithdraw(_eVaultCaller(), amount));
        return false;
    }

    function transferFrom(address from, address to, uint256 amount) external onlyOwner returns (bool) {
        _delegateStake(to, _delegateWithdraw(from, amount));
        return false;
    }

    function transferFromMax(address from, address to) external onlyOwner returns (bool) {
        uint256 amount = eVault.balanceOf(from);

        _delegateStake(to, _delegateWithdraw(from, amount));
        return false;
    }

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

    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    function _eVaultCaller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    function _delegateStake(address account, uint256 amount) internal {
        if (amount == 0) return;

        address owner = evc.getAccountOwner(account);
        rewardVault.delegateStake(owner == address(0) ? account : owner, amount);
    }

    function _delegateWithdraw(address account, uint256 amount) internal returns (uint256) {
        address owner = evc.getAccountOwner(account);

        if (owner != address(0) && owner != account) {
            uint256 delegateStakeAccount = rewardVault.getDelegateStake(account, address(this));

            if (delegateStakeAccount > 0) {
                rewardVault.delegateWithdraw(account, delegateStakeAccount);
                rewardVault.delegateStake(owner, delegateStakeAccount);
            }
        }

        if (owner == address(0)) owner = account;

        uint256 delegateStakeOwner = rewardVault.getDelegateStake(owner, address(this));

        if (amount > delegateStakeOwner) {
            amount = delegateStakeOwner;
        }

        if (amount == 0) return 0;

        rewardVault.delegateWithdraw(owner, amount);
        return amount;
    }
}
