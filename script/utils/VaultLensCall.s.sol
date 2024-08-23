// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import "../../src/Lens/LensTypes.sol";

contract PerspectiveCheck is Script {
    function run() public view returns (VaultInfoFull memory) {
        address lens = vm.envAddress("VAULT_LENS_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");
        return VaultLens(lens).getVaultInfoFull(vault);
    }
}
