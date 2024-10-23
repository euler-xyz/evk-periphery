// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {OracleLens} from "./OracleLens.sol";
import {UtilsLens} from "./UtilsLens.sol";
import "./IEulerEarn.sol"; // TODO: to be imported from the aggregator repo
import "./ConstantsLib.sol"; // TODO: to be imported from the aggregator repo
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
        result.vaultName = IEulerEarn(vault).name();
        result.vaultSymbol = IEulerEarn(vault).symbol();
        result.vaultDecimals = IEulerEarn(vault).decimals();

        result.asset = IEulerEarn(vault).asset();
        result.assetName = _getStringOrBytes32(result.asset, IEulerEarn(vault).name.selector);
        result.assetSymbol = _getStringOrBytes32(result.asset, IEulerEarn(vault).symbol.selector);
        result.assetDecimals = _getDecimals(result.asset);

        result.totalShares = IEulerEarn(vault).totalSupply();
        result.totalAssets = IEulerEarn(vault).totalAssets();
        result.totalAssetsDeposited = IEulerEarn(vault).totalAssetsDeposited();
        result.totalAssetsAllocated = IEulerEarn(vault).totalAllocated();
        result.totalAssetsAllocatable = IEulerEarn(vault).totalAssetsAllocatable();
        result.totalAllocationPoints = IEulerEarn(vault).totalAllocationPoints();
        result.interestAccrued = IEulerEarn(vault).interestAccrued();

        (result.lastInterestUpdate, result.interestSmearEnd, result.interestLeft) =
            IEulerEarn(vault).getEulerEarnSavingRate();

        result.lastHarvestTimestamp = IEulerEarn(vault).lastHarvestTimestamp();

        (result.feeReceiver, result.performanceFee) = IEulerEarn(vault).performanceFeeConfig();
        (result.hookTarget, result.hookedOperations) = IEulerEarn(vault).getHooksConfig();

        result.evc = IEulerEarn(vault).EVC();
        result.balanceTracker = IEulerEarn(vault).balanceTrackerAddress();
        result.permit2 = IEulerEarn(vault).permit2Address();
        result.isHarvestCoolDownCheckOn = IEulerEarn(vault).isCheckingHarvestCoolDown();

        result.accessControlInfo = getVaultAccessControlInfo(vault);

        address[] memory withdrawalQueue = IEulerEarn(vault).withdrawalQueue();
        result.strategies = new EulerEarnVaultStrategyInfo[](withdrawalQueue.length);

        for (uint256 i; i < withdrawalQueue.length; i++) {
            IEulerEarn.Strategy memory strategy = IEulerEarn(vault).getStrategy(withdrawalQueue[i]);

            result.strategies[i] = EulerEarnVaultStrategyInfo({
                strategy: withdrawalQueue[i],
                assetsAllocated: strategy.allocated,
                allocationPoints: strategy.allocationPoints,
                allocationCap: uint120(strategy.cap.resolve()),
                isInEmergency: strategy.status == IEulerEarn.StrategyStatus.Emergency
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
        result.eulerEarnManagerAdmins =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.EULER_EARN_MANAGER_ADMIN);
        result.withdrawalQueueManagerAdmins =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER_ADMIN);
        result.rebalancerAdmins =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.REBALANCER_ADMIN);

        result.guardians = AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.GUARDIAN);
        result.strategyOperators = AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.STRATEGY_OPERATOR);
        result.eulerEarnManagers =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.EULER_EARN_MANAGER);
        result.withdrawalQueueManagers =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER);
        result.rebalancers =
            AccessControlEnumerable(vault).getRoleMembers(ConstantsLib.REBALANCER);

        return result;
    }
}
