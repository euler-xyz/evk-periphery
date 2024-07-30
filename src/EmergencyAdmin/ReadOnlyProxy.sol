// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "evk/EVault/shared/lib/RevertBytes.sol";

/// @title ReadOnlyProxy
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This contract is read-only proxy to the configured implementation contract
contract ReadOnlyProxy {
    address immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function delegateView(bytes memory payload) external returns (bytes memory) {
        (bool success, bytes memory data) = implementation.delegatecall(payload);
        if (!success) RevertBytes.revertBytes(data);

        return data;
    }

    fallback() external {
        (bool success, bytes memory data) = address(this).staticcall(abi.encodeCall(this.delegateView, (msg.data)));
        if (!success) RevertBytes.revertBytes(data);

        assembly {
            return(add(32, data), mload(data))
        }
    }
}
