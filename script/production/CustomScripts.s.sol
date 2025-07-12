// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, IEVC, IEVault, console} from "../utils/ScriptUtils.s.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import {SafeTransaction, SafeMultisendBuilder} from "../utils/SafeUtils.s.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";
import {CapRiskSteward} from "../../src/Governor/CapRiskSteward.sol";
import {GovernorAccessControlEmergency} from "../../src/Governor/GovernorAccessControlEmergency.sol";

abstract contract CustomScriptBase is BatchBuilder {
    function run() public {
        execute();
        saveAddresses();
    }

    function execute() public virtual {}
}

contract MigratePosition is BatchBuilder {
    function run() public {
        uint8[] memory sourceIds = new uint8[](1);
        uint8[] memory destinationIds = new uint8[](1);

        sourceIds[0] = getSourceAccountId();
        destinationIds[0] = getDestinationAccountId();

        execute(sourceIds, destinationIds);
        saveAddresses();
    }

    function run(uint8[] calldata sourceIds, uint8[] calldata destinationIds) public {
        execute(sourceIds, destinationIds);
        saveAddresses();
    }

    function execute(uint8[] memory sourceIds, uint8[] memory destinationIds) public {
        require(
            sourceIds.length == destinationIds.length && sourceIds.length > 0,
            "sourceIds and destinationIds must have the same length and be less than or equal to 5"
        );

        address sourceWallet = getSourceWallet();
        bytes19 sourceWalletPrefix = IEVC(coreAddresses.evc).getAddressPrefix(sourceWallet);
        address destinationWallet = getDestinationWallet();

        uint256 bitfield;
        for (uint8 i = 0; i < sourceIds.length; ++i) {
            bitfield |= 1 << sourceIds[i];
        }

        for (uint8 i = 0; i < sourceIds.length; ++i) {
            _migratePosition(sourceWallet, sourceIds[i], destinationWallet, destinationIds[i]);
        }

        string memory result = string.concat(
            "IMPORTANT: before proceeding, you must trust the destination wallet ",
            vm.toString(destinationWallet),
            "!\n\n"
        );
        result = string.concat(result, "Step 1: give control over your account to the destination wallet\n");
        result = string.concat(
            result,
            "Go to the block explorer dedicated to your network and paste the EVC address: ",
            vm.toString(coreAddresses.evc),
            "\n"
        );
        result = string.concat(
            result,
            "Click 'Contract' and then 'Write Contract'. Find 'setOperator' function. Paste the following input data:\n"
        );
        result = string.concat(result, "    setOperator/payableAmount: 0\n");
        result = string.concat(result, "    addressPrefix: ", _substring(vm.toString(sourceWalletPrefix), 0, 40), "\n");
        result = string.concat(result, "    operator: ", vm.toString(destinationWallet), "\n");
        result = string.concat(result, "    operatorBitField: ", vm.toString(bitfield), "\n");
        result = string.concat(result, "Connect your source wallet, click 'Write' and execute the transaction.\n\n");
        result = string.concat(result, "Step 2: pull the position from the source account to the destination account\n");
        result = string.concat(
            result,
            "Go to the block explorer dedicated to your network and paste the EVC address: ",
            vm.toString(coreAddresses.evc),
            "\n"
        );
        result = string.concat(
            result,
            "Click 'Contract' and then 'Write Contract'. Find 'batch' function. Paste the following input data:\n"
        );
        result = string.concat(result, "    batch/payableAmount: 0\n");
        result = string.concat(result, "    items: ", toString(getBatchItems()), "\n");
        result = string.concat(result, "Connect your destination wallet, click 'Write' and execute the transaction.\n");

        console.log(result);
        vm.writeFile(string.concat(vm.projectRoot(), "/script/MigrationInstruction.txt"), result);
        dumpBatch(destinationWallet);

        // simulation
        vm.prank(sourceWallet);
        IEVC(coreAddresses.evc).setOperator(sourceWalletPrefix, destinationWallet, bitfield);

        if (isBatchViaSafe()) executeBatchViaSafe(false);
        else executeBatchPrank(destinationWallet);
    }

    function _migratePosition(
        address sourceWallet,
        uint8 sourceAccountId,
        address destinationWallet,
        uint8 destinationAccountId
    ) internal {
        address sourceAccount = address(uint160(sourceWallet) ^ sourceAccountId);
        address destinationAccount = address(uint160(destinationWallet) ^ destinationAccountId);
        address[] memory collaterals = IEVC(coreAddresses.evc).getCollaterals(sourceAccount);
        address[] memory controllers = IEVC(coreAddresses.evc).getControllers(sourceAccount);

        for (uint256 i = 0; i < collaterals.length; ++i) {
            uint256 amount = IEVault(collaterals[i]).balanceOf(sourceAccount);
            if (amount == 0) continue;

            addBatchItem(
                coreAddresses.evc,
                address(0),
                abi.encodeCall(IEVC.enableCollateral, (destinationAccount, collaterals[i]))
            );
            addBatchItem(
                collaterals[i],
                sourceAccount,
                abi.encodeCall(IEVault(collaterals[i]).transfer, (destinationAccount, amount))
            );
            addBatchItem(
                coreAddresses.evc, address(0), abi.encodeCall(IEVC.disableCollateral, (sourceAccount, collaterals[i]))
            );
        }

        for (uint256 i = 0; i < controllers.length; ++i) {
            if (IEVault(controllers[i]).debtOf(sourceAccount) == 0) continue;

            addBatchItem(
                coreAddresses.evc,
                address(0),
                abi.encodeCall(IEVC.enableController, (destinationAccount, controllers[i]))
            );
            addBatchItem(
                controllers[i],
                destinationAccount,
                abi.encodeCall(IEVault(controllers[i]).pullDebt, (type(uint256).max, sourceAccount))
            );
            addBatchItem(controllers[i], sourceAccount, abi.encodeCall(IEVault(controllers[i]).disableController, ()));
        }

        addBatchItem(
            coreAddresses.evc,
            address(0),
            abi.encodeCall(IEVC.setAccountOperator, (sourceAccount, destinationWallet, false))
        );
    }
}

contract MergeSafeBatchBuilderFiles is CustomScriptBase, SafeMultisendBuilder {
    function execute() public override {
        address safe = getSafe();
        string memory basePath = string.concat(
            vm.projectRoot(), "/", getPath(), "/SafeBatchBuilder_", vm.toString(safeNonce), "_", vm.toString(safe), "_"
        );

        for (uint256 i = 0; vm.exists(string.concat(basePath, vm.toString(i), ".json")); i++) {
            string memory json = vm.readFile(string.concat(basePath, vm.toString(i), ".json"));
            address target = vm.parseJsonAddress(json, ".transactions[0].to");
            uint256 value = vm.parseJsonUint(json, ".transactions[0].value");
            bytes memory data = vm.parseJsonBytes(json, ".transactions[0].data");

            addMultisendItem(target, value, data);
        }

        executeMultisend(safe, safeNonce++);
    }
}

contract UnpauseEVaultFactory is CustomScriptBase {
    function execute() public override {
        SafeTransaction transaction = new SafeTransaction();

        transaction.create(
            true,
            getSafe(),
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(FactoryGovernor.unpause, (coreAddresses.eVaultFactory)),
            safeNonce++
        );
    }
}

contract DeployAndConfigureCapRiskSteward is CustomScriptBase {
    function execute() public override {
        require(getConfigAddress("riskSteward") != address(0), "Risk steward config address not found");
        require(getConfigAddress("gauntlet") != address(0), "Gauntlet config address not found");

        startBroadcast();
        CapRiskSteward capRiskSteward = new CapRiskSteward(
            governorAddresses.accessControlEmergencyGovernor,
            peripheryAddresses.kinkIRMFactory,
            getDeployer(),
            2e18,
            1 days
        );

        governorAddresses.capRiskSteward = address(capRiskSteward);

        capRiskSteward.grantRole(capRiskSteward.WILD_CARD(), getConfigAddress("riskSteward"));
        capRiskSteward.grantRole(capRiskSteward.DEFAULT_ADMIN_ROLE(), multisigAddresses.DAO);
        capRiskSteward.renounceRole(capRiskSteward.DEFAULT_ADMIN_ROLE(), getDeployer());

        stopBroadcast();

        SafeTransaction transaction = new SafeTransaction();
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory payloads = new bytes[](2);

        targets[0] = governorAddresses.accessControlEmergencyGovernorWildcardTimelockController;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            AccessControl.grantRole,
            (
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController))
                    .PROPOSER_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[1] = governorAddresses.accessControlEmergencyGovernorWildcardTimelockController;
        values[1] = 0;
        payloads[1] = abi.encodeCall(
            AccessControl.grantRole,
            (
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController))
                    .CANCELLER_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        bytes memory data = abi.encodeCall(
            TimelockController.scheduleBatch,
            (
                targets,
                values,
                payloads,
                bytes32(0),
                bytes32(0),
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController))
                    .getMinDelay()
            )
        );

        transaction.create(
            true,
            getSafe(),
            governorAddresses.accessControlEmergencyGovernorWildcardTimelockController,
            0,
            data,
            safeNonce++
        );

        // simulate timelock execution
        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController);
            (bool success,) = targets[i].call{value: values[i]}(payloads[i]);
            require(success, "timelock execution simulation failed");
        }

        targets = new address[](5);
        values = new uint256[](5);
        payloads = new bytes[](5);

        targets[0] = governorAddresses.accessControlEmergencyGovernor;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).CAPS_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[1] = governorAddresses.accessControlEmergencyGovernor;
        values[1] = 0;
        payloads[1] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).LTV_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[2] = governorAddresses.accessControlEmergencyGovernor;
        values[2] = 0;
        payloads[2] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).HOOK_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[3] = governorAddresses.accessControlEmergencyGovernor;
        values[3] = 0;
        payloads[3] =
            abi.encodeCall(AccessControl.grantRole, (IGovernance.setCaps.selector, governorAddresses.capRiskSteward));

        targets[4] = governorAddresses.accessControlEmergencyGovernor;
        values[4] = 0;
        payloads[4] = abi.encodeCall(
            AccessControl.grantRole, (IGovernance.setInterestRateModel.selector, governorAddresses.capRiskSteward)
        );

        data = abi.encodeCall(
            TimelockController.scheduleBatch,
            (
                targets,
                values,
                payloads,
                bytes32(0),
                bytes32(0),
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorAdminTimelockController))
                    .getMinDelay()
            )
        );

        transaction.create(
            true, getSafe(), governorAddresses.accessControlEmergencyGovernorAdminTimelockController, 0, data, safeNonce
        );

        // simulate timelock execution
        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(governorAddresses.accessControlEmergencyGovernorAdminTimelockController);
            (bool success,) = targets[i].call{value: values[i]}(payloads[i]);
            require(success, "timelock execution simulation failed");
        }
    }
}
