// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {IEulerRouter} from "../../OracleFactory/interfaces/IEulerRouter.sol";
import {IEulerRouterFactory} from "../../OracleFactory/interfaces/IEulerRouterFactory.sol";
import {SnapshotRegistry} from "../../OracleFactory/SnapshotRegistry.sol";
import {IEulerKinkIRMFactory} from "../../IRMFactory/interfaces/IEulerKinkIRMFactory.sol";
import {BasePerspective} from "./BasePerspective.sol";

/// @title DefaultClusterPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault has the properties of a cluster vault. It allows collaterals to be
/// recognized by ony of the specified perspectives.
abstract contract DefaultClusterPerspective is BasePerspective {
    address[] public recognizedCollateralPerspectives;
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IEulerRouterFactory internal immutable routerFactory;
    SnapshotRegistry internal immutable adapterRegistry;
    SnapshotRegistry internal immutable externalVaultRegistry;
    IEulerKinkIRMFactory internal immutable irmFactory;

    /// @notice Creates a new DefaultClusterPerspective instance.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    /// @param routerFactory_ The address of the EulerRouterFactory contract.
    /// @param adapterRegistry_ The address of the adapter registry contract.
    /// @param externalVaultRegistry_ The address of the external vault registry contract.
    /// @param irmFactory_ The address of the EulerKinkIRMFactory contract.
    /// @param recognizedCollateralPerspectives_ The addresses of the recognized collateral perspectives. address(0) for
    /// self.
    constructor(
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address externalVaultRegistry_,
        address irmFactory_,
        address[] memory recognizedCollateralPerspectives_
    ) BasePerspective(vaultFactory_) {
        routerFactory = IEulerRouterFactory(routerFactory_);
        adapterRegistry = SnapshotRegistry(adapterRegistry_);
        externalVaultRegistry = SnapshotRegistry(externalVaultRegistry_);
        irmFactory = IEulerKinkIRMFactory(irmFactory_);
        recognizedCollateralPerspectives = recognizedCollateralPerspectives_;
    }

    function perspectiveVerifyInternal(address vault) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), ERROR__FACTORY);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        // cluster vaults must not be upgradeable
        testProperty(!config.upgradeable, ERROR__UPGRADABILITY);

        // cluster vaults must not be nested
        testProperty(!vaultFactory.isProxy(IEVault(vault).asset()), ERROR__NESTING);

        // verify vault configuration at the governance level
        // cluster vaults must not have a governor admin
        testProperty(IEVault(vault).governorAdmin() == address(0), ERROR__GOVERNOR);

        // cluster vaults must have an interest fee in a certain range. lower bound is enforced by the vault itself
        testProperty(IEVault(vault).interestFee() <= 0.5e4, ERROR__INTEREST_FEE);

        // cluster vaults must point to a Kink IRM instance deployed by the factory
        testProperty(irmFactory.isValidDeployment(IEVault(vault).interestRateModel()), ERROR__INTEREST_RATE_MODEL);

        {
            // cluster vaults must not have a hook target nor any operations disabled
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), ERROR__HOOK_TARGET);
            testProperty(hookedOps == 0, ERROR__HOOKED_OPS);
        }

        // cluster vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, ERROR__CONFIG_FLAGS);

        // cluster vaults must have certain liquidation cool off time
        testProperty(IEVault(vault).liquidationCoolOffTime() == 1, ERROR__LIQUIDATION_COOL_OFF_TIME);

        // cluster vaults must point to an ungoverned EulerRouter instance deployed by the factory
        address oracle = IEVault(vault).oracle();
        testProperty(routerFactory.isValidDeployment(oracle), ERROR__ORACLE_INVALID_ROUTER);
        testProperty(IEulerRouter(oracle).governor() == address(0), ERROR__ORACLE_GOVERNED_ROUTER);
        testProperty(IEulerRouter(oracle).fallbackOracle() == address(0), ERROR__ORACLE_INVALID_FALLBACK);

        // Verify the unit of account is either USD or WETH
        address unitOfAccount = IEVault(vault).unitOfAccount();
        testProperty(unitOfAccount == USD || unitOfAccount == WETH, ERROR__UNIT_OF_ACCOUNT);

        // Verify the full pricing configuration for asset/unitOfAccount in the router.
        verifyAssetPricing(oracle, IEVault(vault).asset(), unitOfAccount);

        // cluster vaults must have collaterals set up
        address[] memory ltvList = IEVault(vault).LTVList();
        testProperty(ltvList.length > 0 && ltvList.length <= 10, ERROR__LTV_COLLATERAL_CONFIG_LENGTH);

        // cluster vaults must have recognized collaterals
        for (uint256 i = 0; i < ltvList.length; ++i) {
            address collateral = ltvList[i];

            // Verify the full pricing configuration for collateral/unitOfAccount in the router.
            verifyCollateralPricing(oracle, collateral, unitOfAccount);

            // cluster vaults must have liquidation discount in a certain range
            uint16 maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
            testProperty(
                maxLiquidationDiscount >= 0.05e4 && maxLiquidationDiscount <= 0.2e4, ERROR__LIQUIDATION_DISCOUNT
            );

            // cluster vaults collaterals must have the LTVs set in range with LTV separation provided
            (uint16 borrowLTV, uint16 liquidationLTV,,, uint32 rampDuration) = IEVault(vault).LTVFull(collateral);
            testProperty(borrowLTV != liquidationLTV, ERROR__LTV_COLLATERAL_CONFIG_SEPARATION);
            testProperty(borrowLTV > 0 && borrowLTV <= 0.85e4, ERROR__LTV_COLLATERAL_CONFIG_BORROW);
            testProperty(liquidationLTV > 0 && liquidationLTV <= 0.9e4, ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION);
            testProperty(rampDuration == 0, ERROR__LTV_COLLATERAL_RAMPING);

            // iterate over recognized collateral perspectives to check if the collateral is recognized
            bool recognized = false;
            for (uint256 j = 0; j < recognizedCollateralPerspectives.length; ++j) {
                address perspective = recognizedCollateralPerspectives[j] == address(0)
                    ? address(this)
                    : recognizedCollateralPerspectives[j];

                if (BasePerspective(perspective).isVerified(collateral)) {
                    recognized = true;
                    break;
                }
            }

            if (!recognized) {
                for (uint256 j = 0; j < recognizedCollateralPerspectives.length; ++j) {
                    address perspective = recognizedCollateralPerspectives[j] == address(0)
                        ? address(this)
                        : recognizedCollateralPerspectives[j];

                    try BasePerspective(perspective).perspectiveVerify(collateral, true) {
                        recognized = true;
                    } catch {}

                    if (recognized) break;
                }
            }

            testProperty(recognized, ERROR__LTV_COLLATERAL_RECOGNITION);
        }
    }

    /// @notice Validate the EulerRouter configuration of a collateral vault.
    /// @dev `vault` must be configured as a resolved vault and `verifyAssetPricing` must pass for its asset.
    function verifyCollateralPricing(address router, address vault, address unitOfAccount) internal {
        // The vault must have been configured in the router.
        address resolvedAsset = IEulerRouter(router).resolvedVaults(vault);
        testProperty(resolvedAsset == IEVault(vault).asset(), ERROR__ORACLE_INVALID_ROUTER_CONFIG);

        verifyAssetPricing(router, resolvedAsset, unitOfAccount);
    }

    /// @notice Validate the EulerRouter configuration of an asset.
    /// @dev Valid configurations:
    /// 1. `asset/unitOfAccount` has a configured adapter, valid in `adapterRegistry`.
    /// 2. `asset` is configured as a resolved vault, valid in `externalVaultRegistry`.
    /// IERC4626(asset).asset()/unitOfAccount` has a configured adapter, valid in `adapterRegistry`.
    /// The latter is done to accommodate ERC4626-based tokens e.g. sDai.
    function verifyAssetPricing(address router, address asset, address unitOfAccount) internal {
        // The asset must be either unresolved or a valid external vault.
        address unwrappedAsset = IEulerRouter(router).resolvedVaults(asset);
        if (unwrappedAsset != address(0)) {
            testProperty(
                externalVaultRegistry.isValid(unwrappedAsset, block.timestamp), ERROR__ORACLE_INVALID_ROUTER_CONFIG
            );
        }

        // The final adapter must be valid according to the registry.
        address adapter = IEulerRouter(router).getConfiguredOracle(
            unwrappedAsset == address(0) ? asset : unwrappedAsset, unitOfAccount
        );
        testProperty(adapterRegistry.isValid(adapter, block.timestamp), ERROR__ORACLE_INVALID_ADAPTER);
    }
}
