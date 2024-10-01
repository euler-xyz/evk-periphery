// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20Wrapper} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {ERC20WrapperLocked} from "../implementation/ERC20WrapperLocked.sol";

/// @title RewardToken
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A wrapper for locked ERC20 tokens that can be withdrawn as per the lock schedule.
/// @dev This contract implements a specific unlock schedule for reward tokens. Tokens are gradually unlocked over a
/// 180-day period, with 20% unlocked after 30 days and the remaining 80% linearly unlocked over the next 150 days.
contract RewardToken is ERC20WrapperLocked {
    /// @notice Constructor for RewardToken
    /// @param _evc Address of the Ethereum Vault Connector
    /// @param _owner Address of the contract owner
    /// @param _receiver Address of the receiver
    /// @param _underlying Address of the underlying ERC20 token
    /// @param _name Name of the wrapped token
    /// @param _symbol Symbol of the wrapped token
    constructor(
        address _evc,
        address _owner,
        address _receiver,
        address _underlying,
        string memory _name,
        string memory _symbol
    ) ERC20WrapperLocked(_evc, _owner, _receiver, _underlying, _name, _symbol) {}

    /// @notice Calculates the share of tokens that can be unlocked based on the lock timestamp
    /// @param lockTimestamp The timestamp when the tokens were locked
    /// @return The share of tokens that can be freely unlocked (in basis points)
    function _calculateUnlockShare(uint256 lockTimestamp) internal view virtual override returns (uint256) {
        //      Share %
        //        ^
        //        |                         share4 +----------+
        //        |                                |
        //        |                                |
        //        |              share3 +----------+
        //        |                     |          |
        //        |                     |          |
        //        |              share2 +          |
        //        |                   _/|          |
        //        |                 _/  |          |
        //        |               _/    |          |
        //        |             _/      |          |
        //        |           _/        |          |
        // share1 +----------+          |          |
        //        |          |          |          |
        //        |          |          |          |
        //        +----------+----------+----------+----------> Time (days)
        //        0       period1    period2    period3

        if (lockTimestamp > block.timestamp) return 0;

        unchecked {
            // period1: 30 days; period2: 180 days; period3: 540 days
            // share1: 20%; share2: 80%; share3: 90%; share4: 100%
            uint256 timeElapsed = block.timestamp - lockTimestamp;

            if (timeElapsed <= 30 days) return 0.2e4;
            else if (timeElapsed >= 180 days && timeElapsed <= 540 days) return 0.9e4;
            else if (timeElapsed > 540 days) return SCALE;
            else return (timeElapsed - 30 days) * 0.6e4 / 150 days + 0.2e4;
        }
    }
}
