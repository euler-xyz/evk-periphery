// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseMegaCluster} from "./BaseMegaCluster.s.sol";
import {KinkIRM} from "../../../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer, EulerRouter} from "../../../07_EVault.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract StubPriceOracle {
    string public name = "StubPriceOracle";

    function getQuote(uint256, address, address) external pure returns (uint256) {
        return 1;
    }

    function getQuotes(uint256, address, address) external pure returns (uint256, uint256) {
        return (1, 1);
    }
}

contract MaintainMegaCluster is BaseMegaCluster {
    function run() public {
        setUp();

        // deploy the oracle router
        if (cluster.oracleRouter == address(0)) {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            cluster.oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);
        }

        // deploy the vaults
        if (cluster.vaults.length == 0) {
            EVaultDeployer deployer = new EVaultDeployer();
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                cluster.vaults.push(
                    deployer.deploy(coreAddresses.eVaultFactory, true, cluster.assets[i], cluster.oracleRouter, USD)
                );
            }
        }

        // deploy the IRMs
        {
            KinkIRM deployer = new KinkIRM();
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                uint256[4] storage p = cluster.kinkIRMParams[cluster.assets[i]];
                address irm = cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]];

                if (irm == address(0) && (p[0] != 0 || p[1] != 0 || p[2] != 0 || p[3] != 0)) {
                    irm = deployer.deploy(peripheryAddresses.kinkIRMFactory, p[0], p[1], p[2], uint32(p[3]));
                    cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]] = irm;
                }

                if (cluster.assets.length == cluster.irms.length) {
                    cluster.irms[i] = irm;
                } else {
                    cluster.irms.push(irm);
                }
            }
        }

        // configure the oracle router
        startBroadcast();
        address placeholderOracle = address(new StubPriceOracle());
        stopBroadcast();

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            address vault = cluster.vaults[i];

            if (EulerRouter(cluster.oracleRouter).resolvedVaults(vault) == address(0)) {
                govSetResolvedVault(cluster.oracleRouter, vault, true);
            }
        }

        for (uint256 i = 0; i < cluster.assets.length; ++i) {
            address asset = cluster.assets[i];
            address adapter = getValidAdapter(asset, USD, cluster.oracleProviders[asset]);

            if (adapter == address(0)) {
                adapter = placeholderOracle;
            }

            if (EulerRouter(cluster.oracleRouter).getConfiguredOracle(asset, USD) != adapter) {
                govSetConfig(cluster.oracleRouter, asset, USD, adapter);
            }
        }

        if (EulerRouter(cluster.oracleRouter).governor() != ORACLE_ROUTER_GOVERNOR) {
            transferGovernance(cluster.oracleRouter, ORACLE_ROUTER_GOVERNOR);
        }

        // configure the vaults
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            address vault = cluster.vaults[i];

            if (IEVault(vault).maxLiquidationDiscount() != 0.15e4) {
                setMaxLiquidationDiscount(vault, 0.15e4);
            }

            if (IEVault(vault).liquidationCoolOffTime() != 1) {
                setLiquidationCoolOffTime(vault, 1);
            }
            
            (uint16 supplyCap, uint16 borrowCap) = IEVault(vault).caps();
            if (supplyCap != cluster.supplyCaps[i]) {
                setCaps(vault, cluster.supplyCaps[i], borrowCap);
            }

            if (IEVault(vault).interestRateModel() != cluster.irms[i]) {
                setInterestRateModel(vault, cluster.irms[i]);
            }

            for (uint256 j = 0; j < cluster.vaults.length; ++j) {
                address collateral = cluster.vaults[j];
                uint16 liquidationLTV = cluster.ltvs[j][i];
                uint16 borrowLTV = liquidationLTV > 0.02e4 ? liquidationLTV - 0.02e4 : 0;
                uint16 currentBorrowLTV = IEVault(vault).LTVBorrow(collateral);
                uint16 currentLiquidationLTV = IEVault(vault).LTVLiquidation(collateral);
    
                if (currentBorrowLTV != borrowLTV || currentLiquidationLTV != liquidationLTV) {
                    setLTV(vault, collateral, borrowLTV, liquidationLTV, liquidationLTV >= currentLiquidationLTV ? 0 : 1 days);
                }
            }
        }

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            address vault = cluster.vaults[i];

            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            if (hookTarget != address(0) || hookedOps != 0) {
                setHookConfig(vault, address(0), 0);
            }

            if (IEVault(vault).governorAdmin() != VAULTS_GOVERNOR) {
                setGovernorAdmin(vault, VAULTS_GOVERNOR);
            }
        }

        executeBatch();

        // sanity check the configuration
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(cluster.vaults[i]);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngoverned0xPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | 
                PerspectiveVerifier.E__GOVERNOR | 
                PerspectiveVerifier.E__LTV_COLLATERAL_RECOGNITION |
                PerspectiveVerifier.E__HOOKED_OPS |
                PerspectiveVerifier.E__ORACLE_INVALID_ADAPTER
            );
        }

        vm.writeJson(dumpClusterAddresses(cluster), getInputConfigFilePath("ClusterAddresses.json"));
    }
}
