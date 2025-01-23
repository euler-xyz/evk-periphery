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
    /// @param irm The address of the interest rate model, ignored if escrow
    /// @param escrow True if the vault is collateral only, false if it is borrowable
    struct VaultParams {
        address asset;
        address irm;
        bool escrow;
    }

    /// @notice Parameters for configuring an oracle adapter in the router
    /// @param base The base token address
    /// @param adapter The oracle adapter address
    struct AdapterParams {
        address base;
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
    /// @param collateralVaultIndex Index of the collateral vault in the vaults array
    /// @param controllerVaultIndex Index of the controller vault in the vaults array
    /// @param borrowLTV The loan-to-value ratio for borrowing (1e4 = 100%)
    /// @param liquidationLTV The loan-to-value ratio for liquidation (1e4 = 100%)
    struct LTVParams {
        uint256 collateralVaultIndex;
        uint256 controllerVaultIndex;
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
    /// @param vaults Array of constituent vaults
    event EdgeDeployed(address indexed router, address[] vaults);

    /// @notice Thrown when attempting to deploy with fewer than 2 vaults
    error E_TooFewVaults();

    /// @notice Thrown when attempting to query deployments with invalid indices
    error E_BadQuery();

    /// @notice Deploys an Edge market
    /// @param params The deployment parameters
    /// @dev This function performs the following steps:
    /// @dev 1. Deploys a router
    /// @dev 2. Configures price adapters in the router
    /// @dev 3. Resolves external vaults in the router
    /// @dev 4. Deploys and configures vaults with specified parameters
    /// @dev 5. Sets up LTV relationships between vaults
    /// @dev 6. Renounces governance for all deployed contracts
    /// @dev After deployment, governance is permanently renounced
    /// @dev Reverts if:
    /// @dev - Less than 2 vaults are specified in params
    /// @return The deployed router contract
    /// @return An array of vault addresses in the market
    function deploy(DeployParams calldata params) external returns (address, address[] memory);

    /// @notice The factory contract for deploying vaults
    function eVaultFactory() external view returns (address);

    /// @notice The factory contract for deploying routers
    function eulerRouterFactory() external view returns (address);

    /// @notice Address of the escrowed collateral perspective contract
    function escrowedCollateralPerspective() external view returns (address);

    /// @notice Get the array of vaults for a given deployment index
    function getDeployment(uint256 i) external view returns (address[] memory);

    /// @notice Get the total number of deployments
    /// @return count The total number of Edge markets deployed
    function getDeploymentsListLength() external view returns (uint256);

    /// @notice Get a slice of vault deployment addresses
    /// @param start The start index of the slice from the list of deployed routers (inclusive)
    /// @param end The end index of the slice from the list of deployed routers (exclusive)
    /// @return list An array of arrays of vault addresses, where each inner array contains all vaults for a single Edge
    /// market
    function getDeploymentsListSlice(uint256 start, uint256 end) external view returns (address[][] memory list);

    /// @notice Whether a vault belongs to any one Edge market
    function isDeployed(address vault) external view returns (bool);
}
