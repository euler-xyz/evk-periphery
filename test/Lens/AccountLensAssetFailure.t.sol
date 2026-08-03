// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {AccountLens} from "../../src/Lens/AccountLens.sol";
import {VaultAccountInfo} from "../../src/Lens/LensTypes.sol";

/// @dev asset() is metadata; the position data below it does not depend on it and must still be reported.
contract AccountLensAssetFailureTest is Test {
    AccountLens lens;

    address constant VAULT = address(0xBEEF);
    address constant EVC = address(0xE7C);
    address constant ACCOUNT = address(0xA11CE);

    function setUp() public {
        lens = new AccountLens();
        vm.etch(VAULT, hex"00");
        vm.etch(EVC, hex"00");

        // asset() is the only broken read
        vm.mockCallRevert(VAULT, abi.encodeCall(IEVault(VAULT).asset, ()), "no-asset");

        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).balanceOf, (ACCOUNT)), abi.encode(uint256(1234)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).convertToAssets, (uint256(1234))), abi.encode(uint256(9999)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).debtOf, (ACCOUNT)), abi.encode(uint256(42)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).permit2Address, ()), abi.encode(address(0)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).balanceForwarderEnabled, (ACCOUNT)), abi.encode(true));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).EVC, ()), abi.encode(EVC));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isControllerEnabled, (ACCOUNT, VAULT)), abi.encode(true));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isCollateralEnabled, (ACCOUNT, VAULT)), abi.encode(true));

        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).unitOfAccount, ()), abi.encode(address(0xABCD)));
        vm.mockCall(
            VAULT, abi.encodeCall(IEVault(VAULT).accountLiquidity, (ACCOUNT, false)), abi.encode(uint256(5), uint256(3))
        );
        vm.mockCall(
            VAULT, abi.encodeCall(IEVault(VAULT).accountLiquidity, (ACCOUNT, true)), abi.encode(uint256(6), uint256(4))
        );
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidityFull, (ACCOUNT, false)),
            abi.encode(new address[](0), new uint256[](0), uint256(0))
        );
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).accountLiquidityFull, (ACCOUNT, true)),
            abi.encode(new address[](0), new uint256[](0), uint256(0))
        );
    }

    function test_assetFailure_stillReportsPosition() public {
        VaultAccountInfo memory info = lens.getVaultAccountInfo(ACCOUNT, VAULT);

        assertTrue(info.queryFailure, "failure is still flagged");
        assertEq(info.asset, address(0), "asset unresolved");

        // everything independent of the asset survives
        assertEq(info.shares, 1234, "shares");
        assertEq(info.assets, 9999, "assets");
        assertEq(info.borrowed, 42, "borrowed");
        assertTrue(info.balanceForwarderEnabled, "balanceForwarderEnabled");
        assertTrue(info.isController, "isController");
        assertTrue(info.isCollateral, "isCollateral");

        // and the nested liquidity struct is populated for real rather than left default
        assertEq(info.liquidityInfo.vault, VAULT, "liquidityInfo populated");
        assertEq(info.liquidityInfo.collateralValueBorrowing, 5, "liquidity borrowing value");
        assertEq(info.liquidityInfo.liabilityValueBorrowing, 3, "liquidity liability value");
        assertFalse(info.liquidityInfo.queryFailure, "liquidity itself succeeded, so its flag is honestly false");
    }

    /// @dev the asset-dependent reads must degrade rather than revert
    function test_assetFailure_assetDependentFieldsZero() public {
        VaultAccountInfo memory info = lens.getVaultAccountInfo(ACCOUNT, VAULT);

        assertEq(info.assetsAccount, 0, "assetsAccount");
        assertEq(info.assetAllowanceVault, 0, "assetAllowanceVault");
        assertEq(info.assetAllowancePermit2, 0, "assetAllowancePermit2");
    }

    /// @dev a vault advertising permit2 while asset() fails must not revert on the high-level allowance call
    function test_assetFailure_withPermit2Advertised_doesNotRevert() public {
        address permit2 = address(0x2222);
        vm.etch(permit2, hex"00");
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).permit2Address, ()), abi.encode(permit2));

        VaultAccountInfo memory info = lens.getVaultAccountInfo(ACCOUNT, VAULT);

        assertEq(info.assetAllowanceVaultPermit2, 0, "permit2 allowances skipped when the asset is unknown");
        assertEq(info.shares, 1234, "position data still reported");
    }
}
