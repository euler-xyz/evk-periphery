// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerRouterFactory} from "../src/EulerRouterFactory/EulerRouterFactory.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerKinkyIRMFactory} from "../src/IRMFactory/EulerKinkyIRMFactory.sol";
import {EulerFixedCyclicalBinaryIRMFactory} from "../src/IRMFactory/EulerFixedCyclicalBinaryIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";
import {GovernorAccessControlEmergencyFactoryV2} from
    "../src/GovernorFactory/GovernorAccessControlEmergencyFactoryV2.sol";
import {CapRiskStewardFactory} from "../src/GovernorFactory/CapRiskStewardFactory.sol";

contract PeripheryFactories is ScriptUtils {
    struct PeripheryContracts {
        address oracleRouterFactory;
        address kinkIRMFactory;
        address kinkyIRMFactory;
        address fixedCyclicalBinaryIRMFactory;
        address adaptiveCurveIRMFactory;
        address governorAccessControlEmergencyFactoryV2;
        address capRiskStewardFactory;
    }

    function run() public broadcast returns (PeripheryContracts memory deployedContracts) {
        string memory inputScriptFileName = "02_PeripheryFactories_input.json";
        string memory outputScriptFileName = "02_PeripheryFactories_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        deployedContracts = execute(evc);

        string memory object;
        object = vm.serializeAddress("peripheryFactories", "oracleRouterFactory", deployedContracts.oracleRouterFactory);
        object = vm.serializeAddress("peripheryFactories", "kinkIRMFactory", deployedContracts.kinkIRMFactory);
        object = vm.serializeAddress("peripheryFactories", "kinkyIRMFactory", deployedContracts.kinkyIRMFactory);
        object = vm.serializeAddress(
            "peripheryFactories", "fixedCyclicalBinaryIRMFactory", deployedContracts.fixedCyclicalBinaryIRMFactory
        );
        object = vm.serializeAddress(
            "peripheryFactories", "adaptiveCurveIRMFactory", deployedContracts.adaptiveCurveIRMFactory
        );
        object = vm.serializeAddress(
            "peripheryFactories",
            "governorAccessControlEmergencyFactoryV2",
            deployedContracts.governorAccessControlEmergencyFactoryV2
        );
        object =
            vm.serializeAddress("peripheryFactories", "capRiskStewardFactory", deployedContracts.capRiskStewardFactory);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc) public broadcast returns (PeripheryContracts memory deployedContracts) {
        deployedContracts = execute(evc);
    }

    function deployMissing(address evc, PeripheryContracts memory existingContracts)
        public
        broadcast
        returns (PeripheryContracts memory deployedContracts)
    {
        deployedContracts = execute(evc, existingContracts);
    }

    function execute(address evc) public returns (PeripheryContracts memory deployedContracts) {
        return execute(evc, deployedContracts);
    }

    /// @dev Deploys only the contracts left unset in `existingContracts`. Members are independent except for
    /// capRiskStewardFactory, which is deployed last so it can reference the resolved governor and kink IRM factories,
    /// and is also redeployed when it accepts governors from a different governor factory.
    function execute(address evc, PeripheryContracts memory existingContracts)
        public
        returns (PeripheryContracts memory deployedContracts)
    {
        deployedContracts = existingContracts;

        if (deployedContracts.oracleRouterFactory == address(0)) {
            deployedContracts.oracleRouterFactory = address(new EulerRouterFactory(evc));
        }
        if (deployedContracts.kinkIRMFactory == address(0)) {
            deployedContracts.kinkIRMFactory = address(new EulerKinkIRMFactory());
        }
        if (deployedContracts.kinkyIRMFactory == address(0)) {
            deployedContracts.kinkyIRMFactory = address(new EulerKinkyIRMFactory());
        }
        if (deployedContracts.fixedCyclicalBinaryIRMFactory == address(0)) {
            deployedContracts.fixedCyclicalBinaryIRMFactory = address(new EulerFixedCyclicalBinaryIRMFactory());
        }
        if (deployedContracts.adaptiveCurveIRMFactory == address(0)) {
            deployedContracts.adaptiveCurveIRMFactory = address(new EulerIRMAdaptiveCurveFactory());
        }
        if (deployedContracts.governorAccessControlEmergencyFactoryV2 == address(0)) {
            deployedContracts.governorAccessControlEmergencyFactoryV2 =
                deployGovernorAccessControlEmergencyFactoryV2(evc);
        }
        if (
            !isCapRiskStewardFactoryBoundTo(
                deployedContracts.capRiskStewardFactory, deployedContracts.governorAccessControlEmergencyFactoryV2
            )
        ) {
            deployedContracts.capRiskStewardFactory = address(
                new CapRiskStewardFactory(
                    deployedContracts.governorAccessControlEmergencyFactoryV2, deployedContracts.kinkIRMFactory
                )
            );
        }
    }

    /// @dev At the default 20,000 optimizer runs the factory exceeds the 24,576-byte code size limit, so deployments
    /// use the 10,000-run build that interactiveDeployment.sh compiles into out-governor-factory. Without that build,
    /// the default one is deployed, which only works where the code size limit is not enforced.
    function deployGovernorAccessControlEmergencyFactoryV2(address evc) internal returns (address factory) {
        string memory artifact =
            "out-governor-factory/GovernorAccessControlEmergencyFactoryV2.sol/GovernorAccessControlEmergencyFactoryV2.json";
        bytes memory bytecode = abi.encodePacked(
            vm.isFile(artifact) ? vm.getCode(artifact) : type(GovernorAccessControlEmergencyFactoryV2).creationCode,
            abi.encode(evc)
        );

        assembly {
            factory := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(factory != address(0), "GovernorAccessControlEmergencyFactoryV2 deployment failed");
    }
}

/// @notice Whether `capRiskStewardFactory` deploys risk stewards for governors of `governorFactory`.
/// @dev Early CapRiskStewardFactory versions have no `governorAccessControlFactory()` getter.
function isCapRiskStewardFactoryBoundTo(address capRiskStewardFactory, address governorFactory) view returns (bool) {
    (bool success, bytes memory result) =
        capRiskStewardFactory.staticcall(abi.encodeWithSignature("governorAccessControlFactory()"));

    return success && result.length == 32 && abi.decode(result, (address)) == governorFactory;
}
