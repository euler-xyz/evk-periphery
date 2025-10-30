// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MockToken} from "./MockToken.sol";

contract ReenteringMockToken is MockToken {
    address public reenterTarget;
    bytes public reenterData;

    constructor(string memory name_, string memory symbol_) MockToken(name_, symbol_) {}

    function setReenterTargetAndData(address reenterTarget_, bytes memory reenterData_) external {
        reenterTarget = reenterTarget_;
        reenterData = reenterData_;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        bool success = super.transfer(recipient, amount);

        if (reenterTarget == address(0)) {
            return success;
        }

        (bool reenterSuccess, bytes memory data) = reenterTarget.call(reenterData);
        if (!reenterSuccess) {
            // The call failed, bubble up the error data
            if (data.length > 0) {
                // Decode the revert reason and throw it
                assembly {
                    let data_size := mload(data)
                    revert(add(32, data), data_size)
                }
            } else {
                revert("Call failed without revert reason");
            }
        }

        return success;
    }
}
