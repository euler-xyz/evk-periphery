// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault, IERC4626, IERC20} from "evk/EVault/IEVault.sol";

import {ISwapper} from "../../src/Swaps/ISwapper.sol";
import {Swapper} from "../../src/Swaps/Swapper.sol";
import {SwapVerifier} from "../../src/Swaps/SwapVerifier.sol";

import {Permit2ECDSASigner} from "evk-test/mocks/Permit2ECDSASigner.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import "./Payloads.sol";

import "forge-std/Test.sol";

/// @notice The tests operate on a fork. Create a .env file with FORK_RPC_URL as per fondry docs
contract Swaps1Inch is EVaultTestBase {
    uint256 mainnetFork;
    Swapper swapper;
    SwapVerifier swapVerifier;

    // note for prod, use the latest aggregator V6
    address constant oneInchAggregatorV5 = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    address constant uniswapRouterV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant uniswapRouterV3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant uniswapRouter02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address constant GRT = 0xc944E90C64B2c07662A292be6244BDf05Cda44a7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

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

    function setUp() public virtual override {
        super.setUp();

        user = makeAddr("user");
        user2 = makeAddr("user2");

        swapper = new Swapper(uniswapRouterV2, uniswapRouterV3);
        swapVerifier = new SwapVerifier(address(evc), permit2Address);

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

        eGRT.setHookConfig(address(0), 0);
        eUSDC.setHookConfig(address(0), 0);
        eSTETH.setHookConfig(address(0), 0);
        eUSDT.setHookConfig(address(0), 0);

        if (forBorrow) {
            eUSDC.setLTV(address(eGRT), 0.97e4, 0.97e4, 0);
            eSTETH.setLTV(address(eUSDT), 0.97e4, 0.97e4, 0);

            oracle.setPrice(address(USDC), unitOfAccount, 1e18);
            oracle.setPrice(address(GRT), unitOfAccount, 1e18);
            oracle.setPrice(address(STETH), unitOfAccount, 1e18);
            oracle.setPrice(address(USDT), unitOfAccount, 1e30);

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

        deal(USDT, user, 100_000e6);
        // USDT returns void
        (bool success,) = USDT.call(abi.encodeCall(IERC20.approve, (address(eUSDT), type(uint256).max)));
        if (!success) revert("USDT approval");
        eUSDT.deposit(type(uint256).max, user);
    }

    function test_swapperOneInchV5_basicSwapGRTUSDC() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 1, type(uint256).max))
        });

        evc.batch(items);

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18);
        assertEq(eUSDC.totalSupply(), 125.018572e6);
        assertEq(eUSDC.totalAssets(), 125.018572e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18);
        assertEq(eGRT.maxWithdraw(user), 100_000e18 - 1000e18);
        assertEq(eUSDC.balanceOf(user), 125.018572e6);
        assertEq(eUSDC.maxWithdraw(user), 125.018572e6);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_basicSwapGRTUSDC_exactOutMode() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_OUT,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(eGRT),
                    accountIn: user,
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 1, type(uint256).max))
        });

        evc.batch(items);

        // Results are the same as in exact input mode. There is no unused input to be returned.

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18);
        assertEq(eUSDC.totalSupply(), 125.018572e6);
        assertEq(eUSDC.totalAssets(), 125.018572e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18);
        assertEq(eGRT.maxWithdraw(user), 100_000e18 - 1000e18);
        assertEq(eUSDC.balanceOf(user), 125.018572e6);
        assertEq(eUSDC.maxWithdraw(user), 125.018572e6);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_exectOutGRTUSDC_firstOverswapped() external {
        setupFork(GRT_USDC_BLOCK, false);

        bytes[] memory multicallItems = new bytes[](3);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_EXACT_OUT,
                account: address(0),
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 120e6,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(swapper),
                data: GRT_USDC_V2_PATH
            })
        );
        multicallItems[2] = abi.encodeCall(Swapper.sweep, (USDC, 0, address(eUSDC)));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 120e6, type(uint256).max))
        });

        evc.batch(items);

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18);
        assertEq(eUSDC.totalSupply(), 125.018572e6);
        assertEq(eUSDC.totalAssets(), 125.018572e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18);
        assertEq(eGRT.maxWithdraw(user), 100_000e18 - 1000e18);
        assertEq(eUSDC.balanceOf(user), 125.018572e6);
        assertEq(eUSDC.maxWithdraw(user), 125.018572e6);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_exectOutGRTUSDC_twoSteps() external {
        setupFork(GRT_USDC_BLOCK, false);

        bytes[] memory multicallItems = new bytes[](3);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_EXACT_OUT,
                account: address(0),
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 130e6,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(swapper),
                data: GRT_USDC_V2_PATH
            })
        );
        multicallItems[2] = abi.encodeCall(Swapper.sweep, (USDC, 0, address(eUSDC)));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 130e6, type(uint256).max))
        });

        evc.batch(items);

        // vaults
        assertEq(eGRT.totalSupply(), 98960.107617856350262041e18);
        assertEq(eGRT.totalAssets(), 98960.107617856350262041e18);
        assertEq(eUSDC.totalSupply(), 130e6);
        assertEq(eUSDC.totalAssets(), 130e6);

        // account
        assertEq(eGRT.balanceOf(user), 98960107617856350262041);
        assertEq(eGRT.maxWithdraw(user), 98960107617856350262041);
        assertEq(eUSDC.balanceOf(user), 130e6);
        assertEq(eUSDC.maxWithdraw(user), 130e6);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_exectOutGRTUSDC_twoSteps_fromSubaccount() external {
        setupFork(GRT_USDC_BLOCK, false);

        address subAccount = getSubAccount(user, 5);
        deal(GRT, user, 100_000e18);
        eGRT.deposit(100_000e18, subAccount);

        bytes[] memory multicallItems = new bytes[](3);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_EXACT_OUT,
                account: address(0),
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 130e6,
                vaultIn: address(eGRT),
                accountIn: subAccount,
                receiver: address(swapper),
                data: GRT_USDC_V2_PATH
            })
        );
        multicallItems[2] = abi.encodeCall(Swapper.sweep, (USDC, 0, address(eUSDC)));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: subAccount,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), subAccount))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 130e6, type(uint256).max))
        });

        evc.batch(items);

        // vaults
        assertEq(eGRT.totalSupply(), 198960.107617856350262041e18);
        assertEq(eGRT.totalAssets(), 198960.107617856350262041e18);
        assertEq(eUSDC.totalSupply(), 130e6);
        assertEq(eUSDC.totalAssets(), 130e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18);
        assertEq(eGRT.maxWithdraw(user), 100_000e18);
        assertEq(eGRT.balanceOf(subAccount), 98960107617856350262041);
        assertEq(eGRT.maxWithdraw(subAccount), 98960107617856350262041);
        assertEq(eUSDC.balanceOf(user), 130e6);
        assertEq(eUSDC.maxWithdraw(user), 130e6);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_exectInGRTUSDC_insufficientAmountIn() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (900e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 1, type(uint256).max))
        });

        bytes memory err = abi.encodeWithSignature("Error(string)", ("ERC20: transfer amount exceeds balance"));
        bytes memory swapperErr = abi.encodePacked(
            bytes4(keccak256("Swapper_SwapError(address,bytes)")), abi.encode(oneInchAggregatorV5, err)
        );
        vm.expectRevert(swapperErr);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectOutGRTUSDC_insufficientAmountInSecondary() external {
        setupFork(GRT_USDC_BLOCK, false);

        bytes[] memory multicallItems = new bytes[](3);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_EXACT_OUT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 200e6,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(swapper),
                data: GRT_USDC_V2_PATH
            })
        );
        multicallItems[2] = abi.encodeCall(Swapper.sweep, (USDC, 0, address(eUSDC)));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 200e6, type(uint256).max))
        });
        bytes memory err = abi.encodeWithSignature("Error(string)", ("TransferHelper: TRANSFER_FROM_FAILED"));
        bytes memory swapperErr =
            abi.encodePacked(bytes4(keccak256("Swapper_SwapError(address,bytes)")), abi.encode(uniswapRouterV2, err));
        vm.expectRevert(swapperErr);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectOutGRTUSDC_insufficientAmountInSecondary_V3() external {
        setupFork(GRT_USDC_BLOCK, false);

        bytes[] memory multicallItems = new bytes[](3);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V3(),
                mode: MODE_EXACT_OUT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 200e6,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(swapper),
                data: GRT_USDC_V3_PATH
            })
        );
        multicallItems[2] = abi.encodeCall(Swapper.sweep, (USDC, 0, address(eUSDC)));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 200e6, type(uint256).max))
        });

        bytes memory err = abi.encodeWithSignature("Error(string)", ("STF"));
        bytes memory swapperErr =
            abi.encodePacked(bytes4(keccak256("Swapper_SwapError(address,bytes)")), abi.encode(uniswapRouterV3, err));
        vm.expectRevert(swapperErr);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectInGRTUSDC_insufficientOutput() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 130e6, type(uint256).max))
        });

        vm.expectRevert(SwapVerifier.SwapVerifier_skimMin.selector);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectInGRTUSDC_receiverMismatch() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(user)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 130e6, type(uint256).max))
        });

        vm.expectRevert(SwapVerifier.SwapVerifier_skimMin.selector);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectInGRTUSDC_pastDeadline() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 120e6, block.timestamp - 1))
        });

        vm.expectRevert(SwapVerifier.SwapVerifier_pastDeadline.selector);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectInGRTUSDC_invalidMode() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_INVALID,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 120e6, type(uint256).max))
        });

        vm.expectRevert(Swapper.Swapper_UnknownMode.selector);
        evc.batch(items);
    }

    function test_swapperOneInchV5_exectInGRTUSDC_unknownHandler() external {
        setupFork(GRT_USDC_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e18, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: bytes32("Unknown"),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: GRT,
                    tokenOut: USDC,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(eUSDC)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eUSDC), user, 120e6, type(uint256).max))
        });

        vm.expectRevert(Swapper.Swapper_UnknownHandler.selector);
        evc.batch(items);
    }

    function test_swapperOneInchV5_GRTUSDC_swapAndRepay_V2() external {
        setupFork(GRT_USDC_BLOCK, true);

        evc.enableController(user, address(eUSDC));
        eUSDC.borrow(130e6, user);

        bytes[] memory multicallItems = new bytes[](2);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_TARGET_DEBT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(eUSDC),
                data: GRT_USDC_V2_PATH
            })
        );

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eUSDC), user, 0, type(uint256).max))
        });

        evc.batch(items);

        uint256 secondaryAmountIn = 39.892382143649737959e18;

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eUSDC.totalSupply(), 100_000e6);
        assertEq(eUSDC.totalAssets(), 100_000e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eUSDC.balanceOf(user), 0);
        assertEq(eUSDC.debtOf(user), 0);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_GRTUSDC_swapAndRepay_V2_swapFromSubaccount() external {
        setupFork(GRT_USDC_BLOCK, true);

        evc.enableController(user, address(eUSDC));
        eUSDC.borrow(130e6, user);

        address subAccount = getSubAccount(user, 5);
        deal(GRT, user, 100_000e18);
        eGRT.deposit(100_000e18, subAccount);

        bytes[] memory multicallItems = new bytes[](2);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_TARGET_DEBT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0,
                vaultIn: address(eGRT),
                accountIn: subAccount,
                receiver: address(eUSDC),
                data: GRT_USDC_V2_PATH
            })
        );

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: subAccount,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), subAccount))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eUSDC), user, 0, type(uint256).max))
        });

        evc.batch(items);

        uint256 secondaryAmountIn = 39.892382143649737959e18;

        // vaults
        assertEq(eGRT.totalSupply(), 200_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eGRT.totalAssets(), 200_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eUSDC.totalSupply(), 100_000e6);
        assertEq(eUSDC.totalAssets(), 100_000e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18);
        assertEq(eGRT.balanceOf(subAccount), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eUSDC.balanceOf(user), 0);
        assertEq(eUSDC.debtOf(user), 0);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_GRTUSDC_swapAndRepay_V3() external {
        setupFork(GRT_USDC_BLOCK, true);

        evc.enableController(user, address(eUSDC));
        eUSDC.borrow(130e6, user);

        bytes[] memory multicallItems = new bytes[](2);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V3(),
                mode: MODE_TARGET_DEBT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(eUSDC),
                data: GRT_USDC_V3_PATH
            })
        );

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eUSDC), user, 0, type(uint256).max))
        });

        evc.batch(items);

        uint256 secondaryAmountIn = 40.55895342159832226e18;

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eUSDC.totalSupply(), 100_000e6);
        assertEq(eUSDC.totalAssets(), 100_000e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18 - secondaryAmountIn);
        assertEq(eUSDC.balanceOf(user), 0);
        assertEq(eUSDC.debtOf(user), 0);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_GRTUSDC_swapAndRepay_primaryOverswaps() external {
        setupFork(GRT_USDC_BLOCK, true);

        evc.enableController(user, address(eUSDC));
        eUSDC.borrow(90e6, user);

        bytes[] memory multicallItems = new bytes[](2);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_TARGET_DEBT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(eUSDC),
                data: GRT_USDC_V2_PATH
            })
        );

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eUSDC), user, 0, type(uint256).max))
        });

        evc.batch(items);

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18);
        assertEq(eUSDC.totalSupply(), 100_000e6 + 35.018572e6); // excess amount after repay is deposited
        assertEq(eUSDC.totalAssets(), 100_000e6 + 35.018572e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18);
        assertEq(eUSDC.balanceOf(user), 35.018572e6); // excess amount after repay is deposited
        assertEq(eUSDC.debtOf(user), 0);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    function test_swapperOneInchV5_GRTUSDC_swapAndRepay_overswapOnGenericHandler() external {
        setupFork(GRT_USDC_BLOCK, true);

        evc.enableController(user, address(eUSDC));
        eUSDC.borrow(90e6, user);

        bytes memory swapPayload = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_TARGET_DEBT,
                account: user,
                tokenIn: GRT,
                tokenOut: USDC,
                amountOut: 0,
                vaultIn: address(eGRT),
                accountIn: user,
                receiver: address(eUSDC),
                data: abi.encode(oneInchAggregatorV5, GRT_USDC_injectReceiver(address(swapper)))
            })
        );

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eGRT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1500e18, address(swapper), user))
        });
        items[1] =
            IEVC.BatchItem({onBehalfOfAccount: user, targetContract: address(swapper), value: 0, data: swapPayload});
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eUSDC), user, 0, type(uint256).max))
        });

        evc.batch(items);

        // Results are the same as with 2 step method (test_swapperOneInchV5_GRTUSDC_swapAndRepay_primaryOverswaps)

        // vaults
        assertEq(eGRT.totalSupply(), 100_000e18 - 1000e18);
        assertEq(eGRT.totalAssets(), 100_000e18 - 1000e18);
        assertEq(eUSDC.totalSupply(), 100_000e6 + 35.018572e6); // excess amount after repay is deposited
        assertEq(eUSDC.totalAssets(), 100_000e6 + 35.018572e6);

        // account
        assertEq(eGRT.balanceOf(user), 100_000e18 - 1000e18);
        assertEq(eUSDC.balanceOf(user), 35.018572e6); // excess amount after repay is deposited
        assertEq(eUSDC.debtOf(user), 0);

        // swapper
        assertEq(IERC20(GRT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
    }

    /// @dev Note rebasing tokens like stETH are not supported by current EVault implementation. They are by the Swapper
    function test_swapperOneInchV5_basicSwapUSDTSTETH() external {
        setupFork(USDT_STETH_BLOCK, false);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eUSDT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (1000e6, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(
                Swapper.swap,
                ISwapper.SwapParams({
                    handler: swapper.HANDLER_GENERIC(),
                    mode: MODE_EXACT_IN,
                    account: address(0), // ignored
                    tokenIn: USDT,
                    tokenOut: STETH,
                    amountOut: 0, // ignored
                    vaultIn: address(0), // ignored
                    accountIn: address(0), // ignored
                    receiver: address(0), // ignored
                    data: abi.encode(oneInchAggregatorV5, USDT_STETH_injectReceiver(address(eSTETH)))
                })
            )
        });

        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyAmountMinAndSkim, (address(eSTETH), user, 1, type(uint256).max))
        });

        evc.batch(items);

        // vaults
        assertEq(eUSDT.totalSupply(), 100_000e6 - 1000e6);
        assertEq(eUSDT.totalAssets(), 100_000e6 - 1000e6);
        assertEq(eSTETH.totalSupply(), 0.611673717012496885e18);
        assertEq(eSTETH.totalAssets(), 0.611673717012496885e18);

        // account
        assertEq(eUSDT.balanceOf(user), 100_000e6 - 1000e6);
        assertEq(eUSDT.maxWithdraw(user), 100_000e6 - 1000e6);
        assertEq(eSTETH.balanceOf(user), 0.611673717012496885e18);
        assertEq(eSTETH.maxWithdraw(user), 0.611673717012496885e18);

        // swapper
        assertEq(IERC20(USDT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(STETH).balanceOf(address(swapper)), 0);
    }

    /// @dev Note rebasing tokens like stETH are not supported by current EVault implementation. They are by the Swapper
    function test_swapperOneInchV5_USDTSTETH_swapAndRepay_V2_exactOutNotExact() external {
        setupFork(USDT_STETH_BLOCK, true);

        evc.enableController(user, address(eSTETH));
        eSTETH.borrow(1e18, user);

        // after this delay stETH amount out swap will not be exact. Requested 388326302774618474, received
        // 388326302774618472
        skip(63);

        uint256 totalSupplyBeforeSTETH = eSTETH.totalSupply();
        uint256 totalAssetsBeforeSTETH = eSTETH.totalAssets();

        bytes[] memory multicallItems = new bytes[](2);
        multicallItems[0] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_GENERIC(),
                mode: MODE_EXACT_IN,
                account: address(0), // ignored
                tokenIn: USDT,
                tokenOut: STETH,
                amountOut: 0, // ignored
                vaultIn: address(0), // ignored
                accountIn: address(0), // ignored
                receiver: address(0), // ignored
                data: abi.encode(oneInchAggregatorV5, USDT_STETH_injectReceiver(address(swapper)))
            })
        );
        multicallItems[1] = abi.encodeCall(
            Swapper.swap,
            ISwapper.SwapParams({
                handler: swapper.HANDLER_UNISWAP_V2(),
                mode: MODE_TARGET_DEBT,
                account: user,
                tokenIn: USDT,
                tokenOut: STETH,
                amountOut: 0,
                vaultIn: address(eUSDT),
                accountIn: user,
                receiver: address(eSTETH),
                data: USDT_STETH_V2_PATH
            })
        );

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(eUSDT),
            value: 0,
            data: abi.encodeCall(IERC4626.withdraw, (2000e6, address(swapper), user))
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapper),
            value: 0,
            data: abi.encodeCall(Swapper.multicall, multicallItems)
        });

        // Try to repay exactly to 0
        uint256 exactOutTolerance = 0;
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eSTETH), user, exactOutTolerance, type(uint256).max))
        });

        vm.expectRevert(SwapVerifier.SwapVerifier_debtMax.selector);
        evc.batch(items);

        // Allow 2 wei difference
        exactOutTolerance = 2;
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user,
            targetContract: address(swapVerifier),
            value: 0,
            data: abi.encodeCall(swapVerifier.verifyDebtMax, (address(eSTETH), user, exactOutTolerance, type(uint256).max))
        });

        evc.batch(items);

        uint256 secondaryAmountIn = 641.290668e6;

        // vaults
        assertEq(eUSDT.totalSupply(), 100_000e6 - 1000e6 - secondaryAmountIn);
        assertEq(eUSDT.totalAssets(), 100_000e6 - 1000e6 - secondaryAmountIn);
        assertEq(eSTETH.totalSupply(), totalSupplyBeforeSTETH);
        assertEq(eSTETH.totalAssets(), totalAssetsBeforeSTETH);

        // account
        assertEq(eUSDT.balanceOf(user), 100_000e6 - 1000e6 - secondaryAmountIn);
        assertEq(eSTETH.balanceOf(user), 0);
        assertEq(eSTETH.debtOf(user), exactOutTolerance);

        // swapper
        assertEq(IERC20(USDT).balanceOf(address(swapper)), 0);
        assertEq(IERC20(STETH).balanceOf(address(swapper)), 1); // some residual dust is left by the weird token
    }

    function test_swapperRepayAndDeposit_maxRepayAmount() external {
        // Setup
        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0.9e4, 0);

        startHoax(user);

        assetTST.mint(user, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, user);

        startHoax(user2);

        assetTST2.mint(user2, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, user2);

        evc.enableCollateral(user2, address(eTST2));
        evc.enableController(user2, address(eTST));

        eTST.borrow(5e18, user2);

        // simulate swap

        assetTST.mint(address(swapper), 7e18);

        uint256 snapshot = vm.snapshot();

        assertEq(eTST.debtOf(user2), 5e18);
        assertEq(eTST.balanceOf(user2), 0);
        swapper.repayAndDeposit(address(assetTST), address(eTST), 5e18, user2);
        assertEq(eTST.debtOf(user2), 0);
        assertEq(eTST.balanceOf(user2), 2e18);

        // do the same with smaller amount

        vm.revertTo(snapshot);
        swapper.repayAndDeposit(address(assetTST), address(eTST), 1e18, user2);
        assertEq(eTST.debtOf(user2), 4e18);
        assertEq(eTST.balanceOf(user2), 6e18);

        // use max uint as repayAmount

        vm.revertTo(snapshot);
        swapper.repayAndDeposit(address(assetTST), address(eTST), type(uint256).max, user2);
        assertEq(eTST.debtOf(user2), 0);
        assertEq(eTST.balanceOf(user2), 2e18);
    }

    function test_transferFromSender_allowance() external {
        assetTST.mint(user, 1e18);
        assertEq(assetTST.balanceOf(address(swapper)), 0);

        startHoax(user);
        vm.expectRevert(); // no approvals
        swapVerifier.transferFromSender(address(assetTST), 1e18, address(swapper));

        assetTST.approve(address(swapVerifier), 2e18);

        startHoax(user2);
        vm.expectRevert(); // other users can't pull
        swapVerifier.transferFromSender(address(assetTST), 1e18, address(swapper));

        startHoax(user);
        swapVerifier.transferFromSender(address(assetTST), 1e18, address(swapper));

        assertEq(assetTST.balanceOf(address(swapper)), 1e18);
    }

    function test_transferFromSender_permit2() external {
        assertEq(assetTST.balanceOf(address(swapper)), 0);

        Permit2ECDSASigner permit2Signer = new Permit2ECDSASigner(address(permit2));

        uint256 userPK = 0x123400;
        address signer = vm.addr(userPK);

        assetTST.mint(signer, 1e18);

        startHoax(signer);
        vm.expectRevert(); // no approvals
        swapVerifier.transferFromSender(address(assetTST), 1e18, address(swapper));

        // approve permit2 contract to spend the tokens
        assetTST.approve(permit2, type(uint160).max);

        // build permit2 object
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(assetTST),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: address(swapVerifier),
            sigDeadline: type(uint256).max
        });

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0].onBehalfOfAccount = signer;
        items[0].targetContract = permit2;
        items[0].value = 0;
        items[0].data = abi.encodeWithSignature(
            "permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)",
            signer,
            permitSingle,
            permit2Signer.signPermitSingle(userPK, permitSingle)
        );

        items[1].onBehalfOfAccount = signer;
        items[1].targetContract = address(swapVerifier);
        items[1].value = 0;
        items[1].data = abi.encodeCall(swapVerifier.transferFromSender, (address(assetTST), 1e18, address(swapper)));

        evc.batch(items);

        assertEq(assetTST.balanceOf(address(swapper)), 1e18);
    }
}
