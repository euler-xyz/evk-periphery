// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UnknownPriceOracle} from "../utils/UnknownPriceOracle.sol";
import {OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensUnknownTest is Test {
    OracleLens lens;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testUnknownOracle() public {
        address oracle = address(new UnknownPriceOracle());
        OracleDetailedInfo memory data = lens.getOracleInfo(oracle, new address[](0), new address[](0));

        assertEq(data.oracle, oracle);
        assertEq(data.name, "");
        assertEq(keccak256(data.oracleInfo), keccak256(""));
    }
}
