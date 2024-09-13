// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {AccountLens} from "../src/Lens/AccountLens.sol";
import {OracleLens} from "../src/Lens/OracleLens.sol";
import {IRMLens} from "../src/Lens/IRMLens.sol";
import {VaultLens} from "../src/Lens/VaultLens.sol";
import {UtilsLens} from "../src/Lens/UtilsLens.sol";

contract Lenses is ScriptUtils {
    function run()
        public
        broadcast
        returns (address accountLens, address oracleLens, address irmLens, address vaultLens, address utilsLens)
    {
        string memory inputScriptFileName = "08_Lenses_input.json";
        string memory outputScriptFileName = "08_Lenses_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));

        (accountLens, oracleLens, irmLens, vaultLens, utilsLens) = execute(oracleAdapterRegistry, kinkIRMFactory);

        string memory object;
        object = vm.serializeAddress("lenses", "accountLens", accountLens);
        object = vm.serializeAddress("lenses", "oracleLens", oracleLens);
        object = vm.serializeAddress("lenses", "irmLens", irmLens);
        object = vm.serializeAddress("lenses", "vaultLens", vaultLens);
        object = vm.serializeAddress("lenses", "utilsLens", utilsLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address oracleAdapterRegistry, address kinkIRMFactory)
        public
        broadcast
        returns (address accountLens, address oracleLens, address irmLens, address vaultLens, address utilsLens)
    {
        (accountLens, oracleLens, irmLens, vaultLens, utilsLens) = execute(oracleAdapterRegistry, kinkIRMFactory);
    }

    function execute(address oracleAdapterRegistry, address kinkIRMFactory)
        public
        returns (address accountLens, address oracleLens, address irmLens, address vaultLens, address utilsLens)
    {
        accountLens = address(new AccountLens());
        oracleLens = address(new OracleLens(oracleAdapterRegistry));
        irmLens = address(new IRMLens(kinkIRMFactory));
        vaultLens = address(new VaultLens(address(oracleLens), address(irmLens)));
        utilsLens = address(new UtilsLens());
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
        string memory json = getInputConfig(inputScriptFileName);
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));

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
        string memory json = getInputConfig(inputScriptFileName);
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));

        irmLens = execute(kinkIRMFactory);

        string memory object;
        object = vm.serializeAddress("lens", "irmLens", irmLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address kinkIRMFactory) public broadcast returns (address irmLens) {
        irmLens = execute(kinkIRMFactory);
    }

    function execute(address kinkIRMFactory) public returns (address irmLens) {
        irmLens = address(new IRMLens(kinkIRMFactory));
    }
}

contract LensVaultDeployer is ScriptUtils {
    function run() public broadcast returns (address vaultLens) {
        string memory inputScriptFileName = "08_LensVault_input.json";
        string memory outputScriptFileName = "08_LensVault_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address oracleLens = abi.decode(vm.parseJson(json, ".oracleLens"), (address));
        address irmLens = abi.decode(vm.parseJson(json, ".irmLens"), (address));

        vaultLens = execute(oracleLens, irmLens);

        string memory object;
        object = vm.serializeAddress("lens", "vaultLens", vaultLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address oracleLens, address irmLens) public broadcast returns (address vaultLens) {
        vaultLens = execute(oracleLens, irmLens);
    }

    function execute(address oracleLens, address irmLens) public returns (address vaultLens) {
        vaultLens = address(new VaultLens(oracleLens, irmLens));
    }
}

contract LensUtilsDeployer is ScriptUtils {
    function run() public broadcast returns (address utilsLens) {
        string memory outputScriptFileName = "08_LensUtils_output.json";

        utilsLens = execute();

        string memory object;
        object = vm.serializeAddress("lens", "utilsLens", utilsLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy() public broadcast returns (address utilsLens) {
        utilsLens = execute();
    }

    function execute() public returns (address utilsLens) {
        utilsLens = address(new UtilsLens());
    }
}
