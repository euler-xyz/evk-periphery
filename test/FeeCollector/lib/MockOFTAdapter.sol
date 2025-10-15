// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SendParam, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";

contract MockOFTAdapter {
    address public token;
    uint256 public MESSAGING_NATIVE_FEE = 123;
    bool public wasSendCalled;

    constructor(address _token) {
        token = _token;
    }

    function send(SendParam calldata, MessagingFee calldata, address)
        public
        payable
        returns (MessagingReceipt memory, OFTReceipt memory)
    {
        wasSendCalled = true;
        return (
            MessagingReceipt({
                guid: bytes32(0),
                nonce: 1,
                fee: MessagingFee({nativeFee: MESSAGING_NATIVE_FEE, lzTokenFee: 0})
            }),
            OFTReceipt({amountSentLD: 0, amountReceivedLD: 0})
        );
    }

    function quoteSend(SendParam calldata, bool) public view returns (MessagingFee memory) {
        return MessagingFee({nativeFee: MESSAGING_NATIVE_FEE, lzTokenFee: 0});
    }
}
