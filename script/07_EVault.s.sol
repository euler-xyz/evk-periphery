// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EulerRouterFactory} from "../src/OracleFactory/EulerRouterFactory.sol";
import {IEulerRouter} from "../src/OracleFactory/interfaces/IEulerRouter.sol";

contract EVault is ScriptUtils {
    function run() public startBroadcast returns (address oracleRouter, address eVault) {
        string memory scriptFileName = "07_EVault.json";
        string memory json = getInputConfig(scriptFileName);
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
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address oracleRouterFactory,
        bool deployRouterForOracle,
        address eVaultFactory,
        bool upgradable,
        address asset,
        address oracle,
        address unitOfAccount
    ) public returns (address oracleRouter, address eVault) {
        (oracleRouter, eVault) =
            execute(oracleRouterFactory, deployRouterForOracle, eVaultFactory, upgradable, asset, oracle, unitOfAccount);
    }

    function execute(
        address oracleRouterFactory,
        bool deployRouterForOracle,
        address eVaultFactory,
        bool upgradable,
        address asset,
        address oracle,
        address unitOfAccount
    ) internal returns (address oracleRouter, address eVault) {
        if (deployRouterForOracle) {
            IEulerRouter _oracleRouter = IEulerRouter(EulerRouterFactory(oracleRouterFactory).deploy(getDeployer()));
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
