// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {ScriptExtended} from "../utils/ScriptExtended.s.sol";
import {Vm, console} from "../utils/ScriptUtils.s.sol";

contract ExecuteTimelockTx is ScriptExtended {
    bytes32[] topic = new bytes32[](1);

    constructor() {
        topic[0] = keccak256("CallScheduled(bytes32,uint256,address,uint256,bytes,bytes32,uint256)");
    }

    function run() external {
        address payable timelock = payable(getTimelock());
        bytes32 timelockId = getTimelockId();

        require(timelock != address(0), "ExecuteTimelockTx: Timelock address not provided");
        require(timelockId != bytes32(0), "ExecuteTimelockTx: Timelock id not provided");
        require(
            TimelockController(timelock).isOperationPending(timelockId),
            "ExecuteTimelockTx: Timelock transaction id not pending"
        );
        require(
            TimelockController(timelock).isOperationReady(timelockId),
            "ExecuteTimelockTx: Timelock transaction id not ready"
        );

        uint256 toBlock = getToBlock();
        uint256 intervals;

        if (toBlock == 0) toBlock = block.number;

        while (intervals < 100 && !TimelockController(timelock).isOperationDone(timelockId)) {
            Vm.EthGetLogs[] memory ethLogs = vm.eth_getLogs(toBlock - 1e4, toBlock, timelock, topic);

            for (uint256 i = 0; i < ethLogs.length; ++i) {
                if (timelockId != ethLogs[i].topics[1]) continue;

                uint256 counter;
                for (uint256 j = i; j < ethLogs.length; ++j) {
                    if (timelockId == ethLogs[j].topics[1]) ++counter;
                    else break;
                }

                if (counter == 1) {
                    (address target, uint256 value, bytes memory data, bytes32 predecessor,) =
                        abi.decode(ethLogs[i].data, (address, uint256, bytes, bytes32, uint256));

                    vm.startBroadcast();
                    TimelockController(timelock).execute(target, value, data, predecessor, getTimelockSalt());
                    vm.stopBroadcast();
                } else {
                    address[] memory targets = new address[](counter);
                    uint256[] memory values = new uint256[](counter);
                    bytes[] memory datas = new bytes[](counter);
                    bytes32 predecessor;

                    for (uint256 j = i; j < i + counter; ++j) {
                        (targets[j - i], values[j - i], datas[j - i], predecessor,) =
                            abi.decode(ethLogs[j].data, (address, uint256, bytes, bytes32, uint256));
                    }

                    vm.startBroadcast();
                    TimelockController(timelock).executeBatch(targets, values, datas, predecessor, getTimelockSalt());
                    vm.stopBroadcast();
                }

                return;
            }

            toBlock -= 1e4;
            intervals++;
        }

        require(
            TimelockController(timelock).isOperationDone(timelockId),
            "ExecuteTimelockTx: Timelock transaction not executed"
        );
    }
}
