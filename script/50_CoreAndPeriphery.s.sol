// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {ERC20BurnableMintableDeployer, RewardTokenDeployer} from "./00_ERC20.s.sol";
import {Integrations} from "./01_Integrations.s.sol";
import {PeripheryFactories} from "./02_PeripheryFactories.s.sol";
import {EVaultImplementation} from "./05_EVaultImplementation.s.sol";
import {EVaultFactory} from "./06_EVaultFactory.s.sol";
import {
    LensAccountDeployer,
    LensOracleDeployer,
    LensIRMDeployer,
    LensVaultDeployer,
    LensUtilsDeployer,
    LensEulerEarnVaultDeployer
} from "./08_Lenses.s.sol";
import {
    EVKFactoryPerspectiveDeployer,
    PerspectiveGovernedDeployer,
    EVKPerspectiveEscrowedCollateralDeployer,
    EVKPerspectiveEulerUngoverned0xDeployer,
    EVKPerspectiveEulerUngovernedNzxDeployer
} from "./09_Perspectives.s.sol";
import {Swap} from "./10_Swap.s.sol";
import {FeeFlow} from "./11_FeeFlow.s.sol";
import {EVaultFactoryGovernorDeployer, GovernorAccessControlEmergencyDeployer} from "./12_Governor.s.sol";
import {TermsOfUseSignerDeployer} from "./13_TermsOfUseSigner.s.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";
import {GovernorAccessControlEmergency} from "./../src/Governor/GovernorAccessControlEmergency.sol";
import {ERC20BurnableMintable} from "./../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

contract CoreAndPeriphery is BatchBuilder {
    struct Input {
        address multisigDAO;
        address multisigLabs;
        address multisigSecurityCouncil;
        address permit2;
        address uniswapV2Router;
        address uniswapV3Router;
        uint256 feeFlowInitPrice;
    }

    function run()
        public
        returns (
            MultisigAddresses memory,
            CoreAddresses memory,
            PeripheryAddresses memory,
            LensAddresses memory,
            NTTAddresses memory
        )
    {
        string memory json = getInputConfig("50_CoreAndPeriphery_input.json");
        Input memory input = Input({
            multisigDAO: vm.parseJsonAddress(json, ".multisigDAO"),
            multisigLabs: vm.parseJsonAddress(json, ".multisigLabs"),
            multisigSecurityCouncil: vm.parseJsonAddress(json, ".multisigSecurityCouncil"),
            permit2: vm.parseJsonAddress(json, ".permit2"),
            uniswapV2Router: vm.parseJsonAddress(json, ".uniswapV2Router"),
            uniswapV3Router: vm.parseJsonAddress(json, ".uniswapV3Router"),
            feeFlowInitPrice: vm.parseJsonUint(json, ".feeFlowInitPrice")
        });

        if (
            multisigAddresses.DAO == address(0) && multisigAddresses.labs == address(0)
                && multisigAddresses.securityCouncil == address(0)
        ) {
            console.log("Assigning multisig addresses...");
            multisigAddresses.DAO = input.multisigDAO;
            multisigAddresses.labs = input.multisigLabs;
            multisigAddresses.securityCouncil = input.multisigSecurityCouncil;
        } else {
            console.log("At least one of the multisig addresses already assigned. Skipping...");
        }

        verifyMultisigAddresses(multisigAddresses);

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

        if (coreAddresses.eVaultFactory == address(0)) {
            console.log("Deploying EVault factory...");
            EVaultFactory deployer = new EVaultFactory();
            coreAddresses.eVaultFactory = deployer.deploy(coreAddresses.eVaultImplementation);
        } else {
            console.log("EVault factory already deployed. Skipping...");
        }

        if (coreAddresses.eVaultFactoryGovernor == address(0)) {
            console.log("Deploying EVault factory governor...");
            EVaultFactoryGovernorDeployer deployer = new EVaultFactoryGovernorDeployer();
            coreAddresses.eVaultFactoryGovernor = deployer.deploy();

            bytes32 pauseGuardianRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE();
            bytes32 unpauseAdminRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE();

            startBroadcast();
            console.log("Granting pause guardian role to address %s", multisigAddresses.securityCouncil);
            AccessControl(coreAddresses.eVaultFactoryGovernor).grantRole(
                pauseGuardianRole, multisigAddresses.securityCouncil
            );

            console.log("Granting unpause admin role to address %s", multisigAddresses.securityCouncil);
            AccessControl(coreAddresses.eVaultFactoryGovernor).grantRole(
                unpauseAdminRole, multisigAddresses.securityCouncil
            );
            stopBroadcast();
        } else {
            console.log("EVault factory governor already deployed. Skipping...");
        }

        if (coreAddresses.accessControlEmergencyGovernor == address(0)) {
            console.log("Deploying Euler Emergency Access Control Governor...");
            GovernorAccessControlEmergencyDeployer deployer = new GovernorAccessControlEmergencyDeployer();
            coreAddresses.accessControlEmergencyGovernor = deployer.deploy(coreAddresses.evc);

            bytes32 wildCardRole =
                GovernorAccessControlEmergency(coreAddresses.accessControlEmergencyGovernor).WILD_CARD();
            bytes32 ltvEmergencyRole =
                GovernorAccessControlEmergency(coreAddresses.accessControlEmergencyGovernor).LTV_EMERGENCY_ROLE();
            bytes32 hookEmergencyRole =
                GovernorAccessControlEmergency(coreAddresses.accessControlEmergencyGovernor).HOOK_EMERGENCY_ROLE();
            bytes32 capsEmergencyRole =
                GovernorAccessControlEmergency(coreAddresses.accessControlEmergencyGovernor).CAPS_EMERGENCY_ROLE();

            console.log("Granting wild card role to address %s", multisigAddresses.DAO);
            grantRole(coreAddresses.accessControlEmergencyGovernor, wildCardRole, multisigAddresses.DAO);

            console.log("Granting LTV emergency role to address %s", multisigAddresses.labs);
            grantRole(coreAddresses.accessControlEmergencyGovernor, ltvEmergencyRole, multisigAddresses.labs);

            console.log("Granting hook emergency role to address %s", multisigAddresses.labs);
            grantRole(coreAddresses.accessControlEmergencyGovernor, hookEmergencyRole, multisigAddresses.labs);

            console.log("Granting caps emergency role to address %s", multisigAddresses.labs);
            grantRole(coreAddresses.accessControlEmergencyGovernor, capsEmergencyRole, multisigAddresses.labs);
        } else {
            console.log("Euler Access Control Emergency Governor already deployed. Skipping...");
        }

        if (coreAddresses.EUL == address(0)) {
            if (block.chainid != 1) {
                console.log("Deploying EUL...");
                ERC20BurnableMintableDeployer deployer = new ERC20BurnableMintableDeployer();
                coreAddresses.EUL = deployer.deploy(keccak256("EUL"), "Euler", "EUL", 18);
            }

            // TODO: deploy and configure the NTT contracts here

            if (block.chainid != 1) {
                bytes32 revokeMinterRole = ERC20BurnableMintable(coreAddresses.EUL).REVOKE_MINTER_ROLE();
                bytes32 minterRole = ERC20BurnableMintable(coreAddresses.EUL).MINTER_ROLE();

                console.log("Granting EUL revoke minter role to the desired address %s", multisigAddresses.labs);
                grantRole(coreAddresses.EUL, revokeMinterRole, multisigAddresses.labs);

                //console.log("Granting EUL minter role to the desired address %s", nttAddresses.manager);
                //grantRole(coreAddresses.EUL, minterRole, nttAddresses.manager);
            }
        } else {
            console.log("EUL already deployed. Skipping...");
        }

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

        if (peripheryAddresses.feeFlowController == address(0)) {
            console.log("Deploying FeeFlow...");
            FeeFlow deployer = new FeeFlow();
            peripheryAddresses.feeFlowController = deployer.deploy(
                coreAddresses.evc, input.feeFlowInitPrice, coreAddresses.EUL, multisigAddresses.DAO, 14 days, 2e18, 1e18
            );

            console.log(
                "Setting ProtocolConfig fee receiver to the feeFlowController address %s",
                peripheryAddresses.feeFlowController
            );

            startBroadcast();
            ProtocolConfig(coreAddresses.protocolConfig).setFeeReceiver(peripheryAddresses.feeFlowController);
            stopBroadcast();
        } else {
            console.log("FeeFlow controller already deployed. Skipping...");
        }

        if (peripheryAddresses.swapper == address(0) && peripheryAddresses.swapVerifier == address(0)) {
            console.log("Deploying Swapper...");
            Swap deployer = new Swap();
            (peripheryAddresses.swapper, peripheryAddresses.swapVerifier) =
                deployer.deploy(input.uniswapV2Router, input.uniswapV3Router);
        } else {
            console.log("At least one of the Swapper contracts already deployed. Skipping...");
        }

        if (peripheryAddresses.evkFactoryPerspective == address(0)) {
            console.log("Deploying EVKFactoryPerspective...");
            EVKFactoryPerspectiveDeployer deployer = new EVKFactoryPerspectiveDeployer();
            peripheryAddresses.evkFactoryPerspective = deployer.deploy(coreAddresses.eVaultFactory);
        } else {
            console.log("EVKFactoryPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.governedPerspective == address(0)) {
            console.log("Deploying GovernedPerspective...");
            PerspectiveGovernedDeployer deployer = new PerspectiveGovernedDeployer();
            peripheryAddresses.governedPerspective = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("GovernedPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.escrowedCollateralPerspective == address(0)) {
            console.log("Deploying EscrowedCollateralPerspective...");
            EVKPerspectiveEscrowedCollateralDeployer deployer = new EVKPerspectiveEscrowedCollateralDeployer();
            peripheryAddresses.escrowedCollateralPerspective = deployer.deploy(coreAddresses.eVaultFactory);
        } else {
            console.log("EscrowedCollateralPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.eulerUngoverned0xPerspective == address(0)) {
            console.log("Deploying EulerUngoverned0xPerspective...");
            EVKPerspectiveEulerUngoverned0xDeployer deployer = new EVKPerspectiveEulerUngoverned0xDeployer();
            peripheryAddresses.eulerUngoverned0xPerspective = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry,
                peripheryAddresses.escrowedCollateralPerspective
            );
        } else {
            console.log("EulerUngoverned0xPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.eulerUngovernedNzxPerspective == address(0)) {
            console.log("Deploying EulerUngovernedNzxPerspective...");
            EVKPerspectiveEulerUngovernedNzxDeployer deployer = new EVKPerspectiveEulerUngovernedNzxDeployer();
            peripheryAddresses.eulerUngovernedNzxPerspective = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry,
                peripheryAddresses.governedPerspective,
                peripheryAddresses.escrowedCollateralPerspective
            );
        } else {
            console.log("EulerUngovernedNzxPerspective already deployed. Skipping...");
        }

        if (peripheryAddresses.termsOfUseSigner == address(0)) {
            console.log("Deploying Terms of use signer...");
            TermsOfUseSignerDeployer deployer = new TermsOfUseSignerDeployer();
            peripheryAddresses.termsOfUseSigner = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("Terms of use signer already deployed. Skipping...");
        }

        if (lensAddresses.accountLens == address(0)) {
            console.log("Deploying LensAccount...");
            LensAccountDeployer deployer = new LensAccountDeployer();
            lensAddresses.accountLens = deployer.deploy();
        } else {
            console.log("LensAccount already deployed. Skipping...");
        }
        if (lensAddresses.oracleLens == address(0)) {
            console.log("Deploying LensOracle...");
            LensOracleDeployer deployer = new LensOracleDeployer();
            lensAddresses.oracleLens = deployer.deploy(peripheryAddresses.oracleAdapterRegistry);
        } else {
            console.log("LensOracle already deployed. Skipping...");
        }
        if (lensAddresses.irmLens == address(0)) {
            console.log("Deploying LensIRM...");
            LensIRMDeployer deployer = new LensIRMDeployer();
            lensAddresses.irmLens = deployer.deploy(peripheryAddresses.kinkIRMFactory);
        } else {
            console.log("LensIRM already deployed. Skipping...");
        }
        if (lensAddresses.utilsLens == address(0)) {
            console.log("Deploying LensUtils...");
            LensUtilsDeployer deployer = new LensUtilsDeployer();
            lensAddresses.utilsLens = deployer.deploy(lensAddresses.oracleLens);
        } else {
            console.log("LensUtils already deployed. Skipping...");
        }
        if (lensAddresses.vaultLens == address(0)) {
            console.log("Deploying LensVault...");
            LensVaultDeployer deployer = new LensVaultDeployer();
            lensAddresses.vaultLens =
                deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens, lensAddresses.irmLens);
        } else {
            console.log("LensVault already deployed. Skipping...");
        }
        //if (lensAddresses.eulerEarnVaultLens == address(0)) {
        //    console.log("Deploying EulerEarnVaultLens...");
        //    LensEulerEarnVaultDeployer deployer = new LensEulerEarnVaultDeployer();
        //    lensAddresses.eulerEarnVaultLens = deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens);
        //} else {
        //    console.log("EulerEarnVaultLens already deployed. Skipping...");
        //}

        executeBatch();

        // save results
        vm.writeJson(
            serializeMultisigAddresses(multisigAddresses), getInputConfigFilePath("MultisigAddresses_output.json")
        );
        vm.writeJson(serializeCoreAddresses(coreAddresses), getInputConfigFilePath("CoreAddresses_output.json"));
        vm.writeJson(
            serializePeripheryAddresses(peripheryAddresses), getInputConfigFilePath("PeripheryAddresses_output.json")
        );
        vm.writeJson(serializeLensAddresses(lensAddresses), getInputConfigFilePath("LensAddresses_output.json"));
        vm.writeJson(serializeNTTAddresses(nttAddresses), getInputConfigFilePath("NTTAddresses_output.json"));

        return (multisigAddresses, coreAddresses, peripheryAddresses, lensAddresses, nttAddresses);
    }
}
