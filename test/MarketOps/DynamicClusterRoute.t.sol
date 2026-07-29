// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {DynamicCluster} from "../../script/production/market-ops/DynamicCluster.s.sol";

contract DynamicClusterRouteHarness is DynamicCluster {
    function validate(
        string memory kind,
        bool viaSafe,
        address safe,
        address timelock,
        address riskSteward,
        bool emergency
    ) external pure {
        validateRouteConfig(kind, viaSafe, safe, timelock, riskSteward, emergency);
    }
}

contract DynamicClusterRouteTest is Test {
    DynamicClusterRouteHarness private harness;

    function setUp() public {
        harness = new DynamicClusterRouteHarness();
    }

    function testAcceptsExplicitRouteEvidence() public view {
        harness.validate("deployer-direct", false, address(0), address(0), address(0), false);
        harness.validate("safe", true, address(1), address(0), address(0), false);
        harness.validate("safe-timelock", true, address(1), address(2), address(0), false);
        harness.validate("timelock", false, address(0), address(2), address(0), false);
        harness.validate("risk-steward", true, address(1), address(0), address(3), false);
        harness.validate("emergency", true, address(1), address(0), address(0), true);
    }

    function testRejectsRouteClaimWithoutRequiredEvidence() public {
        vm.expectRevert("DynamicCluster: safe route");
        harness.validate("safe", false, address(0), address(0), address(0), false);

        vm.expectRevert("DynamicCluster: safe timelock route");
        harness.validate("safe-timelock", true, address(1), address(0), address(0), false);

        vm.expectRevert("DynamicCluster: risk steward route");
        harness.validate("risk-steward", false, address(0), address(0), address(0), false);

        vm.expectRevert("DynamicCluster: emergency route");
        harness.validate("emergency", true, address(1), address(0), address(0), false);
    }

    function testRejectsUnsupportedRoute() public {
        vm.expectRevert("DynamicCluster: unsupported route");
        harness.validate("browser-selected", false, address(0), address(0), address(0), false);
    }
}
