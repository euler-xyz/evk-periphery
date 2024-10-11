// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

struct AccountInfo {
    EVCAccountInfo evcAccountInfo;
    VaultAccountInfo vaultAccountInfo;
    AccountRewardInfo accountRewardInfo;
}

struct AccountMultipleVaultsInfo {
    EVCAccountInfo evcAccountInfo;
    VaultAccountInfo[] vaultAccountInfo;
    AccountRewardInfo[] accountRewardInfo;
}

struct EVCAccountInfo {
    uint256 timestamp;
    address evc;
    address account;
    bytes19 addressPrefix;
    address owner;
    bool isLockdownMode;
    bool isPermitDisabledMode;
    uint256 lastAccountStatusCheckTimestamp;
    address[] enabledControllers;
    address[] enabledCollaterals;
}

struct VaultAccountInfo {
    uint256 timestamp;
    address account;
    address vault;
    address asset;
    uint256 assetsAccount;
    uint256 shares;
    uint256 assets;
    uint256 borrowed;
    uint256 assetAllowanceVault;
    uint256 assetAllowanceVaultPermit2;
    uint256 assetAllowanceExpirationVaultPermit2;
    uint256 assetAllowancePermit2;
    bool balanceForwarderEnabled;
    bool isController;
    bool isCollateral;
    AccountLiquidityInfo liquidityInfo;
}

struct AccountLiquidityInfo {
    bool queryFailure;
    bytes queryFailureReason;
    int256 timeToLiquidation;
    uint256 liabilityValue;
    uint256 collateralValueBorrowing;
    uint256 collateralValueLiquidation;
    uint256 collateralValueRaw;
    CollateralLiquidityInfo[] collateralLiquidityBorrowingInfo;
    CollateralLiquidityInfo[] collateralLiquidityLiquidationInfo;
    CollateralLiquidityInfo[] collateralLiquidityRawInfo;
}

struct CollateralLiquidityInfo {
    address collateral;
    uint256 collateralValue;
}

struct VaultInfoFull {
    uint256 timestamp;
    address vault;
    string vaultName;
    string vaultSymbol;
    uint256 vaultDecimals;
    address asset;
    string assetName;
    string assetSymbol;
    uint256 assetDecimals;
    address unitOfAccount;
    string unitOfAccountName;
    string unitOfAccountSymbol;
    uint256 unitOfAccountDecimals;
    uint256 totalShares;
    uint256 totalCash;
    uint256 totalBorrowed;
    uint256 totalAssets;
    uint256 accumulatedFeesShares;
    uint256 accumulatedFeesAssets;
    address governorFeeReceiver;
    address protocolFeeReceiver;
    uint256 protocolFeeShare;
    uint256 interestFee;
    uint256 hookedOperations;
    uint256 configFlags;
    uint256 supplyCap;
    uint256 borrowCap;
    uint256 maxLiquidationDiscount;
    uint256 liquidationCoolOffTime;
    address dToken;
    address oracle;
    address interestRateModel;
    address hookTarget;
    address evc;
    address protocolConfig;
    address balanceTracker;
    address permit2;
    address creator;
    address governorAdmin;
    VaultInterestRateModelInfo irmInfo;
    LTVInfo[] collateralLTVInfo;
    AssetPriceInfo liabilityPriceInfo;
    AssetPriceInfo[] collateralPriceInfo;
    OracleDetailedInfo oracleInfo;
    AssetPriceInfo backupAssetPriceInfo;
    OracleDetailedInfo backupAssetOracleInfo;
}

struct LTVInfo {
    address collateral;
    uint256 borrowLTV;
    uint256 liquidationLTV;
    uint256 initialLiquidationLTV;
    uint256 targetTimestamp;
    uint256 rampDuration;
}

struct AssetPriceInfo {
    bool queryFailure;
    bytes queryFailureReason;
    uint256 timestamp;
    address oracle;
    address asset;
    address unitOfAccount;
    uint256 amountIn;
    uint256 amountOutMid;
    uint256 amountOutBid;
    uint256 amountOutAsk;
}

struct VaultInterestRateModelInfo {
    bool queryFailure;
    bytes queryFailureReason;
    address vault;
    address interestRateModel;
    InterestRateInfo[] interestRateInfo;
    InterestRateModelDetailedInfo interestRateModelInfo;
}

struct InterestRateInfo {
    uint256 cash;
    uint256 borrows;
    uint256 borrowSPY;
    uint256 supplySPY;
    uint256 borrowAPY;
    uint256 supplyAPY;
}

enum InterestRateModelType {
    UNKNOWN,
    KINK
}

struct InterestRateModelDetailedInfo {
    address interestRateModel;
    InterestRateModelType interestRateModelType;
    bytes interestRateModelParams;
}

struct KinkIRMInfo {
    uint256 baseRate;
    uint256 slope1;
    uint256 slope2;
    uint256 kink;
}

struct AccountRewardInfo {
    uint256 timestamp;
    address account;
    address vault;
    address balanceTracker;
    bool balanceForwarderEnabled;
    uint256 balance;
    EnabledRewardInfo[] enabledRewardsInfo;
}

struct EnabledRewardInfo {
    address reward;
    uint256 earnedReward;
    uint256 earnedRewardRecentIgnored;
}

struct VaultRewardInfo {
    uint256 timestamp;
    address vault;
    address reward;
    string rewardName;
    string rewardSymbol;
    uint8 rewardDecimals;
    address balanceTracker;
    uint256 epochDuration;
    uint256 currentEpoch;
    uint256 totalRewardedEligible;
    uint256 totalRewardRegistered;
    uint256 totalRewardClaimed;
    RewardAmountInfo[] epochInfoPrevious;
    RewardAmountInfo[] epochInfoUpcoming;
}

struct RewardAmountInfo {
    uint256 epoch;
    uint256 epochStart;
    uint256 epochEnd;
    uint256 rewardAmount;
}

struct OracleDetailedInfo {
    address oracle;
    string name;
    bytes oracleInfo;
}

struct EulerRouterInfo {
    address governor;
    address fallbackOracle;
    OracleDetailedInfo fallbackOracleInfo;
    address[] bases;
    address[] quotes;
    address[][] resolvedAssets;
    address[] resolvedOracles;
    OracleDetailedInfo[] resolvedOraclesInfo;
}

struct ChainlinkOracleInfo {
    address base;
    address quote;
    address feed;
    string feedDescription;
    uint256 maxStaleness;
}

struct ChainlinkInfrequentOracleInfo {
    address base;
    address quote;
    address feed;
    string feedDescription;
    uint256 maxStaleness;
}

struct ChronicleOracleInfo {
    address base;
    address quote;
    address feed;
    uint256 maxStaleness;
}

struct LidoOracleInfo {
    address base;
    address quote;
}

struct LidoFundamentalOracleInfo {
    address base;
    address quote;
}

struct PythOracleInfo {
    address pyth;
    address base;
    address quote;
    bytes32 feedId;
    uint256 maxStaleness;
    uint256 maxConfWidth;
}

struct RedstoneCoreOracleInfo {
    address base;
    address quote;
    bytes32 feedId;
    uint8 feedDecimals;
    uint256 maxStaleness;
    uint208 cachePrice;
    uint48 cachePriceTimestamp;
}

struct UniswapV3OracleInfo {
    address tokenA;
    address tokenB;
    address pool;
    uint24 fee;
    uint32 twapWindow;
}

struct FixedRateOracleInfo {
    address base;
    address quote;
    uint256 rate;
}

struct RateProviderOracleInfo {
    address base;
    address quote;
    address rateProvider;
}

struct CrossAdapterInfo {
    address base;
    address cross;
    address quote;
    address oracleBaseCross;
    address oracleCrossQuote;
    OracleDetailedInfo oracleBaseCrossInfo;
    OracleDetailedInfo oracleCrossQuoteInfo;
}

struct EulerEarnVaultInfoFull {
    uint256 timestamp;
    address vault;
    string vaultName;
    string vaultSymbol;
    uint256 vaultDecimals;
    address asset;
    string assetName;
    string assetSymbol;
    uint256 assetDecimals;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 totalAssetsDeposited;
    uint256 totalAssetsAllocated;
    uint256 totalAssetsAllocatable;
    uint256 totalAllocationPoints;
    uint256 interestAccrued;
    uint256 lastInterestUpdate;
    uint256 interestSmearEnd;
    uint256 interestLeft;
    uint256 lastHarvestTimestamp;
    uint256 performanceFee;
    address feeReceiver;
    uint256 hookedOperations;
    address hookTarget;
    address evc;
    address balanceTracker;
    address permit2;
    bool isHarvestCoolDownCheckOn;
    EulerEarnVaultAccessControlInfo accessControlInfo;
    EulerEarnVaultStrategyInfo[] strategies;
    AssetPriceInfo backupAssetPriceInfo;
    OracleDetailedInfo backupAssetOracleInfo;
}

struct EulerEarnVaultAccessControlInfo {
    address[] defaultAdmins;
    address[] guardianAdmins;
    address[] strategyOperatorAdmins;
    address[] yieldAggregatorManagerAdmins;
    address[] withdrawalQueueManagerAdmins;
    address[] guardians;
    address[] strategyOperators;
    address[] yieldAggregatorManagers;
    address[] withdrawalQueueManagers;
}

struct EulerEarnVaultStrategyInfo {
    address strategy;
    uint256 assetsAllocated;
    uint256 allocationPoints;
    uint256 allocationCap;
    bool isInEmergency;
}
