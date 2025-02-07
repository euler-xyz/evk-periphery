// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {OFTAdapterUpgradeable} from "../src/OFT/OFTAdapterUpgradeable.sol";
import {MintBurnOFTAdapter} from "../src/OFT/MintBurnOFTAdapter.sol";

contract OFTAdapterUpgradeableDeployer is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "14_OFTAdapterUpgradeable_input.json";
        string memory outputScriptFileName = "14_OFTAdapterUpgradeable_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address token = vm.parseJsonAddress(json, ".token");
        address lzEndpoint = vm.parseJsonAddress(json, ".lzEndpoint");

        adapter = execute(token, lzEndpoint);

        string memory object;
        object = vm.serializeAddress("oftDeployer", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address token, address lzEndpoint) public broadcast returns (address adapter) {
        adapter = execute(token, lzEndpoint);
    }

    function execute(address token, address lzEndpoint) public returns (address adapter) {
        address deployer = getDeployer();
        adapter = address(new OFTAdapterUpgradeable(token, lzEndpoint));
        adapter = address(
            new TransparentUpgradeableProxy(
                adapter, deployer, abi.encodeCall(OFTAdapterUpgradeable.initialize, (deployer))
            )
        );
    }
}

contract MintBurnOFTAdapterDeployer is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "14_MintBurnOFTAdapter_input.json";
        string memory outputScriptFileName = "14_MintBurnOFTAdapter_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address token = vm.parseJsonAddress(json, ".token");
        address lzEndpoint = vm.parseJsonAddress(json, ".lzEndpoint");

        adapter = execute(token, lzEndpoint);

        string memory object;
        object = vm.serializeAddress("oftDeployer", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address token, address lzEndpoint) public broadcast returns (address adapter) {
        adapter = execute(token, lzEndpoint);
    }

    function execute(address token, address lzEndpoint) public returns (address adapter) {
        adapter = address(new MintBurnOFTAdapter(token, lzEndpoint, getDeployer()));
    }
}
