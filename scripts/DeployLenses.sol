// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {AccountLens} from "../src/Lens/AccountLens.sol";
import {OracleLens} from "../src/Lens/OracleLens.sol";
import {UtilsLens} from "../src/Lens/UtilsLens.sol";
import {VaultLens} from "../src/Lens/VaultLens.sol";



contract DeployLenses is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);

        vm.startBroadcast(deployerPrivateKey);
        
        AccountLens accountLens = new AccountLens();
        OracleLens oracleLens = new OracleLens();
        UtilsLens utilsLens = new UtilsLens();
        VaultLens vaultLens = new VaultLens(address(oracleLens));

        vm.stopBroadcast();

        console.log("AccountLens deployed at: ", address(accountLens));
        console.log("OracleLens deployed at: ", address(oracleLens));
        console.log("UtilsLens deployed at: ", address(utilsLens));
        console.log("VaultLens deployed at: ", address(vaultLens));
    }
}