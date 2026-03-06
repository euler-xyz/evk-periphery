// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {TransferFromSender} from "./TransferFromSender.sol";
import {IEVault, IERC4626} from "evk/EVault/IEVault.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SwapVerifier
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Simple contract used to verify post swap conditions. Includes TransferFromSender helper for gas savings.
/// @dev This contract is the only trusted code in the EVK swap periphery
contract SwapVerifier is TransferFromSender {
    error SwapVerifier_skimMin();
    error SwapVerifier_depositMin();
    error SwapVerifier_transferMin();
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

        uint256 cash = IEVault(vault).cash();
        uint256 balance = IERC20(IEVault(vault).asset()).balanceOf(vault);

        unchecked {
            if (balance <= cash || balance - cash < amountMin) revert SwapVerifier_skimMin();
        }

        IEVault(vault).skim(type(uint256).max, receiver);
    }

    /// @notice Verify results of a regular swap, when bought tokens are sent to the verifier, and deposit for the buyer
    /// @param vault The ERC4626 vault to deposit to
    /// @param receiver Account to deposit for
    /// @param amountMin Minimum amount of assets that should be available for deposit
    /// @param deadline Timestamp after which the swap transaction is outdated
    /// @dev Swapper contract will send bought assets to the verifier in certain situations.
    /// @dev Calling this function is then necessary to perform slippage check and claim the output for the buyer
    function verifyAmountMinAndDeposit(address vault, address receiver, uint256 amountMin, uint256 deadline) external {
        if (deadline < block.timestamp) revert SwapVerifier_pastDeadline();

        IERC20 asset = IERC20(IERC4626(vault).asset());
        uint256 balance = asset.balanceOf(address(this));

        if (balance < amountMin) revert SwapVerifier_depositMin();

        SafeERC20.forceApprove(asset, vault, balance);
        IERC4626(vault).deposit(balance, receiver);
    }

    /// @notice Verify that enough of a given asset is present for transfer, then transfer the asset to the receiver.
    /// @param asset The address of the ERC20 token to transfer
    /// @param receiver The address to transfer the asset to
    /// @param amountMin The minimum amount of the asset that must be available before transfer
    /// @param deadline A timestamp after which the transfer will revert
    /// @dev This function checks for slippage and sends all of the contract's balance of the asset to the receiver if the minimum is met
    function verifyAmountMinAndTransfer(address asset, address receiver, uint256 amountMin, uint256 deadline) external {
        if (deadline < block.timestamp) revert SwapVerifier_pastDeadline();

        uint256 balance = IERC20(asset).balanceOf(address(this));

        if (balance < amountMin) revert SwapVerifier_transferMin();

        SafeERC20.safeTransfer(IERC20(asset), receiver, balance);
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
