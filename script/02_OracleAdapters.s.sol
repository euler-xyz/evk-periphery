// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {AdapterRegistry} from "../src/OracleFactory/AdapterRegistry.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {LidoOracle} from "euler-price-oracle/adapter/lido/LidoOracle.sol";
import {PythOracle} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {RedstoneCoreOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreOracle.sol";

contract ChainlinkAdapter is ScriptUtils {
    function run() public startBroadcast returns (address adapter) {
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
        returns (address adapter)
    {
        adapter = execute(adapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(address adapterRegistry, address base, address quote, address feed, uint256 maxStaleness)
        internal
        returns (address adapter)
    {
        adapter = address(new ChainlinkOracle(base, quote, feed, maxStaleness));
        AdapterRegistry(adapterRegistry).addAdapter(adapter, base, quote);
    }
}

contract ChronicleAdapter is ScriptUtils {
    function run() public startBroadcast returns (address adapter) {
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
        returns (address adapter)
    {
        adapter = execute(adapterRegistry, base, quote, feed, maxStaleness);
    }

    function execute(address adapterRegistry, address base, address quote, address feed, uint256 maxStaleness)
        internal
        returns (address adapter)
    {
        adapter = address(new ChronicleOracle(base, quote, feed, maxStaleness));
        AdapterRegistry(adapterRegistry).addAdapter(adapter, base, quote);
    }
}

contract LidoAdapter is ScriptUtils {
    function run() public startBroadcast returns (address adapter) {
        string memory scriptFileName = "02_LidoAdapter.json";
        string memory json = getInputConfig(scriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));

        adapter = execute(adapterRegistry);

        string memory object;
        object = vm.serializeAddress("oracleAdapters", "adapter", adapter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(address adapterRegistry) public returns (address adapter) {
        adapter = execute(adapterRegistry);
    }

    function execute(address adapterRegistry) internal returns (address adapter) {
        adapter = address(new LidoOracle());
        AdapterRegistry(adapterRegistry).addAdapter(adapter, LidoOracle(adapter).STETH(), LidoOracle(adapter).WSTETH());
    }
}

contract PythAdapter is ScriptUtils {
    function run() public startBroadcast returns (address adapter) {
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
    ) public returns (address adapter) {
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
    ) internal returns (address adapter) {
        adapter = address(new PythOracle(pyth, base, quote, feedId, maxStaleness, maxConfWidth));
        AdapterRegistry(adapterRegistry).addAdapter(adapter, base, quote);
    }
}

contract RedstoneAdapter is ScriptUtils {
    function run() public startBroadcast returns (address adapter) {
        string memory scriptFileName = "02_RedstoneAdapter.json";
        string memory json = getInputConfig(scriptFileName);
        address adapterRegistry = abi.decode(vm.parseJson(json, ".adapterRegistry"), (address));
        address base = abi.decode(vm.parseJson(json, ".base"), (address));
        address quote = abi.decode(vm.parseJson(json, ".quote"), (address));
        bytes32 feedId = abi.decode(vm.parseJson(json, ".feedId"), (bytes32));
        uint8 feedDecimals = abi.decode(vm.parseJson(json, ".feedDecimals"), (uint8));
        uint256 maxStaleness = abi.decode(vm.parseJson(json, ".maxStaleness"), (uint256));

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
    ) public returns (address adapter) {
        adapter = execute(adapterRegistry, base, quote, feedId, feedDecimals, maxStaleness);
    }

    function execute(
        address adapterRegistry,
        address base,
        address quote,
        bytes32 feedId,
        uint8 feedDecimals,
        uint256 maxStaleness
    ) internal returns (address adapter) {
        adapter = address(new RedstoneCoreOracle(base, quote, feedId, feedDecimals, maxStaleness));
        AdapterRegistry(adapterRegistry).addAdapter(adapter, base, quote);
    }
}
