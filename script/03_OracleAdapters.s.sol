// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {SnapshotRegistry} from "../src/SnapshotRegistry/SnapshotRegistry.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChainlinkInfrequentOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkInfrequentOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {LidoOracle} from "euler-price-oracle/adapter/lido/LidoOracle.sol";
import {LidoFundamentalOracle} from "euler-price-oracle/adapter/lido/LidoFundamentalOracle.sol";
import {PythOracle} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {RedstoneCoreOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreOracle.sol";
//import {RedstoneCoreArbitrumOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreArbitrumOracle.sol";
import {CrossAdapter} from "euler-price-oracle/adapter/CrossAdapter.sol";
import {UniswapV3Oracle} from "euler-price-oracle/adapter/uniswap/UniswapV3Oracle.sol";
import {FixedRateOracle} from "euler-price-oracle/adapter/fixed/FixedRateOracle.sol";
import {RateProviderOracle} from "euler-price-oracle/adapter/rate/RateProviderOracle.sol";
import {PendleOracle} from "euler-price-oracle/adapter/pendle/PendleOracle.sol";

contract ChainlinkAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_ChainlinkAdapter_input.json";
        string memory outputScriptFileName = "03_ChainlinkAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address feed = abi.decode(vm.parseJson(json, ".feed"), (address));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feed, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address feed,
        uint256 maxStaleness
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address feed,
        uint256 maxStaleness
    ) public returns (address adapter) {
        adapter = address(new ChainlinkOracle(base, quote, feed, maxStaleness));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract ChainlinkInfrequentAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_ChainlinkInfrequentAdapter_input.json";
        string memory outputScriptFileName = "03_ChainlinkInfrequentAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address feed = abi.decode(vm.parseJson(json, ".feed"), (address));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feed, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address feed,
        uint256 maxStaleness
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address feed,
        uint256 maxStaleness
    ) public returns (address adapter) {
        adapter = address(new ChainlinkInfrequentOracle(base, quote, feed, maxStaleness));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract ChronicleAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_ChronicleAdapter_input.json";
        string memory outputScriptFileName = "03_ChronicleAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address feed = abi.decode(vm.parseJson(json, ".feed"), (address));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feed, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address feed,
        uint256 maxStaleness
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address feed,
        uint256 maxStaleness
    ) public returns (address adapter) {
        adapter = address(new ChronicleOracle(base, quote, feed, maxStaleness));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract LidoAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_LidoAdapter_input.json";
        string memory outputScriptFileName = "03_LidoAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));

        adapter = execute(adapterRegistry, addToAdapterRegistry);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address adapterRegistry, bool addToAdapterRegistry) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry);
    }

    function execute(address adapterRegistry, bool addToAdapterRegistry) public returns (address adapter) {
        adapter = address(new LidoOracle());
        if (addToAdapterRegistry) {
            SnapshotRegistry(adapterRegistry).add(adapter, LidoOracle(adapter).WSTETH(), LidoOracle(adapter).STETH());
        }
    }
}

contract LidoFundamentalAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_LidoFundamentalAdapter_input.json";
        string memory outputScriptFileName = "03_LidoFundamentalAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));

        adapter = execute(adapterRegistry, addToAdapterRegistry);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address adapterRegistry, bool addToAdapterRegistry) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry);
    }

    function execute(address adapterRegistry, bool addToAdapterRegistry) public returns (address adapter) {
        adapter = address(new LidoFundamentalOracle());
        if (addToAdapterRegistry) {
            SnapshotRegistry(adapterRegistry).add(
                adapter, LidoFundamentalOracle(adapter).WSTETH(), LidoFundamentalOracle(adapter).WETH()
            );
        }
    }
}

contract PythAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_PythAdapter_input.json";
        string memory outputScriptFileName = "03_PythAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address pyth = abi.decode(vm.parseJson(json, ".pyth"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        bytes32 feedId = abi.decode(vm.parseJson(json, ".feedId"), (bytes32));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));
        uint256 maxConfWidth = abi.decode(vm.parseJson(json, ".maxConfWidth"), (uint256));

        adapter = execute(adapterRegistry, addToAdapterRegistry, pyth, base, quote, feedId, maxStaleness, maxConfWidth);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address pyth,
        address base,
        address quote,
        bytes32 feedId,
        uint256 maxStaleness,
        uint256 maxConfWidth
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, pyth, base, quote, feedId, maxStaleness, maxConfWidth);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address pyth,
        address base,
        address quote,
        bytes32 feedId,
        uint256 maxStaleness,
        uint256 maxConfWidth
    ) public returns (address adapter) {
        adapter = address(new PythOracle(pyth, base, quote, feedId, maxStaleness, maxConfWidth));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract RedstoneAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_RedstoneAdapter_input.json";
        string memory outputScriptFileName = "03_RedstoneAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        bytes memory feed = bytes(abi.decode(vm.parseJson(json, ".feedId"), (string)));
        uint8 feedDecimals = abi.decode(vm.parseJson(json, ".feedDecimals"), (uint8));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        bytes32 feedId;
        assembly {
            feedId := mload(add(feed, 32))
        }

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feedId, feedDecimals, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        bytes32 feedId,
        uint8 feedDecimals,
        uint256 maxStaleness
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, feedId, feedDecimals, maxStaleness);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        bytes32 feedId,
        uint8 feedDecimals,
        uint256 maxStaleness
    ) public returns (address adapter) {
        if (block.chainid == 42161) {
            //adapter = address(new RedstoneCoreArbitrumOracle(base, quote, feedId, feedDecimals, maxStaleness));
            require(false, "redstone not yet supported on arbitrum");
        } else {
            adapter = address(new RedstoneCoreOracle(base, quote, feedId, feedDecimals, maxStaleness));
        }

        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract CrossAdapterDeployer is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_CrossAdapter_input.json";
        string memory outputScriptFileName = "03_CrossAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address cross = abi.decode(vm.parseJson(json, ".cross"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address oracleBaseCross = abi.decode(vm.parseJson(json, ".oracleBaseCross"), (address));
        address oracleCrossQuote = abi.decode(vm.parseJson(json, ".oracleCrossQuote"), (address));

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, cross, quote, oracleBaseCross, oracleCrossQuote);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address cross,
        address quote,
        address oracleBaseCross,
        address oracleCrossQuote
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, cross, quote, oracleBaseCross, oracleCrossQuote);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address cross,
        address quote,
        address oracleBaseCross,
        address oracleCrossQuote
    ) public returns (address adapter) {
        adapter = address(new CrossAdapter(base, cross, quote, oracleBaseCross, oracleCrossQuote));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract UniswapAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_UniswapAdapter_input.json";
        string memory outputScriptFileName = "03_UniswapAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address tokenA = abi.decode(vm.parseJson(json, ".tokenA"), (address));
        address tokenB = abi.decode(vm.parseJson(json, ".tokenB"), (address));
        uint24 fee = abi.decode(vm.parseJson(json, ".fee"), (uint24));
        uint32 twapWindow = abi.decode(vm.parseJson(json, ".twapWindow"), (uint32));
        address uniswapV3Factory = abi.decode(vm.parseJson(json, ".uniswapV3Factory"), (address));

        adapter = execute(adapterRegistry, addToAdapterRegistry, tokenA, tokenB, fee, twapWindow, uniswapV3Factory);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address tokenA,
        address tokenB,
        uint24 fee,
        uint32 twapWindow,
        address uniswapV3Factory
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, tokenA, tokenB, fee, twapWindow, uniswapV3Factory);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address tokenA,
        address tokenB,
        uint24 fee,
        uint32 twapWindow,
        address uniswapV3Factory
    ) public returns (address adapter) {
        adapter = address(new UniswapV3Oracle(tokenA, tokenB, fee, twapWindow, uniswapV3Factory));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, tokenA, tokenB);
    }
}

contract FixedRateAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_FixedRateAdapter_input.json";
        string memory outputScriptFileName = "03_FixedRateAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        uint256 rate = abi.decode(vm.parseJson(json, ".rate"), (uint256));

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, rate);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address adapterRegistry, bool addToAdapterRegistry, address base, address quote, uint256 rate)
        public
        broadcast
        returns (address adapter)
    {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, rate);
    }

    function execute(address adapterRegistry, bool addToAdapterRegistry, address base, address quote, uint256 rate)
        public
        returns (address adapter)
    {
        adapter = address(new FixedRateOracle(base, quote, rate));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract RateProviderAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_RateProviderAdapter_input.json";
        string memory outputScriptFileName = "03_RateProviderAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address rateProvider = abi.decode(vm.parseJson(json, ".rateProvider"), (address));

        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, rateProvider);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address rateProvider
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, base, quote, rateProvider);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address base,
        address quote,
        address rateProvider
    ) public returns (address adapter) {
        adapter = address(new RateProviderOracle(base, quote, rateProvider));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract PendleAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory inputScriptFileName = "03_PendleAdapter_input.json";
        string memory outputScriptFileName = "03_PendleAdapter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        bool addToAdapterRegistry = abi.decode(vm.parseJson(json, ".addToAdapterRegistry"), (bool));
        address pendleOracle = abi.decode(vm.parseJson(json, ".pendleOracle"), (address));
        address pendleMarket = abi.decode(vm.parseJson(json, ".pendleMarket"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        uint32 twapWindow = abi.decode(vm.parseJson(json, ".twapWindow"), (uint32));

        adapter = execute(adapterRegistry, addToAdapterRegistry, pendleOracle, pendleMarket, base, quote, twapWindow);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address pendleOracle,
        address pendleMarket,
        address base,
        address quote,
        uint32 twapWindow
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, addToAdapterRegistry, pendleOracle, pendleMarket, base, quote, twapWindow);
    }

    function execute(
        address adapterRegistry,
        bool addToAdapterRegistry,
        address pendleOracle,
        address pendleMarket,
        address base,
        address quote,
        uint32 twapWindow
    ) public returns (address adapter) {
        adapter = address(new PendleOracle(pendleOracle, pendleMarket, base, quote, twapWindow));
        if (addToAdapterRegistry) SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}
