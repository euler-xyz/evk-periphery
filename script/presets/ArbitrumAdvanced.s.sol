// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../utils/ScriptUtils.s.sol";
import {PeripheryFactories} from "../01_PeripheryFactories.s.sol";
import {
    ChainlinkAdapter, PythAdapter, CrossAdapter, RedstoneAdapter, UniswapAdapter
} from "../02_OracleAdapters.s.sol";
import {KinkIRM} from "../03_KinkIRM.s.sol";
import {Integrations} from "../04_Integrations.s.sol";
import {EVaultImplementation} from "../05_EVaultImplementation.s.sol";
import {EVaultFactory} from "../06_EVaultFactory.s.sol";
import {EVault} from "../07_EVault.s.sol";
import {Lenses} from "../08_Lenses.s.sol";
import {Perspectives} from "../09_Perspectives.s.sol";
import {Swap} from "../10_Swap.s.sol";
import {EscrowSingletonPerspective} from "../../src/Perspectives/deployed/EscrowSingletonPerspective.sol";
import {EulerDefaultClusterPerspective} from "../../src/Perspectives/deployed/EulerDefaultClusterPerspective.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {BalanceForwarder} from "evk/EVault/modules/BalanceForwarder.sol";
import {Borrowing} from "evk/EVault/modules/Borrowing.sol";
import {Governance} from "evk/EVault/modules/Governance.sol";
import {Initialize} from "evk/EVault/modules/Initialize.sol";
import {Liquidation} from "evk/EVault/modules/Liquidation.sol";
import {RiskManager} from "evk/EVault/modules/RiskManager.sol";
import {Token} from "evk/EVault/modules/Token.sol";
import {Vault} from "evk/EVault/modules/Vault.sol";
import {Dispatch} from "evk/EVault/Dispatch.sol";
import {IEVault, IERC20} from "evk/EVault/IEVault.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";

contract Advanced is ScriptUtils {
    address internal USD = address(840);
    address internal WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address internal LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
    address internal UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    struct DeploymentInfo {
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address chainlinkAdapterETHUSD;
        address chainlinkAdapterWSTETHETH;
        address chainlinkAdapterUSDCUSD;
        address chainlinkAdapterLINKUSD;
        address pythAdapterUSDTUSD;
        address redstoneAdapterUSDCUSD;
        address uniwapAdapterUNIWETH;
        address crossAdapterWSTETHUSD;
        address crossAdapterUNIUSD;
        address defaultIRM;
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address eVaultImplementation;
        address eVaultFactory;
        address oracleRouter;
        address[] eVaultCluster;
        address[] eVaultEscrow;
        address accountLens;
        address oracleLens;
        address vaultLens;
        address utilsLens;
        address escrowSingletonPerspective;
        address eulerDefaultClusterPerspective;
        address eulerFactoryPerspective;
        address swapper;
        address swapVerifier;
    }

    function run()
        public
        returns (
            address[] memory eVault,
            address evc,
            address balanceTracker,
            address escrowSingletonPerspective,
            address eulerDefaultClusterPerspective,
            address accountLens,
            address vaultLens,
            address swapper,
            address swapVerifier
        )
    {
        DeploymentInfo memory result;

        // deploy periphery factories
        {
            PeripheryFactories deployer = new PeripheryFactories();
            (
                result.oracleRouterFactory,
                result.oracleAdapterRegistry,
                result.externalVaultRegistry,
                result.kinkIRMFactory
            ) = deployer.deploy();
        }

        // deploy oracle adapters
        {
            ChainlinkAdapter deployer = new ChainlinkAdapter();
            result.chainlinkAdapterETHUSD = deployer.deploy(
                result.oracleAdapterRegistry, WETH, USD, 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 90000
            );
            result.chainlinkAdapterWSTETHETH = deployer.deploy(
                result.oracleAdapterRegistry, wstETH, WETH, 0xb523AE262D20A936BC152e6023996e46FDC2A95D, 90000
            );
            result.chainlinkAdapterUSDCUSD = deployer.deploy(
                result.oracleAdapterRegistry, USDC, USD, 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 90000
            );
            result.chainlinkAdapterLINKUSD = deployer.deploy(
                result.oracleAdapterRegistry, LINK, USD, 0x86E53CF1B870786351Da77A57575e79CB55812CB, 4000
            );
        }
        {
            PythAdapter deployer = new PythAdapter();
            result.pythAdapterUSDTUSD = deployer.deploy(
                result.oracleAdapterRegistry,
                0xE4D5c6aE46ADFAF04313081e8C0052A30b6Dd724,
                USDT,
                USD,
                0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b,
                900,
                100
            );
        }
        {
            UniswapAdapter deployer = new UniswapAdapter();
            result.uniwapAdapterUNIWETH =
                deployer.deploy(result.oracleAdapterRegistry, UNI, WETH, 3000, 1000, UNISWAP_V3_FACTORY);
        }
        {
            CrossAdapter deployer = new CrossAdapter();
            result.crossAdapterWSTETHUSD = deployer.deploy(
                result.oracleAdapterRegistry,
                wstETH,
                WETH,
                USD,
                result.chainlinkAdapterWSTETHETH,
                result.chainlinkAdapterETHUSD
            );
            result.crossAdapterUNIUSD = deployer.deploy(
                result.oracleAdapterRegistry, UNI, WETH, USD, result.uniwapAdapterUNIWETH, result.chainlinkAdapterETHUSD
            );
        }
        {
            RedstoneAdapter deployer = new RedstoneAdapter();
            result.redstoneAdapterUSDCUSD =
                deployer.deploy(result.oracleAdapterRegistry, USDC, USD, bytes32("USDC"), 8, 300);
        }
        // deploy the default IRM
        {
            KinkIRM deployer = new KinkIRM();
            result.defaultIRM = deployer.deploy(result.kinkIRMFactory, 0, 1406417851, 19050045013, 2147483648);
        }
        // deply integrations
        {
            Integrations deployer = new Integrations();
            (result.evc, result.protocolConfig, result.sequenceRegistry, result.balanceTracker, result.permit2) =
                deployer.deploy();
        }
        // deploy EVault implementation
        {
            EVaultImplementation deployer = new EVaultImplementation();
            Base.Integrations memory integrations = Base.Integrations({
                evc: result.evc,
                protocolConfig: result.protocolConfig,
                sequenceRegistry: result.sequenceRegistry,
                balanceTracker: result.balanceTracker,
                permit2: result.permit2
            });
            (, result.eVaultImplementation) = deployer.deploy(integrations);
        }
        // deploy EVault factory
        {
            EVaultFactory deployer = new EVaultFactory();
            result.eVaultFactory = deployer.deploy(result.eVaultImplementation);
        }
        // deploy EVaults
        {
            EVault deployer = new EVault();
            result.eVaultCluster = new address[](5);
            result.eVaultEscrow = new address[](4);

            (result.oracleRouter, result.eVaultCluster[0]) = deployer.deploy(
                result.oracleRouterFactory, true, result.eVaultFactory, false, WETH, result.chainlinkAdapterETHUSD, USD
            );
            (, result.eVaultCluster[1]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, wstETH, result.oracleRouter, USD
            );
            (, result.eVaultCluster[2]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, USDC, result.oracleRouter, USD
            );
            (, result.eVaultCluster[3]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, USDT, result.oracleRouter, USD
            );
            (, result.eVaultCluster[4]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, DAI, result.oracleRouter, USD
            );
            (, result.eVaultEscrow[0]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, wstETH, address(0), address(0)
            );
            (, result.eVaultEscrow[1]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, USDC, address(0), address(0)
            );
            (, result.eVaultEscrow[2]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, LINK, address(0), address(0)
            );
            (, result.eVaultEscrow[3]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, UNI, address(0), address(0)
            );
        }
        // configure the oracle router and the vaults
        {
            startBroadcast();
            for (uint256 i = 0; i < result.eVaultCluster.length; i++) {
                EulerRouter(result.oracleRouter).govSetResolvedVault(result.eVaultCluster[i], true);
            }
            for (uint256 i = 0; i < result.eVaultEscrow.length; i++) {
                EulerRouter(result.oracleRouter).govSetResolvedVault(result.eVaultEscrow[i], true);
            }

            EulerRouter(result.oracleRouter).govSetConfig(WETH, USD, result.chainlinkAdapterETHUSD);
            EulerRouter(result.oracleRouter).govSetConfig(wstETH, WETH, result.chainlinkAdapterWSTETHETH);
            EulerRouter(result.oracleRouter).govSetConfig(USDC, USD, result.chainlinkAdapterUSDCUSD);
            EulerRouter(result.oracleRouter).govSetConfig(LINK, USD, result.chainlinkAdapterLINKUSD);
            EulerRouter(result.oracleRouter).govSetConfig(USDT, USD, result.pythAdapterUSDTUSD);
            EulerRouter(result.oracleRouter).govSetConfig(DAI, USD, result.redstoneAdapterUSDCUSD);
            EulerRouter(result.oracleRouter).govSetConfig(UNI, WETH, result.uniwapAdapterUNIWETH);
            EulerRouter(result.oracleRouter).govSetConfig(wstETH, USD, result.crossAdapterWSTETHUSD);
            EulerRouter(result.oracleRouter).govSetConfig(UNI, USD, result.crossAdapterUNIUSD);
            EulerRouter(result.oracleRouter).transferGovernance(address(0));

            // configure the vaults
            // WETH cluster vault has wstETH cluster, USDC cluster and wstETH escrow as collateral
            IEVault(result.eVaultCluster[0]).setLTV(result.eVaultCluster[1], 8000, 8200, 0);
            IEVault(result.eVaultCluster[0]).setLTV(result.eVaultCluster[2], 7500, 8000, 0);
            IEVault(result.eVaultCluster[0]).setLTV(result.eVaultEscrow[0], 8200, 8400, 0);

            // wstWETH cluster vault has WETH cluster and USDC cluster as collateral
            IEVault(result.eVaultCluster[1]).setLTV(result.eVaultCluster[0], 8000, 8200, 0);
            IEVault(result.eVaultCluster[1]).setLTV(result.eVaultCluster[2], 7500, 8000, 0);

            // USDC cluster vault has WETH cluster wstETH cluster and wstETH escrow as collateral
            IEVault(result.eVaultCluster[2]).setLTV(result.eVaultCluster[0], 7500, 8000, 0);
            IEVault(result.eVaultCluster[2]).setLTV(result.eVaultCluster[1], 7500, 8000, 0);
            IEVault(result.eVaultCluster[2]).setLTV(result.eVaultEscrow[0], 7700, 7900, 0);

            // USDT cluster vault has USDC cluster DAI cluster, USDC escrow and LINK escrow as collateral
            IEVault(result.eVaultCluster[3]).setLTV(result.eVaultCluster[2], 8300, 8500, 0);
            IEVault(result.eVaultCluster[3]).setLTV(result.eVaultCluster[4], 8300, 8500, 0);
            IEVault(result.eVaultCluster[3]).setLTV(result.eVaultEscrow[1], 8500, 8700, 0);
            IEVault(result.eVaultCluster[3]).setLTV(result.eVaultEscrow[2], 5000, 5500, 0);

            // DAI cluster vault has USDC cluster USDT cluster, USDC escrow and UNI escrow as collateral
            IEVault(result.eVaultCluster[4]).setLTV(result.eVaultCluster[2], 8300, 8500, 0);
            IEVault(result.eVaultCluster[4]).setLTV(result.eVaultCluster[3], 8300, 8500, 0);
            IEVault(result.eVaultCluster[4]).setLTV(result.eVaultEscrow[1], 8500, 8700, 0);
            IEVault(result.eVaultCluster[4]).setLTV(result.eVaultEscrow[3], 5000, 5500, 0);

            address deployer = getDeployer();
            for (uint256 i = 0; i < result.eVaultCluster.length; i++) {
                IEVault(result.eVaultCluster[i]).setMaxLiquidationDiscount(0.2e4);
                IEVault(result.eVaultCluster[i]).setLiquidationCoolOffTime(1);
                IEVault(result.eVaultCluster[i]).setInterestRateModel(result.defaultIRM);
                IEVault(result.eVaultCluster[i]).setFeeReceiver(deployer);
            }

            for (uint256 i = 0; i < result.eVaultCluster.length; i++) {
                IEVault(result.eVaultCluster[i]).setGovernorAdmin(address(0));
            }
            for (uint256 i = 0; i < result.eVaultEscrow.length; i++) {
                IEVault(result.eVaultEscrow[i]).setGovernorAdmin(address(0));
            }

            stopBroadcast();
        }
        // deploy lenses
        {
            Lenses deployer = new Lenses();
            (result.accountLens, result.oracleLens, result.vaultLens, result.utilsLens) =
                deployer.deploy(result.oracleAdapterRegistry);
        }
        // deploy perspectives
        {
            Perspectives deployer = new Perspectives();
            (result.escrowSingletonPerspective, result.eulerDefaultClusterPerspective, result.eulerFactoryPerspective) =
            deployer.deploy(
                result.eVaultFactory,
                result.oracleRouterFactory,
                result.oracleAdapterRegistry,
                result.externalVaultRegistry,
                result.kinkIRMFactory
            );
        }
        // verify vaults
        {
            startBroadcast();
            for (uint256 i = 0; i < result.eVaultCluster.length; i++) {
                EulerDefaultClusterPerspective(result.eulerDefaultClusterPerspective).perspectiveVerify(
                    result.eVaultCluster[i], true
                );
            }
            for (uint256 i = 0; i < result.eVaultEscrow.length; i++) {
                EscrowSingletonPerspective(result.escrowSingletonPerspective).perspectiveVerify(
                    result.eVaultEscrow[i], true
                );
            }
            stopBroadcast();
        }
        // deploy swapper
        {
            Swap deployer = new Swap();
            (result.swapper, result.swapVerifier) = deployer.deploy(
                0x1111111254fb6c44bAC0beD2854e76F90643097d,
                0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
                0xE592427A0AEce92De3Edee1F18E0157C05861564,
                0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            );
        }

        eVault = new address[](result.eVaultCluster.length + result.eVaultEscrow.length);
        for (uint256 i = 0; i < result.eVaultCluster.length; i++) {
            eVault[i] = result.eVaultCluster[i];
        }
        for (uint256 i = 0; i < result.eVaultEscrow.length; i++) {
            eVault[i + result.eVaultCluster.length] = result.eVaultEscrow[i];
        }

        return (
            eVault,
            result.evc,
            result.balanceTracker,
            result.escrowSingletonPerspective,
            result.eulerDefaultClusterPerspective,
            result.accountLens,
            result.vaultLens,
            result.swapper,
            result.swapVerifier
        );
    }
}
