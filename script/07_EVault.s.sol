// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {EulerRouterFactory} from "../src/EulerRouterFactory/EulerRouterFactory.sol";

contract EVaultDeployer is ScriptUtils {
    function run() public broadcast returns (address oracleRouter, address eVault) {
        string memory inputScriptFileName = "07_EVault_input.json";
        string memory outputScriptFileName = "07_EVault_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address oracleRouterFactory = abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address));
        bool deployRouterForOracle = abi.decode(vm.parseJson(json, ".deployRouterForOracle"), (bool));
        address eVaultFactory = abi.decode(vm.parseJson(json, ".eVaultFactory"), (address));
        bool upgradable = abi.decode(vm.parseJson(json, ".upgradable"), (bool));
        address asset = abi.decode(vm.parseJson(json, ".asset"), (address));
        address oracle = abi.decode(vm.parseJson(json, ".oracle"), (address));
        address unitOfAccount = abi.decode(vm.parseJson(json, ".unitOfAccount"), (address));

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

contract OracleRouterDeployer is ScriptUtils {
    function run() public broadcast returns (address oracleRouter) {
        string memory inputScriptFileName = "07_OracleRouter_input.json";
        string memory outputScriptFileName = "07_OracleRouter_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address oracleRouterFactory = abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address));

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
