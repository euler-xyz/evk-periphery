// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {Errors} from "evk/EVault/shared/Errors.sol";
import {Utils} from "./Utils.sol";
import "./LensTypes.sol";

contract AccountLens is Utils {
    function getAccountInfo(address account, address vault) public view returns (AccountInfo memory) {
        AccountInfo memory result;

        result.evcAccountInfo = getEVCAccountInfo(IEVault(vault).EVC(), account);
        result.vaultAccountInfo = getVaultAccountInfo(account, vault);
        result.accountRewardInfo = getRewardAccountInfo(account, vault);

        return result;
    }

    function getAccountEnabledVaultsInfo(address evc, address account)
        public
        view
        returns (AccountMultipleVaultsInfo memory)
    {
        AccountMultipleVaultsInfo memory result;

        result.evcAccountInfo = getEVCAccountInfo(evc, account);

        uint256 controllersLength = result.evcAccountInfo.enabledControllers.length;
        uint256 collateralsLength = result.evcAccountInfo.enabledCollaterals.length;

        uint256 counter = collateralsLength;
        for (uint256 i = 0; i < controllersLength; ++i) {
            if (!IEVC(evc).isCollateralEnabled(account, result.evcAccountInfo.enabledControllers[i])) {
                ++counter;
            }
        }

        result.vaultAccountInfo = new VaultAccountInfo[](counter);
        result.accountRewardInfo = new AccountRewardInfo[](counter);

        for (uint256 i = 0; i < controllersLength; ++i) {
            result.vaultAccountInfo[i] = getVaultAccountInfo(account, result.evcAccountInfo.enabledControllers[i]);
            result.accountRewardInfo[i] = getRewardAccountInfo(account, result.evcAccountInfo.enabledControllers[i]);
        }

        counter = controllersLength;
        for (uint256 i = 0; i < collateralsLength; ++i) {
            VaultAccountInfo memory vaultAccountInfo =
                getVaultAccountInfo(account, result.evcAccountInfo.enabledCollaterals[i]);

            if (!vaultAccountInfo.isController) {
                result.vaultAccountInfo[counter] = vaultAccountInfo;
                result.accountRewardInfo[counter] =
                    getRewardAccountInfo(account, result.evcAccountInfo.enabledCollaterals[i]);
                ++counter;
            }
        }

        return result;
    }

    function getEVCAccountInfo(address evc, address account) public view returns (EVCAccountInfo memory) {
        EVCAccountInfo memory result;

        result.timestamp = block.timestamp;

        result.evc = evc;
        result.account = account;
        result.addressPrefix = IEVC(evc).getAddressPrefix(account);
        result.owner = IEVC(evc).getAccountOwner(account);

        result.isLockdownMode = IEVC(evc).isLockdownMode(result.addressPrefix);
        result.isPermitDisabledMode = IEVC(evc).isPermitDisabledMode(result.addressPrefix);
        result.lastAccountStatusCheckTimestamp = IEVC(evc).getLastAccountStatusCheckTimestamp(account);
        result.enabledControllers = IEVC(evc).getControllers(account);
        result.enabledCollaterals = IEVC(evc).getCollaterals(account);

        return result;
    }

    function getVaultAccountInfo(address account, address vault) public view returns (VaultAccountInfo memory) {
        VaultAccountInfo memory result;

        result.timestamp = block.timestamp;

        result.account = account;
        result.vault = vault;

        (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IEVault(vault).asset, ()));

        if (!success || data.length < 32) {
            return result;
        }

        result.asset = abi.decode(data, (address));

        (success, data) = result.asset.staticcall(abi.encodeCall(IEVault(result.asset).balanceOf, (account)));

        if (success && data.length >= 32) {
            result.assetsAccount = abi.decode(data, (uint256));
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).balanceOf, (account)));

        if (success && data.length >= 32) {
            result.shares = abi.decode(data, (uint256));
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).convertToAssets, (result.shares)));

        if (success && data.length >= 32) {
            result.assets = abi.decode(data, (uint256));
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).debtOf, (account)));

        if (success && data.length >= 32) {
            result.borrowed = abi.decode(data, (uint256));
        }

        (success, data) = result.asset.staticcall(abi.encodeCall(IEVault(result.asset).allowance, (account, vault)));

        if (success && data.length >= 32) {
            result.assetAllowanceVault = abi.decode(data, (uint256));
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).permit2Address, ()));

        address permit2;
        if (success && data.length >= 32) {
            permit2 = abi.decode(data, (address));
        }

        if (permit2 != address(0)) {
            (result.assetAllowanceVaultPermit2, result.assetAllowanceExpirationVaultPermit2,) =
                IAllowanceTransfer(permit2).allowance(account, result.asset, vault);

            result.assetAllowancePermit2 = IEVault(result.asset).allowance(account, permit2);
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).balanceForwarderEnabled, (account)));

        if (success && data.length >= 32) {
            result.balanceForwarderEnabled = abi.decode(data, (bool));
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).EVC, ()));

        address evc;
        if (success && data.length >= 32) {
            evc = abi.decode(data, (address));
        }

        result.isController = IEVC(evc).isControllerEnabled(account, vault);
        result.isCollateral = IEVC(evc).isCollateralEnabled(account, vault);
        result.liquidityInfo = getAccountLiquidityInfo(account, vault);

        return result;
    }

    function getAccountLiquidityInfo(address account, address vault)
        public
        view
        returns (AccountLiquidityInfo memory)
    {
        AccountLiquidityInfo memory result;

        result.account = account;
        result.vault = vault;

        (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IEVault(vault).unitOfAccount, ()));

        if (success && data.length >= 32) {
            result.unitOfAccount = abi.decode(data, (address));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).accountLiquidity, (account, false)));

        if (success && data.length >= 64) {
            (result.collateralValueBorrowing, result.liabilityValueBorrowing) = abi.decode(data, (uint256, uint256));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).accountLiquidity, (account, true)));

        if (success && data.length >= 64) {
            (result.collateralValueLiquidation, result.liabilityValueLiquidation) = abi.decode(data, (uint256, uint256));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).accountLiquidityFull, (account, false)));

        if (success && data.length >= 64) {
            (result.collaterals, result.collateralValuesBorrowing,) = abi.decode(data, (address[], uint256[], uint256));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        (success, data) = vault.staticcall(abi.encodeCall(IEVault(vault).accountLiquidityFull, (account, true)));

        if (success && data.length >= 64) {
            (result.collaterals, result.collateralValuesLiquidation,) =
                abi.decode(data, (address[], uint256[], uint256));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        if (!result.queryFailure) {
            result.collateralValuesRaw = new uint256[](result.collaterals.length);

            for (uint256 i = 0; i < result.collaterals.length; ++i) {
                (success, data) =
                    vault.staticcall(abi.encodeCall(IEVault(vault).LTVLiquidation, (result.collaterals[i])));

                if (success && data.length >= 32) {
                    uint256 liquidationLTV = abi.decode(data, (uint16));

                    if (liquidationLTV != 0) {
                        result.collateralValuesRaw[i] =
                            result.collateralValuesLiquidation[i] * CONFIG_SCALE / liquidationLTV;
                    }
                }

                result.collateralValueRaw += result.collateralValuesRaw[i];
            }
        }

        if (!result.queryFailure) {
            result.timeToLiquidation = _calculateTimeToLiquidation(
                vault, result.liabilityValueLiquidation, result.collaterals, result.collateralValuesLiquidation
            );
        }

        return result;
    }

    function getAccountLiquidityInfoNoValidation(address account, address vault)
        public
        view
        returns (AccountLiquidityInfo memory)
    {
        AccountLiquidityInfo memory result = getAccountLiquidityInfo(account, vault);

        if (
            !result.queryFailure
                || (
                    bytes4(result.queryFailureReason) != Errors.E_TransientState.selector
                        && bytes4(result.queryFailureReason) != Errors.E_NoLiability.selector
                        && bytes4(result.queryFailureReason) != Errors.E_NotController.selector
                        && bytes4(result.queryFailureReason) != Errors.E_NoPriceOracle.selector
                )
        ) return result;

        result.queryFailure = false;
        result.queryFailureReason = "";
        result.account = account;
        result.vault = vault;
        result.timeToLiquidation = TTL_ERROR;
        result.liabilityValueBorrowing = 0;
        result.liabilityValueLiquidation = 0;
        result.collateralValueBorrowing = 0;
        result.collateralValueLiquidation = 0;
        result.collateralValueRaw = 0;
        result.unitOfAccount = IEVault(vault).unitOfAccount();
        result.collaterals = IEVC(IEVault(vault).EVC()).getCollaterals(account);
        result.collateralValuesBorrowing = new uint256[](result.collaterals.length);
        result.collateralValuesLiquidation = new uint256[](result.collaterals.length);
        result.collateralValuesRaw = new uint256[](result.collaterals.length);

        address oracle = IEVault(vault).oracle();
        uint256 debt = IEVault(vault).debtOf(account);

        if (debt != 0) {
            address asset = IEVault(vault).asset();

            (bool success, bytes memory data) =
                oracle.staticcall(abi.encodeCall(IPriceOracle.getQuotes, (debt, asset, result.unitOfAccount)));

            if (success && data.length >= 32) {
                (, result.liabilityValueBorrowing) = abi.decode(data, (uint256, uint256));
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }

            (success, data) =
                oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (debt, asset, result.unitOfAccount)));

            if (!result.queryFailure && success && data.length >= 32) {
                result.liabilityValueLiquidation = abi.decode(data, (uint256));
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }
        }

        if (result.queryFailure) return result;

        for (uint256 i = 0; i < result.collaterals.length; ++i) {
            address collateral = result.collaterals[i];
            uint256 balance;

            (bool success, bytes memory data) =
                collateral.staticcall(abi.encodeCall(IEVault(collateral).balanceOf, (account)));

            if (success && data.length >= 32) {
                balance = abi.decode(data, (uint256));
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }

            if (balance == 0) continue;

            (success, data) =
                oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (balance, collateral, result.unitOfAccount)));

            if (success && data.length >= 32) {
                result.collateralValuesRaw[i] = abi.decode(data, (uint256));
                result.collateralValueRaw += result.collateralValuesRaw[i];

                result.collateralValuesLiquidation[i] =
                    result.collateralValuesRaw[i] * IEVault(vault).LTVLiquidation(collateral) / CONFIG_SCALE;
                result.collateralValueLiquidation += result.collateralValuesLiquidation[i];
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }

            (success, data) =
                oracle.staticcall(abi.encodeCall(IPriceOracle.getQuotes, (balance, collateral, result.unitOfAccount)));

            if (success && data.length >= 32) {
                (uint256 collateralValue,) = abi.decode(data, (uint256, uint256));

                result.collateralValuesBorrowing[i] =
                    collateralValue * IEVault(vault).LTVBorrow(collateral) / CONFIG_SCALE;
                result.collateralValueBorrowing += result.collateralValuesBorrowing[i];
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }
        }

        return result;
    }

    function getTimeToLiquidation(address account, address vault) public view returns (int256) {
        address[] memory collaterals;
        uint256[] memory collateralValues;
        uint256 liabilityValue;

        // get detailed collateral values and liability value
        try IEVault(vault).accountLiquidityFull(account, true) returns (
            address[] memory _collaterals, uint256[] memory _collateralValues, uint256 _liabilityValue
        ) {
            collaterals = _collaterals;
            collateralValues = _collateralValues;
            liabilityValue = _liabilityValue;
        } catch (bytes memory reason) {
            if (bytes4(reason) != Errors.E_NoLiability.selector) return TTL_ERROR;
        }

        return _calculateTimeToLiquidation(vault, liabilityValue, collaterals, collateralValues);
    }

    function getRewardAccountInfo(address account, address vault) public view returns (AccountRewardInfo memory) {
        AccountRewardInfo memory result;

        result.timestamp = block.timestamp;

        result.account = account;
        result.vault = vault;

        (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IEVault(vault).balanceTrackerAddress, ()));

        if (!success || data.length < 32) {
            return result;
        }

        result.balanceTracker = abi.decode(data, (address));
        result.balanceForwarderEnabled = IEVault(vault).balanceForwarderEnabled(account);

        if (result.balanceTracker == address(0)) return result;

        result.balance = IRewardStreams(result.balanceTracker).balanceOf(account, vault);

        address[] memory enabledRewards = IRewardStreams(result.balanceTracker).enabledRewards(account, vault);
        result.enabledRewardsInfo = new EnabledRewardInfo[](enabledRewards.length);

        for (uint256 i; i < enabledRewards.length; ++i) {
            result.enabledRewardsInfo[i].reward = enabledRewards[i];

            result.enabledRewardsInfo[i].earnedReward =
                IRewardStreams(result.balanceTracker).earnedReward(account, vault, enabledRewards[i], false);

            result.enabledRewardsInfo[i].earnedRewardRecentIgnored =
                IRewardStreams(result.balanceTracker).earnedReward(account, vault, enabledRewards[i], true);
        }

        return result;
    }
}
