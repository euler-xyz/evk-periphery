// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IIRM, IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {OracleLens} from "./OracleLens.sol";
import {UtilsLens} from "./UtilsLens.sol";
import {IRMLens} from "./IRMLens.sol";
import {Utils} from "./Utils.sol";
import "evk/EVault/shared/types/AmountCap.sol";
import "./LensTypes.sol";

contract VaultLens is Utils {
    OracleLens public immutable oracleLens;
    UtilsLens public immutable utilsLens;
    IRMLens public immutable irmLens;
    address[] internal backupUnitOfAccounts;

    constructor(address _oracleLens, address _utilsLens, address _irmLens) {
        oracleLens = OracleLens(_oracleLens);
        utilsLens = UtilsLens(_utilsLens);
        irmLens = IRMLens(_irmLens);

        address WETH = getWETHAddress();
        backupUnitOfAccounts.push(address(840));
        if (WETH != address(0)) backupUnitOfAccounts.push(WETH);
        backupUnitOfAccounts.push(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB);
    }

    function getVaultInfoStatic(address vault) public view returns (VaultInfoStatic memory) {
        VaultInfoStatic memory result;

        result.timestamp = block.timestamp;
        result.vault = vault;

        result.vaultName = IEVault(vault).name();
        result.vaultSymbol = IEVault(vault).symbol();
        result.vaultDecimals = IEVault(vault).decimals();

        result.asset = IEVault(vault).asset();
        result.assetName = _getStringOrBytes32(result.asset, IEVault(vault).name.selector);
        result.assetSymbol = _getStringOrBytes32(result.asset, IEVault(vault).symbol.selector);
        result.assetDecimals = _getDecimals(result.asset);

        result.unitOfAccount = IEVault(vault).unitOfAccount();
        result.unitOfAccountName = _getStringOrBytes32(result.unitOfAccount, IEVault(vault).name.selector);
        result.unitOfAccountSymbol = _getStringOrBytes32(result.unitOfAccount, IEVault(vault).symbol.selector);
        result.unitOfAccountDecimals = _getDecimals(result.unitOfAccount);

        result.dToken = IEVault(vault).dToken();
        result.oracle = IEVault(vault).oracle();
        result.evc = IEVault(vault).EVC();
        result.protocolConfig = IEVault(vault).protocolConfigAddress();
        result.balanceTracker = IEVault(vault).balanceTrackerAddress();
        result.permit2 = IEVault(vault).permit2Address();
        result.creator = IEVault(vault).creator();

        return result;
    }

    function getVaultInfoDynamic(address vault) public view returns (VaultInfoDynamic memory) {
        VaultInfoDynamic memory result;

        address asset = IEVault(vault).asset();
        address unitOfAccount = IEVault(vault).unitOfAccount();
        address oracle = IEVault(vault).oracle();

        result.timestamp = block.timestamp;
        result.vault = vault;

        result.totalShares = IEVault(vault).totalSupply();
        result.totalCash = IEVault(vault).cash();
        result.totalBorrowed = IEVault(vault).totalBorrows();
        result.totalAssets = IEVault(vault).totalAssets();

        result.accumulatedFeesShares = IEVault(vault).accumulatedFees();
        result.accumulatedFeesAssets = IEVault(vault).accumulatedFeesAssets();

        result.governorFeeReceiver = IEVault(vault).feeReceiver();
        result.protocolFeeReceiver = IEVault(vault).protocolFeeReceiver();
        result.protocolFeeShare = IEVault(vault).protocolFeeShare();
        result.interestFee = IEVault(vault).interestFee();

        (result.hookTarget, result.hookedOperations) = IEVault(vault).hookConfig();
        result.configFlags = IEVault(vault).configFlags();

        result.maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
        result.liquidationCoolOffTime = IEVault(vault).liquidationCoolOffTime();

        (result.supplyCap, result.borrowCap) = IEVault(vault).caps();
        result.supplyCap = AmountCapLib.resolve(AmountCap.wrap(uint16(result.supplyCap)));
        result.borrowCap = AmountCapLib.resolve(AmountCap.wrap(uint16(result.borrowCap)));

        result.interestRateModel = IEVault(vault).interestRateModel();
        result.governorAdmin = IEVault(vault).governorAdmin();

        if (result.interestRateModel == address(0)) {
            result.irmInfo.queryFailure = true;
        } else {
            result.irmInfo.vault = vault;
            result.irmInfo.interestRateModel = result.interestRateModel;
            result.irmInfo.interestRateInfo = new InterestRateInfo[](1);
            result.irmInfo.interestRateInfo[0].cash = result.totalCash;
            result.irmInfo.interestRateInfo[0].borrows = result.totalBorrowed;
            result.irmInfo.interestRateInfo[0].borrowSPY = IEVault(vault).interestRate();
            (result.irmInfo.interestRateInfo[0].borrowAPY, result.irmInfo.interestRateInfo[0].supplyAPY) = _computeAPYs(
                result.irmInfo.interestRateInfo[0].borrowSPY, result.totalCash, result.totalBorrowed, result.interestFee
            );
            result.irmInfo.interestRateModelInfo = irmLens.getInterestRateModelInfo(result.interestRateModel);
        }

        result.collateralLTVInfo = getRecognizedCollateralsLTVInfo(vault);

        result.liabilityPriceInfo = utilsLens.getControllerAssetPriceInfo(vault, asset);

        result.collateralPriceInfo = new AssetPriceInfo[](result.collateralLTVInfo.length);

        address[] memory bases = new address[](result.collateralLTVInfo.length + 1);
        address[] memory quotes = new address[](result.collateralLTVInfo.length + 1);
        bases[0] = asset;
        quotes[0] = unitOfAccount;
        for (uint256 i = 0; i < result.collateralLTVInfo.length; ++i) {
            bases[i + 1] = result.collateralLTVInfo[i].collateral;
            quotes[i + 1] = unitOfAccount;
            result.collateralPriceInfo[i] =
                utilsLens.getControllerAssetPriceInfo(vault, result.collateralLTVInfo[i].collateral);
        }

        result.oracleInfo = oracleLens.getOracleInfo(oracle, bases, quotes);

        bases = new address[](1);
        quotes = new address[](1);
        if (oracle == address(0)) {
            for (uint256 i = 0; i < backupUnitOfAccounts.length + 1; ++i) {
                bases[0] = asset;

                if (i == 0) {
                    if (unitOfAccount == address(0)) continue;

                    quotes[0] = unitOfAccount;
                } else {
                    quotes[0] = backupUnitOfAccounts[i - 1];
                }

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
        }

        return result;
    }

    function getVaultInfoFull(address vault) public view returns (VaultInfoFull memory) {
        VaultInfoStatic memory staticInfo = getVaultInfoStatic(vault);
        VaultInfoDynamic memory dynamicInfo = getVaultInfoDynamic(vault);

        VaultInfoFull memory result;

        // From VaultInfoStatic
        result.timestamp = staticInfo.timestamp;
        result.vault = staticInfo.vault;
        result.vaultName = staticInfo.vaultName;
        result.vaultSymbol = staticInfo.vaultSymbol;
        result.vaultDecimals = staticInfo.vaultDecimals;
        result.asset = staticInfo.asset;
        result.assetName = staticInfo.assetName;
        result.assetSymbol = staticInfo.assetSymbol;
        result.assetDecimals = staticInfo.assetDecimals;
        result.unitOfAccount = staticInfo.unitOfAccount;
        result.unitOfAccountName = staticInfo.unitOfAccountName;
        result.unitOfAccountSymbol = staticInfo.unitOfAccountSymbol;
        result.unitOfAccountDecimals = staticInfo.unitOfAccountDecimals;
        result.dToken = staticInfo.dToken;
        result.oracle = staticInfo.oracle;
        result.evc = staticInfo.evc;
        result.protocolConfig = staticInfo.protocolConfig;
        result.balanceTracker = staticInfo.balanceTracker;
        result.permit2 = staticInfo.permit2;
        result.creator = staticInfo.creator;

        // From VaultInfoDynamic
        result.totalShares = dynamicInfo.totalShares;
        result.totalCash = dynamicInfo.totalCash;
        result.totalBorrowed = dynamicInfo.totalBorrowed;
        result.totalAssets = dynamicInfo.totalAssets;
        result.accumulatedFeesShares = dynamicInfo.accumulatedFeesShares;
        result.accumulatedFeesAssets = dynamicInfo.accumulatedFeesAssets;
        result.governorFeeReceiver = dynamicInfo.governorFeeReceiver;
        result.protocolFeeReceiver = dynamicInfo.protocolFeeReceiver;
        result.protocolFeeShare = dynamicInfo.protocolFeeShare;
        result.interestFee = dynamicInfo.interestFee;
        result.hookedOperations = dynamicInfo.hookedOperations;
        result.configFlags = dynamicInfo.configFlags;
        result.supplyCap = dynamicInfo.supplyCap;
        result.borrowCap = dynamicInfo.borrowCap;
        result.maxLiquidationDiscount = dynamicInfo.maxLiquidationDiscount;
        result.liquidationCoolOffTime = dynamicInfo.liquidationCoolOffTime;
        result.interestRateModel = dynamicInfo.interestRateModel;
        result.hookTarget = dynamicInfo.hookTarget;
        result.governorAdmin = dynamicInfo.governorAdmin;
        result.irmInfo = dynamicInfo.irmInfo;
        result.collateralLTVInfo = dynamicInfo.collateralLTVInfo;
        result.liabilityPriceInfo = dynamicInfo.liabilityPriceInfo;
        result.collateralPriceInfo = dynamicInfo.collateralPriceInfo;
        result.oracleInfo = dynamicInfo.oracleInfo;
        result.backupAssetPriceInfo = dynamicInfo.backupAssetPriceInfo;
        result.backupAssetOracleInfo = dynamicInfo.backupAssetOracleInfo;

        return result;
    }

    function getRewardVaultInfo(address vault, address reward, uint256 numberOfEpochs)
        public
        view
        returns (VaultRewardInfo memory)
    {
        VaultRewardInfo memory result;

        result.timestamp = block.timestamp;

        result.vault = vault;
        result.reward = reward;
        result.rewardName = _getStringOrBytes32(result.reward, IEVault(vault).name.selector);
        result.rewardSymbol = _getStringOrBytes32(result.reward, IEVault(vault).symbol.selector);
        result.rewardDecimals = _getDecimals(result.reward);
        result.balanceTracker = IEVault(vault).balanceTrackerAddress();

        if (result.balanceTracker == address(0)) return result;

        result.epochDuration = IRewardStreams(result.balanceTracker).EPOCH_DURATION();
        result.currentEpoch = IRewardStreams(result.balanceTracker).currentEpoch();
        result.totalRewardedEligible = IRewardStreams(result.balanceTracker).totalRewardedEligible(vault, reward);
        result.totalRewardRegistered = IRewardStreams(result.balanceTracker).totalRewardRegistered(vault, reward);
        result.totalRewardClaimed = IRewardStreams(result.balanceTracker).totalRewardClaimed(vault, reward);

        result.epochInfoPrevious = new RewardAmountInfo[](numberOfEpochs);
        result.epochInfoUpcoming = new RewardAmountInfo[](numberOfEpochs);

        for (uint256 i; i < 2 * numberOfEpochs; ++i) {
            uint48 epoch = uint48(result.currentEpoch - numberOfEpochs + i);

            if (i < numberOfEpochs) {
                uint256 index = i;

                result.epochInfoPrevious[index].epoch = epoch;

                result.epochInfoPrevious[index].epochStart =
                    IRewardStreams(result.balanceTracker).getEpochStartTimestamp(epoch);

                result.epochInfoPrevious[index].epochEnd =
                    IRewardStreams(result.balanceTracker).getEpochEndTimestamp(epoch);

                result.epochInfoPrevious[index].rewardAmount =
                    IRewardStreams(result.balanceTracker).rewardAmount(vault, reward, epoch);
            } else {
                uint256 index = i - numberOfEpochs;

                result.epochInfoUpcoming[index].epoch = epoch;

                result.epochInfoUpcoming[index].epochStart =
                    IRewardStreams(result.balanceTracker).getEpochStartTimestamp(epoch);

                result.epochInfoUpcoming[index].epochEnd =
                    IRewardStreams(result.balanceTracker).getEpochEndTimestamp(epoch);

                result.epochInfoUpcoming[index].rewardAmount =
                    IRewardStreams(result.balanceTracker).rewardAmount(vault, reward, epoch);
            }
        }

        return result;
    }

    function getRecognizedCollateralsLTVInfo(address vault) public view returns (LTVInfo[] memory) {
        address[] memory collaterals = IEVault(vault).LTVList();
        LTVInfo[] memory ltvInfo = new LTVInfo[](collaterals.length);
        uint256 numberOfRecognizedCollaterals = 0;

        for (uint256 i = 0; i < collaterals.length; ++i) {
            ltvInfo[i].collateral = collaterals[i];

            (
                ltvInfo[i].borrowLTV,
                ltvInfo[i].liquidationLTV,
                ltvInfo[i].initialLiquidationLTV,
                ltvInfo[i].targetTimestamp,
                ltvInfo[i].rampDuration
            ) = IEVault(vault).LTVFull(collaterals[i]);

            if (ltvInfo[i].targetTimestamp != 0) {
                ++numberOfRecognizedCollaterals;
            }
        }

        LTVInfo[] memory collateralLTVInfo = new LTVInfo[](numberOfRecognizedCollaterals);

        for (uint256 i = 0; i < collaterals.length; ++i) {
            if (ltvInfo[i].targetTimestamp != 0) {
                collateralLTVInfo[i] = ltvInfo[i];
            }
        }

        return collateralLTVInfo;
    }

    function getVaultInterestRateModelInfo(address vault, uint256[] memory cash, uint256[] memory borrows)
        public
        view
        returns (VaultInterestRateModelInfo memory)
    {
        require(cash.length == borrows.length, "VaultLens: invalid input");

        VaultInterestRateModelInfo memory result;

        result.vault = vault;
        result.interestRateModel = IEVault(vault).interestRateModel();

        if (result.interestRateModel == address(0)) {
            result.queryFailure = true;
            return result;
        }

        uint256 interestFee = IEVault(vault).interestFee();
        result.interestRateInfo = new InterestRateInfo[](cash.length);

        for (uint256 i = 0; i < cash.length; ++i) {
            (bool success, bytes memory data) = result.interestRateModel.staticcall(
                abi.encodeCall(IIRM.computeInterestRateView, (vault, cash[i], borrows[i]))
            );

            if (!success || data.length < 32) {
                result.queryFailure = true;
                result.queryFailureReason = data;
                break;
            }

            result.interestRateInfo[i].cash = cash[i];
            result.interestRateInfo[i].borrows = borrows[i];
            result.interestRateInfo[i].borrowSPY = abi.decode(data, (uint256));
            (result.interestRateInfo[i].borrowAPY, result.interestRateInfo[i].supplyAPY) =
                _computeAPYs(result.interestRateInfo[i].borrowSPY, cash[i], borrows[i], interestFee);
        }

        result.interestRateModelInfo = irmLens.getInterestRateModelInfo(result.interestRateModel);

        return result;
    }

    function getVaultKinkInterestRateModelInfo(address vault) public view returns (VaultInterestRateModelInfo memory) {
        address interestRateModel = IEVault(vault).interestRateModel();

        if (interestRateModel == address(0)) {
            VaultInterestRateModelInfo memory result;
            result.vault = vault;
            return result;
        }

        uint256 kink = IRMLinearKink(interestRateModel).kink();
        uint256[] memory cash = new uint256[](3);
        uint256[] memory borrows = new uint256[](3);

        cash[0] = type(uint32).max;
        cash[1] = type(uint32).max - kink;
        cash[2] = 0;
        borrows[0] = 0;
        borrows[1] = kink;
        borrows[2] = type(uint32).max;

        return getVaultInterestRateModelInfo(vault, cash, borrows);
    }
}
