// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeCollectorUtilTest} from "./FeeCollectorUtil.t.sol";
import {FeeCollectorGulper} from "../../src/Util/FeeCollectorGulper.sol";
import {MockVault} from "./lib/MockVault.sol";
import {BaseFeeFlowControllerTest} from "../FeeFlow/BaseFeeFlowControllerTest.sol";
import {MockESR} from "./lib/MockESR.sol";

contract FeeCollectorGulperTest is BaseFeeFlowControllerTest {
    FeeCollectorGulper gulper;
    MockESR mockESR;
    FeeFlowControllerEVK feeFlowControllerGulper;

    address admin;
    address maintainer;
    MockVault vault1;
    MockVault vault2;

    function setUp() public override {
        super.setUp();

        admin = makeAddr("admin");
        maintainer = makeAddr("maintainer");

        mockESR = new MockESR(address(paymentToken));
        gulper = new FeeCollectorGulper(admin, address(paymentToken), address(mockESR));

        bytes32 maintainerRole = gulper.MAINTAINER_ROLE();
        vm.prank(admin);
        gulper.grantRole(maintainerRole, maintainer);

        vault1 = new MockVault(paymentToken, address(gulper));
        vault2 = new MockVault(paymentToken, address(gulper));


        feeFlowControllerGulper = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(gulper),
            gulper.collectFees.selector
        );
        vm.prank(buyer);
        paymentToken.approve(address(feeFlowControllerGulper), type(uint256).max);
    }

    function testCollectFeesAndGulp() public {


        vm.startPrank(maintainer);
        gulper.addToVaultsList(address(vault1));
        gulper.addToVaultsList(address(vault2));
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(address(mockESR)), 0);

        // no-op if no fees collected
        vm.prank(buyer);
        feeFlowControllerGulper.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        assertTrue(!mockESR.gulpWasCalled());

        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        // gulp called when fees present
        vm.prank(buyer);
        feeFlowControllerGulper.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        assertTrue(mockESR.gulpWasCalled());

        // fees transferred
        assertEq(paymentToken.balanceOf(address(mockESR)), 3e18);
    }

}
