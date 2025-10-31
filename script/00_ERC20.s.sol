// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {MockERC20Mintable} from "./utils/MockERC20Mintable.sol";
import {ERC20BurnableMintable} from "../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {RewardToken} from "../src/ERC20/deployed/RewardToken.sol";
import {ERC20Synth} from "../src/ERC20/deployed/ERC20Synth.sol";

contract MockERC20MintableDeployer is ScriptUtils {
    function run() public broadcast returns (address mockERC20Mintable) {
        string memory inputScriptFileName = "00_MockERC20Mintable_input.json";
        string memory outputScriptFileName = "00_MockERC20Mintable_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        string memory name = vm.parseJsonString(json, ".name");
        string memory symbol = vm.parseJsonString(json, ".symbol");
        uint8 decimals = uint8(vm.parseJsonUint(json, ".decimals"));

        mockERC20Mintable = execute(name, symbol, decimals);

        string memory object;
        object = vm.serializeAddress("mockERC20Mintable", "mockERC20Mintable", mockERC20Mintable);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(string memory name, string memory symbol, uint8 decimals)
        public
        broadcast
        returns (address mockERC20Mintable)
    {
        mockERC20Mintable = execute(name, symbol, decimals);
    }

    function execute(string memory name, string memory symbol, uint8 decimals)
        public
        returns (address mockERC20Mintable)
    {
        mockERC20Mintable = address(new MockERC20Mintable(getDeployer(), name, symbol, decimals));
    }
}

contract ERC20BurnableMintableDeployer is ScriptUtils {
    function run() public broadcast returns (address erc20BurnableMintable) {
        string memory inputScriptFileName = "00_ERC20BurnableMintable_input.json";
        string memory outputScriptFileName = "00_ERC20BurnableMintable_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        string memory name = vm.parseJsonString(json, ".name");
        string memory symbol = vm.parseJsonString(json, ".symbol");
        uint8 decimals = uint8(vm.parseJsonUint(json, ".decimals"));

        erc20BurnableMintable = execute(name, symbol, decimals);

        string memory object;
        object = vm.serializeAddress("erc20BurnableMintable", "erc20BurnableMintable", erc20BurnableMintable);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(string memory name, string memory symbol, uint8 decimals)
        public
        broadcast
        returns (address erc20BurnableMintable)
    {
        erc20BurnableMintable = execute(name, symbol, decimals);
    }

    function execute(string memory name, string memory symbol, uint8 decimals)
        public
        returns (address erc20BurnableMintable)
    {
        erc20BurnableMintable = address(new ERC20BurnableMintable(getDeployer(), name, symbol, decimals));
    }
}

contract RewardTokenDeployer is ScriptUtils {
    function run() public broadcast returns (address rewardToken) {
        string memory inputScriptFileName = "00_RewardToken_input.json";
        string memory outputScriptFileName = "00_RewardToken_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address receiver = vm.parseJsonAddress(json, ".receiver");
        address underlying = vm.parseJsonAddress(json, ".underlying");
        string memory name = vm.parseJsonString(json, ".name");
        string memory symbol = vm.parseJsonString(json, ".symbol");

        rewardToken = execute(evc, receiver, underlying, name, symbol);

        string memory object;
        object = vm.serializeAddress("rewardToken", "rewardToken", rewardToken);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address receiver, address underlying, string memory name, string memory symbol)
        public
        broadcast
        returns (address rewardToken)
    {
        rewardToken = execute(evc, receiver, underlying, name, symbol);
    }

    function execute(address evc, address receiver, address underlying, string memory name, string memory symbol)
        public
        returns (address rewardToken)
    {
        rewardToken = address(new RewardToken(evc, getDeployer(), receiver, underlying, name, symbol));
    }
}

contract ERC20SynthDeployer is ScriptUtils {
    function run() public broadcast returns (address erc20Synth) {
        string memory inputScriptFileName = "00_ERC20Synth_input.json";
        string memory outputScriptFileName = "00_ERC20Synth_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        string memory name = vm.parseJsonString(json, ".name");
        string memory symbol = vm.parseJsonString(json, ".symbol");
        uint8 decimals = uint8(vm.parseJsonUint(json, ".decimals"));

        erc20Synth = execute(evc, name, symbol, decimals);

        string memory object;
        object = vm.serializeAddress("erc20Synth", "erc20Synth", erc20Synth);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, string memory name, string memory symbol, uint8 decimals)
        public
        broadcast
        returns (address erc20Synth)
    {
        erc20Synth = execute(evc, name, symbol, decimals);
    }

    function execute(address evc, string memory name, string memory symbol, uint8 decimals)
        public
        returns (address erc20Synth)
    {
        erc20Synth = address(new ERC20Synth(evc, getDeployer(), name, symbol, decimals));
    }
}
