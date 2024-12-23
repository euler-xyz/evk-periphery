// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract OwnershipTransferPeriphery is BatchBuilder {
    function run() public {
        verifyMultisigAddresses(multisigAddresses);

        if (Ownable(peripheryAddresses.oracleAdapterRegistry).owner() != multisigAddresses.labs) {
            console.log("+ Transferring ownership of OracleAdapterRegistry to %s", multisigAddresses.labs);
            transferOwnership(peripheryAddresses.oracleAdapterRegistry, multisigAddresses.labs);
        } else {
            console.log("- OracleAdapterRegistry owner is already set to the desired address. Skipping...");
        }

        if (Ownable(peripheryAddresses.externalVaultRegistry).owner() != multisigAddresses.labs) {
            console.log("+ Transferring ownership of ExternalVaultRegistry to %s", multisigAddresses.labs);
            transferOwnership(peripheryAddresses.externalVaultRegistry, multisigAddresses.labs);
        } else {
            console.log("- ExternalVaultRegistry owner is already set to the desired address. Skipping...");
        }

        if (Ownable(peripheryAddresses.irmRegistry).owner() != multisigAddresses.labs) {
            console.log("+ Transferring ownership of IRMRegistry to %s", multisigAddresses.labs);
            transferOwnership(peripheryAddresses.irmRegistry, multisigAddresses.labs);
        } else {
            console.log("- IRMRegistry owner is already set to the desired address. Skipping...");
        }

        if (Ownable(peripheryAddresses.governedPerspective).owner() != multisigAddresses.labs) {
            console.log("+ Transferring ownership of GovernedPerspective to %s", multisigAddresses.labs);
            transferOwnership(peripheryAddresses.governedPerspective, multisigAddresses.labs);
        } else {
            console.log("- GovernedPerspective owner is already set to the desired address. Skipping...");
        }

        executeBatch();
    }
}
