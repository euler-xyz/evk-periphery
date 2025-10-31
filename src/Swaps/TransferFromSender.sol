// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SafeERC20Permit2Lib, IERC20} from "euler-earn/libraries/SafeERC20Permit2Lib.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title TransferFromSender
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Simple contract used to pull tokens from the sender.
/// @dev This contract is trusted and can safely receive allowance on token transfers from users.
contract TransferFromSender is EVCUtil {
    /// @notice Address of Permit2 contract
    address public immutable permit2;

    /// @notice Contract constructor
    /// @param _permit2 Address of the Permit2 contract
    constructor(address _evc, address _permit2) EVCUtil(_evc) {
        permit2 = _permit2;
    }

    /// @notice Pull tokens from sender to the designated receiver
    /// @param token ERC20 token address
    /// @param amount Amount of the token to transfer
    /// @param to Receiver of the token
    function transferFromSender(address token, uint256 amount, address to) public {
        SafeERC20Permit2Lib.safeTransferFromWithPermit2(IERC20(token), _msgSender(), to, amount, permit2);
    }
}
