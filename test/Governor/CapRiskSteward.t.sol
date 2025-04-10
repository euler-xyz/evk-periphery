// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {CapRiskSteward} from "../../src/Governor/CapRiskSteward.sol";
import {GovernorAccessControl} from "../../src/Governor/GovernorAccessControl.sol";
import {EulerKinkIRMFactory, IRMLinearKink} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import {AmountCap} from "evk/EVault/shared/types/Types.sol";
import "evk/EVault/shared/Constants.sol";

contract MockTarget {
    function foo() external pure returns (uint256) {
        return 1;
    }

    function bar() external pure returns (bytes memory) {
        return abi.encode(2);
    }
}

contract CapRiskStewardTest is EVaultTestBase {
    MockTarget public mockTarget;
    EulerKinkIRMFactory public irmFactory;
    GovernorAccessControl public governorAccessControl;
    CapRiskSteward public capRiskSteward;
    address public steward;
    address public otherUser;
    uint256 public constant MAX_ADJUST_FACTOR = 1.5e18;
    uint256 public constant CHARGE_INTERVAL = 3 days;

    function setUp() public override {
        super.setUp();

        steward = makeAddr("steward");
        otherUser = makeAddr("otherUser");
        mockTarget = new MockTarget();
        irmFactory = new EulerKinkIRMFactory();
        governorAccessControl = new GovernorAccessControl(address(evc), admin);
        capRiskSteward = new CapRiskSteward(
            address(governorAccessControl), address(irmFactory), admin, MAX_ADJUST_FACTOR, CHARGE_INTERVAL
        );

        eTST.setCaps(_encodeCap(6000e18), _encodeCap(600e18));
        eTST.setGovernorAdmin(address(governorAccessControl));
        eTST2.setCaps(_encodeCap(type(uint256).max), _encodeCap(type(uint256).max));
        eTST2.setGovernorAdmin(address(governorAccessControl));

        vm.startPrank(admin);
        governorAccessControl.grantRole(governorAccessControl.WILD_CARD(), address(capRiskSteward));
        capRiskSteward.grantRole(IGovernance.setCaps.selector, steward);
        capRiskSteward.grantRole(IGovernance.setInterestRateModel.selector, steward);
        vm.stopPrank();
    }

    function test_setCaps_unlimited() public {
        vm.startPrank(steward);
        vm.warp(1_000_000);

        (bool success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(
                    IGovernance.setCaps, (_encodeCap(type(uint256).max / 1e18), _encodeCap(type(uint256).max / 1e18))
                ),
                address(eTST2)
            )
        );
        assertFalse(success);
    }

    function test_setCaps_saneAmount() public {
        vm.prank(eTST2.governorAdmin());
        eTST2.setCaps(_encodeCap(2 * MAX_SANE_AMOUNT), _encodeCap(MAX_SANE_AMOUNT));
        vm.stopPrank();

        vm.startPrank(steward);
        vm.warp(1_000_000);
        uint256 snapshot = vm.snapshot();

        // Disallow increase over MAX_SANE_AMOUNT
        (bool success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(
                    IGovernance.setCaps, (_encodeCap(2 * MAX_SANE_AMOUNT) + 1, _encodeCap(MAX_SANE_AMOUNT) + 1)
                ),
                address(eTST2)
            )
        );
        assertFalse(success);

        // Allow decrease under MAX_SANE_AMOUNT
        vm.revertTo(snapshot);
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(
                    IGovernance.setCaps, (_encodeCap(3 * MAX_SANE_AMOUNT / 2), _encodeCap(2 * MAX_SANE_AMOUNT / 3))
                ),
                address(eTST2)
            )
        );
        assertTrue(success);
    }

    function test_setCaps_fullCapacity() public {
        vm.startPrank(steward);
        vm.warp(1_000_000);
        uint256 snapshot = vm.snapshot();

        // Allow 1.5x increase (max)
        (bool success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(9000e18), _encodeCap(900e18))), address(eTST)
            )
        );
        assertTrue(success);

        // Disallow increase over max
        vm.revertTo(snapshot);
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(9001e18), _encodeCap(901e18))), address(eTST)
            )
        );
        assertFalse(success);

        // Allow 1.5x decrease (min)
        vm.revertTo(snapshot);
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(4000e18), _encodeCap(400e18))), address(eTST)
            )
        );
        assertTrue(success);

        // Disallow decrease under min
        vm.revertTo(snapshot);
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(3999e18), _encodeCap(399e18))), address(eTST)
            )
        );
        assertFalse(success);
    }

    function test_setCaps_partialCapacity() public {
        vm.startPrank(steward);
        vm.warp(1_000_000);
        // Increase the cap by 1.5x
        (bool success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(9000e18), _encodeCap(900e18))), address(eTST)
            )
        );
        assertTrue(success);

        // Only a fifth of the adjust capacity is available (1.1x)
        vm.warp(1_000_000 + capRiskSteward.CHARGE_INTERVAL() / 5);
        uint256 snapshot = vm.snapshot();

        // Allow 1.1x increase (max)
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(9900e18), _encodeCap(990e18))), address(eTST)
            )
        );
        assertTrue(success);

        // Disallow increase over max
        vm.revertTo(snapshot);
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(9901e18), _encodeCap(991e18))), address(eTST)
            )
        );
        assertFalse(success);

        // Allow 1.1x decrease (min)
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(8190e18), _encodeCap(819e18))), address(eTST)
            )
        );
        assertTrue(success);

        // Disallow decrease under min
        vm.revertTo(snapshot);
        (success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setCaps, (_encodeCap(8180e18), _encodeCap(818e18))), address(eTST)
            )
        );
        assertFalse(success);
    }

    function test_setIRM_invalidIRM() public {
        vm.startPrank(steward);
        (bool success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setInterestRateModel, (address(new IRMLinearKink(0, 0, 0, 0)))),
                address(eTST)
            )
        );
        assertFalse(success);
    }

    function test_setIRM_validIRM() public {
        vm.startPrank(steward);
        (bool success,) = address(capRiskSteward).call(
            abi.encodePacked(
                abi.encodeCall(IGovernance.setInterestRateModel, (irmFactory.deploy(0, 0, 0, 0))), address(eTST)
            )
        );
        assertTrue(success);
    }

    function test_reflection() public view {
        assertEq(capRiskSteward.isCapRiskSteward(), CapRiskSteward.isCapRiskSteward.selector);
    }

    function _encodeCap(uint256 value) internal pure returns (uint16) {
        if (value == type(uint256).max) return 0;

        // Find the appropriate exponent
        uint8 exponent = 0;
        uint256 scaledValue = value * 100; // Scale by 100 as per the format

        // Adjust the value and exponent until the mantissa fits in 10 bits (max 1023)
        while (scaledValue > 1023) {
            scaledValue /= 10;
            exponent++;

            // Safety check to prevent infinite loops
            require(exponent < 63);
        }

        // Combine mantissa and exponent into a single uint16
        return uint16(scaledValue << 6 | exponent);
    }
}
