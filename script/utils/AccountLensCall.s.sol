// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {AccountLens} from "../../src/Lens/AccountLens.sol";
import "../../src/Lens/LensTypes.sol";

contract AccountLensCall is Script {
    function run() public view returns (VaultAccountInfo memory) {
        address lens = vm.envAddress("VAULT_LENS_ADDRESS");
        address account = vm.envAddress("ACCOUNT_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");
        return AccountLens(lens).getVaultAccountInfo(account, vault);
    }
}
