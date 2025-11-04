// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {ERC4626EVC} from "../../src/Vault/implementation/ERC4626EVC.sol";
import {ERC4626EVCCollateralFreezable} from "../../src/Vault/implementation/ERC4626EVCCollateralFreezable.sol";
import {ERC4626EVCCollateralSecuritize, IComplianceServiceRegulated} from "../../src/Vault/deployed/ERC4626EVCCollateralSecuritize.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {MockSecuritizeToken} from "./lib/MockSecuritizeToken.sol";
import {MockController} from "./lib/MockController.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

contract ERC4626EVCCollateralSecuritizeTest is EVaultTestBase {
    MockSecuritizeToken securitizeToken;
    ERC4626EVCCollateralSecuritize vault;
    address mockComplianceService;
    address depositor;
    address liquidator;

    function setUp() public virtual override {
        super.setUp();

        depositor = makeAddr("depositor");
        liquidator = makeAddr("liquidator");
        mockComplianceService = makeAddr("mockComplianceService");
        securitizeToken = new MockSecuritizeToken(mockComplianceService);

        vault = new ERC4626EVCCollateralSecuritize(
            address(evc), address(permit2), admin, address(securitizeToken), "Collateral TST", "cTST"
        );

        securitizeToken.mint(depositor, type(uint256).max);
        vm.prank(depositor);
        securitizeToken.approve(address(vault), type(uint256).max);
    }

    function testCollateralSecuritize_pause() public {
        vm.prank(admin);
        vault.pause();

        vm.startPrank(depositor);
        address to = makeAddr("to");
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.deposit(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.mint(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.transfer(depositor, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.transferFrom(depositor, to, 1);
    }

    function testCollateralSecuritizeVault_freeze() public {
        address otherDepositor = makeAddr("otherDepositor");
        securitizeToken.mint(otherDepositor, type(uint256).max);
        vm.startPrank(otherDepositor);
        evc.call(address(0), otherDepositor, 0, ""); // register on evc
        securitizeToken.approve(address(vault), type(uint256).max);
        vault.deposit(1e18, otherDepositor);
        vault.approve(depositor, type(uint256).max);
        vm.stopPrank();

        bytes19 depositorPrefix = _getAddressPrefix(depositor);
        vm.prank(admin);
        vault.freeze(depositorPrefix);

        vm.startPrank(depositor);
        address to = makeAddr("to");

        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.deposit(3, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.mint(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transfer(otherDepositor, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transferFrom(depositor, to, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transferFrom(otherDepositor, depositor, 1);

        vm.startPrank(otherDepositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.withdraw(1, depositor, otherDepositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.redeem(1, depositor, otherDepositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transfer(depositor, 1);
    }

    function testCollateralSecuritizeVault_liquidate() public {
        MockController mockController = new MockController(address(evc));
        vm.startPrank(depositor);
        // enable mock controller as a simulated borrow vault
        evc.enableController(depositor, address(mockController));
        // enable vault with secuirize asset as collateral
        evc.enableCollateral(depositor, address(vault));
        // deposit collateral
        vault.deposit(1e18, depositor);
        vm.stopPrank();

        vm.startPrank(liquidator);
        evc.call(address(0), liquidator, 0, ""); // register liquidator in EVC
        // simulate liquidation
        // The mock controller, through EVC, will enforce a transfer of collateral to the liquidator account
        // The liquidation function signature is the same as in real Euler vaults, but the mock contract will transfer amount
        // of collateral equal to `repayAssets`. `minYieldBalance` is ignored.
        // https://github.com/euler-xyz/euler-vault-kit/blob/master/src/EVault/IEVault.sol#L295

        uint256 amountToSeize = 0.5e18;

        // mock compliance service reply
        vm.mockCall(
            mockComplianceService,
            0,
            abi.encodeCall(IComplianceServiceRegulated.preTransferCheck, (address(vault), liquidator, amountToSeize)),
            abi.encode(uint256(0), string(""))
        );
        mockController.liquidate(depositor, address(vault), amountToSeize, 0);

    }

    function _getAddressPrefix(address account) internal pure returns (bytes19) {
        uint160 ACCOUNT_ID_OFFSET = 8;
        return bytes19(uint152(uint160(account) >> ACCOUNT_ID_OFFSET));
    }
}
