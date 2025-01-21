// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// @title IEdgeFactory
/// @custom:security-contact security@euler.xyz
/// @author Objective Labs (https://www.objectivelabs.io/)
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Factory contract for deploying and configuring Edge markets
interface IEdgeFactory {
    /// @notice Parameters for deploying a vault
    /// @param asset The underlying asset of the vault
    /// @param borrowable Whether the vault supports borrowing
    struct VaultParams {
        address asset;
        address irm;
        bool borrowable;
    }

    /// @notice Parameters for configuring an oracle adapter in the router
    /// @param base The base token address
    /// @param quote The quote token address
    /// @param adapter The oracle adapter address
    struct AdapterParams {
        address base;
        address quote;
        address adapter;
    }

    /// @notice Parameters for configuring the oracle router
    /// @param externalResolvedVaults Array of external ERC4626 vaults to be resolved
    /// @param adapters Array of oracle adapter configurations
    struct RouterParams {
        address[] externalResolvedVaults;
        AdapterParams[] adapters;
    }

    /// @notice Parameters for setting loan-to-value ratios between vaults
    /// @param controllerVaultIndex Index of the controller vault in the vaults array
    /// @param collateralVaultIndex Index of the collateral vault in the vaults array
    /// @param borrowLTV The loan-to-value ratio for borrowing (1e4 = 100%)
    /// @param liquidationLTV The loan-to-value ratio for liquidation (1e4 = 100%)
    struct LTVParams {
        uint256 controllerVaultIndex;
        uint256 collateralVaultIndex;
        uint16 borrowLTV;
        uint16 liquidationLTV;
    }

    /// @notice Parameters for deploying an Edge market
    /// @param vaults Array of vault configurations
    /// @param router Router configuration
    /// @param ltv Array of LTV configurations between vaults
    /// @param unitOfAccount The unit of account token address
    struct DeployParams {
        VaultParams[] vaults;
        RouterParams router;
        LTVParams[] ltv;
        address unitOfAccount;
    }

    /// @notice Emitted when a new Edge market is deployed
    /// @param router The deployed router contract
    /// @param vaults Array of deployed vault contracts
    event EdgeDeployed(address indexed router, address[] vaults);

    /// @notice Thrown when attempting to deploy with fewer than 2 vaults
    error E_TooFewVaults();

    /// @notice Thrown when attempting to set LTV parameters for a non-borrowable vault
    error E_LTVForNonBorrowableVault();

    /// @notice Deploys an Edge market
    function deploy(DeployParams calldata params) external returns (address, address[] memory);
}
