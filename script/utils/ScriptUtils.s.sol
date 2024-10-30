// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {ScriptExtended} from "./ScriptExtended.s.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault, IGovernance} from "evk/EVault/IEVault.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {SafeTransaction} from "./SafeUtils.s.sol";
import {SnapshotRegistry} from "../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {OracleLens} from "../../src/Lens/OracleLens.sol";
import {GovernorAccessControl} from "../../src/Governor/GovernorAccessControl.sol";
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
        startBroadcast();
        _;
        stopBroadcast();
    }

    function startBroadcast() internal {
        vm.startBroadcast(getDeployer());
    }

    function stopBroadcast() internal {
        vm.stopBroadcast();
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
        bool isExternalVault = isValidExternalVault(base);

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
            if (bytes(provider).length == 42) return _stringToAddress(provider);

            console.log("base: %s, quote: %s, provider: %s", base, quote, provider);

            if (adapter == address(0)) revert("getValidAdapters: Adapter not found");
            if (counter > 1) revert("getValidAdapters: Multiple adapters found");
        }
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
        if (_strEq(chainlinkOracleInfo.feedDescription, "Redstone Price Feed")) {
            return true;
        }
        return false;
    }

    function encodeAmountCap(address asset, uint256 amountNoDecimals) internal view returns (uint256) {
        if (amountNoDecimals == type(uint256).max) return 0;

        uint256 decimals = ERC20(asset).decimals();
        uint256 scale = amountNoDecimals == 0 ? 0 : Math.log10(amountNoDecimals);
        uint256 result = (
            amountNoDecimals >= 100
                ? (amountNoDecimals / 10 ** (scale - 2)) << 6
                : (amountNoDecimals * 10 ** scale) << 6
        ) | (scale + decimals);

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

    function encodeAmountCaps(address[] storage assets, mapping(address => uint256 amountsNoDecimals) storage caps)
        internal
    {
        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            caps[asset] = encodeAmountCap(asset, caps[asset]);
        }
    }

    function isGovernanceOperation(bytes4 selector) internal pure returns (bool) {
        return selector == IGovernance.setGovernorAdmin.selector || selector == IGovernance.setFeeReceiver.selector
            || selector == IGovernance.setLTV.selector || selector == IGovernance.setMaxLiquidationDiscount.selector
            || selector == IGovernance.setLiquidationCoolOffTime.selector
            || selector == IGovernance.setInterestRateModel.selector || selector == IGovernance.setHookConfig.selector
            || selector == IGovernance.setConfigFlags.selector || selector == IGovernance.setCaps.selector
            || selector == IGovernance.setInterestFee.selector || selector == IGovernance.setGovernorAdmin.selector
            || selector == IGovernance.setGovernorAdmin.selector;
    }

    function isGovernorAccessControlInstance(address governorAdmin) internal view returns (bool) {
        (bool success, bytes memory result) =
            governorAdmin.staticcall(abi.encodeCall(GovernorAccessControl.isGovernorAccessControl, ()));

        return success && result.length >= 32
            && abi.decode(result, (bytes4)) == GovernorAccessControl.isGovernorAccessControl.selector;
    }
}

abstract contract BatchBuilder is ScriptUtils {
    enum BatchItemType {
        REGULAR,
        CRITICAL
    }

    uint256 internal constant TRIGGER_EXECUTE_BATCH_AT_SIZE = 250;
    IEVC.BatchItem[] internal batchItems;
    IEVC.BatchItem[] internal criticalItems;
    uint256 internal batchCounter;
    uint256 internal currentSafeNonce = getSafeCurrentNonce();

    function addBatchItem(address targetContract, bytes memory data) internal {
        address onBehalfOfAccount = isBatchViaSafe() ? getSafe() : getDeployer();
        addBatchItem(targetContract, onBehalfOfAccount, data);
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
        address onBehalfOfAccount = isBatchViaSafe() ? getSafe() : getDeployer();
        addCriticalItem(targetContract, onBehalfOfAccount, data);
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

        if (isGovernanceOperation(bytes4(data)) && GenericFactory(coreAddresses.eVaultFactory).isProxy(targetContract))
        {
            address governorAdmin = IEVault(targetContract).governorAdmin();

            if (isGovernorAccessControlInstance(governorAdmin)) {
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

    function executeBatchPrank(address caller) internal {
        if (batchItems.length == 0) return;

        console.log("Pranking the batch execution as %s on the EVC (%s)\n", caller, coreAddresses.evc);

        for (uint256 i = 0; i < batchItems.length; ++i) {
            batchItems[i].onBehalfOfAccount = caller;
        }

        vm.prank(caller);
        IEVC(coreAddresses.evc).batch{value: getBatchValue()}(batchItems);

        clearBatchItems();
    }

    function executeBatch() internal {
        if (isBatchViaSafe()) executeBatchViaSafe();
        else executeBatchDirectly();
    }

    function executeBatchDirectly() internal broadcast {
        if (batchItems.length == 0) return;

        console.log("Executing the batch directly on the EVC (%s)\n", coreAddresses.evc);
        dumpBatch(getDeployer());

        IEVC(coreAddresses.evc).batch{value: getBatchValue()}(batchItems);
        clearBatchItems();
    }

    function executeBatchViaSafe() internal {
        if (batchItems.length == 0) return;

        address safe = getSafe();
        console.log("Executing the batch via the Safe (%s) using the EVC (%s)\n", safe, coreAddresses.evc);
        dumpBatch(safe);

        SafeTransaction transaction = new SafeTransaction();

        if (currentSafeNonce == 0) currentSafeNonce = transaction.getNonce(safe);

        transaction.create(safe, coreAddresses.evc, getBatchValue(), getBatchCalldata(), ++currentSafeNonce);

        clearBatchItems();
    }

    function dumpBatch(address from) internal {
        string memory path = string.concat(vm.projectRoot(), "/script/Batches.json");
        string memory json = vm.exists(path) ? vm.readFile(path) : "{}";
        string memory key = vm.toString(batchCounter++);

        json = vm.serializeAddress(key, "from", from);
        json = vm.serializeAddress(key, "to", coreAddresses.evc);
        json = vm.serializeUint(key, "value", getBatchValue());
        json = vm.serializeBytes(key, "data", getBatchCalldata());

        vm.writeJson(vm.serializeString("", key, json), path);
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

contract StubOracle {
    string public name = "StubOracle";

    function getQuote(uint256, address, address) external pure returns (uint256) {
        return 0;
    }

    function getQuotes(uint256, address, address) external pure returns (uint256, uint256) {
        return (0, 0);
    }
}
