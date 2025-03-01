// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "evk/EVault/IEVault.sol";
import {SafeERC20Lib} from "evk/EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

interface IERC1271 {
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4);
}

/// @title Permit2Adapter
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Untrusted helper contract for swaps on EVK with providers requiring Permit2 support
contract Permit2Adapter {
    address public immutable PERMIT2;

    bytes4 private constant MAGIC_WORD = IERC1271.isValidSignature.selector;

    constructor(address permit2) {
        PERMIT2 = permit2;
    }

    function swap(
        address target,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        address receiver,
        bytes calldata data
    ) external {
        setMaxAllowance(tokenIn, PERMIT2);
        (bool success, bytes memory result) =
            SafeERC20Lib.trySafeTransferFrom(IERC20(tokenIn), msg.sender, address(this), amount);

        if (!success) RevertBytes.revertBytes(result);

        (success, result) = target.call(data);
        if (!success) RevertBytes.revertBytes(result);

        sweep(tokenOut, 0, receiver);
    }

    function sweep(address token, uint256 amountMin, address to) public {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance >= amountMin) {
            SafeERC20Lib.safeTransfer(IERC20(token), to, balance);
        }
    }

    function approvePermit2(address token) public {
        setMaxAllowance(token, PERMIT2);
    }

    function isValidSignature(bytes32, bytes memory) external view returns (bytes4 magicValue) {
        return msg.sender == address(PERMIT2) ? MAGIC_WORD : bytes4(0);
    }

    function setMaxAllowance(address token, address spender) internal {
        safeApproveWithRetry(token, spender, type(uint256).max);
    }

    function trySafeApprove(address token, address to, uint256 value) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        return (success && (data.length == 0 || abi.decode(data, (bool))), data);
    }

    function safeApproveWithRetry(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = trySafeApprove(token, to, value);

        // some tokens, like USDT, require the allowance to be set to 0 first
        if (!success) {
            (success,) = trySafeApprove(token, to, 0);
            if (success) {
                (success,) = trySafeApprove(token, to, value);
            }
        }

        if (!success) RevertBytes.revertBytes(data);
    }
}
