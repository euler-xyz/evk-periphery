// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {EscrowSingletonPerspective} from "../src/Perspectives/deployed/EscrowSingletonPerspective.sol";
import {EulerDefaultClusterPerspective} from "../src/Perspectives/deployed/EulerDefaultClusterPerspective.sol";
import {EulerFactoryPerspective} from "../src/Perspectives/deployed/EulerFactoryPerspective.sol";

contract Perspectives is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address escrowSingletonPerspective,
            address eulerDefaultClusterPerspective,
            address eulerFactoryPespective
        )
    {
        string memory scriptFileName = "09_Perspectives.json";
        string memory json = getInputConfig(scriptFileName);
        address eVaultFactory = abi.decode(vm.parseJson(json, ".eVaultFactory"), (address));
        address oracleRouterFactory = abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address));
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));
        address externalVaultRegistry = abi.decode(vm.parseJson(json, ".externalVaultRegistry"), (address));
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));

        (escrowSingletonPerspective, eulerDefaultClusterPerspective, eulerFactoryPespective) =
            execute(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory);

        string memory object;
        object = vm.serializeAddress("perspectives", "escrowSingletonPerspective", escrowSingletonPerspective);
        object = vm.serializeAddress("perspectives", "eulerDefaultClusterPerspective", eulerDefaultClusterPerspective);
        object = vm.serializeAddress("perspectives", "eulerFactoryPespective", eulerFactoryPespective);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory
    )
        public
        broadcast
        returns (
            address escrowSingletonPerspective,
            address eulerDefaultClusterPerspective,
            address eulerFactoryPespective
        )
    {
        (escrowSingletonPerspective, eulerDefaultClusterPerspective, eulerFactoryPespective) =
            execute(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory);
    }

    function execute(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory
    )
        public
        returns (
            address escrowSingletonPerspective,
            address eulerDefaultClusterPerspective,
            address eulerFactoryPespective
        )
    {
        escrowSingletonPerspective = address(new EscrowSingletonPerspective(eVaultFactory));
        eulerDefaultClusterPerspective = address(
            new EulerDefaultClusterPerspective(
                eVaultFactory,
                oracleRouterFactory,
                oracleAdapterRegistry,
                externalVaultRegistry,
                kinkIRMFactory,
                escrowSingletonPerspective
            )
        );
        eulerFactoryPespective = address(new EulerFactoryPerspective(eVaultFactory));
    }
}
