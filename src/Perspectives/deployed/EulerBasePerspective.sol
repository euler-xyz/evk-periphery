// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {IEulerRouterFactory} from "../../EulerRouterFactory/interfaces/IEulerRouterFactory.sol";
import {IEulerKinkIRMFactory} from "../../IRMFactory/interfaces/IEulerKinkIRMFactory.sol";
import {SnapshotRegistry} from "../../SnapshotRegistry/SnapshotRegistry.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title EulerBasePerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault has the properties of a base vault. It allows collaterals to be
/// recognized by any of the specified perspectives.
contract EulerBasePerspective is BasePerspective {
    address[] public recognizedCollateralPerspectives;
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IEulerRouterFactory internal immutable routerFactory;
    SnapshotRegistry internal immutable adapterRegistry;
    SnapshotRegistry internal immutable externalVaultRegistry;
    SnapshotRegistry internal immutable irmRegistry;
    IEulerKinkIRMFactory internal immutable irmFactory;

    /// @notice Creates a new EulerBasePerspective instance.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    /// @param routerFactory_ The address of the EulerRouterFactory contract.
    /// @param adapterRegistry_ The address of the adapter registry contract.
    /// @param externalVaultRegistry_ The address of the external vault registry contract.
    /// @param irmFactory_ The address of the EulerKinkIRMFactory contract.
    /// @param irmRegistry_ The address of an additional IRM registry contract.
    /// @param recognizedCollateralPerspectives_ The addresses of the recognized collateral perspectives. address(0) for
    /// self.
    constructor(
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address externalVaultRegistry_,
        address irmFactory_,
        address irmRegistry_,
        address[] memory recognizedCollateralPerspectives_
    ) BasePerspective(vaultFactory_) {
        routerFactory = IEulerRouterFactory(routerFactory_);
        adapterRegistry = SnapshotRegistry(adapterRegistry_);
        externalVaultRegistry = SnapshotRegistry(externalVaultRegistry_);
        irmFactory = IEulerKinkIRMFactory(irmFactory_);
        irmRegistry = SnapshotRegistry(irmRegistry_);
        recognizedCollateralPerspectives = recognizedCollateralPerspectives_;
    }

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Euler Base Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address vault) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), ERROR__FACTORY);

        // escrow vaults must be upgradeable
        testProperty(vaultFactory.getProxyConfig(vault).upgradeable, ERROR__UPGRADABILITY);

        // base vaults must not be nested
        address asset = IEVault(vault).asset();
        testProperty(!vaultFactory.isProxy(asset), ERROR__NESTING);

        // verify vault configuration at the governance level
        // base vaults must not have a governor admin
        testProperty(IEVault(vault).governorAdmin() == address(0), ERROR__GOVERNOR);

        // base vaults must have an interest fee in a certain range. lower bound is enforced by the vault itself
        testProperty(IEVault(vault).interestFee() <= 0.5e4, ERROR__INTEREST_FEE);

        // base vaults must point to a Kink IRM instance deployed by the factory or be valid in `irmRegistry`
        address irm = IEVault(vault).interestRateModel();
        testProperty(
            irmFactory.isValidDeployment(irm) || irmRegistry.isValid(irm, block.timestamp), ERROR__INTEREST_RATE_MODEL
        );

        {
            // base vaults must not have a hook target nor any operations disabled
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), ERROR__HOOK_TARGET);
            testProperty(hookedOps == 0, ERROR__HOOKED_OPS);
        }

        // base vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, ERROR__CONFIG_FLAGS);

        // base vaults must have liquidation discount in a certain range
        uint16 maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
        testProperty(maxLiquidationDiscount >= 0.05e4 && maxLiquidationDiscount <= 0.2e4, ERROR__LIQUIDATION_DISCOUNT);

        // base vaults must have certain liquidation cool off time
        testProperty(IEVault(vault).liquidationCoolOffTime() == 1, ERROR__LIQUIDATION_COOL_OFF_TIME);

        // base vaults must point to an ungoverned EulerRouter instance deployed by the factory
        address oracle = IEVault(vault).oracle();
        testProperty(routerFactory.isValidDeployment(oracle), ERROR__ORACLE_INVALID_ROUTER);
        testProperty(EulerRouter(oracle).governor() == address(0), ERROR__ORACLE_GOVERNED_ROUTER);
        testProperty(EulerRouter(oracle).fallbackOracle() == address(0), ERROR__ORACLE_INVALID_FALLBACK);

        // Verify the unit of account is either USD or WETH
        address unitOfAccount = IEVault(vault).unitOfAccount();
        testProperty(unitOfAccount == USD || unitOfAccount == WETH, ERROR__UNIT_OF_ACCOUNT);

        // Verify the full pricing configuration for asset/unitOfAccount in the router.
        verifyAssetPricing(oracle, asset, unitOfAccount);

        // base vaults must have collaterals set up
        address[] memory ltvList = IEVault(vault).LTVList();
        uint256 ltvListLength = ltvList.length;
        testProperty(ltvListLength > 0 && ltvListLength <= 10, ERROR__LTV_COLLATERAL_CONFIG_LENGTH);

        // base vaults must have recognized collaterals
        for (uint256 i = 0; i < ltvListLength; ++i) {
            address collateral = ltvList[i];

            // Verify the full pricing configuration for collateral/unitOfAccount in the router.
            verifyCollateralPricing(oracle, collateral, unitOfAccount);

            // base vaults collaterals must have the LTVs set in range with LTV separation provided
            (uint16 borrowLTV, uint16 liquidationLTV,, uint48 targetTimestamp, uint32 rampDuration) =
                IEVault(vault).LTVFull(collateral);
            testProperty(liquidationLTV - borrowLTV >= 0.01e4, ERROR__LTV_COLLATERAL_CONFIG_SEPARATION);
            testProperty(borrowLTV > 0 && borrowLTV <= 0.98e4, ERROR__LTV_COLLATERAL_CONFIG_BORROW);
            testProperty(liquidationLTV > 0 && liquidationLTV <= 0.98e4, ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION);
            testProperty(rampDuration == 0 || targetTimestamp <= block.timestamp, ERROR__LTV_COLLATERAL_RAMPING);

            // iterate over recognized collateral perspectives to check if the collateral is recognized
            bool recognized = false;
            uint256 recognizedCollateralPerspectivesLength = recognizedCollateralPerspectives.length;
            for (uint256 j = 0; j < recognizedCollateralPerspectivesLength; ++j) {
                address perspective = resolveRecognizedPerspective(recognizedCollateralPerspectives[j]);

                if (BasePerspective(perspective).isVerified(collateral)) {
                    recognized = true;
                    break;
                }
            }

            if (!recognized) {
                for (uint256 j = 0; j < recognizedCollateralPerspectivesLength; ++j) {
                    address perspective = resolveRecognizedPerspective(recognizedCollateralPerspectives[j]);

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
    /// @param router The EulerRouter instance.
    /// @param vault The collateral vault to verify.
    /// @param unitOfAccount The unit of account of the liability vault.
    /// @dev `vault` must be configured as a resolved vault and `verifyAssetPricing` must pass for its asset.
    function verifyCollateralPricing(address router, address vault, address unitOfAccount) internal {
        // The vault must have been configured in the router.
        address resolvedAsset = EulerRouter(router).resolvedVaults(vault);
        testProperty(resolvedAsset == IEVault(vault).asset(), ERROR__ORACLE_INVALID_ROUTER_CONFIG);

        // There must not be a short-circuiting adapter.
        testProperty(
            EulerRouter(router).getConfiguredOracle(vault, unitOfAccount) == address(0),
            ERROR__ORACLE_INVALID_ROUTER_CONFIG
        );

        verifyAssetPricing(router, resolvedAsset, unitOfAccount);
    }

    /// @notice Validate the EulerRouter configuration of an asset.
    /// @param router The EulerRouter instance.
    /// @param asset The vault asset to verify.
    /// @param unitOfAccount The unit of account of the liability vault.
    /// @dev Valid configurations:
    /// 1. `asset/unitOfAccount` has a configured adapter, valid in `adapterRegistry`.
    /// 2. `asset` is configured as a resolved vault, valid in `externalVaultRegistry`.
    /// `IERC4626(asset).asset()/unitOfAccount` has a configured adapter, valid in `adapterRegistry`.
    /// The latter is done to accommodate ERC4626-based tokens e.g. sDai.
    function verifyAssetPricing(address router, address asset, address unitOfAccount) internal {
        // The asset must be either unresolved or a valid external vault.
        address unwrappedAsset = EulerRouter(router).resolvedVaults(asset);
        if (unwrappedAsset != address(0)) {
            // The asset is itself an ERC4626 resolved vault. Perform a sanity check against `IERC4626.asset()`.
            testProperty(IERC4626(asset).asset() == unwrappedAsset, ERROR__ORACLE_INVALID_ROUTER_CONFIG);

            // Verify that this vault valid in `externalVaultRegistry`.
            testProperty(externalVaultRegistry.isValid(asset, block.timestamp), ERROR__ORACLE_INVALID_ROUTER_CONFIG);

            // Additionally, there must not be a short-circuiting adapter.
            testProperty(
                EulerRouter(router).getConfiguredOracle(asset, unitOfAccount) == address(0),
                ERROR__ORACLE_INVALID_ROUTER_CONFIG
            );
        }

        // Ignore the case where the underlying asset matches `unitOfAccount`, as the router handles that without
        // calling an adapter.
        address base = unwrappedAsset == address(0) ? asset : unwrappedAsset;
        if (base != unitOfAccount) {
            // The final adapter must be valid according to the registry.
            address adapter = EulerRouter(router).getConfiguredOracle(base, unitOfAccount);
            testProperty(adapterRegistry.isValid(adapter, block.timestamp), ERROR__ORACLE_INVALID_ADAPTER);
        }
    }

    /// @notice Resolves the recognized perspective address.
    /// @param perspective The input perspective address.
    /// @return The resolved perspective address. If the input is the zero address, returns the current contract
    /// address.
    function resolveRecognizedPerspective(address perspective) internal view returns (address) {
        if (perspective == address(0)) {
            return address(this);
        }
        return perspective;
    }
}
