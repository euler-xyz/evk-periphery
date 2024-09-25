// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {OracleLens} from "./OracleLens.sol";
import {UtilsLens} from "./UtilsLens.sol";
import "./IYieldAggregator.sol"; // to be imported from the aggregator repo
import "./ConstantsLib.sol"; // to be imported from the aggregator repo
import {Utils} from "./Utils.sol";
import "evk/EVault/shared/types/AmountCap.sol";
import "./LensTypes.sol";

contract EulerEarnVaultLens is Utils {
    OracleLens public immutable oracleLens;
    UtilsLens public immutable utilsLens;
    address[] internal backupUnitOfAccounts;

    constructor(address _oracleLens, address _utilsLens) {
        oracleLens = OracleLens(_oracleLens);
        utilsLens = UtilsLens(_utilsLens);
        backupUnitOfAccounts = [address(840), _getWETHAddress(), 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB];
    }

    function getVaultInfoFull(address vault) public view returns (EulerEarnVaultInfoFull memory) {
        EulerEarnVaultInfoFull memory result;

        result.timestamp = block.timestamp;

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
        result.totalAssetsAllocated = IYieldAggregator(vault).totalAllocated();
        result.totalAssetsAllocatable = IYieldAggregator(vault).totalAssetsAllocatable();
        result.totalAllocationPoints = IYieldAggregator(vault).totalAllocationPoints();
        result.interestAccrued = IYieldAggregator(vault).interestAccrued();

        (result.lastInterestUpdate, result.interestSmearEnd, result.interestLeft) =
            IYieldAggregator(vault).getYieldAggregatorSavingRate();

        result.lastHarvestTimestamp = IYieldAggregator(vault).lastHarvestTimestamp();

        (result.feeReceiver, result.performanceFee) = IYieldAggregator(vault).performanceFeeConfig();
        (result.hookTarget, result.hookedOperations) = IYieldAggregator(vault).getHooksConfig();

        result.evc = IYieldAggregator(vault).EVC();
        result.balanceTracker = IYieldAggregator(vault).balanceTrackerAddress();
        result.permit2 = IYieldAggregator(vault).permit2Address();
        result.isHarvestCoolDownCheckOn = IYieldAggregator(vault).isHarvestCoolDownCheckOn();

        result.accessControlInfo = getVaultAccessControlInfo(vault);

        address[] memory withdrawalQueue = IYieldAggregator(vault).withdrawalQueue();
        result.strategies = new EulerEarnVaultStrategyInfo[](withdrawalQueue.length);

        for (uint256 i; i < withdrawalQueue.length; i++) {
            IYieldAggregator.Strategy memory strategy = IYieldAggregator(vault).getStrategy(withdrawalQueue[i]);

            result.strategies[i] = EulerEarnVaultStrategyInfo({
                strategy: withdrawalQueue[i],
                assetsAllocated: strategy.allocated,
                allocationPoints: strategy.allocationPoints,
                allocationCap: uint120(strategy.cap.resolve()),
                isInEmergency: strategy.status == IYieldAggregator.StrategyStatus.Emergency
            });
        }

        address[] memory bases = new address[](1);
        address[] memory quotes = new address[](1);
        for (uint256 i = 0; i < backupUnitOfAccounts.length; ++i) {
            bases[0] = result.asset;
            quotes[0] = backupUnitOfAccounts[i];

            result.backupAssetPriceInfo = utilsLens.getAssetPriceInfo(bases[0], quotes[0]);

            if (
                !result.backupAssetPriceInfo.queryFailure
                    || oracleLens.isStalePullOracle(
                        result.backupAssetPriceInfo.oracle, result.backupAssetPriceInfo.queryFailureReason
                    )
            ) {
                result.backupAssetOracleInfo =
                    oracleLens.getOracleInfo(result.backupAssetPriceInfo.oracle, bases, quotes);

                break;
            }
        }

        return result;
    }

    function getVaultAccessControlInfo(address vault) public view returns (EulerEarnVaultAccessControlInfo memory) {
        EulerEarnVaultAccessControlInfo memory result;

        result.defaultAdmins =
            AccessControlEnumerable(vault).getRoleMembers(AccessControlEnumerable(vault).DEFAULT_ADMIN_ROLE());
        result.guardianAdmins = AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.GUARDIAN_ADMIN);
        result.strategyOperatorAdmins =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.STRATEGY_OPERATOR_ADMIN);
        result.yieldAggregatorManagerAdmins =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.YIELD_AGGREGATOR_MANAGER_ADMIN);
        result.withdrawalQueueManagerAdmins =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER_ADMIN);

        result.guardians = AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.GUARDIAN);
        result.strategyOperators = AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.STRATEGY_OPERATOR);
        result.yieldAggregatorManagers =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.YIELD_AGGREGATOR_MANAGER);
        result.withdrawalQueueManagers =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER);

        return result;
    }
}
