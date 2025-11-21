// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault, IERC20} from "evk/EVault/IEVault.sol";
import {TransferFromSender} from "./TransferFromSender.sol";

/// @title SwapVerifier
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Simple contract used to verify post swap conditions. Includes TransferFromSender helper for gas savings.
/// @dev This contract is the only trusted code in the EVK swap periphery
contract SwapVerifier is TransferFromSender {
    error SwapVerifier_skimMin();
    error SwapVerifier_debtMax();
    error SwapVerifier_pastDeadline();

    /// @notice Contract constructor
    /// @param evc Address of the EthereumVaultConnector contract
    /// @param permit2 Address of the Permit2 contract
    constructor(address evc, address permit2) TransferFromSender(evc, permit2) {}

    /// @notice Verify results of a regular swap, when bought tokens are sent to the vault and skim for the buyer
    /// @param vault The EVault to query
    /// @param receiver Account to skim to
    /// @param amountMin Minimum amount of assets that should be available for skim
    /// @param deadline Timestamp after which the swap transaction is outdated
    /// @dev Swapper contract will send bought assets to the vault in certain situations.
    /// @dev Calling this function is then necessary to perform slippage check and claim the output for the buyer
    function verifyAmountMinAndSkim(address vault, address receiver, uint256 amountMin, uint256 deadline) external {
        if (deadline < block.timestamp) revert SwapVerifier_pastDeadline();
        if (amountMin == 0) return;

        uint256 cash = IEVault(vault).cash();
        uint256 balance = IERC20(IEVault(vault).asset()).balanceOf(vault);

        unchecked {
            if (balance <= cash || balance - cash < amountMin) revert SwapVerifier_skimMin();
        }

        IEVault(vault).skim(type(uint256).max, receiver);
    }

    /// @notice Verify results of a swap and repay operation, when debt is repaid down to a requested target
    /// @param vault The EVault to query
    /// @param account User account to query
    /// @param amountMax Max amount of debt that can be held by the account
    /// @param deadline Timestamp after which the swap transaction is outdated
    /// @dev Swapper contract will repay debt up to a requested target amount in certain situations.
    /// @dev Calling the function is then equivalent to a slippage check.
    function verifyDebtMax(address vault, address account, uint256 amountMax, uint256 deadline) external view {
        if (deadline < block.timestamp) revert SwapVerifier_pastDeadline();
        if (amountMax == type(uint256).max) return;

        uint256 debt = IEVault(vault).debtOf(account);

        if (debt > amountMax) revert SwapVerifier_debtMax();
    }
}
