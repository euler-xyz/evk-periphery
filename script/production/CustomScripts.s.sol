// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../utils/ScriptUtils.s.sol";
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

contract MergeSafeBatchBuilderFiles is CustomScriptBase, SafeMultisendBuilder {
    function execute() public override {
        string memory basePath = "deployments/default/1/output/SafeBatchBuilder_220_0xcAD001c30E96765aC90307669d578219D4fb1DCe_";

        for (uint256 i = 0; i < 10; i++) {
            string memory path = string.concat(basePath, vm.toString(i), ".json");
            string memory json = getScriptFile(path);
            bytes memory data = vm.parseJsonBytes(json, ".transactions[0].data");
            address target = vm.parseJsonAddress(json, ".transactions[0].to");

            addMultisendItem(target, data);
        }

        executeMultisend(getSafe(), safeNonce++);
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
