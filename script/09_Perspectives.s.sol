// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {GovernedPerspective} from "../src/Perspectives/deployed/GovernedPerspective.sol";
import {EscrowPerspective} from "../src/Perspectives/deployed/EscrowPerspective.sol";
import {EulerBasePerspective} from "../src/Perspectives/deployed/EulerBasePerspective.sol";
import {EulerBasePlusPerspective} from "../src/Perspectives/deployed/EulerBasePlusPerspective.sol";
import {EulerFactoryPerspective} from "../src/Perspectives/deployed/EulerFactoryPerspective.sol";

contract Perspectives is ScriptUtils {
    function run() public broadcast returns (address[] memory perspectives) {
        string memory inputScriptFileName = "09_Perspectives_input.json";
        string memory outputScriptFileName = "09_Perspectives_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address eVaultFactory = abi.decode(vm.parseJson(json, ".eVaultFactory"), (address));
        address oracleRouterFactory = abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address));
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));
        address externalVaultRegistry = abi.decode(vm.parseJson(json, ".externalVaultRegistry"), (address));
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));
        address irmRegistry = abi.decode(vm.parseJson(json, ".irmRegistry"), (address));

        perspectives = execute(
            eVaultFactory,
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            irmRegistry
        );

        string memory object;
        object = vm.serializeAddress("perspectives", "governedPerspective", perspectives[0]);
        object = vm.serializeAddress("perspectives", "escrowPerspective", perspectives[1]);
        object = vm.serializeAddress("perspectives", "euler0xPerspective", perspectives[2]);
        object = vm.serializeAddress("perspectives", "euler1xPerspective", perspectives[3]);
        object = vm.serializeAddress("perspectives", "eulerFactoryPespective", perspectives[4]);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory,
        address irmRegistry
    ) public broadcast returns (address[] memory perspectives) {
        perspectives = execute(
            eVaultFactory,
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            irmRegistry
        );
    }

    function execute(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory,
        address irmRegistry
    ) public returns (address[] memory perspectives) {
        address governedPerspective = address(new GovernedPerspective(getDeployer()));
        address escrowPerspective = address(new EscrowPerspective(eVaultFactory));

        address[] memory recognizedPerspectives = new address[](2);
        recognizedPerspectives[1] = escrowPerspective;
        recognizedPerspectives[2] = address(0);
        address euler0xPerspective = address(
            new EulerBasePerspective(
                "Euler 0x Perspective",
                eVaultFactory,
                oracleRouterFactory,
                oracleAdapterRegistry,
                externalVaultRegistry,
                kinkIRMFactory,
                irmRegistry,
                recognizedPerspectives
            )
        );

        recognizedPerspectives = new address[](4);
        recognizedPerspectives[0] = governedPerspective;
        recognizedPerspectives[1] = escrowPerspective;
        recognizedPerspectives[2] = euler0xPerspective;
        recognizedPerspectives[3] = address(0);
        address euler1xPerspective = address(
            new EulerBasePlusPerspective(
                "Euler 1x Perspective",
                eVaultFactory,
                oracleRouterFactory,
                oracleAdapterRegistry,
                externalVaultRegistry,
                kinkIRMFactory,
                irmRegistry,
                recognizedPerspectives,
                governedPerspective
            )
        );

        address eulerFactoryPespective = address(new EulerFactoryPerspective(eVaultFactory));

        perspectives = new address[](5);
        perspectives[0] = governedPerspective;
        perspectives[1] = escrowPerspective;
        perspectives[2] = euler0xPerspective;
        perspectives[3] = euler1xPerspective;
        perspectives[4] = eulerFactoryPespective;
    }
}
