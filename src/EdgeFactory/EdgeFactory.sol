// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

import {IEulerRouterFactory} from "../EulerRouterFactory/interfaces/IEulerRouterFactory.sol";
import {IEdgeFactory} from "./interfaces/IEdgeFactory.sol";

/// @title EdgeFactory
/// @custom:security-contact security@euler.xyz
/// @author Objective Labs (https://www.objectivelabs.io/)
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Factory contract for deploying and configuring Edge markets
/// @dev Deploys and configures vaults, router, and their collateral relationships
contract EdgeFactory is IEdgeFactory {
    /// @notice Name of the factory contract
    string public constant name = "Edge Factory";

    /// @notice Whether deployed vaults are upgradeable
    bool internal constant VAULT_UPGRADEABLE = true;

    /// @notice Interest fee charged by vaults (0.1%)
    /// @dev Represented in basis points where 1e4 = 100%
    uint16 internal constant INTEREST_FEE = 0.1e4;

    /// @notice Minimum delay for a liquidation to happen in seconds
    uint16 internal constant LIQ_COOL_OFF_TIME = 1;

    /// @notice Maximum discount applied during liquidations (15%)
    /// @dev Represented in basis points where 1e4 = 100%
    uint16 internal constant MAX_LIQ_DISCOUNT = 0.15e4;

    /// @notice The factory contract for deploying vaults
    GenericFactory public immutable eVaultFactory;

    /// @notice The factory contract for deploying routers
    IEulerRouterFactory public immutable eulerRouterFactory;

    /// @notice Array of all deployed vault addresses
    /// @dev Used for tracking deployment history
    address[] public allVaults;

    /// @notice Constructs a new EdgeFactory
    /// @param _eVaultFactory Address of the vault factory contract
    /// @param _eulerRouterFactory Address of the router factory contract
    constructor(address _eVaultFactory, address _eulerRouterFactory) {
        eVaultFactory = GenericFactory(_eVaultFactory);
        eulerRouterFactory = IEulerRouterFactory(_eulerRouterFactory);
    }

    /// @notice Deploys an Edge market
    /// @param params The deployment parameters
    /// @dev This function performs the following steps:
    /// @dev 1. Deploys a router
    /// @dev 2. Configures price adapters in the router
    /// @dev 3. Resolves external vaults in the router
    /// @dev 4. Deploys and configures vaults with specified parameters
    /// @dev 5. Sets up LTV relationships between vaults
    /// @dev 6. Renounces governance for all deployed contracts
    /// @dev After deployment, governance is permanently transferred to address(0)
    /// @dev Reverts if:
    /// @dev - Less than 2 vaults are specified in params
    /// @dev - Attempting to set LTV for a non-borrowable vault
    function deploy(DeployParams calldata params) external returns (address, address[] memory) {
        if (params.vaults.length < 2) revert E_TooFewVaults();

        // Deploy router
        EulerRouter router = EulerRouter(eulerRouterFactory.deploy(address(this)));
        RouterParams memory routerParams = params.router;

        // Configure adapters in the router
        for (uint256 i; i < routerParams.adapters.length; ++i) {
            AdapterParams memory adapterParams = routerParams.adapters[i];
            router.govSetConfig(adapterParams.base, adapterParams.quote, adapterParams.adapter);
        }

        // Resolve external vaults in the router
        for (uint256 i; i < params.router.externalResolvedVaults.length; ++i) {
            address vault = params.router.externalResolvedVaults[i];
            router.govSetResolvedVault(vault, true);
        }

        // Deploy and configure vaults
        address[] memory deployedVaults = new address[](params.vaults.length);
        address vaultImplementation = eVaultFactory.implementation();
        for (uint256 i; i < params.vaults.length; ++i) {
            VaultParams memory vaultParams = params.vaults[i];
            // Deploy and configure vault
            bytes memory trailingData = abi.encodePacked(vaultParams.asset, router, params.unitOfAccount);
            address vault = eVaultFactory.createProxy(vaultImplementation, VAULT_UPGRADEABLE, trailingData);
            if (vaultParams.borrowable) {
                IEVault(vault).setInterestFee(INTEREST_FEE);
                IEVault(vault).setInterestRateModel(vaultParams.irm);
                IEVault(vault).setLiquidationCoolOffTime(LIQ_COOL_OFF_TIME);
                IEVault(vault).setMaxLiquidationDiscount(MAX_LIQ_DISCOUNT);
            }
            deployedVaults[i] = vault;
            allVaults.push(vault);
            // Resolve vault in the router
            router.govSetResolvedVault(address(vault), true);
        }

        // Configure LTVs
        for (uint256 i; i < params.ltv.length; ++i) {
            LTVParams memory ltvParams = params.ltv[i];
            if (!params.vaults[ltvParams.controllerVaultIndex].borrowable) {
                revert E_LTVForNonBorrowableVault();
            }

            address controllerVault = deployedVaults[ltvParams.controllerVaultIndex];
            address collateralVault = deployedVaults[ltvParams.collateralVaultIndex];
            IEVault(controllerVault).setLTV(collateralVault, ltvParams.borrowLTV, ltvParams.liquidationLTV, 0);
        }

        // Renounce governance
        for (uint256 i; i < deployedVaults.length; ++i) {
            IEVault(deployedVaults[i]).setGovernorAdmin(address(0));
        }
        router.transferGovernance(address(0));

        emit EdgeDeployed(address(router), deployedVaults);
        return (address(router), deployedVaults);
    }
}
