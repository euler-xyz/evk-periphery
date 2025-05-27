// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../utils/ScriptUtils.s.sol";
import {IEulerSwapFactory, EulerSwapOperatorDeployer} from "../30_EulerSwap.s.sol";

contract InstallEulerSwap is ScriptUtils {
    function run() public {
        address eulerSwapFactory = address(0);
        address pool = address(0);

        IEulerSwapFactory.Params memory params = IEulerSwapFactory.Params({
            vault0: 0x0000000000000000000000000000000000000000,
            vault1: 0x0000000000000000000000000000000000000000,
            eulerAccount: 0x0000000000000000000000000000000000000000,
            equilibriumReserve0: 0,
            equilibriumReserve1: 0,
            priceX: 0,
            priceY: 0,
            concentrationX: 0,
            concentrationY: 0,
            fee: 0,
            protocolFee: 0,
            protocolFeeRecipient: 0x0000000000000000000000000000000000000000
        });

        IEulerSwapFactory.InitialState memory initialState =
            IEulerSwapFactory.InitialState({currReserve0: 0, currReserve1: 0});

        bytes32 salt = bytes32(0);

        EulerSwapOperatorDeployer deployer = new EulerSwapOperatorDeployer();
        deployer.execute(eulerSwapFactory, pool, params, initialState, salt);
    }
}
