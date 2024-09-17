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

contract EulerEarn is Utils {
    function getVaultInfoFull(address vault) public view returns (EulerEarnInfoFull memory) {
        EulerEarnInfoFull memory result;

        result.timestamp = block.timestamp;

        result.vault = vault;
        result.vaultName = IEVault(vault).name();
        result.vaultSymbol = IEVault(vault).symbol();
        result.vaultDecimals = IEVault(vault).decimals();

        return result;
    }
}