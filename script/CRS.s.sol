// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, Vm, console} from "./utils/ScriptUtils.s.sol";
import {SafeMultisendBuilder, SafeTransaction, SafeUtil} from "./utils/SafeUtils.s.sol";
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
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {TermsOfUseSignerDeployer} from "./13_TermsOfUseSigner.s.sol";
import {OFTAdapterUpgradeableDeployer, MintBurnOFTAdapterDeployer} from "./14_OFT.s.sol";
import {EdgeFactoryDeployer} from "./15_EdgeFactory.s.sol";
import {EulerEarnImplementation, IntegrationsParams} from "./20_EulerEarnImplementation.s.sol";
import {EulerEarnFactory} from "./21_EulerEarnFactory.s.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";
import {
    IGovernorAccessControlEmergencyFactory,
    GovernorAccessControlEmergencyFactory
} from "./../src/GovernorFactory/GovernorAccessControlEmergencyFactory.sol";
import {CapRiskStewardFactory} from "./../src/GovernorFactory/CapRiskStewardFactory.sol";
import {CapRiskSteward} from "./../src/Governor/CapRiskSteward.sol";
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

import {IEVault} from "evk/EVault/IEVault.sol";

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
        startBroadcast();
        CapRiskSteward capRiskSteward = new CapRiskSteward(governorAddresses.accessControlEmergencyGovernor, peripheryAddresses.kinkIRMFactory, getDeployer(), 2e18, 1 days);
        
        capRiskSteward.grantRole(capRiskSteward.WILD_CARD(), 0x171b16D40e8C3Db6fb5A2EA25ae21e4cddca89a7);
        capRiskSteward.grantRole(capRiskSteward.DEFAULT_ADMIN_ROLE(), multisigAddresses.DAO);
        capRiskSteward.renounceRole(capRiskSteward.DEFAULT_ADMIN_ROLE(), getDeployer());
        stopBroadcast();

        console.log("to: ", governorAddresses.accessControlEmergencyGovernorAdminTimelockController);
        
        address[] memory targets = new address[](4);
        targets[0] = address(governorAddresses.accessControlEmergencyGovernor);
        targets[1] = address(governorAddresses.accessControlEmergencyGovernor);
        targets[2] = address(governorAddresses.accessControlEmergencyGovernor);
        targets[3] = address(governorAddresses.accessControlEmergencyGovernor);
        
        uint256[] memory values = new uint256[](4);
        bytes[] memory payloads = new bytes[](4);
        payloads[0] = abi.encodeCall(AccessControl.revokeRole, (IEVault(address(0)).setCaps.selector, governorAddresses.capRiskSteward));
        payloads[1] = abi.encodeCall(AccessControl.revokeRole, (IEVault(address(0)).setInterestRateModel.selector, governorAddresses.capRiskSteward));
        
        governorAddresses.capRiskSteward = address(capRiskSteward);
        payloads[2] = abi.encodeCall(AccessControl.grantRole, (IEVault(address(0)).setCaps.selector, governorAddresses.capRiskSteward));
        payloads[3] = abi.encodeCall(AccessControl.grantRole, (IEVault(address(0)).setInterestRateModel.selector, governorAddresses.capRiskSteward));
        
        bytes memory data = abi.encodeCall(TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days));
        console.logBytes(data);

        for (uint256 i = 0; i < targets.length; ++i) {
            vm.prank(governorAddresses.accessControlEmergencyGovernorAdminTimelockController);
            (bool success, ) = targets[i].call(payloads[i]);
            require(success, "failed to call");
        }

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
}
