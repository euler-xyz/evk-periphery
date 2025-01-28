// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerRouterFactory} from "../src/EulerRouterFactory/EulerRouterFactory.sol";
import {SnapshotRegistry} from "../src/SnapshotRegistry/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";

contract PeripheryFactories is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory,
            address adaptiveCurveIRMFactory,
            address irmRegistry
        )
    {
        string memory inputScriptFileName = "02_PeripheryFactories_input.json";
        string memory outputScriptFileName = "02_PeripheryFactories_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        (
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            adaptiveCurveIRMFactory,
            irmRegistry
        ) = execute(evc);

        string memory object;
        object = vm.serializeAddress("peripheryFactories", "oracleRouterFactory", oracleRouterFactory);
        object = vm.serializeAddress("peripheryFactories", "oracleAdapterRegistry", oracleAdapterRegistry);
        object = vm.serializeAddress("peripheryFactories", "externalVaultRegistry", externalVaultRegistry);
        object = vm.serializeAddress("peripheryFactories", "kinkIRMFactory", kinkIRMFactory);
        object = vm.serializeAddress("peripheryFactories", "adaptiveCurveIRMFactory", adaptiveCurveIRMFactory);
        object = vm.serializeAddress("peripheryFactories", "irmRegistry", irmRegistry);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc)
        public
        broadcast
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory,
            address adaptiveCurveIRMFactory,
            address irmRegistry
        )
    {
        (
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            adaptiveCurveIRMFactory,
            irmRegistry
        ) = execute(evc);
    }

    function execute(address evc)
        public
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory,
            address adaptiveCurveIRMFactory,
            address irmRegistry
        )
    {
        oracleRouterFactory = address(new EulerRouterFactory(evc));
        oracleAdapterRegistry = address(new SnapshotRegistry(evc, getDeployer()));
        externalVaultRegistry = address(new SnapshotRegistry(evc, getDeployer()));
        kinkIRMFactory = address(new EulerKinkIRMFactory());
        adaptiveCurveIRMFactory = address(new EulerIRMAdaptiveCurveFactory());
        irmRegistry = address(new SnapshotRegistry(evc, getDeployer()));
    }
}
