// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {GovernableWhitelistPerspective} from "../src/Perspectives/deployed/GovernableWhitelistPerspective.sol";
import {EscrowPerspective} from "../src/Perspectives/deployed/EscrowPerspective.sol";
import {EulerBasePerspective} from "../src/Perspectives/deployed/EulerBasePerspective.sol";
import {EulerFactoryPerspective} from "../src/Perspectives/deployed/EulerFactoryPerspective.sol";

contract Perspectives is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address governableWhitelistPerspective,
            address escrowPerspective,
            address eulerBasePerspective,
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

        (governableWhitelistPerspective, escrowPerspective, eulerBasePerspective, eulerFactoryPespective) =
            execute(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, externalVaultRegistry, kinkIRMFactory);

        string memory object;
        object = vm.serializeAddress("perspectives", "governableWhitelistPerspective", governableWhitelistPerspective);
        object = vm.serializeAddress("perspectives", "escrowPerspective", escrowPerspective);
        object = vm.serializeAddress("perspectives", "eulerBasePerspective", eulerBasePerspective);
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
            address governableWhitelistPerspective,
            address escrowPerspective,
            address eulerBasePerspective,
            address eulerFactoryPespective
        )
    {
        (governableWhitelistPerspective, escrowPerspective, eulerBasePerspective, eulerFactoryPespective) =
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
            address governableWhitelistPerspective,
            address escrowPerspective,
            address eulerBasePerspective,
            address eulerFactoryPespective
        )
    {
        address[] memory recognizedPerspectives = new address[](3);
        governableWhitelistPerspective = address(new GovernableWhitelistPerspective(getDeployer()));
        escrowPerspective = address(new EscrowPerspective(eVaultFactory));

        recognizedPerspectives[0] = governableWhitelistPerspective;
        recognizedPerspectives[1] = escrowPerspective;
        recognizedPerspectives[2] = address(0);
        eulerBasePerspective = address(
            new EulerBasePerspective(
                eVaultFactory,
                oracleRouterFactory,
                oracleAdapterRegistry,
                externalVaultRegistry,
                kinkIRMFactory,
                recognizedPerspectives
            )
        );
        eulerFactoryPespective = address(new EulerFactoryPerspective(eVaultFactory));
    }
}
