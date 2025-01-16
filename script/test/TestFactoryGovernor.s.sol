// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "../utils/ScriptUtils.s.sol";
import {SafeTransaction, SafeUtil} from "../utils/SafeUtils.s.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";

contract TestFactoryGovernor is ScriptUtils {
    function run() public {
        simulatePendingTransactions();

        // put your logic here

        require(
            GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin() == governorAddresses.eVaultFactoryGovernor,
            "Upgrade admin is not the factory governor"
        );

        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMemberCount(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE()
            ) == 1,
            "Default admin role is not set"
        );

        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMembers(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE()
            )[0] == governorAddresses.eVaultFactoryTimelockController,
            "Default admin role is not set to the timelock controller"
        );

        vm.prank(multisigAddresses.DAO);
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).schedule(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (address(0))))
            ),
            bytes32(0),
            bytes32(0),
            4 days
        );

        vm.warp(block.timestamp + 4 days);
        
        /// ...

    }

    function simulatePendingTransactions() internal virtual {
        SafeTransaction safeUtil = new SafeTransaction();
        if (!safeUtil.isTransactionServiceAPIAvailable()) return;

        SafeTransaction.Transaction[] memory transactions = safeUtil.getPendingTransactions(getSafe());

        for (uint256 i = 0; i < transactions.length; ++i) {
            try safeUtil.simulate(
                transactions[i].operation == SafeUtil.Operation.CALL,
                transactions[i].safe,
                transactions[i].to,
                transactions[i].value,
                transactions[i].data
            ) {} catch {}
        }
    }
}
