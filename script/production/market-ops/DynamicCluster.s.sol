// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../ManageClusterBase.s.sol";
import {DynamicClusterInputLib} from "./DynamicClusterInput.s.sol";

contract DynamicCluster is ManageClusterBase {
    DynamicClusterInputLib.Input private input;
    bytes32 private inputHash;
    string private routeKind;

    function getDeployer() internal view override returns (address) {
        return input.deployer == address(0) ? vm.envAddress("MARKET_OPS_DEPLOYER") : input.deployer;
    }

    function defineCluster() internal override {
        string memory inputPath = vm.envString("MARKET_OPS_CLUSTER_INPUT");
        (input, inputHash) = DynamicClusterInputLib.read(vm, inputPath);

        require(input.chainId == block.chainid, "DynamicCluster: chain mismatch");
        require(input.blockNumber == block.number, "DynamicCluster: block mismatch");
        require(input.deployer == vm.envAddress("MARKET_OPS_DEPLOYER"), "DynamicCluster: deployer mismatch");
        routeKind = vm.envString("MARKET_OPS_ROUTE_KIND");
        _validateRoute();

        cluster.clusterAddressesPath = getScriptOutputFilePath("ClusterAddresses.json");
        cluster.clusterAddressesPathAbsolute = true;
        cluster.assets = input.assets;
        cluster.vaults = input.vaults;
        cluster.oracleRouters = input.oracleRouters;
        cluster.irmsArr = input.irms;
        cluster.externalVaults = input.externalVaults;
        cluster.stubOracle = input.stubOracle;
    }

    function configureCluster() internal override {
        setNoStubOracle(input.noStubOracle);
        cluster.oracleRoutersGovernor = input.oracleRoutersGovernor;
        cluster.vaultsGovernor = input.vaultsGovernor;
        cluster.unitOfAccount = input.unitOfAccount;
        cluster.feeReceiver = input.feeReceiver;
        cluster.interestFee = input.interestFee;
        cluster.maxLiquidationDiscount = input.maxLiquidationDiscount;
        cluster.liquidationCoolOffTime = input.liquidationCoolOffTime;
        cluster.hookTarget = input.hookTarget;
        cluster.hookedOps = input.hookedOps;
        cluster.configFlags = input.configFlags;
        cluster.forceZeroGovernors = input.forceZeroGovernors;
        cluster.rampDuration = input.rampDuration;
        cluster.spreadLTV = input.spreadLTV;
        cluster.ltvs = input.ltvs;
        cluster.borrowLTVsOverride = input.borrowLTVsOverride;
        cluster.spreadLTVOverride = input.spreadLTVOverride;
        cluster.externalLTVs = input.externalLTVs;
        cluster.externalBorrowLTVsOverride = input.externalBorrowLTVsOverride;
        cluster.externalSpreadLTVsOverride = input.externalSpreadLTVsOverride;

        for (uint256 i = 0; i < input.oracleProviderBases.length; ++i) {
            cluster.oracleProviders[input.oracleProviderBases[i]] = input.oracleProviders[i];
        }

        for (uint256 i = 0; i < input.assets.length; ++i) {
            address asset = input.assets[i];
            cluster.supplyCaps[asset] = input.supplyCaps[i];
            cluster.borrowCaps[asset] = input.borrowCaps[i];
            cluster.feeReceiverOverride[asset] = input.feeReceiverOverrides[i];
            cluster.interestFeeOverride[asset] = input.interestFeeOverrides[i];
            cluster.maxLiquidationDiscountOverride[asset] = input.maxLiquidationDiscountOverrides[i];
            cluster.liquidationCoolOffTimeOverride[asset] = input.liquidationCoolOffTimeOverrides[i];
            cluster.hookTargetOverride[asset] = input.hookTargetOverrides[i];
            cluster.hookedOpsOverride[asset] = input.hookedOpsOverrides[i];
            cluster.configFlagsOverride[asset] = input.configFlagsOverrides[i];
            cluster.kinkIRMParams[asset] = input.kinkIRMParams[i];
            cluster.irms[asset] = input.irms[i];
        }
    }

    function postOperations() internal override {
        bytes32 batchesHash =
            keccak256(bytes(vm.readFile(getScriptOutputFilePath("Batches.json"))));
        bytes32 clusterHash =
            keccak256(bytes(vm.readFile(getScriptOutputFilePath("Cluster.json"))));
        string memory manifest;
        manifest = vm.serializeString("marketOps", "schema", DynamicClusterInputLib.SCHEMA);
        manifest = vm.serializeString("marketOps", "requestHash", input.requestHash);
        manifest = vm.serializeBytes32("marketOps", "inputHash", inputHash);
        manifest = vm.serializeBytes32("marketOps", "batchesHash", batchesHash);
        manifest = vm.serializeBytes32("marketOps", "clusterHash", clusterHash);
        manifest = vm.serializeString("marketOps", "sourceCommit", input.sourceCommit);
        manifest = vm.serializeUint("marketOps", "chainId", input.chainId);
        manifest = vm.serializeUint("marketOps", "blockNumber", input.blockNumber);
        manifest = vm.serializeBytes32("marketOps", "blockHash", input.blockHash);
        manifest = vm.serializeAddress("marketOps", "deployer", input.deployer);
        manifest = vm.serializeString("marketOps", "routeKind", routeKind);
        manifest = vm.serializeAddress("marketOps", "safe", getSafe(false));
        manifest = vm.serializeUint("marketOps", "safeNonce", safeNonce);
        manifest = vm.serializeAddress("marketOps", "timelock", getTimelock());
        manifest = vm.serializeAddress("marketOps", "riskSteward", getRiskSteward());
        manifest = vm.serializeBool("marketOps", "emergency", isEmergency());
        manifest = vm.serializeBool("marketOps", "broadcast", isBroadcast());
        vm.writeJson(manifest, getScriptOutputFilePath("MarketOpsManifest.json"));
    }

    function _validateRoute() private view {
        validateRouteConfig(
            routeKind,
            isBatchViaSafe(),
            getSafe(false),
            getTimelock(),
            getRiskSteward(),
            isEmergency()
        );
    }

    function validateRouteConfig(
        string memory kind,
        bool viaSafe,
        address safe,
        address timelock,
        address riskSteward,
        bool emergency
    ) internal pure {
        if (_strEq(kind, "deployer-direct") || _strEq(kind, "direct")) {
            require(!viaSafe && safe == address(0) && timelock == address(0) && riskSteward == address(0) && !emergency, "DynamicCluster: direct route");
        } else if (_strEq(kind, "safe")) {
            require(viaSafe && safe != address(0) && timelock == address(0) && riskSteward == address(0) && !emergency, "DynamicCluster: safe route");
        } else if (_strEq(kind, "safe-timelock")) {
            require(viaSafe && safe != address(0) && timelock != address(0) && safe != timelock && riskSteward == address(0) && !emergency, "DynamicCluster: safe timelock route");
        } else if (_strEq(kind, "timelock")) {
            require(!viaSafe && safe == address(0) && timelock != address(0) && riskSteward == address(0) && !emergency, "DynamicCluster: timelock route");
        } else if (_strEq(kind, "risk-steward")) {
            require(riskSteward != address(0) && (viaSafe == (safe != address(0))) && !emergency, "DynamicCluster: risk steward route");
        } else if (_strEq(kind, "emergency")) {
            require((viaSafe == (safe != address(0))) && emergency, "DynamicCluster: emergency route");
        } else {
            revert("DynamicCluster: unsupported route");
        }
    }
}
