// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {SafeTransaction} from "./SafeUtil.s.sol";
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

    function isBroadcast() internal view returns (bool) {
        return _strEq(vm.envOr("broadcast", string("")), "--broadcast");
    }

    function isBatchViaSafe() internal view returns (bool) {
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

        if (amountNoDecimals == 0) {
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

    function encodeAmountCaps(address[] storage assets, mapping(address => uint256 amountsNoDecimals) storage caps)
        internal
    {
        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            caps[asset] = encodeAmountCap(asset, caps[asset]);
        }
    }
}

abstract contract BatchBuilder is ScriptUtils {
    uint256 internal constant TRIGGER_EXECUTE_BATCH_AT_SIZE = 250;
    IEVC.BatchItem[] internal items;

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
        console.log("Adding batch item");
        console.log("Target: %s", targetContract);
        console.log("OnBehalfOfAccount: %s", onBehalfOfAccount);
        console.log("Value: %s", value);

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

    function executeBatchPrank(address caller, bool clear) internal {
        if (items.length == 0) return;

        console.log("Pranking the batch execution as %s on the EVC (%s)\n", caller, coreAddresses.evc);

        for (uint256 i = 0; i < items.length; ++i) {
            items[i].onBehalfOfAccount = caller;
        }

        vm.prank(caller);
        IEVC(coreAddresses.evc).batch{value: getBatchValue()}(items);

        if (clear) clearBatchItems();
    }

    function executeBatch() internal {
        if (isBatchViaSafe()) executeBatchViaSafe();
        else executeBatchDirectly();
    }

    function executeBatchDirectly() internal broadcast {
        if (items.length == 0) return;

        console.log("Executing the batch directly on the EVC (%s)\n", coreAddresses.evc);
        IEVC(coreAddresses.evc).batch{value: getBatchValue()}(items);
        clearBatchItems();
    }

    function executeBatchViaSafe() internal {
        if (items.length == 0) return;

        address safe = getSafe();
        SafeTransaction transaction =
            new SafeTransaction(getDeployerPK(), safe, coreAddresses.evc, getBatchValue(), getBatchCalldata());

        transaction.simulate();

        console.log("Executing the batch via the Safe (%s) using the EVC (%s)\n", safe, coreAddresses.evc);

        if (isBroadcast()) {
            transaction.execute();
        }

        clearBatchItems();
    }

    function perspectiveVerify(address perspective, address vault) internal {
        addBatchItem(perspective, abi.encodeCall(BasePerspective.perspectiveVerify, (vault, true)));
        console.log("Data decoded: perspectiveVerify(%s, %s)\n", vault, true);
    }

    function transferGovernance(address oracleRouter, address newGovernor) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter(oracleRouter).transferGovernance, (newGovernor)));
        console.log("Data decoded: transferGovernance(%s)\n", newGovernor);
    }

    function govSetConfig(address oracleRouter, address base, address quote, address oracle) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter.govSetConfig, (base, quote, oracle)));
        console.log("Data decoded: govSetConfig(%s, %s, %s)\n", base, quote, oracle);
    }

    function govSetResolvedVault(address oracleRouter, address vault, bool set) internal {
        addBatchItem(oracleRouter, abi.encodeCall(EulerRouter.govSetResolvedVault, (vault, set)));
        console.log("Data decoded: govSetResolvedVault(%s, %s)\n", vault, set);
    }

    function setGovernorAdmin(address vault, address newGovernorAdmin) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setGovernorAdmin, (newGovernorAdmin)));
        console.log("Data decoded: setGovernorAdmin(%s)\n", newGovernorAdmin);
    }

    function setFeeReceiver(address vault, address newFeeReceiver) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setFeeReceiver, (newFeeReceiver)));
        console.log("Data decoded: setFeeReceiver(%s)\n", newFeeReceiver);
    }

    function setLTV(address vault, address collateral, uint16 borrowLTV, uint16 liquidationLTV, uint32 rampDuration)
        internal
    {
        addBatchItem(
            vault, abi.encodeCall(IEVault(vault).setLTV, (collateral, borrowLTV, liquidationLTV, rampDuration))
        );
        console.log("Data decoded: setLTV(%s, %s,", collateral, borrowLTV);
        console.log("%s, %s)\n", liquidationLTV, rampDuration);
    }

    function setMaxLiquidationDiscount(address vault, uint16 newDiscount) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setMaxLiquidationDiscount, (newDiscount)));
        console.log("Data decoded: setMaxLiquidationDiscount(%s)\n", newDiscount);
    }

    function setLiquidationCoolOffTime(address vault, uint16 newCoolOffTime) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setLiquidationCoolOffTime, (newCoolOffTime)));
        console.log("Data decoded: setLiquidationCoolOffTime(%s)\n", newCoolOffTime);
    }

    function setInterestRateModel(address vault, address newModel) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setInterestRateModel, (newModel)));
        console.log("Data decoded: setInterestRateModel(%s)\n", newModel);
    }

    function setHookConfig(address vault, address newHookTarget, uint32 newHookedOps) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setHookConfig, (newHookTarget, newHookedOps)));
        console.log("Data decoded: setHookConfig(%s, %s)\n", newHookTarget, newHookedOps);
    }

    function setConfigFlags(address vault, uint32 newConfigFlags) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setConfigFlags, (newConfigFlags)));
        console.log("Data decoded: setConfigFlags(%s)\n", newConfigFlags);
    }

    function setCaps(address vault, uint256 supplyCap, uint256 borrowCap) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setCaps, (uint16(supplyCap), uint16(borrowCap))));
        console.log("Data decoded: setCaps(%s, %s)\n", supplyCap, borrowCap);
    }

    function setInterestFee(address vault, uint16 newInterestFee) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setInterestFee, (newInterestFee)));
        console.log("Data decoded: setInterestFee(%s)\n", newInterestFee);
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
