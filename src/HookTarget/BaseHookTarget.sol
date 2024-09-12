// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

contract BaseHookTarget is IHookTarget {
    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    function getAddressFromMsgData() public pure returns (address msgSender) {
        // Ensure that tx.data has at least 20 bytes
        require(msg.data.length >= 20, "tx.data too short");

        // Get the last 20 bytes of tx.data
        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}