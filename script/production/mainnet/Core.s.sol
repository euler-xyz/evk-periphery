// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreInfoLib} from "../../utils/ScriptUtils.s.sol";
import {Integrations} from "../../01_Integrations.s.sol";
import {PeripheryFactories} from "../../02_PeripheryFactories.s.sol";
import {EVaultImplementation} from "../../05_EVaultImplementation.s.sol";
import {EVaultFactory} from "../../06_EVaultFactory.s.sol";
import {Lenses} from "../../08_Lenses.s.sol";
import {Perspectives} from "../../09_Perspectives.s.sol";
import {Swap} from "../../10_Swap.s.sol";
import {FeeFlow} from "../../11_FeeFlow.s.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract Core is ScriptUtils, CoreInfoLib {
    address internal constant EUL = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b;

    address internal constant ONE_INCH_AGGREGATOR_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAP_ROUTER_V3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant UNISWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    uint256 internal constant FEE_FLOW_INIT_PRICE = 1e18;
    address internal constant FEE_FLOW_PAYMENT_TOKEN = EUL;
    address internal constant FEE_FLOW_PAYMENT_RECEIVER = 0xcAD001c30E96765aC90307669d578219D4fb1DCe; // Euler DAO multi-sig
    uint256 internal constant FEE_FLOW_EPOCH_PERIOD = 14 days;
    uint256 internal constant FEE_FLOW_PRICE_MULTIPLIER = 2e18;
    uint256 internal constant FEE_FLOW_MIN_INIT_PRICE = 1e6;

    function run() public returns (CoreInfo memory coreInfo) {
        // deply integrations
        {
            Integrations deployer = new Integrations();
            (
                coreInfo.evc,
                coreInfo.protocolConfig,
                coreInfo.sequenceRegistry,
                coreInfo.balanceTracker,
                coreInfo.permit2
            ) = deployer.deploy();
        }
        // deploy periphery factories
        {
            PeripheryFactories deployer = new PeripheryFactories();
            (
                coreInfo.oracleRouterFactory,
                coreInfo.oracleAdapterRegistry,
                coreInfo.externalVaultRegistry,
                coreInfo.kinkIRMFactory,
                coreInfo.irmRegistry
            ) = deployer.deploy(coreInfo.evc);
        }
        // deploy EVault implementation
        {
            EVaultImplementation deployer = new EVaultImplementation();
            Base.Integrations memory integrations = Base.Integrations({
                evc: coreInfo.evc,
                protocolConfig: coreInfo.protocolConfig,
                sequenceRegistry: coreInfo.sequenceRegistry,
                balanceTracker: coreInfo.balanceTracker,
                permit2: coreInfo.permit2
            });
            (, coreInfo.eVaultImplementation) = deployer.deploy(integrations);
        }
        // deploy EVault factory
        {
            EVaultFactory deployer = new EVaultFactory();
            coreInfo.eVaultFactory = deployer.deploy(coreInfo.eVaultImplementation);
        }
        // deploy lenses
        {
            Lenses deployer = new Lenses();
            (coreInfo.accountLens, coreInfo.oracleLens, coreInfo.vaultLens, coreInfo.utilsLens) =
                deployer.deploy(coreInfo.oracleAdapterRegistry);
        }
        // deploy perspectives
        {
            Perspectives deployer = new Perspectives();
            (
                coreInfo.governableWhitelistPerspective,
                coreInfo.escrowPerspective,
                coreInfo.eulerBasePerspective,
                coreInfo.eulerFactoryPerspective
            ) = deployer.deploy(
                coreInfo.eVaultFactory,
                coreInfo.oracleRouterFactory,
                coreInfo.oracleAdapterRegistry,
                coreInfo.externalVaultRegistry,
                coreInfo.kinkIRMFactory,
                coreInfo.irmRegistry
            );
        }
        // deploy swapper
        {
            Swap deployer = new Swap();
            (coreInfo.swapper, coreInfo.swapVerifier) =
                deployer.deploy(ONE_INCH_AGGREGATOR_V6, UNISWAP_ROUTER_V2, UNISWAP_ROUTER_V3, UNISWAP_ROUTER_02);
        }
        // deploy fee flow
        {
            FeeFlow deployer = new FeeFlow();
            coreInfo.feeFlowController = deployer.deploy(
                coreInfo.evc,
                FEE_FLOW_INIT_PRICE,
                FEE_FLOW_PAYMENT_TOKEN,
                FEE_FLOW_PAYMENT_RECEIVER == address(0) ? getDeployer() : FEE_FLOW_PAYMENT_RECEIVER,
                FEE_FLOW_EPOCH_PERIOD,
                FEE_FLOW_PRICE_MULTIPLIER,
                FEE_FLOW_MIN_INIT_PRICE
            );
        }
        // additional configuration
        {
            startBroadcast();
            ProtocolConfig(coreInfo.protocolConfig).setFeeReceiver(coreInfo.feeFlowController);
            stopBroadcast();
        }

        // save results
        vm.writeJson(serializeCoreInfo(coreInfo), string.concat(vm.projectRoot(), "/script/CoreInfo.json"));

        return coreInfo;
    }
}
