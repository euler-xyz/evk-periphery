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

    function getInputConfig(string memory jsonFile) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/", jsonFile);
        return vm.readFile(configPath);
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

contract CoreInfoLib is Script {
    struct CoreInfo {
        address evc;
        address protocolConfig;
        address sequenceRegistry;
        address balanceTracker;
        address permit2;
        address oracleRouterFactory;
        address oracleAdapterRegistry;
        address externalVaultRegistry;
        address kinkIRMFactory;
        address irmRegistry;
        address eVaultImplementation;
        address eVaultFactory;
        address accountLens;
        address oracleLens;
        address vaultLens;
        address utilsLens;
        address governableWhitelistPerspective;
        address escrowPerspective;
        address eulerBasePerspective;
        address eulerFactoryPerspective;
        address swapper;
        address swapVerifier;
        address feeFlowController;
    }

    function serializeCoreInfo(CoreInfo memory info) internal returns (string memory result) {
        result = vm.serializeAddress("coreInfo", "evc", info.evc);
        result = vm.serializeAddress("coreInfo", "protocolConfig", info.protocolConfig);
        result = vm.serializeAddress("coreInfo", "sequenceRegistry", info.sequenceRegistry);
        result = vm.serializeAddress("coreInfo", "balanceTracker", info.balanceTracker);
        result = vm.serializeAddress("coreInfo", "permit2", info.permit2);
        result = vm.serializeAddress("coreInfo", "oracleRouterFactory", info.oracleRouterFactory);
        result = vm.serializeAddress("coreInfo", "oracleAdapterRegistry", info.oracleAdapterRegistry);
        result = vm.serializeAddress("coreInfo", "externalVaultRegistry", info.externalVaultRegistry);
        result = vm.serializeAddress("coreInfo", "kinkIRMFactory", info.kinkIRMFactory);
        result = vm.serializeAddress("coreInfo", "irmRegistry", info.irmRegistry);
        result = vm.serializeAddress("coreInfo", "eVaultImplementation", info.eVaultImplementation);
        result = vm.serializeAddress("coreInfo", "eVaultFactory", info.eVaultFactory);
        result = vm.serializeAddress("coreInfo", "accountLens", info.accountLens);
        result = vm.serializeAddress("coreInfo", "oracleLens", info.oracleLens);
        result = vm.serializeAddress("coreInfo", "vaultLens", info.vaultLens);
        result = vm.serializeAddress("coreInfo", "utilsLens", info.utilsLens);
        result = vm.serializeAddress("coreInfo", "governableWhitelistPerspective", info.governableWhitelistPerspective);
        result = vm.serializeAddress("coreInfo", "escrowPerspective", info.escrowPerspective);
        result = vm.serializeAddress("coreInfo", "eulerBasePerspective", info.eulerBasePerspective);
        result = vm.serializeAddress("coreInfo", "eulerFactoryPerspective", info.eulerFactoryPerspective);
        result = vm.serializeAddress("coreInfo", "swapper", info.swapper);
        result = vm.serializeAddress("coreInfo", "swapVerifier", info.swapVerifier);
        result = vm.serializeAddress("coreInfo", "feeFlowController", info.feeFlowController);
    }

    function deserializeCoreInfo(string memory json) internal pure returns (CoreInfo memory) {
        return CoreInfo({
            evc: abi.decode(vm.parseJson(json, ".evc"), (address)),
            protocolConfig: abi.decode(vm.parseJson(json, ".protocolConfig"), (address)),
            sequenceRegistry: abi.decode(vm.parseJson(json, ".sequenceRegistry"), (address)),
            balanceTracker: abi.decode(vm.parseJson(json, ".balanceTracker"), (address)),
            permit2: abi.decode(vm.parseJson(json, ".permit2"), (address)),
            oracleRouterFactory: abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address)),
            oracleAdapterRegistry: abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address)),
            externalVaultRegistry: abi.decode(vm.parseJson(json, ".externalVaultRegistry"), (address)),
            kinkIRMFactory: abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address)),
            irmRegistry: abi.decode(vm.parseJson(json, ".irmRegistry"), (address)),
            eVaultImplementation: abi.decode(vm.parseJson(json, ".eVaultImplementation"), (address)),
            eVaultFactory: abi.decode(vm.parseJson(json, ".eVaultFactory"), (address)),
            accountLens: abi.decode(vm.parseJson(json, ".accountLens"), (address)),
            oracleLens: abi.decode(vm.parseJson(json, ".oracleLens"), (address)),
            vaultLens: abi.decode(vm.parseJson(json, ".vaultLens"), (address)),
            utilsLens: abi.decode(vm.parseJson(json, ".utilsLens"), (address)),
            governableWhitelistPerspective: abi.decode(vm.parseJson(json, ".governableWhitelistPerspective"), (address)),
            escrowPerspective: abi.decode(vm.parseJson(json, ".escrowPerspective"), (address)),
            eulerBasePerspective: abi.decode(vm.parseJson(json, ".eulerBasePerspective"), (address)),
            eulerFactoryPerspective: abi.decode(vm.parseJson(json, ".eulerFactoryPerspective"), (address)),
            swapper: abi.decode(vm.parseJson(json, ".swapper"), (address)),
            swapVerifier: abi.decode(vm.parseJson(json, ".swapVerifier"), (address)),
            feeFlowController: abi.decode(vm.parseJson(json, ".feeFlowController"), (address))
        });
    }
}
