// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "evk/EVault/shared/lib/RevertBytes.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

/// @title EmergencyAdmin
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Base contract for emergency admin contracts, which allow certain emergency operation to be executed by designated parties.
abstract contract EmergencyAdmin {
    using EnumerableSet for EnumerableSet.AddressSet;

    // address with full admin rights for controlled contract
    address public admin;
    // addresses with rights to call the emergency function
    EnumerableSet.AddressSet guardians;

    modifier onlyAdmin() {
        require (admin == msg.sender, "unauthorized");
        _;
    }

    modifier onlyAdminOrGuardian() {
        require (admin == msg.sender || guardians.contains(msg.sender), "unauthorized");
        _;
    }

    event AdminSet(address indexed admin);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event Emergency(address indexed target);

    constructor(address _admin, address[] memory _guardians) {
        admin = _admin;
        emit AdminSet(_admin);

        for (uint i; i < _guardians.length; i++) {
            guardians.add(_guardians[i]);
            emit GuardianAdded(_guardians[i]);
        }
    }

    // admin

    function exec(address target, bytes memory payload) external onlyAdmin returns (bytes memory) {
        (bool success, bytes memory data) = target.call(payload);
        if (!success) RevertBytes.revertBytes(data);
        return data;
    }

    function emergency(address target) external onlyAdminOrGuardian {
        _emergency(target);
        emit Emergency(target);
    }

    function _emergency(address target) internal virtual;

    // access control

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
        emit AdminSet(newAdmin);
    }

    function addGuardian(address guardian) external onlyAdmin {
        guardians.add(guardian);
        emit GuardianAdded(guardian);
    }

    function removeGuardian(address guardian) external onlyAdmin {
        guardians.remove(guardian);
        emit GuardianRemoved(guardian);
    }

    function getGuardians() external view returns (address[] memory) {
        return guardians.values();
    }

    function isGuardian(address query) external view returns (bool) {
        return guardians.contains(query);
    }
}
