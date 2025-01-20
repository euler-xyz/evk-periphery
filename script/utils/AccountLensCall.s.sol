// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {AccountLens} from "../../src/Lens/AccountLens.sol";
import "../../src/Lens/LensTypes.sol";

contract AccountLensCall is ScriptUtils {
    function run() public view returns (VaultAccountInfo memory) {
        return AccountLens(lensAddresses.accountLens).getVaultAccountInfo(
            vm.envAddress("ACCOUNT_ADDRESS"), vm.envAddress("VAULT_ADDRESS")
        );
    }
}
