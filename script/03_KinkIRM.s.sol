// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";

contract KinkIRM is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory scriptFileName = "03_KinkIRM.json";
        string memory json = getInputConfig(scriptFileName);
        address irmFactory = abi.decode(vm.parseJson(json, ".irmFactory"), (address));
        uint256 baseRate = abi.decode(vm.parseJson(json, ".baseRate"), (uint256));
        uint256 slope1 = abi.decode(vm.parseJson(json, ".slope1"), (uint256));
        uint256 slope2 = abi.decode(vm.parseJson(json, ".slope2"), (uint256));
        uint256 kink = abi.decode(vm.parseJson(json, ".kink"), (uint256));

        irm = execute(irmFactory, baseRate, slope1, slope2, kink);

        string memory object;
        object = vm.serializeAddress("irm", "irm", irm);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(address irmFactory, uint256 baseRate, uint256 slope1, uint256 slope2, uint256 kink)
        public
        broadcast
        returns (address irm)
    {
        irm = execute(irmFactory, baseRate, slope1, slope2, kink);
    }

    function execute(address irmFactory, uint256 baseRate, uint256 slope1, uint256 slope2, uint256 kink)
        public
        returns (address irm)
    {
        irm = EulerKinkIRMFactory(irmFactory).deploy(baseRate, slope1, slope2, kink);
    }
}
