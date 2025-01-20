// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {EulerRouterFactory} from "../src/EulerRouterFactory/EulerRouterFactory.sol";
import {EscrowedCollateralPerspective} from "../src/Perspectives/deployed/EscrowedCollateralPerspective.sol";

contract EVaultDeployer is ScriptUtils {
    function run() public broadcast returns (address oracleRouter, address eVault) {
        string memory inputScriptFileName = "07_EVault_input.json";
        string memory outputScriptFileName = "07_EVault_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address oracleRouterFactory = vm.parseJsonAddress(json, ".oracleRouterFactory");
        bool deployRouterForOracle = vm.parseJsonBool(json, ".deployRouterForOracle");
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        bool upgradable = vm.parseJsonBool(json, ".upgradable");
        address asset = vm.parseJsonAddress(json, ".asset");
        address oracle = vm.parseJsonAddress(json, ".oracle");
        address unitOfAccount = vm.parseJsonAddress(json, ".unitOfAccount");

        (oracleRouter, eVault) =
            execute(oracleRouterFactory, deployRouterForOracle, eVaultFactory, upgradable, asset, oracle, unitOfAccount);

        string memory object;
        if (deployRouterForOracle) {
            object = vm.serializeAddress("eVault", "oracleRouter", oracleRouter);
        }
        object = vm.serializeAddress("eVault", "eVault", eVault);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address oracleRouterFactory,
        bool deployRouterForOracle,
        address eVaultFactory,
        bool upgradable,
        address asset,
        address oracle,
        address unitOfAccount
    ) public broadcast returns (address oracleRouter, address eVault) {
        (oracleRouter, eVault) =
            execute(oracleRouterFactory, deployRouterForOracle, eVaultFactory, upgradable, asset, oracle, unitOfAccount);
    }

    function deploy(address eVaultFactory, bool upgradable, address asset, address oracle, address unitOfAccount)
        public
        broadcast
        returns (address eVault)
    {
        (, eVault) = execute(address(0), false, eVaultFactory, upgradable, asset, oracle, unitOfAccount);
    }

    function deploy(address eVaultFactory, bool upgradable, address asset) public broadcast returns (address eVault) {
        (, eVault) = execute(address(0), false, eVaultFactory, upgradable, asset, address(0), address(0));
    }

    function execute(
        address oracleRouterFactory,
        bool deployRouterForOracle,
        address eVaultFactory,
        bool upgradable,
        address asset,
        address oracle,
        address unitOfAccount
    ) public returns (address oracleRouter, address eVault) {
        if (deployRouterForOracle) {
            EulerRouter _oracleRouter = EulerRouter(EulerRouterFactory(oracleRouterFactory).deploy(getDeployer()));
            _oracleRouter.govSetConfig(asset, unitOfAccount, oracle);
            oracleRouter = address(_oracleRouter);
        }

        eVault = address(
            GenericFactory(eVaultFactory).createProxy(
                address(0),
                upgradable,
                abi.encodePacked(asset, deployRouterForOracle ? oracleRouter : oracle, unitOfAccount)
            )
        );
    }
}

contract EVaultSingletonEscrowDeployer is ScriptUtils {
    function run() public broadcast returns (address eVault) {
        string memory inputScriptFileName = "07_EVaultSingletonEscrow_input.json";
        string memory outputScriptFileName = "07_EVaultSingletonEscrow_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address escrowedCollateralPerspective = vm.parseJsonAddress(json, ".escrowedCollateralPerspective");
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address asset = vm.parseJsonAddress(json, ".asset");

        eVault = execute(evc, escrowedCollateralPerspective, eVaultFactory, asset);

        string memory object;
        object = vm.serializeAddress("eVault", "eVaultSingletonEscrow", eVault);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address escrowedCollateralPerspective, address eVaultFactory, address asset)
        public
        broadcast
        returns (address eVault)
    {
        eVault = execute(evc, escrowedCollateralPerspective, eVaultFactory, asset);
    }

    function execute(address evc, address escrowedCollateralPerspective, address eVaultFactory, address asset)
        public
        returns (address eVault)
    {
        eVault = EscrowedCollateralPerspective(escrowedCollateralPerspective).singletonLookup(asset);

        if (eVault == address(0)) {
            eVault = address(
                GenericFactory(eVaultFactory).createProxy(
                    address(0), true, abi.encodePacked(asset, address(0), address(0))
                )
            );

            address deployer = getDeployer();
            IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);
            items[0] = IEVC.BatchItem({
                targetContract: eVault,
                onBehalfOfAccount: deployer,
                value: 0,
                data: abi.encodeCall(IEVault(eVault).setHookConfig, (address(0), 0))
            });
            items[1] = IEVC.BatchItem({
                targetContract: eVault,
                onBehalfOfAccount: deployer,
                value: 0,
                data: abi.encodeCall(IEVault(eVault).setGovernorAdmin, (address(0)))
            });
            items[2] = IEVC.BatchItem({
                targetContract: escrowedCollateralPerspective,
                onBehalfOfAccount: deployer,
                value: 0,
                data: abi.encodeCall(
                    EscrowedCollateralPerspective(escrowedCollateralPerspective).perspectiveVerify, (eVault, true)
                )
            });
            IEVC(evc).batch(items);
        }
    }
}

contract OracleRouterDeployer is ScriptUtils {
    function run() public broadcast returns (address oracleRouter) {
        string memory inputScriptFileName = "07_OracleRouter_input.json";
        string memory outputScriptFileName = "07_OracleRouter_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address oracleRouterFactory = vm.parseJsonAddress(json, ".oracleRouterFactory");

        oracleRouter = execute(oracleRouterFactory);

        string memory object;
        object = vm.serializeAddress("oracleRouter", "oracleRouter", oracleRouter);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address oracleRouterFactory) public broadcast returns (address oracleRouter) {
        oracleRouter = execute(oracleRouterFactory);
    }

    function execute(address oracleRouterFactory) public returns (address oracleRouter) {
        oracleRouter = EulerRouterFactory(oracleRouterFactory).deploy(getDeployer());
    }
}
