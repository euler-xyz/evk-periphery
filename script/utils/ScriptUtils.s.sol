// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {ScriptExtended, console} from "./ScriptExtended.s.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {Arrays} from "openzeppelin-contracts/utils/Arrays.sol";
import {EnumerableMap, EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableMap.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault, IGovernance} from "evk/EVault/IEVault.sol";
import {EulerRouter, Governable} from "euler-price-oracle/EulerRouter.sol";
import {SafeTransaction, SafeUtil} from "./SafeUtils.s.sol";
import {BaseFactory} from "../../src/BaseFactory/BaseFactory.sol";
import {SnapshotRegistry} from "../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {OracleLens} from "../../src/Lens/OracleLens.sol";
import {GovernorAccessControl} from "../../src/Governor/GovernorAccessControl.sol";
import {CapRiskSteward} from "../../src/Governor/CapRiskSteward.sol";
import "../../src/Lens/LensTypes.sol";

abstract contract CoreAddressesLib is ScriptExtended {
    struct CoreAddresses {
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address eVaultImplementation;
        address eVaultFactory;
        address eulerEarnFactory;
    }

    function serializeCoreAddresses(CoreAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("coreAddresses", "evc", Addresses.evc);
        result = vm.serializeAddress("coreAddresses", "protocolConfig", Addresses.protocolConfig);
        result = vm.serializeAddress("coreAddresses", "sequenceRegistry", Addresses.sequenceRegistry);
        result = vm.serializeAddress("coreAddresses", "balanceTracker", Addresses.balanceTracker);
        result = vm.serializeAddress("coreAddresses", "permit2", Addresses.permit2);
        result = vm.serializeAddress("coreAddresses", "eVaultImplementation", Addresses.eVaultImplementation);
        result = vm.serializeAddress("coreAddresses", "eVaultFactory", Addresses.eVaultFactory);
        result = vm.serializeAddress("coreAddresses", "eulerEarnFactory", Addresses.eulerEarnFactory);
    }

    function deserializeCoreAddresses(string memory json) internal pure returns (CoreAddresses memory) {
        return CoreAddresses({
            evc: getAddressFromJson(json, ".evc"),
            protocolConfig: getAddressFromJson(json, ".protocolConfig"),
            sequenceRegistry: getAddressFromJson(json, ".sequenceRegistry"),
            balanceTracker: getAddressFromJson(json, ".balanceTracker"),
            permit2: getAddressFromJson(json, ".permit2"),
            eVaultImplementation: getAddressFromJson(json, ".eVaultImplementation"),
            eVaultFactory: getAddressFromJson(json, ".eVaultFactory"),
            eulerEarnFactory: getAddressFromJson(json, ".eulerEarnFactory")
        });
    }
}

abstract contract PeripheryAddressesLib is ScriptExtended {
    struct PeripheryAddresses {
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address kinkyIRMFactory;
        address fixedCyclicalBinaryIRMFactory;
        address adaptiveCurveIRMFactory;
        address irmRegistry;
        address swapper;
        address swapVerifier;
        address feeFlowController;
        address feeFlowControllerUtil;
        address feeCollector;
        address evkFactoryPerspective;
        address governedPerspective;
        address escrowedCollateralPerspective;
        address eulerUngoverned0xPerspective;
        address eulerUngovernedNzxPerspective;
        address eulerEarnFactoryPerspective;
        address eulerEarnGovernedPerspective;
        address edgeFactory;
        address edgeFactoryPerspective;
        address termsOfUseSigner;
        address governorAccessControlEmergencyFactory;
        address capRiskStewardFactory;
        address eulerEarnPublicAllocator;
        address securitizeFactory;
    }

    function serializePeripheryAddresses(PeripheryAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("peripheryAddresses", "oracleRouterFactory", Addresses.oracleRouterFactory);
        result = vm.serializeAddress("peripheryAddresses", "oracleAdapterRegistry", Addresses.oracleAdapterRegistry);
        result = vm.serializeAddress("peripheryAddresses", "externalVaultRegistry", Addresses.externalVaultRegistry);
        result = vm.serializeAddress("peripheryAddresses", "kinkIRMFactory", Addresses.kinkIRMFactory);
        result = vm.serializeAddress("peripheryAddresses", "kinkyIRMFactory", Addresses.kinkyIRMFactory);
        result = vm.serializeAddress(
            "peripheryAddresses", "fixedCyclicalBinaryIRMFactory", Addresses.fixedCyclicalBinaryIRMFactory
        );
        result = vm.serializeAddress("peripheryAddresses", "adaptiveCurveIRMFactory", Addresses.adaptiveCurveIRMFactory);
        result = vm.serializeAddress("peripheryAddresses", "irmRegistry", Addresses.irmRegistry);
        result = vm.serializeAddress("peripheryAddresses", "swapper", Addresses.swapper);
        result = vm.serializeAddress("peripheryAddresses", "swapVerifier", Addresses.swapVerifier);
        result = vm.serializeAddress("peripheryAddresses", "feeFlowController", Addresses.feeFlowController);
        result = vm.serializeAddress("peripheryAddresses", "feeFlowControllerUtil", Addresses.feeFlowControllerUtil);
        result = vm.serializeAddress("peripheryAddresses", "feeCollector", Addresses.feeCollector);
        result = vm.serializeAddress("peripheryAddresses", "evkFactoryPerspective", Addresses.evkFactoryPerspective);
        result = vm.serializeAddress("peripheryAddresses", "governedPerspective", Addresses.governedPerspective);
        result = vm.serializeAddress(
            "peripheryAddresses", "escrowedCollateralPerspective", Addresses.escrowedCollateralPerspective
        );
        result = vm.serializeAddress(
            "peripheryAddresses", "eulerUngoverned0xPerspective", Addresses.eulerUngoverned0xPerspective
        );
        result = vm.serializeAddress(
            "peripheryAddresses", "eulerUngovernedNzxPerspective", Addresses.eulerUngovernedNzxPerspective
        );
        result = vm.serializeAddress(
            "peripheryAddresses", "eulerEarnFactoryPerspective", Addresses.eulerEarnFactoryPerspective
        );
        result = vm.serializeAddress(
            "peripheryAddresses", "eulerEarnGovernedPerspective", Addresses.eulerEarnGovernedPerspective
        );
        result = vm.serializeAddress("peripheryAddresses", "edgeFactory", Addresses.edgeFactory);
        result = vm.serializeAddress("peripheryAddresses", "edgeFactoryPerspective", Addresses.edgeFactoryPerspective);
        result = vm.serializeAddress("peripheryAddresses", "termsOfUseSigner", Addresses.termsOfUseSigner);
        result = vm.serializeAddress(
            "peripheryAddresses",
            "governorAccessControlEmergencyFactory",
            Addresses.governorAccessControlEmergencyFactory
        );
        result = vm.serializeAddress("peripheryAddresses", "capRiskStewardFactory", Addresses.capRiskStewardFactory);
        result =
            vm.serializeAddress("peripheryAddresses", "eulerEarnPublicAllocator", Addresses.eulerEarnPublicAllocator);
        result = vm.serializeAddress("peripheryAddresses", "securitizeFactory", Addresses.securitizeFactory);
    }

    function deserializePeripheryAddresses(string memory json) internal pure returns (PeripheryAddresses memory) {
        return PeripheryAddresses({
            oracleRouterFactory: getAddressFromJson(json, ".oracleRouterFactory"),
            oracleAdapterRegistry: getAddressFromJson(json, ".oracleAdapterRegistry"),
            externalVaultRegistry: getAddressFromJson(json, ".externalVaultRegistry"),
            kinkIRMFactory: getAddressFromJson(json, ".kinkIRMFactory"),
            kinkyIRMFactory: getAddressFromJson(json, ".kinkyIRMFactory"),
            fixedCyclicalBinaryIRMFactory: getAddressFromJson(json, ".fixedCyclicalBinaryIRMFactory"),
            adaptiveCurveIRMFactory: getAddressFromJson(json, ".adaptiveCurveIRMFactory"),
            irmRegistry: getAddressFromJson(json, ".irmRegistry"),
            swapper: getAddressFromJson(json, ".swapper"),
            swapVerifier: getAddressFromJson(json, ".swapVerifier"),
            feeFlowController: getAddressFromJson(json, ".feeFlowController"),
            feeFlowControllerUtil: getAddressFromJson(json, ".feeFlowControllerUtil"),
            feeCollector: getAddressFromJson(json, ".feeCollector"),
            evkFactoryPerspective: getAddressFromJson(json, ".evkFactoryPerspective"),
            governedPerspective: getAddressFromJson(json, ".governedPerspective"),
            escrowedCollateralPerspective: getAddressFromJson(json, ".escrowedCollateralPerspective"),
            eulerUngoverned0xPerspective: getAddressFromJson(json, ".eulerUngoverned0xPerspective"),
            eulerUngovernedNzxPerspective: getAddressFromJson(json, ".eulerUngovernedNzxPerspective"),
            eulerEarnFactoryPerspective: getAddressFromJson(json, ".eulerEarnFactoryPerspective"),
            eulerEarnGovernedPerspective: getAddressFromJson(json, ".eulerEarnGovernedPerspective"),
            edgeFactory: getAddressFromJson(json, ".edgeFactory"),
            edgeFactoryPerspective: getAddressFromJson(json, ".edgeFactoryPerspective"),
            termsOfUseSigner: getAddressFromJson(json, ".termsOfUseSigner"),
            governorAccessControlEmergencyFactory: getAddressFromJson(json, ".governorAccessControlEmergencyFactory"),
            capRiskStewardFactory: getAddressFromJson(json, ".capRiskStewardFactory"),
            eulerEarnPublicAllocator: getAddressFromJson(json, ".eulerEarnPublicAllocator"),
            securitizeFactory: getAddressFromJson(json, ".securitizeFactory")
        });
    }
}

abstract contract LensAddressesLib is ScriptExtended {
    struct LensAddresses {
        address accountLens;
        address oracleLens;
        address irmLens;
        address utilsLens;
        address vaultLens;
        address eulerEarnVaultLens;
    }

    function serializeLensAddresses(LensAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("lensAddresses", "accountLens", Addresses.accountLens);
        result = vm.serializeAddress("lensAddresses", "oracleLens", Addresses.oracleLens);
        result = vm.serializeAddress("lensAddresses", "irmLens", Addresses.irmLens);
        result = vm.serializeAddress("lensAddresses", "utilsLens", Addresses.utilsLens);
        result = vm.serializeAddress("lensAddresses", "vaultLens", Addresses.vaultLens);
        result = vm.serializeAddress("lensAddresses", "eulerEarnVaultLens", Addresses.eulerEarnVaultLens);
    }

    function deserializeLensAddresses(string memory json) internal pure returns (LensAddresses memory) {
        return LensAddresses({
            accountLens: getAddressFromJson(json, ".accountLens"),
            oracleLens: getAddressFromJson(json, ".oracleLens"),
            irmLens: getAddressFromJson(json, ".irmLens"),
            utilsLens: getAddressFromJson(json, ".utilsLens"),
            vaultLens: getAddressFromJson(json, ".vaultLens"),
            eulerEarnVaultLens: getAddressFromJson(json, ".eulerEarnVaultLens")
        });
    }
}

abstract contract GovernorAddressesLib is ScriptExtended {
    struct GovernorAddresses {
        address eVaultFactoryGovernor;
        address eVaultFactoryTimelockController;
        address accessControlEmergencyGovernor;
        address accessControlEmergencyGovernorAdminTimelockController;
        address accessControlEmergencyGovernorWildcardTimelockController;
        address capRiskSteward;
        address eUSDAdminTimelockController;
    }

    function serializeGovernorAddresses(GovernorAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("governorAddresses", "eVaultFactoryGovernor", Addresses.eVaultFactoryGovernor);
        result = vm.serializeAddress(
            "governorAddresses", "eVaultFactoryTimelockController", Addresses.eVaultFactoryTimelockController
        );
        result = vm.serializeAddress(
            "governorAddresses", "accessControlEmergencyGovernor", Addresses.accessControlEmergencyGovernor
        );
        result = vm.serializeAddress(
            "governorAddresses",
            "accessControlEmergencyGovernorAdminTimelockController",
            Addresses.accessControlEmergencyGovernorAdminTimelockController
        );
        result = vm.serializeAddress(
            "governorAddresses",
            "accessControlEmergencyGovernorWildcardTimelockController",
            Addresses.accessControlEmergencyGovernorWildcardTimelockController
        );
        result = vm.serializeAddress("governorAddresses", "capRiskSteward", Addresses.capRiskSteward);
        result = vm.serializeAddress(
            "governorAddresses", "eUSDAdminTimelockController", Addresses.eUSDAdminTimelockController
        );
    }

    function deserializeGovernorAddresses(string memory json) internal pure returns (GovernorAddresses memory) {
        return GovernorAddresses({
            eVaultFactoryGovernor: getAddressFromJson(json, ".eVaultFactoryGovernor"),
            eVaultFactoryTimelockController: getAddressFromJson(json, ".eVaultFactoryTimelockController"),
            accessControlEmergencyGovernor: getAddressFromJson(json, ".accessControlEmergencyGovernor"),
            accessControlEmergencyGovernorAdminTimelockController: getAddressFromJson(
                json, ".accessControlEmergencyGovernorAdminTimelockController"
            ),
            accessControlEmergencyGovernorWildcardTimelockController: getAddressFromJson(
                json, ".accessControlEmergencyGovernorWildcardTimelockController"
            ),
            capRiskSteward: getAddressFromJson(json, ".capRiskSteward"),
            eUSDAdminTimelockController: getAddressFromJson(json, ".eUSDAdminTimelockController")
        });
    }
}

abstract contract TokenAddressesLib is ScriptExtended {
    struct TokenAddresses {
        address EUL;
        address rEUL;
        address eUSD;
        address seUSD;
    }

    function serializeTokenAddresses(TokenAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("tokenAddresses", "EUL", Addresses.EUL);
        result = vm.serializeAddress("tokenAddresses", "rEUL", Addresses.rEUL);
        result = vm.serializeAddress("tokenAddresses", "eUSD", Addresses.eUSD);
        result = vm.serializeAddress("tokenAddresses", "seUSD", Addresses.seUSD);
    }

    function deserializeTokenAddresses(string memory json) internal pure returns (TokenAddresses memory) {
        return TokenAddresses({
            EUL: getAddressFromJson(json, ".EUL"),
            rEUL: getAddressFromJson(json, ".rEUL"),
            eUSD: getAddressFromJson(json, ".eUSD"),
            seUSD: getAddressFromJson(json, ".seUSD")
        });
    }
}

abstract contract MultisigAddressesLib is ScriptExtended {
    struct MultisigAddresses {
        address DAO;
        address labs;
        address securityCouncil;
        address securityPartnerA;
        address securityPartnerB;
    }

    function serializeMultisigAddresses(MultisigAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("multisigAddresses", "DAO", Addresses.DAO);
        result = vm.serializeAddress("multisigAddresses", "labs", Addresses.labs);
        result = vm.serializeAddress("multisigAddresses", "securityCouncil", Addresses.securityCouncil);
        result = vm.serializeAddress("multisigAddresses", "securityPartnerA", Addresses.securityPartnerA);
        result = vm.serializeAddress("multisigAddresses", "securityPartnerB", Addresses.securityPartnerB);
    }

    function deserializeMultisigAddresses(string memory json) internal pure returns (MultisigAddresses memory) {
        return MultisigAddresses({
            DAO: getAddressFromJson(json, ".DAO"),
            labs: getAddressFromJson(json, ".labs"),
            securityCouncil: getAddressFromJson(json, ".securityCouncil"),
            securityPartnerA: getAddressFromJson(json, ".securityPartnerA"),
            securityPartnerB: getAddressFromJson(json, ".securityPartnerB")
        });
    }

    function verifyMultisigAddresses(MultisigAddresses memory Addresses) internal view {
        if (vm.envOr("FORCE_MULTISIG_ADDRESSES", false)) return;

        require(Addresses.DAO != address(0), "DAO multisig is required");
        require(Addresses.labs != address(0), "Labs multisig is required");
        require(Addresses.securityCouncil != address(0), "Security Council multisig is required");
        require(Addresses.securityPartnerA != address(0), "Security Partner A is required");
        require(Addresses.securityPartnerB != address(0), "Security Partner B is required");

        require(Addresses.DAO.code.length != 0, "DAO multisig is not a contract");
        require(Addresses.labs.code.length != 0, "Labs multisig is not a contract");
        require(Addresses.securityCouncil.code.length != 0, "Security Council multisig is not a contract");
        require(Addresses.securityPartnerA.code.length != 0, "Security Partner A is not a contract");
        require(Addresses.securityPartnerB.code.length != 0, "Security Partner B is not a contract");
    }
}

abstract contract EulerSwapAddressesLib is ScriptExtended {
    struct EulerSwapAddresses {
        address eulerSwapV1Implementation;
        address eulerSwapV1Factory;
        address eulerSwapV1Periphery;
        address eulerSwapV2ProtocolFeeConfig;
        address eulerSwapV2Implementation;
        address eulerSwapV2Factory;
        address eulerSwapV2Periphery;
        address eulerSwapV2Registry;
    }

    function serializeEulerSwapAddresses(EulerSwapAddresses memory Addresses) internal returns (string memory result) {
        result =
            vm.serializeAddress("eulerSwapAddresses", "eulerSwapV1Implementation", Addresses.eulerSwapV1Implementation);
        result = vm.serializeAddress("eulerSwapAddresses", "eulerSwapV1Factory", Addresses.eulerSwapV1Factory);
        result = vm.serializeAddress("eulerSwapAddresses", "eulerSwapV1Periphery", Addresses.eulerSwapV1Periphery);
        result = vm.serializeAddress(
            "eulerSwapAddresses", "eulerSwapV2ProtocolFeeConfig", Addresses.eulerSwapV2ProtocolFeeConfig
        );
        result =
            vm.serializeAddress("eulerSwapAddresses", "eulerSwapV2Implementation", Addresses.eulerSwapV2Implementation);
        result = vm.serializeAddress("eulerSwapAddresses", "eulerSwapV2Factory", Addresses.eulerSwapV2Factory);
        result = vm.serializeAddress("eulerSwapAddresses", "eulerSwapV2Periphery", Addresses.eulerSwapV2Periphery);
        result = vm.serializeAddress("eulerSwapAddresses", "eulerSwapV2Registry", Addresses.eulerSwapV2Registry);
    }

    function deserializeEulerSwapAddresses(string memory json) internal pure returns (EulerSwapAddresses memory) {
        return EulerSwapAddresses({
            eulerSwapV1Implementation: getAddressFromJson(json, ".eulerSwapV1Implementation"),
            eulerSwapV1Factory: getAddressFromJson(json, ".eulerSwapV1Factory"),
            eulerSwapV1Periphery: getAddressFromJson(json, ".eulerSwapV1Periphery"),
            eulerSwapV2ProtocolFeeConfig: getAddressFromJson(json, ".eulerSwapV2ProtocolFeeConfig"),
            eulerSwapV2Implementation: getAddressFromJson(json, ".eulerSwapV2Implementation"),
            eulerSwapV2Factory: getAddressFromJson(json, ".eulerSwapV2Factory"),
            eulerSwapV2Periphery: getAddressFromJson(json, ".eulerSwapV2Periphery"),
            eulerSwapV2Registry: getAddressFromJson(json, ".eulerSwapV2Registry")
        });
    }
}

abstract contract BridgeAddressesLib is ScriptExtended {
    struct BridgeAddresses {
        address eulOFTAdapter;
        address eusdOFTAdapter;
        address seusdOFTAdapter;
    }

    function serializeBridgeAddresses(BridgeAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("bridgeAddresses", "eulOFTAdapter", Addresses.eulOFTAdapter);
        result = vm.serializeAddress("bridgeAddresses", "eusdOFTAdapter", Addresses.eusdOFTAdapter);
        result = vm.serializeAddress("bridgeAddresses", "seusdOFTAdapter", Addresses.seusdOFTAdapter);
    }

    function deserializeBridgeAddresses(string memory json) internal pure returns (BridgeAddresses memory) {
        return BridgeAddresses({
            eulOFTAdapter: getAddressFromJson(json, ".eulOFTAdapter"),
            eusdOFTAdapter: getAddressFromJson(json, ".eusdOFTAdapter"),
            seusdOFTAdapter: getAddressFromJson(json, ".seusdOFTAdapter")
        });
    }
}

abstract contract BridgeConfigCache is ScriptExtended {
    using stdJson for string;
    using Arrays for uint256[];
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    EnumerableSet.Bytes32Set internal keys;
    mapping(bytes32 keyBytes => string) internal keyNames;
    mapping(bytes32 keyBytes => EnumerableSet.UintSet) internal srcChainIds;
    mapping(bytes32 keyBytes => mapping(uint256 srcChainId => EnumerableMap.UintToUintMap)) internal config;

    function addBridgeConfigCache(string memory key, uint256 srcChainId, uint256 dstChainId) internal returns (bool) {
        bytes32 keyBytes = keccak256(abi.encode(key));
        keyNames[keyBytes] = key;
        keys.add(keyBytes);
        srcChainIds[keyBytes].add(srcChainId);
        return config[keyBytes][srcChainId].set(dstChainId, 1);
    }

    function removeBridgeConfigCache(string memory key, uint256 srcChainId, uint256 dstChainId) internal {
        bytes32 keyBytes = keccak256(abi.encode(key));
        config[keyBytes][srcChainId].remove(dstChainId);
        if (config[keyBytes][srcChainId].length() == 0) srcChainIds[keyBytes].remove(srcChainId);
        if (srcChainIds[keyBytes].length() == 0) keys.remove(keyBytes);
    }

    function bridgeConfigCacheExists(string memory key, uint256 srcChainId, uint256 dstChainId)
        internal
        view
        returns (bool)
    {
        return config[keccak256(abi.encode(key))][srcChainId].contains(dstChainId);
    }

    function getBridgeConfigSrcChainIds(string memory key) internal view returns (uint256[] memory) {
        return srcChainIds[keccak256(abi.encode(key))].values();
    }

    function getBridgeConfigDstChainIds(string memory key, uint256 srcChainId)
        internal
        view
        returns (uint256[] memory)
    {
        return config[keccak256(abi.encode(key))][srcChainId].keys();
    }

    function serializeBridgeConfigCache() internal returns (string memory result) {
        for (uint256 i = 0; i < keys.length(); ++i) {
            bytes32 keyBytes = keys.at(i);
            string memory keyString = keyNames[keyBytes];

            string memory keyJson = "";
            uint256[] memory srcChainIdsArray = srcChainIds[keyBytes].values();

            for (uint256 j = 0; j < srcChainIdsArray.length; ++j) {
                uint256 srcChainId = srcChainIdsArray[j];
                uint256[] memory dstChainIds = config[keyBytes][srcChainId].keys();
                keyJson = vm.serializeUint(keyString, vm.toString(srcChainId), dstChainIds.sort());
            }

            result = vm.serializeString("bridgeConfigCache", keyString, bytes(keyJson).length == 0 ? "{}" : keyJson);
        }

        return result;
    }

    function deserializeBridgeConfigCache(string memory json) internal {
        if (bytes(json).length == 0) return;

        string[] memory jsonKeys = vm.parseJsonKeys(json, "");

        for (uint256 i = 0; i < jsonKeys.length; ++i) {
            string memory key = jsonKeys[i];
            string[] memory srcChainKeys = vm.parseJsonKeys(json, string.concat(".", key));

            for (uint256 j = 0; j < srcChainKeys.length; ++j) {
                uint256 srcChainId = vm.parseUint(srcChainKeys[j]);
                uint256[] memory dstChainIds =
                    json.readUintArrayOr(string.concat(".", key, ".", srcChainKeys[j]), new uint256[](0));

                for (uint256 k = 0; k < dstChainIds.length; ++k) {
                    addBridgeConfigCache(key, srcChainId, dstChainIds[k]);
                }
            }
        }
    }
}

abstract contract ScriptUtils is
    MultisigAddressesLib,
    CoreAddressesLib,
    PeripheryAddressesLib,
    LensAddressesLib,
    BridgeAddressesLib,
    TokenAddressesLib,
    GovernorAddressesLib,
    EulerSwapAddressesLib,
    BridgeConfigCache
{
    MultisigAddresses internal multisigAddresses;
    CoreAddresses internal coreAddresses;
    PeripheryAddresses internal peripheryAddresses;
    LensAddresses internal lensAddresses;
    BridgeAddresses internal bridgeAddresses;
    TokenAddresses internal tokenAddresses;
    GovernorAddresses internal governorAddresses;
    EulerSwapAddresses internal eulerSwapAddresses;
    uint256 internal safeNonce;

    constructor() {
        multisigAddresses = deserializeMultisigAddresses(getAddressesJson("MultisigAddresses.json"));
        coreAddresses = deserializeCoreAddresses(getAddressesJson("CoreAddresses.json"));
        peripheryAddresses = deserializePeripheryAddresses(getAddressesJson("PeripheryAddresses.json"));
        lensAddresses = deserializeLensAddresses(getAddressesJson("LensAddresses.json"));
        bridgeAddresses = deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json"));
        tokenAddresses = deserializeTokenAddresses(getAddressesJson("TokenAddresses.json"));
        governorAddresses = deserializeGovernorAddresses(getAddressesJson("GovernorAddresses.json"));
        eulerSwapAddresses = deserializeEulerSwapAddresses(getAddressesJson("EulerSwapAddresses.json"));
        deserializeBridgeConfigCache(getBridgeConfigCacheJson("BridgeConfigCache.json"));

        address safe = getSafe(false);
        safeNonce = getSafeNonce();
        if (safe != address(0) && safeNonce == 0) {
            SafeUtil util = new SafeUtil();
            safeNonce = util.getNextNonce(safe);
        }
    }

    modifier broadcast() {
        startBroadcast();
        _;
        stopBroadcast();
    }

    modifier broadcastAndSaveAddresses() {
        startBroadcast();
        _;
        stopBroadcast();
        saveAddresses();
    }

    function startBroadcast() internal {
        vm.startBroadcast(getDeployer());
    }

    function stopBroadcast() internal {
        vm.stopBroadcast();
    }

    function saveAddresses() internal {
        vm.writeJson(serializeMultisigAddresses(multisigAddresses), getScriptFilePath("MultisigAddresses_output.json"));
        vm.writeJson(serializeCoreAddresses(coreAddresses), getScriptFilePath("CoreAddresses_output.json"));
        vm.writeJson(
            serializePeripheryAddresses(peripheryAddresses), getScriptFilePath("PeripheryAddresses_output.json")
        );
        vm.writeJson(serializeGovernorAddresses(governorAddresses), getScriptFilePath("GovernorAddresses_output.json"));
        vm.writeJson(serializeTokenAddresses(tokenAddresses), getScriptFilePath("TokenAddresses_output.json"));
        vm.writeJson(serializeLensAddresses(lensAddresses), getScriptFilePath("LensAddresses_output.json"));
        vm.writeJson(
            serializeEulerSwapAddresses(eulerSwapAddresses), getScriptFilePath("EulerSwapAddresses_output.json")
        );
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
                serializeEulerSwapAddresses(eulerSwapAddresses),
                getAddressesFilePath("EulerSwapAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeBridgeAddresses(bridgeAddresses), getAddressesFilePath("BridgeAddresses.json", block.chainid)
            );

            vm.createDir(string.concat(getAddressesDirPath(), "../config/bridge/"), true);
            vm.writeJson(serializeBridgeConfigCache(), getBridgeConfigCacheJsonFilePath("BridgeConfigCache.json"));
        }
    }

    function getWETHAddress() internal view returns (address) {
        if (block.chainid == 1) {
            return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (
            block.chainid == 10 || block.chainid == 130 || block.chainid == 8453 || block.chainid == 1923
                || block.chainid == 480 || block.chainid == 57073 || block.chainid == 60808
        ) {
            return 0x4200000000000000000000000000000000000006;
        } else if (block.chainid == 56) {
            return 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
        } else if (block.chainid == 100) {
            return 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
        } else if (block.chainid == 137) {
            return 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        } else if (block.chainid == 146) {
            return 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b;
        } else if (block.chainid == 42161) {
            return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        } else if (block.chainid == 43114) {
            return 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
        } else if (block.chainid == 80094) {
            return 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
        } else {
            // bitcoin-specific and test networks
            if (
                block.chainid == 30 || block.chainid == 21000000 || block.chainid == 10143 || block.chainid == 80084
                    || block.chainid == 2390 || block.chainid == 998
            ) {
                return address(0);
            }
            // hyperEVM
            if (block.chainid == 999) {
                return address(0);
            }

            // TAC
            if (block.chainid == 239) {
                return address(0);
            }

            // Plasma
            if (block.chainid == 9745) {
                return address(0);
            }

            // Monad
            if (block.chainid == 143) {
                return address(0);
            }

            // Sepolia
            if (block.chainid == 11155111) {
                return address(0);
            }
        }

        revert("getWETHAddress: Unsupported chain");
    }

    function getRecognizedUnitsOfAccount() internal view returns (address[] memory recognizedUnitsOfAccount) {
        address USD = address(840);
        address WETH = getWETHAddress();
        address BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

        if (WETH == address(0)) {
            recognizedUnitsOfAccount = new address[](2);
            recognizedUnitsOfAccount[0] = USD;
            recognizedUnitsOfAccount[1] = BTC;
        } else {
            recognizedUnitsOfAccount = new address[](3);
            recognizedUnitsOfAccount[0] = USD;
            recognizedUnitsOfAccount[1] = WETH;
            recognizedUnitsOfAccount[2] = BTC;
        }
    }

    function getValidAdapter(address base, address quote, string memory provider)
        internal
        view
        returns (address adapter)
    {
        bool isExternalVault = _strEq("ExternalVault|", _substring(provider, 0, bytes("ExternalVault|").length));

        if (isExternalVault) base = IEVault(base).asset();

        address[] memory adapters = OracleLens(lensAddresses.oracleLens).getValidAdapters(base, quote);

        uint256 counter;
        for (uint256 i = 0; i < adapters.length; ++i) {
            string memory resolvedOracleName = resolveOracleName(
                OracleLens(lensAddresses.oracleLens).getOracleInfo(adapters[i], new address[](0), new address[](0))
            );

            if (_strEq(provider, string.concat(isExternalVault ? "ExternalVault|" : "", resolvedOracleName))) {
                adapter = adapters[i];
                ++counter;
            }
        }

        if (adapter == address(0) || counter > 1) {
            if (isExternalVault && bytes(provider).length == bytes("ExternalVault|").length + 42) {
                adapter = _toAddress(_substring(provider, bytes("ExternalVault|").length, type(uint256).max));
                counter = 0;
            } else if (bytes(provider).length == 42) {
                adapter = _toAddress(provider);
                counter = 0;
            }
        }

        if ((adapter == address(0) && bytes(provider).length != bytes("ExternalVault|").length) || counter > 1) {
            console.log("base: %s, quote: %s, provider: %s", base, quote, provider);
            if (adapter == address(0)) revert("getValidAdapters: Adapter not found");
            if (counter > 1) revert("getValidAdapters: Multiple adapters found");
        }
    }

    function isValidOracleRouter(address oracleRouter) internal view returns (bool) {
        return _strEq(EulerRouter(oracleRouter).name(), "EulerRouter");
    }

    function isValidExternalVault(address vault) internal view returns (bool) {
        (bool success, bytes memory result) = vault.staticcall(abi.encodeCall(IEVault(vault).asset, ()));

        if (!success || result.length < 32) return false;

        address asset = abi.decode(result, (address));
        address[] memory validVaults =
            SnapshotRegistry(peripheryAddresses.externalVaultRegistry).getValidAddresses(vault, asset, block.timestamp);

        return validVaults.length == 1 && validVaults[0] == vault;
    }

    function resolveOracleName(OracleDetailedInfo memory oracleInfo) internal pure returns (string memory) {
        if (_strEq(oracleInfo.name, "ChainlinkOracle")) {
            if (isRedstoneClassicOracle(abi.decode(oracleInfo.oracleInfo, (ChainlinkOracleInfo)))) {
                return "RedstoneClassicOracle";
            } else {
                return "ChainlinkOracle";
            }
        } else if (_strEq(oracleInfo.name, "CrossAdapter")) {
            CrossAdapterInfo memory crossOracleInfo = abi.decode(oracleInfo.oracleInfo, (CrossAdapterInfo));
            string memory oracleBaseCrossName = crossOracleInfo.oracleBaseCrossInfo.name;
            string memory oracleCrossQuoteName = crossOracleInfo.oracleCrossQuoteInfo.name;

            if (
                _strEq(oracleBaseCrossName, "ChainlinkOracle")
                    && isRedstoneClassicOracle(
                        abi.decode(crossOracleInfo.oracleBaseCrossInfo.oracleInfo, (ChainlinkOracleInfo))
                    )
            ) {
                oracleBaseCrossName = "RedstoneClassicOracle";
            }

            if (
                _strEq(oracleCrossQuoteName, "ChainlinkOracle")
                    && isRedstoneClassicOracle(
                        abi.decode(crossOracleInfo.oracleCrossQuoteInfo.oracleInfo, (ChainlinkOracleInfo))
                    )
            ) {
                oracleCrossQuoteName = "RedstoneClassicOracle";
            }

            return string.concat("CrossAdapter=", oracleBaseCrossName, "+", oracleCrossQuoteName);
        }

        return oracleInfo.name;
    }

    function isRedstoneClassicOracle(ChainlinkOracleInfo memory chainlinkOracleInfo) internal pure returns (bool) {
        string[] memory strings = new string[](2);
        strings[0] = "Redstone Price Feed";
        strings[1] = "RedStone Price Feed";

        for (uint256 i = 0; i < strings.length; ++i) {
            if (_strEq(_substring(chainlinkOracleInfo.feedDescription, 0, bytes(strings[i]).length), strings[i])) {
                return true;
            }
        }

        return false;
    }

    function encodeAmountCap(address asset, uint256 amountNoDecimals, bool revertOnFailure)
        internal
        view
        returns (uint256)
    {
        if (amountNoDecimals == type(uint256).max) return 0;

        uint256 decimals = ERC20(asset).decimals();
        uint256 scale = amountNoDecimals == 0 ? 0 : Math.log10(amountNoDecimals);
        uint256 result = (
            amountNoDecimals >= 100
                ? (amountNoDecimals / 10 ** (scale - 2)) << 6
                : (amountNoDecimals * 10 ** scale) << 6
        ) | (scale + decimals);

        if (revertOnFailure && decodeAmountCap(uint16(result)) != amountNoDecimals * 10 ** decimals) {
            console.log(
                "expected: %s; actual: %s",
                amountNoDecimals * 10 ** decimals,
                AmountCapLib.resolve(AmountCap.wrap(uint16(result)))
            );
            revert("encodeAmountCap: incorrect encoding");
        }

        return result;
    }

    function encodeAmountCaps(
        address[] storage assets,
        mapping(address => uint256 amountsNoDecimals) storage caps,
        mapping(address => bool) storage encoded
    ) internal {
        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            if (!encoded[asset]) caps[asset] = encodeAmountCap(asset, caps[asset], true);
            encoded[asset] = true;
        }
    }

    function decodeAmountCap(uint16 amountCap) internal pure returns (uint256) {
        return AmountCapLib.resolve(AmountCap.wrap(uint16(amountCap)));
    }

    function isGovernanceOperation(bytes4 selector) internal pure returns (bool) {
        return selector == Governable.transferGovernance.selector || selector == EulerRouter.govSetConfig.selector
            || selector == EulerRouter.govSetResolvedVault.selector || selector == IGovernance.setGovernorAdmin.selector
            || selector == IGovernance.setFeeReceiver.selector || selector == IGovernance.setLTV.selector
            || selector == IGovernance.setMaxLiquidationDiscount.selector
            || selector == IGovernance.setLiquidationCoolOffTime.selector
            || selector == IGovernance.setInterestRateModel.selector || selector == IGovernance.setHookConfig.selector
            || selector == IGovernance.setConfigFlags.selector || selector == IGovernance.setCaps.selector
            || selector == IGovernance.setInterestFee.selector || selector == IGovernance.setGovernorAdmin.selector
            || selector == IGovernance.setGovernorAdmin.selector;
    }

    function isGovernorAccessControlInstance(address target) internal view returns (bool) {
        (bool success, bytes memory result) =
            target.staticcall(abi.encodeCall(GovernorAccessControl.isGovernorAccessControl, ()));

        return success && result.length >= 32
            && abi.decode(result, (bytes4)) == GovernorAccessControl.isGovernorAccessControl.selector;
    }

    function isRiskStewardInstance(address target) internal view returns (bool) {
        (bool success, bytes memory result) = target.staticcall(abi.encodeCall(CapRiskSteward.isCapRiskSteward, ()));

        return
            success && result.length >= 32 && abi.decode(result, (bytes4)) == CapRiskSteward.isCapRiskSteward.selector;
    }
}

abstract contract BatchBuilder is ScriptUtils {
    enum BatchItemType {
        REGULAR,
        CRITICAL
    }

    struct TimelockCall {
        bytes32 id;
        address target;
        uint256 value;
        bytes data;
        bytes32 predecessor;
        bytes32 salt;
        uint256 delay;
    }

    uint256 internal constant TRIGGER_EXECUTE_BATCH_AT_SIZE = 250;
    IEVC.BatchItem[] internal batchItems;
    IEVC.BatchItem[] internal criticalItems;
    uint256 internal batchCounter;
    TimelockCall[] internal timelockCalls;

    function getAppropriateOnBehalfOfAccount() internal view returns (address) {
        address timelock = getTimelock();

        if (timelock != address(0)) {
            return timelock;
        } else if (isBatchViaSafe()) {
            return getSafe();
        } else {
            return getDeployer();
        }
    }

    function addBatchItem(address targetContract, bytes memory data) internal {
        addBatchItem(targetContract, getAppropriateOnBehalfOfAccount(), data);
    }

    function addBatchItem(address targetContract, address onBehalfOfAccount, bytes memory data) internal {
        addBatchItem(targetContract, onBehalfOfAccount, 0, data);
    }

    function addBatchItem(address targetContract, address onBehalfOfAccount, uint256 value, bytes memory data)
        internal
    {
        addItem(BatchItemType.REGULAR, targetContract, onBehalfOfAccount, value, data);
    }

    function addCriticalItem(address targetContract, bytes memory data) internal {
        addCriticalItem(targetContract, getAppropriateOnBehalfOfAccount(), data);
    }

    function addCriticalItem(address targetContract, address onBehalfOfAccount, bytes memory data) internal {
        addCriticalItem(targetContract, onBehalfOfAccount, 0, data);
    }

    function addCriticalItem(address targetContract, address onBehalfOfAccount, uint256 value, bytes memory data)
        internal
    {
        addItem(BatchItemType.CRITICAL, targetContract, onBehalfOfAccount, value, data);
    }

    function addItem(
        BatchItemType itemType,
        address targetContract,
        address onBehalfOfAccount,
        uint256 value,
        bytes memory data
    ) internal {
        IEVC.BatchItem[] storage items;
        if (itemType == BatchItemType.REGULAR) {
            items = batchItems;
        } else {
            items = criticalItems;
        }

        if (isGovernanceOperation(bytes4(data))) {
            address riskSteward = getRiskSteward();
            address governorAdmin;

            if (GenericFactory(coreAddresses.eVaultFactory).isProxy(targetContract)) {
                governorAdmin = IEVault(targetContract).governorAdmin();
            } else if (BaseFactory(peripheryAddresses.oracleRouterFactory).isValidDeployment(targetContract)) {
                governorAdmin = EulerRouter(targetContract).governor();
            }

            if (riskSteward != address(0) && isRiskStewardInstance(riskSteward)) {
                data = abi.encodePacked(data, targetContract);
                targetContract = riskSteward;
            } else if (isGovernorAccessControlInstance(governorAdmin)) {
                data = abi.encodePacked(data, targetContract);
                targetContract = governorAdmin;
            }
        }

        items.push(
            IEVC.BatchItem({
                targetContract: targetContract,
                onBehalfOfAccount: onBehalfOfAccount,
                value: value,
                data: data
            })
        );

        if (batchItems.length >= TRIGGER_EXECUTE_BATCH_AT_SIZE) executeBatch();
    }

    function appendCriticalSectionToBatch() internal {
        if (criticalItems.length == 0) return;

        if (batchItems.length + criticalItems.length >= TRIGGER_EXECUTE_BATCH_AT_SIZE) executeBatch();

        for (uint256 i = 0; i < criticalItems.length; ++i) {
            batchItems.push(criticalItems[i]);
        }

        clearCriticalItems();
    }

    function getBatchItems() internal view returns (IEVC.BatchItem[] memory) {
        return batchItems;
    }

    function clearBatchItems() internal {
        delete batchItems;
    }

    function clearCriticalItems() internal {
        delete criticalItems;
    }

    function getBatchCalldata() internal view returns (bytes memory) {
        return abi.encodeCall(IEVC.batch, (batchItems));
    }

    function getBatchValue() internal view returns (uint256 value) {
        for (uint256 i = 0; i < batchItems.length; ++i) {
            value += batchItems[i].value;
        }
    }

    function getTimelockPredecessor() internal view returns (bytes32) {
        return timelockCalls.length == 0 ? bytes32(0) : timelockCalls[timelockCalls.length - 1].id;
    }

    function executeBatchPrank(address caller) internal {
        if (batchItems.length == 0) return;

        for (uint256 i = 0; i < batchItems.length; ++i) {
            if (
                batchItems[i].onBehalfOfAccount != address(0)
                    && !IEVC(coreAddresses.evc).haveCommonOwner(batchItems[i].onBehalfOfAccount, caller)
                    && !IEVC(coreAddresses.evc).isAccountOperatorAuthorized(batchItems[i].onBehalfOfAccount, caller)
            ) {
                batchItems[i].onBehalfOfAccount = caller;
            }
        }

        vm.prank(caller);
        IEVC(coreAddresses.evc).batch{value: getBatchValue()}(batchItems);

        clearBatchItems();
    }

    function executeBatch() internal {
        if (isBatchViaSafe()) executeBatchViaSafe(true);
        else executeBatchDirectly(false);
        batchCounter++;
    }

    function executeBatchDirectly(bool allowTimelock) internal broadcast {
        if (batchItems.length == 0) return;

        dumpBatch(getDeployer());

        address payable timelock = payable(getTimelock());
        if (timelock == address(0) || !allowTimelock) {
            console.log("Executing the batch directly on the EVC (%s)\n", coreAddresses.evc);
            IEVC(coreAddresses.evc).batch{value: getBatchValue()}(batchItems);
        } else {
            uint256 delay = TimelockController(timelock).getMinDelay();
            uint256 batchValue = getBatchValue();
            bytes memory batchCalldata = getBatchCalldata();
            bytes32 timelockPredecessor = getTimelockPredecessor();
            bytes32 id = TimelockController(timelock).hashOperation(
                coreAddresses.evc, batchValue, batchCalldata, timelockPredecessor, bytes32(0)
            );
            bytes memory data = abi.encodeCall(
                TimelockController.schedule,
                (coreAddresses.evc, batchValue, batchCalldata, timelockPredecessor, bytes32(0), delay)
            );

            console.log("Executing the batch directly on the EVC (%s) via Timelock (%s)\n", coreAddresses.evc, timelock);
            (bool success,) = timelock.call(data);
            require(success, "executeBatchDirectly: timelock execution failed");

            timelockCalls.push(
                TimelockCall({
                    id: id,
                    target: timelock,
                    value: batchValue,
                    data: data,
                    predecessor: timelockPredecessor,
                    salt: bytes32(0),
                    delay: delay
                })
            );

            dumpTimelockCall(timelockCalls.length - 1);

            // simulate timelock execution
            vm.prank(timelock);
            (success,) = coreAddresses.evc.call{value: batchValue}(batchCalldata);
            require(success, "executeBatchDirectly: timelock execution simulation failed");
        }

        clearBatchItems();
    }

    function executeBatchViaSafe(bool allowTimelock) internal {
        if (batchItems.length == 0) return;

        SafeTransaction transaction = new SafeTransaction();
        if (isSkipSafeSimulation() || isEmergency()) transaction.setSimulationOff();

        address safe = getSafe();
        address payable timelock = payable(getTimelock());

        dumpBatch(safe);

        if (timelock == address(0) || !allowTimelock) {
            console.log("Executing the batch via Safe (%s) using the EVC (%s)\n", safe, coreAddresses.evc);
            transaction.create(true, safe, coreAddresses.evc, getBatchValue(), getBatchCalldata(), safeNonce++);
        } else {
            uint256 delay = TimelockController(timelock).getMinDelay();
            uint256 batchValue = getBatchValue();
            bytes memory batchCalldata = getBatchCalldata();
            bytes32 timelockPredecessor = getTimelockPredecessor();
            bytes32 id = TimelockController(timelock).hashOperation(
                coreAddresses.evc, batchValue, batchCalldata, timelockPredecessor, bytes32(0)
            );
            bytes memory data = abi.encodeCall(
                TimelockController.schedule,
                (coreAddresses.evc, batchValue, batchCalldata, timelockPredecessor, bytes32(0), delay)
            );

            console.log(
                "Executing the batch via Safe (%s) using the Timelock (%s) on the EVC (%s)\n",
                safe,
                timelock,
                coreAddresses.evc
            );

            transaction.create(true, safe, timelock, batchValue, data, safeNonce++);

            timelockCalls.push(
                TimelockCall({
                    id: id,
                    target: timelock,
                    value: batchValue,
                    data: data,
                    predecessor: timelockPredecessor,
                    salt: bytes32(0),
                    delay: delay
                })
            );

            dumpTimelockCall(timelockCalls.length - 1);

            // simulate timelock execution
            vm.prank(timelock);
            (bool success,) = coreAddresses.evc.call{value: batchValue}(batchCalldata);
            require(success, "executeBatchViaSafe: timelock execution simulation failed");
        }

        clearBatchItems();
    }

    function dumpBatch(address from) internal {
        string memory path = string.concat(vm.projectRoot(), "/script/Batches.json");
        string memory json = vm.exists(path) ? vm.readFile(path) : "{}";
        string memory key = string.concat("batch", vm.toString(batchCounter));

        json = vm.serializeAddress(key, "from", from);
        json = vm.serializeAddress(key, "to", coreAddresses.evc);
        json = vm.serializeUint(key, "value", getBatchValue());
        json = vm.serializeBytes(key, "data", getBatchCalldata());

        vm.writeJson(vm.serializeString("batches", vm.toString(batchCounter), json), path);
    }

    function dumpTimelockCall(uint256 i) internal {
        require(i < timelockCalls.length, "dumpTimelockCall: incorrect index");

        string memory path = string.concat(vm.projectRoot(), "/script/TimelockCalls.json");
        string memory json = vm.exists(path) ? vm.readFile(path) : "{}";
        string memory key = vm.toString(timelockCalls[i].id);

        json = vm.serializeBytes32(key, "id", timelockCalls[i].id);
        json = vm.serializeAddress(key, "target", timelockCalls[i].target);
        json = vm.serializeUint(key, "value", timelockCalls[i].value);
        json = vm.serializeBytes(key, "data", timelockCalls[i].data);
        json = vm.serializeBytes32(key, "predecessor", timelockCalls[i].predecessor);
        json = vm.serializeBytes32(key, "salt", timelockCalls[i].salt);
        json = vm.serializeUint(key, "delay", timelockCalls[i].delay);

        vm.writeJson(vm.serializeString("timelockCalls", key, json), path);
    }

    function toString(IEVC.BatchItem[] memory items) internal pure returns (string memory) {
        string memory result = "[";
        for (uint256 i = 0; i < items.length; ++i) {
            result = string.concat(result, toString(items[i]));
            if (i < items.length - 1) {
                result = string.concat(result, ",");
            }
        }
        return string.concat(result, "]");
    }

    function toString(IEVC.BatchItem memory item) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "[\"",
                vm.toString(item.targetContract),
                "\",\"",
                vm.toString(item.onBehalfOfAccount),
                "\",",
                vm.toString(item.value),
                ",\"",
                vm.toString(item.data),
                "\"]"
            )
        );
    }

    function grantRole(address accessController, bytes32 role, address account) internal {
        addBatchItem(accessController, abi.encodeCall(AccessControl.grantRole, (role, account)));
    }

    function renounceRole(address accessController, bytes32 role, address account) internal {
        addBatchItem(accessController, abi.encodeCall(AccessControl.renounceRole, (role, account)));
    }

    function transferOwnership(address ownable, address newOwner) internal {
        addBatchItem(ownable, abi.encodeCall(Ownable.transferOwnership, (newOwner)));
    }

    function setWhitelistStatus(address rEUL, address account, uint256 status) internal {
        addBatchItem(rEUL, abi.encodeWithSignature("setWhitelistStatus(address,uint256)", account, status));
    }

    function perspectiveVerify(address perspective, address vault) internal {
        addBatchItem(perspective, abi.encodeCall(BasePerspective.perspectiveVerify, (vault, true)));
    }

    function transferGovernance(address oracleRouter, address newGovernor) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter(oracleRouter).transferGovernance, (newGovernor)));
    }

    function govSetConfig(address oracleRouter, address base, address quote, address oracle) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter.govSetConfig, (base, quote, oracle)));
    }

    function govSetConfig_critical(address oracleRouter, address base, address quote, address oracle) internal {
        addCriticalItem(oracleRouter, abi.encodeCall(EulerRouter.govSetConfig, (base, quote, oracle)));
    }

    function govSetResolvedVault(address oracleRouter, address vault, bool set) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter.govSetResolvedVault, (vault, set)));
    }

    function add(address snapshotRegistry, address element, address base, address quote) internal {
        addBatchItem(snapshotRegistry, abi.encodeCall(SnapshotRegistry.add, (element, base, quote)));
    }

    function revoke(address snapshotRegistry, address element) internal {
        addBatchItem(snapshotRegistry, abi.encodeCall(SnapshotRegistry.revoke, (element)));
    }

    function setGovernorAdmin(address vault, address newGovernorAdmin) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setGovernorAdmin, (newGovernorAdmin)));
    }

    function setFeeReceiver(address vault, address newFeeReceiver) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setFeeReceiver, (newFeeReceiver)));
    }

    function setLTV(address vault, address collateral, uint16 borrowLTV, uint16 liquidationLTV, uint32 rampDuration)
        internal
    {
        addBatchItem(
            vault, abi.encodeCall(IEVault(vault).setLTV, (collateral, borrowLTV, liquidationLTV, rampDuration))
        );
    }

    function setLTV_critical(
        address vault,
        address collateral,
        uint16 borrowLTV,
        uint16 liquidationLTV,
        uint32 rampDuration
    ) internal {
        addCriticalItem(
            vault, abi.encodeCall(IEVault(vault).setLTV, (collateral, borrowLTV, liquidationLTV, rampDuration))
        );
    }

    function setMaxLiquidationDiscount(address vault, uint16 newDiscount) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setMaxLiquidationDiscount, (newDiscount)));
    }

    function setLiquidationCoolOffTime(address vault, uint16 newCoolOffTime) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setLiquidationCoolOffTime, (newCoolOffTime)));
    }

    function setInterestRateModel(address vault, address newModel) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setInterestRateModel, (newModel)));
    }

    function setHookConfig(address vault, address newHookTarget, uint32 newHookedOps) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setHookConfig, (newHookTarget, newHookedOps)));
    }

    function setConfigFlags(address vault, uint32 newConfigFlags) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setConfigFlags, (newConfigFlags)));
    }

    function setCaps(address vault, uint256 supplyCap, uint256 borrowCap) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setCaps, (uint16(supplyCap), uint16(borrowCap))));
    }

    function setInterestFee(address vault, uint16 newInterestFee) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setInterestFee, (newInterestFee)));
    }
}
