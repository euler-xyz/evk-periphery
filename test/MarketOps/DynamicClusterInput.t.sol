// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {DynamicClusterInputLib} from "../../script/production/market-ops/DynamicClusterInput.s.sol";

contract DynamicClusterInputTest is Test {
    function testReadsExactDynamicClusterInput() public view {
        string memory path =
            string.concat(vm.projectRoot(), "/script/production/market-ops/example-input.json");
        (DynamicClusterInputLib.Input memory input, bytes32 inputHash) =
            DynamicClusterInputLib.read(vm, path);

        assertEq(input.schema, "evk-market-ops-cluster-input-v1");
        assertEq(input.requestHash, "sha256:1111111111111111111111111111111111111111111111111111111111111111");
        assertEq(input.chainId, 1);
        assertEq(input.blockNumber, 1);
        assertEq(input.deployer, 0x1000000000000000000000000000000000000001);
        assertEq(input.assets.length, 1);
        assertEq(input.vaults.length, 1);
        assertEq(input.oracleRouters.length, 1);
        assertEq(input.irms.length, 1);
        assertEq(input.externalVaults.length, 0);
        assertTrue(input.noStubOracle);
        assertEq(input.oracleProviderBases.length, 1);
        assertEq(input.oracleProviders.length, 1);
        assertEq(input.supplyCaps[0], 0);
        assertEq(input.borrowCaps[0], 0);
        assertEq(input.interestFee, 1000);
        assertEq(input.maxLiquidationDiscount, 1500);
        assertEq(input.liquidationCoolOffTime, 1);
        assertEq(input.rampDuration, 14 days);
        assertEq(input.spreadLTV, 200);
        assertEq(input.kinkIRMParams.length, 1);
        assertEq(input.ltvs.length, 1);
        assertEq(input.ltvs[0].length, 1);
        assertEq(input.borrowLTVsOverride[0][0], type(uint16).max);
        assertEq(input.spreadLTVOverride[0][0], type(uint16).max);
        assertTrue(inputHash != bytes32(0));
    }
}
