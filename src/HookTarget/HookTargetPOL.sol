// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Context, ERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {BaseHookTarget, GenericFactory} from "./BaseHookTarget.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

contract ERC20POL is EVCUtil, ERC20 {
    address public immutable hookTarget;

    error NotHookTarget();

    modifier onlyHookTarget() {
        if (msg.sender != hookTarget) revert NotHookTarget();
        _;
    }

    constructor(address _evc, address _hookTarget, address _eVault)
        EVCUtil(_evc)
        ERC20(
            string(abi.encodePacked(ERC20(_eVault).name(), "-POL")),
            string(abi.encodePacked(ERC20(_eVault).symbol(), "-POL"))
        )
    {
        hookTarget = _hookTarget;
    }

    function mint(address _account, uint256 _amount) external onlyHookTarget {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyHookTarget {
        _burn(_account, _amount);
    }

    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address) {
        return EVCUtil._msgSender();
    }
}

contract HookTargetPOL is BaseHookTarget {
    uint16 internal constant MAX_PROTOCOL_FEE_SHARE = 0.5e4;

    address public immutable eVault;
    ERC20POL public immutable erc20;

    error NotEVault();

    modifier onlyEVault() {
        if (msg.sender != eVault) revert NotEVault();
        _;
    }

    constructor(address _eVaultFactory, address _eVault) BaseHookTarget(_eVaultFactory) {
        if (!GenericFactory(_eVaultFactory).isProxy(_eVault)) revert NotEVault();

        eVault = _eVault;
        erc20 = new ERC20POL(IEVault(eVault).EVC(), address(this), _eVault);
    }

    function deposit(uint256 amount, address receiver) external onlyEVault returns (uint256) {
        amount = IEVault(eVault).previewDeposit(
            amount == type(uint256).max ? ERC20(IEVault(eVault).asset()).balanceOf(_msgSender()) : amount
        );

        if (amount > 0) erc20.mint(receiver, amount);
        return 0;
    }

    function mint(uint256 amount, address receiver) external onlyEVault returns (uint256) {
        if (amount > 0) erc20.mint(receiver, amount);
        return 0;
    }

    function withdraw(uint256 amount, address, address owner) external onlyEVault returns (uint256) {
        amount = IEVault(eVault).previewWithdraw(amount);

        if (amount > 0) erc20.burn(owner, amount);
        return 0;
    }

    function redeem(uint256 amount, address, address owner) external onlyEVault returns (uint256) {
        if (amount == type(uint256).max) {
            amount = ERC20(eVault).balanceOf(owner);
        }

        if (amount > 0) erc20.burn(owner, amount);
        return 0;
    }

    function skim(uint256 amount, address receiver) external onlyEVault returns (uint256) {
        amount = IEVault(eVault).previewDeposit(
            amount == type(uint256).max
                ? ERC20(IEVault(eVault).asset()).balanceOf(eVault) - IEVault(eVault).cash()
                : amount
        );

        if (amount > 0) erc20.mint(receiver, amount);
        return 0;
    }

    function repayWithShares(uint256 amount, address) external onlyEVault returns (uint256 shares, uint256 debt) {
        address owner = _msgSender();
        amount = IEVault(eVault).previewWithdraw(amount == type(uint256).max ? ERC20(eVault).balanceOf(owner) : amount);

        if (amount > 0) erc20.burn(owner, amount);
        return (0, 0);
    }

    function convertFees() external onlyEVault {
        (address protocolReceiver, uint16 protocolFee) =
            ProtocolConfig(IEVault(eVault).protocolConfigAddress()).protocolFeeConfig(eVault);
        address governorReceiver = IEVault(eVault).feeReceiver();

        if (governorReceiver == address(0)) {
            protocolFee = CONFIG_SCALE;
        } else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) {
            protocolFee = MAX_PROTOCOL_FEE_SHARE;
        }

        uint256 accumulatedFees = IEVault(eVault).accumulatedFees();
        uint256 governorShares = accumulatedFees * (CONFIG_SCALE - protocolFee) / CONFIG_SCALE;
        uint256 protocolShares = accumulatedFees - governorShares;

        if (governorShares > 0) erc20.mint(governorReceiver, governorShares);
        if (protocolShares > 0) erc20.mint(protocolReceiver, protocolShares);
    }
}
