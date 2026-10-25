// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ScriptUtils} from "../script/utils/ScriptUtils.s.sol";
import {GovernorAccessControlV2} from "../src/Governor/GovernorAccessControlV2.sol";
import {GovernorAccessControlEmergencyV2} from "../src/Governor/GovernorAccessControlEmergencyV2.sol";

contract GovernorDetectionHarness is ScriptUtils {
    function isGovernor(address target) external view returns (bool) {
        return isGovernorAccessControlInstance(target);
    }
}

contract V1MarkerGovernor {
    function isGovernorAccessControl() external pure returns (bytes4) {
        return this.isGovernorAccessControl.selector;
    }
}

contract WrongMarkerContract {
    function isGovernorAccessControl() external pure returns (bytes4) {
        return 0xdeadbeef;
    }
}

contract ScriptUtilsGovernorDetectionTest is Test {
    GovernorDetectionHarness harness;
    address evc;
    address admin;

    function setUp() public {
        // ScriptExtended resolves the deployer from DEPLOYER_KEY at construction
        vm.setEnv("DEPLOYER_KEY", "1");
        harness = new GovernorDetectionHarness();
        evc = makeAddr("evc");
        admin = makeAddr("admin");
    }

    function test_recognisesV2Governors() public {
        assertTrue(harness.isGovernor(address(new GovernorAccessControlV2(evc, admin))));
        assertTrue(harness.isGovernor(address(new GovernorAccessControlEmergencyV2(evc, admin))));
    }

    function test_recognisesV1Governors() public {
        assertTrue(harness.isGovernor(address(new V1MarkerGovernor())));
    }

    function test_rejectsOtherAddresses() public {
        assertFalse(harness.isGovernor(address(new WrongMarkerContract())));
        assertFalse(harness.isGovernor(makeAddr("eoa")));
        assertFalse(harness.isGovernor(address(0)));
    }
}
