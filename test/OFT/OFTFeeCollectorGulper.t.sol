// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeCollectorUtilTest} from "../Util/FeeCollectorUtil.t.sol";
import {OFTFeeCollectorGulper} from "../../src/OFT/OFTFeeCollectorGulper.sol";
import {MockVault} from "../Util/lib/MockVault.sol";
import {BaseFeeFlowControllerTest} from "../FeeFlow/BaseFeeFlowControllerTest.sol";
import {MockESR} from "../Util/lib/MockESR.sol";

contract OFTFeeCollectorGulperTest is BaseFeeFlowControllerTest {
    OFTFeeCollectorGulper feeCollector;
    MockESR mockESR;
    FeeFlowControllerEVK feeFlowController;

    address admin;
    address maintainer;
    MockVault vault1;
    MockVault vault2;

    function setUp() public override {
        super.setUp();

        admin = makeAddr("admin");
        maintainer = makeAddr("maintainer");

        mockESR = new MockESR(address(paymentToken));
        feeCollector = new OFTFeeCollectorGulper(address(evc), admin, address(mockESR));

        bytes32 maintainerRole = feeCollector.MAINTAINER_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(maintainerRole, maintainer);

        vault1 = new MockVault(address(paymentToken), address(feeCollector));
        vault2 = new MockVault(address(paymentToken), address(feeCollector));

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
    }

    function testCollectFeesAndGulp() public {
        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(address(mockESR)), 0);

        // no-op if no fees collected
        vm.prank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        assertTrue(!mockESR.gulpWasCalled());

        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        // gulp called when fees present
        vm.prank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 1, block.timestamp + 1 days, 1000000e18);
        assertTrue(mockESR.gulpWasCalled());

        // fees transferred
        assertEq(paymentToken.balanceOf(address(mockESR)), 3e18);
    }

    function testReceiveLZMessage() public {
        assertEq(paymentToken.balanceOf(address(mockESR)), 0);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);

        // no-op if no balance received
        feeCollector.lzCompose(address(0), bytes32(0), "", address(0), "");
        assertTrue(!mockESR.gulpWasCalled());

        // simulate asset bridged
        paymentToken.mint(address(feeCollector), 1e18);

        feeCollector.lzCompose(address(0), bytes32(0), "", address(0), "");
        assertTrue(mockESR.gulpWasCalled());

        assertEq(paymentToken.balanceOf(address(mockESR)), 1e18);
    }
}
