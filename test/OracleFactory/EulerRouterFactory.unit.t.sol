// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {EulerRouterFactory} from "../../src/EulerRouterFactory/EulerRouterFactory.sol";
import {IEulerRouterFactory, IFactory} from "../../src/EulerRouterFactory/interfaces/IEulerRouterFactory.sol";

contract EulerRouterFactoryTest is Test {
    address internal OWNER;
    EthereumVaultConnector internal evc;
    IEulerRouterFactory internal factory;

    function setUp() public {
        evc = new EthereumVaultConnector();
        factory = new EulerRouterFactory(address(evc));
    }

    /// @dev Factory allows anyone to deploy an instance EulerRouter.
    function testDeploy(address deployer, address governor, uint256 timestamp) public {
        vm.assume(governor != address(0));
        timestamp = bound(timestamp, 0, type(uint96).max);
        vm.warp(timestamp);

        vm.expectEmit(false, true, false, true, address(factory));
        emit IFactory.ContractDeployed(address(0), deployer, timestamp);
        vm.prank(deployer);
        address deployment = factory.deploy(governor);

        (address storedDeployer, uint256 storedTimestamp) = factory.getDeploymentInfo(deployment);
        assertEq(storedDeployer, deployer);
        assertEq(storedTimestamp, timestamp);
    }

    /// @dev Factory allows anyone to deploy duplicate instances of EulerRouter.
    function testDeployDuplicateOk(address deployer, address governor, uint256 timestamp) public {
        vm.assume(governor != address(0));
        vm.warp(timestamp);
        vm.startPrank(deployer);
        address deploymentA = factory.deploy(governor);
        address deploymentB = factory.deploy(governor);

        (address storedDeployerA, uint256 storedTimestampA) = factory.getDeploymentInfo(deploymentA);
        (address storedDeployerB, uint256 storedTimestampB) = factory.getDeploymentInfo(deploymentB);

        assertNotEq(deploymentA, deploymentB);
        assertEq(storedDeployerA, storedDeployerB);
        assertEq(storedTimestampA, storedTimestampB);
    }

    /// @dev Factory deploys an EulerRouter.
    function testDeployIsEulerRouter(address governor) public {
        vm.assume(governor != address(0));
        address factoryDeployment = factory.deploy(governor);
        address directDeployment = address(new EulerRouter(address(evc), governor));
        assertEq(factoryDeployment.codehash, directDeployment.codehash);
    }
}
