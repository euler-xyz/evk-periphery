// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

uint256 constant DAI_USDC_BLOCK = 20613349;
// Swap 1 DAI for 1 USDC
uint256 constant RECEIVER_OFFSET = 3152;
// receiver is 0x1111111111111111111111111111111111111111
bytes constant DAI_USDC_PAYLOAD =
    hex"b35d7e730000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000001ea9059cbb010001ffffffffff6b175474e89094c44da98b954eedeac495271d0f095ea7b3010203ffffffffff6b175474e89094c44da98b954eedeac495271d0f70a082310104ffffffffff02dac17f958d2ee523a2206206994597c13d831ec73df021240105060305ffffffbebc44782c7db0a1a60cb6fe97d0b483032ff1c770a082310104ffffffffff03dac17f958d2ee523a2206206994597c13d831ec7b67d77c5010302ffffffff03ca99eaa38e8f37a168214a3a57c9a45a58563ed5095ea7b3010703ffffffffffdac17f958d2ee523a2206206994597c13d831ec770a082310104ffffffffff07c02aaa39b223fe8d0a0e5c4f27ead9083c756cc25b41b9080105060305ffffffd51a44d3fae010294c616388b506acda1bfaae4670a082310104ffffffffff03c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2b67d77c5010307ffffffff03ca99eaa38e8f37a168214a3a57c9a45a58563ed5095ea7b3010803ffffffffffc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2414bf3894100000000000003e592427a0aece92de3edee1f18e0157c05861564090a0b040c030505ffffffffffffffffffffffffffffffffffffffffffffffff095ea7b3010805ffffffffffc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2095ea7b3010d03ffffffffff2b591e99afe9f32eaa6214f7b7629768c40eeb3970a082310104ffffffffff0d3819f64f282bf135d62168c1e513280daf905e065c11d7950103058e040cffff7a250d5630b4cf539739df2c5dacb4c659f2488d70a082310104ffffffffff033819f64f282bf135d62168c1e513280daf905e06b67d77c501030dffffffff03ca99eaa38e8f37a168214a3a57c9a45a58563ed5095ea7b3010803ffffffffff3819f64f282bf135d62168c1e513280daf905e06414bf3894100000000000003e592427a0aece92de3edee1f18e0157c058615640f1011040c030505ffffffffffffffffffffffffffffffffffffffffffffffff095ea7b3010805ffffffffff3819f64f282bf135d62168c1e513280daf905e06095ea7b3010803ffffffffffe9f721e7419423f11863e83dbd710b5d6127b5b0414bf3894100000000000003e592427a0aece92de3edee1f18e0157c05861564101211130c030505ffffffffffffffffffffffffffffffffffffffffffffffff095ea7b3010805ffffffffffe9f721e7419423f11863e83dbd710b5d6127b5b06e7a43a3010314ffffffff037e7d64d987cab6eed08a191c4c2459daf2f8ed0b241c59120103ffffffffffff7e7d64d987cab6eed08a191c4c2459daf2f8ed0b000000000000000000000000000000000000000000000000000000000000001500000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000002e00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000036000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000000000000000000000000000003e00000000000000000000000000000000000000000000000000000000000000420000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000004a000000000000000000000000000000000000000000000000000000000000004e00000000000000000000000000000000000000000000000000000000000000520000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000005a000000000000000000000000000000000000000000000000000000000000005e0000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000000000000000000000000000000000000006a000000000000000000000000000000000000000000000000000000000000006e00000000000000000000000000000000000000000000000000000000000000720000000000000000000000000000000000000000000000000000000000000076000000000000000000000000000000000000000000000000000000000000007a000000000000000000000000000000000000000000000000000000000000007e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000220866b1a2219f40e72f5c628b65d54268ca3a9d0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000002386f26fc100000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c700000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000dbd2fc137a3000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007d585b0e27bbb3d981b7757115ec11f47c47699400000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d51a44d3fae010294c616388b506acda1bfaae460000000000000000000000000000000000000000000000000000000000000020000000000000000000000000e592427a0aece92de3edee1f18e0157c058615640000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000200000000000000000000000002b591e99afe9f32eaa6214f7b7629768c40eeb3900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000bb80000000000000000000000000000000000000000000000000000000000000020ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000200000000000000000000000007a250d5630b4cf539739df2c5dacb4c659f2488d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000020000000000000000000000002b591e99afe9f32eaa6214f7b7629768c40eeb390000000000000000000000003819f64f282bf135d62168c1e513280daf905e0600000000000000000000000000000000000000000000000000000000000000200000000000000000000000003819f64f282bf135d62168c1e513280daf905e060000000000000000000000000000000000000000000000000000000000000020000000000000000000000000e9f721e7419423f11863e83dbd710b5d6127b5b0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000027100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000020000000000000000000000000111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003";

function DAI_USDC_inectReceiver(address receiver) pure returns (bytes memory payload) {
    payload = DAI_USDC_PAYLOAD;
    assembly {
        mstore(0, receiver)
        mcopy(add(add(payload, 32), RECEIVER_OFFSET), 12, 20)
    }
}
