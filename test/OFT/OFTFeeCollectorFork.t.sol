// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import {FeeFlowControllerEVK} from "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {OFTFeeCollector} from "../../src/OFT/OFTFeeCollector.sol";
import {MockToken} from "../FeeFlow/lib/MockToken.sol";
import {MockVault} from "../Util/lib/MockVault.sol";
import {SendParam, IOFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {ERC20Synth} from "../../src/ERC20/deployed/ERC20Synth.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";

contract OFTFeeCollectorTestFork is Test {
    uint32 constant DST_EID_MAINNET = 30101;
    uint256 constant OFT_DECIMALS_SCALER = 10 ** (18 - 6);
    // Plasma contracts
    address constant FEE_COLLECTOR_ADMIN = 0x3F1297Da87bf2B4c819F7d888fd81095F8dAA57E;
    address constant EUSD_ADMIN = 0x3F1297Da87bf2B4c819F7d888fd81095F8dAA57E;
    FeeFlowControllerEVK feeFlowController = FeeFlowControllerEVK(payable(0xEf8F018E94F358aDFa934B9287324e02FD89BAC4));
    ProtocolConfig protocolConfig = ProtocolConfig(0x593Ab8A0182f752c6f1af52CA2A0E8B9F868f64A);
    ERC20Synth eUSD = ERC20Synth(0xc59F5A9645AD68F3736fE7af69fc9306cdf75403);
    OFTFeeCollector feeCollector = OFTFeeCollector(payable(0x927BDb1c4966f45B5394Ca6B366467e279F2f006));

    MockToken token1;
    MockVault vault1;
    MockVault vault2;

    address maintainer;
    address buyer;
    uint256 fork;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL_PLASMA", string(""));
    uint256 constant BLOCK_NUMBER = 3678601;

    function setUp() public virtual {
        if (bytes(FORK_RPC_URL).length != 0) {
            fork = vm.createSelectFork(FORK_RPC_URL);
            vm.rollFork(BLOCK_NUMBER);

            buyer = makeAddr("buyer");
            maintainer = makeAddr("maintainer");

            vm.prank(protocolConfig.admin());
            protocolConfig.setFeeReceiver(address(feeFlowController));

            bytes32 maintainerRole = feeCollector.MAINTAINER_ROLE();
            vm.prank(FEE_COLLECTOR_ADMIN);
            feeCollector.grantRole(maintainerRole, maintainer);

            token1 = new MockToken("Token 1", "T1");
            vault1 = new MockVault(address(eUSD), address(feeCollector));
            vault2 = new MockVault(address(eUSD), address(feeCollector));

            vm.startPrank(maintainer);
            feeCollector.addToVaultsList(address(vault1));
            feeCollector.addToVaultsList(address(vault2));
            vm.stopPrank();

            vm.prank(buyer);
            eUSD.approve(address(feeFlowController), type(uint256).max);

            deal(buyer, 200 ether);
            vm.prank(buyer);
            payable(address(feeFlowController)).transfer(100 ether);
            payable(address(feeCollector)).transfer(100 ether);
        }
    }

    function testAuctionAndFeeCollectionOnFork() public {
        vm.skip(bytes(FORK_RPC_URL).length == 0);

        // put some eUSD fees to collect
        uint256 vault1FeesAmount = 1e18 + 11; // with extra dust
        uint256 vault2FeesAmount = 2e18 + 22; // with extra dust

        deal(address(eUSD), address(vault1), vault1FeesAmount);
        deal(address(eUSD), address(vault2), vault2FeesAmount);

        vault1.mockSetFeeAmount(vault1FeesAmount);
        vault2.mockSetFeeAmount(vault2FeesAmount);

        // give the buyer funds to buy the auction
        uint256 auctionPrice = feeFlowController.getPrice();
        deal(address(eUSD), buyer, auctionPrice);

        uint256 expectedSentAuction = auctionPrice / OFT_DECIMALS_SCALER * OFT_DECIMALS_SCALER;
        uint256 expectedSentFees = (vault1FeesAmount + vault2FeesAmount) / OFT_DECIMALS_SCALER * OFT_DECIMALS_SCALER;

        address[] memory buyAssets = addresses();
        address feeFlowOftAdapter = feeFlowController.oftAdapter();
        address feeCollectorOftAdapter = feeCollector.oftAdapter();
        vm.startPrank(buyer);
        // sent auction preoceeds were burned
        vm.expectEmit(true, true, true, true, address(eUSD));
        emit IERC20.Transfer(address(feeFlowController), address(0), expectedSentAuction);
        // proceeds from the auction sent to DAO
        vm.expectEmit(false, true, true, true, feeFlowOftAdapter);
        emit IOFT.OFTSent(
            bytes32(uint256(1)), // some giud, not checked
            DST_EID_MAINNET, // Destination Endpoint ID.
            address(feeFlowController), // Address of the sender on the src chain.
            expectedSentAuction, // Amount of tokens sent in local decimals.
            expectedSentAuction // Amount of tokens received in local decimals.
        );
        // sent fees were burned
        vm.expectEmit(true, true, true, true, address(eUSD));
        emit IERC20.Transfer(address(feeCollector), address(0), expectedSentFees);
        // collected fees sent to mainnet fee collector
        vm.expectEmit(false, true, true, true, feeCollectorOftAdapter);
        emit IOFT.OFTSent(
            bytes32(uint256(1)), // some giud, not checked
            DST_EID_MAINNET, // Destination Endpoint ID.
            address(feeCollector), // Address of the sender on the src chain.
            expectedSentFees, // Amount of tokens sent in local decimals.
            expectedSentFees // Amount of tokens received in local decimals.
        );

        feeFlowController.buy(buyAssets, buyer, 0, block.timestamp + 1 days, 1000000e18);

        vm.stopPrank();

        // buyer paid full price
        assertEq(eUSD.balanceOf(buyer), 0);

        // dust was returned
        assertEq(eUSD.balanceOf(address(feeFlowController)), auctionPrice - expectedSentAuction);
        assertEq(eUSD.balanceOf(address(feeCollector)), vault1FeesAmount + vault2FeesAmount - expectedSentFees);
    }

    function addresses() internal view returns (address[] memory) {
        address[] memory a = new address[](1);
        a[0] = address(token1);
        return a;
    }
}
