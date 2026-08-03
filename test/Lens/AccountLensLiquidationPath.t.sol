// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {AccountLens} from "../../src/Lens/AccountLens.sol";
import {AccountLiquidityInfo} from "../../src/Lens/LensTypes.sol";

/// @dev accountLiquidityFull returns the raw EVC-enabled collateral list, so user-controlled addresses reach the lens
/// and _calculateTimeToLiquidation calls each of them. These are the queries a liquidation bot depends on.
contract AccountLensLiquidationPathTest is Test {
    AccountLens lens;

    address constant VAULT = address(0xBEEF);
    address constant GOOD = address(0x600D);
    address constant HOSTILE = address(0xBAD);
    address constant UOA = address(0xABCD);
    address constant ACCOUNT = address(0xA11CE);

    function setUp() public {
        lens = new AccountLens();
        vm.etch(VAULT, hex"00");
        vm.etch(GOOD, hex"00");
        vm.etch(HOSTILE, hex"00");

        address[] memory collaterals = new address[](2);
        collaterals[0] = GOOD;
        collaterals[1] = HOSTILE;

        uint256[] memory values = new uint256[](2);
        values[0] = 900;
        values[1] = 100;

        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).unitOfAccount, ()), abi.encode(UOA));
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidity, (ACCOUNT, false)),
            abi.encode(uint256(1000), uint256(100))
        );
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidity, (ACCOUNT, true)),
            abi.encode(uint256(1000), uint256(100))
        );
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidityFull, (ACCOUNT, false)),
            abi.encode(collaterals, values, uint256(100))
        );
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidityFull, (ACCOUNT, true)),
            abi.encode(collaterals, values, uint256(100))
        );
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVLiquidation, (GOOD)), abi.encode(uint16(9000)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVLiquidation, (HOSTILE)), abi.encode(uint16(0)));
        // non-zero borrow rate so the time-to-liquidation search actually runs the collateral loop
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).interestRate, ()), abi.encode(uint256(1e9)));

        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).interestRate, ()), abi.encode(uint256(1e9)));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).totalBorrows, ()), abi.encode(uint256(1)));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).cash, ()), abi.encode(uint256(1)));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).interestFee, ()), abi.encode(uint256(0)));
    }

    /// @dev hostile collateral reverts every read the lens makes against it
    function _hostileReverts() internal {
        vm.mockCallRevert(HOSTILE, abi.encodeCall(IEVault(HOSTILE).interestRate, ()), "boom");
        vm.mockCallRevert(HOSTILE, abi.encodeCall(IEVault(HOSTILE).totalBorrows, ()), "boom");
        vm.mockCallRevert(HOSTILE, abi.encodeCall(IEVault(HOSTILE).cash, ()), "boom");
        vm.mockCallRevert(HOSTILE, abi.encodeCall(IEVault(HOSTILE).interestFee, ()), "boom");
    }

    /// @dev hostile collateral returns undecodable payloads instead
    function _hostileGarbage() internal {
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).interestRate, ()), hex"ab");
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).totalBorrows, ()), abi.encode(type(uint256).max));
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).cash, ()), hex"");
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).interestFee, ()), abi.encode(type(uint256).max));
    }

    function test_getAccountLiquidityInfo_survivesRevertingCollateral() public {
        _hostileReverts();

        AccountLiquidityInfo memory info = lens.getAccountLiquidityInfo(ACCOUNT, VAULT);

        assertFalse(info.queryFailure, "vault answered, so the query succeeded");
        assertEq(info.collaterals.length, 2, "both collaterals reported");
        assertEq(info.liabilityValueLiquidation, 100, "liability intact");
        assertEq(info.collateralValueLiquidation, 1000, "collateral value intact");
    }

    function test_getAccountLiquidityInfo_survivesGarbageCollateral() public {
        _hostileGarbage();

        AccountLiquidityInfo memory info = lens.getAccountLiquidityInfo(ACCOUNT, VAULT);

        assertFalse(info.queryFailure, "vault answered, so the query succeeded");
        assertEq(info.collaterals.length, 2, "both collaterals reported");
    }

    function test_getTimeToLiquidation_survivesRevertingCollateral() public {
        _hostileReverts();
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidityFull, (ACCOUNT, true)),
            abi.encode(_collaterals(), _values(), uint256(100))
        );

        lens.getTimeToLiquidation(ACCOUNT, VAULT);
    }

    function test_getTimeToLiquidation_survivesGarbageCollateral() public {
        _hostileGarbage();

        lens.getTimeToLiquidation(ACCOUNT, VAULT);
    }

    function _collaterals() internal pure returns (address[] memory c) {
        c = new address[](2);
        c[0] = GOOD;
        c[1] = HOSTILE;
    }

    function _values() internal pure returns (uint256[] memory v) {
        v = new uint256[](2);
        v[0] = 900;
        v[1] = 100;
    }
}
