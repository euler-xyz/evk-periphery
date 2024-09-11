// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {Test} from "forge-std/Test.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {boundAddr, distinct} from "euler-price-oracle-test/utils/TestUtils.sol";
import {
    CHAINLINK_ETH_USD_FEED,
    CHAINLINK_USDC_USD_FEED,
    CHAINLINK_USDT_USD_FEED,
    CHAINLINK_BTC_USD_FEED
} from "euler-price-oracle-test/adapter/chainlink/ChainlinkAddresses.sol";
import {USDC, USDT, WBTC, WETH, USD} from "euler-price-oracle-test/utils/EthereumAddresses.sol";
import {IOracle, OracleLens} from "src/Lens/OracleLens.sol";
import "src/Lens/LensTypes.sol";

contract OracleLensEulerRouterTest is Test {
    OracleLens lens;
    address wethVault;
    address wbtcVault;
    address usdcVault;
    address usdtVault;

    function setUp() public {
        lens = new OracleLens(address(0));
    }

    function testEulerRouter() public {
        vm.mockCall(WETH, abi.encodeCall(IERC20.decimals, ()), abi.encode(18));
        vm.mockCall(WBTC, abi.encodeCall(IERC20.decimals, ()), abi.encode(8));
        vm.mockCall(USDC, abi.encodeCall(IERC20.decimals, ()), abi.encode(6));
        vm.mockCall(USDT, abi.encodeCall(IERC20.decimals, ()), abi.encode(6));
        vm.mockCall(CHAINLINK_ETH_USD_FEED, abi.encodeCall(IERC20.decimals, ()), abi.encode(8));
        vm.mockCall(CHAINLINK_BTC_USD_FEED, abi.encodeCall(IERC20.decimals, ()), abi.encode(8));
        vm.mockCall(CHAINLINK_USDC_USD_FEED, abi.encodeCall(IERC20.decimals, ()), abi.encode(8));
        vm.mockCall(CHAINLINK_USDT_USD_FEED, abi.encodeCall(IERC20.decimals, ()), abi.encode(8));
        vm.mockCall(CHAINLINK_ETH_USD_FEED, abi.encodeCall(IOracle.description, ()), abi.encode("Chainlink ETH/USD"));
        vm.mockCall(CHAINLINK_BTC_USD_FEED, abi.encodeCall(IOracle.description, ()), abi.encode("Chainlink BTC/USD"));
        vm.mockCall(CHAINLINK_USDC_USD_FEED, abi.encodeCall(IOracle.description, ()), abi.encode("Chainlink USDC/USD"));
        vm.mockCall(CHAINLINK_USDT_USD_FEED, abi.encodeCall(IOracle.description, ()), abi.encode("Chainlink USDT/USD"));
        vm.mockCall(wethVault, abi.encodeCall(IERC4626.asset, ()), abi.encode(WETH));
        vm.mockCall(wbtcVault, abi.encodeCall(IERC4626.asset, ()), abi.encode(WBTC));
        vm.mockCall(usdcVault, abi.encodeCall(IERC4626.asset, ()), abi.encode(USDC));
        vm.mockCall(usdtVault, abi.encodeCall(IERC4626.asset, ()), abi.encode(USDT));

        ChainlinkOracle ethUsdOracle = new ChainlinkOracle(WETH, USD, CHAINLINK_ETH_USD_FEED, 24 hours);
        ChainlinkOracle wbtcUsdOracle = new ChainlinkOracle(WBTC, USD, CHAINLINK_BTC_USD_FEED, 24 hours);
        ChainlinkOracle usdcUsdOracle = new ChainlinkOracle(USDC, USD, CHAINLINK_USDC_USD_FEED, 24 hours);
        ChainlinkOracle usdtUsdOracle = new ChainlinkOracle(USDT, USD, CHAINLINK_USDT_USD_FEED, 24 hours);

        EulerRouter router = new EulerRouter(address(1), address(this));
        EulerRouter fallbackRouter = new EulerRouter(address(1), address(this));
        router.govSetResolvedVault(wethVault, true);
        router.govSetResolvedVault(wbtcVault, true);
        router.govSetConfig(WETH, USD, address(ethUsdOracle));
        router.govSetConfig(WBTC, USD, address(wbtcUsdOracle));
        router.govSetFallbackOracle(address(fallbackRouter));

        fallbackRouter.govSetResolvedVault(usdcVault, true);
        fallbackRouter.govSetResolvedVault(usdtVault, true);
        fallbackRouter.govSetConfig(USDC, USD, address(usdcUsdOracle));
        fallbackRouter.govSetConfig(USDT, USD, address(usdtUsdOracle));

        address[] memory bases = new address[](4);
        bases[0] = WETH;
        bases[1] = WBTC;
        bases[2] = USDC;
        bases[3] = USDT;

        address[] memory quotes = new address[](4);
        quotes[0] = USD;
        quotes[1] = USD;
        quotes[2] = USD;
        quotes[3] = USD;

        OracleDetailedInfo memory data = lens.getOracleInfo(address(router), bases, quotes);
        assertEq(data.name, "EulerRouter");

        EulerRouterInfo memory routerInfo = abi.decode(data.oracleInfo, (EulerRouterInfo));

        assertEq(routerInfo.governor, address(this));
        assertEq(routerInfo.fallbackOracle, address(fallbackRouter));

        assertEq(routerInfo.resolvedOracles[0], address(ethUsdOracle));
        ChainlinkOracleInfo memory resolvedOracles0Info =
            abi.decode(routerInfo.resolvedOraclesInfo[0].oracleInfo, (ChainlinkOracleInfo));
        assertEq(resolvedOracles0Info.base, WETH);
        assertEq(resolvedOracles0Info.quote, USD);
        assertEq(resolvedOracles0Info.feed, CHAINLINK_ETH_USD_FEED);
        assertEq(resolvedOracles0Info.feedDescription, "Chainlink ETH/USD");

        assertEq(routerInfo.resolvedOracles[1], address(wbtcUsdOracle));
        ChainlinkOracleInfo memory resolvedOracles1Info =
            abi.decode(routerInfo.resolvedOraclesInfo[1].oracleInfo, (ChainlinkOracleInfo));
        assertEq(resolvedOracles1Info.base, WBTC);
        assertEq(resolvedOracles1Info.quote, USD);
        assertEq(resolvedOracles1Info.feed, CHAINLINK_BTC_USD_FEED);
        assertEq(resolvedOracles1Info.feedDescription, "Chainlink BTC/USD");

        assertEq(routerInfo.resolvedOracles[2], address(fallbackRouter));
        assertEq(routerInfo.resolvedOracles[3], address(fallbackRouter));

        OracleDetailedInfo memory fallbackData = routerInfo.fallbackOracleInfo;
        assertEq(fallbackData.name, "EulerRouter");

        EulerRouterInfo memory fallbackRouterInfo = abi.decode(fallbackData.oracleInfo, (EulerRouterInfo));

        assertEq(fallbackRouterInfo.governor, address(this));
        assertEq(fallbackRouterInfo.fallbackOracle, address(0));
        assertEq(fallbackRouterInfo.resolvedOracles[0], address(0));
        assertEq(fallbackRouterInfo.resolvedOracles[1], address(0));

        assertEq(fallbackRouterInfo.resolvedOracles[2], address(usdcUsdOracle));
        ChainlinkOracleInfo memory fallbackRouterResolvedOracles2Info =
            abi.decode(fallbackRouterInfo.resolvedOraclesInfo[2].oracleInfo, (ChainlinkOracleInfo));
        assertEq(fallbackRouterResolvedOracles2Info.base, USDC);
        assertEq(fallbackRouterResolvedOracles2Info.quote, USD);
        assertEq(fallbackRouterResolvedOracles2Info.feed, CHAINLINK_USDC_USD_FEED);
        assertEq(fallbackRouterResolvedOracles2Info.feedDescription, "Chainlink USDC/USD");

        assertEq(fallbackRouterInfo.resolvedOracles[3], address(usdtUsdOracle));
        ChainlinkOracleInfo memory fallbackRouterResolvedOracles3Info =
            abi.decode(fallbackRouterInfo.resolvedOraclesInfo[3].oracleInfo, (ChainlinkOracleInfo));
        assertEq(fallbackRouterResolvedOracles3Info.base, USDT);
        assertEq(fallbackRouterResolvedOracles3Info.quote, USD);
        assertEq(fallbackRouterResolvedOracles3Info.feed, CHAINLINK_USDT_USD_FEED);
        assertEq(fallbackRouterResolvedOracles3Info.feedDescription, "Chainlink USDT/USD");
    }

    function arrOf(address e0) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = e0;
        return arr;
    }
}
