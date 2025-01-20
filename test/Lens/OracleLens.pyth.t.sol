// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PythOracleHelper} from "euler-price-oracle-test/adapter/pyth/PythOracleHelper.sol";
import {OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensPythTest is PythOracleHelper {
    OracleLens lens;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testPythOracle(FuzzableState memory s) public {
        setUpState(s);
        OracleDetailedInfo memory data = lens.getOracleInfo(oracle, new address[](0), new address[](0));

        assertEq(data.name, "PythOracle");
        PythOracleInfo memory oracleInfo = abi.decode(data.oracleInfo, (PythOracleInfo));

        assertEq(oracleInfo.base, s.base);
        assertEq(oracleInfo.quote, s.quote);
        assertEq(oracleInfo.feedId, s.feedId);
        assertEq(oracleInfo.maxStaleness, s.maxStaleness);
        assertEq(oracleInfo.maxConfWidth, s.maxConfWidth);
    }
}
