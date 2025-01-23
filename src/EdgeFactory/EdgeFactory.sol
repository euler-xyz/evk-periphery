// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

import {IEulerRouterFactory} from "../EulerRouterFactory/interfaces/IEulerRouterFactory.sol";
import {IEdgeFactory} from "./interfaces/IEdgeFactory.sol";
import {EscrowedCollateralPerspective} from "../Perspectives/deployed/EscrowedCollateralPerspective.sol";

/// @title EdgeFactory
/// @custom:security-contact security@euler.xyz
/// @author Objective Labs (https://www.objectivelabs.io/)
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Factory contract for deploying and configuring Edge markets
/// @dev Deploys and configures vaults, router, and their collateral relationships
contract EdgeFactory is IEdgeFactory {
    /// @notice Name of the factory contract
    string public constant name = "Edge Factory";

    /// @notice Minimum delay for a liquidation to happen in seconds
    uint16 internal constant LIQ_COOL_OFF_TIME = 1;

    /// @notice Maximum discount applied during liquidations (15%)
    /// @dev Represented in basis points where 1e4 = 100%
    uint16 internal constant MAX_LIQ_DISCOUNT = 0.15e4;

    /// @notice The factory contract for deploying vaults
    address public immutable eVaultFactory;

    /// @notice The factory contract for deploying routers
    address public immutable eulerRouterFactory;

    /// @notice Address of the escrowed collateral perspective contract
    address public immutable escrowedCollateralPerspective;

    /// @notice Mapping from vault address to whether it was deployed by this factory
    mapping(address => bool) public isDeployed;

    /// @notice Array of all Edge market deployments.
    address[][] internal deployments;

    /// @notice Constructs a new EdgeFactory
    /// @param _eVaultFactory Address of the vault factory contract
    /// @param _eulerRouterFactory Address of the router factory contract
    /// @param _escrowedCollateralPerspective Address of the escrowed collateral perspective contract
    constructor(address _eVaultFactory, address _eulerRouterFactory, address _escrowedCollateralPerspective) {
        eVaultFactory = _eVaultFactory;
        eulerRouterFactory = _eulerRouterFactory;
        escrowedCollateralPerspective = _escrowedCollateralPerspective;
    }

    /// @inheritdoc IEdgeFactory
    function deploy(DeployParams calldata params) external returns (address, address[] memory) {
        if (params.vaults.length < 2) revert E_TooFewVaults();

        // Deploy router
        EulerRouter router = EulerRouter(IEulerRouterFactory(eulerRouterFactory).deploy(address(this)));
        RouterParams memory routerParams = params.router;

        // Configure adapters in the router
        for (uint256 i; i < routerParams.adapters.length; ++i) {
            AdapterParams memory adapterParams = routerParams.adapters[i];
            router.govSetConfig(adapterParams.base, params.unitOfAccount, adapterParams.adapter);
        }

        // Resolve external vaults in the router
        for (uint256 i; i < params.router.externalResolvedVaults.length; ++i) {
            address vault = params.router.externalResolvedVaults[i];
            router.govSetResolvedVault(vault, true);
        }

        // Deploy and configure vaults
        address[] memory vaults = new address[](params.vaults.length);
        for (uint256 i; i < params.vaults.length; ++i) {
            VaultParams memory vaultParams = params.vaults[i];

            address vault;
            if (vaultParams.escrow) {
                // If the escrowed collateral vault is not deployed, deploy it and verify it in the perspective.
                vault = EscrowedCollateralPerspective(escrowedCollateralPerspective).singletonLookup(vaultParams.asset);
                if (vault == address(0)) {
                    bytes memory trailingData = abi.encodePacked(vaultParams.asset, address(0), address(0));
                    vault = GenericFactory(eVaultFactory).createProxy(address(0), true, trailingData);
                    IEVault(vault).setHookConfig(address(0), 0);
                    IEVault(vault).setGovernorAdmin(address(0));
                    EscrowedCollateralPerspective(escrowedCollateralPerspective).perspectiveVerify(vault, true);
                }
            } else {
                // This is a borrowable vault. Deploy and configure it.
                bytes memory trailingData = abi.encodePacked(vaultParams.asset, router, params.unitOfAccount);
                vault = GenericFactory(eVaultFactory).createProxy(address(0), true, trailingData);
                IEVault(vault).setInterestRateModel(vaultParams.irm);
                IEVault(vault).setLiquidationCoolOffTime(LIQ_COOL_OFF_TIME);
                IEVault(vault).setMaxLiquidationDiscount(MAX_LIQ_DISCOUNT);
                IEVault(vault).setHookConfig(address(0), 0);
            }
            vaults[i] = vault;
            // Resolve vault in the router
            router.govSetResolvedVault(address(vault), true);
        }

        // Configure LTVs
        for (uint256 i; i < params.ltv.length; ++i) {
            LTVParams memory ltvParams = params.ltv[i];
            address controllerVault = vaults[ltvParams.controllerVaultIndex];
            address collateralVault = vaults[ltvParams.collateralVaultIndex];
            // Note: setLTV will revert if controllerVault is escrow
            IEVault(controllerVault).setLTV(collateralVault, ltvParams.borrowLTV, ltvParams.liquidationLTV, 0);
        }

        // Renounce governance
        for (uint256 i; i < vaults.length; ++i) {
            if (!params.vaults[i].escrow) {
                IEVault(vaults[i]).setGovernorAdmin(address(0));
            }
            if (!isDeployed[vaults[i]]) {
                isDeployed[vaults[i]] = true;
            }
        }
        router.transferGovernance(address(0));

        deployments.push(vaults);
        emit EdgeDeployed(address(router), vaults);
        return (address(router), vaults);
    }

    /// @inheritdoc IEdgeFactory
    function getDeployment(uint256 i) external view returns (address[] memory) {
        return deployments[i];
    }

    /// @inheritdoc IEdgeFactory
    function getDeploymentsListLength() external view returns (uint256) {
        return deployments.length;
    }

    /// @inheritdoc IEdgeFactory
    function getDeploymentsListSlice(uint256 start, uint256 end) external view returns (address[][] memory list) {
        if (end == type(uint256).max) end = deployments.length;
        if (end < start || end > deployments.length) revert();

        list = new address[][](end - start);
        for (uint256 i; i < end - start; ++i) {
            list[i] = deployments[i];
        }
    }
}
