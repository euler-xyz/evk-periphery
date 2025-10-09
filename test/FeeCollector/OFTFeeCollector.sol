// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {FeeFlowControllerEVK} from "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeFlowControllerEVKTest} from "../FeeFlow/FeeFlowControllerEVK.t.sol";
import {OFTFeeCollector} from "../../src/OFT/OFTFeeCollector.sol";
import {MockToken} from "../FeeFlow/lib/MockToken.sol";
import {MockVault} from "./lib/MockVault.sol";
import {BaseFeeFlowControllerTest} from "../FeeFlow/BaseFeeFlowControllerTest.sol";

contract OFTFeeCollectorTest is BaseFeeFlowControllerTest {
    OFTFeeCollector feeCollector;
    FeeFlowControllerEVK feeFlowControllerCollector;
    address admin;
    address maintainer;
    MockVault vault1;
    MockVault vault2;
    MockVault vaultOtherUnderlying;

    function setUp() public override virtual {
        super.setUp();

        admin = makeAddr("admin");
        maintainer = makeAddr("maintainer");
        feeCollector = new OFTFeeCollector(admin, address(paymentToken));

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
    }

}
