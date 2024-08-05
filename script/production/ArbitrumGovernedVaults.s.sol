// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../utils/ScriptUtils.s.sol";
import {KinkIRM} from "../04_KinkIRM.s.sol";
import {EVault} from "../07_EVault.s.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {EulerRouterFactory} from "../../src/OracleFactory/EulerRouterFactory.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract ArbitrumGovernedVaults is ScriptUtils {
    struct CoreInfo {
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address eVaultImplementation;
        address eVaultFactory;
        address accountLens;
        address oracleLens;
        address vaultLens;
        address utilsLens;
        address governableWhitelistPerspective;
        address escrowPerspective;
        address eulerBasePerspective;
        address eulerFactoryPerspective;
        address swapper;
        address swapVerifier;
        address feeFlowController;
    }

    address internal constant USD = address(840);
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address internal constant WETHUSD = 0xb70977986f38c74aB22D8ffaa0B7E13A7d574dD2;
    address internal constant wstETHUSD = 0x92a31a99ae3d754c6880fCc9eaEe502f5205624E;
    address internal constant WBTCUSD = 0x30Dcb2c78a01B9AD67c8cB8853D09EAEF1842594;
    address internal constant USDCUSD = 0x862b1042f653AE74880D0d3EBf0DDEe90aB8601D;
    address internal constant USDTUSD = 0x53aC2d35D724fc32BdabF1b92Be5B326b76c1205;

    mapping(address => address) internal escrowVaults;
    mapping(address => address) internal riskOnVaults;
    mapping(address => address) internal riskOffVaults;

    uint16[][] internal riskOnEscrowLTVs;
    uint16[][] internal riskOnRiskOnLTVs;
    uint16[][] internal riskOnRiskOffLTVs;
    uint16[][] internal riskOffEscrowLTVs;
    uint16[][] internal riskOffRiskOffLTVs;
    uint16[] internal riskOnMaxLiquidationDiscount;
    uint16[] internal riskOffMaxLiquidationDiscount;

    CoreInfo internal coreInfo;
    address oracleRouter;
    address defaultIRM;

    address[] internal assetsList;
    address[] internal oracleAdaptersList;
    address[] internal IRMList;

    constructor() {
        coreInfo = CoreInfo({
            evc: 0xE45Ee4046bD755330D555dFe4aDA7839a3eEb926,
            protocolConfig: 0xfD0a90035864CA77b6b1614CD461387976De0068,
            sequenceRegistry: 0xfD97C35d07229dEd53b0267d182EFeD3E8971233,
            balanceTracker: 0x3EF0C3295D90739E85c1CD17505Fb411D99c2432,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            oracleRouterFactory: 0x09867085527984d5b74d6C0796f4D600198b7b6E,
            oracleAdapterRegistry: 0xA2c071deC6F06686174094285FBA0a8EA4269fDD,
            externalVaultRegistry: 0xD4101919FC8AEdF2f037140E97442Ee5e34707e9,
            kinkIRMFactory: 0x29D739716F64E84E81552ffDDc36547A39282bCa,
            eVaultImplementation: 0x127c6d59fE30b67e81915EEA3CDcF7ae7D0f21Fb,
            eVaultFactory: 0x4e464eDf15188BfA63F836f86546128061e92625,
            accountLens: 0xFEFaaC0022e14c80d208C9870Aaa7d2a5Ea8F867,
            oracleLens: 0x94D82b819601f3d10dF3dEDf56BD5ee09fBD6004,
            vaultLens: 0xbd07ca6664cD4572A29Eb6eBd757C022Cf0F3AA1,
            utilsLens: 0x2B992Db66418D9b9210C50BB42d201b8a19cFC34,
            governableWhitelistPerspective: 0xCDa58e1eB35BF2A510c166D86A860340208C125D,
            escrowPerspective: 0x4743d2cEF0BD7b74281BC394bA1c6fC91A4C3f71,
            eulerBasePerspective: 0x02F29b394d0051E6Cf31AEb4CA0962C504CFb37A,
            eulerFactoryPerspective: 0x150579454E347a1eba2F6daFe7EA87284770D32b,
            swapper: 0xf11A61f808526B45ba797777Ab7B1DB5CC65DE0F,
            swapVerifier: 0x8aAA2CaEca30AB50d48EB0EA71b83c49A2f49791,
            feeFlowController: 0xFff00F5eda0FcdB4C80f1246B52857B148Fdb47A
        });

        riskOnEscrowLTVs = [
            [0, 0.96e4, 0.9e4, 0.9e4, 0.87e4],
            [0.96e4, 0, 0.87e4, 0.87e4, 0.84e4],
            [0.82e4, 0.82e4, 0, 0.82e4, 0.79e4],
            [0.83e4, 0.83e4, 0.83e4, 0, 0.91e4],
            [0.83e4, 0.83e4, 0.83e4, 0.94e4, 0]
        ];

        riskOnRiskOnLTVs = [
            [0, 0.93e4, 0.87e4, 0.87e4, 0.87e4],
            [0.93e4, 0, 0.84e4, 0.84e4, 0.84e4],
            [0.79e4, 0.79e4, 0, 0.79e4, 0.79e4],
            [0.8e4, 0.8e4, 0.8e4, 0, 0.91e4],
            [0.8e4, 0.8e4, 0.8e4, 0.91e4, 0]
        ];

        riskOnRiskOffLTVs = [
            [0, 0.95e4, 0.89e4, 0.89e4, 0.9e4],
            [0.95e4, 0, 0.86e4, 0.86e4, 0.87e4],
            [0.81e4, 0.81e4, 0, 0.81e4, 0.82e4],
            [0.82e4, 0.82e4, 0.82e4, 0, 0.94e4],
            [0.82e4, 0.82e4, 0.82e4, 0.93e4, 0]
        ];

        riskOffEscrowLTVs = [
            [0, 0.89e4, 0.83e4, 0.83e4, 0.83e4],
            [0.89e4, 0, 0.8e4, 0.8e4, 0.8e4],
            [0.75e4, 0.75e4, 0, 0.75e4, 0.75e4],
            [0.76e4, 0.76e4, 0.76e4, 0, 0.87e4],
            [0.76e4, 0.76e4, 0.76e4, 0.87e4, 0]
        ];

        riskOffRiskOffLTVs = [
            [0, 0.87e4, 0.81e4, 0.81e4, 0.81e4],
            [0.87e4, 0, 0.78e4, 0.78e4, 0.78e4],
            [0.73e4, 0.73e4, 0, 0.73e4, 0.73e4],
            [0.74e4, 0.74e4, 0.74e4, 0, 0.85e4],
            [0.74e4, 0.74e4, 0.74e4, 0.85e4, 0]
        ];

        assetsList = [WETH, wstETH, WBTC, USDC, USDT];
        oracleAdaptersList = [WETHUSD, wstETHUSD, WBTCUSD, USDCUSD, USDTUSD];
    }

    function run() public returns (address[] memory) {
        // deploy the oracle router
        startBroadcast();
        oracleRouter = EulerRouterFactory(coreInfo.oracleRouterFactory).deploy(getDeployer());
        stopBroadcast();

        // TODO
        // deploy the IRMs
        defaultIRM = (new KinkIRM()).deploy(coreInfo.kinkIRMFactory, 0, 1406417851, 19050045013, 2147483648);
        IRMList = [defaultIRM, defaultIRM, defaultIRM, defaultIRM, defaultIRM];

        // deploy the vaults
        EVault deployer = new EVault();
        for (uint256 i = 0; i < assetsList.length; ++i) {
            (, escrowVaults[assetsList[i]]) =
                deployer.deploy(address(0), false, coreInfo.eVaultFactory, true, assetsList[i], address(0), address(0));

            (, riskOnVaults[assetsList[i]]) = deployer.deploy(
                coreInfo.oracleRouterFactory, false, coreInfo.eVaultFactory, true, assetsList[i], oracleRouter, USD
            );

            (, riskOffVaults[assetsList[i]]) = deployer.deploy(
                coreInfo.oracleRouterFactory, false, coreInfo.eVaultFactory, true, assetsList[i], oracleRouter, USD
            );
        }

        // configure the oracle router
        startBroadcast();
        for (uint256 i = 0; i < assetsList.length; ++i) {
            EulerRouter(oracleRouter).govSetConfig(assetsList[i], USD, oracleAdaptersList[i]);
            EulerRouter(oracleRouter).govSetResolvedVault(escrowVaults[assetsList[i]], true);
            EulerRouter(oracleRouter).govSetResolvedVault(riskOnVaults[assetsList[i]], true);
            EulerRouter(oracleRouter).govSetResolvedVault(riskOffVaults[assetsList[i]], true);
        }

        // configure the LTVs
        setLTVs(riskOnVaults, escrowVaults, riskOnEscrowLTVs);
        setLTVs(riskOnVaults, riskOnVaults, riskOnRiskOnLTVs);
        setLTVs(riskOnVaults, riskOffVaults, riskOnRiskOffLTVs);
        setLTVs(riskOffVaults, escrowVaults, riskOffEscrowLTVs);
        setLTVs(riskOffVaults, riskOffVaults, riskOffRiskOffLTVs);

        for (uint256 i = 0; i < assetsList.length; ++i) {
            // allow lower interest fee by configuring the protocol config
            ProtocolConfig(coreInfo.protocolConfig).setVaultInterestFeeRange(
                riskOnVaults[assetsList[i]], true, 0.05e4, 1e4
            );
            ProtocolConfig(coreInfo.protocolConfig).setVaultInterestFeeRange(
                riskOffVaults[assetsList[i]], true, 0.05e4, 1e4
            );

            // configure the escrow vaults and verify it by the escrow perspective
            IEVault(escrowVaults[assetsList[i]]).setHookConfig(address(0), 0);
            IEVault(escrowVaults[assetsList[i]]).setGovernorAdmin(address(0));
            BasePerspective(coreInfo.escrowPerspective).perspectiveVerify(escrowVaults[assetsList[i]], true);

            // configure the riskOn vaults and add it to the whitelist perspective
            IEVault(riskOnVaults[assetsList[i]]).setMaxLiquidationDiscount(0.1e4);
            IEVault(riskOnVaults[assetsList[i]]).setLiquidationCoolOffTime(1);
            IEVault(riskOnVaults[assetsList[i]]).setInterestRateModel(IRMList[i]);
            IEVault(riskOnVaults[assetsList[i]]).setInterestFee(0.05e4);
            IEVault(riskOnVaults[assetsList[i]]).setHookConfig(address(0), 0);
            BasePerspective(coreInfo.governableWhitelistPerspective).perspectiveVerify(
                riskOnVaults[assetsList[i]], true
            );

            // configure the riskOff vaults and add it to the whitelist perspective
            IEVault(riskOffVaults[assetsList[i]]).setMaxLiquidationDiscount(0.1e4);
            IEVault(riskOffVaults[assetsList[i]]).setLiquidationCoolOffTime(1);
            IEVault(riskOffVaults[assetsList[i]]).setInterestRateModel(IRMList[i]);
            IEVault(riskOffVaults[assetsList[i]]).setInterestFee(0.05e4);
            IEVault(riskOffVaults[assetsList[i]]).setHookConfig(address(0), 0);
            BasePerspective(coreInfo.governableWhitelistPerspective).perspectiveVerify(
                riskOffVaults[assetsList[i]], true
            );
        }
        stopBroadcast();

        // prepare the results
        address[] memory result = new address[](3 * assetsList.length);
        for (uint256 i = 0; i < assetsList.length; ++i) {
            result[i] = escrowVaults[assetsList[i]];
            result[i + assetsList.length] = riskOnVaults[assetsList[i]];
            result[i + 2 * assetsList.length] = riskOffVaults[assetsList[i]];
        }
        return result;
    }

    function setLTVs(
        mapping(address => address) storage vaults,
        mapping(address => address) storage collaterals,
        uint16[][] storage ltvs
    ) internal {
        for (uint256 i = 0; i < assetsList.length; ++i) {
            for (uint256 j = 0; j < assetsList.length; ++j) {
                if (i == j) continue;

                IEVault(vaults[assetsList[j]]).setLTV(collaterals[assetsList[i]], ltvs[i][j] - 0.02e4, ltvs[i][j], 0);
            }
        }
    }
}
