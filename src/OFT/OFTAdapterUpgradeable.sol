// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable as OFTAdapter} from "layerzero/oft-evm-upgradeable/oft/OFTAdapterUpgradeable.sol";

/// @title OFTAdapterUpgradeable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice OFTAdapter is a contract that adapts an ERC-20 token to the OFT functionality.
/// @dev Inherits from LZ's OFTAdapterUpgradeable and provides an initializer for the contract.
contract OFTAdapterUpgradeable is OFTAdapter {
    /// @notice Creates the OFTAdapterUpgradeable contract
    /// @param _token The address of the underlying ERC20 token
    /// @param _lzEndpoint The LayerZero endpoint address
    constructor(address _token, address _lzEndpoint) OFTAdapter(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the OFTAdapterUpgradeable contract
    /// @param _delegate The address of the delegate
    function initialize(address _delegate) public initializer {
        __OFTAdapter_init(_delegate);
        __Ownable_init(_delegate);
    }
}
