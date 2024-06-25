// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./LensTypes.sol";

contract DecodeLensTypes {
    function getAccountInfo() public pure returns (AccountInfo memory accountInfo) {}

    function getAccountMultipleVaultsInfo()
        public
        pure
        returns (AccountMultipleVaultsInfo memory accountMultipleVaultsInfo)
    {}

    function getEVCAccountInfo() public pure returns (EVCAccountInfo memory evcAccountInfo) {}

    function getVaultAccountInfo() public pure returns (VaultAccountInfo memory vaultAccountInfo) {}

    function getAccountLiquidityInfo() public pure returns (AccountLiquidityInfo memory accountLiquidityInfo) {}

    function getCollateralLiquidityInfo()
        public
        pure
        returns (CollateralLiquidityInfo memory collateralLiquidityInfo)
    {}

    function getVaultInfoSimple() public pure returns (VaultInfoSimple memory vaultInfoSimple) {}

    function getVaultInfoFull() public pure returns (VaultInfoFull memory vaultInfoFull) {}

    function getLTVInfo() public pure returns (LTVInfo memory ltvInfo) {}

    function getAssetPriceInfo() public pure returns (AssetPriceInfo memory assetPriceInfo) {}

    function getVaultInterestRateModelInfo()
        public
        pure
        returns (VaultInterestRateModelInfo memory vaultInterestRateModelInfo)
    {}

    function getInterestRateInfo() public pure returns (InterestRateInfo memory interestRateInfo) {}

    function getAccountRewardInfo() public pure returns (AccountRewardInfo memory accountRewardInfo) {}

    function getEnabledRewardInfo() public pure returns (EnabledRewardInfo memory enabledRewardInfo) {}

    function getVaultRewardInfo() public pure returns (VaultRewardInfo memory vaultRewardInfo) {}

    function getRewardAmountInfo() public pure returns (RewardAmountInfo memory rewardAmountInfo) {}

    function getOracleDetailedInfo() public pure returns (OracleDetailedInfo memory oracleDetailedInfo) {}

    function getEulerRouterInfo() public pure returns (EulerRouterInfo memory eulerRouterInfo) {}

    function getChainlinkOracleInfo() public pure returns (ChainlinkOracleInfo memory chainlinkOracleInfo) {}

    function getChronicleOracleInfo() public pure returns (ChronicleOracleInfo memory chronicleOracleInfo) {}

    function getLidoOracleInfo() public pure returns (LidoOracleInfo memory lidoOracleInfo) {}

    function getPythOracleInfo() public pure returns (PythOracleInfo memory pythOracleInfo) {}

    function getRedstoneCoreOracleInfo() public pure returns (RedstoneCoreOracleInfo memory redstoneCoreOracleInfo) {}

    function getUniswapV3OracleInfo() public pure returns (UniswapV3OracleInfo memory uniswapV3OracleInfo) {}

    function getCrossAdapterInfo() public pure returns (CrossAdapterInfo memory crossAdapterInfo) {}
}
