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
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";

import "forge-std/console.sol";

abstract contract CoreAddressesLib is Script {
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

    function deserializeCoreAddresses(string memory json) internal pure returns (CoreAddresses memory result) {
        if (bytes(json).length == 0) return result;

        result = CoreAddresses({
            evc: abi.decode(vm.parseJson(json, ".evc"), (address)),
            protocolConfig: abi.decode(vm.parseJson(json, ".protocolConfig"), (address)),
            sequenceRegistry: abi.decode(vm.parseJson(json, ".sequenceRegistry"), (address)),
            balanceTracker: abi.decode(vm.parseJson(json, ".balanceTracker"), (address)),
            permit2: abi.decode(vm.parseJson(json, ".permit2"), (address)),
            eVaultImplementation: abi.decode(vm.parseJson(json, ".eVaultImplementation"), (address)),
            eVaultFactory: abi.decode(vm.parseJson(json, ".eVaultFactory"), (address)),
            eVaultFactoryGovernor: abi.decode(vm.parseJson(json, ".eVaultFactoryGovernor"), (address))
        });
    }
}

abstract contract PeripheryAddressesLib is Script {
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
    }

    function deserializePeripheryAddresses(string memory json)
        internal
        pure
        returns (PeripheryAddresses memory result)
    {
        if (bytes(json).length == 0) return result;

        result = PeripheryAddresses({
            oracleRouterFactory: abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address)),
            oracleAdapterRegistry: abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address)),
            externalVaultRegistry: abi.decode(vm.parseJson(json, ".externalVaultRegistry"), (address)),
            kinkIRMFactory: abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address)),
            irmRegistry: abi.decode(vm.parseJson(json, ".irmRegistry"), (address)),
            swapper: abi.decode(vm.parseJson(json, ".swapper"), (address)),
            swapVerifier: abi.decode(vm.parseJson(json, ".swapVerifier"), (address)),
            feeFlowController: abi.decode(vm.parseJson(json, ".feeFlowController"), (address)),
            evkFactoryPerspective: abi.decode(vm.parseJson(json, ".evkFactoryPerspective"), (address)),
            governedPerspective: abi.decode(vm.parseJson(json, ".governedPerspective"), (address)),
            escrowedCollateralPerspective: abi.decode(vm.parseJson(json, ".escrowedCollateralPerspective"), (address)),
            eulerUngoverned0xPerspective: abi.decode(vm.parseJson(json, ".eulerUngoverned0xPerspective"), (address)),
            eulerUngovernedNzxPerspective: abi.decode(vm.parseJson(json, ".eulerUngovernedNzxPerspective"), (address))
        });
    }
}

abstract contract LensAddressesLib is Script {
    struct LensAddresses {
        address accountLens;
        address oracleLens;
        address irmLens;
        address vaultLens;
        address utilsLens;
    }

    function serializeLensAddresses(LensAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("lensAddresses", "accountLens", Addresses.accountLens);
        result = vm.serializeAddress("lensAddresses", "oracleLens", Addresses.oracleLens);
        result = vm.serializeAddress("lensAddresses", "irmLens", Addresses.irmLens);
        result = vm.serializeAddress("lensAddresses", "vaultLens", Addresses.vaultLens);
        result = vm.serializeAddress("lensAddresses", "utilsLens", Addresses.utilsLens);
    }

    function deserializeLensAddresses(string memory json) internal pure returns (LensAddresses memory result) {
        if (bytes(json).length == 0) return result;

        result = LensAddresses({
            accountLens: abi.decode(vm.parseJson(json, ".accountLens"), (address)),
            oracleLens: abi.decode(vm.parseJson(json, ".oracleLens"), (address)),
            irmLens: abi.decode(vm.parseJson(json, ".irmLens"), (address)),
            vaultLens: abi.decode(vm.parseJson(json, ".vaultLens"), (address)),
            utilsLens: abi.decode(vm.parseJson(json, ".utilsLens"), (address))
        });
    }
}

abstract contract ScriptUtils is Script, CoreAddressesLib, PeripheryAddressesLib, LensAddressesLib {
    CoreAddresses internal coreAddresses;
    PeripheryAddresses internal peripheryAddresses;
    LensAddresses internal lensAddresses;
    IEVC.BatchItem[] private items;

    constructor() {
        coreAddresses = deserializeCoreAddresses(getAddressesJson("CoreAddresses.json"));
        peripheryAddresses = deserializePeripheryAddresses(getAddressesJson("PeripheryAddresses.json"));
        lensAddresses = deserializeLensAddresses(getAddressesJson("LensAddresses.json"));
    }

    modifier broadcast() {
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));
        _;
        vm.stopBroadcast();
    }

    function startBroadcast() internal {
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));
    }

    function stopBroadcast() internal {
        vm.stopBroadcast();
    }

    function getDeployer() internal view virtual returns (address) {
        address deployer = vm.addr(vm.envOr("DEPLOYER_KEY", uint256(1)));
        return deployer == vm.addr(1) ? address(this) : deployer;
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
        if (bytes(addressesDirPath).length == 0) return "";
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

    function encodeAmountCap(address asset, uint16 amountNoDecimals) internal view returns (uint16) {
        uint256 decimals = ERC20(asset).decimals();
        uint16 result;

        if (amountNoDecimals >= 100) {
            uint256 scale = Math.log10(amountNoDecimals);
            result = uint16(((amountNoDecimals / 10 ** (scale - 2)) << 6) | (scale + decimals));
        } else {
            result = uint16((100 * amountNoDecimals << 6) | decimals);
        }

        require(
            AmountCapLib.resolve(AmountCap.wrap(result)) == amountNoDecimals * 10 ** decimals,
            "encodeAmountCap: incorrect encoding"
        );

        return result;
    }

    function encodeAmountCaps(address[] storage assets, uint16[] storage amountsNoDecimals)
        internal
        view
        returns (uint16[] memory)
    {
        require(
            assets.length == amountsNoDecimals.length,
            "encodeAmountCaps: assets and amountsNoDecimals must have the same length"
        );

        uint16[] memory result = new uint16[](assets.length);
        for (uint256 i = 0; i < assets.length; ++i) {
            result[i] = encodeAmountCap(assets[i], amountsNoDecimals[i]);
        }
        return result;
    }
}

abstract contract BatchBuilder is ScriptUtils {
    IEVC.BatchItem[] internal items;

    function addBatchItem(address targetContract, bytes memory data) internal {
        addBatchItem(targetContract, getDeployer(), data);
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
    }

    function clearBatchItems() internal {
        delete items;
    }

    function getBatchCalldata() internal view returns (bytes memory) {
        return abi.encodeCall(IEVC.batch, (items));
    }

    function executeBatch() internal broadcast {
        IEVC(coreAddresses.evc).batch(items);
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

    function setCaps(address vault, uint16 supplyCap, uint16 borrowCap) internal {
        addBatchItem(vault, abi.encodeCall(IEVault(vault).setCaps, (supplyCap, borrowCap)));
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
