// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {MigrationHelper, IMorpho} from "../../src/Swaps/MigrationHelper.sol";
import {ISwapper} from "../../src/Swaps/ISwapper.sol";
import {SwapVerifier} from "../../src/Swaps/SwapVerifier.sol";
import "./MigrationHelperSwapRoutes.sol";

interface IAavePoolFork {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external;
    function withdraw(address asset, uint256 amount, address to) external;
}

interface IVariableDebtTokenFork {
    function approveDelegation(address delegatee, uint256 amount) external;
}

interface IEVaultFork {
    function debtOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function borrow(uint256 amount, address receiver) external returns (uint256);
    function redeem(uint256 amount, address receiver, address owner) external returns (uint256);
    function transferFromMax(address from, address to) external returns (bool);
    function disableController() external;
}

interface IMorphoFork is IMorpho {
    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );

    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function repay(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid);
    function supplyCollateral(MarketParams calldata marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;
    function supply(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);
}

/// @notice Fork tests for full-position migrations through EVC batches and Swapper multicalls.
/// @dev The fork supplies real protocol contracts, token implementations, and account positions.
contract MigrationHelperForkTest is Test {
    address internal constant EVC = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383;
    address internal constant OWNER = 0x8A54C278D117854486db0F6460D901a180Fff517;
    address internal constant POSITION_SUB_ACCOUNT = 0x8a54C278D117854486Db0f6460D901A180fFF504;
    address internal constant EULER_MIGRATION_ACCOUNT = 0x8A54c278D117854486db0f6460D901A180FF2bBa;
    address internal constant SWAP_VERIFIER = 0x312eE8B4a2df952E3c52Bb155c44F54f81f92d1d;
    address internal constant SWAPPER = 0x719F8b330CcA71cb6195D032A43194C7D3F9Fb45;

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant A_USDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant A_WETH = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address internal constant VARIABLE_DEBT_USDT = 0x6df1C1E379bC5a00a7b4C6e67A203333772f45A8;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address internal constant USDC_VAULT = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address internal constant USDT_VAULT = 0x313603FA690301b0CaeEf8069c065862f9162162;
    address internal constant WETH_VAULT = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2;
    address internal constant WSTETH_VAULT = 0xbC4B4AC47582c3E38Ce5940B80Da65401F4628f1;
    address internal constant OLD_POSITION_COLLATERAL_VAULT = 0x412D0E31790D77b6e7a7872a9fd6967B6E640229;

    address internal constant MORPHO_ORACLE = 0x0F948CBa8231Db7898ef36A4212581Ad7b1B4580;
    address internal constant MORPHO_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    bytes32 internal constant HANDLER_GENERIC = bytes32("Generic");

    uint256 internal constant AAVE_VARIABLE_RATE_MODE = 2;
    uint256 internal constant MORPHO_LLTV = 860_000_000_000_000_000;

    uint256 internal constant MORPHO_WETH_WITHDRAW_AMOUNT = 17_897_776_116_692_377;
    uint256 internal constant MORPHO_USDC_REPAY_SHARES = 17_413_856_871_975;
    uint256 internal constant MORPHO_USDC_REPAY_ASSETS = 17_827_182;
    uint256 internal constant MORPHO_TO_EULER_NO_SWAP_BORROW_AMOUNT = 18_005_277;
    uint256 internal constant MORPHO_TO_EULER_WITH_SWAP_BORROW_AMOUNT = 18_200_000;
    uint256 internal constant MORPHO_TO_EULER_DEBT_SWAP_AMOUNT_OUT = 18_182_564;
    uint256 internal constant MORPHO_TO_EULER_COLLATERAL_SWAP_AMOUNT_OUT = 14_453_702_622_485_925;

    uint256 internal constant AAVE_A_USDC_PERMIT_AMOUNT = 2_000_208;
    uint256 internal constant AAVE_USDC_COLLATERAL_AMOUNT = 2_000_033;
    uint256 internal constant AAVE_USDT_DEBT_AMOUNT = 1_486_826;
    uint256 internal constant AAVE_TO_EULER_BORROW_AMOUNT = 1_501_684;
    uint256 internal constant AAVE_TO_EULER_COLLATERAL_SWAP_AMOUNT_IN = 2_000_007;
    uint256 internal constant AAVE_TO_EULER_COLLATERAL_SWAP_AMOUNT_OUT = 1_274_986_811_621_375;

    uint256 internal constant EULER_POSITION_REDEEM_AMOUNT = 10_819_764_310_319_474;
    uint256 internal constant EULER_POSITION_EXTERNAL_COLLATERAL_AMOUNT = 11_257_028_750_852_452;
    uint256 internal constant EULER_POSITION_EXTERNAL_BORROW_AMOUNT = 2_104_503;

    uint256 internal constant MORPHO_TO_EULER_NO_SWAP_BATCH_ITEMS = 7;
    uint256 internal constant MORPHO_TO_EULER_WITH_SWAP_BATCH_ITEMS = 7;
    uint256 internal constant AAVE_TO_EULER_NO_SWAP_BATCH_ITEMS = 8;
    uint256 internal constant AAVE_TO_EULER_WITH_SWAP_BATCH_ITEMS = 7;
    uint256 internal constant EULER_TO_MORPHO_POSITION_BATCH_ITEMS = 8;
    uint256 internal constant EULER_TO_AAVE_POSITION_BATCH_ITEMS = 8;
    uint256 internal constant MIGRATION_FORK_BLOCK = 25_437_507;
    uint256 internal constant VERIFY_DEADLINE = 4_000_000_000;

    bool internal forkReady;

    function setUp() public {
        string memory forkRpcUrl = vm.envOr("FORK_RPC_URL", string(""));
        if (bytes(forkRpcUrl).length == 0) forkRpcUrl = vm.envOr("DEPLOYMENT_RPC_URL_1", string(""));

        if (bytes(forkRpcUrl).length != 0) {
            vm.createSelectFork(forkRpcUrl, MIGRATION_FORK_BLOCK);
            forkReady = true;

            vm.label(EVC, "EVC");
            vm.label(OWNER, "migration owner");
            vm.label(POSITION_SUB_ACCOUNT, "Euler position sub-account");
            vm.label(SWAP_VERIFIER, "SwapVerifier");
            vm.label(SWAPPER, "Swapper");
        }
    }

    function test_migrateMorphoPositionToEulerWithoutSwaps() public {
        _requireFork();

        vm.prank(EULER_MIGRATION_ACCOUNT);
        IEVC(EVC).setAccountOperator(EULER_MIGRATION_ACCOUNT, OWNER, true);

        // Fork fixture: Morpho approvals/authorizations are set manually/pre-seeded and are not encoded below.
        // Production batches must include the enable authorization call and the matching disable call.
        bytes32 morphoMarketId = _morphoMarketId(_morphoUsdcWethMarket());

        _executeBatch(_morphoToEulerNoSwapBatch());

        (uint256 morphoSupplySharesAfter, uint128 morphoBorrowSharesAfter, uint128 morphoCollateralAfter) =
            IMorphoFork(MORPHO).position(morphoMarketId, OWNER);
        uint256 eulerCollateralAfter = _vaultAssets(WETH_VAULT, EULER_MIGRATION_ACCOUNT);
        uint256 eulerDebtAfter = IEVaultFork(USDC_VAULT).debtOf(EULER_MIGRATION_ACCOUNT);

        assertEq(morphoSupplySharesAfter, 0);
        assertEq(morphoBorrowSharesAfter, 0);
        assertEq(morphoCollateralAfter, 0);
        assertApproxEqAbs(eulerCollateralAfter, MORPHO_WETH_WITHDRAW_AMOUNT, 1);
        assertEq(eulerDebtAfter, MORPHO_USDC_REPAY_ASSETS);
        _assertCleanSwapBalances(USDC, WETH);
    }

    function test_migrateMorphoPositionToEulerWithSwaps() public {
        _requireFork();

        vm.prank(EULER_MIGRATION_ACCOUNT);
        IEVC(EVC).setAccountOperator(EULER_MIGRATION_ACCOUNT, OWNER, true);

        // Fork fixture: Morpho approvals/authorizations are set manually/pre-seeded and are not encoded below.
        // Production batches must include the enable authorization call and the matching disable call.
        bytes32 morphoMarketId = _morphoMarketId(_morphoUsdcWethMarket());

        _executeBatch(_morphoToEulerWithSwapBatch());

        (uint256 morphoSupplySharesAfter, uint128 morphoBorrowSharesAfter, uint128 morphoCollateralAfter) =
            IMorphoFork(MORPHO).position(morphoMarketId, OWNER);
        uint256 eulerCollateralAfter = _vaultAssets(WSTETH_VAULT, EULER_MIGRATION_ACCOUNT);
        uint256 eulerDebtAfter = IEVaultFork(USDT_VAULT).debtOf(EULER_MIGRATION_ACCOUNT);

        assertEq(morphoSupplySharesAfter, 0);
        assertEq(morphoBorrowSharesAfter, 0);
        assertEq(morphoCollateralAfter, 0);
        assertEq(eulerDebtAfter, MORPHO_TO_EULER_WITH_SWAP_BORROW_AMOUNT);
        assertEq(eulerCollateralAfter, MORPHO_TO_EULER_COLLATERAL_SWAP_AMOUNT_OUT);
        _assertCleanSwapBalances(USDT, USDC, WETH, WSTETH);
    }

    function test_migrateAavePositionToEulerWithoutSwaps() public {
        _requireFork();

        vm.prank(EULER_MIGRATION_ACCOUNT);
        IEVC(EVC).setAccountOperator(EULER_MIGRATION_ACCOUNT, OWNER, true);

        _approveTokenAs(OWNER, A_USDC, SWAP_VERIFIER, AAVE_A_USDC_PERMIT_AMOUNT);

        _executeBatch(_aaveToEulerNoSwapBatch());

        uint256 aaveCollateralAfter = IERC20(A_USDC).balanceOf(OWNER);
        uint256 aaveDebtAfter = IERC20(VARIABLE_DEBT_USDT).balanceOf(OWNER);
        uint256 eulerCollateralAfter = _vaultAssets(USDC_VAULT, EULER_MIGRATION_ACCOUNT);
        uint256 eulerDebtAfter = IEVaultFork(USDT_VAULT).debtOf(EULER_MIGRATION_ACCOUNT);

        assertEq(aaveCollateralAfter, 0);
        assertEq(aaveDebtAfter, 0);
        assertApproxEqAbs(eulerCollateralAfter, AAVE_USDC_COLLATERAL_AMOUNT, 1);
        assertEq(eulerDebtAfter, AAVE_USDT_DEBT_AMOUNT);
        _assertCleanSwapBalances(USDT, A_USDC, USDC);
    }

    function test_migrateAavePositionToEulerWithSwaps() public {
        _requireFork();

        vm.prank(EULER_MIGRATION_ACCOUNT);
        IEVC(EVC).setAccountOperator(EULER_MIGRATION_ACCOUNT, OWNER, true);

        _approveTokenAs(OWNER, A_USDC, SWAP_VERIFIER, AAVE_A_USDC_PERMIT_AMOUNT);

        _executeBatch(_aaveToEulerWithSwapBatch());

        uint256 aaveCollateralAfter = IERC20(A_USDC).balanceOf(OWNER);
        uint256 aaveDebtAfter = IERC20(VARIABLE_DEBT_USDT).balanceOf(OWNER);
        uint256 eulerCollateralAfter = _vaultAssets(WETH_VAULT, EULER_MIGRATION_ACCOUNT);
        uint256 eulerDebtAfter = IEVaultFork(USDT_VAULT).debtOf(EULER_MIGRATION_ACCOUNT);

        assertEq(aaveCollateralAfter, 0);
        assertEq(aaveDebtAfter, 0);
        assertEq(eulerDebtAfter, AAVE_USDT_DEBT_AMOUNT);
        assertEq(eulerCollateralAfter, AAVE_TO_EULER_COLLATERAL_SWAP_AMOUNT_OUT);
        _assertCleanSwapBalances(USDT, A_USDC, USDC, WETH);
    }

    function test_migrateEulerPositionToMorpho() public {
        _requireFork();

        bytes32 morphoMarketId = _morphoMarketId(_morphoUsdtWethMarket());

        // Fork fixture: Morpho approvals/authorizations are set manually/pre-seeded and are not encoded below.
        // Production batches must include the enable authorization call and the matching disable call.
        _executeBatch(_eulerToMorphoPositionBatch());

        (, uint128 morphoCollateralAfter) = _morphoBorrowAndCollateral(morphoMarketId, OWNER);
        uint256 morphoDebtAfter = _morphoBorrowAssets(morphoMarketId, OWNER);
        uint256 eulerCollateralSharesAfter = IERC20(WETH_VAULT).balanceOf(POSITION_SUB_ACCOUNT);
        uint256 oldPositionCollateralSharesAfter = IERC20(OLD_POSITION_COLLATERAL_VAULT).balanceOf(POSITION_SUB_ACCOUNT);

        assertEq(IEVaultFork(USDT_VAULT).debtOf(POSITION_SUB_ACCOUNT), 0);
        assertEq(eulerCollateralSharesAfter, 0);
        assertEq(oldPositionCollateralSharesAfter, 0);
        assertApproxEqAbs(morphoDebtAfter, EULER_POSITION_EXTERNAL_BORROW_AMOUNT, 1);
        assertEq(morphoCollateralAfter, EULER_POSITION_EXTERNAL_COLLATERAL_AMOUNT);
        _assertCleanSwapBalances(USDT, WETH);
    }

    function test_migrateEulerPositionToAave() public {
        _requireFork();

        vm.prank(OWNER);
        IVariableDebtTokenFork(VARIABLE_DEBT_USDT).approveDelegation(
            SWAP_VERIFIER, EULER_POSITION_EXTERNAL_BORROW_AMOUNT
        );

        _executeBatch(_eulerToAavePositionBatch());

        uint256 eulerCollateralSharesAfter = IERC20(WETH_VAULT).balanceOf(POSITION_SUB_ACCOUNT);
        uint256 oldPositionCollateralSharesAfter = IERC20(OLD_POSITION_COLLATERAL_VAULT).balanceOf(POSITION_SUB_ACCOUNT);

        assertEq(IEVaultFork(USDT_VAULT).debtOf(POSITION_SUB_ACCOUNT), 0);
        assertEq(eulerCollateralSharesAfter, 0);
        assertEq(oldPositionCollateralSharesAfter, 0);
        assertApproxEqAbs(IERC20(A_WETH).balanceOf(OWNER), EULER_POSITION_EXTERNAL_COLLATERAL_AMOUNT, 1);
        assertApproxEqAbs(
            IERC20(VARIABLE_DEBT_USDT).balanceOf(OWNER),
            AAVE_USDT_DEBT_AMOUNT + EULER_POSITION_EXTERNAL_BORROW_AMOUNT,
            1
        );
        _assertCleanSwapBalances(USDT, WETH);
    }

    function _morphoToEulerNoSwapBatch() internal pure returns (IEVC.BatchItem[] memory items) {
        items = new IEVC.BatchItem[](MORPHO_TO_EULER_NO_SWAP_BATCH_ITEMS);
        items[0] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableController, (EULER_MIGRATION_ACCOUNT, USDC_VAULT)));
        items[1] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableCollateral, (EULER_MIGRATION_ACCOUNT, WETH_VAULT)));
        items[2] = _batchItem(
            USDC_VAULT,
            EULER_MIGRATION_ACCOUNT,
            abi.encodeCall(IEVaultFork.borrow, (MORPHO_TO_EULER_NO_SWAP_BORROW_AMOUNT, SWAPPER))
        );
        items[3] =
            _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_morphoToEulerNoSwapRepayMorphoCalls())));
        items[4] = _batchItem(SWAP_VERIFIER, OWNER, _morphoWithdrawCollateralForSenderCall(SWAP_VERIFIER));
        items[5] = _batchItem(
            SWAP_VERIFIER,
            OWNER,
            abi.encodeCall(
                SwapVerifier.verifyAmountMinAndDeposit,
                (WETH_VAULT, EULER_MIGRATION_ACCOUNT, MORPHO_WETH_WITHDRAW_AMOUNT, VERIFY_DEADLINE)
            )
        );
        items[6] = _batchItem(
            SWAPPER,
            OWNER,
            abi.encodeCall(
                ISwapper.repay, (USDC, USDC_VAULT, MORPHO_TO_EULER_NO_SWAP_BORROW_AMOUNT, EULER_MIGRATION_ACCOUNT)
            )
        );
    }

    function _morphoToEulerWithSwapBatch() internal pure returns (IEVC.BatchItem[] memory items) {
        items = new IEVC.BatchItem[](MORPHO_TO_EULER_WITH_SWAP_BATCH_ITEMS);
        items[0] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableController, (EULER_MIGRATION_ACCOUNT, USDT_VAULT)));
        items[1] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableCollateral, (EULER_MIGRATION_ACCOUNT, WSTETH_VAULT)));
        items[2] = _batchItem(
            USDT_VAULT,
            EULER_MIGRATION_ACCOUNT,
            abi.encodeCall(IEVaultFork.borrow, (MORPHO_TO_EULER_WITH_SWAP_BORROW_AMOUNT, SWAPPER))
        );
        items[3] =
            _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_morphoToEulerWithSwapRepayMorphoCalls())));
        items[4] = _batchItem(SWAP_VERIFIER, OWNER, _morphoWithdrawCollateralForSenderCall(SWAPPER));
        items[5] = _batchItem(
            SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_morphoToEulerWithSwapCollateralOuterCalls()))
        );
        items[6] = _batchItem(
            SWAP_VERIFIER,
            EULER_MIGRATION_ACCOUNT,
            abi.encodeCall(
                SwapVerifier.verifyAmountMinAndSkim,
                (WSTETH_VAULT, EULER_MIGRATION_ACCOUNT, MORPHO_TO_EULER_COLLATERAL_SWAP_AMOUNT_OUT, VERIFY_DEADLINE)
            )
        );
    }

    function _aaveToEulerNoSwapBatch() internal pure returns (IEVC.BatchItem[] memory items) {
        items = new IEVC.BatchItem[](AAVE_TO_EULER_NO_SWAP_BATCH_ITEMS);
        items[0] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableController, (EULER_MIGRATION_ACCOUNT, USDT_VAULT)));
        items[1] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableCollateral, (EULER_MIGRATION_ACCOUNT, USDC_VAULT)));
        items[2] = _batchItem(
            USDT_VAULT,
            EULER_MIGRATION_ACCOUNT,
            abi.encodeCall(IEVaultFork.borrow, (AAVE_TO_EULER_BORROW_AMOUNT, SWAPPER))
        );
        items[3] = _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_aaveToEulerDebtRepayCalls())));
        items[4] = _batchItem(SWAP_VERIFIER, OWNER, _transferBalanceFromSenderCall());
        items[5] = _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_aaveToEulerNoSwapDepositCalls())));
        items[6] = _batchItem(
            SWAP_VERIFIER,
            OWNER,
            abi.encodeCall(
                SwapVerifier.verifyAmountMinAndDeposit,
                (USDC_VAULT, EULER_MIGRATION_ACCOUNT, 2_000_007, VERIFY_DEADLINE)
            )
        );
        items[7] = _batchItem(
            SWAPPER,
            OWNER,
            abi.encodeCall(ISwapper.repay, (USDT, USDT_VAULT, AAVE_TO_EULER_BORROW_AMOUNT, EULER_MIGRATION_ACCOUNT))
        );
    }

    function _aaveToEulerWithSwapBatch() internal pure returns (IEVC.BatchItem[] memory items) {
        items = new IEVC.BatchItem[](AAVE_TO_EULER_WITH_SWAP_BATCH_ITEMS);
        items[0] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableController, (EULER_MIGRATION_ACCOUNT, USDT_VAULT)));
        items[1] =
            _batchItem(EVC, address(0), abi.encodeCall(IEVC.enableCollateral, (EULER_MIGRATION_ACCOUNT, WETH_VAULT)));
        items[2] = _batchItem(
            USDT_VAULT,
            EULER_MIGRATION_ACCOUNT,
            abi.encodeCall(IEVaultFork.borrow, (AAVE_TO_EULER_BORROW_AMOUNT, SWAPPER))
        );
        items[3] = _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_aaveToEulerDebtRepayCalls())));
        items[4] = _batchItem(SWAP_VERIFIER, OWNER, _transferBalanceFromSenderCall());
        items[5] =
            _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_aaveToEulerWithSwapCollateralCalls())));
        items[6] = _batchItem(
            SWAP_VERIFIER,
            EULER_MIGRATION_ACCOUNT,
            abi.encodeCall(
                SwapVerifier.verifyAmountMinAndSkim,
                (WETH_VAULT, EULER_MIGRATION_ACCOUNT, AAVE_TO_EULER_COLLATERAL_SWAP_AMOUNT_OUT, VERIFY_DEADLINE)
            )
        );
    }

    function _eulerToMorphoPositionBatch() internal pure returns (IEVC.BatchItem[] memory items) {
        items = new IEVC.BatchItem[](EULER_TO_MORPHO_POSITION_BATCH_ITEMS);
        items[0] = _batchItem(
            WETH_VAULT,
            POSITION_SUB_ACCOUNT,
            abi.encodeCall(IEVaultFork.redeem, (EULER_POSITION_REDEEM_AMOUNT, SWAPPER, POSITION_SUB_ACCOUNT))
        );
        items[1] =
            _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_eulerToMorphoCollateralSupplyCalls())));
        items[2] = _batchItem(SWAP_VERIFIER, OWNER, _morphoBorrowForSenderCall());
        items[3] = _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_eulerToExternalCleanupCalls())));
        items[4] = _batchItem(
            SWAP_VERIFIER,
            OWNER,
            abi.encodeCall(SwapVerifier.verifyDebtMax, (USDT_VAULT, POSITION_SUB_ACCOUNT, 0, VERIFY_DEADLINE))
        );
        items[5] = _batchItem(
            EVC,
            address(0),
            abi.encodeCall(IEVC.disableCollateral, (POSITION_SUB_ACCOUNT, OLD_POSITION_COLLATERAL_VAULT))
        );
        items[6] = _batchItem(
            OLD_POSITION_COLLATERAL_VAULT,
            POSITION_SUB_ACCOUNT,
            abi.encodeCall(IEVaultFork.transferFromMax, (POSITION_SUB_ACCOUNT, OWNER))
        );
        items[7] = _batchItem(USDT_VAULT, POSITION_SUB_ACCOUNT, abi.encodeCall(IEVaultFork.disableController, ()));
    }

    function _eulerToAavePositionBatch() internal pure returns (IEVC.BatchItem[] memory items) {
        items = new IEVC.BatchItem[](EULER_TO_AAVE_POSITION_BATCH_ITEMS);
        items[0] = _batchItem(
            WETH_VAULT,
            POSITION_SUB_ACCOUNT,
            abi.encodeCall(IEVaultFork.redeem, (EULER_POSITION_REDEEM_AMOUNT, SWAPPER, POSITION_SUB_ACCOUNT))
        );
        items[1] = _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_eulerToAaveCollateralSupplyCalls())));
        items[2] = _batchItem(SWAP_VERIFIER, OWNER, _aaveBorrowForSenderCall());
        items[3] = _batchItem(SWAPPER, OWNER, abi.encodeCall(ISwapper.multicall, (_eulerToExternalCleanupCalls())));
        items[4] = _batchItem(
            SWAP_VERIFIER,
            OWNER,
            abi.encodeCall(SwapVerifier.verifyDebtMax, (USDT_VAULT, POSITION_SUB_ACCOUNT, 0, VERIFY_DEADLINE))
        );
        items[5] = _batchItem(
            EVC,
            address(0),
            abi.encodeCall(IEVC.disableCollateral, (POSITION_SUB_ACCOUNT, OLD_POSITION_COLLATERAL_VAULT))
        );
        items[6] = _batchItem(
            OLD_POSITION_COLLATERAL_VAULT,
            POSITION_SUB_ACCOUNT,
            abi.encodeCall(IEVaultFork.transferFromMax, (POSITION_SUB_ACCOUNT, OWNER))
        );
        items[7] = _batchItem(USDT_VAULT, POSITION_SUB_ACCOUNT, abi.encodeCall(IEVaultFork.disableController, ()));
    }

    function _morphoToEulerNoSwapRepayMorphoCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
        calls[0] = _morphoRepaySwapCall();
    }

    function _morphoToEulerWithSwapRepayMorphoCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](3);
        calls[0] = _genericSwapCall(
            EULER_MIGRATION_ACCOUNT,
            USDT,
            USDC,
            USDT_VAULT,
            EULER_MIGRATION_ACCOUNT,
            SWAPPER,
            NORDSTERN_PROVIDER,
            MORPHO_TO_EULER_DEBT_PROVIDER_CALLDATA
        );
        calls[1] = _morphoRepaySwapCall();
        calls[2] = abi.encodeCall(ISwapper.sweep, (USDC, 0, OWNER));
    }

    function _morphoToEulerWithSwapCollateralOuterCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](2);
        calls[0] = abi.encodeCall(ISwapper.multicall, (_morphoToEulerWithSwapCollateralInnerCalls()));
        calls[1] = abi.encodeCall(
            ISwapper.repay, (USDT, USDT_VAULT, MORPHO_TO_EULER_WITH_SWAP_BORROW_AMOUNT, EULER_MIGRATION_ACCOUNT)
        );
    }

    function _morphoToEulerWithSwapCollateralInnerCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](3);
        calls[0] = _genericSwapCall(
            EULER_MIGRATION_ACCOUNT,
            WETH,
            WSTETH,
            address(0),
            address(0),
            WSTETH_VAULT,
            NORDSTERN_PROVIDER,
            MORPHO_TO_EULER_COLLATERAL_PROVIDER_CALLDATA
        );
        calls[1] = abi.encodeCall(ISwapper.sweep, (WETH, 1, OWNER));
        calls[2] = abi.encodeCall(ISwapper.deposit, (WSTETH, WSTETH_VAULT, 5, OWNER));
    }

    function _aaveToEulerDebtRepayCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
        calls[0] = _genericSwapCall(
            AAVE_POOL,
            USDT,
            USDT,
            AAVE_POOL,
            AAVE_POOL,
            AAVE_POOL,
            AAVE_POOL,
            abi.encodeCall(IAavePoolFork.repay, (USDT, AAVE_TO_EULER_BORROW_AMOUNT, AAVE_VARIABLE_RATE_MODE, OWNER))
        );
    }

    function _aaveToEulerNoSwapDepositCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
        calls[0] = _aaveWithdrawSwapCall(SWAP_VERIFIER);
    }

    function _aaveToEulerWithSwapCollateralCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](3);
        calls[0] = _aaveWithdrawSwapCall(SWAPPER);
        calls[1] = abi.encodeCall(ISwapper.multicall, (_aaveToEulerWithSwapCollateralInnerCalls()));
        calls[2] =
            abi.encodeCall(ISwapper.repay, (USDT, USDT_VAULT, AAVE_TO_EULER_BORROW_AMOUNT, EULER_MIGRATION_ACCOUNT));
    }

    function _aaveToEulerWithSwapCollateralInnerCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](4);
        calls[0] = _genericSwapCall(
            EULER_MIGRATION_ACCOUNT,
            USDC,
            WETH,
            address(0),
            address(0),
            WETH_VAULT,
            NORDSTERN_PROVIDER,
            AAVE_TO_EULER_COLLATERAL_PROVIDER_CALLDATA
        );
        calls[1] = abi.encodeCall(ISwapper.sweep, (WETH, 0, WETH_VAULT));
        calls[2] = abi.encodeCall(ISwapper.sweep, (USDC, 1, OWNER));
        calls[3] = abi.encodeCall(ISwapper.deposit, (WETH, WETH_VAULT, 5, OWNER));
    }

    function _eulerToMorphoCollateralSupplyCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
        calls[0] = _genericSwapCall(
            MORPHO,
            WETH,
            WETH,
            MORPHO,
            MORPHO,
            MORPHO,
            MORPHO,
            abi.encodeCall(
                IMorphoFork.supplyCollateral,
                (_morphoUsdtWethMarket(), EULER_POSITION_EXTERNAL_COLLATERAL_AMOUNT, OWNER, bytes(""))
            )
        );
    }

    function _eulerToAaveCollateralSupplyCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
        calls[0] = _genericSwapCall(
            AAVE_POOL,
            WETH,
            WETH,
            AAVE_POOL,
            AAVE_POOL,
            AAVE_POOL,
            AAVE_POOL,
            abi.encodeCall(IAavePoolFork.supply, (WETH, EULER_POSITION_EXTERNAL_COLLATERAL_AMOUNT, OWNER, 0))
        );
    }

    function _eulerToExternalCleanupCalls() internal pure returns (bytes[] memory calls) {
        calls = new bytes[](3);
        calls[0] = abi.encodeCall(ISwapper.repay, (USDT, USDT_VAULT, type(uint256).max, POSITION_SUB_ACCOUNT));
        calls[1] = abi.encodeCall(ISwapper.sweep, (USDT, 0, OWNER));
        calls[2] = abi.encodeCall(ISwapper.sweep, (WETH, 0, OWNER));
    }

    function _morphoRepaySwapCall() internal pure returns (bytes memory) {
        return _genericSwapCall(
            MORPHO,
            USDC,
            USDC,
            MORPHO,
            MORPHO,
            MORPHO,
            MORPHO,
            abi.encodeCall(IMorphoFork.repay, (_morphoUsdcWethMarket(), 0, MORPHO_USDC_REPAY_SHARES, OWNER, bytes("")))
        );
    }

    function _aaveWithdrawSwapCall(address withdrawReceiver) internal pure returns (bytes memory) {
        return _genericSwapCall(
            AAVE_POOL,
            A_USDC,
            USDC,
            AAVE_POOL,
            AAVE_POOL,
            AAVE_POOL,
            AAVE_POOL,
            abi.encodeCall(IAavePoolFork.withdraw, (USDC, type(uint256).max, withdrawReceiver))
        );
    }

    function _genericSwapCall(
        address account,
        address tokenIn,
        address tokenOut,
        address vaultIn,
        address accountIn,
        address receiver,
        address target,
        bytes memory targetCallData
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(
            ISwapper.swap,
            (
                ISwapper.SwapParams({
                    handler: HANDLER_GENERIC,
                    mode: 0,
                    account: account,
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    vaultIn: vaultIn,
                    accountIn: accountIn,
                    receiver: receiver,
                    amountOut: 0,
                    data: abi.encode(target, targetCallData)
                })
            )
        );
    }

    function _morphoWithdrawCollateralForSenderCall(address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(
            MigrationHelper.morphoWithdrawCollateralForSender,
            (MORPHO, _morphoUsdcWethMarket(), MORPHO_WETH_WITHDRAW_AMOUNT, receiver)
        );
    }

    function _transferBalanceFromSenderCall() internal pure returns (bytes memory) {
        return abi.encodeCall(MigrationHelper.transferBalanceFromSender, (A_USDC, AAVE_A_USDC_PERMIT_AMOUNT, SWAPPER));
    }

    function _morphoBorrowForSenderCall() internal pure returns (bytes memory) {
        return abi.encodeCall(
            MigrationHelper.morphoBorrowForSender,
            (MORPHO, _morphoUsdtWethMarket(), EULER_POSITION_EXTERNAL_BORROW_AMOUNT, SWAPPER)
        );
    }

    function _aaveBorrowForSenderCall() internal pure returns (bytes memory) {
        return abi.encodeCall(
            MigrationHelper.aaveBorrowForSender, (AAVE_POOL, USDT, EULER_POSITION_EXTERNAL_BORROW_AMOUNT, SWAPPER)
        );
    }

    function _morphoUsdcWethMarket() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: MORPHO_ORACLE,
            irm: MORPHO_IRM,
            lltv: MORPHO_LLTV
        });
    }

    function _morphoUsdtWethMarket() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: USDT,
            collateralToken: WETH,
            oracle: MORPHO_ORACLE,
            irm: MORPHO_IRM,
            lltv: MORPHO_LLTV
        });
    }

    function _morphoMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }

    function _morphoBorrowAndCollateral(bytes32 marketId, address account)
        internal
        view
        returns (uint128 borrowShares, uint128 collateral)
    {
        (, borrowShares, collateral) = IMorphoFork(MORPHO).position(marketId, account);
    }

    function _morphoBorrowAssets(bytes32 marketId, address account) internal view returns (uint256) {
        (uint128 borrowShares,) = _morphoBorrowAndCollateral(marketId, account);
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = IMorphoFork(MORPHO).market(marketId);
        if (borrowShares == 0 || totalBorrowShares == 0) return 0;

        return (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1)
            / uint256(totalBorrowShares);
    }

    function _vaultAssets(address vault, address account) internal view returns (uint256) {
        return IEVaultFork(vault).convertToAssets(IERC20(vault).balanceOf(account));
    }

    function _assertCleanSwapBalances(address token0, address token1) internal view {
        _assertCleanSwapBalance(token0);
        _assertCleanSwapBalance(token1);
    }

    function _assertCleanSwapBalances(address token0, address token1, address token2) internal view {
        _assertCleanSwapBalance(token0);
        _assertCleanSwapBalance(token1);
        _assertCleanSwapBalance(token2);
    }

    function _assertCleanSwapBalances(address token0, address token1, address token2, address token3) internal view {
        _assertCleanSwapBalance(token0);
        _assertCleanSwapBalance(token1);
        _assertCleanSwapBalance(token2);
        _assertCleanSwapBalance(token3);
    }

    function _assertCleanSwapBalance(address token) internal view {
        assertEq(IERC20(token).balanceOf(SWAPPER), 0);
        assertEq(IERC20(token).balanceOf(SWAP_VERIFIER), 0);
    }

    function _batchItem(address target, address onBehalf, bytes memory data)
        internal
        pure
        returns (IEVC.BatchItem memory)
    {
        return IEVC.BatchItem({targetContract: target, onBehalfOfAccount: onBehalf, value: 0, data: data});
    }

    function _approveTokenAs(address owner, address token, address spender, uint256 amount) internal {
        vm.prank(owner);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        assertTrue(success && (data.length == 0 || abi.decode(data, (bool))), "approve failed");
    }

    function _executeBatch(IEVC.BatchItem[] memory items) internal {
        vm.prank(OWNER);
        IEVC(EVC).batch(items);
    }

    function _requireFork() internal {
        vm.skip(!forkReady);
    }
}
