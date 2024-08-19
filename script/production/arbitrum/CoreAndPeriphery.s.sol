// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreAddressesLib, PeripheryAddressesLib, ExtraAddressesLib} from "../../utils/ScriptUtils.s.sol";
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

contract CoreAndPeriphery is ScriptUtils, CoreAddressesLib, PeripheryAddressesLib, ExtraAddressesLib {
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address internal constant ONE_INCH_AGGREGATOR_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAP_ROUTER_V3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant UNISWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    uint256 internal constant FEE_FLOW_INIT_PRICE = 1e6;
    address internal constant FEE_FLOW_PAYMENT_TOKEN = WETH; // TODO
    address internal constant FEE_FLOW_PAYMENT_RECEIVER = 0x0000000000000000000000000000000000000000; // TODO
    uint256 internal constant FEE_FLOW_EPOCH_PERIOD = 14 days;
    uint256 internal constant FEE_FLOW_PRICE_MULTIPLIER = 2e18; // TODO
    uint256 internal constant FEE_FLOW_MIN_INIT_PRICE = 1e6; // TODO

    function run()
        public
        returns (
            CoreAddresses memory coreAddresses,
            PeripheryAddresses memory peripheryAddresses,
            ExtraAddresses memory extraAddresses
        )
    {
        // deply integrations
        {
            Integrations deployer = new Integrations();
            (
                coreAddresses.evc,
                coreAddresses.protocolConfig,
                coreAddresses.sequenceRegistry,
                coreAddresses.balanceTracker,
                coreAddresses.permit2
            ) = deployer.deploy();
        }
        // deploy periphery factories
        {
            PeripheryFactories deployer = new PeripheryFactories();
            (
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry
            ) = deployer.deploy(coreAddresses.evc);
        }
        // deploy EVault implementation
        {
            EVaultImplementation deployer = new EVaultImplementation();
            Base.Integrations memory integrations = Base.Integrations({
                evc: coreAddresses.evc,
                protocolConfig: coreAddresses.protocolConfig,
                sequenceRegistry: coreAddresses.sequenceRegistry,
                balanceTracker: coreAddresses.balanceTracker,
                permit2: coreAddresses.permit2
            });
            (, coreAddresses.eVaultImplementation) = deployer.deploy(integrations);
        }
        // deploy EVault factory
        {
            EVaultFactory deployer = new EVaultFactory();
            coreAddresses.eVaultFactory = deployer.deploy(coreAddresses.eVaultImplementation);
        }
        // deploy swapper
        {
            Swap deployer = new Swap();
            (peripheryAddresses.swapper, peripheryAddresses.swapVerifier) =
                deployer.deploy(ONE_INCH_AGGREGATOR_V6, UNISWAP_ROUTER_V2, UNISWAP_ROUTER_V3, UNISWAP_ROUTER_02);
        }
        // deploy fee flow
        {
            FeeFlow deployer = new FeeFlow();
            peripheryAddresses.feeFlowController = deployer.deploy(
                coreAddresses.evc,
                FEE_FLOW_INIT_PRICE,
                FEE_FLOW_PAYMENT_TOKEN,
                FEE_FLOW_PAYMENT_RECEIVER == address(0) ? getDeployer() : FEE_FLOW_PAYMENT_RECEIVER,
                FEE_FLOW_EPOCH_PERIOD,
                FEE_FLOW_PRICE_MULTIPLIER,
                FEE_FLOW_MIN_INIT_PRICE
            );
        }
        // additional fee flow configuration
        {
            startBroadcast();
            ProtocolConfig(coreAddresses.protocolConfig).setFeeReceiver(peripheryAddresses.feeFlowController);
            stopBroadcast();
        }
        // deploy lenses
        {
            Lenses deployer = new Lenses();
            (extraAddresses.accountLens, extraAddresses.oracleLens, extraAddresses.vaultLens, extraAddresses.utilsLens)
            = deployer.deploy(peripheryAddresses.oracleAdapterRegistry);
        }
        // deploy perspectives
        {
            Perspectives deployer = new Perspectives();
            address[] memory perspectives = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry
            );

            extraAddresses.governedPerspective = perspectives[0];
            extraAddresses.escrowPerspective = perspectives[1];
            extraAddresses.euler0xPerspective = perspectives[2];
            extraAddresses.euler1xPerspective = perspectives[3];
            extraAddresses.eulerFactoryPerspective = perspectives[4];
        }

        // save results
        vm.writeJson(serializeCoreAddresses(coreAddresses), getInputConfigFilePath("CoreAddresses.json"));
        vm.writeJson(serializePeripheryAddresses(peripheryAddresses), getInputConfigFilePath("PeripheryAddresses.json"));
        vm.writeJson(serializeExtraAddresses(extraAddresses), getInputConfigFilePath("ExtraAddresses.json"));

        return (coreAddresses, peripheryAddresses, extraAddresses);
    }
}
