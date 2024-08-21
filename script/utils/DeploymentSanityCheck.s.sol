// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {ScriptUtils, CoreInfoLib} from "./ScriptUtils.s.sol";

import {EVault} from "evk/EVault/EVault.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";
import {FeeFlowController} from "fee-flow/FeeFlowController.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {OracleLens} from "../../src/Lens/OracleLens.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {EulerBasePerspective} from "../../src/Perspectives/deployed/EulerBasePerspective.sol";
import {Swapper} from "../../src/Swaps/Swapper.sol";
import {EulerRouterFactory} from "../../src/EulerRouterFactory/EulerRouterFactory.sol";

interface IEVCUser {
    function EVC() external view returns (address);
}


contract DeploymentSanityCheck is ScriptUtils, CoreInfoLib {
    // assets
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant EUL = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b;

    // adapters
    address internal constant WETHUSD = 0x10674C8C1aE2072d4a75FE83f1E159425fd84E1D;
    address internal constant wstETHUSD = 0x02dd5B7ab536629d2235276aBCDf8eb3Af9528D7;
    address internal constant USDCUSD = 0x6213f24332D35519039f2afa7e3BffE105a37d3F;
    address internal constant USDTUSD = 0x587CABe0521f5065b561A6e68c25f338eD037FF9;

    address internal constant ONE_INCH_ROUTER_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant UNI_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNI_ROUTER_V3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant UNI_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address internal constant EULER_DEPLOYER = 0xEe009FAF00CF54C1B4387829aF7A8Dc5f0c8C8C5;
    address internal constant DAO_MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    // expected admins

    address internal constant EVAULT_FACTORY_ADMIN = DAO_MULTISIG;
    address internal constant PROTOCOL_CONFIG_ADMIN = DAO_MULTISIG;
    address internal constant ORACLE_ADAPTER_REGISTRY_ADMIN = EULER_DEPLOYER;
    address internal constant EXTERNAL_VAULT_REGISTRY_ADMIN = EULER_DEPLOYER;
    address internal constant IRM_REGISTRY_ADMIN = EULER_DEPLOYER;
    address internal constant GOVERNABLE_WHITELIST_PERSPECTIVE_ADMIN = EULER_DEPLOYER;
    // PROTOCOL_CONFIG_FEE_RECEIVER: feeFlow
    address internal constant FEE_FLOW_PAYMENT_RECEIVER = DAO_MULTISIG;

    function run() public view {
        CoreInfo memory coreInfo = deserializeCoreInfo(vm.readFile(vm.envString("COREINFO_PATH")));
        verifyCore(coreInfo);
        verifyVaults(coreInfo);

        // FIXME: oracle / adapters?
    }

    function verifyCore(CoreInfo memory coreInfo) internal view {
        // Nothing to check in: evc, sequenceRegistry, accountLens, utilsLens, kinkIRMFactory, swapVerifier

        // eVaultFactory
        // - upgradeAdmin
        // - implementation

        require(GenericFactory(coreInfo.eVaultFactory).upgradeAdmin() == EVAULT_FACTORY_ADMIN, "eVaultFactory admin");
        require(GenericFactory(coreInfo.eVaultFactory).implementation() == coreInfo.eVaultImplementation, "eVaultFactory implementation");

        // eVaultImplementation 
        // - immutables: evc, protocolConfig, sequenceRegistry, balanceTracker, permit2

        assert(callWithTrailing(coreInfo.eVaultImplementation, IEVCUser.EVC.selector) == coreInfo.evc);
        assert(callWithTrailing(coreInfo.eVaultImplementation, EVault.balanceTrackerAddress.selector) == coreInfo.balanceTracker);
        assert(callWithTrailing(coreInfo.eVaultImplementation, EVault.protocolConfigAddress.selector) == coreInfo.protocolConfig);
        assert(callWithTrailing(coreInfo.eVaultImplementation, EVault.permit2Address.selector) == coreInfo.permit2);
        // unfortunately no accessor for sequenceRegistry, verified manually

        // balanceTracker
        // - immutables: evc, epochDuration

        assert(IEVCUser(coreInfo.balanceTracker).EVC() == coreInfo.evc);
        assert(TrackingRewardStreams(coreInfo.balanceTracker).EPOCH_DURATION() == 14 days);

        // feeFlowControler
        // - immutables: peymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice

        assert(address(FeeFlowController(coreInfo.feeFlowController).paymentToken()) == EUL);
        assert(FeeFlowController(coreInfo.feeFlowController).paymentReceiver() == FEE_FLOW_PAYMENT_RECEIVER);
        assert(FeeFlowController(coreInfo.feeFlowController).epochPeriod() == 14 days);
        assert(FeeFlowController(coreInfo.feeFlowController).priceMultiplier() == 2e18);
        assert(FeeFlowController(coreInfo.feeFlowController).minInitPrice() == 1e6);

        // protocolConfig
        // - admin
        // - global config: feeReceiver, protocolFeeShare

        assert(ProtocolConfig(coreInfo.protocolConfig).admin() == PROTOCOL_CONFIG_ADMIN);
        (address feeReceiver, uint16 protocolFeeShare) = ProtocolConfig(coreInfo.protocolConfig).protocolFeeConfig(address(1));
        assert(feeReceiver == coreInfo.feeFlowController);
        assert(protocolFeeShare == 0.5e4);


        // oracleRouterFactory
        // - immutables: evc
        assert(IEVCUser(coreInfo.oracleRouterFactory).EVC() == coreInfo.evc);

        // oracleAdapterRegistry
        // - owner
        assert(Ownable(coreInfo.oracleAdapterRegistry).owner() == ORACLE_ADAPTER_REGISTRY_ADMIN);

        // externalVaultRegistry
        // - owner
        assert(Ownable(coreInfo.externalVaultRegistry).owner() == EXTERNAL_VAULT_REGISTRY_ADMIN);

        // irmRegistry
        // - owner
        assert(Ownable(coreInfo.irmRegistry).owner() == IRM_REGISTRY_ADMIN);

        // oracleLens
        // - immutable: adapterRegistry
        assert(address(OracleLens(coreInfo.oracleLens).adapterRegistry()) == coreInfo.oracleAdapterRegistry);

        // vaultLens
        // - immutable: oracleLens
        assert(address(VaultLens(coreInfo.vaultLens).oracleLens()) == coreInfo.oracleLens);

        // escrowPerspective
        // - immutable: vaultFactory
        // VERIFIED manually in creation TX https://etherscan.io/tx/0x1d3d9f2cb49c06ba52d7855b9dcc02c8f3a7f794e6eb1565d3a9b6bbb803a531

        // eulerFactoryPerspective
        // - immutable: vaultFactory
        // VERIFIED manually in creation TX https://etherscan.io/tx/0x9a27da6c4170cb47ac8d35cd7fbe0fb1a4cbad1d27219532b33317e1afcd5e0f

        // eulerBasePerspective
        // - immutables: vaultFactory, routerFactory, adapterRegistry, externalVaultRegistry, irmRegistry, irmFactory
        // - recognizedCollateralPerspectives
        // VERIFIED immutables manually in creation TX https://etherscan.io/tx/0xdf281d88a257624765ab569353a14d1caabb1f34c6a6a47545f2ae9913919ffe
        address recognized = EulerBasePerspective(coreInfo.eulerBasePerspective).recognizedCollateralPerspectives(0);
        assert(recognized == coreInfo.governableWhitelistPerspective);
        recognized = EulerBasePerspective(coreInfo.eulerBasePerspective).recognizedCollateralPerspectives(1);
        assert(recognized == coreInfo.escrowPerspective);
        recognized = EulerBasePerspective(coreInfo.eulerBasePerspective).recognizedCollateralPerspectives(2);
        assert(recognized == address(0));

        try EulerBasePerspective(coreInfo.eulerBasePerspective).recognizedCollateralPerspectives(3) {
            revert('array too long!');
        } catch {}

        // governableWhitelistPerspective
        // - owner

        assert(Ownable(coreInfo.governableWhitelistPerspective).owner() == GOVERNABLE_WHITELIST_PERSPECTIVE_ADMIN);

        // swapper
        // - immutables: oneInchAggregator, uniswapRouterV2, uniswapRouterV3, uniswapRouter02

        assert(Swapper(coreInfo.swapper).oneInchAggregator() == ONE_INCH_ROUTER_V6);
        assert(Swapper(coreInfo.swapper).uniswapRouterV2() == UNI_ROUTER_V2);
        assert(Swapper(coreInfo.swapper).uniswapRouterV3() == UNI_ROUTER_V3);
        assert(Swapper(coreInfo.swapper).uniswapRouter02() == UNI_ROUTER_02);
    }

    function verifyVaults(CoreInfo memory coreInfo) internal view {
        assert(GenericFactory(coreInfo.eVaultFactory).getProxyListLength() == 8);
        address[] memory vaults = GenericFactory(coreInfo.eVaultFactory).getProxyListSlice(0, 8);

        address oracle = EVault(vaults[1]).oracle();

        for (uint i = 0; i < vaults.length; i++) {
            if (BasePerspective(coreInfo.escrowPerspective).isVerified(vaults[i])) {
                // escrow vaults
                assert(EVault(vaults[i]).governorAdmin() == address(0));
            } else if (BasePerspective(coreInfo.governableWhitelistPerspective).isVerified(vaults[i])) {
                // managed vaults
                assert(BasePerspective(coreInfo.governableWhitelistPerspective).isVerified(vaults[i]));
                assert(EVault(vaults[i]).governorAdmin() == DAO_MULTISIG);

                // oracle

                assert(oracle == EVault(vaults[i]).oracle());
                assert(EulerRouterFactory(coreInfo.oracleRouterFactory).isValidDeployment(oracle));
                assert(EulerRouter(oracle).governor() == DAO_MULTISIG);
                assert(EVault(vaults[i]).unitOfAccount() == USD);

                // common config
                assert(EVault(vaults[i]).maxLiquidationDiscount() == 0.15e4);
                assert(EVault(vaults[i]).liquidationCoolOffTime() == 1);
                assert(EVault(vaults[i]).interestFee() == 0.1e4);

            } else {
                revert ('vault not found in perspectives');
            }
        }

        // oracle config for escrow
        address vault = vaults[0];
        assert(BasePerspective(coreInfo.escrowPerspective).isVerified(vault));
        assert(EVault(vault).asset() == WETH);
        (,,, address adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == WETHUSD);

        vault = vaults[2];
        assert(BasePerspective(coreInfo.escrowPerspective).isVerified(vault));
        assert(EVault(vault).asset() == wstETH);
        (,,, adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == wstETHUSD);

        vault = vaults[4];
        assert(BasePerspective(coreInfo.escrowPerspective).isVerified(vault));
        assert(EVault(vault).asset() == USDC);
        (,,, adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == USDCUSD);

        vault = vaults[6];
        assert(BasePerspective(coreInfo.escrowPerspective).isVerified(vault));
        assert(EVault(vault).asset() == USDT);
        (,,, adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == USDTUSD);

        // managed vaults config
        // WETH
        vault = vaults[1];
        assert(EVault(vault).asset() == WETH);
        (,,, adapter) = EulerRouter(EVault(vault).oracle()).resolveOracle(1e18, vault, USD);
        assert(adapter == WETHUSD);
        address irm = EVault(vault).interestRateModel();
        assert(IRMLinearKink(irm).baseRate() == 0);
        assert(IRMLinearKink(irm).slope1() == 218407859);
        assert(IRMLinearKink(irm).slope2() == 42500370385);
        assert(IRMLinearKink(irm).kink() == 3865470566);

        // escrow WETH
        (uint16 borrowLTV, uint16 liquidationLTV,,,) = EVault(vault).LTVFull(vaults[0]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 
        // escrow wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[2]);
        assert(borrowLTV == 0.87e4); 
        assert(liquidationLTV == 0.89e4); 
        // escrow USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[4]);
        assert(borrowLTV == 0.74e4); 
        assert(liquidationLTV == 0.76e4); 
        // escrow USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[6]);
        assert(borrowLTV == 0.74e4); 
        assert(liquidationLTV == 0.76e4); 
        // managed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 
        // managed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0.85e4); 
        assert(liquidationLTV == 0.87e4); 
        // managed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0.72e4); 
        assert(liquidationLTV == 0.74e4); 
        // managed USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[7]);
        assert(borrowLTV == 0.72e4); 
        assert(liquidationLTV == 0.74e4); 

        // wstETH
        vault = vaults[3];
        assert(EVault(vault).asset() == wstETH);
        (,,, adapter) = EulerRouter(EVault(vault).oracle()).resolveOracle(1e18, vault, USD);
        assert(adapter == wstETHUSD);
        irm = EVault(vault).interestRateModel();
        assert(IRMLinearKink(irm).baseRate() == 0);
        assert(IRMLinearKink(irm).slope1() == 760869530);
        assert(IRMLinearKink(irm).slope2() == 7611888145);
        assert(IRMLinearKink(irm).kink() == 1932735283);
        // escrow WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[0]);
        assert(borrowLTV == 0.87e4); 
        assert(liquidationLTV == 0.89e4); 
        // escrow wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[2]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 
        // escrow USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[4]);
        assert(borrowLTV == 0.74e4); 
        assert(liquidationLTV == 0.76e4); 
        // escrow USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[6]);
        assert(borrowLTV == 0.74e4); 
        assert(liquidationLTV == 0.76e4); 
        // managed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0.85e4); 
        assert(liquidationLTV == 0.87e4); 
        // managed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 
        // managed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0.72e4); 
        assert(liquidationLTV == 0.74e4); 
        // managed USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[7]);
        assert(borrowLTV == 0.72e4); 
        assert(liquidationLTV == 0.74e4); 

        // USDC
        vault = vaults[5];
        assert(EVault(vault).asset() == USDC);
        (,,, adapter) = EulerRouter(EVault(vault).oracle()).resolveOracle(1e18, vault, USD);
        assert(adapter == USDCUSD);
        irm = EVault(vault).interestRateModel();
        assert(IRMLinearKink(irm).baseRate() == 0);
        assert(IRMLinearKink(irm).slope1() == 505037995);
        assert(IRMLinearKink(irm).slope2() == 41211382066);
        assert(IRMLinearKink(irm).kink() == 3951369912);
        // escrow WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[0]);
        assert(borrowLTV == 0.81e4); 
        assert(liquidationLTV == 0.83e4); 
        // escrow wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[2]);
        assert(borrowLTV == 0.78e4); 
        assert(liquidationLTV == 0.8e4); 
        // escrow USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[4]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 
        // escrow USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[6]);
        assert(borrowLTV == 0.85e4); 
        assert(liquidationLTV == 0.87e4); 
        // managed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0.79e4); 
        assert(liquidationLTV == 0.81e4); 
        // managed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0.76e4); 
        assert(liquidationLTV == 0.78e4); 
        // managed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 
        // managed USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[7]);
        assert(borrowLTV == 0.83e4); 
        assert(liquidationLTV == 0.85e4); 

        // USDT
        vault = vaults[7];
        assert(EVault(vault).asset() == USDT);
        (,,, adapter) = EulerRouter(EVault(vault).oracle()).resolveOracle(1e18, vault, USD);
        assert(adapter == USDTUSD);
        irm = EVault(vault).interestRateModel();
        assert(IRMLinearKink(irm).baseRate() == 0);
        assert(IRMLinearKink(irm).slope1() == 505037995);
        assert(IRMLinearKink(irm).slope2() == 49166860226);
        assert(IRMLinearKink(irm).kink() == 3951369912);
        // escrow WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[0]);
        assert(borrowLTV == 0.81e4); 
        assert(liquidationLTV == 0.83e4); 
        // escrow wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[2]);
        assert(borrowLTV == 0.78e4); 
        assert(liquidationLTV == 0.8e4); 
        // escrow USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[4]);
        assert(borrowLTV == 0.85e4); 
        assert(liquidationLTV == 0.87e4); 
        // escrow USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[6]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0);
        // managed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0.79e4); 
        assert(liquidationLTV == 0.81e4); 
        // managed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0.76e4); 
        assert(liquidationLTV == 0.78e4); 
        // managed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0.83e4); 
        assert(liquidationLTV == 0.85e4); 
        // managed USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[7]);
        assert(borrowLTV == 0); 
        assert(liquidationLTV == 0); 


        // FIXME add IRM config
    }

    function callWithTrailing(address target, bytes4 selector) internal view returns (address) {
        (bool success, bytes memory data) = target.staticcall(abi.encodePacked(selector, uint256(0), uint256(0)));
        assert(success);
        assert(data.length == 32);
        return abi.decode(data, (address));
    }
}
