// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../utils/ScriptUtils.s.sol";

abstract contract CustomScriptBase is BatchBuilder {
    function run() public {
        execute();
        saveAddresses();
    }

    function execute() public virtual {}
}

import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import {SafeTransaction} from "../utils/SafeUtils.s.sol";
import {CapRiskSteward} from "../../src/Governor/CapRiskSteward.sol";
import {GovernorAccessControlEmergency} from "../../src/Governor/GovernorAccessControlEmergency.sol";

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

        address[] memory targets = new address[](7);
        uint256[] memory values = new uint256[](7);
        bytes[] memory payloads = new bytes[](7);

        targets[0] = governorAddresses.accessControlEmergencyGovernorAdminTimelockController;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            AccessControl.grantRole,
            (
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorAdminTimelockController))
                    .PROPOSER_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[1] = governorAddresses.accessControlEmergencyGovernorAdminTimelockController;
        values[1] = 0;
        payloads[1] = abi.encodeCall(
            AccessControl.grantRole,
            (
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorAdminTimelockController))
                    .CANCELLER_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[2] = governorAddresses.accessControlEmergencyGovernor;
        values[2] = 0;
        payloads[2] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).CAPS_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[3] = governorAddresses.accessControlEmergencyGovernor;
        values[3] = 0;
        payloads[3] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).LTV_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[4] = governorAddresses.accessControlEmergencyGovernor;
        values[4] = 0;
        payloads[4] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).HOOK_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[5] = governorAddresses.accessControlEmergencyGovernor;
        values[5] = 0;
        payloads[5] =
            abi.encodeCall(AccessControl.grantRole, (IGovernance.setCaps.selector, governorAddresses.capRiskSteward));

        targets[6] = governorAddresses.accessControlEmergencyGovernor;
        values[6] = 0;
        payloads[6] = abi.encodeCall(
            AccessControl.grantRole, (IGovernance.setInterestRateModel.selector, governorAddresses.capRiskSteward)
        );

        SafeTransaction transaction = new SafeTransaction();
        safeNonce = safeNonce == 0 ? transaction.getNextNonce(getSafe()) : safeNonce;

        bytes memory data = abi.encodeCall(
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
