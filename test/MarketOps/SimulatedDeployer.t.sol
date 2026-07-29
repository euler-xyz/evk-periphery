// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ScriptExtended} from "../../script/utils/ScriptExtended.s.sol";

contract SimulatedDeployerHarness is ScriptExtended {
    function deployer() external view returns (address) {
        return getDeployer();
    }
}

contract SimulatedDeployerTest is Test {
    function testUsesRequestScopedDeployerWithoutPrivateKey() public {
        address expected = 0x1000000000000000000000000000000000000001;
        vm.setEnv("MARKET_OPS_DEPLOYER", vm.toString(expected));

        SimulatedDeployerHarness harness = new SimulatedDeployerHarness();

        assertEq(harness.deployer(), expected);
    }
}
