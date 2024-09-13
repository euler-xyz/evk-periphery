// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ChronicleOracleHelper} from "euler-price-oracle-test/adapter/chronicle/ChronicleOracleHelper.sol";
import {OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensChronicleTest is ChronicleOracleHelper {
    OracleLens lens;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testChronicleOracle(FuzzableState memory s) public {
        setUpState(s);
        OracleDetailedInfo memory data = lens.getOracleInfo(oracle, new address[](0), new address[](0));

        assertEq(data.name, "ChronicleOracle");
        ChronicleOracleInfo memory oracleInfo = abi.decode(data.oracleInfo, (ChronicleOracleInfo));

        assertEq(oracleInfo.base, s.base);
        assertEq(oracleInfo.quote, s.quote);
        assertEq(oracleInfo.feed, s.feed);
        assertEq(oracleInfo.maxStaleness, s.maxStaleness);
    }
}
