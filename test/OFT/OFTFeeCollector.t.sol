// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {FeeFlowControllerEVK} from "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeFlowControllerEVKTest} from "../FeeFlow/FeeFlowControllerEVK.t.sol";
import {OFTFeeCollector} from "../../src/OFT/OFTFeeCollector.sol";
import {MockToken} from "../FeeFlow/lib/MockToken.sol";
import {MockVault} from "../Util/lib/MockVault.sol";
import {MockOFTAdapter} from "./lib/MockOFTAdapter.sol";
import {BaseFeeFlowControllerTest} from "../FeeFlow/BaseFeeFlowControllerTest.sol";
import {SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";

contract OFTFeeCollectorTest is BaseFeeFlowControllerTest {
    OFTFeeCollector feeCollector;
    FeeFlowControllerEVK feeFlowController;
    address admin;
    address maintainer;
    MockVault vault1;
    MockVault vault2;
    MockVault vaultOtherUnderlying;

    function setUp() public virtual override {
        super.setUp();

        admin = makeAddr("admin");
        maintainer = makeAddr("maintainer");
        feeCollector = new OFTFeeCollector(address(evc), admin, address(paymentToken));

        bytes32 maintainerRole = feeCollector.MAINTAINER_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(maintainerRole, maintainer);

        vault1 = new MockVault(address(paymentToken), address(feeCollector));
        vault2 = new MockVault(address(paymentToken), address(feeCollector));

        // deploy new controller with new hook data
        feeFlowController = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(mockOFTAdapter),
            DST_EID,
            address(feeCollector),
            feeCollector.collectFees.selector
        );
        vm.prank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);

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
        feeCollector.configure(address(mockOFTAdapter), address(2), 1, "", "");
        deal(address(feeCollector), 1 ether);

        address[] memory addresses = assetsAddresses();
        // buy doesn't revert because collectFees error is cought. The mock vaults should still hold fees
        vm.prank(buyer);
        feeFlowController.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        assertEq(vault1.feesAmount(), 1e18);
        assertEq(vault2.feesAmount(), 2e18);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);

        // after granting the role, fees are collected
        bytes32 role = feeCollector.COLLECTOR_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(role, address(feeFlowController));

        vm.prank(buyer);
        feeFlowController.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

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
        feeCollector.configure(address(mockOFTAdapter), address(2), 1, "", "");
        bytes32 role = feeCollector.COLLECTOR_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(role, address(feeFlowController));

        address[] memory addresses = assetsAddresses();

        vm.prank(buyer);
        feeFlowController.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        // without eth for gas, fees are converted but not bridged

        assertEq(vault1.feesAmount(), 0);
        assertEq(vault2.feesAmount(), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);
        assertTrue(!mockOFTAdapter.wasSendCalled());

        // after providing balance for LZ fees, vault fees are collected
        deal(admin, 1 ether);
        vm.prank(admin);
        payable(address(feeCollector)).transfer(1 ether);

        vm.prank(buyer);
        feeFlowController.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

        assertEq(address(feeCollector).balance, 1 ether - mockOFTAdapter.MESSAGING_NATIVE_FEE());
        assertEq(vault1.feesAmount(), 0);
        assertEq(vault2.feesAmount(), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);
        assertTrue(mockOFTAdapter.wasSendCalled());
        assertEq(paymentToken.allowance(address(feeCollector), address(mockOFTAdapter)), 3e18);
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
        feeCollector.grantRole(role, address(feeFlowController));
        deal(address(feeCollector), 1 ether);

        address[] memory addresses = assetsAddresses();
        // if oft collector is not configured, fees are not collected
        vm.prank(buyer);
        feeFlowController.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        assertEq(vault1.feesAmount(), 1e18);
        assertEq(vault2.feesAmount(), 2e18);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);

        // fees are collected after configuring the collector
        vm.prank(admin);
        feeCollector.configure(address(mockOFTAdapter), address(2), 1, "", "");

        vm.prank(buyer);
        feeFlowController.buy(addresses, assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);

        assertEq(address(feeCollector).balance, 1 ether - mockOFTAdapter.MESSAGING_NATIVE_FEE());
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
        feeCollector.grantRole(role, address(feeFlowController));
        deal(address(feeCollector), 1 ether);

        address[] memory addresses = assetsAddresses();

        uint32 dstEid = 123;
        address dstAddress = makeAddr("dstAddress");

        bytes memory composeMsg = abi.encode("composeMsg");
        bytes memory extraOptions = abi.encode("extraOptions");

        vm.prank(admin);
        feeCollector.configure(address(mockOFTAdapter), dstAddress, dstEid, composeMsg, extraOptions);

        SendParam memory expecParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(dstAddress))),
            amountLD: 3e18,
            minAmountLD: 0,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });
        MessagingFee memory fee = mockOFTAdapter.quoteSend(expecParam, false);

        vm.prank(buyer);
        vm.expectCall(
            address(mockOFTAdapter), abi.encodeCall(MockOFTAdapter.send, (expecParam, fee, address(feeCollector)))
        );
        feeFlowController.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        assertEq(address(feeCollector).balance, 1 ether - mockOFTAdapter.MESSAGING_NATIVE_FEE());
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
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                feeCollector.DEFAULT_ADMIN_ROLE()
            )
        );
        feeCollector.configure(address(1), address(2), 1, "", "");

        vm.startPrank(admin);
        // not an adapter
        vm.expectRevert();
        feeCollector.configure(address(1), address(2), 1, "", "");

        MockOFTAdapter adapterWrongToken = new MockOFTAdapter(makeAddr("other_token"));
        vm.expectRevert(OFTFeeCollector.InvalidOFTAdapter.selector);
        feeCollector.configure(address(adapterWrongToken), address(2), 1, "", "");

        bytes memory composeMsg = abi.encode(123);
        bytes memory extraOptions = abi.encode(456);
        // success
        feeCollector.configure(address(mockOFTAdapter), address(2), 1, composeMsg, extraOptions);
        assertEq(feeCollector.oftAdapter(), address(mockOFTAdapter));
        assertEq(feeCollector.dstAddress(), address(2));
        assertEq(feeCollector.dstEid(), 1);
        assertEq(feeCollector.composeMsg(), composeMsg);
        assertEq(feeCollector.extraOptions(), extraOptions);

        // can reconfigure
        bytes memory otherComposeMsg = abi.encode(100);
        bytes memory otherExtraOptions = abi.encode(200);
        MockOFTAdapter otherAdapter = new MockOFTAdapter(address(paymentToken));

        feeCollector.configure(address(otherAdapter), address(4), 2, otherComposeMsg, otherExtraOptions);
        assertEq(feeCollector.oftAdapter(), address(otherAdapter));
        assertEq(feeCollector.dstAddress(), address(4));
        assertEq(feeCollector.dstEid(), 2);
        assertEq(feeCollector.composeMsg(), otherComposeMsg);
        assertEq(feeCollector.extraOptions(), otherExtraOptions);
    }
}
