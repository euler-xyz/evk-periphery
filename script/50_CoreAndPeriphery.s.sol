// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, Vm, console} from "./utils/ScriptUtils.s.sol";
import {SafeMultisendBuilder, SafeTransaction} from "./utils/SafeUtils.s.sol";
import {LayerZeroUtil} from "./utils/LayerZeroUtils.s.sol";
import {ERC20BurnableMintableDeployer, RewardTokenDeployer, ERC20SynthDeployer, ERC20Synth} from "./00_ERC20.s.sol";
import {Integrations} from "./01_Integrations.s.sol";
import {PeripheryFactories} from "./02_PeripheryFactories.s.sol";
import {AdaptiveCurveIRMDeployer} from "./04_IRM.s.sol";
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
    EVKPerspectiveEulerUngovernedNzxDeployer,
    EulerEarnPerspectivesDeployer,
    EdgePerspectivesDeployer
} from "./09_Perspectives.s.sol";
import {Swap} from "./10_Swap.s.sol";
import {FeeFlow} from "./11_FeeFlow.s.sol";
import {EVaultFactoryGovernorDeployer, TimelockControllerDeployer} from "./12_Governor.s.sol";
import {TermsOfUseSignerDeployer} from "./13_TermsOfUseSigner.s.sol";
import {OFTAdapterUpgradeableDeployer, MintBurnOFTAdapterDeployer} from "./14_OFT.s.sol";
import {EdgeFactoryDeployer} from "./15_EdgeFactory.s.sol";
import {EulerEarnFactoryDeployer} from "./20_EulerEarnFactory.s.sol";
import {EulerSwapImplementationDeployer} from "./21_EulerSwapImplementation.s.sol";
import {EulerSwapFactoryDeployer} from "./22_EulerSwapFactory.s.sol";
import {EulerSwapPeripheryDeployer} from "./23_EulerSwapPeriphery.s.sol";
import {EulerSwapRegistryDeployer} from "./24_EulerSwapRegistry.s.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";
import {
    IGovernorAccessControlEmergencyFactory,
    GovernorAccessControlEmergencyFactory
} from "./../src/GovernorFactory/GovernorAccessControlEmergencyFactory.sol";
import {CapRiskStewardFactory} from "./../src/GovernorFactory/CapRiskStewardFactory.sol";
import {ERC20BurnableMintable} from "./../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {RewardToken} from "./../src/ERC20/deployed/RewardToken.sol";
import {SnapshotRegistry} from "./../src/SnapshotRegistry/SnapshotRegistry.sol";
import {FeeCollectorUtil} from "./../src/Util/FeeCollectorUtil.sol";
import {OFTFeeCollectorGulper} from "./../src/OFT/OFTFeeCollectorGulper.sol";
import {OFTFeeCollector} from "./../src/OFT/OFTFeeCollector.sol";
import {EulerSavingsRate} from "evk/Synths/EulerSavingsRate.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {
    IOAppOptionsType3,
    EnforcedOptionParam
} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {
    IMessageLibManager,
    SetConfigParam
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

interface IEndpointV2 {
    function eid() external view returns (uint32);
    function delegates(address oapp) external view returns (address);
}

contract CoreAndPeriphery is BatchBuilder, SafeMultisendBuilder {
    using OptionsBuilder for bytes;

    struct Input {
        address multisigDAO;
        address multisigLabs;
        address multisigSecurityCouncil;
        address multisigSecurityPartnerA;
        address multisigSecurityPartnerB;
        address permit2;
        address uniswapV2Router;
        address uniswapV3Router;
        uint256 feeFlowInitPrice;
        bool deployEULOFT;
        bool deployEulerEarn;
        bool deployEulerSwap;
        bool deployEUSD;
        bool deploySEUSD;
        bool deploySecuritizeFactory;
        address uniswapPoolManager;
        address eulerSwapProtocolFeeConfigAdmin;
        address eulerSwapRegistryCurator;
    }

    struct AdaptiveCurveIRMParams {
        int256 targetUtilization;
        int256 initialRateAtTarget;
        int256 minRateAtTarget;
        int256 maxRateAtTarget;
        int256 curveSteepness;
        int256 adjustmentSpeed;
    }

    address internal constant BURN_ADDRESS = address(0xdead);
    uint256 internal constant HUB_CHAIN_ID = 1;
    uint8 internal constant STANDARD_DECIMALS = 18;
    uint256 internal constant EVAULT_FACTORY_TIMELOCK_MIN_DELAY = 4 days;
    uint256 internal constant ACCESS_CONTROL_EMERGENCY_GOVERNOR_ADMIN_TIMELOCK_MIN_DELAY = 2 days;
    uint256 internal constant ACCESS_CONTROL_EMERGENCY_GOVERNOR_WILDCARD_TIMELOCK_MIN_DELAY = 2 days;
    uint256 internal constant EUSD_ADMIN_TIMELOCK_MIN_DELAY = 7 days;
    address[2] internal EVAULT_FACTORY_GOVERNOR_PAUSERS =
        [0xff217004BdD3A6A592162380dc0E6BbF143291eB, 0xcC6451385685721778E7Bd80B54F8c92b484F601];

    uint256 internal constant FEE_FLOW_EPOCH_PERIOD = 14 days;
    uint256 internal constant FEE_FLOW_PRICE_MULTIPLIER = 2e18;
    uint256 internal constant FEE_FLOW_MIN_INIT_PRICE = 10 ** STANDARD_DECIMALS;

    uint16 internal constant OFT_MSG_TYPE_SEND = 1;
    uint16 internal constant OFT_MSG_TYPE_SEND_AND_CALL = 2;
    uint32 internal constant OFT_EXECUTOR_CONFIG_TYPE = 1;
    uint32 internal constant OFT_ULN_CONFIG_TYPE = 2;
    uint32 internal constant OFT_MAX_MESSAGE_SIZE = 10000;
    string[6] internal OFT_ACCEPTED_DVNS = ["LayerZero Labs", "Google", "Canary", "Polyhedra", "Nethermind", "Horizen"];

    mapping(string => uint128) internal OFT_ENFORCED_GAS_LIMIT_SEND;
    mapping(string => uint128) internal OFT_ENFORCED_GAS_LIMIT_CALL;
    mapping(string => uint8) internal OFT_REQUIRED_DVNS_COUNT;
    mapping(string => uint256[]) internal OFT_HUB_CHAIN_IDS;
    mapping(string => uint256[]) internal OFT_CONFIG_IGNORE_CHAIN_IDS;

    int256 internal constant YEAR = 365 days;
    int256 internal constant IRM_TARGET_UTILIZATION = 0.9e18;
    int256[5] internal IRM_INITIAL_RATES_AT_TARGET =
        [0.01e18 / YEAR, 0.02e18 / YEAR, 0.04e18 / YEAR, 0.08e18 / YEAR, 0.16e18 / YEAR];
    int256 internal constant IRM_MIN_RATE_AT_TARGET = 0.001e18 / YEAR;
    int256 internal constant IRM_MAX_RATE_AT_TARGET = 2e18 / YEAR;
    int256 internal constant IRM_CURVE_STEEPNESS = 4e18;
    int256 internal constant IRM_ADJUSTMENT_SPEED = 100e18 / YEAR;

    AdaptiveCurveIRMParams[] internal DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS;

    constructor() {
        OFT_ENFORCED_GAS_LIMIT_SEND["EUL"] = 100000;
        OFT_ENFORCED_GAS_LIMIT_CALL["EUL"] = 100000;
        OFT_REQUIRED_DVNS_COUNT["EUL"] = 2;
        OFT_HUB_CHAIN_IDS["EUL"] = [HUB_CHAIN_ID, 8453];
        OFT_CONFIG_IGNORE_CHAIN_IDS["EUL"] = [10, 100, 137, 480, 2818, 5000, 999, 57073, 21000000];

        OFT_ENFORCED_GAS_LIMIT_SEND["eUSD"] = 150000;
        OFT_ENFORCED_GAS_LIMIT_CALL["eUSD"] = 100000;
        OFT_REQUIRED_DVNS_COUNT["eUSD"] = 3;
        OFT_HUB_CHAIN_IDS["eUSD"] = [HUB_CHAIN_ID];
        OFT_CONFIG_IGNORE_CHAIN_IDS["eUSD"] = [10, 100, 137, 480, 2818, 5000, 999, 57073, 21000000];

        OFT_ENFORCED_GAS_LIMIT_SEND["seUSD"] = 100000;
        OFT_ENFORCED_GAS_LIMIT_CALL["seUSD"] = 100000;
        OFT_REQUIRED_DVNS_COUNT["seUSD"] = 3;
        OFT_HUB_CHAIN_IDS["seUSD"] = [HUB_CHAIN_ID];
        OFT_CONFIG_IGNORE_CHAIN_IDS["seUSD"] = [10, 100, 137, 480, 2818, 5000, 999, 57073, 21000000];

        for (uint256 i = 0; i < IRM_INITIAL_RATES_AT_TARGET.length; ++i) {
            DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS.push(
                AdaptiveCurveIRMParams({
                    targetUtilization: IRM_TARGET_UTILIZATION,
                    initialRateAtTarget: IRM_INITIAL_RATES_AT_TARGET[i],
                    minRateAtTarget: IRM_MIN_RATE_AT_TARGET,
                    maxRateAtTarget: IRM_MAX_RATE_AT_TARGET,
                    curveSteepness: IRM_CURVE_STEEPNESS,
                    adjustmentSpeed: IRM_ADJUSTMENT_SPEED
                })
            );
        }
    }

    function run()
        public
        returns (
            MultisigAddresses memory,
            CoreAddresses memory,
            PeripheryAddresses memory,
            LensAddresses memory,
            BridgeAddresses memory
        )
    {
        string memory json = getScriptFile("50_CoreAndPeriphery_input.json");
        Input memory input = Input({
            multisigDAO: vm.parseJsonAddress(json, ".multisigDAO"),
            multisigLabs: vm.parseJsonAddress(json, ".multisigLabs"),
            multisigSecurityCouncil: vm.parseJsonAddress(json, ".multisigSecurityCouncil"),
            multisigSecurityPartnerA: vm.parseJsonAddress(json, ".multisigSecurityPartnerA"),
            multisigSecurityPartnerB: vm.parseJsonAddress(json, ".multisigSecurityPartnerB"),
            permit2: vm.parseJsonAddress(json, ".permit2"),
            uniswapV2Router: vm.parseJsonAddress(json, ".uniswapV2Router"),
            uniswapV3Router: vm.parseJsonAddress(json, ".uniswapV3Router"),
            feeFlowInitPrice: vm.parseJsonUint(json, ".feeFlowInitPrice"),
            deployEULOFT: vm.parseJsonBool(json, ".deployEULOFT"),
            deployEulerEarn: vm.parseJsonBool(json, ".deployEulerEarn"),
            deployEulerSwap: vm.parseJsonBool(json, ".deployEulerSwap"),
            deployEUSD: vm.parseJsonBool(json, ".deployEUSD"),
            deploySEUSD: vm.parseJsonBool(json, ".deploySEUSD"),
            deploySecuritizeFactory: vm.parseJsonBool(json, ".deploySecuritizeFactory"),
            uniswapPoolManager: vm.parseJsonAddress(json, ".uniswapPoolManager"),
            eulerSwapProtocolFeeConfigAdmin: vm.parseJsonAddress(json, ".eulerSwapProtocolFeeConfigAdmin"),
            eulerSwapRegistryCurator: vm.parseJsonAddress(json, ".eulerSwapRegistryCurator")
        });

        if (
            multisigAddresses.DAO == address(0) && multisigAddresses.labs == address(0)
                && multisigAddresses.securityCouncil == address(0) && multisigAddresses.securityPartnerA == address(0)
                && multisigAddresses.securityPartnerB == address(0)
        ) {
            console.log("+ Assigning multisig addresses...");
            multisigAddresses.DAO = input.multisigDAO;
            multisigAddresses.labs = input.multisigLabs;
            multisigAddresses.securityCouncil = input.multisigSecurityCouncil;
            multisigAddresses.securityPartnerA = input.multisigSecurityPartnerA;
            multisigAddresses.securityPartnerB = input.multisigSecurityPartnerB;
        } else {
            console.log("- At least one of the multisig addresses already assigned. Skipping...");
        }

        verifyMultisigAddresses(multisigAddresses);

        if (
            coreAddresses.evc == address(0) && coreAddresses.protocolConfig == address(0)
                && coreAddresses.sequenceRegistry == address(0) && coreAddresses.balanceTracker == address(0)
                && coreAddresses.permit2 == address(0)
        ) {
            console.log("+ Deploying Integrations...");
            Integrations deployer = new Integrations();
            (
                coreAddresses.evc,
                coreAddresses.protocolConfig,
                coreAddresses.sequenceRegistry,
                coreAddresses.balanceTracker,
                coreAddresses.permit2
            ) = deployer.deploy(input.permit2);
        } else {
            console.log("- At least one of the Integrations contracts already deployed. Skipping...");
        }

        if (coreAddresses.eVaultImplementation == address(0)) {
            console.log("+ Deploying EVault implementation...");
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
            console.log("- EVault implementation already deployed. Skipping...");
        }

        if (coreAddresses.eVaultFactory == address(0)) {
            console.log("+ Deploying EVault factory...");
            EVaultFactory deployer = new EVaultFactory();
            coreAddresses.eVaultFactory = deployer.deploy(coreAddresses.eVaultImplementation);
        } else {
            console.log("- EVault factory already deployed. Skipping...");
        }

        if (governorAddresses.eVaultFactoryGovernor == address(0)) {
            console.log("+ Deploying EVault factory governor...");
            EVaultFactoryGovernorDeployer deployer = new EVaultFactoryGovernorDeployer();
            governorAddresses.eVaultFactoryGovernor = deployer.deploy();

            bytes32 pauseGuardianRole = FactoryGovernor(governorAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE();
            bytes32 unpauseAdminRole = FactoryGovernor(governorAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE();

            startBroadcast();
            console.log("    Granting pause guardian role to address %s", multisigAddresses.labs);
            AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(pauseGuardianRole, multisigAddresses.labs);

            for (uint256 i = 0; i < EVAULT_FACTORY_GOVERNOR_PAUSERS.length; ++i) {
                console.log("    Granting pause guardian role to address %s", EVAULT_FACTORY_GOVERNOR_PAUSERS[i]);
                AccessControl(governorAddresses.eVaultFactoryGovernor)
                    .grantRole(pauseGuardianRole, EVAULT_FACTORY_GOVERNOR_PAUSERS[i]);
            }

            console.log("    Granting unpause admin role to address %s", multisigAddresses.labs);
            AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(unpauseAdminRole, multisigAddresses.labs);
            stopBroadcast();
        } else {
            console.log("- EVault factory governor already deployed. Skipping...");
        }

        if (governorAddresses.eVaultFactoryTimelockController == address(0)) {
            console.log("+ Deploying EVault factory timelock controller...");
            TimelockControllerDeployer deployer = new TimelockControllerDeployer();
            address[] memory proposers = new address[](1);
            address[] memory executors = new address[](1);
            proposers[0] = multisigAddresses.DAO;
            executors[0] = address(0);
            governorAddresses.eVaultFactoryTimelockController =
                deployer.deploy(EVAULT_FACTORY_TIMELOCK_MIN_DELAY, proposers, executors);

            console.log("    Granting proposer role to address %s", multisigAddresses.DAO);
            console.log("    Granting canceller role to address %s", multisigAddresses.DAO);
            console.log("    Granting executor role to anyone");
            console.log("    Granting canceller role to address %s", multisigAddresses.securityCouncil);

            startBroadcast();
            bytes32 cancellerRole =
                TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).CANCELLER_ROLE();
            AccessControl(governorAddresses.eVaultFactoryTimelockController)
                .grantRole(cancellerRole, multisigAddresses.securityCouncil);
            stopBroadcast();
        } else {
            console.log("- EVault factory timelock controller already deployed. Skipping...");
        }

        if (tokenAddresses.EUL == address(0) && block.chainid != HUB_CHAIN_ID) {
            console.log("+ Deploying EUL...");
            ERC20BurnableMintableDeployer deployer = new ERC20BurnableMintableDeployer();
            tokenAddresses.EUL = deployer.deploy("Euler", "EUL", STANDARD_DECIMALS);

            startBroadcast();
            console.log("    Granting EUL revoke minter role to the desired address %s", multisigAddresses.labs);
            bytes32 revokeMinterRole = ERC20BurnableMintable(tokenAddresses.EUL).REVOKE_MINTER_ROLE();
            AccessControl(tokenAddresses.EUL).grantRole(revokeMinterRole, multisigAddresses.labs);
            stopBroadcast();
        } else {
            console.log("- EUL already deployed. Skipping...");
        }

        if (tokenAddresses.rEUL == address(0)) {
            console.log("+ Deploying rEUL...");
            RewardTokenDeployer deployer = new RewardTokenDeployer();
            tokenAddresses.rEUL =
                deployer.deploy(coreAddresses.evc, BURN_ADDRESS, tokenAddresses.EUL, "Reward EUL", "rEUL");

            console.log("    Setting whitelist admin status for address %s", multisigAddresses.labs);
            uint256 whitelistStatusAdmin = RewardToken(tokenAddresses.rEUL).WHITELIST_STATUS_ADMIN();
            setWhitelistStatus(tokenAddresses.rEUL, multisigAddresses.labs, whitelistStatusAdmin);
        } else {
            console.log("- rEUL already deployed. Skipping...");
        }

        if (bridgeAddresses.eulOFTAdapter == address(0)) {
            if (input.deployEULOFT) {
                console.log("+ Deploying OFT Adapter for EUL...");
                bridgeAddresses.eulOFTAdapter = deployAndConfigureOFTAdapter(tokenAddresses.EUL, true);
            } else {
                console.log("! EUL OFT Adapter deployment deliberately skipped. Skipping...");
            }
        } else {
            console.log("- EUL OFT Adapter already deployed. Skipping...");
        }

        if (
            containsOFTHubChainId(tokenAddresses.EUL, block.chainid) && bridgeAddresses.eulOFTAdapter != address(0)
                && !getSkipOFTHubChainConfigEUL()
        ) {
            console.log("+ Attempting to configure OFT Adapter on chain %s for EUL", block.chainid);
            configureOFTAdapter(tokenAddresses.EUL, bridgeAddresses.eulOFTAdapter);
        }

        if (tokenAddresses.eUSD == address(0)) {
            if (input.deployEUSD) {
                console.log("+ Deploying eUSD...");
                {
                    ERC20SynthDeployer deployer = new ERC20SynthDeployer();
                    tokenAddresses.eUSD = deployer.deploy(coreAddresses.evc, "Euler USD", "eUSD", STANDARD_DECIMALS);
                }

                startBroadcast();
                console.log("    Granting eUSD revoke minter role to the desired address %s", multisigAddresses.labs);
                bytes32 revokeMinterRole = ERC20BurnableMintable(tokenAddresses.eUSD).REVOKE_MINTER_ROLE();
                AccessControl(tokenAddresses.eUSD).grantRole(revokeMinterRole, multisigAddresses.labs);
                stopBroadcast();

                console.log(" + Deploying eUSD timelock controller...");
                {
                    TimelockControllerDeployer deployer = new TimelockControllerDeployer();
                    address[] memory proposers = new address[](1);
                    address[] memory executors = new address[](1);
                    proposers[0] = multisigAddresses.DAO;
                    executors[0] = address(0);
                    governorAddresses.eUSDAdminTimelockController =
                        deployer.deploy(EUSD_ADMIN_TIMELOCK_MIN_DELAY, proposers, executors);
                }

                console.log("    Granting proposer role to address %s", multisigAddresses.DAO);
                console.log("    Granting canceller role to address %s", multisigAddresses.DAO);
                console.log("    Granting executor role to anyone");
                console.log("    Granting canceller role to address %s", multisigAddresses.labs);

                startBroadcast();
                bytes32 cancellerRole =
                    TimelockController(payable(governorAddresses.eUSDAdminTimelockController)).CANCELLER_ROLE();
                AccessControl(governorAddresses.eUSDAdminTimelockController)
                    .grantRole(cancellerRole, multisigAddresses.labs);

                console.log("    Granting eUSD allocator role to the desired address %s", governorAddresses.eUSDAdminTimelockController);
                bytes32 allocatorRole = ERC20Synth(tokenAddresses.eUSD).ALLOCATOR_ROLE();
                AccessControl(tokenAddresses.eUSD).grantRole(allocatorRole, governorAddresses.eUSDAdminTimelockController);
                stopBroadcast();
            } else {
                console.log("! eUSD deployment deliberately skipped. Skipping...");
            }
        } else {
            console.log("- eUSD already deployed. Skipping...");
        }

        if (bridgeAddresses.eusdOFTAdapter == address(0)) {
            if (tokenAddresses.eUSD != address(0)) {
                console.log("+ Deploying OFT Adapter for eUSD...");
                bridgeAddresses.eusdOFTAdapter = deployAndConfigureOFTAdapter(tokenAddresses.eUSD, false);

                bytes32 defaultAdminRole = ERC20BurnableMintable(tokenAddresses.eUSD).DEFAULT_ADMIN_ROLE();
                if (ERC20BurnableMintable(tokenAddresses.eUSD).hasRole(defaultAdminRole, getDeployer())) {
                    vm.startBroadcast();
                    console.log(
                        "    Setting eUSD minter capacity to for the OFT Adapter %s", bridgeAddresses.eusdOFTAdapter
                    );
                    ERC20Synth(tokenAddresses.eUSD).setCapacity(bridgeAddresses.eusdOFTAdapter, type(uint128).max);
                    stopBroadcast();
                } else if (ERC20BurnableMintable(tokenAddresses.eUSD).hasRole(defaultAdminRole, getSafe(false))) {
                    console.log(
                        "    Adding multisend item to set eUSD minter capacity to for the OFT Adapter %s",
                        bridgeAddresses.eusdOFTAdapter
                    );
                    addMultisendItem(
                        tokenAddresses.eUSD,
                        abi.encodeCall(ERC20Synth.setCapacity, (bridgeAddresses.eusdOFTAdapter, type(uint128).max))
                    );
                } else {
                    console.log(
                        "    ! The deployer or designated safe no longer has the default admin role to set the eUSD minter capacity for the OFT Adapter. This must be done manually. Skipping..."
                    );
                }
            } else {
                console.log("! eUSD OFT Adapter deployment skipped. Skipping...");
            }
        } else {
            console.log("- eUSD OFT Adapter already deployed. Skipping...");
        }

        if (
            containsOFTHubChainId(tokenAddresses.eUSD, block.chainid) && bridgeAddresses.eusdOFTAdapter != address(0)
                && !getSkipOFTHubChainConfigEUSD()
        ) {
            console.log("+ Attempting to configure OFT Adapter on chain %s for EUSD", block.chainid);
            configureOFTAdapter(tokenAddresses.eUSD, bridgeAddresses.eusdOFTAdapter);
        }

        if (tokenAddresses.seUSD == address(0)) {
            if (input.deploySEUSD) {
                console.log("+ Deploying seUSD...");
                if (block.chainid == HUB_CHAIN_ID) {
                    startBroadcast();
                    tokenAddresses.seUSD = address(
                        new EulerSavingsRate(coreAddresses.evc, tokenAddresses.eUSD, "Savings Rate eUSD", "seUSD")
                    );
                    stopBroadcast();
                } else {
                    ERC20BurnableMintableDeployer deployer = new ERC20BurnableMintableDeployer();
                    tokenAddresses.seUSD = deployer.deploy("Savings Rate eUSD", "seUSD", STANDARD_DECIMALS);

                    startBroadcast();
                    console.log(
                        "    Granting seUSD revoke minter role to the desired address %s", multisigAddresses.labs
                    );
                    bytes32 revokeMinterRole = ERC20BurnableMintable(tokenAddresses.seUSD).REVOKE_MINTER_ROLE();
                    AccessControl(tokenAddresses.seUSD).grantRole(revokeMinterRole, multisigAddresses.labs);
                    stopBroadcast();
                }
            } else {
                console.log("! seUSD deployment deliberately skipped. Skipping...");
            }
        } else {
            console.log("- seUSD already deployed. Skipping...");
        }

        if (bridgeAddresses.seusdOFTAdapter == address(0)) {
            if (tokenAddresses.seUSD != address(0)) {
                console.log("+ Deploying OFT Adapter for seUSD...");
                bridgeAddresses.seusdOFTAdapter = deployAndConfigureOFTAdapter(tokenAddresses.seUSD, true);
            } else {
                console.log("! seUSD OFT Adapter deployment skipped. Skipping...");
            }
        } else {
            console.log("- seUSD OFT Adapter already deployed. Skipping...");
        }

        if (
            containsOFTHubChainId(tokenAddresses.seUSD, block.chainid) && bridgeAddresses.seusdOFTAdapter != address(0)
                && !getSkipOFTHubChainConfigSEUSD()
        ) {
            console.log("+ Attempting to configure OFT Adapter on chain %s for seUSD", block.chainid);
            configureOFTAdapter(tokenAddresses.seUSD, bridgeAddresses.seusdOFTAdapter);
        }

        if (peripheryAddresses.feeCollector == address(0)) {
            if (
                tokenAddresses.eUSD != address(0) && bridgeAddresses.eusdOFTAdapter != address(0)
                    && tokenAddresses.seUSD != address(0)
            ) {
                console.log("+ Deploying eUSD fee collecting system...");
                if (block.chainid == HUB_CHAIN_ID) {
                    startBroadcast();
                    console.log("    Deploying OFTFeeCollectorGulper");
                    peripheryAddresses.feeCollector =
                        address(new OFTFeeCollectorGulper(coreAddresses.evc, getDeployer(), tokenAddresses.seUSD));
                    stopBroadcast();
                } else {
                    startBroadcast();
                    console.log("    Deploying OFTFeeCollector...");
                    peripheryAddresses.feeCollector =
                        address(new OFTFeeCollector(coreAddresses.evc, getDeployer(), tokenAddresses.eUSD));
                    stopBroadcast();

                    LayerZeroUtil lzUtil = new LayerZeroUtil(HUB_CHAIN_ID);
                    LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(HUB_CHAIN_ID);
                    address feeCollectorOther =
                        deserializePeripheryAddresses(getAddressesJson("PeripheryAddresses.json", HUB_CHAIN_ID))
                    .feeCollector;

                    require(feeCollectorOther != address(0), "Hub chain feeCollector is not deployed yet");

                    startBroadcast();
                    console.log("    Configuring OFTFeeCollector");
                    OFTFeeCollector(payable(peripheryAddresses.feeCollector))
                        .configure(
                            bridgeAddresses.eusdOFTAdapter, feeCollectorOther, infoOther.eid, abi.encode(true), ""
                        );
                    stopBroadcast();
                }

                startBroadcast();
                console.log(
                    "    Granting fee collector maintainer role to the desired address %s", multisigAddresses.labs
                );
                bytes32 maintainerRole = FeeCollectorUtil(peripheryAddresses.feeCollector).MAINTAINER_ROLE();
                AccessControl(peripheryAddresses.feeCollector).grantRole(maintainerRole, multisigAddresses.labs);
                stopBroadcast();
            } else {
                console.log("- eUSD fee collecting system not deployed. Skipping...");
            }
        } else {
            console.log("- eUSD fee collecting system already deployed. Skipping...");
        }

        if (
            peripheryAddresses.oracleRouterFactory == address(0)
                && peripheryAddresses.oracleAdapterRegistry == address(0)
                && peripheryAddresses.externalVaultRegistry == address(0)
                && peripheryAddresses.kinkIRMFactory == address(0) && peripheryAddresses.kinkyIRMFactory == address(0)
                && peripheryAddresses.fixedCyclicalBinaryIRMFactory == address(0)
                && peripheryAddresses.adaptiveCurveIRMFactory == address(0)
                && peripheryAddresses.irmRegistry == address(0)
                && peripheryAddresses.governorAccessControlEmergencyFactory == address(0)
                && peripheryAddresses.capRiskStewardFactory == address(0)
        ) {
            console.log("+ Deploying Periphery factories...");
            PeripheryFactories deployer = new PeripheryFactories();
            PeripheryFactories.PeripheryContracts memory peripheryContracts = deployer.deploy(coreAddresses.evc);

            peripheryAddresses.oracleRouterFactory = peripheryContracts.oracleRouterFactory;
            peripheryAddresses.oracleAdapterRegistry = peripheryContracts.oracleAdapterRegistry;
            peripheryAddresses.externalVaultRegistry = peripheryContracts.externalVaultRegistry;
            peripheryAddresses.kinkIRMFactory = peripheryContracts.kinkIRMFactory;
            peripheryAddresses.kinkyIRMFactory = peripheryContracts.kinkyIRMFactory;
            peripheryAddresses.fixedCyclicalBinaryIRMFactory = peripheryContracts.fixedCyclicalBinaryIRMFactory;
            peripheryAddresses.adaptiveCurveIRMFactory = peripheryContracts.adaptiveCurveIRMFactory;
            peripheryAddresses.irmRegistry = peripheryContracts.irmRegistry;
            peripheryAddresses.governorAccessControlEmergencyFactory =
            peripheryContracts.governorAccessControlEmergencyFactory;
            peripheryAddresses.capRiskStewardFactory = peripheryContracts.capRiskStewardFactory;
        } else {
            console.log("- At least one of the Periphery factories contracts already deployed. Skipping...");
        }

        if (peripheryAddresses.feeFlowController == address(0)) {
            address paymentToken = bridgeAddresses.eusdOFTAdapter != address(0)
                ? tokenAddresses.eUSD
                : bridgeAddresses.eulOFTAdapter != address(0) ? tokenAddresses.EUL : getWETHAddress();
            address oftAdapter = block.chainid == HUB_CHAIN_ID
                ? address(0)
                : paymentToken == tokenAddresses.eUSD
                    ? bridgeAddresses.eusdOFTAdapter
                    : paymentToken == tokenAddresses.EUL ? bridgeAddresses.eulOFTAdapter : address(0);

            if (input.feeFlowInitPrice != 0 && paymentToken != address(0)) {
                console.log("+ Deploying FeeFlowController...");
                FeeFlow deployer = new FeeFlow();
                FeeFlow.Input memory feeFlowInput = FeeFlow.Input({
                    evc: coreAddresses.evc,
                    initPrice: input.feeFlowInitPrice,
                    paymentToken: paymentToken,
                    paymentReceiver: oftAdapter == address(0)
                        ? multisigAddresses.DAO
                        : deserializeMultisigAddresses(getAddressesJson("MultisigAddresses.json", HUB_CHAIN_ID)).DAO,
                    epochPeriod: FEE_FLOW_EPOCH_PERIOD,
                    priceMultiplier: FEE_FLOW_PRICE_MULTIPLIER,
                    minInitPrice: FEE_FLOW_MIN_INIT_PRICE,
                    oftAdapter: oftAdapter,
                    dstEid: oftAdapter == address(0)
                        ? 0
                        : (new LayerZeroUtil(HUB_CHAIN_ID)).getDeploymentInfo(HUB_CHAIN_ID).eid,
                    hookTarget: peripheryAddresses.feeCollector,
                    hookTargetSelector: FeeCollectorUtil.collectFees.selector
                });
                peripheryAddresses.feeFlowController = deployer.deploy(feeFlowInput);

                if (block.chainid != HUB_CHAIN_ID) {
                    bytes32 defaultAdminRole =
                        OFTFeeCollector(payable(peripheryAddresses.feeCollector)).DEFAULT_ADMIN_ROLE();
                    bytes32 collectorRole = OFTFeeCollector(payable(peripheryAddresses.feeCollector)).COLLECTOR_ROLE();
                    if (OFTFeeCollector(payable(peripheryAddresses.feeCollector))
                            .hasRole(defaultAdminRole, getDeployer())) {
                        vm.startBroadcast();
                        console.log(
                            "    Granting OFTFeeCollector collector role to the desired address %s",
                            peripheryAddresses.feeFlowController
                        );
                        AccessControl(peripheryAddresses.feeCollector)
                            .grantRole(collectorRole, peripheryAddresses.feeFlowController);
                        stopBroadcast();
                    } else if (OFTFeeCollector(payable(peripheryAddresses.feeCollector))
                            .hasRole(defaultAdminRole, getSafe(false))) {
                        console.log(
                            "    Adding multisend item to grant OFTFeeCollector collector role to the desired address %s",
                            peripheryAddresses.feeFlowController
                        );
                        addMultisendItem(
                            peripheryAddresses.feeCollector,
                            abi.encodeCall(
                                AccessControl.grantRole, (collectorRole, peripheryAddresses.feeFlowController)
                            )
                        );
                    } else {
                        console.log(
                            "    ! The deployer or designated safe no longer has the default admin role to grant the OFTFeeCollector collector role to the desired address. This must be done manually. Skipping..."
                        );
                    }
                }
            } else {
                console.log(
                    "! feeFlowInitPrice or paymentToken is not set for FeeFlowController deployment. Skipping..."
                );
            }

            address feeReceiver = peripheryAddresses.feeFlowController == address(0)
                ? multisigAddresses.DAO
                : peripheryAddresses.feeFlowController;

            if (ProtocolConfig(coreAddresses.protocolConfig).feeReceiver() != feeReceiver) {
                if (ProtocolConfig(coreAddresses.protocolConfig).admin() == getDeployer()) {
                    startBroadcast();
                    console.log("+ Setting ProtocolConfig fee receiver to the %s address", feeReceiver);
                    ProtocolConfig(coreAddresses.protocolConfig).setFeeReceiver(feeReceiver);
                    stopBroadcast();
                } else if (ProtocolConfig(coreAddresses.protocolConfig).admin() == getSafe(false)) {
                    addMultisendItem(
                        coreAddresses.protocolConfig, abi.encodeCall(ProtocolConfig.setFeeReceiver, (feeReceiver))
                    );
                } else {
                    console.log(
                        "! The deployer or designated Safe no longer has the ProtocolConfig admin role to set the fee receiver address. This must be done manually. Skipping..."
                    );
                }
            } else {
                console.log("- ProtocolConfig fee receiver is already set to the desired address. Skipping...");
            }
        } else {
            console.log("- FeeFlowController already deployed. Skipping...");
        }

        if (
            governorAddresses.accessControlEmergencyGovernorAdminTimelockController == address(0)
                && governorAddresses.accessControlEmergencyGovernorWildcardTimelockController == address(0)
                && governorAddresses.accessControlEmergencyGovernor == address(0)
                && governorAddresses.capRiskSteward == address(0)
        ) {
            console.log("+ Deploying GovernorAccessControlEmergency contracts suite...");

            IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams;
            IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams;
            address[] memory governorAccessControlEmergencyGuardians;

            adminTimelockControllerParams.minDelay = ACCESS_CONTROL_EMERGENCY_GOVERNOR_ADMIN_TIMELOCK_MIN_DELAY;
            adminTimelockControllerParams.proposers = new address[](1);
            adminTimelockControllerParams.proposers[0] = multisigAddresses.DAO;
            adminTimelockControllerParams.cancellers = new address[](2);
            adminTimelockControllerParams.cancellers[0] = multisigAddresses.DAO;
            adminTimelockControllerParams.cancellers[1] = multisigAddresses.labs;
            adminTimelockControllerParams.executors = new address[](1);
            adminTimelockControllerParams.executors[0] = address(0);

            console.log("    Granting admin timelock controller proposer role to address %s", multisigAddresses.DAO);
            console.log("    Granting admin timelock controller canceller role to address %s", multisigAddresses.DAO);
            console.log("    Granting admin timelock controller canceller role to address %s", multisigAddresses.labs);
            console.log("    Granting admin timelock controller executor role to anyone");

            wildcardTimelockControllerParams.minDelay = ACCESS_CONTROL_EMERGENCY_GOVERNOR_WILDCARD_TIMELOCK_MIN_DELAY;
            wildcardTimelockControllerParams.proposers = new address[](1);
            wildcardTimelockControllerParams.proposers[0] = multisigAddresses.DAO;
            wildcardTimelockControllerParams.cancellers = new address[](2);
            wildcardTimelockControllerParams.cancellers[0] = multisigAddresses.DAO;
            wildcardTimelockControllerParams.cancellers[1] = multisigAddresses.labs;
            wildcardTimelockControllerParams.executors = new address[](1);
            wildcardTimelockControllerParams.executors[0] = address(0);

            console.log("    Granting wildcard timelock controller proposer role to address %s", multisigAddresses.DAO);
            console.log("    Granting wildcard timelock controller canceller role to address %s", multisigAddresses.DAO);
            console.log(
                "    Granting wildcard timelock controller canceller role to address %s", multisigAddresses.labs
            );
            console.log("    Granting wildcard timelock controller executor role to anyone");

            governorAccessControlEmergencyGuardians = new address[](1);
            governorAccessControlEmergencyGuardians[0] = multisigAddresses.labs;

            console.log(
                "    Granting emergency access control governor guardian role to address %s", multisigAddresses.labs
            );

            startBroadcast();
            (
                governorAddresses.accessControlEmergencyGovernorAdminTimelockController,
                governorAddresses.accessControlEmergencyGovernorWildcardTimelockController,
                governorAddresses.accessControlEmergencyGovernor
            ) =
                GovernorAccessControlEmergencyFactory(peripheryAddresses.governorAccessControlEmergencyFactory)
                    .deploy(
                        adminTimelockControllerParams,
                        wildcardTimelockControllerParams,
                        governorAccessControlEmergencyGuardians
                    );

            //governorAddresses.capRiskSteward = CapRiskStewardFactory(peripheryAddresses.capRiskStewardFactory).deploy(
            //    governorAddresses.accessControlEmergencyGovernor,
            //    peripheryAddresses.kinkIRMFactory,
            //    multisigAddresses.DAO
            //);

            stopBroadcast();
        } else {
            console.log("- GovernorAccessControlEmergency contracts suite already deployed. Skipping...");
        }

        if (peripheryAddresses.swapper == address(0) && peripheryAddresses.swapVerifier == address(0)) {
            console.log("+ Deploying Swapper...");
            Swap deployer = new Swap();
            (peripheryAddresses.swapper, peripheryAddresses.swapVerifier) =
                deployer.deploy(coreAddresses.evc, coreAddresses.permit2, input.uniswapV2Router, input.uniswapV3Router);
        } else {
            console.log("- At least one of the Swapper contracts already deployed. Skipping...");
        }

        if (peripheryAddresses.evkFactoryPerspective == address(0)) {
            console.log("+ Deploying EVKFactoryPerspective...");
            EVKFactoryPerspectiveDeployer deployer = new EVKFactoryPerspectiveDeployer();
            peripheryAddresses.evkFactoryPerspective = deployer.deploy(coreAddresses.eVaultFactory);
        } else {
            console.log("- EVKFactoryPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.governedPerspective == address(0)) {
            console.log("+ Deploying GovernedPerspective...");
            PerspectiveGovernedDeployer deployer = new PerspectiveGovernedDeployer();
            peripheryAddresses.governedPerspective = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("- GovernedPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.escrowedCollateralPerspective == address(0)) {
            console.log("+ Deploying EscrowedCollateralPerspective...");
            EVKPerspectiveEscrowedCollateralDeployer deployer = new EVKPerspectiveEscrowedCollateralDeployer();
            peripheryAddresses.escrowedCollateralPerspective = deployer.deploy(coreAddresses.eVaultFactory);
        } else {
            console.log("- EscrowedCollateralPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.eulerUngoverned0xPerspective == address(0)) {
            console.log("+ Deploying EulerUngoverned0xPerspective...");
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
            console.log("- EulerUngoverned0xPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.eulerUngovernedNzxPerspective == address(0)) {
            console.log("+ Deploying EulerUngovernedNzxPerspective...");
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
            console.log("- EulerUngovernedNzxPerspective already deployed. Skipping...");
        }

        if (coreAddresses.eulerEarnFactory == address(0) && peripheryAddresses.eulerEarnPublicAllocator == address(0)) {
            if (input.deployEulerEarn) {
                console.log("+ Deploying EulerEarn factory and public allocator...");
                EulerEarnFactoryDeployer deployer = new EulerEarnFactoryDeployer();
                (coreAddresses.eulerEarnFactory, peripheryAddresses.eulerEarnPublicAllocator) =
                    deployer.deploy(coreAddresses.evc, coreAddresses.permit2, peripheryAddresses.evkFactoryPerspective);
            } else {
                console.log("- EulerEarn deliberately skipped. Skipping...");
                if (vm.isDir("out-euler-earn")) vm.removeDir("out-euler-earn", true);
            }
        } else {
            console.log("- EulerEarn factory and public allocator already deployed. Skipping...");
            if (vm.isDir("out-euler-earn")) vm.removeDir("out-euler-earn", true);
        }

        if (
            peripheryAddresses.eulerEarnFactoryPerspective == address(0)
                && peripheryAddresses.eulerEarnGovernedPerspective == address(0)
        ) {
            if (coreAddresses.eulerEarnFactory != address(0)) {
                console.log("+ Deploying EulerEarnFactoryPerspective and Euler Earn GovernedPerspective...");
                EulerEarnPerspectivesDeployer deployer = new EulerEarnPerspectivesDeployer();
                address[] memory perspectives = deployer.deploy(coreAddresses.eulerEarnFactory);
                peripheryAddresses.eulerEarnFactoryPerspective = perspectives[0];
                peripheryAddresses.eulerEarnGovernedPerspective = perspectives[1];
            } else {
                console.log("- EulerEarn perspectives not deployed. Skipping...");
            }
        } else {
            console.log("- At least one of the Euler Earn perspectives is already deployed. Skipping...");
        }

        if (peripheryAddresses.edgeFactory == address(0)) {
            console.log("+ Deploying EdgeFactory...");
            EdgeFactoryDeployer deployer = new EdgeFactoryDeployer();
            peripheryAddresses.edgeFactory = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.escrowedCollateralPerspective
            );
        } else {
            console.log("- EdgeFactory already deployed. Skipping...");
        }

        if (peripheryAddresses.edgeFactoryPerspective == address(0)) {
            console.log("+ Deploying EdgeFactoryPerspective...");
            EdgePerspectivesDeployer deployer = new EdgePerspectivesDeployer();
            peripheryAddresses.edgeFactoryPerspective = deployer.deploy(peripheryAddresses.edgeFactory)[0];
        } else {
            console.log("- EdgeFactoryPerspective already deployed. Skipping...");
        }

        if (peripheryAddresses.securitizeFactory == address(0)) {
            if (input.deploySecuritizeFactory) {
                console.log("+ Deploying ERC4626EVCCollateralSecuritizeFactory...");
                bytes memory bytecode = abi.encodePacked(
                    vm.getCode(
                        "out-securitize-factory/ERC4626EVCCollateralSecuritizeFactory.sol/ERC4626EVCCollateralSecuritizeFactory.json"
                    ),
                    abi.encode(coreAddresses.evc, coreAddresses.permit2)
                );
                address factory;
                startBroadcast();
                assembly {
                    factory := create(0, add(bytecode, 0x20), mload(bytecode))
                }
                stopBroadcast();
                peripheryAddresses.securitizeFactory = factory;
            } else {
                console.log("! ERC4626EVCCollateralSecuritizeFactory deployment deliberately skipped. Skipping...");
                if (vm.isDir("out-securitize-factory")) vm.removeDir("out-securitize-factory", true);
            }
        } else {
            console.log("- ERC4626EVCCollateralSecuritizeFactory already deployed. Skipping...");
            if (vm.isDir("out-securitize-factory")) vm.removeDir("out-securitize-factory", true);
        }

        if (peripheryAddresses.termsOfUseSigner == address(0)) {
            console.log("+ Deploying Terms of use signer...");
            TermsOfUseSignerDeployer deployer = new TermsOfUseSignerDeployer();
            peripheryAddresses.termsOfUseSigner = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("- Terms of use signer already deployed. Skipping...");
        }

        if (lensAddresses.accountLens == address(0)) {
            console.log("+ Deploying LensAccount...");
            LensAccountDeployer deployer = new LensAccountDeployer();
            lensAddresses.accountLens = deployer.deploy();
        } else {
            console.log("- LensAccount already deployed. Skipping...");
        }
        if (lensAddresses.oracleLens == address(0)) {
            console.log("+ Deploying LensOracle...");
            LensOracleDeployer deployer = new LensOracleDeployer();
            lensAddresses.oracleLens = deployer.deploy(peripheryAddresses.oracleAdapterRegistry);
        } else {
            console.log("- LensOracle already deployed. Skipping...");
        }
        if (lensAddresses.irmLens == address(0)) {
            console.log("+ Deploying LensIRM...");
            LensIRMDeployer deployer = new LensIRMDeployer();
            lensAddresses.irmLens = deployer.deploy(
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.adaptiveCurveIRMFactory,
                peripheryAddresses.kinkyIRMFactory,
                peripheryAddresses.fixedCyclicalBinaryIRMFactory
            );
        } else {
            console.log("- LensIRM already deployed. Skipping...");
        }
        if (lensAddresses.utilsLens == address(0)) {
            console.log("+ Deploying LensUtils...");
            LensUtilsDeployer deployer = new LensUtilsDeployer();
            lensAddresses.utilsLens = deployer.deploy(coreAddresses.eVaultFactory, lensAddresses.oracleLens);
        } else {
            console.log("- LensUtils already deployed. Skipping...");
        }
        if (lensAddresses.vaultLens == address(0)) {
            console.log("+ Deploying LensVault...");
            LensVaultDeployer deployer = new LensVaultDeployer();
            lensAddresses.vaultLens =
                deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens, lensAddresses.irmLens);
        } else {
            console.log("- LensVault already deployed. Skipping...");
        }
        if (lensAddresses.eulerEarnVaultLens == address(0)) {
            console.log("+ Deploying EulerEarnVaultLens...");
            LensEulerEarnVaultDeployer deployer = new LensEulerEarnVaultDeployer();
            lensAddresses.eulerEarnVaultLens = deployer.deploy(lensAddresses.utilsLens);
        } else {
            console.log("- EulerEarnVaultLens already deployed. Skipping...");
        }

        if (peripheryAddresses.adaptiveCurveIRMFactory != address(0) && peripheryAddresses.irmRegistry != address(0)) {
            if (
                SnapshotRegistry(peripheryAddresses.irmRegistry)
                    .getValidAddresses(address(0), address(0), block.timestamp)
                    .length == 0
            ) {
                address owner = SnapshotRegistry(peripheryAddresses.irmRegistry).owner();
                if (owner == getDeployer() || owner == getSafe(false)) {
                    console.log("+ Deploying default Adaptive Curve IRMs and adding them to the IRM registry...");
                    AdaptiveCurveIRMDeployer deployer = new AdaptiveCurveIRMDeployer();
                    for (uint256 i = 0; i < DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS.length; ++i) {
                        add(
                            peripheryAddresses.irmRegistry,
                            deployer.deploy(
                                peripheryAddresses.adaptiveCurveIRMFactory,
                                DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS[i].targetUtilization,
                                DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS[i].initialRateAtTarget,
                                DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS[i].minRateAtTarget,
                                DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS[i].maxRateAtTarget,
                                DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS[i].curveSteepness,
                                DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS[i].adjustmentSpeed
                            ),
                            address(0),
                            address(0)
                        );
                    }
                } else {
                    console.log(
                        "    ! The deployer or specified Safe no longer has the IRM registry owner role to add the default IRMs. Skipping..."
                    );
                }
            } else {
                console.log("- Adaptive Curve IRMs already deployed and added to the IRM registry. Skipping...");
            }
        } else {
            console.log("- Adaptive Curve IRM factory or IRM registry not deployed. Skipping...");
        }

        if (
            eulerSwapAddresses.eulerSwapV1Implementation == address(0)
                && eulerSwapAddresses.eulerSwapV1Factory == address(0)
                && eulerSwapAddresses.eulerSwapV1Periphery == address(0)
        ) {
            console.log("+ EulerSwap V1 implementation deprecated. Skipping...");
        } else {
            console.log("- EulerSwap V1 implementation, factory, and periphery already deployed. Skipping...");
        }

        if (
            eulerSwapAddresses.eulerSwapV2ProtocolFeeConfig == address(0)
                && eulerSwapAddresses.eulerSwapV2Implementation == address(0)
                && eulerSwapAddresses.eulerSwapV2Factory == address(0)
                && eulerSwapAddresses.eulerSwapV2Periphery == address(0)
                && eulerSwapAddresses.eulerSwapV2Registry == address(0)
        ) {
            if (input.deployEulerSwap) {
                {
                    console.log("+ Deploying EulerSwap V2 protocol fee config and implementation...");
                    EulerSwapImplementationDeployer deployer = new EulerSwapImplementationDeployer();
                    (eulerSwapAddresses.eulerSwapV2ProtocolFeeConfig, eulerSwapAddresses.eulerSwapV2Implementation) =
                        deployer.deploy(
                            coreAddresses.evc, input.eulerSwapProtocolFeeConfigAdmin, input.uniswapPoolManager
                        );
                }
                {
                    console.log("+ Deploying EulerSwap V2 factory...");
                    EulerSwapFactoryDeployer deployer = new EulerSwapFactoryDeployer();
                    eulerSwapAddresses.eulerSwapV2Factory =
                        deployer.deploy(coreAddresses.evc, eulerSwapAddresses.eulerSwapV2Implementation);
                }
                {
                    console.log("+ Deploying EulerSwap V2 periphery...");
                    EulerSwapPeripheryDeployer deployer = new EulerSwapPeripheryDeployer();
                    eulerSwapAddresses.eulerSwapV2Periphery = deployer.deploy();
                }
                {
                    console.log("+ Deploying EulerSwap V2 registry...");
                    EulerSwapRegistryDeployer deployer = new EulerSwapRegistryDeployer();
                    eulerSwapAddresses.eulerSwapV2Registry = deployer.deploy(
                        coreAddresses.evc,
                        eulerSwapAddresses.eulerSwapV2Factory,
                        peripheryAddresses.evkFactoryPerspective,
                        input.eulerSwapRegistryCurator
                    );
                }
            } else {
                console.log("- EulerSwap V2 deliberately skipped. Skipping...");
                if (vm.isDir("out-euler-swap")) vm.removeDir("out-euler-swap", true);
            }
        } else {
            console.log(
                "- EulerSwap V2 protocol fee config, implementation, factory, periphery and registry already deployed. Skipping..."
            );
            if (vm.isDir("out-euler-swap")) vm.removeDir("out-euler-swap", true);
        }

        executeBatch();

        if (multisendItemExists()) {
            executeMultisend(getSafe(), safeNonce++);
        }

        saveAddresses();
        return (multisigAddresses, coreAddresses, peripheryAddresses, lensAddresses, bridgeAddresses);
    }

    function getEnforcedOptions(address token, uint32 eid) internal view returns (EnforcedOptionParam[] memory) {
        string memory tokenKey = getTokenKey(token);
        require(
            OFT_ENFORCED_GAS_LIMIT_SEND[tokenKey] != 0 && OFT_ENFORCED_GAS_LIMIT_CALL[tokenKey] != 0,
            "getEnforcedOptions: Token not supported"
        );

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(OFT_ENFORCED_GAS_LIMIT_SEND[tokenKey], 0)
        });
        enforcedOptions[1] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND_AND_CALL,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(OFT_ENFORCED_GAS_LIMIT_SEND[tokenKey], 0)
                .addExecutorLzComposeOption(0, OFT_ENFORCED_GAS_LIMIT_CALL[tokenKey], 0)
        });
        return enforcedOptions;
    }

    function deployAndConfigureOFTAdapter(address token, bool tokenHasHubChain) internal returns (address adapter) {
        LayerZeroUtil lzUtil = new LayerZeroUtil(block.chainid);
        LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(block.chainid);
        string memory tokenKey = getTokenKey(token);

        if (tokenHasHubChain && block.chainid == HUB_CHAIN_ID) {
            OFTAdapterUpgradeableDeployer deployer = new OFTAdapterUpgradeableDeployer();
            adapter = deployer.deploy(token, info.endpointV2);
        } else {
            MintBurnOFTAdapterDeployer deployer = new MintBurnOFTAdapterDeployer();
            adapter = deployer.deploy(token, info.endpointV2);
        }

        require(address(IOAppCore(adapter).endpoint()) == info.endpointV2, "OFT Adapter endpoint mismatch");
        require(IEndpointV2(info.endpointV2).eid() == info.eid, string.concat("OFT Adapter eid mismatch"));

        vm.startBroadcast();
        console.log("    Setting %s OFT Adapter send library on chain %s", tokenKey, block.chainid);
        IMessageLibManager(info.endpointV2).setSendLibrary(adapter, info.eid, info.sendUln302);

        console.log("    Setting %s OFT Adapter receive library on chain %s", tokenKey, block.chainid);
        IMessageLibManager(info.endpointV2).setReceiveLibrary(adapter, info.eid, info.receiveUln302, 0);
        vm.stopBroadcast();

        if (!containsOFTHubChainId(token, block.chainid)) {
            for (uint256 i = 0; i < OFT_HUB_CHAIN_IDS[tokenKey].length; ++i) {
                uint256 hubChainId = OFT_HUB_CHAIN_IDS[tokenKey][i];
                address adapterHub = getOFTAdapter(token, hubChainId);
                LayerZeroUtil.DeploymentInfo memory infoHub = lzUtil.getDeploymentInfo(hubChainId);

                addBridgeConfigCache(tokenKey, block.chainid, hubChainId);

                SetConfigParam[] memory params = new SetConfigParam[](2);
                params[0] = SetConfigParam({
                    eid: infoHub.eid,
                    configType: OFT_EXECUTOR_CONFIG_TYPE,
                    config: abi.encode(ExecutorConfig({maxMessageSize: OFT_MAX_MESSAGE_SIZE, executor: info.executor}))
                });
                params[1] = SetConfigParam({
                    eid: infoHub.eid,
                    configType: OFT_ULN_CONFIG_TYPE,
                    config: abi.encode(
                        lzUtil.getUlnConfig(
                            adapter, hubChainId, getAcceptedDVNs(), OFT_REQUIRED_DVNS_COUNT[tokenKey], true
                        )
                    )
                });

                vm.startBroadcast();
                console.log(
                    "    Setting %s OFT Adapter send config on chain %s for chain %s",
                    tokenKey,
                    block.chainid,
                    hubChainId
                );
                IMessageLibManager(info.endpointV2).setConfig(adapter, info.sendUln302, params);
                vm.stopBroadcast();

                params = new SetConfigParam[](1);
                params[0] = SetConfigParam({
                    eid: infoHub.eid,
                    configType: OFT_ULN_CONFIG_TYPE,
                    config: abi.encode(
                        lzUtil.getUlnConfig(
                            adapter, hubChainId, getAcceptedDVNs(), OFT_REQUIRED_DVNS_COUNT[tokenKey], false
                        )
                    )
                });

                vm.startBroadcast();
                console.log(
                    "    Setting %s OFT Adapter receive config on chain %s for chain %s",
                    tokenKey,
                    block.chainid,
                    hubChainId
                );
                IMessageLibManager(info.endpointV2).setConfig(adapter, info.receiveUln302, params);
                vm.stopBroadcast();

                vm.startBroadcast();
                console.log(
                    "    Setting %s OFT Adapter peer on chain %s for chain %s", tokenKey, block.chainid, hubChainId
                );
                IOAppCore(adapter).setPeer(infoHub.eid, bytes32(uint256(uint160(adapterHub))));
                vm.stopBroadcast();

                vm.startBroadcast();
                console.log(
                    "    Setting %s OFT Adapter enforced options on chain %s for chain %s",
                    tokenKey,
                    block.chainid,
                    hubChainId
                );
                IOAppOptionsType3(adapter).setEnforcedOptions(getEnforcedOptions(token, infoHub.eid));
                vm.stopBroadcast();

                console.log(
                    "    Sanity checking config compatibility on chain %s for chain %s", block.chainid, hubChainId
                );
                lzUtil.getCompatibleUlnConfig(adapter, hubChainId, block.chainid, getAcceptedDVNs(), true);
                lzUtil.getCompatibleUlnConfig(adapter, hubChainId, block.chainid, getAcceptedDVNs(), false);
            }
        }

        if (!tokenHasHubChain || block.chainid != HUB_CHAIN_ID) {
            bytes32 defaultAdminRole = ERC20BurnableMintable(token).DEFAULT_ADMIN_ROLE();
            bytes32 minterRole = ERC20BurnableMintable(token).MINTER_ROLE();
            if (ERC20BurnableMintable(token).hasRole(defaultAdminRole, getDeployer())) {
                vm.startBroadcast();
                console.log("    Granting minter role to the OFT Adapter %s", adapter);
                AccessControl(token).grantRole(minterRole, adapter);
                stopBroadcast();
            } else if (ERC20BurnableMintable(token).hasRole(defaultAdminRole, getSafe(false))) {
                console.log("    Adding multisend item to grant minter role to the OFT Adapter %s", adapter);
                addMultisendItem(token, abi.encodeCall(AccessControl.grantRole, (minterRole, adapter)));
            } else {
                console.log(
                    "    ! The deployer or designated safe no longer has the default admin role to grant the minter role to the OFT Adapter. This must be done manually. Skipping..."
                );
            }
        }
    }

    function configureOFTAdapter(address token, address adapter) internal {
        LayerZeroUtil lzUtil = new LayerZeroUtil(block.chainid);
        LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(block.chainid);
        Vm.DirEntry[] memory entries = vm.readDir(getAddressesDirPath(), 1);
        address delegate = IEndpointV2(info.endpointV2).delegates(adapter);
        string memory tokenKey = getTokenKey(token);

        for (uint256 i = 0; i < entries.length; ++i) {
            if (!entries[i].isDir) continue;

            uint256 chainIdOther = getChainIdFromAddressesDirPath(entries[i].path);

            if (chainIdOther == 0 || block.chainid == chainIdOther) continue;

            address adapterOther = getOFTAdapter(token, chainIdOther);

            if (adapterOther == address(0)) {
                console.log("    ! %s OFT Adapter not deployed for chain %s. Skipping...", tokenKey, chainIdOther);
                continue;
            }

            if (
                bridgeConfigCacheExists(tokenKey, block.chainid, chainIdOther)
                    && containsOFTConfigIgnoreChainId(token, chainIdOther)
            ) {
                LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(chainIdOther);
                removeBridgeConfigCache(tokenKey, block.chainid, chainIdOther);

                if (delegate == getDeployer()) {
                    vm.startBroadcast();
                    console.log(
                        "    + Removing %s OFT Adapter config on chain %s for chain %s by setting peer to address zero",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    IOAppCore(adapter).setPeer(infoOther.eid, bytes32(0));
                    vm.stopBroadcast();
                } else if (delegate == getSafe(false)) {
                    console.log(
                        "    + Adding multisend item to remove %s OFT Adapter config on chain %s for chain %s by setting peer to address zero",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    addMultisendItem(adapter, abi.encodeCall(IOAppCore.setPeer, (infoOther.eid, bytes32(0))));
                } else {
                    addBridgeConfigCache(tokenKey, block.chainid, chainIdOther);
                    console.log(
                        "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. %s OFT Adapter config on chain %s for chain %s must be removed manually.",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                }
            } else if (addBridgeConfigCache(tokenKey, block.chainid, chainIdOther)) {
                LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(chainIdOther);

                SetConfigParam[] memory params = new SetConfigParam[](2);
                params[0] = SetConfigParam({
                    eid: infoOther.eid,
                    configType: OFT_EXECUTOR_CONFIG_TYPE,
                    config: abi.encode(ExecutorConfig({maxMessageSize: OFT_MAX_MESSAGE_SIZE, executor: info.executor}))
                });
                params[1] = SetConfigParam({
                    eid: infoOther.eid,
                    configType: OFT_ULN_CONFIG_TYPE,
                    config: abi.encode(
                        bridgeConfigCacheExists(tokenKey, chainIdOther, block.chainid)
                            ? lzUtil.getCompatibleUlnConfig(
                                adapterOther, block.chainid, chainIdOther, getAcceptedDVNs(), true
                            )
                            : lzUtil.getUlnConfig(
                                adapter, chainIdOther, getAcceptedDVNs(), OFT_REQUIRED_DVNS_COUNT[tokenKey], true
                            )
                    )
                });

                if (delegate == getDeployer()) {
                    vm.startBroadcast();
                    console.log(
                        "    + Setting %s OFT Adapter send config on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    IMessageLibManager(info.endpointV2).setConfig(adapter, info.sendUln302, params);
                    vm.stopBroadcast();
                } else if (delegate == getSafe(false)) {
                    console.log(
                        "    + Adding multisend item to set %s OFT Adapter send config on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    addMultisendItem(
                        info.endpointV2,
                        abi.encodeCall(IMessageLibManager.setConfig, (adapter, info.sendUln302, params))
                    );
                } else {
                    removeBridgeConfigCache(tokenKey, block.chainid, chainIdOther);
                    console.log(
                        "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. %s OFT Adapter send config on chain %s for chain %s must be set manually.",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                }

                params = new SetConfigParam[](1);
                params[0] = SetConfigParam({
                    eid: infoOther.eid,
                    configType: OFT_ULN_CONFIG_TYPE,
                    config: abi.encode(
                        bridgeConfigCacheExists(tokenKey, chainIdOther, block.chainid)
                            ? lzUtil.getCompatibleUlnConfig(
                                adapterOther, block.chainid, chainIdOther, getAcceptedDVNs(), false
                            )
                            : lzUtil.getUlnConfig(
                                adapter, chainIdOther, getAcceptedDVNs(), OFT_REQUIRED_DVNS_COUNT[tokenKey], false
                            )
                    )
                });

                if (delegate == getDeployer()) {
                    vm.startBroadcast();
                    console.log(
                        "    + Setting %s OFT Adapter receive config on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    IMessageLibManager(info.endpointV2).setConfig(adapter, info.receiveUln302, params);
                    vm.stopBroadcast();
                } else if (delegate == getSafe(false)) {
                    console.log(
                        "    + Adding multisend item to set %s OFT Adapter receive config on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    addMultisendItem(
                        info.endpointV2,
                        abi.encodeCall(IMessageLibManager.setConfig, (adapter, info.receiveUln302, params))
                    );
                } else {
                    removeBridgeConfigCache(tokenKey, block.chainid, chainIdOther);
                    console.log(
                        "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. %s OFT Adapter receive config on chain %s for chain %s must be set manually.",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                }

                if (delegate == getDeployer()) {
                    vm.startBroadcast();
                    console.log(
                        "    + Setting %s OFT Adapter peer on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    IOAppCore(adapter).setPeer(infoOther.eid, bytes32(uint256(uint160(adapterOther))));
                    vm.stopBroadcast();
                } else if (delegate == getSafe(false)) {
                    console.log(
                        "    + Adding multisend item to set %s OFT Adapter peer on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    addMultisendItem(
                        adapter,
                        abi.encodeCall(IOAppCore.setPeer, (infoOther.eid, bytes32(uint256(uint160(adapterOther)))))
                    );
                } else {
                    removeBridgeConfigCache(tokenKey, block.chainid, chainIdOther);
                    console.log(
                        "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. %s OFT Adapter peer on chain %s for chain %s must be set manually.",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                }

                if (delegate == getDeployer()) {
                    vm.startBroadcast();
                    console.log(
                        "    + Setting %s OFT Adapter enforced options on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    IOAppOptionsType3(adapter).setEnforcedOptions(getEnforcedOptions(token, infoOther.eid));
                    vm.stopBroadcast();
                } else if (delegate == getSafe(false)) {
                    console.log(
                        "    + Adding multisend item to set %s OFT Adapter enforced options on chain %s for chain %s",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                    addMultisendItem(
                        adapter,
                        abi.encodeCall(IOAppOptionsType3.setEnforcedOptions, (getEnforcedOptions(token, infoOther.eid)))
                    );
                } else {
                    removeBridgeConfigCache(tokenKey, block.chainid, chainIdOther);
                    console.log(
                        "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. %s OFT Adapter enforced options on chain %s for chain %s must be set manually.",
                        tokenKey,
                        block.chainid,
                        chainIdOther
                    );
                }
            } else {
                console.log("    - %s OFT Adapter already configured for chain %s. Skipping...", tokenKey, chainIdOther);
            }
        }
    }

    function getTokenKey(address token) internal view returns (string memory) {
        if (token == tokenAddresses.EUL) {
            return "EUL";
        } else if (token == tokenAddresses.eUSD) {
            return "eUSD";
        } else if (token == tokenAddresses.seUSD) {
            return "seUSD";
        }

        revert("getTokenKey: Token not supported");
    }

    function getOFTAdapter(address token, uint256 chainId) internal view returns (address adapter) {
        BridgeAddresses memory chainIdBridgeAddresses =
            deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", chainId));

        if (token == tokenAddresses.EUL) {
            adapter = chainIdBridgeAddresses.eulOFTAdapter;
        } else if (token == tokenAddresses.eUSD) {
            adapter = chainIdBridgeAddresses.eusdOFTAdapter;
        } else if (token == tokenAddresses.seUSD) {
            adapter = chainIdBridgeAddresses.seusdOFTAdapter;
        }
    }

    function getAcceptedDVNs() internal view returns (string[] memory) {
        string[] memory acceptedDVNs = new string[](OFT_ACCEPTED_DVNS.length);
        for (uint256 i = 0; i < OFT_ACCEPTED_DVNS.length; ++i) {
            acceptedDVNs[i] = OFT_ACCEPTED_DVNS[i];
        }
        return acceptedDVNs;
    }

    function containsOFTHubChainId(address token, uint256 chainId) internal view returns (bool) {
        string memory tokenKey = getTokenKey(token);
        require(OFT_HUB_CHAIN_IDS[tokenKey].length != 0, "containsOFTHubChainId: Token not supported");

        for (uint256 i = 0; i < OFT_HUB_CHAIN_IDS[tokenKey].length; ++i) {
            if (OFT_HUB_CHAIN_IDS[tokenKey][i] == chainId) {
                return true;
            }
        }
        return false;
    }

    function containsOFTConfigIgnoreChainId(address token, uint256 chainId) internal view returns (bool) {
        string memory tokenKey = getTokenKey(token);

        for (uint256 i = 0; i < OFT_CONFIG_IGNORE_CHAIN_IDS[tokenKey].length; ++i) {
            if (OFT_CONFIG_IGNORE_CHAIN_IDS[tokenKey][i] == chainId) {
                return true;
            }
        }
        return false;
    }
}
