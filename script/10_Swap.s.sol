// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {Swapper} from "../src/Swaps/Swapper.sol";
import {SwapVerifier} from "../src/Swaps/SwapVerifier.sol";
import {OneInchHandler} from "../src/Swaps/handlers/OneInchHandler.sol";
import {UniswapV2Handler} from "../src/Swaps/handlers/UniswapV2Handler.sol";
import {UniswapV3Handler} from "../src/Swaps/handlers/UniswapV3Handler.sol";
import {UniswapAutoRouterHandler} from "../src/Swaps/handlers/UniswapAutoRouterHandler.sol";

contract Swap is ScriptUtils {
    function run() public broadcast returns (address swapper, address swapVerifier) {
        string memory scriptFileName = "10_Swap.json";
        string memory json = getInputConfig(scriptFileName);
        address oneInchAggregator = abi.decode(vm.parseJson(json, ".oneInchAggregator"), (address));
        address uniswapRouterV2 = abi.decode(vm.parseJson(json, ".uniswapRouterV2"), (address));
        address uniswapRouterV3 = abi.decode(vm.parseJson(json, ".uniswapRouterV3"), (address));
        address uniswapRouter02 = abi.decode(vm.parseJson(json, ".uniswapRouter02"), (address));

        (swapper, swapVerifier) = execute(oneInchAggregator, uniswapRouterV2, uniswapRouterV3, uniswapRouter02);

        string memory object;
        object = vm.serializeAddress("swap", "swapper", swapper);
        object = vm.serializeAddress("swap", "swapVerifier", swapVerifier);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address oneInchAggregator,
        address uniswapRouterV2,
        address uniswapRouterV3,
        address uniswapRouter02
    ) public broadcast returns (address swapper, address swapVerifier) {
        (swapper, swapVerifier) = execute(oneInchAggregator, uniswapRouterV2, uniswapRouterV3, uniswapRouter02);
    }

    function execute(
        address oneInchAggregator,
        address uniswapRouterV2,
        address uniswapRouterV3,
        address uniswapRouter02
    ) public returns (address swapper, address swapVerifier) {
        swapper = address(new Swapper(oneInchAggregator, uniswapRouterV2, uniswapRouterV3, uniswapRouter02));
        swapVerifier = address(new SwapVerifier());
    }
}
