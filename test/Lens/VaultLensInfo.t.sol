// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import {VaultInfoStatic, LTVInfo} from "../../src/Lens/LensTypes.sol";

contract VaultLensInfoTest is Test {
    VaultLens lens;

    address constant VAULT = address(0xBEEF);
    address constant ASSET = address(0xCAFE);
    address constant UOA = address(0xABCD);
    address constant EVC = address(0xE7C);

    function setUp() public {
        vm.chainId(1);
        lens = new VaultLens(address(0x1), address(0x2), address(0x3));
        vm.etch(VAULT, hex"00");
        vm.etch(ASSET, hex"00");
        vm.etch(UOA, hex"00");

        vm.mockCall(VAULT, abi.encodeWithSignature("name()"), abi.encode("Euler Vault"));
        vm.mockCall(VAULT, abi.encodeWithSignature("symbol()"), abi.encode("eVLT"));
        vm.mockCall(VAULT, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).asset, ()), abi.encode(ASSET));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).unitOfAccount, ()), abi.encode(UOA));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).dToken, ()), abi.encode(address(0xD70C)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).oracle, ()), abi.encode(address(0x0AC1)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).EVC, ()), abi.encode(EVC));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).protocolConfigAddress, ()), abi.encode(address(0xC0F1)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).balanceTrackerAddress, ()), abi.encode(address(0x8A1A)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).permit2Address, ()), abi.encode(address(0x9E12)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).creator, ()), abi.encode(address(0xC8EA)));

        vm.mockCall(ASSET, abi.encodeWithSignature("name()"), abi.encode("Asset"));
        vm.mockCall(ASSET, abi.encodeWithSignature("symbol()"), abi.encode("AST"));
        vm.mockCall(ASSET, abi.encodeWithSignature("decimals()"), abi.encode(uint8(6)));
        vm.mockCall(UOA, abi.encodeWithSignature("name()"), abi.encode("Unit"));
        vm.mockCall(UOA, abi.encodeWithSignature("symbol()"), abi.encode("USD"));
        vm.mockCall(UOA, abi.encodeWithSignature("decimals()"), abi.encode(uint8(8)));
    }

    function test_getVaultInfoStatic_populatesFields() public {
        VaultInfoStatic memory info = lens.getVaultInfoStatic(VAULT);

        assertEq(info.vault, VAULT, "vault");
        assertEq(info.vaultName, "Euler Vault", "vaultName");
        assertEq(info.vaultSymbol, "eVLT", "vaultSymbol");
        assertEq(info.vaultDecimals, 18, "vaultDecimals");
        assertEq(info.asset, ASSET, "asset");
        assertEq(info.assetSymbol, "AST", "assetSymbol");
        assertEq(info.assetDecimals, 6, "assetDecimals");
        assertEq(info.unitOfAccount, UOA, "unitOfAccount");
        assertEq(info.unitOfAccountDecimals, 8, "unitOfAccountDecimals");
        assertEq(info.evc, EVC, "evc");
        assertEq(info.creator, address(0xC8EA), "creator");
    }

    /// @dev asset metadata is optional under ERC20 and is read defensively
    function test_getVaultInfoStatic_assetWithoutMetadata() public {
        vm.mockCallRevert(ASSET, abi.encodeWithSignature("name()"), "");
        vm.mockCallRevert(ASSET, abi.encodeWithSignature("symbol()"), "");
        vm.mockCallRevert(ASSET, abi.encodeWithSignature("decimals()"), "");

        VaultInfoStatic memory info = lens.getVaultInfoStatic(VAULT);

        assertEq(info.assetDecimals, 18, "decimals falls back to 18");
        assertEq(info.vaultName, "Euler Vault", "vault metadata unaffected");
    }

    function test_getRecognizedCollateralsLTVInfo_emptyList() public {
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVList, ()), abi.encode(new address[](0)));

        LTVInfo[] memory info = lens.getRecognizedCollateralsLTVInfo(VAULT);

        assertEq(info.length, 0, "no collaterals");
    }

    function test_getRecognizedCollateralsLTVInfo_noneRecognized() public {
        address[] memory list = new address[](2);
        list[0] = address(0xA1);
        list[1] = address(0xB2);
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVList, ()), abi.encode(list));
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).LTVFull, (address(0xA1))),
            abi.encode(uint16(0), uint16(0), uint16(0), uint48(0), uint32(0))
        );
        vm.mockCall(
            VAULT,
            abi.encodeCall(IEVault(VAULT).LTVFull, (address(0xB2))),
            abi.encode(uint16(0), uint16(0), uint16(0), uint48(0), uint32(0))
        );

        LTVInfo[] memory info = lens.getRecognizedCollateralsLTVInfo(VAULT);

        assertEq(info.length, 0, "none recognized");
    }

    /// @dev alternating recognized/unrecognized is the ordering most likely to expose an index mistake
    function test_getRecognizedCollateralsLTVInfo_alternating() public {
        address[] memory list = new address[](4);
        list[0] = address(0xA1);
        list[1] = address(0xB2);
        list[2] = address(0xC3);
        list[3] = address(0xD4);
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).LTVList, ()), abi.encode(list));

        for (uint256 i = 0; i < list.length; ++i) {
            vm.mockCall(
                VAULT,
                abi.encodeCall(IEVault(VAULT).LTVFull, (list[i])),
                abi.encode(uint16(8000), uint16(9000), uint16(9000), uint48(i % 2 == 1 ? 1 : 0), uint32(0))
            );
        }

        LTVInfo[] memory info = lens.getRecognizedCollateralsLTVInfo(VAULT);

        assertEq(info.length, 2, "two recognized");
        assertEq(info[0].collateral, address(0xB2), "first recognized compacted to slot 0");
        assertEq(info[1].collateral, address(0xD4), "second recognized compacted to slot 1");
    }
}
