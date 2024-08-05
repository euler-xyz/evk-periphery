// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../utils/ScriptUtils.s.sol";
import {Integrations} from "../01_Integrations.s.sol";
import {PeripheryFactories} from "../02_PeripheryFactories.s.sol";
import {EVaultImplementation} from "../05_EVaultImplementation.s.sol";
import {EVaultFactory} from "../06_EVaultFactory.s.sol";
import {Lenses} from "../08_Lenses.s.sol";
import {Perspectives} from "../09_Perspectives.s.sol";
import {Swap} from "../10_Swap.s.sol";
import {FeeFlow} from "../11_FeeFlow.s.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract Advanced is ScriptUtils {
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

    function run() public returns (CoreInfo memory result) {
        // deply integrations
        {
            Integrations deployer = new Integrations();
            (result.evc, result.protocolConfig, result.sequenceRegistry, result.balanceTracker, result.permit2) =
                deployer.deploy();
        }
        // deploy periphery factories
        {
            PeripheryFactories deployer = new PeripheryFactories();
            (
                result.oracleRouterFactory,
                result.oracleAdapterRegistry,
                result.externalVaultRegistry,
                result.kinkIRMFactory
            ) = deployer.deploy(result.evc);
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
        // deploy lenses
        {
            Lenses deployer = new Lenses();
            (result.accountLens, result.oracleLens, result.vaultLens, result.utilsLens) =
                deployer.deploy(result.oracleAdapterRegistry);
        }
        // deploy perspectives
        {
            Perspectives deployer = new Perspectives();
            (
                result.governableWhitelistPerspective,
                result.escrowPerspective,
                result.eulerBasePerspective,
                result.eulerFactoryPerspective
            ) = deployer.deploy(
                result.eVaultFactory,
                result.oracleRouterFactory,
                result.oracleAdapterRegistry,
                result.externalVaultRegistry,
                result.kinkIRMFactory
            );
        }
        // deploy swapper
        {
            Swap deployer = new Swap();
            (result.swapper, result.swapVerifier) = deployer.deploy(
                0x111111125421cA6dc452d289314280a0f8842A65,
                0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
                0xE592427A0AEce92De3Edee1F18E0157C05861564,
                0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            );
        }
        // deploy fee flow
        {
            FeeFlow deployer = new FeeFlow();
            // TODO figure out the parameters
            result.feeFlowController = deployer.deploy(
                result.evc, 1e6, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, getDeployer(), 14 days, 2e18, 1e6
            );
        }
        // TODO configure the core contracts
        {
            startBroadcast();
            ProtocolConfig(result.protocolConfig).setFeeReceiver(result.feeFlowController);

            // set fee receiver in the protocol config and transfer the ownership
            // transfer the ownership of the adapter and external vault registry
            // transfer eVault factory admin role
            // transfer governable whitelist perspective ownership

            stopBroadcast();
        }
    }
}
