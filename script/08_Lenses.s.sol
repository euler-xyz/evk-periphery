// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {AccountLens} from "../src/Lens/AccountLens.sol";
import {OracleLens} from "../src/Lens/OracleLens.sol";
import {IRMLens} from "../src/Lens/IRMLens.sol";
import {VaultLens} from "../src/Lens/VaultLens.sol";
import {UtilsLens} from "../src/Lens/UtilsLens.sol";
import {EulerEarnVaultLens} from "../src/Lens/EulerEarnVaultLens.sol";

contract Lenses is ScriptUtils {
    function run() public broadcast returns (address[] memory lenses) {
        string memory inputScriptFileName = "08_Lenses_input.json";
        string memory outputScriptFileName = "08_Lenses_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address oracleAdapterRegistry = vm.parseJsonAddress(json, ".oracleAdapterRegistry");
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        address adaptiveCurveIRMFactory = vm.parseJsonAddress(json, ".adaptiveCurveIRMFactory");
        address kinkyIRMFactory = vm.parseJsonAddress(json, ".kinkyIRMFactory");
        address fixedCyclicalBinaryIRMFactory = vm.parseJsonAddress(json, ".fixedCyclicalBinaryIRMFactory");

        lenses = execute(
            eVaultFactory,
            oracleAdapterRegistry,
            kinkIRMFactory,
            adaptiveCurveIRMFactory,
            kinkyIRMFactory,
            fixedCyclicalBinaryIRMFactory
        );

        string memory object;
        object = vm.serializeAddress("lenses", "accountLens", lenses[0]);
        object = vm.serializeAddress("lenses", "oracleLens", lenses[1]);
        object = vm.serializeAddress("lenses", "irmLens", lenses[2]);
        object = vm.serializeAddress("lenses", "utilsLens", lenses[3]);
        object = vm.serializeAddress("lenses", "vaultLens", lenses[4]);
        object = vm.serializeAddress("lenses", "eulerEarnVaultLens", lenses[5]);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleAdapterRegistry,
        address kinkIRMFactory,
        address adaptiveCurveIRMFactory,
        address kinkyIRMFactory,
        address fixedCyclicalBinaryIRMFactory
    ) public broadcast returns (address[] memory lenses) {
        lenses = execute(
            eVaultFactory,
            oracleAdapterRegistry,
            kinkIRMFactory,
            adaptiveCurveIRMFactory,
            kinkyIRMFactory,
            fixedCyclicalBinaryIRMFactory
        );
    }

    function execute(
        address eVaultFactory,
        address oracleAdapterRegistry,
        address kinkIRMFactory,
        address adaptiveCurveIRMFactory,
        address kinkyIRMFactory,
        address fixedCyclicalBinaryIRMFactory
    ) public returns (address[] memory lenses) {
        lenses = new address[](6);
        lenses[0] = address(new AccountLens());
        lenses[1] = address(new OracleLens(oracleAdapterRegistry));
        lenses[2] = address(
            new IRMLens(kinkIRMFactory, adaptiveCurveIRMFactory, kinkyIRMFactory, fixedCyclicalBinaryIRMFactory)
        );
        lenses[3] = address(new UtilsLens(eVaultFactory, address(lenses[1])));
        lenses[4] = address(new VaultLens(address(lenses[1]), address(lenses[3]), address(lenses[2])));
        lenses[5] = address(new EulerEarnVaultLens(address(lenses[3])));
    }
}

contract LensAccountDeployer is ScriptUtils {
    function run() public broadcast returns (address accountLens) {
        string memory outputScriptFileName = "08_LensAccount_output.json";

        accountLens = execute();

        string memory object;
        object = vm.serializeAddress("lens", "accountLens", accountLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy() public broadcast returns (address accountLens) {
        accountLens = address(new AccountLens());
    }

    function execute() public returns (address accountLens) {
        accountLens = address(new AccountLens());
    }
}

contract LensOracleDeployer is ScriptUtils {
    function run() public broadcast returns (address oracleLens) {
        string memory inputScriptFileName = "08_LensOracle_input.json";
        string memory outputScriptFileName = "08_LensOracle_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address oracleAdapterRegistry = vm.parseJsonAddress(json, ".oracleAdapterRegistry");

        oracleLens = execute(oracleAdapterRegistry);

        string memory object;
        object = vm.serializeAddress("lens", "oracleLens", oracleLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address oracleAdapterRegistry) public broadcast returns (address oracleLens) {
        oracleLens = execute(oracleAdapterRegistry);
    }

    function execute(address oracleAdapterRegistry) public returns (address oracleLens) {
        oracleLens = address(new OracleLens(oracleAdapterRegistry));
    }
}

contract LensIRMDeployer is ScriptUtils {
    function run() public broadcast returns (address irmLens) {
        string memory inputScriptFileName = "08_LensIRM_input.json";
        string memory outputScriptFileName = "08_LensIRM_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        address adaptiveCurveIRMFactory = vm.parseJsonAddress(json, ".adaptiveCurveIRMFactory");
        address kinkyIRMFactory = vm.parseJsonAddress(json, ".kinkyIRMFactory");
        address fixedCyclicalBinaryIRMFactory = vm.parseJsonAddress(json, ".fixedCyclicalBinaryIRMFactory");

        irmLens = execute(kinkIRMFactory, adaptiveCurveIRMFactory, kinkyIRMFactory, fixedCyclicalBinaryIRMFactory);

        string memory object;
        object = vm.serializeAddress("lens", "irmLens", irmLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address kinkIRMFactory,
        address adaptiveCurveIRMFactory,
        address kinkyIRMFactory,
        address fixedCyclicalBinaryIRMFactory
    ) public broadcast returns (address irmLens) {
        irmLens = execute(kinkIRMFactory, adaptiveCurveIRMFactory, kinkyIRMFactory, fixedCyclicalBinaryIRMFactory);
    }

    function execute(
        address kinkIRMFactory,
        address adaptiveCurveIRMFactory,
        address kinkyIRMFactory,
        address fixedCyclicalBinaryIRMFactory
    ) public returns (address irmLens) {
        irmLens = address(
            new IRMLens(kinkIRMFactory, adaptiveCurveIRMFactory, kinkyIRMFactory, fixedCyclicalBinaryIRMFactory)
        );
    }
}

contract LensVaultDeployer is ScriptUtils {
    function run() public broadcast returns (address vaultLens) {
        string memory inputScriptFileName = "08_LensVault_input.json";
        string memory outputScriptFileName = "08_LensVault_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address oracleLens = vm.parseJsonAddress(json, ".oracleLens");
        address utilsLens = vm.parseJsonAddress(json, ".utilsLens");
        address irmLens = vm.parseJsonAddress(json, ".irmLens");

        vaultLens = execute(oracleLens, utilsLens, irmLens);

        string memory object;
        object = vm.serializeAddress("lens", "vaultLens", vaultLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address oracleLens, address utilsLens, address irmLens)
        public
        broadcast
        returns (address vaultLens)
    {
        vaultLens = execute(oracleLens, utilsLens, irmLens);
    }

    function execute(address oracleLens, address utilsLens, address irmLens) public returns (address vaultLens) {
        vaultLens = address(new VaultLens(oracleLens, utilsLens, irmLens));
    }
}

contract LensUtilsDeployer is ScriptUtils {
    function run() public broadcast returns (address utilsLens) {
        string memory inputScriptFileName = "08_LensUtils_input.json";
        string memory outputScriptFileName = "08_LensUtils_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address oracleLens = vm.parseJsonAddress(json, ".oracleLens");

        utilsLens = execute(eVaultFactory, oracleLens);

        string memory object;
        object = vm.serializeAddress("lens", "utilsLens", utilsLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address eVaultFactory, address oracleLens) public broadcast returns (address utilsLens) {
        utilsLens = execute(eVaultFactory, oracleLens);
    }

    function execute(address eVaultFactory, address oracleLens) public returns (address utilsLens) {
        utilsLens = address(new UtilsLens(eVaultFactory, oracleLens));
    }
}

contract LensEulerEarnVaultDeployer is ScriptUtils {
    function run() public broadcast returns (address eulerEarnVaultLens) {
        string memory inputScriptFileName = "08_LensEulerEarnVault_input.json";
        string memory outputScriptFileName = "08_LensEulerEarnVault_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address utilsLens = vm.parseJsonAddress(json, ".utilsLens");

        eulerEarnVaultLens = execute(utilsLens);

        string memory object;
        object = vm.serializeAddress("lens", "eulerEarnVaultLens", eulerEarnVaultLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address utilsLens) public broadcast returns (address eulerEarnVaultLens) {
        eulerEarnVaultLens = execute(utilsLens);
    }

    function execute(address utilsLens) public returns (address eulerEarnVaultLens) {
        eulerEarnVaultLens = address(new EulerEarnVaultLens(utilsLens));
    }
}
