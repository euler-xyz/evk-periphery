// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {GovernorAccessControlEmergency} from "../Governor/GovernorAccessControlEmergency.sol";
import {IGovernorAccessControlEmergencyFactory} from "./interfaces/IGovernorAccessControlEmergencyFactory.sol";

/// @title GovernorAccessControlEmergencyFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A factory for governor access control emergency contract configured with timelock controllers.
contract GovernorAccessControlEmergencyFactory is BaseFactory, IGovernorAccessControlEmergencyFactory {
    /// @notice The minimum delay that can be set for a timelock controller
    uint256 public constant MIN_MIN_DELAY = 1 days;

    /// @notice The EVC address used to deploy the governor access control emergency contract
    address public immutable evc;

    event GovernorAccessControlEmergencySuiteDeployed(
        address indexed adminTimelockController,
        address indexed wildcardTimelockController,
        address indexed governorAccessControlEmergency
    );

    /// @notice Thrown when a critical address parameter is zero
    error InvalidAddress();

    /// @notice Thrown when the provided minimum delay is less than the required minimum delay or when the admin
    /// timelock delay is less than the wildcard timelock delay
    error InvalidMinDelay();

    /// @notice Thrown when no proposers are provided for a timelock controller
    error InvalidProposers();

    /// @notice Thrown when no executors are provided for a timelock controller
    error InvalidExecutors();

    /// @notice Initializes the factory with the EVC address
    /// @param _evc The address of the Ethereum Vault Connector (EVC) contract
    constructor(address _evc) {
        if (_evc == address(0)) revert InvalidAddress();
        evc = _evc;
    }

    /// @notice Deploys a new governor contracts suite.
    /// @param adminTimelockControllerParams The parameters for the admin timelock controller.
    /// @param wildcardTimelockControllerParams The parameters for the wildcard timelock controller.
    /// @param governorAccessControlEmergencyGuardians The addresses that will be granted emergency roles
    /// @return adminTimelockController The address of the admin timelock controller.
    /// @return wildcardTimelockController The address of the wildcard timelock controller.
    /// @return governorAccessControlEmergency The address of the governor access control emergency contract.
    function deploy(
        TimelockControllerParams memory adminTimelockControllerParams,
        TimelockControllerParams memory wildcardTimelockControllerParams,
        address[] memory governorAccessControlEmergencyGuardians
    ) external override returns (address, address, address) {
        if (
            adminTimelockControllerParams.minDelay < MIN_MIN_DELAY
                || wildcardTimelockControllerParams.minDelay < MIN_MIN_DELAY
                || adminTimelockControllerParams.minDelay < wildcardTimelockControllerParams.minDelay
        ) revert InvalidMinDelay();

        if (
            adminTimelockControllerParams.proposers.length == 0
                || wildcardTimelockControllerParams.proposers.length == 0
        ) revert InvalidProposers();

        if (
            adminTimelockControllerParams.executors.length == 0
                || wildcardTimelockControllerParams.executors.length == 0
        ) revert InvalidExecutors();

        TimelockController adminTimelockController = new TimelockController(
            adminTimelockControllerParams.minDelay, new address[](0), new address[](0), address(this)
        );

        TimelockController wildcardTimelockController = new TimelockController(
            wildcardTimelockControllerParams.minDelay, new address[](0), new address[](0), address(this)
        );

        GovernorAccessControlEmergency governorAccessControlEmergency =
            new GovernorAccessControlEmergency(evc, address(this));

        {
            bytes32 proposerRole = adminTimelockController.PROPOSER_ROLE();
            for (uint256 i = 0; i < adminTimelockControllerParams.proposers.length; ++i) {
                adminTimelockController.grantRole(proposerRole, adminTimelockControllerParams.proposers[i]);
            }

            bytes32 cancellerRole = adminTimelockController.CANCELLER_ROLE();
            for (uint256 i = 0; i < adminTimelockControllerParams.cancellers.length; ++i) {
                adminTimelockController.grantRole(cancellerRole, adminTimelockControllerParams.cancellers[i]);
            }

            bytes32 executorRole = adminTimelockController.EXECUTOR_ROLE();
            for (uint256 i = 0; i < adminTimelockControllerParams.executors.length; ++i) {
                adminTimelockController.grantRole(executorRole, adminTimelockControllerParams.executors[i]);
            }

            adminTimelockController.renounceRole(adminTimelockController.DEFAULT_ADMIN_ROLE(), address(this));
        }

        {
            bytes32 proposerRole = wildcardTimelockController.PROPOSER_ROLE();
            for (uint256 i = 0; i < wildcardTimelockControllerParams.proposers.length; ++i) {
                wildcardTimelockController.grantRole(proposerRole, wildcardTimelockControllerParams.proposers[i]);
            }

            bytes32 cancellerRole = wildcardTimelockController.CANCELLER_ROLE();
            for (uint256 i = 0; i < wildcardTimelockControllerParams.cancellers.length; ++i) {
                wildcardTimelockController.grantRole(cancellerRole, wildcardTimelockControllerParams.cancellers[i]);
            }

            bytes32 executorRole = wildcardTimelockController.EXECUTOR_ROLE();
            for (uint256 i = 0; i < wildcardTimelockControllerParams.executors.length; ++i) {
                wildcardTimelockController.grantRole(executorRole, wildcardTimelockControllerParams.executors[i]);
            }

            wildcardTimelockController.renounceRole(wildcardTimelockController.DEFAULT_ADMIN_ROLE(), address(this));
        }

        {
            governorAccessControlEmergency.grantRole(
                governorAccessControlEmergency.DEFAULT_ADMIN_ROLE(), address(adminTimelockController)
            );
            governorAccessControlEmergency.grantRole(
                governorAccessControlEmergency.WILD_CARD(), address(wildcardTimelockController)
            );

            bytes32 ltvEmergencyRole = governorAccessControlEmergency.LTV_EMERGENCY_ROLE();
            bytes32 hookEmergencyRole = governorAccessControlEmergency.HOOK_EMERGENCY_ROLE();
            bytes32 capsEmergencyRole = governorAccessControlEmergency.CAPS_EMERGENCY_ROLE();

            for (uint256 i = 0; i < governorAccessControlEmergencyGuardians.length; ++i) {
                governorAccessControlEmergency.grantRole(ltvEmergencyRole, governorAccessControlEmergencyGuardians[i]);
                governorAccessControlEmergency.grantRole(hookEmergencyRole, governorAccessControlEmergencyGuardians[i]);
                governorAccessControlEmergency.grantRole(capsEmergencyRole, governorAccessControlEmergencyGuardians[i]);
            }

            governorAccessControlEmergency.renounceRole(
                governorAccessControlEmergency.DEFAULT_ADMIN_ROLE(), address(this)
            );
        }

        emit GovernorAccessControlEmergencySuiteDeployed(
            address(adminTimelockController),
            address(wildcardTimelockController),
            address(governorAccessControlEmergency)
        );

        deploymentInfo[address(governorAccessControlEmergency)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(governorAccessControlEmergency));
        emit ContractDeployed(address(governorAccessControlEmergency), msg.sender, block.timestamp);

        return (
            address(adminTimelockController),
            address(wildcardTimelockController),
            address(governorAccessControlEmergency)
        );
    }
}
