// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ScriptUtils is Script {
    modifier broadcast() {
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));
        _;
        vm.stopBroadcast();
    }

    function startBroadcast() internal {
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));
    }

    function stopBroadcast() internal {
        vm.stopBroadcast();
    }

    function getDeployer() internal view returns (address) {
        address deployer = vm.addr(vm.envOr("DEPLOYER_KEY", uint256(1)));
        return deployer == vm.addr(1) ? address(this) : deployer;
    }

    function getInputConfig(string memory jsonFile) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/input/", jsonFile);
        return vm.readFile(configPath);
    }
}

contract ERC20Mintable is Ownable, ERC20 {
    uint8 internal immutable _decimals;

    constructor(address owner, string memory name_, string memory symbol_, uint8 decimals_)
        Ownable(owner)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
