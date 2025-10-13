// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {FeeFlowControllerEVK} from "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeFlowControllerEVKTest} from "../FeeFlow/FeeFlowControllerEVK.t.sol";
import {OFTFeeCollectorHarness} from "./lib/OFTFeeCollectorHarness.sol";
import {OFTFeeCollector} from "../../src/OFT/OFTFeeCollector.sol";
import {MockToken} from "../FeeFlow/lib/MockToken.sol";
import {MockVault} from "./lib/MockVault.sol";
import {MockOFTAdapter} from "./lib/MockOFTAdapter.sol";
import {BaseFeeFlowControllerTest} from "../FeeFlow/BaseFeeFlowControllerTest.sol";

contract OFTFeeCollectorTest is BaseFeeFlowControllerTest {
    OFTFeeCollectorHarness feeCollector;
    FeeFlowControllerEVK feeFlowControllerCollector;
    address admin;
    address maintainer;
    MockVault vault1;
    MockVault vault2;
    MockVault vaultOtherUnderlying;
    MockOFTAdapter mockOFTAdapter;

    function setUp() public override virtual {
        super.setUp();

        admin = makeAddr("admin");
        maintainer = makeAddr("maintainer");
        feeCollector = new OFTFeeCollectorHarness(admin, address(paymentToken));

        bytes32 maintainerRole = feeCollector.MAINTAINER_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(maintainerRole, maintainer);

        vault1 = new MockVault(paymentToken, address(feeCollector));
        vault2 = new MockVault(paymentToken, address(feeCollector));

        // deploy new controller with new hook data
        feeFlowControllerCollector = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(feeCollector),
            feeCollector.collectFees.selector
        );
        vm.prank(buyer);
        paymentToken.approve(address(feeFlowControllerCollector), type(uint256).max);

        mockOFTAdapter = new MockOFTAdapter(address(paymentToken));
    }

    function testCollectFeesOnlyCurator() public {
        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        vm.prank(admin);
        feeCollector.configure(address(mockOFTAdapter), address(2), 0, true);
        deal(address(feeCollector), 100);

        address[] memory addresses = assetsAddresses();
        // buy doesn't revert because collectFees error is cought. The mock vaults should still hold fees
        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        assertEq(vault1.feesAmount(), 1e18);
        assertEq(vault2.feesAmount(), 2e18);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);


        // after granting the role, fees are collected
        bytes32 role = feeCollector.COLLECTOR_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(role, address(feeFlowControllerCollector));

        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

        assertEq(vault1.feesAmount(), 0);
        assertEq(vault2.feesAmount(), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);
    }

    function testFeesCollectorNeedsBalanceForLZFee() public {
        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        vm.prank(admin);
        feeCollector.configure(address(mockOFTAdapter), address(2), 0, true);
        bytes32 role = feeCollector.COLLECTOR_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(role, address(feeFlowControllerCollector));

        address[] memory addresses = assetsAddresses();
        // buy doesn't revert because collectFees error is cought. The mock vaults should still hold fees
        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        assertEq(vault1.feesAmount(), 1e18);
        assertEq(vault2.feesAmount(), 2e18);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);


        // after providing balance for LZ fees, vault fees are collected
        deal(admin, 100);
        vm.prank(admin);
        payable(address(feeCollector)).transfer(100);

        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

        assertEq(address(feeCollector).balance, 100 - mockOFTAdapter.MESSAGING_NATIVE_FEE());
        assertEq(vault1.feesAmount(), 0);
        assertEq(vault2.feesAmount(), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);
    }

    function testFeesCollectorMustBeConfigured() public {
        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        bytes32 role = feeCollector.COLLECTOR_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(role, address(feeFlowControllerCollector));
        deal(address(feeCollector), 100);

        address[] memory addresses = assetsAddresses();
        // if oft collector is not configured, fees are not collected
        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        assertEq(vault1.feesAmount(), 1e18);
        assertEq(vault2.feesAmount(), 2e18);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);


        // fees are collected after configuring the collector
        vm.prank(admin);
        feeCollector.configure(address(mockOFTAdapter), address(2), 0, true);

        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

        assertEq(address(feeCollector).balance, 100 - mockOFTAdapter.MESSAGING_NATIVE_FEE());
        assertEq(vault1.feesAmount(), 0);
        assertEq(vault2.feesAmount(), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);
    }

    function testFeesCollectorCallsAdapter() public {
        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        bytes32 role = feeCollector.COLLECTOR_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(role, address(feeFlowControllerCollector));
        deal(address(feeCollector), 100);

        address[] memory addresses = assetsAddresses();

        vm.prank(admin);
        feeCollector.configure(address(mockOFTAdapter), address(2), 0, true);

        vm.prank(buyer);
        feeFlowControllerCollector.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

        assertEq(address(feeCollector).balance, 100 - mockOFTAdapter.MESSAGING_NATIVE_FEE());
        assertEq(vault1.feesAmount(), 0);
        assertEq(vault2.feesAmount(), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);

        // adapter has allowance
        assertEq(paymentToken.allowance(address(feeCollector), address(mockOFTAdapter)), 3e18);
    }

    function testFeeCollectorConfigure() public {
        // only admin
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeCollector.DEFAULT_ADMIN_ROLE()
            )
        );
        feeCollector.configure(address(1), address(2), 1, true);

        vm.startPrank(admin);
        // not an adapter
        vm.expectRevert();
        feeCollector.configure(address(1), address(2), 1, true);

        MockOFTAdapter adapterWrongToken = new MockOFTAdapter(makeAddr("other_token"));
        vm.expectRevert(OFTFeeCollector.InvalidOFTAdapter.selector);
        feeCollector.configure(address(adapterWrongToken), address(2), 1, true);

        // success
        feeCollector.configure(address(mockOFTAdapter), address(2), 1, true);
        assertEq(feeCollector.oftAdapter(), address(mockOFTAdapter));
        assertEq(feeCollector.dstAddress(), address(2));
        assertEq(feeCollector.dstEid(), 1);
        assertEq(feeCollector.isComposedMsg(), true);

        // can reconfigure
        feeCollector.configure(address(mockOFTAdapter), address(4), 2, false);
        assertEq(feeCollector.dstAddress(), address(4));
        assertEq(feeCollector.dstEid(), 2);
        assertEq(feeCollector.isComposedMsg(), false);
    }
}
