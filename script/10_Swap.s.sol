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
        string memory json = getInputConfig(inputScriptFileName);
        address uniswapRouterV2 = vm.parseJsonAddress(json, ".uniswapRouterV2");
        address uniswapRouterV3 = vm.parseJsonAddress(json, ".uniswapRouterV3");

        (swapper, swapVerifier) = execute(uniswapRouterV2, uniswapRouterV3);

        string memory object;
        object = vm.serializeAddress("swap", "swapper", swapper);
        object = vm.serializeAddress("swap", "swapVerifier", swapVerifier);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address uniswapRouterV2, address uniswapRouterV3)
        public
        broadcast
        returns (address swapper, address swapVerifier)
    {
        (swapper, swapVerifier) = execute(uniswapRouterV2, uniswapRouterV3);
    }

    function execute(address uniswapRouterV2, address uniswapRouterV3)
        public
        returns (address swapper, address swapVerifier)
    {
        swapper = address(new Swapper(uniswapRouterV2, uniswapRouterV3));
        swapVerifier = address(new SwapVerifier());
    }
}
