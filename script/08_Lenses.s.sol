// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
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
        string memory scriptFileName = "08_Lenses.json";

        (accountLens, oracleLens, vaultLens, utilsLens) = execute();

        string memory object;
        object = vm.serializeAddress("lenses", "accountLens", accountLens);
        object = vm.serializeAddress("lenses", "oracleLens", oracleLens);
        object = vm.serializeAddress("lenses", "vaultLens", vaultLens);
        object = vm.serializeAddress("lenses", "utilsLens", utilsLens);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy()
        public
        broadcast
        returns (address accountLens, address oracleLens, address vaultLens, address utilsLens)
    {
        (accountLens, oracleLens, vaultLens, utilsLens) = execute();
    }

    function execute() public returns (address accountLens, address oracleLens, address vaultLens, address utilsLens) {
        accountLens = address(new AccountLens());
        oracleLens = address(new OracleLens());
        vaultLens = address(new VaultLens(address(oracleLens)));
        utilsLens = address(new UtilsLens());
    }
}
