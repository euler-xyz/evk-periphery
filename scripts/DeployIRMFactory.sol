// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";


contract DeployIRMFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);

        vm.startBroadcast(deployerPrivateKey);

        EulerKinkIRMFactory irmFactory = new EulerKinkIRMFactory();

        vm.stopBroadcast();

        console.log("EulerKinkIRMFactory deployed at: ", address(irmFactory));
    }

}