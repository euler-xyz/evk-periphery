// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {Swapper} from "../src/Swaps/Swapper.sol";
import {SwapVerifier} from "../src/Swaps/SwapVerifier.sol";
import {GenericHandler} from "../src/Swaps/handlers/GenericHandler.sol";
import {UniswapV2Handler} from "../src/Swaps/handlers/UniswapV2Handler.sol";
import {UniswapV3Handler} from "../src/Swaps/handlers/UniswapV3Handler.sol";

contract Swap is ScriptUtils {
    function run() public broadcast returns (address swapper, address swapVerifier) {
        string memory inputScriptFileName = "10_Swap_input.json";
        string memory outputScriptFileName = "10_Swap_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address uniswapRouterV2 = vm.parseJsonAddress(json, ".uniswapRouterV2");
        address uniswapRouterV3 = vm.parseJsonAddress(json, ".uniswapRouterV3");
        address evc = vm.parseJsonAddress(json, ".evc");
        address permit2 = vm.parseJsonAddress(json, ".permit2");

        (swapper, swapVerifier) = execute(evc, permit2, uniswapRouterV2, uniswapRouterV3);

        string memory object;
        object = vm.serializeAddress("swap", "swapper", swapper);
        object = vm.serializeAddress("swap", "swapVerifier", swapVerifier);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address permit2, address uniswapRouterV2, address uniswapRouterV3)
        public
        broadcast
        returns (address swapper, address swapVerifier)
    {
        (swapper, swapVerifier) = execute(evc, permit2, uniswapRouterV2, uniswapRouterV3);
    }

    function execute(address evc, address permit2, address uniswapRouterV2, address uniswapRouterV3)
        public
        returns (address swapper, address swapVerifier)
    {
        swapper = address(new Swapper(uniswapRouterV2, uniswapRouterV3));
        swapVerifier = address(new SwapVerifier(evc, permit2));
    }
}
