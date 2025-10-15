// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
// import "forge-std/Test.sol";
// import "evc/EthereumVaultConnector.sol";
// import "../../src/FeeFlow/FeeFlowControllerEVK.sol";
// import {FeeCollectorUtilTest} from "./FeeCollectorUtil.t.sol";
// import {OFTGulper} from "../../src/OFT/OFTGulper.sol";
// import {MockVault} from "./lib/MockVault.sol";
// import {BaseFeeFlowControllerTest} from "../FeeFlow/BaseFeeFlowControllerTest.sol";
// import {MockESR} from "./lib/MockESR.sol";

// contract OFTGulperTest is BaseFeeFlowControllerTest {
//     OFTGulper gulper;
//     MockESR mockESR;
//     address owner;

//     function setUp() public override {
//         super.setUp();

//         owner = makeAddr("owner");

//         mockESR = new MockESR(address(paymentToken));
//         gulper = new OFTGulper(owner, address(mockESR));
//     }

//     function testFeeAssetTakenFromESR() public view {
//         assertEq(address(gulper.feeToken()), mockESR.asset());
//     }

//     function testReceiveLZMessage() public {
//         assertEq(paymentToken.balanceOf(address(mockESR)), 0);
//         assertEq(paymentToken.balanceOf(address(gulper)), 0);

//         // no-op if no balance received
//         gulper.lzCompose(address(0), bytes32(0), "", address(0), "");
//         assertTrue(!mockESR.gulpWasCalled());

//         // simulate asset bridged
//         paymentToken.mint(address(gulper), 1e18);

//         gulper.lzCompose(address(0), bytes32(0), "", address(0), "");
//         assertTrue(mockESR.gulpWasCalled());

//         assertEq(paymentToken.balanceOf(address(mockESR)), 1e18);
//     }

//     function testOFTGulperRecoverTokens() public {
//         deal(address(gulper), 1 ether);
//         deal(address(paymentToken), address(gulper), 2e18);

//         // only owner can recover
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Ownable.OwnableUnauthorizedAccount.selector, address(this)
//             )
//         );
//         gulper.recoverToken(address(0), owner, 1 ether);

//         vm.startPrank(owner);
//         // recover too much ether
//         vm.expectRevert("Native currency recovery failed");
//         gulper.recoverToken(address(0), owner, 1 ether + 1);

//         // recover ether
//         assertEq(owner.balance, 0);
//         gulper.recoverToken(address(0), owner, 1 ether);
//         assertEq(owner.balance, 1 ether);
//         // recover too much token
//         vm.expectRevert();
//         gulper.recoverToken(address(paymentToken), owner, 2 ether + 1);

//         // recover token
//         assertEq(paymentToken.balanceOf(owner), 0);
//         gulper.recoverToken(address(paymentToken), owner, 2 ether);
//         assertEq(paymentToken.balanceOf(owner), 2 ether);
//     }
// }
