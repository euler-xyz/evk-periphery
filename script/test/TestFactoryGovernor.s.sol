// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "../utils/ScriptUtils.s.sol";
import {SafeTransaction, SafeUtil} from "../utils/SafeUtils.s.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract TestFactoryGovernor is ScriptUtils {

    address constant HYPERNATIVE = 0xff217004BdD3A6A592162380dc0E6BbF143291eB;
    address constant HEXAGATE = 0xcC6451385685721778E7Bd80B54F8c92b484F601;
    address constant EUSDC2 = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;

    function run() public {
        simulatePendingTransactions();

        // sanity check
        require(governorAddresses.eVaultFactoryGovernor == 0x2F13256E04022d6356d8CE8C53C7364e13DC1f3d, "new factory gov");
        require(governorAddresses.eVaultFactoryTimelockController == 0xfb034c1C6c7F42171b2d1Cb8486E0f43ED07A968, "timelock");
        require(multisigAddresses.DAO == 0xcAD001c30E96765aC90307669d578219D4fb1DCe, "dao multisig");


        // UPGRADES

        // Factory governor is installed
        require(
            GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin() == governorAddresses.eVaultFactoryGovernor,
            "Upgrade admin is not the factory governor"
        );

        // Timelock is default admin
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

        // Timelock roles
        require(TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).hasRole(
            TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).PROPOSER_ROLE(),
            multisigAddresses.DAO
        ));
        require(TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).hasRole(
            TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).CANCELLER_ROLE(),
            multisigAddresses.DAO
        ));
        require(TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).hasRole(
            TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).CANCELLER_ROLE(),
            multisigAddresses.securityCouncil
        ));
        require(TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).hasRole(
            TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).EXECUTOR_ROLE(),
            address(0)
        ));

        // DAO can upgrade implementation

        uint256 snapshot = vm.snapshot();

        IEVault(EUSDC2).touch();

        address newImplementation = address(10000);
        vm.etch(newImplementation, coreAddresses.eVaultFactory.code);

        require(GenericFactory(coreAddresses.eVaultFactory).implementation() != newImplementation);

        require(TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).getMinDelay() == 4 days);

        vm.prank(multisigAddresses.DAO);
        // delay too short
        vm.expectRevert();
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).schedule(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0),
            3 days
        );

        vm.prank(multisigAddresses.DAO);
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).schedule(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0),
            4 days
        );

        // too soon
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert();
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).execute(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0)
        );

        vm.warp(block.timestamp + 1 days);
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).execute(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0)
        );

        vm.expectRevert();
        IEVault(EUSDC2).touch();

        require(GenericFactory(coreAddresses.eVaultFactory).implementation() == newImplementation);
        vm.revertTo(snapshot);


        // cancel proposal
        snapshot = vm.snapshot();

        vm.prank(multisigAddresses.DAO);
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).schedule(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0),
            4 days
        );

        vm.warp(block.timestamp + 1 days);

        bytes32 id = TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).hashOperation(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0)
        );

        vm.expectRevert();
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).cancel(id);

        vm.prank(multisigAddresses.securityCouncil);
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).cancel(id);

        vm.warp(block.timestamp + 3 days);
        vm.expectRevert();
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).execute(
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(
                FactoryGovernor.adminCall,
                (coreAddresses.eVaultFactory, abi.encodeCall(GenericFactory.setImplementation, (newImplementation)))
            ),
            bytes32(0),
            bytes32(0)
        );

        // PAUSE GUARDIANS

        // exec scheduled call to add hexagate
        vm.warp(block.timestamp + 4 days);
        TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).execute(
            governorAddresses.eVaultFactoryGovernor,
            0,
            hex"2f2ff15d3bb181d5689164b4d72d34b056228c95b51f3fb0f6dbdb7f9ddba5f91c6821dd000000000000000000000000cc6451385685721778e7bd80b54f8c92b484f601",
            bytes32(0),
            bytes32(0)
        );

        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMemberCount(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE()
            ) == 3,
            "Pause guardian roles length"
        );

        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMembers(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE()
            )[0] == multisigAddresses.labs,
            "pause guardian labs"
        );
        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMembers(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE()
            )[1] == HYPERNATIVE,
            "pause guardian hypernative"
        );
        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMembers(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE()
            )[2] == HEXAGATE,
            "pause guardian hexagate"
        );


        // UNPAUSE ADMIN

        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMemberCount(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE()
            ) == 1,
            "Unpause admin roles length"
        );

        require(
            FactoryGovernor(governorAddresses.eVaultFactoryGovernor).getRoleMembers(
                FactoryGovernor(governorAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE()
            )[0] == multisigAddresses.labs,
            "unpause admin labs"
        );


        // PAUSE / UNPAUSE


        vm.prank(HYPERNATIVE);
        FactoryGovernor(governorAddresses.eVaultFactoryGovernor).pause(coreAddresses.eVaultFactory);

        vm.expectRevert("contract is in read-only mode");
        IEVault(EUSDC2).touch();

        vm.prank(multisigAddresses.labs);
        FactoryGovernor(governorAddresses.eVaultFactoryGovernor).unpause(coreAddresses.eVaultFactory);

        IEVault(EUSDC2).touch();


        vm.prank(HEXAGATE);
        FactoryGovernor(governorAddresses.eVaultFactoryGovernor).pause(coreAddresses.eVaultFactory);

        vm.expectRevert("contract is in read-only mode");
        IEVault(EUSDC2).touch();

        vm.prank(multisigAddresses.labs);
        FactoryGovernor(governorAddresses.eVaultFactoryGovernor).unpause(coreAddresses.eVaultFactory);

        IEVault(EUSDC2).touch();

        vm.prank(multisigAddresses.labs);
        FactoryGovernor(governorAddresses.eVaultFactoryGovernor).pause(coreAddresses.eVaultFactory);

        vm.expectRevert("contract is in read-only mode");
        IEVault(EUSDC2).touch();

        vm.prank(multisigAddresses.labs);
        FactoryGovernor(governorAddresses.eVaultFactoryGovernor).unpause(coreAddresses.eVaultFactory);

        IEVault(EUSDC2).touch();
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
