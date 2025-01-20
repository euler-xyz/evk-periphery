// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LidoOracleHelper} from "euler-price-oracle-test/adapter/lido/LidoOracleHelper.sol";
import {OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensLidoTest is LidoOracleHelper {
    OracleLens lens;
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testLidoOracle(FuzzableState memory s) public {
        setUpState(s);
        OracleDetailedInfo memory data = lens.getOracleInfo(oracle, new address[](0), new address[](0));

        assertEq(data.name, "LidoOracle");
        LidoOracleInfo memory oracleInfo = abi.decode(data.oracleInfo, (LidoOracleInfo));

        assertEq(oracleInfo.base, WSTETH);
        assertEq(oracleInfo.quote, STETH);
    }
}
