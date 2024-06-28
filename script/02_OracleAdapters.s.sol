// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {SnapshotRegistry} from "../src/OracleFactory/SnapshotRegistry.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {LidoOracle} from "euler-price-oracle/adapter/lido/LidoOracle.sol";
import {PythOracle} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {RedstoneCoreOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreOracle.sol";
import {CrossAdapter as CrossOracle} from "euler-price-oracle/adapter/CrossAdapter.sol";
import {UniswapV3Oracle} from "euler-price-oracle/adapter/uniswap/UniswapV3Oracle.sol";

contract ChainlinkAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory json = getInputConfig("02_ChainlinkAdapter.json");
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address feed = abi.decode(vm.parseJson(json, ".feed"), (address));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        adapter = execute(adapterRegistry, base, quote, feed, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/02_ChainlinkAdapter.json"));
    }

    function deploy(address adapterRegistry, address base, address quote, address feed, uint256 maxStaleness)
        public
        broadcast
        returns (address adapter)
    {
        adapter = execute(adapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(address adapterRegistry, address base, address quote, address feed, uint256 maxStaleness)
        public
        returns (address adapter)
    {
        adapter = address(new ChainlinkOracle(base, quote, feed, maxStaleness));
        SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract ChronicleAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory scriptFileName = "02_ChronicleAdapter.json";
        string memory json = getInputConfig(scriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address feed = abi.decode(vm.parseJson(json, ".feed"), (address));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        adapter = execute(adapterRegistry, base, quote, feed, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(address adapterRegistry, address base, address quote, address feed, uint256 maxStaleness)
        public
        broadcast
        returns (address adapter)
    {
        adapter = execute(adapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(address adapterRegistry, address base, address quote, address feed, uint256 maxStaleness)
        public
        returns (address adapter)
    {
        adapter = address(new ChronicleOracle(base, quote, feed, maxStaleness));
        SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract LidoAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory scriptFileName = "02_LidoAdapter.json";
        string memory json = getInputConfig(scriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));

        adapter = execute(adapterRegistry);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(address adapterRegistry) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry);
    }

    function execute(address adapterRegistry) public returns (address adapter) {
        adapter = address(new LidoOracle());
        SnapshotRegistry(adapterRegistry).add(adapter, LidoOracle(adapter).STETH(), LidoOracle(adapter).WSTETH());
    }
}

contract PythAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory scriptFileName = "02_PythAdapter.json";
        string memory json = getInputConfig(scriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address pyth = abi.decode(vm.parseJson(json, ".pyth"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        bytes32 feedId = abi.decode(vm.parseJson(json, ".feedId"), (bytes32));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));
        uint256 maxConfWidth = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        adapter = execute(adapterRegistry, pyth, base, quote, feedId, maxStaleness, maxConfWidth);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address adapterRegistry,
        address pyth,
        address base,
        address quote,
        bytes32 feedId,
        uint256 maxStaleness,
        uint256 maxConfWidth
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, pyth, base, quote, feedId, maxStaleness, maxConfWidth);
    }

    function execute(
        address adapterRegistry,
        address pyth,
        address base,
        address quote,
        bytes32 feedId,
        uint256 maxStaleness,
        uint256 maxConfWidth
    ) public returns (address adapter) {
        adapter = address(new PythOracle(pyth, base, quote, feedId, maxStaleness, maxConfWidth));
        SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract RedstoneAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory scriptFileName = "02_RedstoneAdapter.json";
        string memory json = getInputConfig(scriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        bytes memory feed = bytes(abi.decode(vm.parseJson(json, ".feedId"), (string)));
        uint8 feedDecimals = abi.decode(vm.parseJson(json, ".feedDecimals"), (uint8));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

        bytes32 feedId;
        assembly {
            feedId := mload(add(feed, 32))
        }

        adapter = execute(adapterRegistry, base, quote, feedId, feedDecimals, maxStaleness);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address adapterRegistry,
        address base,
        address quote,
        bytes32 feedId,
        uint8 feedDecimals,
        uint256 maxStaleness
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, base, quote, feedId, feedDecimals, maxStaleness);
    }

    function execute(
        address adapterRegistry,
        address base,
        address quote,
        bytes32 feedId,
        uint8 feedDecimals,
        uint256 maxStaleness
    ) public returns (address adapter) {
        adapter = address(new RedstoneCoreOracle(base, quote, feedId, feedDecimals, maxStaleness));
        SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract CrossAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory json = getInputConfig("02_CrossAdapter.json");
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address cross = abi.decode(vm.parseJson(json, ".cross"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        address oracleBaseCross = abi.decode(vm.parseJson(json, ".oracleBaseCross"), (address));
        address oracleCrossQuote = abi.decode(vm.parseJson(json, ".oracleCrossQuote"), (address));

        adapter = execute(adapterRegistry, base, cross, quote, oracleBaseCross, oracleCrossQuote);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/02_CrossAdapter.json"));
    }

    function deploy(
        address adapterRegistry,
        address base,
        address cross,
        address quote,
        address oracleBaseCross,
        address oracleCrossQuote
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, base, cross, quote, oracleBaseCross, oracleCrossQuote);
    }

    function execute(
        address adapterRegistry,
        address base,
        address cross,
        address quote,
        address oracleBaseCross,
        address oracleCrossQuote
    ) public returns (address adapter) {
        adapter = address(new CrossOracle(base, cross, quote, oracleBaseCross, oracleCrossQuote));
        SnapshotRegistry(adapterRegistry).add(adapter, base, quote);
    }
}

contract UniswapAdapter is ScriptUtils {
    function run() public broadcast returns (address adapter) {
        string memory json = getInputConfig("02_UniswapAdapter.json");
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address tokenA = abi.decode(vm.parseJson(json, ".tokenA"), (address));
        address tokenB = abi.decode(vm.parseJson(json, ".tokenB"), (address));
        uint24 fee = abi.decode(vm.parseJson(json, ".fee"), (uint24));
        uint32 twapWindow = abi.decode(vm.parseJson(json, ".twapWindow"), (uint32));
        address uniswapV3Factory = abi.decode(vm.parseJson(json, ".uniswapV3Factory"), (address));

        adapter = execute(adapterRegistry, tokenA, tokenB, fee, twapWindow, uniswapV3Factory);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/02_UniswapAdapter.json"));
    }

    function deploy(
        address adapterRegistry,
        address tokenA,
        address tokenB,
        uint24 fee,
        uint32 twapWindow,
        address uniswapV3Factory
    ) public broadcast returns (address adapter) {
        adapter = execute(adapterRegistry, tokenA, tokenB, fee, twapWindow, uniswapV3Factory);
    }

    function execute(
        address adapterRegistry,
        address tokenA,
        address tokenB,
        uint24 fee,
        uint32 twapWindow,
        address uniswapV3Factory
    ) public returns (address adapter) {
        adapter = address(new UniswapV3Oracle(tokenA, tokenB, fee, twapWindow, uniswapV3Factory));
        SnapshotRegistry(adapterRegistry).add(adapter, tokenA, tokenB);
    }
}
