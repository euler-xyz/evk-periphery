// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {BalanceForwarder} from "evk/EVault/modules/BalanceForwarder.sol";
import {Borrowing} from "evk/EVault/modules/Borrowing.sol";
import {Governance} from "evk/EVault/modules/Governance.sol";
import {Initialize} from "evk/EVault/modules/Initialize.sol";
import {Liquidation} from "evk/EVault/modules/Liquidation.sol";
import {RiskManager} from "evk/EVault/modules/RiskManager.sol";
import {Token} from "evk/EVault/modules/Token.sol";
import {Vault} from "evk/EVault/modules/Vault.sol";
import {Dispatch} from "evk/EVault/Dispatch.sol";
import {EVault} from "evk/EVault/EVault.sol";

contract EVaultImplementation is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address moduleBalanceForwarder,
            address moduleBorrowing,
            address moduleGovernance,
            address moduleInitialize,
            address moduleLiquidation,
            address moduleRiskManager,
            address moduleToken,
            address moduleVault,
            address implementation
        )
    {
        Base.Integrations memory integrations;
        string memory scriptFileName = "05_EVaultImplementation.json";
        string memory json = getInputConfig(scriptFileName);
        integrations.evc = abi.decode(vm.parseJson(json, ".evc"), (address));
        integrations.protocolConfig = abi.decode(vm.parseJson(json, ".protocolConfig"), (address));
        integrations.sequenceRegistry = abi.decode(vm.parseJson(json, ".sequenceRegistry"), (address));
        integrations.balanceTracker = abi.decode(vm.parseJson(json, ".balanceTracker"), (address));
        integrations.permit2 = abi.decode(vm.parseJson(json, ".permit2"), (address));

        Dispatch.DeployedModules memory modules;
        (modules, implementation) = execute(integrations);

        moduleBalanceForwarder = modules.balanceForwarder;
        moduleBorrowing = modules.borrowing;
        moduleGovernance = modules.governance;
        moduleInitialize = modules.initialize;
        moduleLiquidation = modules.liquidation;
        moduleRiskManager = modules.riskManager;
        moduleToken = modules.token;
        moduleVault = modules.vault;

        string memory object;
        object = vm.serializeAddress("", "eVaultImplementation", implementation);
        object = vm.serializeAddress("modules", "balanceForwarder", modules.balanceForwarder);
        object = vm.serializeAddress("modules", "borrowing", modules.borrowing);
        object = vm.serializeAddress("modules", "governance", modules.governance);
        object = vm.serializeAddress("modules", "initialize", modules.initialize);
        object = vm.serializeAddress("modules", "liquidation", modules.liquidation);
        object = vm.serializeAddress("modules", "riskManager", modules.riskManager);
        object = vm.serializeAddress("modules", "token", modules.token);
        object = vm.serializeAddress("modules", "vault", modules.vault);

        vm.writeJson(
            vm.serializeString("", "modules", object),
            string.concat(vm.projectRoot(), "/script/output/", scriptFileName)
        );
    }

    function deploy(Base.Integrations memory integrations)
        public
        broadcast
        returns (Dispatch.DeployedModules memory modules, address implementation)
    {
        (modules, implementation) = execute(integrations);
    }

    function execute(Base.Integrations memory integrations)
        public
        returns (Dispatch.DeployedModules memory modules, address implementation)
    {
        modules = Dispatch.DeployedModules({
            balanceForwarder: address(new BalanceForwarder(integrations)),
            borrowing: address(new Borrowing(integrations)),
            governance: address(new Governance(integrations)),
            initialize: address(new Initialize(integrations)),
            liquidation: address(new Liquidation(integrations)),
            riskManager: address(new RiskManager(integrations)),
            token: address(new Token(integrations)),
            vault: address(new Vault(integrations))
        });

        implementation = address(new EVault(integrations, modules));
    }
}
