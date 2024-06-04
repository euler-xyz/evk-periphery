// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {IEulerRouter} from "../../../../OracleFactory/interfaces/IEulerRouter.sol";
import {IEulerRouterFactory} from "../../../../OracleFactory/interfaces/IEulerRouterFactory.sol";
import {AdapterRegistry} from "../../../../OracleFactory/AdapterRegistry.sol";
import {EulerKinkIRMFactory} from "../../../../IRMFactory/EulerKinkIRMFactory.sol";
import {BasePerspective} from "../../../BasePerspective.sol";

contract ClusterConservativeWithRecognizedCollateralsPerspective is BasePerspective {
    address[] public recognizedCollateralPerspectives;
    address internal constant USD = address(840);
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IEulerRouterFactory internal immutable routerFactory;
    AdapterRegistry internal immutable adapterRegistry;
    EulerKinkIRMFactory internal immutable irmFactory;

    constructor(
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address irmFactory_,
        address[] memory recognizedCollateralPerspectives_
    ) BasePerspective(vaultFactory_) {
        routerFactory = IEulerRouterFactory(routerFactory_);
        adapterRegistry = AdapterRegistry(adapterRegistry_);
        irmFactory = EulerKinkIRMFactory(irmFactory_);
        recognizedCollateralPerspectives = recognizedCollateralPerspectives_;
    }

    function name() public pure virtual override returns (string memory) {
        return "Immutable.Ungoverned.ClusterConservativeWithRecognizedCollateralsPerspective";
    }

    function perspectiveVerifyInternal(address vault, bool failEarly) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), vault, ERROR__FACTORY, failEarly);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        // cluster vaults must not be upgradeable
        testProperty(!config.upgradeable, vault, ERROR__UPGRADABILITY, failEarly);

        // verify vault configuration at the governance level
        // cluster vaults must not have a governor admin
        testProperty(IEVault(vault).governorAdmin() == address(0), vault, ERROR__GOVERNOR, failEarly);

        // cluster vaults must have an interest fee in a certain range. lower bound is enforced by the vault itself
        testProperty(IEVault(vault).interestFee() <= 0.5e4, vault, ERROR__INTEREST_FEE, failEarly);

        // cluster vaults must point to a Kink IRM instance deployed by the factory
        testProperty(
            irmFactory.isValidDeployment(IEVault(vault).interestRateModel()),
            vault,
            ERROR__INTEREST_RATE_MODEL,
            failEarly
        );

        {
            // cluster vaults must not have supply or borrow caps
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
            testProperty(supplyCap == 0, vault, ERROR__SUPPLY_CAP, failEarly);
            testProperty(borrowCap == 0, vault, ERROR__BORROW_CAP, failEarly);

            // cluster vaults must not have a hook target nor any operations disabled
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), vault, ERROR__HOOK_TARGET, failEarly);
            testProperty(hookedOps == 0, vault, ERROR__HOOKED_OPS, failEarly);
        }

        // cluster vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, vault, ERROR__CONFIG_FLAGS, failEarly);

        // cluster vaults must have certain liquidation cool off time
        testProperty(IEVault(vault).liquidationCoolOffTime() == 1, vault, ERROR__LIQUIDATION_COOL_OFF_TIME, failEarly);

        // cluster vaults must point to an ungoverned EulerRouter instance deployed by the factory
        address oracle = IEVault(vault).oracle();
        testProperty(routerFactory.isValidDeployment(oracle), vault, ERROR__ORACLE, failEarly);
        testProperty(IEulerRouter(oracle).governor() == address(0), vault, ERROR__ORACLE, failEarly);

        // Verify the unit of account is either USD or WETH
        address unitOfAccount = IEVault(vault).unitOfAccount();
        testProperty(
            unitOfAccount == USD || unitOfAccount == ETH || unitOfAccount == WETH,
            vault,
            ERROR__UNIT_OF_ACCOUNT,
            failEarly
        );

        // the router must contain a valid pricing configuration
        address fallbackOracle = IEulerRouter(oracle).fallbackOracle();
        {
            testProperty(
                fallbackOracle == address(0) || routerFactory.isValidDeployment(fallbackOracle),
                vault,
                ERROR__ORACLE,
                failEarly
            );
            (,,, address resolvedOracle) = IEulerRouter(oracle).resolveOracle(1e18, vault, unitOfAccount);
            testProperty(
                (fallbackOracle != address(0) && resolvedOracle == fallbackOracle)
                    || adapterRegistry.isValidAdapter(resolvedOracle, block.timestamp),
                vault,
                ERROR__ORACLE_ASSET,
                failEarly
            );
        }

        // cluster vaults must have collaterals set up
        address[] memory ltvList = IEVault(vault).LTVList();
        testProperty(ltvList.length > 0 && ltvList.length <= 10, vault, ERROR__LTV_LENGTH, failEarly);

        // cluster vaults must have recognized collaterals with LTV set in range
        for (uint256 i = 0; i < ltvList.length; ++i) {
            address collateral = ltvList[i];
            {
                (,,, address resolvedOracle) = IEulerRouter(oracle).resolveOracle(1e18, vault, unitOfAccount);
                testProperty(
                    (fallbackOracle != address(0) && resolvedOracle == fallbackOracle)
                        || adapterRegistry.isValidAdapter(resolvedOracle, block.timestamp),
                    vault,
                    ERROR__ORACLE_COLLATERAL,
                    failEarly
                );
            }

            // cluster vaults must have liquidation discount in a certain range
            uint16 maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
            testProperty(
                maxLiquidationDiscount >= 0.05e4 && maxLiquidationDiscount <= 0.2e4,
                vault,
                ERROR__LIQUIDATION_DISCOUNT,
                failEarly
            );

            // cluster vaults collaterals must have the LTVs set in range with LTV separation provided
            (uint16 borrowLTV, uint16 liquidationLTV,,,) = IEVault(vault).LTVFull(collateral);
            testProperty(borrowLTV != liquidationLTV, vault, ERROR__LTV_CONFIG, failEarly);
            testProperty(borrowLTV > 0 && borrowLTV <= 0.85e4, vault, ERROR__LTV_CONFIG, failEarly);
            testProperty(liquidationLTV > 0 && liquidationLTV <= 0.9e4, vault, ERROR__LTV_CONFIG, failEarly);

            // iterate over recognized collateral perspectives to check if the collateral is recognized
            bool recognized = false;
            for (uint256 j = 0; j < recognizedCollateralPerspectives.length; ++j) {
                address perspective = recognizedCollateralPerspectives[j] == address(0)
                    ? address(this)
                    : recognizedCollateralPerspectives[j];

                try BasePerspective(perspective).perspectiveVerify(collateral, true) {
                    recognized = true;
                } catch {}

                if (recognized) break;
            }

            testProperty(recognized, vault, ERROR__LTV_COLLATERAL_RECOGNITION, failEarly);
        }
    }
}
