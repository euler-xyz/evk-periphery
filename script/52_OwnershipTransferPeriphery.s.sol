// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract OwnershipTransferPeriphery is BatchBuilder {
    function run() public {
        verifyMultisigAddresses(multisigAddresses);

        address owner = Ownable(peripheryAddresses.oracleAdapterRegistry).owner();
        if (owner != multisigAddresses.labs) {
            if (owner == getDeployer()) {
                console.log("+ Transferring ownership of OracleAdapterRegistry to %s", multisigAddresses.labs);
                transferOwnership(peripheryAddresses.oracleAdapterRegistry, multisigAddresses.labs);
            } else {
                console.log("! OracleAdapterRegistry owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- OracleAdapterRegistry owner is already set to the desired address. Skipping...");
        }

        owner = Ownable(peripheryAddresses.externalVaultRegistry).owner();
        if (owner != multisigAddresses.labs) {
            if (owner == getDeployer()) {
                console.log("+ Transferring ownership of ExternalVaultRegistry to %s", multisigAddresses.labs);
                transferOwnership(peripheryAddresses.externalVaultRegistry, multisigAddresses.labs);
            } else {
                console.log("! ExternalVaultRegistry owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- ExternalVaultRegistry owner is already set to the desired address. Skipping...");
        }

        owner = Ownable(peripheryAddresses.irmRegistry).owner();
        if (owner != multisigAddresses.labs) {
            if (owner == getDeployer()) {
                console.log("+ Transferring ownership of IRMRegistry to %s", multisigAddresses.labs);
                transferOwnership(peripheryAddresses.irmRegistry, multisigAddresses.labs);
            } else {
                console.log("! IRMRegistry owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- IRMRegistry owner is already set to the desired address. Skipping...");
        }

        owner = Ownable(peripheryAddresses.governedPerspective).owner();
        if (owner != multisigAddresses.labs) {
            if (owner == getDeployer()) {
                console.log("+ Transferring ownership of GovernedPerspective to %s", multisigAddresses.labs);
                transferOwnership(peripheryAddresses.governedPerspective, multisigAddresses.labs);
            } else {
                console.log("! GovernedPerspective owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- GovernedPerspective owner is already set to the desired address. Skipping...");
        }

        if (peripheryAddresses.eulerEarnGovernedPerspective != address(0)) {
            owner = Ownable(peripheryAddresses.eulerEarnGovernedPerspective).owner();
            if (owner != multisigAddresses.labs) {
                if (owner == getDeployer()) {
                    console.log("+ Transferring ownership of EulerEarnGovernedPerspective to %s", multisigAddresses.labs);
                    transferOwnership(peripheryAddresses.eulerEarnGovernedPerspective, multisigAddresses.labs);
                } else {
                    console.log("! EulerEarnGovernedPerspective owner is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- EulerEarnGovernedPerspective owner is already set to the desired address. Skipping...");
            }
        } else {
            console.log("! EulerEarnGovernedPerspective is not deployed yet. Skipping...");
        }

        executeBatch();
    }
}
