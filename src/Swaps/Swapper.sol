// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault, IERC20} from "evk/EVault/IEVault.sol";
import {SafeERC20Lib} from "evk/EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

import {ISwapper} from "./ISwapper.sol";

import {OneInchHandler} from "./handlers/OneInchHandler.sol";
import {UniswapV2Handler} from "./handlers/UniswapV2Handler.sol";
import {UniswapV3Handler} from "./handlers/UniswapV3Handler.sol";
import {UniswapAutoRouterHandler} from "./handlers/UniswapAutoRouterHandler.sol";

/// @title Swapper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Untrusted helper contract for EVK for performing swaps and swaps to repay
contract Swapper is OneInchHandler, UniswapV2Handler, UniswapV3Handler, UniswapAutoRouterHandler {
    bytes32 public constant HANDLER_ONE_INCH = bytes32("1Inch");
    bytes32 public constant HANDLER_UNISWAP_V2 = bytes32("UniswapV2");
    bytes32 public constant HANDLER_UNISWAP_V3 = bytes32("UniswapV3");
    bytes32 public constant HANDLER_UNISWAP_AUTOROUTER = bytes32("UniswapAutoRouter");

    uint256 internal constant REENTRANCYLOCK_UNLOCKED = 1;
    uint256 internal constant REENTRANCYLOCK_LOCKED = 2;

    uint256 private reentrancyLock;

    error Swapper_UnknownMode();
    error Swapper_UnknownHandler();
    error Swapper_Reentrancy();
    error Swapper_InsufficientBalance();

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

    constructor(address oneInchAggregator, address uniswapRouterV2, address uniswapRouterV3, address uniswapRouter02)
        OneInchHandler(oneInchAggregator)
        UniswapV2Handler(uniswapRouterV2)
        UniswapV3Handler(uniswapRouterV3)
        UniswapAutoRouterHandler(uniswapRouter02)
    {}

    /// @inheritdoc ISwapper
    function swap(SwapParams memory params)
        public
        override (OneInchHandler, UniswapV2Handler, UniswapV3Handler, UniswapAutoRouterHandler)
        externalLock
    {
        if (params.mode >= MODE_MAX_VALUE) revert Swapper_UnknownMode();

        if (params.handler == HANDLER_ONE_INCH) {
            OneInchHandler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_V2) {
            UniswapV2Handler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_V3) {
            UniswapV3Handler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_AUTOROUTER) {
            UniswapAutoRouterHandler.swap(params);
        } else {
            revert Swapper_UnknownHandler();
        }

        if (params.mode == MODE_EXACT_IN) return;

        // swapping to target debt is only useful for repaying
        if (params.mode == MODE_TARGET_DEBT) {
            // at this point amountOut holds the required repay amount
            repayAndDeposit(params.tokenOut, params.receiver, params.amountOut, params.account);
        }

        // return unused input token after exact output swap
        deposit(params.tokenIn, params.vaultIn, 0, params.account);
    }

    /// @inheritdoc ISwapper
    /// @dev in case of over-swapping to repay, pass max uint amount
    function repay(address token, address vault, uint256 repayAmount, address account) public externalLock {
        uint256 balance = setMaxAllowance(token, vault);
        if (repayAmount != type(uint256).max && repayAmount > balance) revert Swapper_InsufficientBalance();

        IEVault(vault).repay(repayAmount, account);
    }

    /// @inheritdoc ISwapper
    function repayAndDeposit(address token, address vault, uint256 repayAmount, address account) public externalLock {
        uint256 balance = setMaxAllowance(token, vault);
        if (repayAmount != type(uint256).max && repayAmount > balance) revert Swapper_InsufficientBalance();

        IEVault(vault).repay(repayAmount, account);

        if (balance > repayAmount) {
            IEVault(vault).deposit(type(uint256).max, account);
        }
    }

    /// @inheritdoc ISwapper
    function deposit(address token, address vault, uint256 amountMin, address account) public externalLock {
        uint256 balance = setMaxAllowance(token, vault);
        if (balance >= amountMin) {
            IEVault(vault).deposit(balance, account);
        }
    }

    /// @inheritdoc ISwapper
    function sweep(address token, uint256 amountMin, address to) public externalLock {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance >= amountMin) {
            SafeERC20Lib.safeTransfer(IERC20(token), to, balance);
        }
    }

    /// @inheritdoc ISwapper
    function multicall(bytes[] memory calls) external externalLock {
        for (uint256 i; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).call(calls[i]);
            if (!success) RevertBytes.revertBytes(result);
        }
    }
}
