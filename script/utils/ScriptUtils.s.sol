// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ScriptUtils is Script {
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

    function getDeployer() internal view returns (address) {
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
}

contract CoreAddressesLib is Script {
    struct CoreAddresses {
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address eVaultImplementation;
        address eVaultFactory;
    }

    function serializeCoreAddresses(CoreAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("coreAddresses", "evc", Addresses.evc);
        result = vm.serializeAddress("coreAddresses", "protocolConfig", Addresses.protocolConfig);
        result = vm.serializeAddress("coreAddresses", "sequenceRegistry", Addresses.sequenceRegistry);
        result = vm.serializeAddress("coreAddresses", "balanceTracker", Addresses.balanceTracker);
        result = vm.serializeAddress("coreAddresses", "permit2", Addresses.permit2);
        result = vm.serializeAddress("coreAddresses", "eVaultImplementation", Addresses.eVaultImplementation);
        result = vm.serializeAddress("coreAddresses", "eVaultFactory", Addresses.eVaultFactory);
    }

    function deserializeCoreAddresses(string memory json) internal pure returns (CoreAddresses memory) {
        return CoreAddresses({
            evc: abi.decode(vm.parseJson(json, ".evc"), (address)),
            protocolConfig: abi.decode(vm.parseJson(json, ".protocolConfig"), (address)),
            sequenceRegistry: abi.decode(vm.parseJson(json, ".sequenceRegistry"), (address)),
            balanceTracker: abi.decode(vm.parseJson(json, ".balanceTracker"), (address)),
            permit2: abi.decode(vm.parseJson(json, ".permit2"), (address)),
            eVaultImplementation: abi.decode(vm.parseJson(json, ".eVaultImplementation"), (address)),
            eVaultFactory: abi.decode(vm.parseJson(json, ".eVaultFactory"), (address))
        });
    }
}

contract PeripheryAddressesLib is Script {
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

    function deserializePeripheryAddresses(string memory json) internal pure returns (PeripheryAddresses memory) {
        return PeripheryAddresses({
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

contract LensAddressesLib is Script {
    struct LensAddresses {
        address accountLens;
        address oracleLens;
        address vaultLens;
        address utilsLens;
    }

    function serializeLensAddresses(LensAddresses memory Addresses) internal returns (string memory result) {
        result = vm.serializeAddress("lensAddresses", "accountLens", Addresses.accountLens);
        result = vm.serializeAddress("lensAddresses", "oracleLens", Addresses.oracleLens);
        result = vm.serializeAddress("lensAddresses", "vaultLens", Addresses.vaultLens);
        result = vm.serializeAddress("lensAddresses", "utilsLens", Addresses.utilsLens);
    }

    function deserializeLensAddresses(string memory json) internal pure returns (LensAddresses memory) {
        return LensAddresses({
            accountLens: abi.decode(vm.parseJson(json, ".accountLens"), (address)),
            oracleLens: abi.decode(vm.parseJson(json, ".oracleLens"), (address)),
            vaultLens: abi.decode(vm.parseJson(json, ".vaultLens"), (address)),
            utilsLens: abi.decode(vm.parseJson(json, ".utilsLens"), (address))
        });
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
