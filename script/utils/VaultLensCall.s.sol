// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import "../../src/Lens/LensTypes.sol";

contract VaultLensCall is ScriptUtils {
    function run() public view returns (VaultInfoFull memory) {
        return VaultLens(lensAddresses.vaultLens).getVaultInfoFull(vm.envAddress("VAULT_ADDRESS"));
    }
}
