// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {CoreAddressesLib, PeripheryAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {OracleVerifier} from "../../utils/SanityCheckOracle.s.sol";

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {EVault} from "evk/EVault/EVault.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";
import {FeeFlowController} from "fee-flow/FeeFlowController.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {BasePerspective} from "../../../src/Perspectives/implementation/BasePerspective.sol";
import {EulerUngovernedPerspective} from "../../../src/Perspectives/deployed/EulerUngovernedPerspective.sol";
import {Swapper} from "../../../src/Swaps/Swapper.sol";
import {EulerRouterFactory} from "../../../src/EulerRouterFactory/EulerRouterFactory.sol";

contract SanityCheckInitialDeployment is Script, CoreAddressesLib, PeripheryAddressesLib {
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
    address internal constant GOVERNED_PERSPECTIVE_ADMIN = EULER_DEPLOYER;

    // PROTOCOL_CONFIG_FEE_RECEIVER: feeFlow
    address internal constant FEE_FLOW_PAYMENT_RECEIVER = DAO_MULTISIG;

    function run() public view {
        CoreAddresses memory coreAddresses = deserializeCoreAddresses(vm.readFile(vm.envString("CORE_ADDRESSES_PATH")));
        PeripheryAddresses memory peripheryAddresses =
            deserializePeripheryAddresses(vm.readFile(vm.envString("PERIPHERY_ADDRESSES_PATH")));

        verifyCoreAndPeriphery(coreAddresses, peripheryAddresses);
        verifyVaults(coreAddresses, peripheryAddresses);
    }

    function verifyCoreAndPeriphery(CoreAddresses memory coreAddresses, PeripheryAddresses memory peripheryAddresses)
        internal
        view
    {
        // Nothing to check in: evc, sequenceRegistry, accountLens, utilsLens, kinkIRMFactory, swapVerifier

        // eVaultFactory
        // - upgradeAdmin
        // - implementation

        require(
            GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin() == EVAULT_FACTORY_ADMIN, "eVaultFactory admin"
        );
        require(
            GenericFactory(coreAddresses.eVaultFactory).implementation() == coreAddresses.eVaultImplementation,
            "eVaultFactory implementation"
        );

        // eVaultImplementation
        // - immutables: evc, protocolConfig, sequenceRegistry, balanceTracker, permit2

        assert(callWithTrailing(coreAddresses.eVaultImplementation, EVCUtil.EVC.selector) == coreAddresses.evc);
        assert(
            callWithTrailing(coreAddresses.eVaultImplementation, EVault.balanceTrackerAddress.selector)
                == coreAddresses.balanceTracker
        );
        assert(
            callWithTrailing(coreAddresses.eVaultImplementation, EVault.protocolConfigAddress.selector)
                == coreAddresses.protocolConfig
        );
        assert(
            callWithTrailing(coreAddresses.eVaultImplementation, EVault.permit2Address.selector)
                == coreAddresses.permit2
        );
        // unfortunately no accessor for sequenceRegistry, verified manually

        // balanceTracker
        // - immutables: evc, epochDuration

        assert(EVCUtil(coreAddresses.balanceTracker).EVC() == coreAddresses.evc);
        assert(TrackingRewardStreams(coreAddresses.balanceTracker).EPOCH_DURATION() == 14 days);

        // feeFlowControler
        // - immutables: peymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice

        assert(address(FeeFlowController(peripheryAddresses.feeFlowController).paymentToken()) == EUL);
        assert(FeeFlowController(peripheryAddresses.feeFlowController).paymentReceiver() == FEE_FLOW_PAYMENT_RECEIVER);
        assert(FeeFlowController(peripheryAddresses.feeFlowController).epochPeriod() == 14 days);
        assert(FeeFlowController(peripheryAddresses.feeFlowController).priceMultiplier() == 2e18);
        assert(FeeFlowController(peripheryAddresses.feeFlowController).minInitPrice() == 1e6);

        // protocolConfig
        // - admin
        // - global config: feeReceiver, protocolFeeShare

        assert(ProtocolConfig(coreAddresses.protocolConfig).admin() == PROTOCOL_CONFIG_ADMIN);
        (address feeReceiver, uint16 protocolFeeShare) =
            ProtocolConfig(coreAddresses.protocolConfig).protocolFeeConfig(address(1));
        assert(feeReceiver == peripheryAddresses.feeFlowController);
        assert(protocolFeeShare == 0.5e4);

        // oracleRouterFactory
        // - immutables: evc
        assert(EVCUtil(peripheryAddresses.oracleRouterFactory).EVC() == coreAddresses.evc);

        // oracleAdapterRegistry
        // - evc
        // - owner
        assert(EVCUtil(peripheryAddresses.oracleAdapterRegistry).EVC() == coreAddresses.evc);
        assert(Ownable(peripheryAddresses.oracleAdapterRegistry).owner() == ORACLE_ADAPTER_REGISTRY_ADMIN);

        // externalVaultRegistry
        // - evc
        // - owner
        assert(EVCUtil(peripheryAddresses.externalVaultRegistry).EVC() == coreAddresses.evc);
        assert(Ownable(peripheryAddresses.externalVaultRegistry).owner() == EXTERNAL_VAULT_REGISTRY_ADMIN);

        // irmRegistry
        // - evc
        // - owner
        assert(EVCUtil(peripheryAddresses.irmRegistry).EVC() == coreAddresses.evc);
        assert(Ownable(peripheryAddresses.irmRegistry).owner() == IRM_REGISTRY_ADMIN);

        // evkFactoryPerspective
        // - immutable: vaultFactory
        assert(
            address(BasePerspective(peripheryAddresses.evkFactoryPerspective).vaultFactory())
                == coreAddresses.eVaultFactory
        );

        // governedPerspective
        // - evc
        // - owner
        assert(EVCUtil(peripheryAddresses.governedPerspective).EVC() == coreAddresses.evc);
        assert(Ownable(peripheryAddresses.governedPerspective).owner() == GOVERNED_PERSPECTIVE_ADMIN);

        // escrowedCollateralPerspective
        // - immutable: vaultFactory
        assert(
            address(BasePerspective(peripheryAddresses.escrowedCollateralPerspective).vaultFactory())
                == coreAddresses.eVaultFactory
        );

        // eulerUngoverned0xPerspective
        // - immutables: vaultFactory, routerFactory, adapterRegistry, externalVaultRegistry, irmRegistry,
        // irmFactory
        // - recognizedUnitOfAccounts
        // - recognizedCollateralPerspectives
        assert(
            address(BasePerspective(peripheryAddresses.eulerUngoverned0xPerspective).vaultFactory())
                == coreAddresses.eVaultFactory
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).routerFactory())
                == peripheryAddresses.oracleRouterFactory
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).adapterRegistry())
                == peripheryAddresses.oracleAdapterRegistry
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).externalVaultRegistry())
                == peripheryAddresses.externalVaultRegistry
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).irmRegistry())
                == peripheryAddresses.irmRegistry
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).irmFactory())
                == peripheryAddresses.kinkIRMFactory
        );

        assert(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).isRecognizedUnitOfAccount(USD));
        assert(EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective).isRecognizedUnitOfAccount(WETH));

        address[] memory recognized = EulerUngovernedPerspective(peripheryAddresses.eulerUngoverned0xPerspective)
            .recognizedCollateralPerspectives();
        assert(recognized[0] == peripheryAddresses.escrowedCollateralPerspective);
        assert(recognized[1] == address(0));
        assert(recognized.length == 2);

        // eulerUngovernedNzxPerspective
        // - immutables: vaultFactory, routerFactory, adapterRegistry, externalVaultRegistry, irmRegistry,
        // irmFactory
        // - recognizedUnitOfAccounts
        // - recognizedCollateralPerspectives
        assert(
            address(BasePerspective(peripheryAddresses.eulerUngovernedNzxPerspective).vaultFactory())
                == coreAddresses.eVaultFactory
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).routerFactory())
                == peripheryAddresses.oracleRouterFactory
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).adapterRegistry())
                == peripheryAddresses.oracleAdapterRegistry
        );
        assert(
            address(
                EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).externalVaultRegistry()
            ) == peripheryAddresses.externalVaultRegistry
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).irmRegistry())
                == peripheryAddresses.irmRegistry
        );
        assert(
            address(EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).irmFactory())
                == peripheryAddresses.kinkIRMFactory
        );

        assert(EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).isRecognizedUnitOfAccount(USD));
        assert(EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective).isRecognizedUnitOfAccount(WETH));

        recognized = EulerUngovernedPerspective(peripheryAddresses.eulerUngovernedNzxPerspective)
            .recognizedCollateralPerspectives();
        assert(recognized[0] == peripheryAddresses.governedPerspective);
        assert(recognized[1] == peripheryAddresses.escrowedCollateralPerspective);
        assert(recognized[2] == address(0));
        assert(recognized.length == 3);

        // swapper
        // - immutables: oneInchAggregator, uniswapRouterV2, uniswapRouterV3, uniswapRouter02

        assert(Swapper(peripheryAddresses.swapper).oneInchAggregator() == ONE_INCH_ROUTER_V6);
        assert(Swapper(peripheryAddresses.swapper).uniswapRouterV2() == UNI_ROUTER_V2);
        assert(Swapper(peripheryAddresses.swapper).uniswapRouterV3() == UNI_ROUTER_V3);
        assert(Swapper(peripheryAddresses.swapper).uniswapRouter02() == UNI_ROUTER_02);
    }

    function verifyVaults(CoreAddresses memory coreAddresses, PeripheryAddresses memory peripheryAddresses)
        internal
        view
    {
        assert(GenericFactory(coreAddresses.eVaultFactory).getProxyListLength() >= 8);
        address[] memory vaults = GenericFactory(coreAddresses.eVaultFactory).getProxyListSlice(0, 8);

        address oracle = EVault(vaults[1]).oracle();

        for (uint256 i = 0; i < vaults.length; i++) {
            if (BasePerspective(peripheryAddresses.escrowedCollateralPerspective).isVerified(vaults[i])) {
                // escrow vaults
                assert(EVault(vaults[i]).governorAdmin() == address(0));
                (address hookTarget, uint32 hookedOps) = EVault(vaults[i]).hookConfig();
                assert(hookTarget == address(0));
                assert(hookedOps == 0);
            } else if (BasePerspective(peripheryAddresses.governedPerspective).isVerified(vaults[i])) {
                // managed vaults
                assert(BasePerspective(peripheryAddresses.governedPerspective).isVerified(vaults[i]));
                assert(EVault(vaults[i]).governorAdmin() == DAO_MULTISIG);

                // oracle
                assert(oracle == EVault(vaults[i]).oracle());
                assert(EulerRouterFactory(peripheryAddresses.oracleRouterFactory).isValidDeployment(oracle));
                assert(EulerRouter(oracle).governor() == DAO_MULTISIG);
                assert(EVault(vaults[i]).unitOfAccount() == USD);

                // common config
                assert(EVault(vaults[i]).maxLiquidationDiscount() == 0.15e4);
                assert(EVault(vaults[i]).liquidationCoolOffTime() == 1);
                assert(EVault(vaults[i]).interestFee() == 0.1e4);
                (address hookTarget, uint32 hookedOps) = EVault(vaults[i]).hookConfig();
                assert(hookTarget == address(0));
                assert(hookedOps == 0);
            } else {
                revert("vault not found in perspectives");
            }

            OracleVerifier.verifyOracleConfig(vaults[i]);
        }

        // oracle config for escrow
        address vault = vaults[0];
        assert(BasePerspective(peripheryAddresses.escrowedCollateralPerspective).isVerified(vault));
        assert(EVault(vault).asset() == WETH);
        (,,, address adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == WETHUSD);

        vault = vaults[2];
        assert(BasePerspective(peripheryAddresses.escrowedCollateralPerspective).isVerified(vault));
        assert(EVault(vault).asset() == wstETH);
        (,,, adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == wstETHUSD);

        vault = vaults[4];
        assert(BasePerspective(peripheryAddresses.escrowedCollateralPerspective).isVerified(vault));
        assert(EVault(vault).asset() == USDC);
        (,,, adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == USDCUSD);

        vault = vaults[6];
        assert(BasePerspective(peripheryAddresses.escrowedCollateralPerspective).isVerified(vault));
        assert(EVault(vault).asset() == USDT);
        (,,, adapter) = EulerRouter(oracle).resolveOracle(1e18, vault, USD);
        assert(adapter == USDTUSD);

        // governed vaults config
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
        // governed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0);
        assert(liquidationLTV == 0);
        // governed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0.85e4);
        assert(liquidationLTV == 0.87e4);
        // governed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0.72e4);
        assert(liquidationLTV == 0.74e4);
        // governed USDT
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
        // governed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0.85e4);
        assert(liquidationLTV == 0.87e4);
        // governed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0);
        assert(liquidationLTV == 0);
        // governed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0.72e4);
        assert(liquidationLTV == 0.74e4);
        // governed USDT
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
        // governed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0.79e4);
        assert(liquidationLTV == 0.81e4);
        // governed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0.76e4);
        assert(liquidationLTV == 0.78e4);
        // governed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0);
        assert(liquidationLTV == 0);
        // governed USDT
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
        // governed WETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[1]);
        assert(borrowLTV == 0.79e4);
        assert(liquidationLTV == 0.81e4);
        // governed wstETH
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[3]);
        assert(borrowLTV == 0.76e4);
        assert(liquidationLTV == 0.78e4);
        // governed USDC
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[5]);
        assert(borrowLTV == 0.83e4);
        assert(liquidationLTV == 0.85e4);
        // governed USDT
        (borrowLTV, liquidationLTV,,,) = EVault(vault).LTVFull(vaults[7]);
        assert(borrowLTV == 0);
        assert(liquidationLTV == 0);
    }

    function callWithTrailing(address target, bytes4 selector) internal view returns (address) {
        (bool success, bytes memory data) = target.staticcall(abi.encodePacked(selector, uint256(0), uint256(0)));
        assert(success);
        assert(data.length == 32);
        return abi.decode(data, (address));
    }
}
