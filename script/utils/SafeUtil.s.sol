// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Surl} from "surl/Surl.sol";

// inspired by https://github.com/ind-igo/forge-safe
contract SafeTransaction is Script {
    using Surl for *;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct SafeTx {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
        bytes32 txHash;
        bytes signature;
    }

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256
    // gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    // );
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    address public sender;
    address public safe;
    SafeTx internal transaction;

    constructor(uint256 privateKey, address _safe, address target, uint256 value, bytes memory data) {
        sender = vm.addr(privateKey);
        safe = _safe;

        transaction.to = target;
        transaction.value = value;
        transaction.data = data;
        transaction.operation = Operation.CALL;
        transaction.safeTxGas = 0;
        transaction.baseGas = 0;
        transaction.gasPrice = 0;
        transaction.gasToken = address(0);
        transaction.refundReceiver = address(0);
        transaction.nonce = _getNonce();
        transaction.txHash = _getTransactionHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, transaction.txHash);
        transaction.signature = abi.encodePacked(r, s, v);
    }

    function getTransaction() external view returns (SafeTx memory) {
        return transaction;
    }

    function simulate() external {
        vm.prank(safe);
        (bool success, bytes memory result) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, string(result));
    }

    function execute() external {
        string memory payload = "";
        payload = vm.serializeAddress("payload", "safe", safe);
        payload = vm.serializeAddress("payload", "to", transaction.to);
        payload = vm.serializeUint("payload", "value", transaction.value);
        payload = vm.serializeBytes("payload", "data", transaction.data);
        payload = vm.serializeUint("payload", "operation", uint256(transaction.operation));
        payload = vm.serializeUint("payload", "safeTxGas", transaction.safeTxGas);
        payload = vm.serializeUint("payload", "baseGas", transaction.baseGas);
        payload = vm.serializeUint("payload", "gasPrice", transaction.gasPrice);
        payload = vm.serializeAddress("payload", "gasToken", transaction.gasToken);
        payload = vm.serializeAddress("payload", "refundReceiver", transaction.refundReceiver);
        payload = vm.serializeUint("payload", "nonce", transaction.nonce);
        payload = vm.serializeBytes32("payload", "contractTransactionHash", transaction.txHash);
        payload = vm.serializeBytes("payload", "signature", transaction.signature);
        payload = vm.serializeAddress("payload", "sender", sender);

        string memory endpoint =
            string(abi.encodePacked(_getSafeAPIBaseURL(), vm.toString(safe), "/multisig-transactions/"));
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";

        (uint256 status, bytes memory response) = endpoint.post(headers, payload);

        if (status == 201) {
            console.log("Safe transaction sent successfully");
        } else {
            console.log(string(response));
            revert("Safe transaction failed!");
        }
    }

    function _getTransactionHash() private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, safe)),
                keccak256(
                    abi.encode(
                        SAFE_TX_TYPEHASH,
                        transaction.to,
                        transaction.value,
                        keccak256(transaction.data),
                        transaction.operation,
                        transaction.safeTxGas,
                        transaction.baseGas,
                        transaction.gasPrice,
                        transaction.gasToken,
                        transaction.refundReceiver,
                        transaction.nonce
                    )
                )
            )
        );
    }

    function _getNonce() private returns (uint256) {
        string memory endpoint =
            string(abi.encodePacked(_getSafeAPIBaseURL(), vm.toString(safe), "/multisig-transactions/?limit=1"));

        (uint256 status, bytes memory response) = endpoint.get();
        if (status == 200) {
            return abi.decode(vm.parseJson(string(response), ".results"), (string[])).length == 0
                ? 0
                : abi.decode(vm.parseJson(string(response), ".results[0].nonce"), (uint256)) + 1;
        } else {
            revert("getNonce: Failed to get nonce");
        }
    }

    function _getSafeAPIBaseURL() private view returns (string memory) {
        if (block.chainid == 1) {
            return "https://safe-transaction-mainnet.safe.global/api/v1/safes/";
        } else if (block.chainid == 5) {
            return "https://safe-transaction-goerli.safe.global/api/v1/safes/";
        } else if (block.chainid == 8453) {
            return "https://safe-transaction-base.safe.global/api/v1/safes/";
        } else if (block.chainid == 42161) {
            return "https://safe-transaction-arbitrum.safe.global/api/v1/safes/";
        } else if (block.chainid == 43114) {
            return "https://safe-transaction-avalanche.safe.global/api/v1/safes/";
        } else {
            revert("getSafeAPIBaseURL: Unsupported chain");
        }
    }
}
