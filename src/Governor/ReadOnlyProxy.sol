// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

/// @title ReadOnlyProxy
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This contract is read-only proxy to the configured implementation contract
contract ReadOnlyProxy {
    address immutable implementation;

    /// @notice Constructor to set the implementation address to proxy to.
    /// @param _implementation Old implementation contract to proxy to
    constructor(address _implementation) {
        implementation = _implementation;
    }

    /// @dev Callable only by fallback, delegate calls original payload in a static frame,
    /// which means any state mutation will cause a revert
    function proxyDelegateView(bytes memory payload) external returns (bytes memory) {
        require(msg.sender == address(this), "unauthorized");

        (bool success, bytes memory data) = implementation.delegatecall(payload);
        if (!success) {
            if (data.length == 0) revert("contract is in read-only mode");
            else RevertBytes.revertBytes(data);
        }

        assembly {
            return(add(32, data), mload(data))
        }
    }

    /// @dev Fallback functions forwards the calldata in a static frame to `proxyDelegateView` which in turn
    /// delegate calls into the proxied implementation, with guarantee that any state mutation will revert the tx.
    fallback() external {
        (bool success, bytes memory data) = address(this).staticcall(abi.encodeCall(this.proxyDelegateView, (msg.data)));
        if (!success) RevertBytes.revertBytes(data);

        assembly {
            return(add(32, data), mload(data))
        }
    }
}
