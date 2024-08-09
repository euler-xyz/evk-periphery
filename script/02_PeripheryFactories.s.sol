// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerRouterFactory} from "../src/EulerRouterFactory/EulerRouterFactory.sol";
import {SnapshotRegistry} from "../src/SnapshotRegistry/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";

contract PeripheryFactories is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory,
            address irmRegistry
        )
    {
        string memory inputScriptFileName = "02_PeripheryFactories_input.json";
        string memory outputScriptFileName = "02_PeripheryFactories_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address evc = abi.decode(vm.parseJson(json, ".evc"), (address));

        (oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory, irmRegistry) = execute(evc);

        string memory object;
        object = vm.serializeAddress("peripheryFactories", "oracleRouterFactory", oracleRouterFactory);
        object = vm.serializeAddress("peripheryFactories", "oracleAdapterRegistry", oracleAdapterRegistry);
        object = vm.serializeAddress("peripheryFactories", "externalVaultRegistry", externalVaultRegistry);
        object = vm.serializeAddress("peripheryFactories", "kinkIRMFactory", kinkIRMFactory);
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
            address irmRegistry
        )
    {
        (oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory, irmRegistry) = execute(evc);
    }

    function execute(address evc)
        public
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory,
            address irmRegistry
        )
    {
        oracleRouterFactory = address(new EulerRouterFactory(evc));
        oracleAdapterRegistry = address(new SnapshotRegistry(getDeployer()));
        externalVaultRegistry = address(new SnapshotRegistry(getDeployer()));
        kinkIRMFactory = address(new EulerKinkIRMFactory());
        irmRegistry = address(new SnapshotRegistry(getDeployer()));
    }
}
