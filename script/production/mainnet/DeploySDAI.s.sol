// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../../utils/ScriptUtils.s.sol";
import {EVaultDeployer} from "../../07_EVault.s.sol";
import {SnapshotRegistry} from "../../../src/SnapshotRegistry/SnapshotRegistry.sol";

contract DeploySDAI is BatchBuilder {
    address internal constant sDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function run() public returns (address escrowVaultSDAI) {
        // add sDAI to the external vault registry
        addBatchItem(peripheryAddresses.externalVaultRegistry, abi.encodeCall(SnapshotRegistry.add, (sDAI, sDAI, DAI)));

        // deploy the sDAI escrow vault
        {
            EVaultDeployer deployer = new EVaultDeployer();
            escrowVaultSDAI = deployer.deploy(coreAddresses.eVaultFactory, true, sDAI);
        }

        // configure the sDAI escrow vault and verify it by the escrow perspective
        setHookConfig(escrowVaultSDAI, address(0), 0);
        setGovernorAdmin(escrowVaultSDAI, address(0));
        perspectiveVerify(peripheryAddresses.escrowedCollateralPerspective, escrowVaultSDAI);
        executeBatch();
    }
}
