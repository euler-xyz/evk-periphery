// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import "../../src/Lens/LensTypes.sol";

contract ClusterDump is ScriptUtils {
    function run() public view {
        //string memory json = vm.readFile(string.concat(vm.envString("CLUSTER_ADDRESSES_PATH")));
        //addresses[] memory vaults = getAddressesFromJson(json, ".vaults");
        //addresses[] memory externalVaults = getAddressesFromJson(json, ".externalVaults");
        //VaultInfoFull memory vaultInfo;
//
        //for (uint256 i = 0; i < vaults.length; ++i) {
        //    vaultInfo = VaultLens(lensAddresses.vaultLens).getVaultInfoFull(vaults[i]);
        //}
//
        //console.log("Vaults %s:", vaults.length);
    }
}
