// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {IEulerEarn} from "euler-earn/interface/IEulerEarn.sol";

struct IntegrationsParams {
    address evc;
    address balanceTracker;
    address permit2;
    bool isHarvestCoolDownCheckOn;
}

contract EulerEarnImplementation is ScriptUtils {
    function run()
        public
        broadcast
        returns (
            address moduleEulerEarnVault,
            address moduleRewards,
            address moduleHooks,
            address moduleFee,
            address moduleStrategy,
            address moduleWithdrawalQueue,
            address implementation
        )
    {
        IntegrationsParams memory integrations;
        string memory inputScriptFileName = "20_EulerEarnImplementation_input.json";
        string memory outputScriptFileName = "20_EulerEarnImplementation_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        integrations.evc = vm.parseJsonAddress(json, ".evc");
        integrations.balanceTracker = vm.parseJsonAddress(json, ".balanceTracker");
        integrations.permit2 = vm.parseJsonAddress(json, ".permit2");
        integrations.isHarvestCoolDownCheckOn = vm.parseJsonBool(json, ".isHarvestCoolDownCheckOn");

        IEulerEarn.DeploymentParams memory deploymentParams;
        (deploymentParams, implementation) = execute(integrations);

        moduleEulerEarnVault = deploymentParams.eulerEarnVaultModule;
        moduleRewards = deploymentParams.rewardsModule;
        moduleHooks = deploymentParams.hooksModule;
        moduleFee = deploymentParams.feeModule;
        moduleStrategy = deploymentParams.strategyModule;
        moduleWithdrawalQueue = deploymentParams.withdrawalQueueModule;

        string memory object;
        object = vm.serializeAddress("", "eulerEarnImplementation", implementation);
        object = vm.serializeAddress("modules", "eulerEarnVault", moduleEulerEarnVault);
        object = vm.serializeAddress("modules", "rewards", moduleRewards);
        object = vm.serializeAddress("modules", "hooks", moduleHooks);
        object = vm.serializeAddress("modules", "fee", moduleFee);
        object = vm.serializeAddress("modules", "strategy", moduleStrategy);
        object = vm.serializeAddress("modules", "withdrawalQueue", moduleWithdrawalQueue);

        vm.writeJson(
            vm.serializeString("", "modules", object), string.concat(vm.projectRoot(), "/script/", outputScriptFileName)
        );
    }

    function deploy(IntegrationsParams memory integrations)
        public
        broadcast
        returns (IEulerEarn.DeploymentParams memory deploymentParams, address implementation)
    {
        (deploymentParams, implementation) = execute(integrations);
    }

    function execute(IntegrationsParams memory integrations)
        public
        returns (IEulerEarn.DeploymentParams memory deploymentParams, address implementation)
    {
        address module;
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-earn/EulerEarnVault.sol/EulerEarnVault.json"), abi.encode(integrations)
        );
        assembly {
            module := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        deploymentParams.eulerEarnVaultModule = module;

        bytecode = abi.encodePacked(vm.getCode("out-euler-earn/Rewards.sol/Rewards.json"), abi.encode(integrations));
        assembly {
            module := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        deploymentParams.rewardsModule = module;

        bytecode = abi.encodePacked(vm.getCode("out-euler-earn/Hooks.sol/Hooks.json"), abi.encode(integrations));
        assembly {
            module := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        deploymentParams.hooksModule = module;

        bytecode = abi.encodePacked(vm.getCode("out-euler-earn/Fee.sol/Fee.json"), abi.encode(integrations));
        assembly {
            module := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        deploymentParams.feeModule = module;

        bytecode = abi.encodePacked(vm.getCode("out-euler-earn/Strategy.sol/Strategy.json"), abi.encode(integrations));
        assembly {
            module := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        deploymentParams.strategyModule = module;

        bytecode = abi.encodePacked(
            vm.getCode("out-euler-earn/WithdrawalQueue.sol/WithdrawalQueue.json"), abi.encode(integrations)
        );
        assembly {
            module := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        deploymentParams.withdrawalQueueModule = module;

        bytecode = abi.encodePacked(
            vm.getCode("out-euler-earn/EulerEarn.sol/EulerEarn.json"), abi.encode(integrations, deploymentParams)
        );
        assembly {
            implementation := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
