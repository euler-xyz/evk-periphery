// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {CrossAdapter} from "euler-price-oracle/adapter/CrossAdapter.sol";
import {distinct} from "euler-price-oracle-test/utils/TestUtils.sol";
import {IOracle, OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensCrossTest is Test {
    OracleLens lens;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testCrossAdapter(
        address base,
        address cross,
        address quote,
        address chainlinkFeed,
        address chronicleFeed,
        uint256 chainlinkMaxStaleness,
        uint256 chronicleMaxStaleness
    ) public {
        base = boundAddr(base);
        cross = boundAddr(cross);
        quote = boundAddr(quote);
        chainlinkFeed = boundAddr(chainlinkFeed);
        chronicleFeed = boundAddr(chronicleFeed);
        vm.assume(distinct(base, cross, quote, chainlinkFeed, chronicleFeed));

        vm.mockCall(base, abi.encodeCall(IERC20.decimals, ()), abi.encode(18));
        vm.mockCall(cross, abi.encodeCall(IERC20.decimals, ()), abi.encode(18));
        vm.mockCall(quote, abi.encodeCall(IERC20.decimals, ()), abi.encode(18));
        vm.mockCall(chainlinkFeed, abi.encodeCall(IERC20.decimals, ()), abi.encode(18));
        vm.mockCall(chronicleFeed, abi.encodeCall(IERC20.decimals, ()), abi.encode(18));
        vm.mockCall(chainlinkFeed, abi.encodeCall(IOracle.description, ()), abi.encode("Chainlink Description"));

        chainlinkMaxStaleness = bound(chainlinkMaxStaleness, 1 minutes, 72 hours);
        chronicleMaxStaleness = bound(chronicleMaxStaleness, 1 minutes, 72 hours);

        ChainlinkOracle oracleBaseCross = new ChainlinkOracle(base, cross, chainlinkFeed, chainlinkMaxStaleness);
        ChronicleOracle oracleCrossQuote = new ChronicleOracle(base, cross, chronicleFeed, chronicleMaxStaleness);
        CrossAdapter crossAdapter =
            new CrossAdapter(base, cross, quote, address(oracleBaseCross), address(oracleCrossQuote));

        OracleDetailedInfo memory crossAdapterData =
            lens.getOracleInfo(address(crossAdapter), arrOf(base), arrOf(quote));
        OracleDetailedInfo memory oracleBaseCrossData =
            lens.getOracleInfo(address(oracleBaseCross), arrOf(base), arrOf(cross));
        OracleDetailedInfo memory oracleCrossQuoteData =
            lens.getOracleInfo(address(oracleCrossQuote), arrOf(cross), arrOf(quote));

        assertEq(crossAdapterData.name, "CrossAdapter");
        CrossAdapterInfo memory crossAdapterInfo = abi.decode(crossAdapterData.oracleInfo, (CrossAdapterInfo));

        assertEq(crossAdapterInfo.base, base);
        assertEq(crossAdapterInfo.cross, cross);
        assertEq(crossAdapterInfo.quote, quote);
        assertEq(crossAdapterInfo.oracleBaseCross, address(oracleBaseCross));
        assertEq(crossAdapterInfo.oracleCrossQuote, address(oracleCrossQuote));

        assertEq(
            keccak256(abi.encode(crossAdapterInfo.oracleBaseCrossInfo)), keccak256(abi.encode(oracleBaseCrossData))
        );
        assertEq(
            keccak256(abi.encode(crossAdapterInfo.oracleCrossQuoteInfo)), keccak256(abi.encode(oracleCrossQuoteData))
        );
    }

    function arrOf(address e0) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = e0;
        return arr;
    }

    function boundAddr(address addr) internal pure returns (address) {
        if (
            uint160(addr) < 256 || addr == 0x4e59b44847b379578588920cA78FbF26c0B4956C
                || addr == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || addr == 0x000000000000000000636F6e736F6c652e6c6f67
                || addr == 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f || addr == 0x2e234DAe75C793f67A35089C9d99245E1C58470b
                || addr == 0x104fBc016F4bb334D775a19E8A6510109AC63E00 || addr == 0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2
                || addr == 0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
        ) return address(uint160(addr) + 256);

        return addr;
    }
}
