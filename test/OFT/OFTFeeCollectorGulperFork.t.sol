// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IOFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTFeeCollectorGulper} from "../../src/OFT/OFTFeeCollectorGulper.sol";
import {ERC20Synth} from "../../src/ERC20/deployed/ERC20Synth.sol";
import {EulerSavingsRate} from "evk/Synths/EulerSavingsRate.sol";

contract OFTFeeCollectorGulperTestFork is Test {
    // Mainnet contracts
    address constant EUSD_ADMIN = 0xB1345E7A4D35FB3E6bF22A32B3741Ae74E5Fba27;

    ERC20Synth eUSD = ERC20Synth(0x950C6BEF80bbfD1eA2335D9e6Cb5bc3A23361b39);
    OFTFeeCollectorGulper feeCollectorGulper =
        OFTFeeCollectorGulper(payable(0x1e3249cFC9C393E621F3e81bb992FF428bd18E66));
    IOFT eUsdOFTAdapter = IOFT(0xEb333262B68E29a48F769c32da8049765eC9c9A1);
    EulerSavingsRate seUSD = EulerSavingsRate(0xA2C12AB83F056510421d3DC4ad38A075e68a690e);

    uint256 constant ESR_MIN_DEPOSIT = 10e6;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL", string(""));
    uint256 constant BLOCK_NUMBER = 23590280;
    uint256 fork;

    address depositor;

    function setUp() public virtual {
        if (bytes(FORK_RPC_URL).length != 0) {
            fork = vm.createSelectFork(FORK_RPC_URL);
            vm.rollFork(BLOCK_NUMBER);
            depositor = makeAddr("depositor");
        }
    }

    function testGulpFeesOnMainnet() public {
        vm.skip(bytes(FORK_RPC_URL).length == 0);

        uint256 feesToGulp = 123e18;

        // fees arrive to the collector
        vm.prank(address(eUsdOFTAdapter));
        eUSD.mint(address(feeCollectorGulper), feesToGulp);

        // ESR is empty
        assertEq(eUSD.balanceOf(address(seUSD)), 0);
        assertEq(seUSD.totalSupply(), 0);

        // there must be minimal deposited amount for gulp to work
        deal(address(eUSD), depositor, ESR_MIN_DEPOSIT);
        vm.startPrank(depositor);
        eUSD.approve(address(seUSD), type(uint256).max);
        seUSD.deposit(ESR_MIN_DEPOSIT, depositor);
        vm.stopPrank();

        vm.prank(address(eUsdOFTAdapter));

        // message arrives
        vm.expectEmit();
        emit EulerSavingsRate.Gulped(feesToGulp, feesToGulp);
        feeCollectorGulper.lzCompose(address(0), bytes32(uint256(0)), "", address(0), "");

        assertEq(eUSD.balanceOf(address(feeCollectorGulper)), 0);
        assertEq(eUSD.balanceOf(address(seUSD)), ESR_MIN_DEPOSIT + feesToGulp);
    }
}
