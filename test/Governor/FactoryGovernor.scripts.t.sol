// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;
import {Test, console, stdError} from "forge-std/Test.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {EVault} from "evk/EVault/EVault.sol";


/// @notice The tests operate on a fork. Create a .env file with FORK_RPC_URL as per foundry docs
contract FactoryGovernorScriptsTest is Test {
    uint256 constant BLOCK_NUMBER = 20764243;
    address internal constant FACTORY_GOVERNOR = 0x799E9b58895d7D10306cA6C4cAb51728B142a224;

    address internal constant EVAULT_FACTORY = 0x29a56a1b8214D9Cf7c5561811750D5cBDb45CC8e;
    address internal constant EULER_DAO = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;
    address internal EUSDC2 = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;

    address internal constant EVAULT_FACTORY_GOVERNOR_ADMIN = EULER_DAO;

    uint256 mainnetFork;

    FactoryGovernor factoryGovernor;
    GenericFactory factory;
    EVault eUSDC;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL", string(""));

    constructor () {
        factoryGovernor = FactoryGovernor(FACTORY_GOVERNOR);
        factory = GenericFactory(EVAULT_FACTORY);
        eUSDC = EVault(EUSDC2);
    }

    function setUp() public virtual {
        if (bytes(FORK_RPC_URL).length == 0) return; 

        mainnetFork = vm.createSelectFork(FORK_RPC_URL);
        vm.rollFork(BLOCK_NUMBER);


        // install factory gov
        startHoax(EULER_DAO);
        factory.setUpgradeAdmin(FACTORY_GOVERNOR);
        vm.stopPrank();
    }

    function shouldSkip() internal view returns (bool) {
        if (bytes(FORK_RPC_URL).length == 0) return true;
        return false;
    }

    function test_InstallFactoryGovernor_factoryGovernorInstalled() external {
        vm.skip(shouldSkip());
        assertEq(factory.upgradeAdmin(), address(factoryGovernor));
    }

    function test_InstallFactoryGovernor_factoryGovernorEnumRoles() external {
        vm.skip(shouldSkip());

        assertEq(factoryGovernor.getRoleMemberCount(factoryGovernor.DEFAULT_ADMIN_ROLE()), 1);
        assertEq(factoryGovernor.getRoleMember(factoryGovernor.DEFAULT_ADMIN_ROLE(), 0), EULER_DAO);

        assertEq(factoryGovernor.getRoleMemberCount(factoryGovernor.GUARDIAN_ROLE()), 1);
        assertEq(factoryGovernor.getRoleMember(factoryGovernor.GUARDIAN_ROLE(), 0), EULER_DAO);
    }

    function test_InstallFactoryGovernor_factoryGovernorCanUpgradeVault() external {
        vm.skip(shouldSkip());

        address newImplementation = makeAddr("newImplementation");
        vm.etch(newImplementation, "123");

        vm.expectRevert();
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setImplementation, (newImplementation)));

        startHoax(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setImplementation, (newImplementation)));

        assertEq(factory.implementation(), newImplementation);
    }

    function test_InstallFactoryGovernor_factoryGovernorCanTransferAdmin() external {
        vm.skip(shouldSkip());

        address newFactoryAdmin = makeAddr("newFactoryAdmin");

        startHoax(EVAULT_FACTORY_GOVERNOR_ADMIN);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setUpgradeAdmin, (newFactoryAdmin)));
        vm.expectRevert();
        factoryGovernor.adminCall(address(factory), abi.encodeCall(GenericFactory.setUpgradeAdmin, (newFactoryAdmin)));

        assertEq(factory.upgradeAdmin(), newFactoryAdmin);
    }

    function test_InstallFactoryGovernor_factoryGovernorCanPauseAndUnpause() external {
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

    function test_InstallFactoryGovernor_factoryGovernorGuardianCanPause() external {
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
