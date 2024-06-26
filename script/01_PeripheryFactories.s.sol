// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerRouterFactory} from "../src/OracleFactory/EulerRouterFactory.sol";
import {SnapshotRegistry} from "../src/OracleFactory/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";

contract PeripheryFactories is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory
        )
    {
        string memory scriptFileName = "01_PeripheryFactories.json";

        (oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory) = execute();

        string memory object;
        object = vm.serializeAddress("peripheryFactories", "oracleRouterFactory", oracleRouterFactory);
        object = vm.serializeAddress("peripheryFactories", "oracleAdapterRegistry", oracleAdapterRegistry);
        object = vm.serializeAddress("peripheryFactories", "externalVaultRegistry", externalVaultRegistry);
        object = vm.serializeAddress("peripheryFactories", "kinkIRMFactory", kinkIRMFactory);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy()
        public
        broadcast
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory
        )
    {
        (oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory) = execute();
    }

    function execute()
        public
        returns (
            address oracleRouterFactory,
            address oracleAdapterRegistry,
            address externalVaultRegistry,
            address kinkIRMFactory
        )
    {
        oracleRouterFactory = address(new EulerRouterFactory());
        oracleAdapterRegistry = address(new SnapshotRegistry(getDeployer()));
        externalVaultRegistry = address(new SnapshotRegistry(getDeployer()));
        kinkIRMFactory = address(new EulerKinkIRMFactory());
    }
}
