// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";

contract KinkIRM is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory inputScriptFileName = "04_KinkIRM_input.json";
        string memory outputScriptFileName = "04_KinkIRM_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        uint256 baseRate = vm.parseJsonUint(json, ".baseRate");
        uint256 slope1 = vm.parseJsonUint(json, ".slope1");
        uint256 slope2 = vm.parseJsonUint(json, ".slope2");
        uint32 kink = uint32(vm.parseJsonUint(json, ".kink"));

        irm = execute(kinkIRMFactory, baseRate, slope1, slope2, kink);

        string memory object;
        object = vm.serializeAddress("irm", "irm", irm);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address kinkIRMFactory, uint256 baseRate, uint256 slope1, uint256 slope2, uint32 kink)
        public
        broadcast
        returns (address irm)
    {
        irm = execute(kinkIRMFactory, baseRate, slope1, slope2, kink);
    }

    function execute(address kinkIRMFactory, uint256 baseRate, uint256 slope1, uint256 slope2, uint32 kink)
        public
        returns (address irm)
    {
        irm = EulerKinkIRMFactory(kinkIRMFactory).deploy(baseRate, slope1, slope2, kink);
    }
}
