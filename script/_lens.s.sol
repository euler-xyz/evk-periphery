// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {AccountLens} from "../src/Lens/AccountLens.sol";
import {VaultLens} from "../src/Lens/VaultLens.sol";
import "../src/Lens/LensTypes.sol";

contract UseLens is ScriptUtils {
    function run() public {
        string memory json = vm.readFile(string.concat(vm.projectRoot(), "/script/", "_lens.json"));
        address accountLens = abi.decode(vm.parseJson(json, ".accountLens"), (address));
        address vaultLens = abi.decode(vm.parseJson(json, ".vaultLens"), (address));
        address account = abi.decode(vm.parseJson(json, ".account"), (address));
        address vault = abi.decode(vm.parseJson(json, ".vault"), (address));
        uint256 optionId = abi.decode(vm.parseJson(json, ".optionId"), (uint256));

        if (optionId == 0) {
            AccountInfo memory result = AccountLens(accountLens).getAccountInfo(account, vault);
            vm.writeJson(serializeAccountInfo(result), string.concat(vm.projectRoot(), "/script/", "_lens_result.json"));
        } else if (optionId == 1) {
            VaultInfoFull memory result = VaultLens(vaultLens).getVaultInfoFull(vault);
            vm.writeJson(
                serializeVaultFullInfo(result), string.concat(vm.projectRoot(), "/script/", "_lens_result.json")
            );
        } else {
            revert("Invalid optionId");
        }
    }

    function serializeAccountInfo(AccountInfo memory result) internal returns (string memory) {
        string memory object;
        object = vm.serializeString("accountInfo", "evcAccountInfo", serializeEVCAccountInfo(result.evcAccountInfo));
        object =
            vm.serializeString("accountInfo", "vaultAccountInfo", serializeVaultAccountInfo(result.vaultAccountInfo));
        object =
            vm.serializeString("accountInfo", "accountRewardInfo", serializeAccountRewardInfo(result.accountRewardInfo));
        return object;
    }

    function serializeEVCAccountInfo(EVCAccountInfo memory result) internal returns (string memory) {
        string memory object;
        object = vm.serializeUint("evcAccountInfo", "timestamp", result.timestamp);
        object = vm.serializeUint("evcAccountInfo", "blockNumber", result.blockNumber);
        object = vm.serializeAddress("evcAccountInfo", "evc", result.evc);
        object = vm.serializeAddress("evcAccountInfo", "account", result.account);
        object = vm.serializeBytes32("evcAccountInfo", "addressPrefix", bytes32(result.addressPrefix));
        object = vm.serializeAddress("evcAccountInfo", "owner", result.owner);
        object = vm.serializeBool("evcAccountInfo", "isLockdownMode", result.isLockdownMode);
        object = vm.serializeBool("evcAccountInfo", "isPermitDisabledMode", result.isPermitDisabledMode);
        object = vm.serializeUint(
            "evcAccountInfo", "lastAccountStatusCheckTimestamp", result.lastAccountStatusCheckTimestamp
        );
        object = vm.serializeAddress("evcAccountInfo", "enabledControllers", result.enabledControllers);
        object = vm.serializeAddress("evcAccountInfo", "enabledCollaterals", result.enabledCollaterals);
        return object;
    }

    function serializeVaultAccountInfo(VaultAccountInfo memory result) internal returns (string memory) {
        string memory object;
        object = vm.serializeUint("vaultAccountInfo", "timestamp", result.timestamp);
        object = vm.serializeUint("vaultAccountInfo", "blockNumber", result.blockNumber);
        object = vm.serializeAddress("vaultAccountInfo", "account", result.account);
        object = vm.serializeAddress("vaultAccountInfo", "vault", result.vault);
        object = vm.serializeAddress("vaultAccountInfo", "asset", result.asset);
        object = vm.serializeUint("vaultAccountInfo", "assetsAccount", result.assetsAccount);
        object = vm.serializeUint("vaultAccountInfo", "shares", result.shares);
        object = vm.serializeUint("vaultAccountInfo", "assets", result.assets);
        object = vm.serializeUint("vaultAccountInfo", "borrowed", result.borrowed);
        object = vm.serializeUint("vaultAccountInfo", "assetAllowanceVault", result.assetAllowanceVault);
        object = vm.serializeUint("vaultAccountInfo", "assetAllowanceVaultPermit2", result.assetAllowanceVaultPermit2);
        object = vm.serializeUint(
            "vaultAccountInfo", "assetAllowanceExpirationVaultPermit2", result.assetAllowanceExpirationVaultPermit2
        );
        object = vm.serializeUint("vaultAccountInfo", "assetAllowancePermit2", result.assetAllowancePermit2);
        object = vm.serializeBool("vaultAccountInfo", "balanceForwarderEnabled", result.balanceForwarderEnabled);
        object = vm.serializeBool("vaultAccountInfo", "isController", result.isController);
        object = vm.serializeBool("vaultAccountInfo", "isCollateral", result.isCollateral);

        string memory object2;
        object2 = vm.serializeInt("liquidityInfo", "timeToLiquidation", result.liquidityInfo.timeToLiquidation);
        object2 = vm.serializeUint("liquidityInfo", "liabilityValue", result.liquidityInfo.liabilityValue);
        object2 =
            vm.serializeUint("liquidityInfo", "collateralValueBorrowing", result.liquidityInfo.collateralValueBorrowing);
        object2 = vm.serializeUint(
            "liquidityInfo", "collateralValueLiquidation", result.liquidityInfo.collateralValueLiquidation
        );
        object = vm.serializeString("vaultAccountInfo", "liquidityInfo", object2);

        object = vm.serializeString("vaultAccountInfo", "collateralLiquidityBorrowingInfo", "unknown");
        object = vm.serializeString("vaultAccountInfo", "collateralLiquidityLiquidationInfo", "unknown");

        return object;
    }

    function serializeAccountRewardInfo(AccountRewardInfo memory result) internal returns (string memory) {
        string memory object;
        object = vm.serializeUint("accountRewardInfo", "timestamp", result.timestamp);
        object = vm.serializeUint("accountRewardInfo", "blockNumber", result.blockNumber);
        object = vm.serializeAddress("accountRewardInfo", "account", result.account);
        object = vm.serializeAddress("accountRewardInfo", "vault", result.vault);
        object = vm.serializeAddress("accountRewardInfo", "balanceTracker", result.balanceTracker);
        object = vm.serializeBool("accountRewardInfo", "balanceForwarderEnabled", result.balanceForwarderEnabled);
        object = vm.serializeUint("accountRewardInfo", "balance", result.balance);

        object = vm.serializeString("accountRewardInfo", "enabledRewardsInfo", "unknown");

        return object;
    }

    function serializeVaultFullInfo(VaultInfoFull memory result) internal returns (string memory) {
        string memory object;
        object = vm.serializeUint("vaultInfo", "timestamp", result.timestamp);
        object = vm.serializeUint("vaultInfo", "blockNumber", result.blockNumber);
        object = vm.serializeAddress("vaultInfo", "vault", result.vault);
        object = vm.serializeString("vaultInfo", "vaultName", result.vaultName);
        object = vm.serializeString("vaultInfo", "vaultSymbol", result.vaultSymbol);
        object = vm.serializeUint("vaultInfo", "vaultDecimals", result.vaultDecimals);
        object = vm.serializeAddress("vaultInfo", "asset", result.asset);
        object = vm.serializeString("vaultInfo", "assetName", result.assetName);
        object = vm.serializeString("vaultInfo", "assetSymbol", result.assetSymbol);
        object = vm.serializeUint("vaultInfo", "assetDecimals", result.assetDecimals);
        object = vm.serializeAddress("vaultInfo", "unitOfAccount", result.unitOfAccount);
        object = vm.serializeString("vaultInfo", "unitOfAccountName", result.unitOfAccountName);
        object = vm.serializeString("vaultInfo", "unitOfAccountSymbol", result.unitOfAccountSymbol);
        object = vm.serializeUint("vaultInfo", "unitOfAccountDecimals", result.unitOfAccountDecimals);
        object = vm.serializeUint("vaultInfo", "totalShares", result.totalShares);
        object = vm.serializeUint("vaultInfo", "totalCash", result.totalCash);
        object = vm.serializeUint("vaultInfo", "totalBorrowed", result.totalBorrowed);
        object = vm.serializeUint("vaultInfo", "totalAssets", result.totalAssets);
        object = vm.serializeUint("vaultInfo", "accumulatedFeesShares", result.accumulatedFeesShares);
        object = vm.serializeUint("vaultInfo", "accumulatedFeesAssets", result.accumulatedFeesAssets);
        object = vm.serializeAddress("vaultInfo", "governorFeeReceiver", result.governorFeeReceiver);
        object = vm.serializeAddress("vaultInfo", "protocolFeeReceiver", result.protocolFeeReceiver);
        object = vm.serializeUint("vaultInfo", "protocolFeeShare", result.protocolFeeShare);
        object = vm.serializeUint("vaultInfo", "interestFee", result.interestFee);
        object = vm.serializeUint("vaultInfo", "hookedOperations", result.hookedOperations);
        object = vm.serializeUint("vaultInfo", "supplyCap", result.supplyCap);
        object = vm.serializeUint("vaultInfo", "borrowCap", result.borrowCap);
        object = vm.serializeUint("vaultInfo", "maxLiquidationDiscount", result.maxLiquidationDiscount);
        object = vm.serializeUint("vaultInfo", "liquidationCoolOffTime", result.liquidationCoolOffTime);
        object = vm.serializeAddress("vaultInfo", "dToken", result.dToken);
        object = vm.serializeAddress("vaultInfo", "oracle", result.oracle);
        object = vm.serializeAddress("vaultInfo", "interestRateModel", result.interestRateModel);
        object = vm.serializeAddress("vaultInfo", "hookTarget", result.hookTarget);
        object = vm.serializeAddress("vaultInfo", "evc", result.evc);
        object = vm.serializeAddress("vaultInfo", "protocolConfig", result.protocolConfig);
        object = vm.serializeAddress("vaultInfo", "balanceTracker", result.balanceTracker);
        object = vm.serializeAddress("vaultInfo", "permit2", result.permit2);
        object = vm.serializeAddress("vaultInfo", "creator", result.creator);
        object = vm.serializeAddress("vaultInfo", "governorAdmin", result.governorAdmin);

        string memory object2;
        object2 = vm.serializeAddress("irmInfo", "vault", result.irmInfo.vault);
        object2 = vm.serializeAddress("irmInfo", "interestRateModel", result.irmInfo.interestRateModel);
        object2 = vm.serializeString("irmInfo", "apyInfo", "unknown");
        object = vm.serializeString("vaultInfo", "irmInfo", object2);

        object = vm.serializeString("vaultInfo", "collateralLTVInfo", "unknown");

        string memory object3;
        object3 = vm.serializeUint("liabilityPriceInfo", "timestamp", result.liabilityPriceInfo.timestamp);
        object3 = vm.serializeUint("liabilityPriceInfo", "blockNumber", result.liabilityPriceInfo.blockNumber);
        object3 = vm.serializeAddress("liabilityPriceInfo", "oracle", result.liabilityPriceInfo.oracle);
        object3 = vm.serializeAddress("liabilityPriceInfo", "asset", result.liabilityPriceInfo.asset);
        object3 = vm.serializeAddress("liabilityPriceInfo", "unitOfAccount", result.liabilityPriceInfo.unitOfAccount);
        object3 = vm.serializeUint("liabilityPriceInfo", "amountIn", result.liabilityPriceInfo.amountIn);
        object3 = vm.serializeUint("liabilityPriceInfo", "amountOutMid", result.liabilityPriceInfo.amountOutMid);
        object3 = vm.serializeUint("liabilityPriceInfo", "amountOutBid", result.liabilityPriceInfo.amountOutBid);
        object3 = vm.serializeUint("liabilityPriceInfo", "amountOutAsk", result.liabilityPriceInfo.amountOutAsk);
        object = vm.serializeString("vaultInfo", "liabilityPriceInfo", object3);

        object = vm.serializeString("vaultInfo", "collateralPriceInfo", "unknown");

        string memory object4;
        object4 = vm.serializeString("oracleInfo", "name", result.oracleInfo.name);
        object4 = vm.serializeBytes("oracleInfo", "oracleInfo", result.oracleInfo.oracleInfo);
        object = vm.serializeString("vaultInfo", "oracleInfo", object4);

        return object;
    }
}
