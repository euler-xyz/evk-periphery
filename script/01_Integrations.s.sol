// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {SequenceRegistry} from "evk/SequenceRegistry/SequenceRegistry.sol";
import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

contract Integrations is ScriptUtils {
    address internal constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function run()
        public
        broadcast
        returns (address evc, address protocolConfig, address sequenceRegistry, address balanceTracker, address permit2)
    {
        string memory outputScriptFileName = "01_Integrations_output.json";

        (evc, protocolConfig, sequenceRegistry, balanceTracker, permit2) = execute();

        string memory object;
        object = vm.serializeAddress("integrations", "evc", evc);
        object = vm.serializeAddress("integrations", "protocolConfig", protocolConfig);
        object = vm.serializeAddress("integrations", "sequenceRegistry", sequenceRegistry);
        object = vm.serializeAddress("integrations", "balanceTracker", balanceTracker);
        object = vm.serializeAddress("integrations", "permit2", permit2);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy()
        public
        broadcast
        returns (address evc, address protocolConfig, address sequenceRegistry, address balanceTracker, address permit2)
    {
        (evc, protocolConfig, sequenceRegistry, balanceTracker, permit2) = execute();
    }

    function execute()
        public
        returns (address evc, address protocolConfig, address sequenceRegistry, address balanceTracker, address permit2)
    {
        address deployer = getDeployer();

        evc = address(new EthereumVaultConnector());
        protocolConfig = address(new ProtocolConfig(deployer, deployer));
        sequenceRegistry = address(new SequenceRegistry());
        balanceTracker = address(new TrackingRewardStreams(evc, 14 days));
        permit2 = PERMIT2_ADDRESS;

        if (permit2.code.length == 0) {
            DeployPermit2 deployPermit2 = new DeployPermit2();
            deployPermit2.deployPermit2();
        }
    }
}
