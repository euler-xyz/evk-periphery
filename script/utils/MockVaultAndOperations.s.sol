// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {MockERC20MintableDeployer, MockERC20Mintable} from "../00_ERC20.s.sol";
import {EVaultDeployer, IEVault} from "../07_EVault.s.sol";

contract MockVaultAndOperations is ScriptUtils {
    uint256 internal constant AMOUNT = 1e6 * 1e18;

    function run() public {
        MockERC20MintableDeployer mockERC20MintableDeployer = new MockERC20MintableDeployer();
        EVaultDeployer eVaultDeployer = new EVaultDeployer();

        MockERC20Mintable mockERC20 = MockERC20Mintable(mockERC20MintableDeployer.deploy("MockERC20", "MOCK", 18));
        IEVault eVault = IEVault(eVaultDeployer.deploy(coreAddresses.eVaultFactory, true, address(mockERC20)));

        vm.startBroadcast();
        address deployer = getDeployer();
        mockERC20.mint(deployer, AMOUNT);
        mockERC20.approve(address(eVault), AMOUNT);
        eVault.setHookConfig(address(0), 0);
        eVault.deposit(AMOUNT, deployer);
        eVault.withdraw(AMOUNT / 2, deployer, deployer);
        vm.stopBroadcast();
    }
}
