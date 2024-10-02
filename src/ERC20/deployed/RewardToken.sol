// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20WrapperLocked} from "../implementation/ERC20WrapperLocked.sol";

/// @title RewardToken
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A wrapper for locked ERC20 tokens that can be withdrawn as per the lock schedule.
/// @dev This contract implements a specific unlock schedule for reward tokens. Tokens are unlocked over a 180-day
/// period. 20% is unlocked immediately, and the remaining 80% unlocks linearly over 6 months, reaching full unlock at
/// maturity. The linear unlock starts LOCK_NORMALIZATION_FACTOR after the lock is created.
contract RewardToken is ERC20WrapperLocked {
    /// @notice Constructor for RewardToken
    /// @param _evc Address of the Ethereum Vault Connector
    /// @param _owner Address of the contract owner
    /// @param _receiver Address of the receiver
    /// @param _underlying Address of the underlying ERC20 token
    /// @param _name Name of the reward token
    /// @param _symbol Symbol of the reward token
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
        if (lockTimestamp > block.timestamp) return 0;

        unchecked {
            uint256 timeElapsed = block.timestamp - lockTimestamp;

            if (timeElapsed <= LOCK_NORMALIZATION_FACTOR) {
                return 0.2e18;
            } else if (timeElapsed >= 180 days) {
                return SCALE;
            } else {
                return
                    (timeElapsed - LOCK_NORMALIZATION_FACTOR) * 0.8e18 / (180 days - LOCK_NORMALIZATION_FACTOR) + 0.2e18;
            }
        }
    }
}
