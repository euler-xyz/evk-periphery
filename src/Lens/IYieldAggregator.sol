// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// contracts
import {Checkpoints} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
// libs
import {AmountCap} from "evk/EVault/shared/types/AmountCap.sol";

interface IYieldAggregator {
    /// @dev Struct to pass to constructor.
    struct DeploymentParams {
        address yieldAggregatorVaultModule;
        address rewardsModule;
        address hooksModule;
        address feeModule;
        address strategyModule;
        address withdrawalQueueModule;
    }

    /// @dev Struct to pass init() call params.
    struct InitParams {
        address yieldAggregatorVaultOwner;
        address asset;
        string name;
        string symbol;
        uint256 initialCashAllocationPoints;
    }

    /// @dev A struct that hold a strategy allocation's config
    /// allocated: amount of asset deposited into strategy
    /// allocationPoints: number of points allocated to this strategy
    /// cap: an optional cap in terms of deposited underlying asset. By default, it is set to 0(not activated)
    /// status: an enum describing the strategy status. Check the enum definition for more details.
    struct Strategy {
        uint120 allocated;
        uint96 allocationPoints;
        AmountCap cap;
        StrategyStatus status;
    }

    /// @dev An enum for strategy status.
    /// An inactive strategy is a strategy that is not added to and recognized by the withdrawal queue.
    /// An active strategy is a well-functional strategy that is added in the withdrawal queue, can be rebalanced and
    /// harvested.
    /// A strategy status set as Emergency, if when the strategy for some reasons can no longer be withdrawn from or
    /// deposited into it,
    /// this will be used as a circuit-breaker to ensure that the Yield Aggregator can continue functioning as intended,
    /// and the only impacted strategy will be the one set as Emergency.
    enum StrategyStatus {
        Inactive,
        Active,
        Emergency
    }

    /// non-view functions
    function init(InitParams calldata _initParams) external;
    function setFeeRecipient(address _newFeeRecipient) external;
    function setPerformanceFee(uint96 _newFee) external;
    function optInStrategyRewards(address _strategy) external;
    function optOutStrategyRewards(address _strategy) external;
    function enableRewardForStrategy(address _strategy, address _reward) external;
    function disableRewardForStrategy(address _strategy, address _reward, bool _forfeitRecentReward) external;
    function claimStrategyReward(address _strategy, address _reward, address _recipient, bool _forfeitRecentReward)
        external;
    function setHooksConfig(address _hooksTarget, uint32 _hookedFns) external;
    function addStrategy(address _strategy, uint256 _allocationPoints) external;
    function removeStrategy(address _strategy) external;
    function setStrategyCap(address _strategy, uint16 _cap) external;
    function adjustAllocationPoints(address _strategy, uint256 _newPoints) external;
    function toggleStrategyEmergencyStatus(address _strategy) external;
    function enableBalanceForwarder() external;
    function disableBalanceForwarder() external;
    function rebalance(address[] calldata _strategies) external;
    function reorderWithdrawalQueue(uint8 _index1, uint8 _index2) external;
    function harvest() external;
    function updateInterestAccrued() external;
    function gulp() external;
    function deposit(uint256 _assets, address _receiver) external returns (uint256);
    function mint(uint256 _shares, address _receiver) external returns (uint256);
    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256 shares);
    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 assets);
    function transfer(address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function delegate(address _delegatee) external;
    function delegateBySig(address _delegatee, uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s)
        external;

    /// view functions
    function asset() external view returns (address);
    function interestAccrued() external view returns (uint256);
    function getYieldAggregatorSavingRate() external view returns (uint40, uint40, uint168);
    function totalAllocated() external view returns (uint256);
    function totalAssetsDeposited() external view returns (uint256);
    function lastHarvestTimestamp() external view returns (uint256);
    function totalAssetsAllocatable() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 _assets) external view returns (uint256);
    function convertToAssets(uint256 _shares) external view returns (uint256);
    function maxWithdraw(address _owner) external view returns (uint256);
    function maxRedeem(address _owner) external view returns (uint256);
    function previewDeposit(uint256 _assets) external view returns (uint256);
    function previewMint(uint256 _shares) external view returns (uint256);
    function previewWithdraw(uint256 _assets) external view returns (uint256);
    function previewRedeem(uint256 _shares) external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function maxDeposit(address _owner) external view returns (uint256);
    function maxMint(address _owner) external view returns (uint256);
    function getStrategy(address _strategy) external view returns (Strategy memory);
    function totalAllocationPoints() external view returns (uint256);
    function performanceFeeConfig() external view returns (address, uint96);
    function getHooksConfig() external view returns (address, uint32);
    function balanceTrackerAddress() external view returns (address);
    function balanceForwarderEnabled(address _account) external view returns (bool);
    function withdrawalQueue() external view returns (address[] memory);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function numCheckpoints(address _account) external view returns (uint32);
    function checkpoints(address _account, uint32 _pos) external view returns (Checkpoints.Checkpoint208 memory);
    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address _account) external view returns (uint256);
    function getPastVotes(address _account, uint256 _timepoint) external view returns (uint256);
    function getPastTotalSupply(uint256 _timepoint) external view returns (uint256);
    function delegates(address _account) external view returns (address);

    // to be added in the original IYieldAggregator
    function EVC() external view returns (address);
    function permit2Address() external view returns (address);
    function isHarvestCoolDownCheckOn() external view returns (bool);
}
