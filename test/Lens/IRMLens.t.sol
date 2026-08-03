// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IRMLens} from "../../src/Lens/IRMLens.sol";
import {InterestRateModelDetailedInfo, InterestRateModelType, KinkIRMInfo} from "../../src/Lens/LensTypes.sol";

contract IRMLensTest is Test {
    IRMLens lens;

    address constant KINK_FACTORY = address(0xF1);
    address constant ADAPTIVE_FACTORY = address(0xF2);
    address constant KINKY_FACTORY = address(0xF3);
    address constant CYCLICAL_FACTORY = address(0xF4);
    address constant IRM = address(0x1121);

    function setUp() public {
        lens = new IRMLens(KINK_FACTORY, ADAPTIVE_FACTORY, KINKY_FACTORY, CYCLICAL_FACTORY);
        vm.etch(KINK_FACTORY, hex"00");
        vm.etch(ADAPTIVE_FACTORY, hex"00");
        vm.etch(KINKY_FACTORY, hex"00");
        vm.etch(CYCLICAL_FACTORY, hex"00");
        vm.etch(IRM, hex"00");
        _noFactoryClaims();
    }

    function _noFactoryClaims() internal {
        bytes memory call = abi.encodeWithSignature("isValidDeployment(address)", IRM);
        vm.mockCall(KINK_FACTORY, call, abi.encode(false));
        vm.mockCall(ADAPTIVE_FACTORY, call, abi.encode(false));
        vm.mockCall(KINKY_FACTORY, call, abi.encode(false));
        vm.mockCall(CYCLICAL_FACTORY, call, abi.encode(false));
    }

    function test_zeroAddress_returnsEmpty() public view {
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(0));

        assertEq(info.interestRateModel, address(0), "no model");
        assertTrue(info.interestRateModelType == InterestRateModelType.UNKNOWN, "unknown type");
    }

    function test_kinkFactoryDeployment_isTyped() public {
        vm.mockCall(KINK_FACTORY, abi.encodeWithSignature("isValidDeployment(address)", IRM), abi.encode(true));
        vm.mockCall(IRM, abi.encodeWithSignature("baseRate()"), abi.encode(uint256(1)));
        vm.mockCall(IRM, abi.encodeWithSignature("slope1()"), abi.encode(uint256(2)));
        vm.mockCall(IRM, abi.encodeWithSignature("slope2()"), abi.encode(uint256(3)));
        vm.mockCall(IRM, abi.encodeWithSignature("kink()"), abi.encode(uint256(4)));

        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(IRM);

        assertTrue(info.interestRateModelType == InterestRateModelType.KINK, "kink type");
        KinkIRMInfo memory params = abi.decode(info.interestRateModelParams, (KinkIRMInfo));
        assertEq(params.baseRate, 1, "baseRate");
        assertEq(params.kink, 4, "kink");
    }

    /// @dev an unknown IRM whose name() returns a well-formed string
    function test_unknownIrm_withName_doesNotRevert() public {
        vm.mockCall(IRM, abi.encodeWithSignature("name()"), abi.encode("SomeOtherIRM"));

        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(IRM);

        assertEq(info.interestRateModel, IRM, "model still reported");
        assertTrue(info.interestRateModelType == InterestRateModelType.UNKNOWN, "unknown type");
    }

    /// @dev name() returning a non-string payload must not revert the query: string decoding validates offsets, so the
    /// data.length >= 32 check alone admits payloads that blow up
    function test_unknownIrm_withUndecodableName_doesNotRevert() public {
        vm.mockCall(IRM, abi.encodeWithSignature("name()"), abi.encode(type(uint256).max));

        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(IRM);

        assertEq(info.interestRateModel, IRM, "model still reported");
        assertTrue(info.interestRateModelType == InterestRateModelType.UNKNOWN, "falls back to unknown");
    }

    function test_unknownIrm_nameReverts_doesNotRevert() public {
        vm.mockCallRevert(IRM, abi.encodeWithSignature("name()"), "boom");

        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(IRM);

        assertTrue(info.interestRateModelType == InterestRateModelType.UNKNOWN, "unknown type");
    }

    /// @dev an IRM with no code at all
    function test_unknownIrm_noCode_doesNotRevert() public {
        address bare = address(0xDEAD);
        bytes memory call = abi.encodeWithSignature("isValidDeployment(address)", bare);
        vm.mockCall(KINK_FACTORY, call, abi.encode(false));
        vm.mockCall(ADAPTIVE_FACTORY, call, abi.encode(false));
        vm.mockCall(KINKY_FACTORY, call, abi.encode(false));
        vm.mockCall(CYCLICAL_FACTORY, call, abi.encode(false));

        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(bare);

        assertEq(info.interestRateModel, bare, "model reported");
        assertTrue(info.interestRateModelType == InterestRateModelType.UNKNOWN, "unknown type");
    }
}
