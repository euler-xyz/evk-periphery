// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {GovernorAccessControlEmergencyFactory} from
    "../../src/GovernorFactory/GovernorAccessControlEmergencyFactory.sol";
import {IGovernorAccessControlEmergencyFactory} from
    "../../src/GovernorFactory/interfaces/IGovernorAccessControlEmergencyFactory.sol";
import {GovernorAccessControlEmergency} from "../../src/Governor/GovernorAccessControlEmergency.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";

contract GovernorAccessControlEmergencyFactoryTests is Test {
    GovernorAccessControlEmergencyFactory governorAccessControlEmergencyFactory;
    address evc;
    address user1;
    address user2;
    address user3;

    function setUp() public {
        evc = makeAddr("evc");
        governorAccessControlEmergencyFactory = new GovernorAccessControlEmergencyFactory(evc);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
    }

    // Test function to verify that the factory reverts when a zero address is passed for EVC
    function test_revert_zeroEVCAddress() external {
        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidAddress.selector);
        new GovernorAccessControlEmergencyFactory(address(0));
    }

    // Test admin minDelay too low
    function test_deployAdminMinDelayTooLow(uint256 adminMinDelay) external {
        // Bound adminMinDelay to be less than the minimum required (1 day)
        adminMinDelay = bound(adminMinDelay, 0, governorAccessControlEmergencyFactory.MIN_MIN_DELAY() - 1);

        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory emptyArray = new address[](0);
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: adminMinDelay,
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidMinDelay.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test wildcard minDelay too low
    function test_deployWildcardMinDelayTooLow(uint256 wildcardMinDelay) external {
        // Bound wildcardMinDelay to be less than the minimum required (1 day)
        wildcardMinDelay = bound(wildcardMinDelay, 0, governorAccessControlEmergencyFactory.MIN_MIN_DELAY() - 1);

        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory emptyArray = new address[](0);
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: wildcardMinDelay,
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidMinDelay.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test admin minDelay < wildcard minDelay
    function test_deployAdminMinDelayLessThanWildcard() external {
        uint256 adminMinDelay = governorAccessControlEmergencyFactory.MIN_MIN_DELAY();
        uint256 wildcardMinDelay = adminMinDelay + 1;

        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory emptyArray = new address[](0);
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: adminMinDelay,
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: wildcardMinDelay,
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidMinDelay.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test empty admin proposers array
    function test_deployEmptyAdminProposers() external {
        address[] memory emptyArray = new address[](0);
        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: emptyArray,
            cancellers: emptyArray,
            executors: emptyArray
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidProposers.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test empty wildcard proposers array
    function test_deployEmptyWildcardProposers() external {
        address[] memory emptyArray = new address[](0);
        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: emptyArray,
            cancellers: emptyArray,
            executors: emptyArray
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidProposers.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test empty admin executors array
    function test_deployEmptyAdminExecutors() external {
        address[] memory emptyArray = new address[](0);
        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory executors = new address[](1);
        executors[0] = user1;
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray // Empty executors array
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: executors
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidExecutors.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test empty wildcard executors array
    function test_deployEmptyWildcardExecutors() external {
        address[] memory emptyArray = new address[](0);
        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory executors = new address[](1);
        executors[0] = user1;
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: executors
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: emptyArray,
            executors: emptyArray // Empty executors array
        });

        vm.expectRevert(GovernorAccessControlEmergencyFactory.InvalidExecutors.selector);
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );
    }

    // Test successful deployment with basic validation of roles
    function test_deploySuccess() external {
        vm.warp(1);

        address[] memory proposers = new address[](1);
        proposers[0] = user1;
        address[] memory cancellers = new address[](1);
        cancellers[0] = user2;
        address[] memory executors = new address[](1);
        executors[0] = user1;
        address[] memory guardians = new address[](1);
        guardians[0] = user3;

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: cancellers,
            executors: executors
        });

        IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
        IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
            minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
            proposers: proposers,
            cancellers: cancellers,
            executors: executors
        });

        (address adminTimelockAddr, address wildcardTimelockAddr, address governorAddr) =
        governorAccessControlEmergencyFactory.deploy(
            adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
        );

        // Verify EVC was correctly set
        assertEq(governorAccessControlEmergencyFactory.evc(), evc, "EVC address mismatch");

        // Verify contracts were deployed
        assertTrue(adminTimelockAddr != address(0), "Admin timelock not deployed");
        assertTrue(wildcardTimelockAddr != address(0), "Wildcard timelock not deployed");
        assertTrue(governorAddr != address(0), "Governor not deployed");

        // BaseFactory checks
        assertTrue(
            governorAccessControlEmergencyFactory.isValidDeployment(governorAddr),
            "Governor not tracked as valid deployment"
        );
        (address deployer, uint96 deployedAt) = governorAccessControlEmergencyFactory.getDeploymentInfo(governorAddr);
        assertEq(deployer, address(this), "Deployer address incorrect");
        assertEq(deployedAt, block.timestamp, "Deployment timestamp incorrect");

        assertEq(
            governorAccessControlEmergencyFactory.getDeploymentsListLength(), 1, "Deployments list length incorrect"
        );

        address[] memory deploymentsList = governorAccessControlEmergencyFactory.getDeploymentsListSlice(0, 1);
        assertEq(deploymentsList.length, 1, "Deployments list slice length incorrect");
        assertEq(deploymentsList[0], governorAddr, "Deployments list contains wrong address");

        // Get contract instances
        TimelockController adminTimelock = TimelockController(payable(adminTimelockAddr));
        TimelockController wildcardTimelock = TimelockController(payable(wildcardTimelockAddr));
        GovernorAccessControlEmergency governor = GovernorAccessControlEmergency(governorAddr);

        // Verify roles in admin timelock
        assertTrue(adminTimelock.hasRole(adminTimelock.PROPOSER_ROLE(), user1), "Admin timelock proposer role not set");
        assertTrue(
            adminTimelock.hasRole(adminTimelock.CANCELLER_ROLE(), user2), "Admin timelock canceller role not set"
        );
        assertTrue(adminTimelock.hasRole(adminTimelock.EXECUTOR_ROLE(), user1), "Admin timelock executor role not set");
        assertFalse(
            adminTimelock.hasRole(adminTimelock.DEFAULT_ADMIN_ROLE(), address(governorAccessControlEmergencyFactory)),
            "Factory still has admin role"
        );

        // Verify roles in wildcard timelock
        assertTrue(
            wildcardTimelock.hasRole(wildcardTimelock.PROPOSER_ROLE(), user1), "Wildcard timelock proposer role not set"
        );
        assertTrue(
            wildcardTimelock.hasRole(wildcardTimelock.CANCELLER_ROLE(), user2),
            "Wildcard timelock canceller role not set"
        );
        assertTrue(
            wildcardTimelock.hasRole(wildcardTimelock.EXECUTOR_ROLE(), user1), "Wildcard timelock executor role not set"
        );
        assertFalse(
            wildcardTimelock.hasRole(
                wildcardTimelock.DEFAULT_ADMIN_ROLE(), address(governorAccessControlEmergencyFactory)
            ),
            "Factory still has admin role"
        );

        // Verify roles in governor
        assertTrue(
            governor.hasRole(governor.DEFAULT_ADMIN_ROLE(), adminTimelockAddr), "Admin timelock not set as admin"
        );
        assertTrue(
            governor.hasRole(governor.WILD_CARD(), wildcardTimelockAddr), "Wildcard timelock not set with wildcard role"
        );

        // Verify guardian roles
        assertTrue(governor.hasRole(governor.LTV_EMERGENCY_ROLE(), user3), "Guardian not set with LTV emergency role");
        assertTrue(governor.hasRole(governor.HOOK_EMERGENCY_ROLE(), user3), "Guardian not set with hook emergency role");
        assertTrue(governor.hasRole(governor.CAPS_EMERGENCY_ROLE(), user3), "Guardian not set with caps emergency role");

        // Verify factory no longer has admin role
        assertFalse(
            governor.hasRole(governor.DEFAULT_ADMIN_ROLE(), address(governorAccessControlEmergencyFactory)),
            "Factory still has admin role in governor"
        );
    }

    // Test with multiple guardians, proposers, cancellers, and executors
    function test_deployWithMultipleRoles() external {
        vm.warp(1);

        address adminTimelockAddr;
        address wildcardTimelockAddr;
        address governorAddr;
        address[] memory proposers;
        address[] memory cancellers;
        address[] memory executors;
        address[] memory guardians;
        {
            proposers = new address[](2);
            proposers[0] = user1;
            proposers[1] = makeAddr("proposer2");

            cancellers = new address[](2);
            cancellers[0] = user2;
            cancellers[1] = makeAddr("canceller2");

            executors = new address[](2);
            executors[0] = user1;
            executors[1] = makeAddr("executor2");

            guardians = new address[](3);
            guardians[0] = user3;
            guardians[1] = makeAddr("guardian2");
            guardians[2] = makeAddr("guardian3");

            IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory adminTimelockControllerParams =
            IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
                minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
                proposers: proposers,
                cancellers: cancellers,
                executors: executors
            });

            IGovernorAccessControlEmergencyFactory.TimelockControllerParams memory wildcardTimelockControllerParams =
            IGovernorAccessControlEmergencyFactory.TimelockControllerParams({
                minDelay: governorAccessControlEmergencyFactory.MIN_MIN_DELAY(),
                proposers: proposers,
                cancellers: cancellers,
                executors: executors
            });

            (adminTimelockAddr, wildcardTimelockAddr, governorAddr) = governorAccessControlEmergencyFactory.deploy(
                adminTimelockControllerParams, wildcardTimelockControllerParams, guardians
            );
        }

        // BaseFactory checks
        assertTrue(
            governorAccessControlEmergencyFactory.isValidDeployment(governorAddr),
            "Governor not tracked as valid deployment"
        );
        (address deployer, uint96 deployedAt) = governorAccessControlEmergencyFactory.getDeploymentInfo(governorAddr);
        assertEq(deployer, address(this), "Deployer address incorrect");
        assertEq(deployedAt, block.timestamp, "Deployment timestamp incorrect");

        assertEq(
            governorAccessControlEmergencyFactory.getDeploymentsListLength(), 1, "Deployments list length incorrect"
        );

        address[] memory deploymentsList = governorAccessControlEmergencyFactory.getDeploymentsListSlice(0, 1);
        assertEq(deploymentsList.length, 1, "Deployments list slice length incorrect");
        assertEq(deploymentsList[0], governorAddr, "Deployments list contains wrong address");

        // Get contract instances
        TimelockController adminTimelock = TimelockController(payable(adminTimelockAddr));
        TimelockController wildcardTimelock = TimelockController(payable(wildcardTimelockAddr));
        GovernorAccessControlEmergency governor = GovernorAccessControlEmergency(governorAddr);

        // Check all roles were properly assigned in admin timelock
        for (uint256 i = 0; i < proposers.length; i++) {
            assertTrue(
                adminTimelock.hasRole(adminTimelock.PROPOSER_ROLE(), proposers[i]),
                "Admin timelock proposer role not set"
            );
        }

        for (uint256 i = 0; i < cancellers.length; i++) {
            assertTrue(
                adminTimelock.hasRole(adminTimelock.CANCELLER_ROLE(), cancellers[i]),
                "Admin timelock canceller role not set"
            );
        }

        for (uint256 i = 0; i < executors.length; i++) {
            assertTrue(
                adminTimelock.hasRole(adminTimelock.EXECUTOR_ROLE(), executors[i]),
                "Admin timelock executor role not set"
            );
        }

        // Check all roles were properly assigned in wildcard timelock
        for (uint256 i = 0; i < proposers.length; i++) {
            assertTrue(
                wildcardTimelock.hasRole(wildcardTimelock.PROPOSER_ROLE(), proposers[i]),
                "Wildcard timelock proposer role not set"
            );
        }

        for (uint256 i = 0; i < cancellers.length; i++) {
            assertTrue(
                wildcardTimelock.hasRole(wildcardTimelock.CANCELLER_ROLE(), cancellers[i]),
                "Wildcard timelock canceller role not set"
            );
        }

        for (uint256 i = 0; i < executors.length; i++) {
            assertTrue(
                wildcardTimelock.hasRole(wildcardTimelock.EXECUTOR_ROLE(), executors[i]),
                "Wildcard timelock executor role not set"
            );
        }

        // Verify guardian roles
        for (uint256 i = 0; i < guardians.length; i++) {
            assertTrue(
                governor.hasRole(governor.LTV_EMERGENCY_ROLE(), guardians[i]),
                "Guardian not set with LTV emergency role"
            );
            assertTrue(
                governor.hasRole(governor.HOOK_EMERGENCY_ROLE(), guardians[i]),
                "Guardian not set with hook emergency role"
            );
            assertTrue(
                governor.hasRole(governor.CAPS_EMERGENCY_ROLE(), guardians[i]),
                "Guardian not set with caps emergency role"
            );
        }
    }
}
