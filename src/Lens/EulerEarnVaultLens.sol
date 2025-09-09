// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    IEulerEarn, IERC4626, MarketConfig, PendingUint136, PendingAddress
} from "euler-earn/interfaces/IEulerEarn.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {UtilsLens} from "./UtilsLens.sol";
import {Utils} from "./Utils.sol";
import "./LensTypes.sol";

contract EulerEarnVaultLens is Utils {
    UtilsLens public immutable utilsLens;

    constructor(address _utilsLens) {
        utilsLens = UtilsLens(_utilsLens);
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
        result.lostAssets = IEulerEarn(vault).lostAssets();

        if (result.lostAssets > 0) {
            uint256 coveredLostAssets = IEulerEarn(vault).convertToAssets(IEulerEarn(vault).balanceOf(address(1)));
            result.lostAssets = result.lostAssets > coveredLostAssets ? result.lostAssets - coveredLostAssets : 0;
        }

        result.timelock = IEulerEarn(vault).timelock();
        result.performanceFee = IEulerEarn(vault).fee();
        result.feeReceiver = IEulerEarn(vault).feeRecipient();
        result.owner = IEulerEarn(vault).owner();
        result.creator = IEulerEarn(vault).creator();
        result.curator = IEulerEarn(vault).curator();
        result.guardian = IEulerEarn(vault).guardian();
        result.evc = EVCUtil(vault).EVC();
        result.permit2 = IEulerEarn(vault).permit2Address();

        PendingUint136 memory pendingTimelock = IEulerEarn(vault).pendingTimelock();
        PendingAddress memory pendingGuardian = IEulerEarn(vault).pendingGuardian();

        result.pendingTimelock = pendingTimelock.value;
        result.pendingTimelockValidAt = pendingTimelock.validAt;
        result.pendingGuardian = pendingGuardian.value;
        result.pendingGuardianValidAt = pendingGuardian.validAt;

        result.supplyQueue = new address[](IEulerEarn(vault).supplyQueueLength());
        for (uint256 i; i < result.supplyQueue.length; ++i) {
            result.supplyQueue[i] = address(IEulerEarn(vault).supplyQueue(i));
        }

        result.strategies = new EulerEarnVaultStrategyInfo[](IEulerEarn(vault).withdrawQueueLength());

        for (uint256 i; i < result.strategies.length; ++i) {
            result.strategies[i] = getStrategyInfo(vault, address(IEulerEarn(vault).withdrawQueue(i)));
            result.availableAssets += result.strategies[i].availableAssets;
        }

        return result;
    }

    function getStrategiesInfo(address vault, address[] calldata strategies)
        public
        view
        returns (EulerEarnVaultStrategyInfo[] memory)
    {
        EulerEarnVaultStrategyInfo[] memory result = new EulerEarnVaultStrategyInfo[](strategies.length);

        for (uint256 i; i < strategies.length; ++i) {
            result[i] = getStrategyInfo(vault, strategies[i]);
        }

        return result;
    }

    function getStrategyInfo(address _vault, address _strategy)
        public
        view
        returns (EulerEarnVaultStrategyInfo memory)
    {
        IEulerEarn vault = IEulerEarn(_vault);
        IERC4626 strategy = IERC4626(_strategy);
        MarketConfig memory config = vault.config(strategy);
        PendingUint136 memory pendingConfig = vault.pendingCap(strategy);

        return EulerEarnVaultStrategyInfo({
            strategy: _strategy,
            allocatedAssets: vault.expectedSupplyAssets(strategy),
            availableAssets: vault.maxWithdrawFromStrategy(strategy),
            currentAllocationCap: config.cap,
            pendingAllocationCap: pendingConfig.value,
            pendingAllocationCapValidAt: pendingConfig.validAt,
            removableAt: config.removableAt,
            info: utilsLens.getVaultInfoERC4626(_strategy)
        });
    }
}
