// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerRouterFactory} from "../src/EulerRouterFactory/EulerRouterFactory.sol";
import {SnapshotRegistry} from "../src/SnapshotRegistry/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";
import {GovernorAccessControlEmergencyFactory} from "../src/GovernorFactory/GovernorAccessControlEmergencyFactory.sol";

contract PeripheryFactories is ScriptUtils {
    struct PeripheryContracts {
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address adaptiveCurveIRMFactory;
        address irmRegistry;
        address governorAccessControlEmergencyFactory;
    }

    function run() public broadcast returns (PeripheryContracts memory deployedContracts) {
        string memory inputScriptFileName = "02_PeripheryFactories_input.json";
        string memory outputScriptFileName = "02_PeripheryFactories_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        deployedContracts = execute(evc);

        string memory object;
        object = vm.serializeAddress("peripheryFactories", "oracleRouterFactory", deployedContracts.oracleRouterFactory);
        object =
            vm.serializeAddress("peripheryFactories", "oracleAdapterRegistry", deployedContracts.oracleAdapterRegistry);
        object =
            vm.serializeAddress("peripheryFactories", "externalVaultRegistry", deployedContracts.externalVaultRegistry);
        object = vm.serializeAddress("peripheryFactories", "kinkIRMFactory", deployedContracts.kinkIRMFactory);
        object = vm.serializeAddress(
            "peripheryFactories", "adaptiveCurveIRMFactory", deployedContracts.adaptiveCurveIRMFactory
        );
        object = vm.serializeAddress("peripheryFactories", "irmRegistry", deployedContracts.irmRegistry);
        object = vm.serializeAddress(
            "peripheryFactories",
            "governorAccessControlEmergencyFactory",
            deployedContracts.governorAccessControlEmergencyFactory
        );
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc) public broadcast returns (PeripheryContracts memory deployedContracts) {
        deployedContracts = execute(evc);
    }

    function execute(address evc) public returns (PeripheryContracts memory deployedContracts) {
        deployedContracts = PeripheryContracts({
            oracleRouterFactory: address(new EulerRouterFactory(evc)),
            oracleAdapterRegistry: address(new SnapshotRegistry(evc, getDeployer())),
            externalVaultRegistry: address(new SnapshotRegistry(evc, getDeployer())),
            kinkIRMFactory: address(new EulerKinkIRMFactory()),
            adaptiveCurveIRMFactory: address(new EulerIRMAdaptiveCurveFactory()),
            irmRegistry: address(new SnapshotRegistry(evc, getDeployer())),
            governorAccessControlEmergencyFactory: address(new GovernorAccessControlEmergencyFactory(evc))
        });
    }
}
