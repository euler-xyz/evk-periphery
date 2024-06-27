// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../utils/ScriptUtils.s.sol";
import {PeripheryFactories} from "../01_PeripheryFactories.s.sol";
import {ChainlinkAdapter, LidoAdapter, PythAdapter, CrossAdapter} from "../02_OracleAdapters.s.sol";
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
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal EUL = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b;
    address internal SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;

    struct DeploymentInfo {
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address chainlinkAdapterWETHUSD;
        address chainlinkAdapterUSDCUSD;
        address chainlinkAdapterDAIUSD;
        address chainlinkAdapterSTETHUSD;
        address pythAdapterWBTCUSD;
        address lidoAdapterWSTETHSTETH;
        address crossAdapterWSTETHUSD;
        address defaultIRM;
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address eVaultImplementation;
        address eVaultFactory;
        address oracleRouter;
        address[] eVault;
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
            result.chainlinkAdapterWETHUSD = deployer.deploy(
                result.oracleAdapterRegistry, WETH, USD, 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 3700
            );
            result.chainlinkAdapterUSDCUSD = deployer.deploy(
                result.oracleAdapterRegistry, USDC, USD, 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6, 86500
            );
            result.chainlinkAdapterDAIUSD = deployer.deploy(
                result.oracleAdapterRegistry, DAI, USD, 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9, 3700
            );
            result.chainlinkAdapterSTETHUSD = deployer.deploy(
                result.oracleAdapterRegistry, stETH, USD, 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8, 3700
            );
        }
        {
            PythAdapter deployer = new PythAdapter();
            result.pythAdapterWBTCUSD = deployer.deploy(
                result.oracleAdapterRegistry,
                0x4305FB66699C3B2702D4d05CF36551390A4c69C6,
                WBTC,
                USD,
                0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33,
                300,
                200
            );
        }
        {
            LidoAdapter deployer = new LidoAdapter();
            result.lidoAdapterWSTETHSTETH = deployer.deploy(result.oracleAdapterRegistry);
        }
        {
            CrossAdapter deployer = new CrossAdapter();
            result.crossAdapterWSTETHUSD = deployer.deploy(
                result.oracleAdapterRegistry,
                wstETH,
                stETH,
                USD,
                result.lidoAdapterWSTETHSTETH,
                result.chainlinkAdapterSTETHUSD
            );
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
            result.eVault = new address[](6);

            (result.oracleRouter, result.eVault[0]) = deployer.deploy(
                result.oracleRouterFactory, true, result.eVaultFactory, false, WETH, result.chainlinkAdapterWETHUSD, USD
            );
            (, result.eVault[1]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, WBTC, result.oracleRouter, USD
            );
            (, result.eVault[2]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, USDC, result.oracleRouter, USD
            );
            (, result.eVault[3]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, DAI, result.oracleRouter, USD
            );
            (, result.eVault[4]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, wstETH, address(0), address(0)
            );
            (, result.eVault[5]) = deployer.deploy(
                result.oracleRouterFactory, false, result.eVaultFactory, false, WBTC, address(0), address(0)
            );
        }
        // configure the oracle router and the vaults
        {
            startBroadcast();
            for (uint256 i = 0; i < result.eVault.length; i++) {
                EulerRouter(result.oracleRouter).govSetResolvedVault(result.eVault[i], true);
            }

            EulerRouter(result.oracleRouter).govSetConfig(WETH, USD, result.chainlinkAdapterWETHUSD);
            EulerRouter(result.oracleRouter).govSetConfig(WBTC, USD, result.pythAdapterWBTCUSD);
            EulerRouter(result.oracleRouter).govSetConfig(USDC, USD, result.chainlinkAdapterUSDCUSD);
            EulerRouter(result.oracleRouter).govSetConfig(DAI, USD, result.chainlinkAdapterDAIUSD);
            EulerRouter(result.oracleRouter).govSetConfig(wstETH, USD, result.crossAdapterWSTETHUSD);
            EulerRouter(result.oracleRouter).transferGovernance(address(0));

            // configure the vaults
            // WETH vault has WBTC, USDC, DAI, wstETH escrow and WBTC escrow as collateral
            IEVault(result.eVault[0]).setLTV(result.eVault[1], 6000, 6500, 0);
            IEVault(result.eVault[0]).setLTV(result.eVault[2], 7500, 8000, 0);
            IEVault(result.eVault[0]).setLTV(result.eVault[3], 7500, 8000, 0);
            IEVault(result.eVault[0]).setLTV(result.eVault[4], 8500, 9000, 0);
            IEVault(result.eVault[0]).setLTV(result.eVault[5], 7000, 7500, 0);

            // WBTC vault has USDC, DAI and WBTC escrow as collateral
            IEVault(result.eVault[1]).setLTV(result.eVault[2], 8000, 8500, 0);
            IEVault(result.eVault[1]).setLTV(result.eVault[3], 8000, 8500, 0);
            IEVault(result.eVault[1]).setLTV(result.eVault[5], 8500, 9000, 0);

            // USDC vault has DAI as collateral
            IEVault(result.eVault[2]).setLTV(result.eVault[3], 8500, 9000, 0);

            // DAI vault has USDC as collateral
            IEVault(result.eVault[3]).setLTV(result.eVault[2], 8500, 9000, 0);

            address deployer = getDeployer();
            for (uint256 i = 0; i < result.eVault.length - 2; i++) {
                IEVault(result.eVault[i]).setMaxLiquidationDiscount(0.2e4);
                IEVault(result.eVault[i]).setLiquidationCoolOffTime(1);
                IEVault(result.eVault[i]).setInterestRateModel(result.defaultIRM);
                IEVault(result.eVault[i]).setFeeReceiver(deployer);
            }

            for (uint256 i = 0; i < result.eVault.length; i++) {
                IEVault(result.eVault[i]).setGovernorAdmin(address(0));
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
            EulerDefaultClusterPerspective(result.eulerDefaultClusterPerspective).perspectiveVerify(
                result.eVault[0], true
            );
            EulerDefaultClusterPerspective(result.eulerDefaultClusterPerspective).perspectiveVerify(
                result.eVault[1], true
            );
            EulerDefaultClusterPerspective(result.eulerDefaultClusterPerspective).perspectiveVerify(
                result.eVault[2], true
            );
            EulerDefaultClusterPerspective(result.eulerDefaultClusterPerspective).perspectiveVerify(
                result.eVault[3], true
            );
            EscrowSingletonPerspective(result.escrowSingletonPerspective).perspectiveVerify(result.eVault[4], true);
            EscrowSingletonPerspective(result.escrowSingletonPerspective).perspectiveVerify(result.eVault[5], true);
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
        // set up reward streams
        {
            startBroadcast();
            IERC20(EUL).approve(result.balanceTracker, type(uint256).max);
            IERC20(SHIB).approve(result.balanceTracker, type(uint256).max);

            uint128[] memory amounts = new uint128[](10);
            for (uint256 i = 0; i < amounts.length; i++) {
                amounts[i] = 1000e18;
            }
            TrackingRewardStreams(result.balanceTracker).registerReward(result.eVault[0], EUL, 0, amounts);
            TrackingRewardStreams(result.balanceTracker).registerReward(result.eVault[1], EUL, 0, amounts);
            for (uint256 i = 0; i < amounts.length; i++) {
                amounts[i] = 100000e18;
            }
            TrackingRewardStreams(result.balanceTracker).registerReward(result.eVault[0], SHIB, 0, amounts);
            stopBroadcast();
        }

        return (
            result.eVault,
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
