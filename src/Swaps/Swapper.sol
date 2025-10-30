// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault, IERC20} from "evk/EVault/IEVault.sol";
import {SafeERC20Lib} from "evk/EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

import {ISwapper} from "./ISwapper.sol";

import {GenericHandler} from "./handlers/GenericHandler.sol";
import {UniswapV2Handler} from "./handlers/UniswapV2Handler.sol";
import {UniswapV3Handler} from "./handlers/UniswapV3Handler.sol";

/// @title Swapper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Untrusted helper contract for EVK for performing swaps and swaps to repay
contract Swapper is GenericHandler, UniswapV2Handler, UniswapV3Handler {
    bytes32 public constant HANDLER_GENERIC = bytes32("Generic");
    bytes32 public constant HANDLER_UNISWAP_V2 = bytes32("UniswapV2");
    bytes32 public constant HANDLER_UNISWAP_V3 = bytes32("UniswapV3");

    uint256 internal constant REENTRANCYLOCK_UNLOCKED = 1;
    uint256 internal constant REENTRANCYLOCK_LOCKED = 2;

    uint256 private reentrancyLock;

    error Swapper_UnknownMode();
    error Swapper_UnknownHandler();
    error Swapper_Reentrancy();

    // In the locked state, allow contract to call itself, but block all external calls
    modifier externalLock() {
        bool isExternal = msg.sender != address(this);

        if (isExternal) {
            if (reentrancyLock == REENTRANCYLOCK_LOCKED) revert Swapper_Reentrancy();
            reentrancyLock = REENTRANCYLOCK_LOCKED;
        }

        _;

        if (isExternal) reentrancyLock = REENTRANCYLOCK_UNLOCKED;
    }

    constructor(address uniswapRouterV2, address uniswapRouterV3)
        UniswapV2Handler(uniswapRouterV2)
        UniswapV3Handler(uniswapRouterV3)
    {}

    /// @inheritdoc ISwapper
    function swap(SwapParams memory params) public virtual externalLock {
        if (params.mode >= MODE_MAX_VALUE) revert Swapper_UnknownMode();

        if (params.handler == HANDLER_GENERIC) {
            swapGeneric(params);
        } else if (params.handler == HANDLER_UNISWAP_V2) {
            swapUniswapV2(params);
        } else if (params.handler == HANDLER_UNISWAP_V3) {
            swapUniswapV3(params);
        } else {
            revert Swapper_UnknownHandler();
        }

        if (params.mode == MODE_EXACT_IN) return;

        // swapping to target debt is only useful for repaying
        if (params.mode == MODE_TARGET_DEBT) {
            // at this point amountOut holds the required repay amount
            _repayAndDeposit(params.tokenOut, params.receiver, params.amountOut, params.account);
        }

        // return unused input token after exact output swap
        _deposit(params.tokenIn, params.vaultIn, 0, params.accountIn);
    }

    /// @inheritdoc ISwapper
    /// @dev in case of over-swapping to repay, pass max uint amount
    function repay(address token, address vault, uint256 repayAmount, address account) public virtual externalLock {
        setMaxAllowance(token, vault);
        uint256 balance = IERC20(token).balanceOf(address(this));
        repayAmount = _capRepayToBalance(repayAmount, balance);

        IEVault(vault).repay(repayAmount, account);
    }

    /// @inheritdoc ISwapper
    function repayAndDeposit(address token, address vault, uint256 repayAmount, address account)
        public
        virtual
        externalLock
    {
        _repayAndDeposit(token, vault, repayAmount, account);
    }

    /// @inheritdoc ISwapper
    function deposit(address token, address vault, uint256 amountMin, address account) public virtual externalLock {
        _deposit(token, vault, amountMin, account);
    }

    /// @inheritdoc ISwapper
    function sweep(address token, uint256 amountMin, address to) public virtual externalLock {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance >= amountMin) {
            SafeERC20Lib.safeTransfer(IERC20(token), to, balance);
        }
    }

    /// @inheritdoc ISwapper
    function multicall(bytes[] memory calls) public virtual externalLock {
        for (uint256 i; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).call(calls[i]);
            if (!success) RevertBytes.revertBytes(result);
        }
    }

    // internal

    function _deposit(address token, address vault, uint256 amountMin, address account) internal {
        setMaxAllowance(token, vault);
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance >= amountMin) {
            IEVault(vault).deposit(balance, account);
        }
    }

    function _repayAndDeposit(address token, address vault, uint256 repayAmount, address account) internal {
        setMaxAllowance(token, vault);
        uint256 balance = IERC20(token).balanceOf(address(this));
        repayAmount = _capRepayToBalance(repayAmount, balance);

        repayAmount = IEVault(vault).repay(repayAmount, account);

        if (balance > repayAmount) {
            IEVault(vault).deposit(type(uint256).max, account);
        }
    }

    // Adjust repay to the available balance. It is needed when exact output swaps are not exact in reality.
    // It is user's responsibility to verify the debt is within accepted limits after the call to Swapper
    function _capRepayToBalance(uint256 repayAmount, uint256 balance) internal pure returns (uint256) {
        if (repayAmount != type(uint256).max && repayAmount > balance) {
            repayAmount = balance;
        }

        return repayAmount;
    }
}
