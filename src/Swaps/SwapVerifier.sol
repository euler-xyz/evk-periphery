// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault, IERC20} from "evk/EVault/IEVault.sol";

/// @title SwapVerifier
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Simple contract used to verify post swap conditions
/// @dev This contract is the only trusted code in the EVK swap periphery
contract SwapVerifier {
    error SwapVerifier_skimMin();
    error SwapVerifier_debtMax();

    /// @notice Verify amount of assets available for `skim` in an EVault is greater than a given limit
    /// @param vault The EVault to query
    /// @param amountMin Minimum amount of assets that should be available for skim
    /// @dev Swapper contract will send bought assets to the vault in certain situations.
    /// @dev Calling the function is then equivalent to a slippage check.
    function verifySkimMin(address vault, uint256 amountMin) external view {
        if (amountMin == 0) return;

        uint256 cash = IEVault(vault).cash();
        uint256 balance = IERC20(IEVault(vault).asset()).balanceOf(vault);

        if (balance <= cash || balance - cash < amountMin) revert SwapVerifier_skimMin();
    }

    /// @notice Verify amount of debt held by an account is less than a given limit
    /// @param vault The EVault to query
    /// @param account User account to query
    /// @param amountMax Max amount of debt that can be held by the account
    /// @dev Swapper contract will repay debt up to a requested target amount in certain situations.
    /// @dev Calling the function is then equivalent to a slippage check.
    function verifyDebtMax(address vault, address account, uint256 amountMax) external view {
        uint256 debt = IEVault(vault).debtOf(account);
        if (debt > amountMax) revert SwapVerifier_debtMax();
    }
}
