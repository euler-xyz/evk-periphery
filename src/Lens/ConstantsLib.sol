// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library ConstantsLib {
    // Hookable functions code.
    uint32 public constant DEPOSIT = 1 << 0;
    uint32 public constant WITHDRAW = 1 << 1;
    uint32 public constant MINT = 1 << 2;
    uint32 public constant REDEEM = 1 << 3;
    uint32 public constant ADD_STRATEGY = 1 << 4;
    uint32 public constant REMOVE_STRATEGY = 1 << 5;
    uint32 constant ACTIONS_COUNTER = 1 << 6;

    // Re-entrancy protection
    uint8 internal constant REENTRANCYLOCK__UNLOCKED = 1;
    uint8 internal constant REENTRANCYLOCK__LOCKED = 2;

    /// @dev Interest rate smearing period
    uint256 public constant INTEREST_SMEAR = 2 weeks;

    /// @dev Cool down period for harvest call during withdraw operation.
    uint256 public constant HARVEST_COOLDOWN = 1 days;

    /// @dev The maximum performance fee the vault can have is 50%
    uint96 internal constant MAX_PERFORMANCE_FEE = 0.5e18;

    /// @dev address(0) set for cash reserve strategy.
    address public constant CASH_RESERVE = address(0);

    /// @dev Max cap amount, which is the same as the max amount `Strategy.allocated` can hold.
    uint256 public constant MAX_CAP_AMOUNT = type(uint120).max;

    /// @dev Max number of strategies in withdrawal queue.
    uint256 public constant MAX_STRATEGIES = 10;

    // Roles and their ADMIN roles.
    /// @dev GUARDIAN: can set strategy cap, adjust strategy allocation points, set strategy status to EMERGENCY or
    /// revert it back.
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");
    bytes32 public constant GUARDIAN_ADMIN = keccak256("GUARDIAN_ADMIN");
    /// @dev STRATEGY_OPERATOR: can add and remove strategy.
    bytes32 public constant STRATEGY_OPERATOR = keccak256("STRATEGY_OPERATOR");
    bytes32 public constant STRATEGY_OPERATOR_ADMIN = keccak256("STRATEGY_OPERATOR_ADMIN");
    /// @dev YIELD_AGGREGATOR_MANAGER: can set performance fee and recipient, opt in&out underlying strategy rewards,
    /// including enabling, disabling and claiming those rewards, plus set hooks config.
    bytes32 public constant YIELD_AGGREGATOR_MANAGER = keccak256("YIELD_AGGREGATOR_MANAGER");
    bytes32 public constant YIELD_AGGREGATOR_MANAGER_ADMIN = keccak256("YIELD_AGGREGATOR_MANAGER_ADMIN");
    /// @dev WITHDRAWAL_QUEUE_MANAGER: can re-order withdrawal queue array.
    bytes32 public constant WITHDRAWAL_QUEUE_MANAGER = keccak256("WITHDRAWAL_QUEUE_MANAGER");
    bytes32 public constant WITHDRAWAL_QUEUE_MANAGER_ADMIN = keccak256("WITHDRAWAL_QUEUE_MANAGER_ADMIN");
}
