// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {OracleLens} from "../../src/Lens/OracleLens.sol";
import "../../src/Lens/LensTypes.sol";

abstract contract ScriptExtended is Script {
    function getAddressFromJson(string memory json, string memory key) internal pure returns (address) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            return abi.decode(data, (address));
        } catch {
            revert(string(abi.encodePacked("getAddressFromJson: failed to parse JSON for key: ", key)));
        }
    }

    function getAddressesFromJson(string memory json, string memory key) internal pure returns (address[] memory) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            return abi.decode(data, (address[]));
        } catch {
            revert(string(abi.encodePacked("getAddressesFromJson: failed to parse JSON for key: ", key)));
        }
    }

    function _strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

abstract contract CoreAddressesLib is ScriptExtended {
    struct CoreAddresses {
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address eVaultImplementation;
        address eVaultFactory;
        address eVaultFactoryGovernor;
    }

    function serializeCoreAddresses(CoreAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("coreAddresses", "evc", Addresses.evc);
        result = vm.serializeAddress("coreAddresses", "protocolConfig", Addresses.protocolConfig);
        result = vm.serializeAddress("coreAddresses", "sequenceRegistry", Addresses.sequenceRegistry);
        result = vm.serializeAddress("coreAddresses", "balanceTracker", Addresses.balanceTracker);
        result = vm.serializeAddress("coreAddresses", "permit2", Addresses.permit2);
        result = vm.serializeAddress("coreAddresses", "eVaultImplementation", Addresses.eVaultImplementation);
        result = vm.serializeAddress("coreAddresses", "eVaultFactory", Addresses.eVaultFactory);
        result = vm.serializeAddress("coreAddresses", "eVaultFactoryGovernor", Addresses.eVaultFactoryGovernor);
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
            eVaultFactoryGovernor: getAddressFromJson(json, ".eVaultFactoryGovernor")
        });
    }
}

abstract contract PeripheryAddressesLib is ScriptExtended {
    struct PeripheryAddresses {
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address irmRegistry;
        address swapper;
        address swapVerifier;
        address feeFlowController;
        address evkFactoryPerspective;
        address governedPerspective;
        address escrowedCollateralPerspective;
        address eulerUngoverned0xPerspective;
        address eulerUngovernedNzxPerspective;
        address termsOfUseSigner;
    }

    function serializePeripheryAddresses(PeripheryAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("peripheryAddresses", "oracleRouterFactory", Addresses.oracleRouterFactory);
        result = vm.serializeAddress("peripheryAddresses", "oracleAdapterRegistry", Addresses.oracleAdapterRegistry);
        result = vm.serializeAddress("peripheryAddresses", "externalVaultRegistry", Addresses.externalVaultRegistry);
        result = vm.serializeAddress("peripheryAddresses", "kinkIRMFactory", Addresses.kinkIRMFactory);
        result = vm.serializeAddress("peripheryAddresses", "irmRegistry", Addresses.irmRegistry);
        result = vm.serializeAddress("peripheryAddresses", "swapper", Addresses.swapper);
        result = vm.serializeAddress("peripheryAddresses", "swapVerifier", Addresses.swapVerifier);
        result = vm.serializeAddress("peripheryAddresses", "feeFlowController", Addresses.feeFlowController);
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
        result = vm.serializeAddress("peripheryAddresses", "termsOfUseSigner", Addresses.termsOfUseSigner);
    }

    function deserializePeripheryAddresses(string memory json) internal pure returns (PeripheryAddresses memory) {
        return PeripheryAddresses({
            oracleRouterFactory: getAddressFromJson(json, ".oracleRouterFactory"),
            oracleAdapterRegistry: getAddressFromJson(json, ".oracleAdapterRegistry"),
            externalVaultRegistry: getAddressFromJson(json, ".externalVaultRegistry"),
            kinkIRMFactory: getAddressFromJson(json, ".kinkIRMFactory"),
            irmRegistry: getAddressFromJson(json, ".irmRegistry"),
            swapper: getAddressFromJson(json, ".swapper"),
            swapVerifier: getAddressFromJson(json, ".swapVerifier"),
            feeFlowController: getAddressFromJson(json, ".feeFlowController"),
            evkFactoryPerspective: getAddressFromJson(json, ".evkFactoryPerspective"),
            governedPerspective: getAddressFromJson(json, ".governedPerspective"),
            escrowedCollateralPerspective: getAddressFromJson(json, ".escrowedCollateralPerspective"),
            eulerUngoverned0xPerspective: getAddressFromJson(json, ".eulerUngoverned0xPerspective"),
            eulerUngovernedNzxPerspective: getAddressFromJson(json, ".eulerUngovernedNzxPerspective"),
            termsOfUseSigner: getAddressFromJson(json, ".termsOfUseSigner")
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

abstract contract ScriptUtils is CoreAddressesLib, PeripheryAddressesLib, LensAddressesLib {
    CoreAddresses internal coreAddresses;
    PeripheryAddresses internal peripheryAddresses;
    LensAddresses internal lensAddresses;

    constructor() {
        coreAddresses = deserializeCoreAddresses(getAddressesJson("CoreAddresses.json"));
        peripheryAddresses = deserializePeripheryAddresses(getAddressesJson("PeripheryAddresses.json"));
        lensAddresses = deserializeLensAddresses(getAddressesJson("LensAddresses.json"));
    }

    modifier broadcast() {
        vm.startBroadcast(getDeployerPK());
        _;
        vm.stopBroadcast();
    }

    function startBroadcast() internal {
        vm.startBroadcast(getDeployerPK());
    }

    function stopBroadcast() internal {
        vm.stopBroadcast();
    }

    function getDeployerPK() internal view returns (uint256) {
        return vm.envUint("DEPLOYER_KEY");
    }

    function getDeployer() internal view returns (address) {
        address deployer = vm.addr(vm.envOr("DEPLOYER_KEY", uint256(1)));
        return deployer == vm.addr(1) ? address(this) : deployer;
    }

    function getSafe() internal view returns (address) {
        return vm.envAddress("SAFE_ADDRESS");
    }

    function getBroadcast() internal view returns (bool) {
        return _strEq(vm.envOr("broadcast", string("")), "--broadcast");
    }

    function getBatchViaSafe() internal view returns (bool) {
        return _strEq(vm.envOr("batch_via_safe", string("")), "--batch-via-safe");
    }

    function getInputConfigFilePath(string memory jsonFile) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/script/", jsonFile);
    }

    function getInputConfig(string memory jsonFile) internal view returns (string memory) {
        return vm.readFile(getInputConfigFilePath(jsonFile));
    }

    function getAddressesJson(string memory jsonFile) internal view returns (string memory) {
        string memory addressesDirPath = vm.envOr("ADDRESSES_DIR_PATH", string(""));

        if (bytes(addressesDirPath).length == 0) {
            revert("getAddressesJson: ADDRESSES_DIR_PATH environment variable is not set");
        }

        return vm.readFile(string.concat(addressesDirPath, "/", jsonFile));
    }

    function getWETHAddress() internal view returns (address) {
        if (block.chainid == 1) {
            return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (block.chainid == 42161) {
            return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        } else {
            revert("getWETHAddress: Unsupported chain");
        }
    }

    function getValidAdapter(address base, address quote, string memory provider)
        internal
        view
        returns (address adapter)
    {
        address[] memory adapters = OracleLens(lensAddresses.oracleLens).getValidAdapters(base, quote);

        uint256 counter;
        for (uint256 i = 0; i < adapters.length; ++i) {
            string memory resolvedOracleName = resolveOracleName(
                OracleLens(lensAddresses.oracleLens).getOracleInfo(adapters[i], new address[](0), new address[](0))
            );

            if (_strEq(provider, resolvedOracleName)) {
                adapter = adapters[i];
                ++counter;
            }
        }

        // fixme to be removed
        if (adapter == address(0)) {
            return address(0);
        }

        if (adapter == address(0) || counter > 1) {
            console.log("base: %s, quote: %s, provider: %s", base, quote, provider);

            if (adapter == address(0)) revert("getValidAdapters: Adapter not found");
            if (counter > 1) revert("getValidAdapters: Multiple adapters found");
        }
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

            return string(abi.encodePacked("CrossAdapter=", oracleBaseCrossName, "+", oracleCrossQuoteName));
        }

        return oracleInfo.name;
    }

    function isRedstoneClassicOracle(ChainlinkOracleInfo memory chainlinkOracleInfo) internal pure returns (bool) {
        if (_strEq(chainlinkOracleInfo.feedDescription, "Redstone Price Feed")) {
            return true;
        }
        return false;
    }

    function encodeAmountCap(address asset, uint256 amountNoDecimals) internal view returns (uint256) {
        uint256 decimals = ERC20(asset).decimals();
        uint256 result;

        if (amountNoDecimals == type(uint256).max) {
            return 0;
        } else if (amountNoDecimals >= 100) {
            uint256 scale = Math.log10(amountNoDecimals);
            result = ((amountNoDecimals / 10 ** (scale - 2)) << 6) | (scale + decimals);
        } else {
            result = (100 * amountNoDecimals << 6) | decimals;
        }

        if (AmountCapLib.resolve(AmountCap.wrap(uint16(result))) != amountNoDecimals * 10 ** decimals) {
            console.log(
                "expected: %s; actual: %s",
                amountNoDecimals * 10 ** decimals,
                AmountCapLib.resolve(AmountCap.wrap(uint16(result)))
            );
            revert("encodeAmountCap: incorrect encoding");
        }

        return result;
    }

    function encodeAmountCaps(address[] storage assets, uint256[] storage amountsNoDecimals)
        internal
        view
        returns (uint256[] memory)
    {
        require(
            assets.length == amountsNoDecimals.length,
            "encodeAmountCaps: assets and amountsNoDecimals must have the same length"
        );

        uint256[] memory result = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; ++i) {
            result[i] = encodeAmountCap(assets[i], amountsNoDecimals[i]);
        }
        return result;
    }
}

// inspired by https://github.com/ind-igo/forge-safe
contract SafeTransaction is ScriptExtended {
    using Surl for *;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct SafeTx {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
        bytes32 txHash;
        bytes signature;
    }

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256
    // gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    // );
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    address public sender;
    address public safe;
    SafeTx internal transaction;

    constructor(uint256 privateKey, address _safe, address target, uint256 value, bytes memory data) {
        sender = vm.addr(privateKey);
        safe = _safe;

        transaction.to = target;
        transaction.value = value;
        transaction.data = data;
        transaction.operation = Operation.CALL;
        transaction.safeTxGas = 0;
        transaction.baseGas = 0;
        transaction.gasPrice = 0;
        transaction.gasToken = address(0);
        transaction.refundReceiver = address(0);
        transaction.nonce = _getNonce();
        transaction.txHash = _getTransactionHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, transaction.txHash);
        transaction.signature = abi.encodePacked(r, s, v);
    }

    function getTransaction() external view returns (SafeTx memory) {
        return transaction;
    }

    function simulate() external {
        vm.prank(safe);
        (bool success, bytes memory result) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, string(result));
    }

    function execute() external {
        string memory payload = "";
        payload = vm.serializeAddress("payload", "safe", safe);
        payload = vm.serializeAddress("payload", "to", transaction.to);
        payload = vm.serializeUint("payload", "value", transaction.value);
        payload = vm.serializeBytes("payload", "data", transaction.data);
        payload = vm.serializeUint("payload", "operation", uint256(transaction.operation));
        payload = vm.serializeUint("payload", "safeTxGas", transaction.safeTxGas);
        payload = vm.serializeUint("payload", "baseGas", transaction.baseGas);
        payload = vm.serializeUint("payload", "gasPrice", transaction.gasPrice);
        payload = vm.serializeAddress("payload", "gasToken", transaction.gasToken);
        payload = vm.serializeAddress("payload", "refundReceiver", transaction.refundReceiver);
        payload = vm.serializeUint("payload", "nonce", transaction.nonce);
        payload = vm.serializeBytes32("payload", "contractTransactionHash", transaction.txHash);
        payload = vm.serializeBytes("payload", "signature", transaction.signature);
        payload = vm.serializeAddress("payload", "sender", sender);

        string memory endpoint =
            string(abi.encodePacked(_getSafeAPIBaseURL(), vm.toString(safe), "/multisig-transactions/"));
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";

        (uint256 status, bytes memory response) = endpoint.post(headers, payload);

        if (status == 201) {
            console.log("Safe transaction sent successfully");
        } else {
            console.log(string(response));
            revert("Safe transaction failed!");
        }
    }

    function _getTransactionHash() private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, safe)),
                keccak256(
                    abi.encode(
                        SAFE_TX_TYPEHASH,
                        transaction.to,
                        transaction.value,
                        keccak256(transaction.data),
                        transaction.operation,
                        transaction.safeTxGas,
                        transaction.baseGas,
                        transaction.gasPrice,
                        transaction.gasToken,
                        transaction.refundReceiver,
                        transaction.nonce
                    )
                )
            )
        );
    }

    function _getNonce() private returns (uint256) {
        string memory endpoint =
            string(abi.encodePacked(_getSafeAPIBaseURL(), vm.toString(safe), "/multisig-transactions/?limit=1"));

        (uint256 status, bytes memory response) = endpoint.get();
        if (status == 200) {
            return abi.decode(vm.parseJson(string(response), ".results"), (string[])).length == 0
                ? 0
                : abi.decode(vm.parseJson(string(response), ".results[0].nonce"), (uint256)) + 1;
        } else {
            revert("getNonce: Failed to get nonce");
        }
    }

    function _getSafeAPIBaseURL() private view returns (string memory) {
        if (block.chainid == 1) {
            return "https://safe-transaction-mainnet.safe.global/api/v1/safes/";
        } else if (block.chainid == 5) {
            return "https://safe-transaction-goerli.safe.global/api/v1/safes/";
        } else if (block.chainid == 8453) {
            return "https://safe-transaction-base.safe.global/api/v1/safes/";
        } else if (block.chainid == 42161) {
            return "https://safe-transaction-arbitrum.safe.global/api/v1/safes/";
        } else if (block.chainid == 43114) {
            return "https://safe-transaction-avalanche.safe.global/api/v1/safes/";
        } else {
            revert("getSafeAPIBaseURL: Unsupported chain");
        }
    }
}

abstract contract BatchBuilder is ScriptUtils {
    uint256 internal constant TRIGGER_EXECUTE_BATCH_AT_SIZE = 250;
    IEVC.BatchItem[] internal items;

    function addBatchItem(address targetContract, bytes memory data) internal {
        address onBehalfOfAccount = getBatchViaSafe() ? getSafe() : getDeployer();
        addBatchItem(targetContract, onBehalfOfAccount, data);
    }

    function addBatchItem(address targetContract, address onBehalfOfAccount, bytes memory data) internal {
        addBatchItem(targetContract, onBehalfOfAccount, 0, data);
    }

    function addBatchItem(address targetContract, address onBehalfOfAccount, uint256 value, bytes memory data)
        internal
    {
        items.push(
            IEVC.BatchItem({
                targetContract: targetContract,
                onBehalfOfAccount: onBehalfOfAccount,
                value: value,
                data: data
            })
        );

        if (items.length >= TRIGGER_EXECUTE_BATCH_AT_SIZE) executeBatch();
    }

    function clearBatchItems() internal {
        delete items;
    }

    function getBatchCalldata() internal view returns (bytes memory) {
        return abi.encodeCall(IEVC.batch, (items));
    }

    function getBatchValue() internal view returns (uint256 value) {
        for (uint256 i = 0; i < items.length; ++i) {
            value += items[i].value;
        }
    }

    function executeBatch() internal {
        if (getBatchViaSafe()) executeBatchViaSafe();
        else executeBatchDirectly();
    }

    function executeBatchDirectly() internal broadcast {
        if (items.length == 0) return;
        IEVC(coreAddresses.evc).batch{value: getBatchValue()}(items);
        clearBatchItems();
    }

    function executeBatchViaSafe() internal {
        if (items.length == 0) return;

        SafeTransaction transaction =
            new SafeTransaction(getDeployerPK(), getSafe(), coreAddresses.evc, getBatchValue(), getBatchCalldata());

        transaction.simulate();

        if (getBroadcast()) {
            transaction.execute();
        }

        clearBatchItems();
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

    function govSetResolvedVault(address oracleRouter, address vault, bool set) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter.govSetResolvedVault, (vault, set)));
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

contract ERC20Mintable is Ownable, ERC20 {
    uint8 internal immutable _decimals;

    constructor(address owner, string memory name_, string memory symbol_, uint8 decimals_)
        Ownable(owner)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
