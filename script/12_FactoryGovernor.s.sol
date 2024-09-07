// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {FactoryGovernor} from "../src/Governor/FactoryGovernor.sol";

contract FactoryGovernorDeployer is ScriptUtils {
    function run() public broadcast returns (address factoryGovernor) {
        string memory outputScriptFileName = "12_FactoryGovernor_output.json";

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
