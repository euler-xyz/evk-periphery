// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {FactoryGovernor} from "../src/Governor/FactoryGovernor.sol";
import {GovernorAccessControl} from "../src/Governor/GovernorAccessControl.sol";
import {GovernorAccessControlEmergency} from "../src/Governor/GovernorAccessControlEmergency.sol";

contract EVaultFactoryGovernorDeployer is ScriptUtils {
    function run() public broadcast returns (address factoryGovernor) {
        string memory outputScriptFileName = "12_EVaultFactoryGovernor_output.json";

        factoryGovernor = execute();

        string memory object;
        object = vm.serializeAddress("factoryGovernor", "factoryGovernor", factoryGovernor);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy() public broadcast returns (address factoryGovernor) {
        factoryGovernor = execute();
    }

    function execute() public returns (address factoryGovernor) {
        factoryGovernor = address(new FactoryGovernor(getDeployer()));
    }
}

contract GovernorAccessControlDeployer is ScriptUtils {
    function run() public broadcast returns (address governorAccessControl) {
        string memory inputScriptFileName = "12_GovernorAccessControl_input.json";
        string memory outputScriptFileName = "12_GovernorAccessControl_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        governorAccessControl = execute(evc);

        string memory object;
        object = vm.serializeAddress("governorAccessControl", "governorAccessControl", governorAccessControl);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc) public broadcast returns (address governorAccessControl) {
        governorAccessControl = execute(evc);
    }

    function execute(address evc) public returns (address governorAccessControl) {
        governorAccessControl = address(new GovernorAccessControl(evc, getDeployer()));
    }
}

contract GovernorAccessControlEmergencyDeployer is ScriptUtils {
    function run() public broadcast returns (address governorAccessControlEmergency) {
        string memory inputScriptFileName = "12_GovernorAccessControlEmergency_input.json";
        string memory outputScriptFileName = "12_GovernorAccessControlEmergency_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        governorAccessControlEmergency = execute(evc);

        string memory object;
        object = vm.serializeAddress(
            "governorAccessControlEmergency", "governorAccessControlEmergency", governorAccessControlEmergency
        );
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc) public broadcast returns (address governorAccessControlEmergency) {
        governorAccessControlEmergency = execute(evc);
    }

    function execute(address evc) public returns (address governorAccessControlEmergency) {
        governorAccessControlEmergency = address(new GovernorAccessControlEmergency(evc, getDeployer()));
    }
}
