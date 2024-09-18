// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IIRM, IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {IPriceOracle} from "evk/interfaces/IPriceOracle.sol";
import {OracleLens} from "./OracleLens.sol";
import {IRMLens} from "./IRMLens.sol";
import {Utils} from "./Utils.sol";
import "evk/EVault/shared/types/AmountCap.sol";
import "./LensTypes.sol";

contract VaultLens is Utils {
    OracleLens public immutable oracleLens;
    IRMLens public immutable irmLens;
    address[] internal backupUnitOfAccounts;

    constructor(address _oracleLens, address _irmLens) {
        oracleLens = OracleLens(_oracleLens);
        irmLens = IRMLens(_irmLens);
        backupUnitOfAccounts = [address(840), _getWETHAddress(), 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB];
    }

    function getVaultInfoFull(address vault) public view returns (VaultInfoFull memory) {
        VaultInfoFull memory result;

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

        result.dToken = IEVault(vault).dToken();
        result.oracle = IEVault(vault).oracle();
        result.interestRateModel = IEVault(vault).interestRateModel();

        result.evc = IEVault(vault).EVC();
        result.protocolConfig = IEVault(vault).protocolConfigAddress();
        result.balanceTracker = IEVault(vault).balanceTrackerAddress();
        result.permit2 = IEVault(vault).permit2Address();

        result.creator = IEVault(vault).creator();
        result.governorAdmin = IEVault(vault).governorAdmin();

        uint256[] memory cash = new uint256[](1);
        uint256[] memory borrows = new uint256[](1);
        cash[0] = result.totalCash;
        borrows[0] = result.totalBorrowed;
        result.irmInfo = getVaultInterestRateModelInfo(vault, cash, borrows);

        result.collateralLTVInfo = getRecognizedCollateralsLTVInfo(vault);

        result.liabilityPriceInfo = getControllerAssetPriceInfo(vault, result.asset);

        result.collateralPriceInfo = new AssetPriceInfo[](result.collateralLTVInfo.length);

        address[] memory bases = new address[](result.collateralLTVInfo.length + 1);
        address[] memory quotes = new address[](result.collateralLTVInfo.length + 1);
        bases[0] = result.asset;
        quotes[0] = result.unitOfAccount;
        for (uint256 i = 0; i < result.collateralLTVInfo.length; ++i) {
            bases[i + 1] = result.collateralLTVInfo[i].collateral;
            quotes[i + 1] = result.unitOfAccount;
            result.collateralPriceInfo[i] = getControllerAssetPriceInfo(vault, result.collateralLTVInfo[i].collateral);
        }

        result.oracleInfo = oracleLens.getOracleInfo(result.oracle, bases, quotes);

        if (result.oracle == address(0)) {
            for (uint256 i = 0; i < backupUnitOfAccounts.length + 1; ++i) {
                bases = new address[](1);
                quotes = new address[](1);
                bases[0] = result.asset;

                if (i == 0) {
                    if (result.unitOfAccount == address(0)) continue;

                    quotes[0] = result.unitOfAccount;
                } else {
                    quotes[0] = backupUnitOfAccounts[i - 1];
                }

                result.backupAssetPriceInfo = getAssetPriceInfo(bases[0], quotes[0]);

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

            result.interestRateInfo[i].supplySPY =
                _computeSupplySPY(result.interestRateInfo[i].borrowSPY, cash[i], borrows[i], interestFee);

            (result.interestRateInfo[i].borrowAPY, result.interestRateInfo[i].supplyAPY) =
                _computeAPYs(result.interestRateInfo[i].borrowSPY, result.interestRateInfo[i].supplySPY);
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

    function getControllerAssetPriceInfo(address controller, address asset)
        public
        view
        returns (AssetPriceInfo memory)
    {
        AssetPriceInfo memory result;

        result.timestamp = block.timestamp;

        result.oracle = IEVault(controller).oracle();
        result.asset = asset;
        result.unitOfAccount = IEVault(controller).unitOfAccount();

        result.amountIn = 10 ** _getDecimals(asset);

        if (result.oracle == address(0)) {
            result.queryFailure = true;
            return result;
        }

        (bool success, bytes memory data) = result.oracle.staticcall(
            abi.encodeCall(IPriceOracle.getQuote, (result.amountIn, asset, result.unitOfAccount))
        );

        if (success && data.length >= 32) {
            result.amountOutMid = abi.decode(data, (uint256));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        (success, data) = result.oracle.staticcall(
            abi.encodeCall(IPriceOracle.getQuotes, (result.amountIn, asset, result.unitOfAccount))
        );

        if (success && data.length >= 64) {
            (result.amountOutBid, result.amountOutAsk) = abi.decode(data, (uint256, uint256));
        } else {
            result.queryFailure = true;
        }

        return result;
    }

    function getAssetPriceInfo(address asset, address unitOfAccount) public view returns (AssetPriceInfo memory) {
        AssetPriceInfo memory result;

        result.timestamp = block.timestamp;

        result.asset = asset;
        result.unitOfAccount = unitOfAccount;

        result.amountIn = 10 ** _getDecimals(asset);

        address[] memory adapters = oracleLens.getValidAdapters(asset, unitOfAccount);
        uint256 amountIn = result.amountIn;

        if (adapters.length == 0) {
            (bool success, bytes memory data) =
                asset.staticcall(abi.encodeCall(IEVault(asset).convertToAssets, (amountIn)));

            if (success && data.length >= 32) {
                amountIn = abi.decode(data, (uint256));
                (success, data) = asset.staticcall(abi.encodeCall(IEVault(asset).asset, ()));

                if (success && data.length >= 32) {
                    asset = abi.decode(data, (address));
                    adapters = oracleLens.getValidAdapters(asset, unitOfAccount);
                }
            }
        }

        if (adapters.length == 0) {
            result.queryFailure = true;
            return result;
        }

        for (uint256 i = 0; i < adapters.length; ++i) {
            result.oracle = adapters[i];

            (bool success, bytes memory data) =
                result.oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (amountIn, asset, unitOfAccount)));

            if (success && data.length >= 32) {
                result.amountOutMid = abi.decode(data, (uint256));
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }

            (success, data) =
                result.oracle.staticcall(abi.encodeCall(IPriceOracle.getQuotes, (amountIn, asset, unitOfAccount)));

            if (success && data.length >= 64) {
                (result.amountOutBid, result.amountOutAsk) = abi.decode(data, (uint256, uint256));
            } else {
                result.queryFailure = true;
            }

            if (!result.queryFailure) break;
        }

        return result;
    }
}
