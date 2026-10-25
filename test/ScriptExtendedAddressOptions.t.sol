// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ScriptUtils} from "../script/utils/ScriptUtils.s.sol";

contract AddressOptionsHarness is ScriptUtils {
    function timelock(string memory key) external view returns (address) {
        return _getTimelock(key);
    }

    function riskSteward(string memory key) external view returns (address) {
        return _getRiskSteward(key);
    }
}

contract ScriptExtendedAddressOptionsTest is Test {
    AddressOptionsHarness harness;

    function setUp() public {
        // ScriptExtended resolves the deployer from DEPLOYER_KEY at construction
        vm.setEnv("DEPLOYER_KEY", "1");
        harness = new AddressOptionsHarness();
    }

    function test_unsetOptions_resolveToZero() public view {
        assertEq(harness.timelock("address_options_test_unset_timelock"), address(0));
        assertEq(harness.riskSteward("address_options_test_unset_risk_steward"), address(0));
    }

    function test_explicitAddresses_areUsed() public {
        address target = makeAddr("target");
        vm.setEnv("address_options_test_timelock", vm.toString(target));
        vm.setEnv("address_options_test_risk_steward", vm.toString(target));

        assertEq(harness.timelock("address_options_test_timelock"), target);
        assertEq(harness.riskSteward("address_options_test_risk_steward"), target);
    }

    function test_unresolvedTimelock_reverts() public {
        vm.setEnv("address_options_test_wildcard", "wildcard");

        vm.expectRevert(bytes("address_options_test_wildcard: not an address or a GovernorAddresses.json key"));
        harness.timelock("address_options_test_wildcard");
    }

    function test_riskStewardAlias_reverts() public {
        vm.setEnv("address_options_test_default", "default");

        vm.expectRevert(bytes("address_options_test_default: not an address"));
        harness.riskSteward("address_options_test_default");
    }
}
