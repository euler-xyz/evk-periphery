// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {AccountLens} from "../src/Lens/AccountLens.sol";
import {OracleLens} from "../src/Lens/OracleLens.sol";
import {VaultLens} from "../src/Lens/VaultLens.sol";
import {UtilsLens} from "../src/Lens/UtilsLens.sol";

contract Lenses is ScriptUtils {
    function run()
        public
        broadcast
        returns (address accountLens, address oracleLens, address vaultLens, address utilsLens)
    {
        string memory inputScriptFileName = "08_Lenses_input.json";
        string memory outputScriptFileName = "08_Lenses_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));

        (accountLens, oracleLens, vaultLens, utilsLens) = execute(oracleAdapterRegistry);

        string memory object;
        object = vm.serializeAddress("lenses", "accountLens", accountLens);
        object = vm.serializeAddress("lenses", "oracleLens", oracleLens);
        object = vm.serializeAddress("lenses", "vaultLens", vaultLens);
        object = vm.serializeAddress("lenses", "utilsLens", utilsLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address oracleAdapterRegistry)
        public
        broadcast
        returns (address accountLens, address oracleLens, address vaultLens, address utilsLens)
    {
        (accountLens, oracleLens, vaultLens, utilsLens) = execute(oracleAdapterRegistry);
    }

    function execute(address oracleAdapterRegistry)
        public
        returns (address accountLens, address oracleLens, address vaultLens, address utilsLens)
    {
        accountLens = address(new AccountLens());
        oracleLens = address(new OracleLens(oracleAdapterRegistry));
        vaultLens = address(new VaultLens(address(oracleLens)));
        utilsLens = address(new UtilsLens());
    }
}
