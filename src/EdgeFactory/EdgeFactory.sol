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
    address public immutable eVaultFactory;

    /// @notice The factory contract for deploying routers
    address public immutable eulerRouterFactory;

    /// @notice Address of the escrowed collateral perspective contract
    address public immutable escrowedCollateralPerspective;

    /// @notice Mapping from router address to its associated vault addresses
    /// @dev Each router maps to an array of vault addresses that were deployed with it as part of an Edge market
    mapping(address => address[]) public routerToVaults;

    /// @notice Array of all deployed router addresses
    /// @dev Maintains a list of all routers deployed by this factory, in chronological order
    address[] public deployedRouters;

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
            router.govSetConfig(adapterParams.base, adapterParams.quote, adapterParams.adapter);
        }

        // Resolve external vaults in the router
        for (uint256 i; i < params.router.externalResolvedVaults.length; ++i) {
            address vault = params.router.externalResolvedVaults[i];
            router.govSetResolvedVault(vault, true);
        }

        // Deploy and configure vaults
        address[] memory vaults = new address[](params.vaults.length);
        address vaultImplementation = GenericFactory(eVaultFactory).implementation();
        for (uint256 i; i < params.vaults.length; ++i) {
            VaultParams memory vaultParams = params.vaults[i];

            address vault;
            if (vaultParams.escrow) {
                // If the escrowed collateral vault is not deployed, deploy it and verify it in the perspective.
                vault = EscrowedCollateralPerspective(escrowedCollateralPerspective).singletonLookup(vaultParams.asset);
                if (vault == address(0)) {
                    bytes memory trailingData = abi.encodePacked(vaultParams.asset, address(0), address(0));
                    vault =
                        GenericFactory(eVaultFactory).createProxy(vaultImplementation, VAULT_UPGRADEABLE, trailingData);
                    IEVault(vault).setHookConfig(address(0), 0);
                    IEVault(vault).setGovernorAdmin(address(0));
                    EscrowedCollateralPerspective(escrowedCollateralPerspective).perspectiveVerify(vault, true);
                }
            } else {
                // This is a borrowable vault. Deploy and configure it.
                bytes memory trailingData = abi.encodePacked(vaultParams.asset, router, params.unitOfAccount);
                vault = GenericFactory(eVaultFactory).createProxy(vaultImplementation, VAULT_UPGRADEABLE, trailingData);
                IEVault(vault).setInterestFee(INTEREST_FEE);
                IEVault(vault).setInterestRateModel(vaultParams.irm);
                IEVault(vault).setLiquidationCoolOffTime(LIQ_COOL_OFF_TIME);
                IEVault(vault).setMaxLiquidationDiscount(MAX_LIQ_DISCOUNT);
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
        }
        router.transferGovernance(address(0));

        deployedRouters.push(address(router));
        routerToVaults[address(router)] = vaults;
        emit EdgeDeployed(address(router), vaults);
        return (address(router), vaults);
    }

    /// @inheritdoc IEdgeFactory
    function getDeploymentsListLength() external view returns (uint256) {
        return deployedRouters.length;
    }

    /// @inheritdoc IEdgeFactory
    function getDeploymentsListSlice(uint256 start, uint256 end) external view returns (address[][] memory list) {
        if (end == type(uint256).max) end = deployedRouters.length;
        if (end < start || end > deployedRouters.length) revert();

        list = new address[][](end - start);
        for (uint256 i; i < end - start; ++i) {
            list[i] = routerToVaults[deployedRouters[i]];
        }
    }
}
