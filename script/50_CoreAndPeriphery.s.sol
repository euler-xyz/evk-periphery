// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "./utils/ScriptUtils.s.sol";
import {ERC20BurnableMintableDeployer, RewardTokenDeployer} from "./00_ERC20.s.sol";
import {Integrations} from "./01_Integrations.s.sol";
import {PeripheryFactories} from "./02_PeripheryFactories.s.sol";
import {EVaultImplementation} from "./05_EVaultImplementation.s.sol";
import {EVaultFactory} from "./06_EVaultFactory.s.sol";
import {Lenses} from "./08_Lenses.s.sol";
import {EVKPerspectives} from "./09_Perspectives.s.sol";
import {Swap} from "./10_Swap.s.sol";
import {FeeFlow} from "./11_FeeFlow.s.sol";
import {EVaultFactoryGovernorDeployer, GovernorAccessControlEmergencyDeployer} from "./12_Governor.s.sol";
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

    function run()
        public
        returns (
            CoreAddresses memory,
            PeripheryAddresses memory,
            LensAddresses memory,
            MultisigAddresses memory,
            NTTAddresses memory
        )
    {
        string memory json = getInputConfig("50_CoreAndPeriphery_input.json");
        Input memory input = Input({
            permit2: vm.parseJsonAddress(json, ".permit2"),
            uniswapV2Router: vm.parseJsonAddress(json, ".uniswapV2Router"),
            uniswapV3Router: vm.parseJsonAddress(json, ".uniswapV3Router"),
            feeFlowInitPrice: vm.parseJsonUint(json, ".feeFlowInitPrice"),
            feeFlowPaymentToken: vm.parseJsonAddress(json, ".feeFlowPaymentToken"),
            feeFlowPaymentReceiver: vm.parseJsonAddress(json, ".feeFlowPaymentReceiver"),
            feeFlowEpochPeriod: vm.parseJsonUint(json, ".feeFlowEpochPeriod"),
            feeFlowPriceMultiplier: vm.parseJsonUint(json, ".feeFlowPriceMultiplier"),
            feeFlowMinInitPrice: vm.parseJsonUint(json, ".feeFlowMinInitPrice")
        });

        // deploy integrations
        if (
            coreAddresses.evc == address(0) && coreAddresses.protocolConfig == address(0)
                && coreAddresses.sequenceRegistry == address(0) && coreAddresses.balanceTracker == address(0)
                && coreAddresses.permit2 == address(0)
        ) {
            console.log("Deploying Integrations...");
            Integrations deployer = new Integrations();
            (
                coreAddresses.evc,
                coreAddresses.protocolConfig,
                coreAddresses.sequenceRegistry,
                coreAddresses.balanceTracker,
                coreAddresses.permit2
            ) = deployer.deploy(input.permit2);
        } else {
            console.log("At least one of the Integrations contracts already deployed. Skipping...");
        }
        // deploy EVault implementation
        if (coreAddresses.eVaultImplementation == address(0)) {
            console.log("Deploying EVault implementation...");
            EVaultImplementation deployer = new EVaultImplementation();
            Base.Integrations memory integrations = Base.Integrations({
                evc: coreAddresses.evc,
                protocolConfig: coreAddresses.protocolConfig,
                sequenceRegistry: coreAddresses.sequenceRegistry,
                balanceTracker: coreAddresses.balanceTracker,
                permit2: coreAddresses.permit2
            });
            (, coreAddresses.eVaultImplementation) = deployer.deploy(integrations);
        } else {
            console.log("EVault implementation already deployed. Skipping...");
        }
        // deploy EVault factory
        if (coreAddresses.eVaultFactory == address(0)) {
            console.log("Deploying EVault factory...");
            EVaultFactory deployer = new EVaultFactory();
            coreAddresses.eVaultFactory = deployer.deploy(coreAddresses.eVaultImplementation);
        } else {
            console.log("EVault factory already deployed. Skipping...");
        }
        // deploy factory governor
        if (coreAddresses.eVaultFactoryGovernor == address(0)) {
            console.log("Deploying EVault factory governor...");
            EVaultFactoryGovernorDeployer deployer = new EVaultFactoryGovernorDeployer();
            coreAddresses.eVaultFactoryGovernor = deployer.deploy();
        } else {
            console.log("EVault factory governor already deployed. Skipping...");
        }
        // deploy euler access control emergency governor
        if (coreAddresses.eulerAccessControlEmergencyGovernor == address(0)) {
            console.log("Deploying Euler Emergency Access Control Governor...");
            GovernorAccessControlEmergencyDeployer deployer = new GovernorAccessControlEmergencyDeployer();
            coreAddresses.eulerAccessControlEmergencyGovernor = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("Euler Access Control Emergency Governor already deployed. Skipping...");
        }
        // deploy EUL
        if (coreAddresses.EUL == address(0)) {
            console.log("Deploying EUL...");
            ERC20BurnableMintableDeployer deployer = new ERC20BurnableMintableDeployer();
            coreAddresses.EUL = deployer.deploy(keccak256("EUL"), "Euler", "EUL", 18);
        } else {
            console.log("EUL already deployed. Skipping...");
        }
        // deploy rEUL
        if (coreAddresses.rEUL == address(0)) {
            console.log("Deploying rEUL...");
            RewardTokenDeployer deployer = new RewardTokenDeployer();
            coreAddresses.rEUL = deployer.deploy(
                keccak256("rEUL"),
                coreAddresses.evc,
                address(0x000000000000000000000000000000000000dEaD),
                coreAddresses.EUL,
                "Reward EUL",
                "rEUL"
            );
        } else {
            console.log("rEUL already deployed. Skipping...");
        }

        // deploy periphery factories
        if (
            peripheryAddresses.oracleRouterFactory == address(0)
                && peripheryAddresses.oracleAdapterRegistry == address(0)
                && peripheryAddresses.externalVaultRegistry == address(0) && peripheryAddresses.kinkIRMFactory == address(0)
                && peripheryAddresses.irmRegistry == address(0)
        ) {
            console.log("Deploying Periphery factories...");
            PeripheryFactories deployer = new PeripheryFactories();
            (
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry
            ) = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("At least one of the Periphery factories contracts already deployed. Skipping...");
        }
        // deploy fee flow
        if (peripheryAddresses.feeFlowController == address(0)) {
            console.log("Deploying FeeFlow...");
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
        } else {
            console.log("FeeFlow controller already deployed. Skipping...");
        }
        // deploy swapper
        if (peripheryAddresses.swapper == address(0) && peripheryAddresses.swapVerifier == address(0)) {
            console.log("Deploying Swapper...");
            Swap deployer = new Swap();
            (peripheryAddresses.swapper, peripheryAddresses.swapVerifier) =
                deployer.deploy(input.uniswapV2Router, input.uniswapV3Router);
        } else {
            console.log("At least one of the Swapper contracts already deployed. Skipping...");
        }
        // deploy perspectives
        if (
            peripheryAddresses.evkFactoryPerspective == address(0)
                && peripheryAddresses.governedPerspective == address(0)
                && peripheryAddresses.escrowedCollateralPerspective == address(0)
                && peripheryAddresses.eulerUngoverned0xPerspective == address(0)
                && peripheryAddresses.eulerUngovernedNzxPerspective == address(0)
        ) {
            console.log("Deploying Perspectives...");
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
        } else {
            console.log("At least one of the Perspectives contracts already deployed. Skipping...");
        }
        // deploy terms of use signer
        if (peripheryAddresses.termsOfUseSigner == address(0)) {
            console.log("Deploying Terms of use signer...");
            TermsOfUseSignerDeployer deployer = new TermsOfUseSignerDeployer();
            peripheryAddresses.termsOfUseSigner = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("Terms of use signer already deployed. Skipping...");
        }

        // deploy lenses
        if (
            lensAddresses.accountLens == address(0) && lensAddresses.oracleLens == address(0)
                && lensAddresses.irmLens == address(0) && lensAddresses.utilsLens == address(0)
                && lensAddresses.vaultLens == address(0) && lensAddresses.eulerEarnVaultLens == address(0)
        ) {
            console.log("Deploying Lenses...");
            Lenses deployer = new Lenses();
            address[] memory lenses =
                deployer.deploy(peripheryAddresses.oracleAdapterRegistry, peripheryAddresses.kinkIRMFactory);

            lensAddresses.accountLens = lenses[0];
            lensAddresses.oracleLens = lenses[1];
            lensAddresses.irmLens = lenses[2];
            lensAddresses.utilsLens = lenses[3];
            lensAddresses.vaultLens = lenses[4];
            lensAddresses.eulerEarnVaultLens = lenses[5];
        } else {
            console.log("At least one of the Lens contracts already deployed. Skipping...");
        }

        // additional configuration
        if (ProtocolConfig(coreAddresses.protocolConfig).feeReceiver() != peripheryAddresses.feeFlowController) {
            console.log(
                "Setting ProtocolConfig fee receiver to the feeFlowController address %s",
                peripheryAddresses.feeFlowController
            );
            startBroadcast();
            ProtocolConfig(coreAddresses.protocolConfig).setFeeReceiver(peripheryAddresses.feeFlowController);
            stopBroadcast();
        } else {
            console.log("ProtocolConfig fee receiver is already set to the feeFlowController address. Skipping...");
        }

        // save results
        vm.writeJson(serializeCoreAddresses(coreAddresses), getInputConfigFilePath("CoreAddresses_output.json"));
        vm.writeJson(
            serializePeripheryAddresses(peripheryAddresses), getInputConfigFilePath("PeripheryAddresses_output.json")
        );
        vm.writeJson(serializeLensAddresses(lensAddresses), getInputConfigFilePath("LensAddresses_output.json"));
        vm.writeJson(
            serializeMultisigAddresses(multisigAddresses), getInputConfigFilePath("MultisigAddresses_output.json")
        );
        vm.writeJson(serializeNTTAddresses(nttAddresses), getInputConfigFilePath("NTTAddresses_output.json"));

        return (coreAddresses, peripheryAddresses, lensAddresses, multisigAddresses, nttAddresses);
    }
}
