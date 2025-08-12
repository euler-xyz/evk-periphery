// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, Vm, console} from "./utils/ScriptUtils.s.sol";
import {SafeMultisendBuilder, SafeTransaction} from "./utils/SafeUtils.s.sol";
import {LayerZeroUtil} from "./utils/LayerZeroUtils.s.sol";
import {ERC20BurnableMintableDeployer, RewardTokenDeployer} from "./00_ERC20.s.sol";
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
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";
import {
    IGovernorAccessControlEmergencyFactory,
    GovernorAccessControlEmergencyFactory
} from "./../src/GovernorFactory/GovernorAccessControlEmergencyFactory.sol";
import {CapRiskStewardFactory} from "./../src/GovernorFactory/CapRiskStewardFactory.sol";
import {ERC20BurnableMintable} from "./../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {RewardToken} from "./../src/ERC20/deployed/RewardToken.sol";
import {SnapshotRegistry} from "./../src/SnapshotRegistry/SnapshotRegistry.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {Arrays} from "openzeppelin-contracts/utils/Arrays.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {ILayerZeroEndpointV2, IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
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
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

interface IEndpointV2 is ILayerZeroEndpointV2 {
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
        bool deployOFT;
        bool deployEulerSwapV1;
        address uniswapPoolManager;
        address eulerSwapFeeOwner;
        address eulerSwapFeeRecipientSetter;
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
    uint256 internal constant EUL_HUB_CHAIN_ID = 1;
    uint8 internal constant EUL_DECIMALS = 18;
    uint256 internal constant EVAULT_FACTORY_TIMELOCK_MIN_DELAY = 4 days;
    uint256 internal constant ACCESS_CONTROL_EMERGENCY_GOVERNOR_ADMIN_TIMELOCK_MIN_DELAY = 2 days;
    uint256 internal constant ACCESS_CONTROL_EMERGENCY_GOVERNOR_WILDCARD_TIMELOCK_MIN_DELAY = 2 days;
    address[2] internal EVAULT_FACTORY_GOVERNOR_PAUSERS =
        [0xff217004BdD3A6A592162380dc0E6BbF143291eB, 0xcC6451385685721778E7Bd80B54F8c92b484F601];

    uint256 internal constant FEE_FLOW_EPOCH_PERIOD = 14 days;
    uint256 internal constant FEE_FLOW_PRICE_MULTIPLIER = 2e18;
    uint256 internal constant FEE_FLOW_MIN_INIT_PRICE = 10 ** EUL_DECIMALS;

    uint16 internal constant OFT_MSG_TYPE_SEND = 1;
    uint16 internal constant OFT_MSG_TYPE_SEND_AND_CALL = 2;
    uint128 internal constant OFT_ENFORCED_GAS_LIMIT_SEND = 100000;
    uint128 internal constant OFT_ENFORCED_GAS_LIMIT_CALL = 100000;
    uint32 internal constant OFT_EXECUTOR_CONFIG_TYPE = 1;
    uint32 internal constant OFT_ULN_CONFIG_TYPE = 2;
    uint32 internal constant OFT_MAX_MESSAGE_SIZE = 10000;
    uint8 internal constant OFT_REQUIRED_DVNS_COUNT = 2;
    string[5] internal OFT_ACCEPTED_DVNS = ["LayerZero Labs", "Google", "Polyhedra", "Nethermind", "Horizen"];
    uint256[2] internal OFT_HUB_CHAIN_IDS = [EUL_HUB_CHAIN_ID, 8453];

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
            deployOFT: vm.parseJsonBool(json, ".deployOFT"),
            deployEulerSwapV1: vm.parseJsonBool(json, ".deployEulerSwapV1"),
            uniswapPoolManager: vm.parseJsonAddress(json, ".uniswapPoolManager"),
            eulerSwapFeeOwner: vm.parseJsonAddress(json, ".eulerSwapFeeOwner"),
            eulerSwapFeeRecipientSetter: vm.parseJsonAddress(json, ".eulerSwapFeeRecipientSetter")
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
                AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(
                    pauseGuardianRole, EVAULT_FACTORY_GOVERNOR_PAUSERS[i]
                );
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
            AccessControl(governorAddresses.eVaultFactoryTimelockController).grantRole(
                cancellerRole, multisigAddresses.securityCouncil
            );
            stopBroadcast();
        } else {
            console.log("- EVault factory timelock controller already deployed. Skipping...");
        }

        if (tokenAddresses.EUL == address(0) && block.chainid != EUL_HUB_CHAIN_ID) {
            console.log("+ Deploying EUL...");
            ERC20BurnableMintableDeployer deployer = new ERC20BurnableMintableDeployer();
            tokenAddresses.EUL = deployer.deploy("Euler", "EUL", EUL_DECIMALS);

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

        if (bridgeAddresses.oftAdapter == address(0)) {
            if (input.deployOFT) {
                console.log("+ Deploying OFT Adapter...");

                LayerZeroUtil lzUtil = new LayerZeroUtil();
                string memory lzMetadata = lzUtil.getRawMetadata();
                LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(lzMetadata, block.chainid);

                require(info.endpointV2 != address(0), "Failed to get OFT Adapter deployment info");
                require(info.eid >= 30000 && info.eid < 40000, "eid must indicate mainnet");

                if (block.chainid == EUL_HUB_CHAIN_ID) {
                    OFTAdapterUpgradeableDeployer deployer = new OFTAdapterUpgradeableDeployer();
                    bridgeAddresses.oftAdapter = deployer.deploy(tokenAddresses.EUL, info.endpointV2);
                } else {
                    MintBurnOFTAdapterDeployer deployer = new MintBurnOFTAdapterDeployer();
                    bridgeAddresses.oftAdapter = deployer.deploy(tokenAddresses.EUL, info.endpointV2);
                }

                require(
                    address(IOAppCore(bridgeAddresses.oftAdapter).endpoint()) == info.endpointV2,
                    "OFT Adapter endpoint mismatch"
                );
                require(IEndpointV2(info.endpointV2).eid() == info.eid, "OFT Adapter eid mismatch");

                vm.startBroadcast();
                console.log("    Setting OFT Adapter send library on chain %s", block.chainid);
                IMessageLibManager(info.endpointV2).setSendLibrary(
                    bridgeAddresses.oftAdapter, info.eid, info.sendUln302
                );

                console.log("    Setting OFT Adapter receive library on chain %s", block.chainid);
                IMessageLibManager(info.endpointV2).setReceiveLibrary(
                    bridgeAddresses.oftAdapter, info.eid, info.receiveUln302, 0
                );
                vm.stopBroadcast();

                if (!containsOftHubChainId(block.chainid)) {
                    for (uint256 i = 0; i < OFT_HUB_CHAIN_IDS.length; ++i) {
                        uint256 hubChainId = OFT_HUB_CHAIN_IDS[i];

                        BridgeAddresses memory bridgeAddressesHub =
                            deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", hubChainId));

                        LayerZeroUtil.DeploymentInfo memory infoHub = lzUtil.getDeploymentInfo(lzMetadata, hubChainId);

                        require(
                            bridgeAddressesHub.oftAdapter != address(0),
                            string.concat("Failed to get bridge addresses for chain ", vm.toString(hubChainId))
                        );

                        addBridgeConfigCache(block.chainid, hubChainId);

                        SetConfigParam[] memory params = new SetConfigParam[](2);
                        params[0] = SetConfigParam({
                            eid: infoHub.eid,
                            configType: OFT_EXECUTOR_CONFIG_TYPE,
                            config: abi.encode(
                                ExecutorConfig({maxMessageSize: OFT_MAX_MESSAGE_SIZE, executor: info.executor})
                            )
                        });
                        params[1] = SetConfigParam({
                            eid: infoHub.eid,
                            configType: OFT_ULN_CONFIG_TYPE,
                            config: abi.encode(getUlnConfig(lzUtil, lzMetadata, bridgeAddresses, info, infoHub, true))
                        });

                        vm.startBroadcast();
                        console.log(
                            "    Setting OFT Adapter send config on chain %s for chain %s", block.chainid, hubChainId
                        );
                        IMessageLibManager(info.endpointV2).setConfig(
                            bridgeAddresses.oftAdapter, info.sendUln302, params
                        );
                        vm.stopBroadcast();

                        params = new SetConfigParam[](1);
                        params[0] = SetConfigParam({
                            eid: infoHub.eid,
                            configType: OFT_ULN_CONFIG_TYPE,
                            config: abi.encode(getUlnConfig(lzUtil, lzMetadata, bridgeAddresses, info, infoHub, false))
                        });

                        vm.startBroadcast();
                        console.log(
                            "    Setting OFT Adapter receive config on chain %s for chain %s", block.chainid, hubChainId
                        );
                        IMessageLibManager(info.endpointV2).setConfig(
                            bridgeAddresses.oftAdapter, info.receiveUln302, params
                        );
                        vm.stopBroadcast();

                        vm.startBroadcast();
                        console.log("    Setting OFT Adapter peer on chain %s for chain %s", block.chainid, hubChainId);
                        IOAppCore(bridgeAddresses.oftAdapter).setPeer(
                            infoHub.eid, bytes32(uint256(uint160(bridgeAddressesHub.oftAdapter)))
                        );
                        vm.stopBroadcast();

                        vm.startBroadcast();
                        console.log(
                            "    Setting OFT Adapter enforced options on chain %s for chain %s",
                            block.chainid,
                            hubChainId
                        );
                        IOAppOptionsType3(bridgeAddresses.oftAdapter).setEnforcedOptions(
                            getEnforcedOptions(infoHub.eid)
                        );
                        vm.stopBroadcast();

                        console.log(
                            "    Sanity checking config compatibility on chain %s for chain %s",
                            block.chainid,
                            hubChainId
                        );
                        getCompatibleUlnConfig(lzUtil, lzMetadata, bridgeAddresses, infoHub, info, true);
                        getCompatibleUlnConfig(lzUtil, lzMetadata, bridgeAddresses, infoHub, info, false);
                    }
                }

                if (block.chainid != EUL_HUB_CHAIN_ID) {
                    bytes32 defaultAdminRole = ERC20BurnableMintable(tokenAddresses.EUL).DEFAULT_ADMIN_ROLE();
                    bytes32 minterRole = ERC20BurnableMintable(tokenAddresses.EUL).MINTER_ROLE();
                    if (ERC20BurnableMintable(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                        vm.startBroadcast();
                        console.log("    Granting EUL minter role to the OFT Adapter %s", bridgeAddresses.oftAdapter);
                        AccessControl(tokenAddresses.EUL).grantRole(minterRole, bridgeAddresses.oftAdapter);
                        stopBroadcast();
                    } else if (ERC20BurnableMintable(tokenAddresses.EUL).hasRole(defaultAdminRole, getSafe(false))) {
                        console.log(
                            "    Adding multisend item to grant EUL minter role to the OFT Adapter %s",
                            bridgeAddresses.oftAdapter
                        );
                        addMultisendItem(
                            tokenAddresses.EUL,
                            abi.encodeCall(AccessControl.grantRole, (minterRole, bridgeAddresses.oftAdapter))
                        );
                    } else {
                        console.log(
                            "    ! The deployer or designated safe no longer has the EUL default admin role to grant the minter role to the OFT Adapter. This must be done manually. Skipping..."
                        );
                    }
                }
            } else {
                console.log("! OFT Adapter deployment deliberately skipped. Skipping...");
            }
        } else {
            console.log("- OFT Adapter already deployed. Skipping...");
        }

        if (
            containsOftHubChainId(block.chainid) && bridgeAddresses.oftAdapter != address(0)
                && !getSkipOFTHubChainConfig()
        ) {
            console.log("+ Attempting to configure OFT Adapter on chain %s", block.chainid);

            LayerZeroUtil lzUtil = new LayerZeroUtil();
            string memory lzMetadata = lzUtil.getRawMetadata();
            LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(lzMetadata, block.chainid);
            Vm.DirEntry[] memory entries = vm.readDir(getAddressesDirPath(), 1);
            address delegate = IEndpointV2(info.endpointV2).delegates(bridgeAddresses.oftAdapter);

            for (uint256 i = 0; i < entries.length; ++i) {
                if (!entries[i].isDir) continue;

                uint256 chainIdOther = getChainIdFromAddressesDirPath(entries[i].path);

                if (chainIdOther == 0 || block.chainid == chainIdOther) continue;

                BridgeAddresses memory bridgeAddressesOther =
                    deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", chainIdOther));

                LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(lzMetadata, chainIdOther);

                if (bridgeAddressesOther.oftAdapter == address(0)) {
                    console.log("    ! OFT Adapter not deployed for chain %s. Skipping...", chainIdOther);
                    continue;
                }

                if (addBridgeConfigCache(block.chainid, chainIdOther)) {
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
                            bridgeConfigCacheExists(chainIdOther, block.chainid)
                                ? getCompatibleUlnConfig(lzUtil, lzMetadata, bridgeAddressesOther, info, infoOther, true)
                                : getUlnConfig(lzUtil, lzMetadata, bridgeAddresses, info, infoOther, true)
                        )
                    });

                    if (delegate == getDeployer()) {
                        vm.startBroadcast();
                        console.log(
                            "    + Setting OFT Adapter send config on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        IMessageLibManager(info.endpointV2).setConfig(
                            bridgeAddresses.oftAdapter, info.sendUln302, params
                        );
                        vm.stopBroadcast();
                    } else if (delegate == getSafe(false)) {
                        console.log(
                            "    + Adding multisend item to set OFT Adapter send config on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        addMultisendItem(
                            info.endpointV2,
                            abi.encodeCall(
                                IMessageLibManager.setConfig, (bridgeAddresses.oftAdapter, info.sendUln302, params)
                            )
                        );
                    } else {
                        removeBridgeConfigCache(block.chainid, chainIdOther);
                        console.log(
                            "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. OFT Adapter send config on chain %s for chain %s must be set manually.",
                            block.chainid,
                            chainIdOther
                        );
                    }

                    params = new SetConfigParam[](1);
                    params[0] = SetConfigParam({
                        eid: infoOther.eid,
                        configType: OFT_ULN_CONFIG_TYPE,
                        config: abi.encode(
                            bridgeConfigCacheExists(chainIdOther, block.chainid)
                                ? getCompatibleUlnConfig(lzUtil, lzMetadata, bridgeAddressesOther, info, infoOther, false)
                                : getUlnConfig(lzUtil, lzMetadata, bridgeAddresses, info, infoOther, false)
                        )
                    });

                    if (delegate == getDeployer()) {
                        vm.startBroadcast();
                        console.log(
                            "    + Setting OFT Adapter receive config on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        IMessageLibManager(info.endpointV2).setConfig(
                            bridgeAddresses.oftAdapter, info.receiveUln302, params
                        );
                        vm.stopBroadcast();
                    } else if (delegate == getSafe(false)) {
                        console.log(
                            "    + Adding multisend item to set OFT Adapter receive config on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        addMultisendItem(
                            info.endpointV2,
                            abi.encodeCall(
                                IMessageLibManager.setConfig, (bridgeAddresses.oftAdapter, info.receiveUln302, params)
                            )
                        );
                    } else {
                        removeBridgeConfigCache(block.chainid, chainIdOther);
                        console.log(
                            "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. OFT Adapter receive config on chain %s for chain %s must be set manually.",
                            block.chainid,
                            chainIdOther
                        );
                    }

                    if (delegate == getDeployer()) {
                        vm.startBroadcast();
                        console.log(
                            "    + Setting OFT Adapter peer on chain %s for chain %s", block.chainid, chainIdOther
                        );
                        IOAppCore(bridgeAddresses.oftAdapter).setPeer(
                            infoOther.eid, bytes32(uint256(uint160(bridgeAddressesOther.oftAdapter)))
                        );
                        vm.stopBroadcast();
                    } else if (delegate == getSafe(false)) {
                        console.log(
                            "    + Adding multisend item to set OFT Adapter peer on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        addMultisendItem(
                            bridgeAddresses.oftAdapter,
                            abi.encodeCall(
                                IOAppCore.setPeer,
                                (infoOther.eid, bytes32(uint256(uint160(bridgeAddressesOther.oftAdapter))))
                            )
                        );
                    } else {
                        removeBridgeConfigCache(block.chainid, chainIdOther);
                        console.log(
                            "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. OFT Adapter peer on chain %s for chain %s must be set manually.",
                            block.chainid,
                            chainIdOther
                        );
                    }

                    if (delegate == getDeployer()) {
                        vm.startBroadcast();
                        console.log(
                            "    + Setting OFT Adapter enforced options on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        IOAppOptionsType3(bridgeAddresses.oftAdapter).setEnforcedOptions(
                            getEnforcedOptions(infoOther.eid)
                        );
                        vm.stopBroadcast();
                    } else if (delegate == getSafe(false)) {
                        console.log(
                            "    + Adding multisend item to set OFT Adapter enforced options on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        addMultisendItem(
                            bridgeAddresses.oftAdapter,
                            abi.encodeCall(IOAppOptionsType3.setEnforcedOptions, (getEnforcedOptions(infoOther.eid)))
                        );
                    } else {
                        removeBridgeConfigCache(block.chainid, chainIdOther);
                        console.log(
                            "    ! The caller of this script or designated Safe is not the OFT Adapter delegate. OFT Adapter enforced options on chain %s for chain %s must be set manually.",
                            block.chainid,
                            chainIdOther
                        );
                    }
                } else {
                    console.log("    - OFT Adapter already configured for chain %s. Skipping...", chainIdOther);
                }
            }
        }

        if (
            peripheryAddresses.oracleRouterFactory == address(0)
                && peripheryAddresses.oracleAdapterRegistry == address(0)
                && peripheryAddresses.externalVaultRegistry == address(0) && peripheryAddresses.kinkIRMFactory == address(0)
                && peripheryAddresses.kinkyIRMFactory == address(0)
                && peripheryAddresses.fixedCyclicalBinaryIRMFactory == address(0)
                && peripheryAddresses.adaptiveCurveIRMFactory == address(0) && peripheryAddresses.irmRegistry == address(0)
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
            address paymentToken = bridgeAddresses.oftAdapter == address(0) ? getWETHAddress() : tokenAddresses.EUL;

            if (input.feeFlowInitPrice != 0 && paymentToken != address(0)) {
                console.log("+ Deploying FeeFlow...");
                FeeFlow deployer = new FeeFlow();
                peripheryAddresses.feeFlowController = deployer.deploy(
                    coreAddresses.evc,
                    input.feeFlowInitPrice,
                    paymentToken,
                    multisigAddresses.DAO,
                    FEE_FLOW_EPOCH_PERIOD,
                    FEE_FLOW_PRICE_MULTIPLIER,
                    FEE_FLOW_MIN_INIT_PRICE
                );
            } else {
                console.log("! feeFlowInitPrice or paymentToken is not set for FeeFlow deployment. Skipping...");
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
            ) = GovernorAccessControlEmergencyFactory(peripheryAddresses.governorAccessControlEmergencyFactory).deploy(
                adminTimelockControllerParams, wildcardTimelockControllerParams, governorAccessControlEmergencyGuardians
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
                deployer.deploy(input.uniswapV2Router, input.uniswapV3Router);
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

        if (coreAddresses.eulerEarnFactory == address(0)) {
            console.log("+ Deploying EulerEarn factory...");
            EulerEarnFactoryDeployer deployer = new EulerEarnFactoryDeployer();
            coreAddresses.eulerEarnFactory =
                deployer.deploy(coreAddresses.evc, coreAddresses.permit2, peripheryAddresses.evkFactoryPerspective);
        } else {
            console.log("- EulerEarn factory already deployed. Skipping...");
            if (vm.isDir("out-euler-earn")) vm.removeDir("out-euler-earn", true);
        }

        if (
            peripheryAddresses.eulerEarnFactoryPerspective == address(0)
                && peripheryAddresses.eulerEarnGovernedPerspective == address(0)
        ) {
            console.log("+ Deploying EulerEarnFactoryPerspective and Euler Earn GovernedPerspective...");
            EulerEarnPerspectivesDeployer deployer = new EulerEarnPerspectivesDeployer();
            address[] memory perspectives = deployer.deploy(coreAddresses.eulerEarnFactory);
            peripheryAddresses.eulerEarnFactoryPerspective = perspectives[0];
            peripheryAddresses.eulerEarnGovernedPerspective = perspectives[1];
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
                SnapshotRegistry(peripheryAddresses.irmRegistry).getValidAddresses(
                    address(0), address(0), block.timestamp
                ).length == 0
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
            if (input.deployEulerSwapV1) {
                {
                    console.log("+ Deploying EulerSwap V1 implementation...");
                    EulerSwapImplementationDeployer deployer = new EulerSwapImplementationDeployer();
                    eulerSwapAddresses.eulerSwapV1Implementation =
                        deployer.deploy(coreAddresses.evc, input.uniswapPoolManager);
                }
                {
                    console.log("+ Deploying EulerSwap V1 factory...");
                    EulerSwapFactoryDeployer deployer = new EulerSwapFactoryDeployer();
                    eulerSwapAddresses.eulerSwapV1Factory = deployer.deploy(
                        coreAddresses.evc,
                        coreAddresses.eVaultFactory,
                        eulerSwapAddresses.eulerSwapV1Implementation,
                        input.eulerSwapFeeOwner,
                        input.eulerSwapFeeRecipientSetter
                    );
                }
                {
                    console.log("+ Deploying EulerSwap V1 periphery...");
                    EulerSwapPeripheryDeployer deployer = new EulerSwapPeripheryDeployer();
                    eulerSwapAddresses.eulerSwapV1Periphery = deployer.deploy();
                }
            } else {
                console.log("- EulerSwap v1 not deployed. Skipping...");
                if (vm.isDir("out-euler-swap")) vm.removeDir("out-euler-swap", true);
            }
        }

        executeBatch();

        if (multisendItemExists()) {
            executeMultisend(getSafe(), safeNonce++);
        }

        saveAddresses();
        return (multisigAddresses, coreAddresses, peripheryAddresses, lensAddresses, bridgeAddresses);
    }

    function getAcceptedDVNs() internal view returns (string[] memory) {
        string[] memory acceptedDVNs = new string[](OFT_ACCEPTED_DVNS.length);
        for (uint256 i = 0; i < OFT_ACCEPTED_DVNS.length; ++i) {
            acceptedDVNs[i] = OFT_ACCEPTED_DVNS[i];
        }
        return acceptedDVNs;
    }

    function getDVNAddresses(LayerZeroUtil lzUtil, string memory metadata, string memory chainKey)
        internal
        view
        returns (address[] memory)
    {
        (, address[] memory dvns) = lzUtil.getDVNAddresses(metadata, getAcceptedDVNs(), chainKey);
        require(
            dvns.length >= OFT_REQUIRED_DVNS_COUNT, string.concat("Failed to find enough accepted DVNs for ", chainKey)
        );
        assembly {
            mstore(dvns, OFT_REQUIRED_DVNS_COUNT)
        }
        return Arrays.sort(dvns);
    }

    function getUlnConfig(
        LayerZeroUtil lzUtil,
        string memory metadata,
        BridgeAddresses memory bridgeAddresses,
        LayerZeroUtil.DeploymentInfo memory info,
        LayerZeroUtil.DeploymentInfo memory infoOther,
        bool isSend
    ) internal view returns (UlnConfig memory) {
        return UlnConfig({
            confirmations: abi.decode(
                IMessageLibManager(info.endpointV2).getConfig(
                    bridgeAddresses.oftAdapter,
                    isSend ? info.sendUln302 : info.receiveUln302,
                    infoOther.eid,
                    OFT_ULN_CONFIG_TYPE
                ),
                (UlnConfig)
            ).confirmations,
            requiredDVNCount: OFT_REQUIRED_DVNS_COUNT,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: getDVNAddresses(lzUtil, metadata, info.chainKey),
            optionalDVNs: new address[](0)
        });
    }

    function getCompatibleUlnConfig(
        LayerZeroUtil lzUtil,
        string memory metadata,
        BridgeAddresses memory bridgeAddressesOther,
        LayerZeroUtil.DeploymentInfo memory info,
        LayerZeroUtil.DeploymentInfo memory infoOther,
        bool isSend
    ) internal returns (UlnConfig memory) {
        (string[] memory dvnNames, address[] memory dvnAddresses) =
            lzUtil.getDVNAddresses(metadata, getAcceptedDVNs(), infoOther.chainKey);

        require(
            selectFork(infoOther.chainId),
            string.concat("Failed to select fork for chain ", vm.toString(infoOther.chainId))
        );

        UlnConfig memory ulnConfig = abi.decode(
            IMessageLibManager(infoOther.endpointV2).getConfig(
                bridgeAddressesOther.oftAdapter,
                isSend ? infoOther.receiveUln302 : infoOther.sendUln302,
                info.eid,
                OFT_ULN_CONFIG_TYPE
            ),
            (UlnConfig)
        );

        selectFork(DEFAULT_FORK_CHAIN_ID);

        string[] memory acceptedDVNs = new string[](ulnConfig.requiredDVNs.length);

        for (uint256 i = 0; i < dvnAddresses.length; ++i) {
            for (uint256 j = 0; j < ulnConfig.requiredDVNs.length; ++j) {
                if (dvnAddresses[i] == ulnConfig.requiredDVNs[j]) {
                    acceptedDVNs[j] = dvnNames[i];
                    break;
                }
            }
        }

        (, address[] memory dvns) = lzUtil.getDVNAddresses(metadata, acceptedDVNs, info.chainKey);
        dvns = Arrays.sort(dvns);

        require(
            dvns.length == OFT_REQUIRED_DVNS_COUNT,
            string.concat("Failed to find compatible accepted DVNs for ", info.chainKey)
        );

        return UlnConfig({
            confirmations: ulnConfig.confirmations,
            requiredDVNCount: OFT_REQUIRED_DVNS_COUNT,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: dvns,
            optionalDVNs: new address[](0)
        });
    }

    function getEnforcedOptions(uint32 eid) internal pure returns (EnforcedOptionParam[] memory) {
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(OFT_ENFORCED_GAS_LIMIT_SEND, 0)
        });
        enforcedOptions[1] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND_AND_CALL,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(OFT_ENFORCED_GAS_LIMIT_SEND, 0)
                .addExecutorLzComposeOption(0, OFT_ENFORCED_GAS_LIMIT_CALL, 0)
        });
        return enforcedOptions;
    }

    function containsOftHubChainId(uint256 chainId) internal view returns (bool) {
        for (uint256 i = 0; i < OFT_HUB_CHAIN_IDS.length; ++i) {
            if (OFT_HUB_CHAIN_IDS[i] == chainId) {
                return true;
            }
        }
        return false;
    }
}
