// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {Integrations} from "./01_Integrations.s.sol";
import {PeripheryFactories} from "./02_PeripheryFactories.s.sol";
import {EVaultImplementation} from "./05_EVaultImplementation.s.sol";
import {EVaultFactory} from "./06_EVaultFactory.s.sol";
import {Lenses} from "./08_Lenses.s.sol";
import {EVKPerspectives} from "./09_Perspectives.s.sol";
import {Swap} from "./10_Swap.s.sol";
import {FeeFlow} from "./11_FeeFlow.s.sol";
import {FactoryGovernorDeployer} from "./12_FactoryGovernor.s.sol";
import {TermsOfUseSignerDeployer} from "./13_TermsOfUseSigner.s.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract CoreAndPeriphery is ScriptUtils {
    struct Input {
        address permit2;
        address uniswapV2Router;
        address uniswapV3Router;
        uint256 feeFlowInitPrice;
        address feeFlowPaymentToken;
        address feeFlowPaymentReceiver;
        uint256 feeFlowEpochPeriod;
        uint256 feeFlowPriceMultiplier;
        uint256 feeFlowMinInitPrice;
    }

    function run() public returns (CoreAddresses memory, PeripheryAddresses memory, LensAddresses memory) {
        string memory json = getInputConfig("50_CoreAndPeriphery_input.json");
        Input memory input = Input({
            permit2: abi.decode(vm.parseJson(json, ".permit2"), (address)),
            uniswapV2Router: abi.decode(vm.parseJson(json, ".uniswapV2Router"), (address)),
            uniswapV3Router: abi.decode(vm.parseJson(json, ".uniswapV3Router"), (address)),
            feeFlowInitPrice: abi.decode(vm.parseJson(json, ".feeFlowInitPrice"), (uint256)),
            feeFlowPaymentToken: abi.decode(vm.parseJson(json, ".feeFlowPaymentToken"), (address)),
            feeFlowPaymentReceiver: abi.decode(vm.parseJson(json, ".feeFlowPaymentReceiver"), (address)),
            feeFlowEpochPeriod: abi.decode(vm.parseJson(json, ".feeFlowEpochPeriod"), (uint256)),
            feeFlowPriceMultiplier: abi.decode(vm.parseJson(json, ".feeFlowPriceMultiplier"), (uint256)),
            feeFlowMinInitPrice: abi.decode(vm.parseJson(json, ".feeFlowMinInitPrice"), (uint256))
        });

        // deply integrations
        {
            Integrations deployer = new Integrations();
            (
                coreAddresses.evc,
                coreAddresses.protocolConfig,
                coreAddresses.sequenceRegistry,
                coreAddresses.balanceTracker,
                coreAddresses.permit2
            ) = deployer.deploy(input.permit2);
        }
        // deploy periphery factories
        {
            PeripheryFactories deployer = new PeripheryFactories();
            (
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.indicativeOracleRouter,
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
        // deploy factory governor
        {
            FactoryGovernorDeployer deployer = new FactoryGovernorDeployer();
            coreAddresses.eVaultFactoryGovernor = deployer.deploy();
        }
        // deploy swapper
        {
            Swap deployer = new Swap();
            (peripheryAddresses.swapper, peripheryAddresses.swapVerifier) =
                deployer.deploy(input.uniswapV2Router, input.uniswapV3Router);
        }
        // deploy fee flow
        {
            FeeFlow deployer = new FeeFlow();
            peripheryAddresses.feeFlowController = deployer.deploy(
                coreAddresses.evc,
                input.feeFlowInitPrice,
                input.feeFlowPaymentToken,
                input.feeFlowPaymentReceiver,
                input.feeFlowEpochPeriod,
                input.feeFlowPriceMultiplier,
                input.feeFlowMinInitPrice
            );
        }
        // additional fee flow configuration
        {
            startBroadcast();
            ProtocolConfig(coreAddresses.protocolConfig).setFeeReceiver(peripheryAddresses.feeFlowController);
            stopBroadcast();
        }
        // deploy perspectives
        {
            EVKPerspectives deployer = new EVKPerspectives();
            address[] memory perspectives = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry
            );

            peripheryAddresses.evkFactoryPerspective = perspectives[0];
            peripheryAddresses.governedPerspective = perspectives[1];
            peripheryAddresses.escrowedCollateralPerspective = perspectives[2];
            peripheryAddresses.eulerUngoverned0xPerspective = perspectives[3];
            peripheryAddresses.eulerUngovernedNzxPerspective = perspectives[4];
        }
        // deploy terms of use signer
        {
            TermsOfUseSignerDeployer deployer = new TermsOfUseSignerDeployer();
            peripheryAddresses.termsOfUseSigner = deployer.deploy(coreAddresses.evc);
        }
        // deploy lenses
        {
            Lenses deployer = new Lenses();
            address[] memory lenses =
                deployer.deploy(peripheryAddresses.oracleAdapterRegistry, peripheryAddresses.kinkIRMFactory);

            lensAddresses.accountLens = lenses[0];
            lensAddresses.oracleLens = lenses[1];
            lensAddresses.irmLens = lenses[2];
            lensAddresses.utilsLens = lenses[3];
            lensAddresses.vaultLens = lenses[4];
            lensAddresses.eulerEarnVaultLens = lenses[5];
        }

        // save results
        vm.writeJson(serializeCoreAddresses(coreAddresses), getInputConfigFilePath("50_CoreAddresses_output.json"));
        vm.writeJson(
            serializePeripheryAddresses(peripheryAddresses), getInputConfigFilePath("50_PeripheryAddresses_output.json")
        );
        vm.writeJson(serializeLensAddresses(lensAddresses), getInputConfigFilePath("50_LensAddresses_output.json"));

        return (coreAddresses, peripheryAddresses, lensAddresses);
    }
}
