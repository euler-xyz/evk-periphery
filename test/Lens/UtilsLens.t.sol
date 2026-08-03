// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {UtilsLens} from "../../src/Lens/UtilsLens.sol";
import {VaultInfoERC4626} from "../../src/Lens/LensTypes.sol";

contract UtilsLensTest is Test {
    UtilsLens lens;

    address constant FACTORY = address(0xFAC7);
    address constant ORACLE_LENS = address(0x01C1);
    address constant VAULT = address(0xBEEF);
    address constant ASSET = address(0xCAFE);
    address constant ACCOUNT = address(0xA11CE);
    address constant SPENDER = address(0x5DEF);

    function setUp() public {
        lens = new UtilsLens(FACTORY, ORACLE_LENS);
        vm.etch(FACTORY, hex"00");
        vm.etch(VAULT, hex"00");
        vm.etch(ASSET, hex"00");
    }

    function _conformingVault() internal {
        vm.mockCall(VAULT, abi.encodeWithSignature("name()"), abi.encode("Vault Name"));
        vm.mockCall(VAULT, abi.encodeWithSignature("symbol()"), abi.encode("VLT"));
        vm.mockCall(VAULT, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.mockCall(VAULT, abi.encodeCall(IEVault(VAULT).asset, ()), abi.encode(ASSET));
        vm.mockCall(VAULT, abi.encodeWithSignature("totalSupply()"), abi.encode(uint256(1000)));
        vm.mockCall(VAULT, abi.encodeWithSignature("totalAssets()"), abi.encode(uint256(2000)));
        vm.mockCall(ASSET, abi.encodeWithSignature("name()"), abi.encode("Asset Name"));
        vm.mockCall(ASSET, abi.encodeWithSignature("symbol()"), abi.encode("AST"));
        vm.mockCall(ASSET, abi.encodeWithSignature("decimals()"), abi.encode(uint8(6)));
        vm.mockCall(FACTORY, abi.encodeWithSignature("isProxy(address)", VAULT), abi.encode(true));
    }

    function test_getVaultInfoERC4626_populatesFields() public {
        _conformingVault();

        VaultInfoERC4626 memory info = lens.getVaultInfoERC4626(VAULT);

        assertEq(info.vault, VAULT, "vault");
        assertEq(info.vaultName, "Vault Name", "vaultName");
        assertEq(info.vaultSymbol, "VLT", "vaultSymbol");
        assertEq(info.vaultDecimals, 18, "vaultDecimals");
        assertEq(info.asset, ASSET, "asset");
        assertEq(info.assetDecimals, 6, "assetDecimals");
        assertEq(info.totalShares, 1000, "totalShares");
        assertEq(info.totalAssets, 2000, "totalAssets");
        assertTrue(info.isEVault, "isEVault");
    }

    /// @dev the asset's optional ERC20 metadata is read defensively; missing decimals falls back to 18
    function test_getVaultInfoERC4626_assetWithoutMetadata() public {
        _conformingVault();
        vm.mockCallRevert(ASSET, abi.encodeWithSignature("name()"), "");
        vm.mockCallRevert(ASSET, abi.encodeWithSignature("symbol()"), "");
        vm.mockCallRevert(ASSET, abi.encodeWithSignature("decimals()"), "");

        VaultInfoERC4626 memory info = lens.getVaultInfoERC4626(VAULT);

        assertEq(info.assetDecimals, 18, "decimals defaults to 18");
        assertEq(info.vaultName, "Vault Name", "vault metadata unaffected");
    }

    /// @dev MKR-style bytes32 metadata is handled by the length == 32 branch, not the string decode
    function test_getVaultInfoERC4626_assetWithBytes32Metadata() public {
        _conformingVault();
        vm.mockCall(ASSET, abi.encodeWithSignature("symbol()"), abi.encode(bytes32("MKR")));

        VaultInfoERC4626 memory info = lens.getVaultInfoERC4626(VAULT);

        assertEq(bytes(info.assetSymbol).length, 32, "bytes32 symbol passed through raw");
    }

    /// @dev a payload that is neither 32 bytes nor a valid string encoding: the decode would revert unguarded
    function test_getVaultInfoERC4626_assetWithMalformedMetadata() public {
        _conformingVault();
        vm.mockCall(ASSET, abi.encodeWithSignature("symbol()"), abi.encode(uint256(type(uint128).max), uint256(5)));
        vm.mockCall(ASSET, abi.encodeWithSignature("name()"), abi.encode(uint256(type(uint128).max), uint256(5)));

        VaultInfoERC4626 memory info = lens.getVaultInfoERC4626(VAULT);

        assertEq(info.assetSymbol, "", "undecodable symbol falls back to empty");
        assertEq(info.assetName, "", "undecodable name falls back to empty");
        assertEq(info.totalAssets, 2000, "the rest of the query is unaffected");
    }

    /// @dev decimals() returning a value wider than uint8: the decode would revert unguarded
    function test_getVaultInfoERC4626_assetWithOutOfRangeDecimals() public {
        _conformingVault();
        vm.mockCall(ASSET, abi.encodeWithSignature("decimals()"), abi.encode(uint256(300)));

        VaultInfoERC4626 memory info = lens.getVaultInfoERC4626(VAULT);

        assertEq(info.assetDecimals, 18, "out-of-range decimals falls back to 18");
    }

    function test_tokenBalances_perTokenIsolation() public {
        address good = address(0x6001);
        address bad = address(0x6002);
        vm.etch(good, hex"00");
        vm.etch(bad, hex"00");
        vm.mockCall(good, abi.encodeCall(IEVault(good).balanceOf, (ACCOUNT)), abi.encode(uint256(77)));
        vm.mockCallRevert(bad, abi.encodeCall(IEVault(bad).balanceOf, (ACCOUNT)), "boom");

        address[] memory tokens = new address[](3);
        tokens[0] = good;
        tokens[1] = bad;
        tokens[2] = address(0); // native balance

        vm.deal(ACCOUNT, 5 ether);
        uint256[] memory balances = lens.tokenBalances(ACCOUNT, tokens);

        assertEq(balances[0], 77, "good token");
        assertEq(balances[1], 0, "reverting token yields zero, not a revert");
        assertEq(balances[2], 5 ether, "native balance");
    }

    function test_tokenAllowances_perTokenIsolation() public {
        address good = address(0x6001);
        address bad = address(0x6002);
        vm.etch(good, hex"00");
        vm.etch(bad, hex"00");
        vm.mockCall(good, abi.encodeCall(IEVault(good).allowance, (ACCOUNT, SPENDER)), abi.encode(uint256(42)));
        vm.mockCallRevert(bad, abi.encodeCall(IEVault(bad).allowance, (ACCOUNT, SPENDER)), "boom");

        address[] memory tokens = new address[](2);
        tokens[0] = good;
        tokens[1] = bad;

        uint256[] memory allowances = lens.tokenAllowances(SPENDER, ACCOUNT, tokens);

        assertEq(allowances[0], 42, "good token");
        assertEq(allowances[1], 0, "reverting token yields zero");
    }

    function test_tokenBalances_emptyList() public view {
        uint256[] memory balances = lens.tokenBalances(ACCOUNT, new address[](0));
        assertEq(balances.length, 0, "empty");
    }

    function test_computeAPYs_zeroBorrows() public view {
        (uint256 borrowAPY, uint256 supplyAPY) = lens.computeAPYs(0, 1000, 0, 0);
        assertEq(borrowAPY, 0, "no borrow rate");
        assertEq(supplyAPY, 0, "no supply rate");
    }
}
