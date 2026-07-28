// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import {LTVInfo} from "../../src/Lens/LensTypes.sol";

/// @dev getRecognizedCollateralsLTVInfo compacts a sparse list into a smaller array. Probing the index it writes with.
contract VaultLensLTVCompactionTest is Test {
    VaultLens lens;

    address constant VAULT = address(0xBEEF);
    address constant COLL_A = address(0xA1);
    address constant COLL_B = address(0xB2);
    address constant COLL_C = address(0xC3);

    function setUp() public {
        vm.chainId(1);
        lens = new VaultLens(address(0x1), address(0x2), address(0x3));
        vm.etch(VAULT, hex"00");
    }

    function _mockLTV(address collateral, uint256 targetTimestamp) internal {
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).LTVFull, (collateral)),
            abi.encode(uint16(8000), uint16(9000), uint16(9000), uint48(targetTimestamp), uint32(0))
        );
    }

    /// @dev every collateral recognized: sizes match, so the index happens to line up
    function test_allRecognized_works() public {
        address[] memory list = new address[](2);
        list[0] = COLL_A;
        list[1] = COLL_B;
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVList, ()), abi.encode(list));
        _mockLTV(COLL_A, 1);
        _mockLTV(COLL_B, 1);

        LTVInfo[] memory info = lens.getRecognizedCollateralsLTVInfo(VAULT);

        assertEq(info.length, 2, "both recognized");
        assertEq(info[0].collateral, COLL_A, "A");
        assertEq(info[1].collateral, COLL_B, "B");
    }

    /// @dev an unrecognized collateral BEFORE a recognized one: output array is shorter than the index used
    function test_unrecognizedFirst_recognizedLater() public {
        address[] memory list = new address[](3);
        list[0] = COLL_A;
        list[1] = COLL_B;
        list[2] = COLL_C;
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVList, ()), abi.encode(list));
        _mockLTV(COLL_A, 0); // not recognized
        _mockLTV(COLL_B, 0); // not recognized
        _mockLTV(COLL_C, 1); // recognized, at index 2, into a length-1 array

        LTVInfo[] memory info = lens.getRecognizedCollateralsLTVInfo(VAULT);

        assertEq(info.length, 1, "one recognized");
        assertEq(info[0].collateral, COLL_C, "the recognized collateral must be compacted to slot 0");
    }

    /// @dev trailing unrecognized entries leave silent gaps rather than reverting
    function test_recognizedFirst_unrecognizedLater() public {
        address[] memory list = new address[](2);
        list[0] = COLL_A;
        list[1] = COLL_B;
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVList, ()), abi.encode(list));
        _mockLTV(COLL_A, 1); // recognized
        _mockLTV(COLL_B, 0); // not

        LTVInfo[] memory info = lens.getRecognizedCollateralsLTVInfo(VAULT);

        assertEq(info.length, 1, "one recognized");
        assertEq(info[0].collateral, COLL_A, "A compacted to slot 0");
    }
}
