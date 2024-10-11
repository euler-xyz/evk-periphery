// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EVKFactoryPerspective} from "../src/Perspectives/deployed/EVKFactoryPerspective.sol";
import {GovernedPerspective} from "../src/Perspectives/deployed/GovernedPerspective.sol";
import {EscrowedCollateralPerspective} from "../src/Perspectives/deployed/EscrowedCollateralPerspective.sol";
import {EulerUngovernedPerspective} from "../src/Perspectives/deployed/EulerUngovernedPerspective.sol";

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
        object = vm.serializeAddress("perspectives", "evkFactoryPerspective", perspectives[0]);
        object = vm.serializeAddress("perspectives", "governedPerspective", perspectives[1]);
        object = vm.serializeAddress("perspectives", "escrowedCollateralPerspective", perspectives[2]);
        object = vm.serializeAddress("perspectives", "eulerUngoverned0xPerspective", perspectives[3]);
        object = vm.serializeAddress("perspectives", "eulerUngovernedNzxPerspective", perspectives[4]);
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
        address evc;
        {
            (bool success, bytes memory data) = GenericFactory(eVaultFactory).implementation().staticcall(
                abi.encodePacked(EVCUtil.EVC.selector, uint256(0), uint256(0))
            );
            assert(success && data.length == 32);

            evc = abi.decode(data, (address));
            require(
                evc == EVCUtil(oracleAdapterRegistry).EVC() && evc == EVCUtil(externalVaultRegistry).EVC()
                    && evc == EVCUtil(irmRegistry).EVC(),
                "EVCs do not match"
            );
        }

        address evkFactoryPerspective = address(new EVKFactoryPerspective(eVaultFactory));
        address governedPerspective = address(new GovernedPerspective(evc, getDeployer()));
        address escrowedCollateralPerspective = address(new EscrowedCollateralPerspective(eVaultFactory));

        address[] memory recognizedUnitOfAccounts = new address[](3);
        recognizedUnitOfAccounts[0] = address(840);
        recognizedUnitOfAccounts[1] = getWETHAddress();
        recognizedUnitOfAccounts[2] = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

        address[] memory recognizedPerspectives = new address[](2);
        recognizedPerspectives[0] = escrowedCollateralPerspective;
        recognizedPerspectives[1] = address(0);
        address eulerUngoverned0xPerspective = address(
            new EulerUngovernedPerspective(
                "Euler Ungoverned 0x Perspective",
                eVaultFactory,
                oracleRouterFactory,
                oracleAdapterRegistry,
                externalVaultRegistry,
                kinkIRMFactory,
                irmRegistry,
                recognizedUnitOfAccounts,
                recognizedPerspectives
            )
        );

        recognizedPerspectives = new address[](3);
        recognizedPerspectives[0] = governedPerspective;
        recognizedPerspectives[1] = escrowedCollateralPerspective;
        recognizedPerspectives[2] = address(0);
        address eulerUngovernedNzxPerspective = address(
            new EulerUngovernedPerspective(
                "Euler Ungoverned nzx Perspective",
                eVaultFactory,
                oracleRouterFactory,
                oracleAdapterRegistry,
                externalVaultRegistry,
                kinkIRMFactory,
                irmRegistry,
                recognizedUnitOfAccounts,
                recognizedPerspectives
            )
        );

        perspectives = new address[](5);
        perspectives[0] = evkFactoryPerspective;
        perspectives[1] = governedPerspective;
        perspectives[2] = escrowedCollateralPerspective;
        perspectives[3] = eulerUngoverned0xPerspective;
        perspectives[4] = eulerUngovernedNzxPerspective;
    }
}
