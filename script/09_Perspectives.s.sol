// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EVKFactoryPerspective} from "../src/Perspectives/deployed/EVKFactoryPerspective.sol";
import {GovernedPerspective} from "../src/Perspectives/deployed/GovernedPerspective.sol";
import {EscrowedCollateralPerspective} from "../src/Perspectives/deployed/EscrowedCollateralPerspective.sol";
import {EulerUngovernedPerspective} from "../src/Perspectives/deployed/EulerUngovernedPerspective.sol";
import {EulerEarnFactoryPerspective} from "../src/Perspectives/deployed/EulerEarnFactoryPerspective.sol";
import {EdgeFactoryPerspective} from "../src/Perspectives/deployed/EdgeFactoryPerspective.sol";

contract EVKPerspectives is ScriptUtils {
    function run() public broadcast returns (address[] memory perspectives) {
        string memory inputScriptFileName = "09_EVKPerspectives_input.json";
        string memory outputScriptFileName = "09_EVKPerspectives_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address oracleRouterFactory = vm.parseJsonAddress(json, ".oracleRouterFactory");
        address oracleAdapterRegistry = vm.parseJsonAddress(json, ".oracleAdapterRegistry");
        address externalVaultRegistry = vm.parseJsonAddress(json, ".externalVaultRegistry");
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        address irmRegistry = vm.parseJsonAddress(json, ".irmRegistry");

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

        address[] memory recognizedUnitOfAccounts = getRecognizedUnitsOfAccount();
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

contract EVKFactoryPerspectiveDeployer is ScriptUtils {
    function run() public broadcast returns (address evkFactoryPerspective) {
        string memory inputScriptFileName = "09_EVKFactoryPerspective_input.json";
        string memory outputScriptFileName = "09_EVKFactoryPerspective_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");

        evkFactoryPerspective = execute(eVaultFactory);

        string memory object;
        object = vm.serializeAddress("evkFactoryPerspective", "evkFactoryPerspective", evkFactoryPerspective);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address eVaultFactory) public broadcast returns (address evkFactoryPerspective) {
        evkFactoryPerspective = execute(eVaultFactory);
    }

    function execute(address eVaultFactory) public returns (address evkFactoryPerspective) {
        evkFactoryPerspective = address(new EVKFactoryPerspective(eVaultFactory));
    }
}

contract PerspectiveGovernedDeployer is ScriptUtils {
    function run() public broadcast returns (address governedPerspective) {
        string memory inputScriptFileName = "09_PerspectiveGoverned_input.json";
        string memory outputScriptFileName = "09_PerspectiveGoverned_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        governedPerspective = execute(evc);

        string memory object;
        object = vm.serializeAddress("governedPerspective", "governedPerspective", governedPerspective);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc) public broadcast returns (address governedPerspective) {
        governedPerspective = execute(evc);
    }

    function execute(address evc) public returns (address governedPerspective) {
        governedPerspective = address(new GovernedPerspective(evc, getDeployer()));
    }
}

contract EVKPerspectiveEscrowedCollateralDeployer is ScriptUtils {
    function run() public broadcast returns (address escrowedCollateralPerspective) {
        string memory inputScriptFileName = "09_EVKPerspectiveEscrowedCollateral_input.json";
        string memory outputScriptFileName = "09_EVKPerspectiveEscrowedCollateral_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");

        escrowedCollateralPerspective = execute(eVaultFactory);

        string memory object;
        object = vm.serializeAddress(
            "escrowedCollateralPerspective", "escrowedCollateralPerspective", escrowedCollateralPerspective
        );
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address eVaultFactory) public broadcast returns (address escrowedCollateralPerspective) {
        escrowedCollateralPerspective = execute(eVaultFactory);
    }

    function execute(address eVaultFactory) public returns (address escrowedCollateralPerspective) {
        escrowedCollateralPerspective = address(new EscrowedCollateralPerspective(eVaultFactory));
    }
}

contract EVKPerspectiveEulerUngoverned0xDeployer is ScriptUtils {
    function run() public broadcast returns (address eulerUngoverned0xPerspective) {
        string memory inputScriptFileName = "09_EVKPerspectiveEulerUngoverned0x_input.json";
        string memory outputScriptFileName = "09_EVKPerspectiveEulerUngoverned0x_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address oracleRouterFactory = vm.parseJsonAddress(json, ".oracleRouterFactory");
        address oracleAdapterRegistry = vm.parseJsonAddress(json, ".oracleAdapterRegistry");
        address externalVaultRegistry = vm.parseJsonAddress(json, ".externalVaultRegistry");
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        address irmRegistry = vm.parseJsonAddress(json, ".irmRegistry");
        address escrowedCollateralPerspective = vm.parseJsonAddress(json, ".escrowedCollateralPerspective");

        eulerUngoverned0xPerspective = execute(
            eVaultFactory,
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            irmRegistry,
            escrowedCollateralPerspective
        );

        string memory object;
        object = vm.serializeAddress(
            "eulerUngoverned0xPerspective", "eulerUngoverned0xPerspective", eulerUngoverned0xPerspective
        );
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory,
        address irmRegistry,
        address escrowedCollateralPerspective
    ) public broadcast returns (address eulerUngoverned0xPerspective) {
        eulerUngoverned0xPerspective = execute(
            eVaultFactory,
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            irmRegistry,
            escrowedCollateralPerspective
        );
    }

    function execute(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory,
        address irmRegistry,
        address escrowedCollateralPerspective
    ) public returns (address eulerUngoverned0xPerspective) {
        {
            (bool success, bytes memory data) = GenericFactory(eVaultFactory).implementation().staticcall(
                abi.encodePacked(EVCUtil.EVC.selector, uint256(0), uint256(0))
            );
            assert(success && data.length == 32);

            address evc = abi.decode(data, (address));
            require(
                evc == EVCUtil(oracleAdapterRegistry).EVC() && evc == EVCUtil(externalVaultRegistry).EVC()
                    && evc == EVCUtil(irmRegistry).EVC(),
                "EVCs do not match"
            );
            require(
                eVaultFactory == address(EscrowedCollateralPerspective(escrowedCollateralPerspective).vaultFactory()),
                "Escrowed Collateral Perspective is not for this eVaultFactory"
            );
        }

        address[] memory recognizedUnitOfAccounts = getRecognizedUnitsOfAccount();
        address[] memory recognizedPerspectives = new address[](2);
        recognizedPerspectives[0] = escrowedCollateralPerspective;
        recognizedPerspectives[1] = address(0);
        eulerUngoverned0xPerspective = address(
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
    }
}

contract EVKPerspectiveEulerUngovernedNzxDeployer is ScriptUtils {
    function run() public broadcast returns (address eulerUngovernedNzxPerspective) {
        string memory inputScriptFileName = "09_EVKPerspectiveEulerUngovernedNzx_input.json";
        string memory outputScriptFileName = "09_EVKPerspectiveEulerUngovernedNzx_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address oracleRouterFactory = vm.parseJsonAddress(json, ".oracleRouterFactory");
        address oracleAdapterRegistry = vm.parseJsonAddress(json, ".oracleAdapterRegistry");
        address externalVaultRegistry = vm.parseJsonAddress(json, ".externalVaultRegistry");
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        address irmRegistry = vm.parseJsonAddress(json, ".irmRegistry");
        address governedPerspective = vm.parseJsonAddress(json, ".governedPerspective");
        address escrowedCollateralPerspective = vm.parseJsonAddress(json, ".escrowedCollateralPerspective");

        eulerUngovernedNzxPerspective = execute(
            eVaultFactory,
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            irmRegistry,
            governedPerspective,
            escrowedCollateralPerspective
        );

        string memory object;
        object = vm.serializeAddress(
            "eulerUngovernedNzxPerspective", "eulerUngovernedNzxPerspective", eulerUngovernedNzxPerspective
        );
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory,
        address irmRegistry,
        address governedPerspective,
        address escrowedCollateralPerspective
    ) public broadcast returns (address eulerUngovernedNzxPerspective) {
        eulerUngovernedNzxPerspective = execute(
            eVaultFactory,
            oracleRouterFactory,
            oracleAdapterRegistry,
            externalVaultRegistry,
            kinkIRMFactory,
            irmRegistry,
            governedPerspective,
            escrowedCollateralPerspective
        );
    }

    function execute(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address externalVaultRegistry,
        address kinkIRMFactory,
        address irmRegistry,
        address governedPerspective,
        address escrowedCollateralPerspective
    ) public returns (address eulerUngovernedNzxPerspective) {
        {
            (bool success, bytes memory data) = GenericFactory(eVaultFactory).implementation().staticcall(
                abi.encodePacked(EVCUtil.EVC.selector, uint256(0), uint256(0))
            );
            assert(success && data.length == 32);

            address evc = abi.decode(data, (address));
            require(
                evc == EVCUtil(oracleAdapterRegistry).EVC() && evc == EVCUtil(externalVaultRegistry).EVC()
                    && evc == EVCUtil(irmRegistry).EVC() && evc == EVCUtil(governedPerspective).EVC(),
                "EVCs do not match"
            );
            require(
                eVaultFactory == address(EscrowedCollateralPerspective(escrowedCollateralPerspective).vaultFactory()),
                "Escrowed Collateral Perspective is not for this eVaultFactory"
            );
        }

        address[] memory recognizedUnitOfAccounts = getRecognizedUnitsOfAccount();
        address[] memory recognizedPerspectives = new address[](3);
        recognizedPerspectives[0] = governedPerspective;
        recognizedPerspectives[1] = escrowedCollateralPerspective;
        recognizedPerspectives[2] = address(0);
        eulerUngovernedNzxPerspective = address(
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
    }
}

contract EulerEarnPerspectivesDeployer is ScriptUtils {
    function run() public broadcast returns (address[] memory perspectives) {
        string memory inputScriptFileName = "09_EulerEarnPerspectives_input.json";
        string memory outputScriptFileName = "09_EulerEarnPerspectives_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eulerEarnFactory = vm.parseJsonAddress(json, ".eulerEarnFactory");

        perspectives = execute(eulerEarnFactory);

        string memory object;
        object = vm.serializeAddress("perspectives", "eulerEarnFactoryPerspective", perspectives[0]);
        object = vm.serializeAddress("perspectives", "governedPerspective", perspectives[1]);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address eulerEarnFactory) public broadcast returns (address[] memory perspectives) {
        perspectives = execute(eulerEarnFactory);
    }

    function execute(address eulerEarnFactory) public returns (address[] memory perspectives) {
        address eulerEarnFactoryPerspective = address(new EulerEarnFactoryPerspective(eulerEarnFactory));
        address governedPerspective = address(new GovernedPerspective(EVCUtil(eulerEarnFactory).EVC(), getDeployer()));

        perspectives = new address[](2);
        perspectives[0] = eulerEarnFactoryPerspective;
        perspectives[1] = governedPerspective;
    }
}

contract EdgePerspectivesDeployer is ScriptUtils {
    function run() public broadcast returns (address[] memory perspectives) {
        string memory inputScriptFileName = "09_EdgePerspectives_input.json";
        string memory outputScriptFileName = "09_EdgePerspectives_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address edgeFactory = vm.parseJsonAddress(json, ".edgeFactory");

        perspectives = execute(edgeFactory);

        string memory object;
        object = vm.serializeAddress("perspectives", "edgeFactoryPerspective", perspectives[0]);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address edgeFactory) public broadcast returns (address[] memory perspectives) {
        perspectives = execute(edgeFactory);
    }

    function execute(address edgeFactory) public returns (address[] memory perspectives) {
        address edgeFactoryPerspective = address(new EdgeFactoryPerspective(edgeFactory));

        perspectives = new address[](1);
        perspectives[0] = edgeFactoryPerspective;
    }
}
