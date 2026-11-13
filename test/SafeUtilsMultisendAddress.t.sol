// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SafeMultisendBuilder} from "../script/utils/SafeUtils.s.sol";

contract MultisendAddressHarness is SafeMultisendBuilder {
    function multisendAddress(address safe) external view returns (address) {
        return _getMultisendAddress(safe, true);
    }
}

contract SafeVersionMock {
    string public VERSION;

    constructor(string memory version) {
        VERSION = version;
    }
}

contract SafeUtilsMultisendAddressTest is Test {
    MultisendAddressHarness harness;

    function setUp() public {
        harness = new MultisendAddressHarness();
    }

    function test_returnsTheCanonicalMultiSendCallOnlyForEachSafeVersion() public {
        assertEq(
            harness.multisendAddress(address(new SafeVersionMock("1.3.0"))), 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D
        );
        assertEq(
            harness.multisendAddress(address(new SafeVersionMock("1.4.1"))), 0x9641d764fc13c8B624c04430C7356C1C7C8102e2
        );
        assertEq(
            harness.multisendAddress(address(new SafeVersionMock("1.5.0"))), 0xA83c336B20401Af773B6219BA5027174338D1836
        );
    }

    function test_revertsForAnUnknownSafeVersion() public {
        address safe = address(new SafeVersionMock("1.2.0"));
        vm.expectRevert(bytes("getMultisendAddress: Unsupported Safe version: 1.2.0"));
        harness.multisendAddress(safe);
    }
}
