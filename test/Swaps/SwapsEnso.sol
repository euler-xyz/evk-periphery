// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault, IERC4626, IERC20} from "evk/EVault/IEVault.sol";

import {ISwapper} from "../../src/Swaps/ISwapper.sol";
import {Swapper} from "../../src/Swaps/Swapper.sol";
import {SwapVerifier} from "../../src/Swaps/SwapVerifier.sol";

import "./PayloadsEnso.sol";

import "forge-std/Test.sol";

/// @notice The tests operate on a fork. Create a .env file with FORK_RPC_URL as per foundry docs
contract SwapsEnso is EVaultTestBase {
    uint256 mainnetFork;
    Swapper swapper;
    SwapVerifier swapVerifier;

    address constant oneInchAggregatorV5 = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    address constant uniswapRouterV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant uniswapRouterV3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant uniswapRouter02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant ensoAggregator = 0x80EbA3855878739F4710233A8a19d89Bdd2ffB8E;

    address constant GRT = 0xc944E90C64B2c07662A292be6244BDf05Cda44a7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint256 internal constant MODE_EXACT_IN = 0;
    uint256 internal constant MODE_EXACT_OUT = 1;
    uint256 internal constant MODE_TARGET_DEBT = 2;
    uint256 internal constant MODE_INVALID = 3;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL", string(""));

    address user;
    address user2;

    IEVault eGRT;
    IEVault eUSDC;
    IEVault eSTETH;
    IEVault eUSDT;
    IEVault eDAI;

    function setUp() public virtual override {
        super.setUp();

        user = makeAddr("user");
        user2 = makeAddr("user2");

        swapper = new Swapper(oneInchAggregatorV5, uniswapRouterV2, uniswapRouterV3, uniswapRouter02, ensoAggregator);
        swapVerifier = new SwapVerifier();

        if (bytes(FORK_RPC_URL).length != 0) {
            mainnetFork = vm.createSelectFork(FORK_RPC_URL);
        }
    }

    function setupFork(uint256 blockNumber, bool forBorrow) internal {
        vm.skip(bytes(FORK_RPC_URL).length == 0);
        vm.rollFork(blockNumber);

        eGRT = IEVault(factory.createProxy(address(0), true, abi.encodePacked(GRT, address(oracle), unitOfAccount)));
        eUSDC = IEVault(factory.createProxy(address(0), true, abi.encodePacked(USDC, address(oracle), unitOfAccount)));
        eSTETH = IEVault(factory.createProxy(address(0), true, abi.encodePacked(STETH, address(oracle), unitOfAccount)));
        eUSDT = IEVault(factory.createProxy(address(0), true, abi.encodePacked(USDT, address(oracle), unitOfAccount)));
        eDAI = IEVault(factory.createProxy(address(0), true, abi.encodePacked(DAI, address(oracle), unitOfAccount)));

        eGRT.setHookConfig(address(0), 0);
        eUSDC.setHookConfig(address(0), 0);
        eSTETH.setHookConfig(address(0), 0);
        eUSDT.setHookConfig(address(0), 0);
        eDAI.setHookConfig(address(0), 0);

        if (forBorrow) {
            eUSDC.setLTV(address(eGRT), 0.97e4, 0.97e4, 0);
            eSTETH.setLTV(address(eUSDT), 0.97e4, 0.97e4, 0);
            eDAI.setLTV(address(eUSDC), 0.97e4, 0.97e4, 0);

            oracle.setPrice(address(USDC), unitOfAccount, 1e18);
            oracle.setPrice(address(GRT), unitOfAccount, 1e18);
            oracle.setPrice(address(STETH), unitOfAccount, 1e18);
            oracle.setPrice(address(USDT), unitOfAccount, 1e30);
            oracle.setPrice(address(DAI), unitOfAccount, 1e18);

            startHoax(user2);

            deal(USDC, user2, 100_000e6);
            IERC20(USDC).approve(address(eUSDC), type(uint256).max);
            eUSDC.deposit(type(uint256).max, user2);

            bytes32 slot = keccak256(abi.encode(user2, 0)); // stEth balances are at slot 0
            vm.store(STETH, slot, bytes32(uint256(100_000e18)));
            IERC20(STETH).approve(address(eSTETH), type(uint256).max);
            eSTETH.deposit(type(uint256).max, user2);

            startHoax(user);

            evc.enableCollateral(user, address(eGRT));
            evc.enableCollateral(user, address(eUSDT));
        }

        startHoax(user);

        deal(GRT, user, 100_000e18);
        IERC20(GRT).approve(address(eGRT), type(uint256).max);
        eGRT.deposit(type(uint256).max, user);

        deal(DAI, user, 100_000e18);
        IERC20(DAI).approve(address(eDAI), type(uint256).max);
        eDAI.deposit(type(uint256).max, user);

        deal(USDT, user, 100_000e6);
        // USDT returns void
        (bool success,) = USDT.call(abi.encodeCall(IERC20.approve, (address(eUSDT), type(uint256).max)));
        if (!success) revert("USDT approval");
        eUSDT.deposit(type(uint256).max, user);
    }

    function test_swapperEnso_basicSwapDAIUSDC() external {
        setupFork(DAI_USDC_BLOCK, true);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eDAI),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, ((1e18), address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_ENSO(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: DAI,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: DAI_USDC_inectReceiver(address(eUSDC))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 1, type(uint256).max))
        });

        uint256 eUSDCBalanceBefore = eUSDC.balanceOf(user);
        evc.batch(items);
        uint256 eUSDCBalanceAfter = eUSDC.balanceOf(user);

        console2.log("eUSDCBalanceBefore", eUSDCBalanceBefore);
        console2.log("eUSDCBalanceAfter", eUSDCBalanceAfter);
    }
}
