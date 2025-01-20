// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
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
        string memory json = getScriptFile(inputScriptFileName);
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
        string memory json = getScriptFile(inputScriptFileName);
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

contract TimelockControllerDeployer is ScriptUtils {
    function run() public broadcast returns (address timelockController) {
        string memory inputScriptFileName = "12_TimelockController_input.json";
        string memory outputScriptFileName = "12_TimelockController_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        uint256 minDelay = vm.parseJsonUint(json, ".minDelay");
        address[] memory proposers = vm.parseJsonAddressArray(json, ".proposers");
        address[] memory executors = vm.parseJsonAddressArray(json, ".executors");

        timelockController = execute(minDelay, proposers, executors);

        string memory object;
        object = vm.serializeAddress("timelockController", "timelockController", timelockController);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(uint256 minDelay, address[] memory proposers, address[] memory executors)
        public
        broadcast
        returns (address timelockController)
    {
        timelockController = execute(minDelay, proposers, executors);
    }

    function execute(uint256 minDelay, address[] memory proposers, address[] memory executors)
        public
        returns (address timelockController)
    {
        timelockController = address(new TimelockController(minDelay, proposers, executors, getDeployer()));
    }
}
