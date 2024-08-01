// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract DeployEscrowFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);

        vm.startBroadcast(deployerPrivateKey);
        
        EscrowFactory escrowFactory = new EscrowFactory(
            vm.env("VAULT_FACTORY"),
            vm.env("ESCROW_PERSPECTIVE")
        );

        vm.stopBroadcast();

        console.log("EscrowFactory deployed at: ", address(escrowFactory));
    }
}