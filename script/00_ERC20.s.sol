// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, ERC20Mintable} from "./utils/ScriptUtils.s.sol";
import {RewardToken} from "../src/ERC20/deployed/RewardToken.sol";

contract MockERC20Deployer is ScriptUtils {
    function run() public broadcast returns (address mockERC20) {
        string memory inputScriptFileName = "00_MockERC20_input.json";
        string memory outputScriptFileName = "00_MockERC20_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        string memory name = abi.decode(vm.parseJson(json, ".name"), (string));
        string memory symbol = abi.decode(vm.parseJson(json, ".symbol"), (string));
        uint8 decimals = abi.decode(vm.parseJson(json, ".decimals"), (uint8));

        mockERC20 = execute(name, symbol, decimals);

        string memory object;
        object = vm.serializeAddress("mock", "mockERC20", mockERC20);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(string memory name, string memory symbol, uint8 decimals)
        public
        broadcast
        returns (address mockERC20)
    {
        mockERC20 = execute(name, symbol, decimals);
    }

    function execute(string memory name, string memory symbol, uint8 decimals) public returns (address mockERC20) {
        mockERC20 = address(new ERC20Mintable(getDeployer(), name, symbol, decimals));
    }
}

contract RewardTokenDeployer is ScriptUtils {
    function run() public broadcast returns (address rewardToken) {
        string memory inputScriptFileName = "00_RewardToken_input.json";
        string memory outputScriptFileName = "00_RewardToken_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address evc = abi.decode(vm.parseJson(json, ".evc"), (address));
        address owner = abi.decode(vm.parseJson(json, ".owner"), (address));
        address receiver = abi.decode(vm.parseJson(json, ".receiver"), (address));
        address underlying = abi.decode(vm.parseJson(json, ".underlying"), (address));
        string memory name = abi.decode(vm.parseJson(json, ".name"), (string));
        string memory symbol = abi.decode(vm.parseJson(json, ".symbol"), (string));

        rewardToken = execute(evc, owner, receiver, underlying, name, symbol);

        string memory object;
        object = vm.serializeAddress("rewardToken", "rewardToken", rewardToken);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address evc,
        address owner,
        address receiver,
        address underlying,
        string memory name,
        string memory symbol
    ) public broadcast returns (address rewardToken) {
        rewardToken = execute(evc, owner, receiver, underlying, name, symbol);
    }

    function execute(
        address evc,
        address owner,
        address receiver,
        address underlying,
        string memory name,
        string memory symbol
    ) public returns (address rewardToken) {
        rewardToken = address(new RewardToken(evc, owner, receiver, underlying, name, symbol));
    }
}
