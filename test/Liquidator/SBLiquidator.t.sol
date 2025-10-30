// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

// import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {SBuidlLiquidator, ISBToken} from "../../src/Liquidator/SBLiquidator.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract SBLiquidatorTests is EVaultTestBase {
    uint256 mainnetFork;
    SBuidlLiquidator sbLiquidator;

    address SB_TOKEN = 0x07a36C630e3F072637da3445Da733B29958D8cAB;
    IERC20 SB_TOKEN_IERC20 = IERC20(SB_TOKEN);
    address SB_TOKEN_HOLDER = 0x69088d25a635D22dcbe7c4A5C7707B9cc64bD114;
    address SB_TOKEN_ADMIN = 0xCf28710273B55F9dD6D19088eD4B994af560266b;
    uint256 blockNumber = 20957465;

    address depositor = makeAddr("depositor");
    address borrower = makeAddr("borrower");
    address liquidator = makeAddr("liquidator");
    address receiver = makeAddr("receiver");
    address nonOwner = makeAddr("nonOwner");

    IERC20 sbUnderlyingToken;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL", string(""));

    IEVault esBToken;

    function setUp() public override {
        super.setUp();

        vm.skip(bytes(FORK_RPC_URL).length == 0);
        mainnetFork = vm.createSelectFork(FORK_RPC_URL);
        vm.rollFork(blockNumber);

        esBToken =
            IEVault(factory.createProxy(address(0), true, abi.encodePacked(SB_TOKEN, address(oracle), unitOfAccount)));
        esBToken.setHookConfig(address(0), 0);
        oracle.setPrice(address(esBToken), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST), unitOfAccount, 1e18);

        address[] memory customLiquidationVaults = new address[](1);
        customLiquidationVaults[0] = address(esBToken);

        sbLiquidator = new SBuidlLiquidator(address(evc), liquidator, customLiquidationVaults);

        // Set LTV for esBToken as collateral
        eTST.setLTV(address(esBToken), 0.97e4, 0.97e4, 0);

        // Add liquidator to the liquidators role
        vm.startPrank(SB_TOKEN_ADMIN);
        ISBToken(SB_TOKEN).addLiquidator(address(sbLiquidator));
        vm.stopPrank();

        // Move SB_TOKEN to the liquidator and borrower for usage as collateral
        vm.startPrank(SB_TOKEN_HOLDER);
        uint256 sbTokenBalance = SB_TOKEN_IERC20.balanceOf(SB_TOKEN_HOLDER);
        SB_TOKEN_IERC20.transfer(liquidator, sbTokenBalance / 2);
        SB_TOKEN_IERC20.transfer(borrower, sbTokenBalance / 2);
        vm.stopPrank();

        // Depositor
        // Deposit borrowable liquidity
        vm.startPrank(depositor);
        assetTST.mint(depositor, 1000e18);
        assetTST.approve(address(eTST), 1000e18);
        eTST.deposit(1000e18, depositor);
        vm.stopPrank();

        // Borrower
        // Deposit SB_TOKEN as collateral
        vm.startPrank(borrower);
        uint256 borrowerSbTokenBalance = SB_TOKEN_IERC20.balanceOf(borrower);
        SB_TOKEN_IERC20.approve(address(esBToken), borrowerSbTokenBalance);
        esBToken.deposit(borrowerSbTokenBalance, borrower);

        // Enable collateral and controller on the evc
        evc.enableCollateral(borrower, address(esBToken));
        evc.enableController(borrower, address(eTST));
        // Borrow up to 97% of the collateral value - 1 to avoid rounding errors
        eTST.borrow(borrowerSbTokenBalance * 97 / 100 - 1, borrower);

        vm.stopPrank();

        // Liquidator
        vm.startPrank(liquidator);
        evc.enableCollateral(liquidator, address(esBToken));
        evc.enableController(liquidator, address(eTST));
        // Deposit some collateral to be able to absorb liduidation
        uint256 liquidatorSbTokenBalance = SB_TOKEN_IERC20.balanceOf(liquidator);
        SB_TOKEN_IERC20.approve(address(esBToken), liquidatorSbTokenBalance);
        esBToken.deposit(liquidatorSbTokenBalance, liquidator);
        // Enable the liquidator as an operator
        evc.setAccountOperator(liquidator, address(sbLiquidator), true);

        vm.stopPrank();

        // Make position unhealthy
        oracle.setPrice(address(esBToken), unitOfAccount, 0.6e18);

        // Get the underlying token
        sbUnderlyingToken = IERC20(ISBToken(address(SB_TOKEN)).liquidationToken());
    }

    function test_liquidation() public {
        uint256 borrowerCollateralBefore = esBToken.balanceOf(borrower);
        uint256 receiverCollateralBefore = esBToken.balanceOf(liquidator);
        uint256 receiverSbUnderlyingBefore = sbUnderlyingToken.balanceOf(receiver);
        uint256 borrowerDebtBefore = eTST.debtOf(borrower);
        uint256 liquidatorDebtBefore = eTST.debtOf(liquidator);

        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        sbLiquidator.liquidate(receiver, address(eTST), borrower, address(esBToken), type(uint256).max, 0);
        vm.stopPrank();

        vm.startPrank(liquidator);
        sbLiquidator.liquidate(receiver, address(eTST), borrower, address(esBToken), type(uint256).max, 0);
        vm.stopPrank();

        uint256 borrowerCollateralAfter = esBToken.balanceOf(borrower);
        uint256 receiverCollateralAfter = esBToken.balanceOf(liquidator);
        uint256 receiverSbUnderlyingAfter = sbUnderlyingToken.balanceOf(receiver);
        uint256 borrowerDebtAfter = eTST.debtOf(borrower);
        uint256 liquidatorDebtAfter = eTST.debtOf(liquidator);

        uint256 amountCollateralSeized = borrowerCollateralBefore - borrowerCollateralAfter;
        uint256 amountDebtAbsorbed = borrowerDebtBefore - borrowerDebtAfter;

        assertEq(receiverCollateralAfter, receiverCollateralBefore, "Should not receive raw unredeemed collateral");
        assertEq(
            liquidatorDebtAfter, liquidatorDebtBefore + amountDebtAbsorbed, "Debt not properly absorbed by liquidator"
        );
        assertEq(
            receiverSbUnderlyingAfter,
            receiverSbUnderlyingBefore + amountCollateralSeized,
            "Should receive underlying token as liquidation proceeds"
        );
    }
}
