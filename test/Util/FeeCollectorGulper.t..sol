// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeCollectorUtilTest} from "./FeeCollectorUtil.t.sol";
import {FeeCollectorGulper} from "../../src/Util/FeeCollectorGulper.sol";

contract FeeCollectorGulperTest is FeeCollectorUtilTest {
    FeeCollectorGulper gulper;
    MockESR mockESR;

    function setUp() public override {
        super.setUp();
        mockESR = new MockESR();
        gulper = new FeeCollectorGulper(admin, address(paymentToken), address(mockESR));

        // deploy new controller with gulper in hook
        feeFlowController = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(gulper),
            abi.encodeCall(gulper.collectFees, ())
        );
        vm.prank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);
    }

    function testCollectFeesAndGulp() public {
        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(address(mockESR)), 0);

        // gulp was called
        vm.expectCall(address(mockESR), abi.encodeCall(MockESR.gulp, ()));
        vm.prank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        // fees transferred
        assertEq(paymentToken.balanceOf(address(mockESR)), 3e18);
    }

}

contract MockESR {
    function gulp() public {}
}