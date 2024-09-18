// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Utils} from "./Utils.sol";
import "./IYieldAggregator.sol";
import "./LensTypes.sol";
import "evk/EVault/shared/types/AmountCap.sol";

contract EulerEarn is Utils {
    function getVaultInfoFull(address vault) public view returns (EulerEarnInfoFull memory) {
        EulerEarnInfoFull memory result;

        result.timestamp = block.timestamp;
        result.balanceTracker = IYieldAggregator(vault).balanceTrackerAddress();

        result.vault = vault;
        result.vaultName = IYieldAggregator(vault).name();
        result.vaultSymbol = IYieldAggregator(vault).symbol();
        result.vaultDecimals = IYieldAggregator(vault).decimals();

        result.asset = IYieldAggregator(vault).asset();
        result.assetName = _getStringOrBytes32(result.asset, IYieldAggregator(vault).name.selector);
        result.assetSymbol = _getStringOrBytes32(result.asset, IYieldAggregator(vault).symbol.selector);
        result.assetDecimals = _getDecimals(result.asset);

        result.totalShares = IYieldAggregator(vault).totalSupply();
        result.totalAssets = IYieldAggregator(vault).totalAssets();
        result.totalAssetsDeposited = IYieldAggregator(vault).totalAssetsDeposited();
        result.totalAllocated = IYieldAggregator(vault).totalAllocated();
        result.totalAssetsAllocatable = IYieldAggregator(vault).totalAssetsAllocatable();
        result.totalAllocationPoints = IYieldAggregator(vault).totalAllocationPoints();
        result.interestAccrued = IYieldAggregator(vault).interestAccrued();

        (result.lastInterestUpdate, result.interestSmearEnd, result.interestLeft) =
            IYieldAggregator(vault).getYieldAggregatorSavingRate();

        (result.feeRecipient, result.performanceFee) = IYieldAggregator(vault).performanceFeeConfig();

        (result.hookTarget, result.hookedOperations) = IYieldAggregator(vault).getHooksConfig();

        result.lastHarvestTimestamp = IYieldAggregator(vault).lastHarvestTimestamp();

        address[] memory withdrawalQueue = IYieldAggregator(vault).withdrawalQueue();
        uint256 strategiesNumber = withdrawalQueue.length;
        EulerEarnStrategyInfo[] memory strategies = new EulerEarnStrategyInfo[](strategiesNumber);
        for (uint256 i; i < strategiesNumber; i++) {
            IYieldAggregator.Strategy memory strategy = IYieldAggregator(vault).getStrategy(withdrawalQueue[i]);

            strategies[i] = EulerEarnStrategyInfo({
                startegy: withdrawalQueue[i],
                allocated: strategy.allocated,
                allocationPoints: strategy.allocationPoints,
                cap: uint120(strategy.cap.resolve()),
                isInEmergencyStatus: strategy.status == IYieldAggregator.StrategyStatus.Emergency
            });
        }

        return result;
    }
}
