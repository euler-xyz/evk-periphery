// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RedstoneCoreOracleHelper} from "euler-price-oracle-test/adapter/redstone/RedstoneCoreOracleHelper.sol";
import {OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensRedstoneCoreTest is RedstoneCoreOracleHelper {
    OracleLens lens;

    function setUp() public {
        lens = new OracleLens();
    }

    function testRedstoneCoreOracle(FuzzableState memory s) public {
        setUpState(s);
        mockPrice(s);
        setPrice(s);

        address[] memory bases = new address[](1);
        bases[0] = s.base;
        OracleDetailedInfo memory data = lens.getOracleInfo(oracle, bases, s.quote);

        assertEq(data.name, "RedstoneCoreOracle");
        RedstoneCoreOracleInfo memory oracleInfo = abi.decode(data.oracleInfo, (RedstoneCoreOracleInfo));

        assertEq(oracleInfo.base, s.base);
        assertEq(oracleInfo.quote, s.quote);
        assertEq(oracleInfo.feedId, s.feedId);
        assertEq(oracleInfo.feedDecimals, s.feedDecimals);
        assertEq(oracleInfo.maxStaleness, s.maxStaleness);
        assertEq(oracleInfo.cachePrice, s.price);
        assertEq(oracleInfo.cachePriceTimestamp, s.tsDataPackage);
    }
}
