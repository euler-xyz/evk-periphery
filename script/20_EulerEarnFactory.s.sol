// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerEarnFactoryDeployer is ScriptUtils {
    function run() public broadcast returns (address eulerEarnfactory, address eulerEarnPublicAllocator) {
        string memory inputScriptFileName = "21_EulerEarnFactory_input.json";
        string memory outputScriptFileName = "21_EulerEarnFactory_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address permit2 = vm.parseJsonAddress(json, ".permit2");
        address perspective = vm.parseJsonAddress(json, ".perspective");

        (eulerEarnfactory, eulerEarnPublicAllocator) = execute(evc, permit2, perspective);

        string memory object;
        object = vm.serializeAddress("factory", "eulerEarnfactory", eulerEarnfactory);
        object = vm.serializeAddress("publicAllocator", "eulerEarnPublicAllocator", eulerEarnPublicAllocator);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address permit2, address perspective)
        public
        broadcast
        returns (address factory, address publicAllocator)
    {
        (factory, publicAllocator) = execute(evc, permit2, perspective);
    }

    function execute(address evc, address permit2, address perspective)
        public
        returns (address factory, address publicAllocator)
    {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-earn/EulerEarnFactory.sol/EulerEarnFactory.json"),
            abi.encode(getDeployer(), evc, permit2, perspective)
        );
        assembly {
            factory := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        bytecode =
            abi.encodePacked(vm.getCode("out-euler-earn/PublicAllocator.sol/PublicAllocator.json"), abi.encode(evc));
        assembly {
            publicAllocator := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
