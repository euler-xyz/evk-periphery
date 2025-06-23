// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IEulerEarn, IERC4626, MarketConfig, PendingUint192} from "euler-earn/interfaces/IEulerEarn.sol";
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
        result.performanceFee = IEulerEarn(vault).fee();
        result.feeReceiver = IEulerEarn(vault).feeRecipient();
        result.owner = IEulerEarn(vault).owner();
        result.creator = IEulerEarn(vault).creator();
        result.curator = IEulerEarn(vault).curator();
        result.guardian = IEulerEarn(vault).guardian();
        result.evc = EVCUtil(vault).EVC();
        result.permit2 = IEulerEarn(vault).permit2Address();

        result.strategies = new EulerEarnVaultStrategyInfo[](IEulerEarn(vault).withdrawQueueLength());

        for (uint256 i; i < result.strategies.length; ++i) {
            IERC4626 strategy = IEulerEarn(vault).withdrawQueue(i);
            MarketConfig memory config = IEulerEarn(vault).config(strategy);
            PendingUint192 memory pendingConfig = IEulerEarn(vault).pendingCap(strategy);

            result.strategies[i].strategy = address(strategy);
            result.strategies[i].assetsAllocated = strategy.previewRedeem(strategy.balanceOf(vault));
            result.strategies[i].currentAllocationCap = config.cap;
            result.strategies[i].pendingAllocationCap = pendingConfig.value;
            result.strategies[i].pendingAllocationCapValidAt = pendingConfig.validAt;
            result.strategies[i].removableAt = config.removableAt;
            result.strategies[i].info = utilsLens.getVaultInfoERC4626(result.strategies[i].strategy);
        }

        return result;
    }
}
