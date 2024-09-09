// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;
import {Test, console, stdError} from "forge-std/Test.sol";
import {OwnershipTransferCore} from "../../script/production/mainnet/OwnershipTransferCore.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {EVault} from "evk/EVault/EVault.sol";


/// @notice The tests operate on a fork. Create a .env file with FORK_RPC_URL as per foundry docs
contract FactoryGovernorScriptsTest is Test, OwnershipTransferCore {
    uint256 constant BLOCK_NUMBER = 20712274;

    address internal constant EVAULT_FACTORY = 0x29a56a1b8214D9Cf7c5561811750D5cBDb45CC8e;
    address internal constant PROTOCOL_CONFIG = 0x4cD6BF1D183264c02Be7748Cb5cd3A47d013351b;
    address internal EUSDC2 = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;

    address internal constant DEPLOYER = 0xEe009FAF00CF54C1B4387829aF7A8Dc5f0c8C8C5;

    // SET AFTER DEPLOYMENT
    address internal constant FACTORY_GOVERNOR = address(0);

    uint256 mainnetFork;

    FactoryGovernor factoryGovernor;
    GenericFactory factory;
    ProtocolConfig protocolConfig;
    EVault eUSDC;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL", string(""));

    constructor () OwnershipTransferCore() {
        coreAddresses.eVaultFactory = EVAULT_FACTORY;
        coreAddresses.protocolConfig = PROTOCOL_CONFIG;
    }
    function getDeployer() internal pure override returns (address) {
        return DEPLOYER;
    }

    function setUp() public virtual {
        if (bytes(FORK_RPC_URL).length == 0) return; 

        mainnetFork = vm.createSelectFork(FORK_RPC_URL);
        vm.rollFork(BLOCK_NUMBER);

        if (coreAddresses.eVaultFactoryGovernor == address(0))
            coreAddresses.eVaultFactoryGovernor = address(new FactoryGovernor(getDeployer()));

        factoryGovernor = FactoryGovernor(coreAddresses.eVaultFactoryGovernor);
        factory = GenericFactory(coreAddresses.eVaultFactory);
        protocolConfig = ProtocolConfig(coreAddresses.protocolConfig);
        eUSDC = EVault(EUSDC2);

        // temporarily set upgrade admin on factory and protocol config back to euler deployer
        startHoax(EULER_DAO);
        factory.setUpgradeAdmin(DEPLOYER);
        protocolConfig.setAdmin(DEPLOYER);

        startHoax(DEPLOYER);
        transferOwnership();
        vm.stopPrank();
    }

    function shouldSkip() internal view returns (bool) {
        if (bytes(FORK_RPC_URL).length == 0) return true;

        if (factory.upgradeAdmin() != FACTORY_GOVERNOR) return false;
        if (factoryGovernor.getRoleMember(factoryGovernor.DEFAULT_ADMIN_ROLE(), 0) != EVAULT_FACTORY_GOVERNOR_ADMIN) return false;
        if (protocolConfig.admin() != PROTOCOL_CONFIG_ADMIN) return false;

        return true;
    }

    function test_OwnershipTransferScript_newProtocolConfigAdmin() external {
        vm.skip(shouldSkip());

        assertEq(protocolConfig.admin(), PROTOCOL_CONFIG_ADMIN);

        address feeReceiver = makeAddr("newFeeReceiver");
        vm.prank(PROTOCOL_CONFIG_ADMIN);
        protocolConfig.setFeeReceiver(feeReceiver);

        assertEq(protocolConfig.feeReceiver(), feeReceiver);
    }

    function test_OwnershipTransferScript_factoryGovernorInstalled() external {
        vm.skip(shouldSkip());
        assertEq(factory.upgradeAdmin(), address(factoryGovernor));
    }

    function test_OwnershipTransferScript_factoryGovernorEnumRoles() external {
        vm.skip(shouldSkip());

        assertEq(factoryGovernor.getRoleMemberCount(factoryGovernor.DEFAULT_ADMIN_ROLE()), 1);
        assertEq(factoryGovernor.getRoleMember(factoryGovernor.DEFAULT_ADMIN_ROLE(), 0), EULER_DAO);

        assertEq(factoryGovernor.getRoleMemberCount(factoryGovernor.GUARDIAN_ROLE()), 1);
        assertEq(factoryGovernor.getRoleMember(factoryGovernor.GUARDIAN_ROLE(), 0), EULER_DAO);
    }

    function test_OwnershipTransferScript_factoryGovernorCanUpgradeVault() external {
        vm.skip(shouldSkip());

        address newImplementation = makeAddr("newImplementation");
        vm.etch(newImplementation, "123");

        vm.expectRevert();
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setImplementation, (newImplementation)));

        startHoax(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setImplementation, (newImplementation)));

        assertEq(factory.implementation(), newImplementation);
    }

    function test_OwnershipTransferScript_factoryGovernorCanTransferAdmin() external {
        vm.skip(shouldSkip());

        address newFactoryAdmin = makeAddr("newFactoryAdmin");

        startHoax(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setUpgradeAdmin, (newFactoryAdmin)));
        vm.expectRevert();
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setUpgradeAdmin, (newFactoryAdmin)));

        assertEq(factory.upgradeAdmin(), newFactoryAdmin);
    }

    function test_OwnershipTransferScript_factoryGovernorCanPauseAndUnpause() external {
        vm.skip(shouldSkip());

        address oldImplementation = factory.implementation();

        eUSDC.touch();

        vm.expectRevert();
        factoryGovernor.pause(address(factory));

        startHoax(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.pause(address(factory));

        vm.expectRevert("contract is in read-only mode");
        eUSDC.touch();

        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setImplementation, (oldImplementation)));
        eUSDC.touch();
    }

    function test_OwnershipTransferScript_factoryGovernorGuardianCanPause() external {
        vm.skip(shouldSkip());

        address guardian = makeAddr("guardian");

        address oldImplementation = factory.implementation();

        startHoax(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.grantRole(factoryGovernor.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        vm.expectRevert("contract is in read-only mode");
        eUSDC.touch();

        vm.prank(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setImplementation, (oldImplementation)));
        eUSDC.touch();
    }
}
