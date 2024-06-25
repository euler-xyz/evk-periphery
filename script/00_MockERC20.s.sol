// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, ERC20Mintable} from "./ScriptUtils.s.sol";

contract MockERC20 is ScriptUtils {
    function run() public startBroadcast returns (address mockERC20) {
        string memory scriptFileName = "00_MockERC20.json";
        string memory json = getInputConfig(scriptFileName);
        string memory name = abi.decode(vm.parseJson(json, ".name"), (string));
        string memory symbol = abi.decode(vm.parseJson(json, ".symbol"), (string));
        uint8 decimals = abi.decode(vm.parseJson(json, ".decimals"), (uint8));

        mockERC20 = execute(name, symbol, decimals);

        string memory object;
        object = vm.serializeAddress("mock", "mockERC20", mockERC20);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(string memory name, string memory symbol, uint8 decimals)
        public
        startBroadcast
        returns (address mockERC20)
    {
        mockERC20 = execute(name, symbol, decimals);
    }

    function execute(string memory name, string memory symbol, uint8 decimals) public returns (address mockERC20) {
        mockERC20 = address(new ERC20Mintable(getDeployer(), name, symbol, decimals));
    }
}
