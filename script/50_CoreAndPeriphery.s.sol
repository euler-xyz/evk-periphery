// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, Vm, console} from "./utils/ScriptUtils.s.sol";
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
import {
    EVaultFactoryGovernorDeployer,
    TimelockControllerDeployer,
    GovernorAccessControlEmergencyDeployer
} from "./12_Governor.s.sol";
import {TermsOfUseSignerDeployer} from "./13_TermsOfUseSigner.s.sol";
import {OFTAdapterUpgradeableDeployer, MintBurnOFTAdapterDeployer} from "./14_OFT.s.sol";
import {EdgeFactoryDeployer} from "./15_EdgeFactory.s.sol";
import {EulerEarnImplementation, IntegrationsParams} from "./20_EulerEarnImplementation.s.sol";
import {EulerEarnFactory} from "./21_EulerEarnFactory.s.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";
import {GovernorAccessControlEmergency} from "./../src/Governor/GovernorAccessControlEmergency.sol";
import {ERC20BurnableMintable} from "./../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {RewardToken} from "./../src/ERC20/deployed/RewardToken.sol";
import {SnapshotRegistry} from "./../src/SnapshotRegistry/SnapshotRegistry.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
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

contract CoreAndPeriphery is BatchBuilder {
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
    }

    struct AdaptiveCurveIRMParams {
        int256 targetUtilization;
        int256 initialRateAtTarget;
        int256 minRateAtTarget;
        int256 maxRateAtTarget;
        int256 curveSteepness;
        int256 adjustmentSpeed;
    }

    mapping(uint256 chainId => bool isHarvestCoolDownCheckOn) internal EULER_EARN_HARVEST_COOL_DOWN_CHECK_ON;
    uint256[1] internal EULER_EARN_HARVEST_COOL_DOWN_CHECK_ON_CHAIN_IDS = [1];

    address internal constant BURN_ADDRESS = address(0xdead);
    uint256 internal constant EUL_HUB_CHAIN_ID = 1;
    uint8 internal constant EUL_DECIMALS = 18;
    uint256 internal constant TIMELOCK_MIN_DELAY = 4 days;
    address[2] internal EVAULT_FACTORY_GOVERNOR_PAUSERS =
        [0xff217004BdD3A6A592162380dc0E6BbF143291eB, 0xcC6451385685721778E7Bd80B54F8c92b484F601];

    uint256 internal constant FEE_FLOW_EPOCH_PERIOD = 14 days;
    uint256 internal constant FEE_FLOW_PRICE_MULTIPLIER = 2e18;
    uint256 internal constant FEE_FLOW_MIN_INIT_PRICE = 10 ** EUL_DECIMALS;

    uint16 internal constant OFT_MSG_TYPE_SEND = 1;
    uint16 internal constant OFT_MSG_TYPE_SEND_AND_CALL = 2;
    uint128 internal constant OFT_ENFORCED_GAS_LIMIT = 100000;
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
    int256 internal constant IRM_ADJUSTMENT_SPEED = 50e18 / YEAR;

    AdaptiveCurveIRMParams[] internal DEFAULT_ADAPTIVE_CURVE_IRMS_PARAMS;

    constructor() {
        for (uint256 i = 0; i < EULER_EARN_HARVEST_COOL_DOWN_CHECK_ON_CHAIN_IDS.length; ++i) {
            uint256 chainId = EULER_EARN_HARVEST_COOL_DOWN_CHECK_ON_CHAIN_IDS[i];
            EULER_EARN_HARVEST_COOL_DOWN_CHECK_ON[chainId] = true;
        }

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
            deployOFT: vm.parseJsonBool(json, ".deployOFT")
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

        if (coreAddresses.eulerEarnImplementation == address(0)) {
            console.log("+ Deploying EulerEarn implementation...");
            EulerEarnImplementation deployer = new EulerEarnImplementation();
            IntegrationsParams memory integrations = IntegrationsParams({
                evc: coreAddresses.evc,
                balanceTracker: coreAddresses.balanceTracker,
                permit2: coreAddresses.permit2,
                isHarvestCoolDownCheckOn: EULER_EARN_HARVEST_COOL_DOWN_CHECK_ON[block.chainid]
            });
            (, coreAddresses.eulerEarnImplementation) = deployer.deploy(integrations);
        } else {
            console.log("- EulerEarn implementation already deployed. Skipping...");
        }

        if (coreAddresses.eulerEarnFactory == address(0)) {
            console.log("+ Deploying EulerEarn factory...");
            EulerEarnFactory deployer = new EulerEarnFactory();
            coreAddresses.eulerEarnFactory = deployer.deploy(coreAddresses.eulerEarnImplementation);
        } else {
            console.log("- EulerEarn factory already deployed. Skipping...");
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
                deployer.deploy(TIMELOCK_MIN_DELAY, proposers, executors);

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

        if (governorAddresses.accessControlEmergencyGovernor == address(0)) {
            console.log("+ Deploying Emergency Access Control Governor...");
            GovernorAccessControlEmergencyDeployer deployer = new GovernorAccessControlEmergencyDeployer();
            governorAddresses.accessControlEmergencyGovernor = deployer.deploy(coreAddresses.evc);

            bytes32 wildCardRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).WILD_CARD();
            bytes32 ltvEmergencyRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).LTV_EMERGENCY_ROLE();
            bytes32 hookEmergencyRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).HOOK_EMERGENCY_ROLE();
            bytes32 capsEmergencyRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).CAPS_EMERGENCY_ROLE();

            console.log("    Granting wild card role to address %s", multisigAddresses.DAO);
            grantRole(governorAddresses.accessControlEmergencyGovernor, wildCardRole, multisigAddresses.DAO);

            console.log("    Granting LTV emergency role to address %s", multisigAddresses.labs);
            grantRole(governorAddresses.accessControlEmergencyGovernor, ltvEmergencyRole, multisigAddresses.labs);

            console.log("    Granting hook emergency role to address %s", multisigAddresses.labs);
            grantRole(governorAddresses.accessControlEmergencyGovernor, hookEmergencyRole, multisigAddresses.labs);

            console.log("    Granting caps emergency role to address %s", multisigAddresses.labs);
            grantRole(governorAddresses.accessControlEmergencyGovernor, capsEmergencyRole, multisigAddresses.labs);
        } else {
            console.log("- Vault Access Control Emergency Governor already deployed. Skipping...");
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

                        {
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
                                config: abi.encode(
                                    UlnConfig({
                                        confirmations: abi.decode(
                                            IMessageLibManager(info.endpointV2).getConfig(
                                                bridgeAddresses.oftAdapter, info.sendUln302, infoHub.eid, OFT_ULN_CONFIG_TYPE
                                            ),
                                            (UlnConfig)
                                        ).confirmations,
                                        requiredDVNCount: OFT_REQUIRED_DVNS_COUNT,
                                        optionalDVNCount: 0,
                                        optionalDVNThreshold: 0,
                                        requiredDVNs: getDVNAddresses(lzUtil, lzMetadata, info.chainKey),
                                        optionalDVNs: new address[](0)
                                    })
                                )
                            });

                            vm.startBroadcast();
                            console.log(
                                "    Setting OFT Adapter send config on chain %s for chain %s",
                                block.chainid,
                                hubChainId
                            );
                            IMessageLibManager(info.endpointV2).setConfig(
                                bridgeAddresses.oftAdapter, info.sendUln302, params
                            );
                            vm.stopBroadcast();
                        }

                        {
                            SetConfigParam[] memory params = new SetConfigParam[](1);
                            params[0] = SetConfigParam({
                                eid: infoHub.eid,
                                configType: OFT_ULN_CONFIG_TYPE,
                                config: abi.encode(
                                    UlnConfig({
                                        confirmations: abi.decode(
                                            IMessageLibManager(info.endpointV2).getConfig(
                                                bridgeAddresses.oftAdapter, info.receiveUln302, infoHub.eid, OFT_ULN_CONFIG_TYPE
                                            ),
                                            (UlnConfig)
                                        ).confirmations,
                                        requiredDVNCount: OFT_REQUIRED_DVNS_COUNT,
                                        optionalDVNCount: 0,
                                        optionalDVNThreshold: 0,
                                        requiredDVNs: getDVNAddresses(lzUtil, lzMetadata, infoHub.chainKey),
                                        optionalDVNs: new address[](0)
                                    })
                                )
                            });

                            vm.startBroadcast();
                            console.log(
                                "    Setting OFT Adapter receive config on chain %s for chain %s",
                                block.chainid,
                                hubChainId
                            );
                            IMessageLibManager(info.endpointV2).setConfig(
                                bridgeAddresses.oftAdapter, info.receiveUln302, params
                            );
                            vm.stopBroadcast();
                        }

                        {
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
                        }
                    }
                }

                if (block.chainid != EUL_HUB_CHAIN_ID) {
                    bytes32 defaultAdminRole = ERC20BurnableMintable(tokenAddresses.EUL).DEFAULT_ADMIN_ROLE();
                    if (ERC20BurnableMintable(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                        vm.startBroadcast();
                        console.log("    Granting EUL minter role to the OFT Adapter %s", bridgeAddresses.oftAdapter);
                        bytes32 minterRole = ERC20BurnableMintable(tokenAddresses.EUL).MINTER_ROLE();
                        AccessControl(tokenAddresses.EUL).grantRole(minterRole, bridgeAddresses.oftAdapter);
                        stopBroadcast();
                    } else {
                        console.log(
                            "    ! The deployer no longer has the EUL default admin role to grant the minter role to the OFT Adapter. This must be done manually. Skipping..."
                        );
                    }
                }
            } else {
                console.log("! OFT Adapter deployment deliberately skipped. Skipping...");
            }
        } else {
            console.log("- OFT Adapter already deployed. Skipping...");
        }

        if (containsOftHubChainId(block.chainid) && bridgeAddresses.oftAdapter != address(0)) {
            console.log("+ Attempting to configure OFT Adapter on chain %s", block.chainid);

            LayerZeroUtil lzUtil = new LayerZeroUtil();
            string memory lzMetadata = lzUtil.getRawMetadata();
            LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(lzMetadata, block.chainid);
            Vm.DirEntry[] memory entries = vm.readDir(getAddressesDirPath(), 1);
            bool isDelegate = IEndpointV2(info.endpointV2).delegates(bridgeAddresses.oftAdapter) == getDeployer();

            if (!isDelegate) {
                console.log(
                    "    ! The caller of this script is not the OFT Adapter delegate. Below OFT Adapter configuration must be done manually."
                );
            }

            for (uint256 i = 0; i < entries.length; ++i) {
                if (!entries[i].isDir) continue;

                uint256 chainIdOther = getChainIdFromAddressessDirPath(entries[i].path);

                if (chainIdOther == 0 || block.chainid == chainIdOther) continue;

                BridgeAddresses memory bridgeAddressesOther =
                    deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", chainIdOther));

                LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(lzMetadata, chainIdOther);

                if (bridgeAddressesOther.oftAdapter == address(0)) {
                    console.log("    ! OFT Adapter not deployed for chain %s. Skipping...", chainIdOther);
                    continue;
                }

                if (addBridgeConfigCache(block.chainid, chainIdOther)) {
                    if (!selectFork(chainIdOther)) {
                        console.log("    ! Failed to select fork for chain %s. Skipping...", chainIdOther);
                        removeBridgeConfigCache(block.chainid, chainIdOther);
                        continue;
                    }
                    uint64 confirmationsSendOther = abi.decode(
                        IMessageLibManager(infoOther.endpointV2).getConfig(
                            bridgeAddressesOther.oftAdapter, infoOther.sendUln302, info.eid, OFT_ULN_CONFIG_TYPE
                        ),
                        (UlnConfig)
                    ).confirmations;
                    uint64 confirmationsReceiveOther = abi.decode(
                        IMessageLibManager(infoOther.endpointV2).getConfig(
                            bridgeAddressesOther.oftAdapter, infoOther.receiveUln302, info.eid, OFT_ULN_CONFIG_TYPE
                        ),
                        (UlnConfig)
                    ).confirmations;
                    selectFork(DEFAULT_FORK_CHAIN_ID);

                    {
                        address[] memory dvns = getDVNAddresses(lzUtil, lzMetadata, info.chainKey);
                        SetConfigParam[] memory params = new SetConfigParam[](2);

                        params[0] = SetConfigParam({
                            eid: infoOther.eid,
                            configType: OFT_EXECUTOR_CONFIG_TYPE,
                            config: abi.encode(
                                ExecutorConfig({maxMessageSize: OFT_MAX_MESSAGE_SIZE, executor: info.executor})
                            )
                        });
                        params[1] = SetConfigParam({
                            eid: infoOther.eid,
                            configType: OFT_ULN_CONFIG_TYPE,
                            config: abi.encode(
                                UlnConfig({
                                    confirmations: confirmationsReceiveOther,
                                    requiredDVNCount: OFT_REQUIRED_DVNS_COUNT,
                                    optionalDVNCount: 0,
                                    optionalDVNThreshold: 0,
                                    requiredDVNs: dvns,
                                    optionalDVNs: new address[](0)
                                })
                            )
                        });

                        console.log(
                            "    Attempting to set OFT Adapter send config on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        if (isDelegate) {
                            vm.startBroadcast();
                            IMessageLibManager(info.endpointV2).setConfig(
                                bridgeAddresses.oftAdapter, info.sendUln302, params
                            );
                            vm.stopBroadcast();
                        }
                    }

                    {
                        address[] memory dvns = getDVNAddresses(lzUtil, lzMetadata, infoOther.chainKey);
                        SetConfigParam[] memory params = new SetConfigParam[](1);

                        params[0] = SetConfigParam({
                            eid: infoOther.eid,
                            configType: OFT_ULN_CONFIG_TYPE,
                            config: abi.encode(
                                UlnConfig({
                                    confirmations: confirmationsSendOther,
                                    requiredDVNCount: OFT_REQUIRED_DVNS_COUNT,
                                    optionalDVNCount: 0,
                                    optionalDVNThreshold: 0,
                                    requiredDVNs: dvns,
                                    optionalDVNs: new address[](0)
                                })
                            )
                        });

                        console.log(
                            "    Attempting to set OFT Adapter receive config on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        if (isDelegate) {
                            vm.startBroadcast();
                            IMessageLibManager(info.endpointV2).setConfig(
                                bridgeAddresses.oftAdapter, info.receiveUln302, params
                            );
                            vm.stopBroadcast();
                        }
                    }

                    {
                        console.log(
                            "    Attempting to set OFT Adapter enforced options on chain %s for chain %s",
                            block.chainid,
                            chainIdOther
                        );
                        if (isDelegate) {
                            vm.startBroadcast();
                            IOAppOptionsType3(bridgeAddresses.oftAdapter).setEnforcedOptions(
                                getEnforcedOptions(infoOther.eid)
                            );
                            vm.stopBroadcast();
                        }
                    }
                } else {
                    console.log("    ! OFT Adapter already configured for chain %s. Skipping...", chainIdOther);
                }
            }
        }

        if (
            peripheryAddresses.oracleRouterFactory == address(0)
                && peripheryAddresses.oracleAdapterRegistry == address(0)
                && peripheryAddresses.externalVaultRegistry == address(0) && peripheryAddresses.kinkIRMFactory == address(0)
                && peripheryAddresses.adaptiveCurveIRMFactory == address(0) && peripheryAddresses.irmRegistry == address(0)
        ) {
            console.log("+ Deploying Periphery factories...");
            PeripheryFactories deployer = new PeripheryFactories();
            (
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.adaptiveCurveIRMFactory,
                peripheryAddresses.irmRegistry
            ) = deployer.deploy(coreAddresses.evc);
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
                } else {
                    console.log(
                        "! The deployer no longer has the ProtocolConfig admin role to set the fee receiver address. This must be done manually. Skipping..."
                    );
                }
            } else {
                console.log("- ProtocolConfig fee receiver is already set to the desired address. Skipping...");
            }
        } else {
            console.log("- FeeFlowController already deployed. Skipping...");
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
            lensAddresses.irmLens =
                deployer.deploy(peripheryAddresses.kinkIRMFactory, peripheryAddresses.adaptiveCurveIRMFactory);
        } else {
            console.log("- LensIRM already deployed. Skipping...");
        }
        if (lensAddresses.utilsLens == address(0)) {
            console.log("+ Deploying LensUtils...");
            LensUtilsDeployer deployer = new LensUtilsDeployer();
            lensAddresses.utilsLens = deployer.deploy(lensAddresses.oracleLens);
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
            lensAddresses.eulerEarnVaultLens = deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens);
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
                if (owner == getDeployer() || (owner == getSafe() && isBatchViaSafe())) {
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

        executeBatch();

        // save results
        vm.writeJson(serializeMultisigAddresses(multisigAddresses), getScriptFilePath("MultisigAddresses_output.json"));
        vm.writeJson(serializeCoreAddresses(coreAddresses), getScriptFilePath("CoreAddresses_output.json"));
        vm.writeJson(
            serializePeripheryAddresses(peripheryAddresses), getScriptFilePath("PeripheryAddresses_output.json")
        );
        vm.writeJson(serializeGovernorAddresses(governorAddresses), getScriptFilePath("GovernorAddresses_output.json"));
        vm.writeJson(serializeTokenAddresses(tokenAddresses), getScriptFilePath("TokenAddresses_output.json"));
        vm.writeJson(serializeLensAddresses(lensAddresses), getScriptFilePath("LensAddresses_output.json"));
        vm.writeJson(serializeBridgeAddresses(bridgeAddresses), getScriptFilePath("BridgeAddresses_output.json"));
        vm.writeJson(serializeBridgeConfigCache(), getScriptFilePath("BridgeConfigCache_output.json"));

        if (isBroadcast() && !isLocalForkDeployment()) {
            vm.createDir(getAddressesFilePath("", block.chainid), true);

            vm.writeJson(
                serializeMultisigAddresses(multisigAddresses),
                getAddressesFilePath("MultisigAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeCoreAddresses(coreAddresses), getAddressesFilePath("CoreAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializePeripheryAddresses(peripheryAddresses),
                getAddressesFilePath("PeripheryAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeGovernorAddresses(governorAddresses),
                getAddressesFilePath("GovernorAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeTokenAddresses(tokenAddresses), getAddressesFilePath("TokenAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeLensAddresses(lensAddresses), getAddressesFilePath("LensAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeBridgeAddresses(bridgeAddresses), getAddressesFilePath("BridgeAddresses.json", block.chainid)
            );

            vm.createDir(string.concat(getAddressesDirPath(), "../config/bridge/"), true);
            vm.writeJson(serializeBridgeConfigCache(), getBridgeConfigCacheJsonFilePath("BridgeConfigCache.json"));
        }

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
        return dvns;
    }

    function getEnforcedOptions(uint32 eid) internal pure returns (EnforcedOptionParam[] memory) {
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](3);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND,
            options: OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), OFT_ENFORCED_GAS_LIMIT, 0)
        });
        enforcedOptions[1] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND_AND_CALL,
            options: OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), OFT_ENFORCED_GAS_LIMIT, 0)
        });
        enforcedOptions[2] = EnforcedOptionParam({
            eid: eid,
            msgType: OFT_MSG_TYPE_SEND_AND_CALL,
            options: OptionsBuilder.addExecutorLzComposeOption(OptionsBuilder.newOptions(), 0, OFT_ENFORCED_GAS_LIMIT, 0)
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
