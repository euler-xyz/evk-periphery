// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ChainlinkOracleHelper} from "euler-price-oracle-test/adapter/chainlink/ChainlinkOracleHelper.sol";
import {IOracle, OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensChainlinkTest is ChainlinkOracleHelper {
    OracleLens lens;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testChainlinkOracle(FuzzableState memory s) public {
        setUpState(s);
        vm.mockCall(s.feed, abi.encodeCall(IOracle.description, ()), abi.encode("Oracle Description"));

        OracleDetailedInfo memory data = lens.getOracleInfo(oracle, new address[](0), new address[](0));

        assertEq(data.name, "ChainlinkOracle");
        ChainlinkOracleInfo memory oracleInfo = abi.decode(data.oracleInfo, (ChainlinkOracleInfo));

        assertEq(oracleInfo.base, s.base);
        assertEq(oracleInfo.quote, s.quote);
        assertEq(oracleInfo.feed, s.feed);
        assertEq(oracleInfo.feedDescription, "Oracle Description");
        assertEq(oracleInfo.maxStaleness, s.maxStaleness);
    }
}
