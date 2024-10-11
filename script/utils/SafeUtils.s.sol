// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ScriptExtended} from "./ScriptExtended.s.sol";
import {Surl} from "surl/Surl.sol";
import {console} from "forge-std/console.sol";

// inspired by https://github.com/ind-igo/forge-safe

abstract contract SafeUtil is ScriptExtended {
    using Surl for *;

    int256 internal currentNonce = getSafeCurrentNonce();

    function isSafeOwnerOrDelegate(address safe, address account) internal returns (bool) {
        address[] memory safes = getSafes(account);
        for (uint256 i = 0; i < safes.length; ++i) {
            if (safes[i] == safe) return true;
        }

        address[] memory delegates = getDelegates(safe);
        for (uint256 i = 0; i < delegates.length; ++i) {
            if (delegates[i] == account) return true;
        }

        return false;
    }

    function getNonce(address safe) internal returns (uint256) {
        if (currentNonce >= 0) return uint256(++currentNonce);

        string memory endpoint =
            string.concat(getTransactionsAPIBaseURL(), vm.toString(safe), "/multisig-transactions/?limit=1");
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            return abi.decode(vm.parseJson(string(response), ".results"), (string[])).length == 0
                ? 0
                : abi.decode(vm.parseJson(string(response), ".results[0].nonce"), (uint256)) + 1;
        } else {
            revert("getNonce: Failed to get nonce");
        }
    }

    function getSafes(address owner) internal returns (address[] memory) {
        string memory endpoint = string.concat(getOwnersAPIBaseURL(), vm.toString(owner), "/safes/");
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            return abi.decode(vm.parseJson(string(response), ".safes"), (address[]));
        } else {
            revert("getSafes: Failed to get safes");
        }
    }

    function getDelegates(address safe) internal returns (address[] memory) {
        string memory endpoint = string.concat(getDelegatesAPIBaseURL(), "?safe=", vm.toString(safe));
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            uint256 count = abi.decode(vm.parseJson(string(response), ".count"), (uint256));
            address[] memory delegates = new address[](count);

            for (uint256 i = 0; i < count; ++i) {
                delegates[i] = abi.decode(
                    vm.parseJson(string(response), string.concat(".results[", vm.toString(i), "].delegate")), (address)
                );
            }

            return delegates;
        } else {
            revert("getDelegates: Failed to get delegates");
        }
    }

    function getTransactionsAPIBaseURL() internal view returns (string memory) {
        return string.concat(getSafeBaseURL(), "api/v1/safes/");
    }

    function getOwnersAPIBaseURL() internal view returns (string memory) {
        return string.concat(getSafeBaseURL(), "api/v1/owners/");
    }

    function getDelegatesAPIBaseURL() internal view returns (string memory) {
        return string.concat(getSafeBaseURL(), "api/v2/delegates/");
    }

    function getSafeBaseURL() internal view returns (string memory) {
        if (block.chainid == 1) {
            return "https://safe-transaction-mainnet.safe.global/";
        } else if (block.chainid == 5) {
            return "https://safe-transaction-goerli.safe.global/";
        } else if (block.chainid == 8453) {
            return "https://safe-transaction-base.safe.global/";
        } else if (block.chainid == 42161) {
            return "https://safe-transaction-arbitrum.safe.global/";
        } else if (block.chainid == 43114) {
            return "https://safe-transaction-avalanche.safe.global/";
        } else {
            revert("getSafeBaseURL: Unsupported chain");
        }
    }

    function getHeaders() internal pure returns (string[] memory) {
        string[] memory headers = new string[](2);
        headers[0] = "Accept: application/json";
        headers[1] = "Content-Type: application/json";
        return headers;
    }

    function getHeadersString() internal pure returns (string memory) {
        string[] memory headers = getHeaders();
        string memory headersString = " ";
        for (uint256 i = 0; i < headers.length; i++) {
            headersString = string.concat(headersString, "-H \"", headers[i], "\" ");
        }
        return headersString;
    }
}

contract SafeTransaction is SafeUtil {
    using Surl for *;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct Transaction {
        address safe;
        address sender;
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
        bytes32 hash;
        bytes signature;
    }

    Transaction internal transaction;

    function create(address safe, address target, uint256 value, bytes memory data) public {
        _initialize(getSafePK(), safe, target, value, data);
        _simulate();
        if (isBroadcast()) _create();
    }

    function createManually(address safe, address target, uint256 value, bytes memory data) public {
        _initialize(getSafePKOptional(), safe, target, value, data);
        _simulate();

        transaction.sender = address(0);
        transaction.signature = "";

        console.log("Sign the following hash:");
        console.logBytes32(transaction.hash);

        console.log("");
        console.log("and send the following POST request adding the sender address and the signature to the payload:");
        console.log(
            string.concat(
                "curl -X POST ",
                getTransactionsAPIBaseURL(),
                vm.toString(transaction.safe),
                "/multisig-transactions/ ",
                getHeadersString(),
                "-d '",
                _getPayload(),
                "'"
            )
        );
    }

    function _initialize(uint256 privateKey, address safe, address target, uint256 value, bytes memory data) private {
        transaction.safe = safe;
        transaction.sender = vm.addr(privateKey);
        transaction.to = target;
        transaction.value = value;
        transaction.data = data;
        transaction.operation = Operation.CALL;
        transaction.safeTxGas = 0;
        transaction.baseGas = 0;
        transaction.gasPrice = 0;
        transaction.gasToken = address(0);
        transaction.refundReceiver = address(0);
        transaction.nonce = getNonce(safe);
        transaction.hash = _getHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, transaction.hash);
        transaction.signature = abi.encodePacked(r, s, v);
    }

    function _simulate() private {
        if (!isSafeOwnerOrDelegate(transaction.safe, transaction.sender)) {
            console.log(
                "Sender (%s) not authorized to execute a transaction on Safe (%s)", transaction.sender, transaction.safe
            );
            revert("Not authorized");
        }

        vm.prank(transaction.safe);
        (bool success, bytes memory result) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, string(result));
    }

    function _create() private {
        string memory endpoint =
            string.concat(getTransactionsAPIBaseURL(), vm.toString(transaction.safe), "/multisig-transactions/");
        (uint256 status, bytes memory response) = endpoint.post(getHeaders(), _getPayload());

        if (status == 201) {
            console.log("Safe transaction created successfully");
        } else {
            console.log(string(response));
            revert("Safe transaction creation failed!");
        }
    }

    function _getPayload() private returns (string memory) {
        string memory payload = "";
        payload = vm.serializeAddress("payload", "safe", transaction.safe);
        payload = vm.serializeAddress("payload", "sender", transaction.sender);
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
        payload = vm.serializeBytes32("payload", "contractTransactionHash", transaction.hash);
        payload = vm.serializeBytes("payload", "signature", transaction.signature);
        return payload;
    }

    function _getHash() private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
                        block.chainid,
                        transaction.safe
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256(
                            "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
                        ),
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
}

contract SafeDelegation is SafeUtil {
    using Surl for *;

    struct Delegate {
        address safe;
        address delegator;
        address delegate;
        string label;
        uint256 totp;
        bytes32 hash;
        bytes signature;
    }

    Delegate internal data;

    function create(address safe, address delegate, string memory label) public {
        _initialize(getSafePK(), safe, delegate, label);
        _create();
    }

    function createManually(address safe, address delegate, string memory label) public {
        _initialize(getSafePKOptional(), safe, delegate, label);
        data.delegator = address(0);
        data.signature = "";

        console.log("Sign the following hash:");
        console.logBytes32(data.hash);

        console.log("");
        console.log(
            "and send the following POST request adding the delegator address and the signature to the payload:"
        );
        console.log(
            string.concat(
                "curl -X POST ", getDelegatesAPIBaseURL(), getHeadersString(), "-d '", _getCreatePayload(), "'"
            )
        );
    }

    function remove(address safe, address delegate) public {
        _initialize(getSafePK(), safe, delegate, "");
        _remove();
    }

    function removeManually(address safe, address delegate) public {
        _initialize(getSafePKOptional(), safe, delegate, "");
        data.delegator = address(0);
        data.signature = "";

        console.log("Sign the following hash:");
        console.logBytes32(data.hash);

        console.log("");
        console.log(
            "and send the following DELETE request adding the delegator address and the signature to the payload:"
        );
        console.log(
            string.concat(
                "curl -X DELETE ",
                getDelegatesAPIBaseURL(),
                vm.toString(data.delegate),
                "/ ",
                getHeadersString(),
                "-d '",
                _getRemovePayload(),
                "'"
            )
        );
    }

    function _initialize(uint256 privateKey, address safe, address delegate, string memory label) private {
        data.safe = safe;
        data.delegator = vm.addr(privateKey);
        data.delegate = delegate;
        data.label = label;
        data.totp = block.timestamp / 1 hours;
        data.hash = _getHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, data.hash);
        data.signature = abi.encodePacked(r, s, v);
    }

    function _create() private {
        (uint256 status, bytes memory response) = getDelegatesAPIBaseURL().post(getHeaders(), _getCreatePayload());

        if (status == 201) {
            console.log("Safe delegate creation successful");
        } else {
            console.log(string(response));
            revert("Safe delegate creation failed!");
        }
    }

    function _remove() private {
        string memory endpoint = string.concat(getDelegatesAPIBaseURL(), vm.toString(data.delegate), "/");
        (uint256 status, bytes memory response) = endpoint.del(getHeaders(), _getRemovePayload());

        if (status == 204) {
            console.log("Safe delegate removal successful");
        } else {
            console.log(string(response));
            revert("Safe delegate removal failed!");
        }
    }

    function _getCreatePayload() private returns (string memory) {
        string memory payload = "";
        payload = vm.serializeAddress("payload", "safe", data.safe);
        payload = vm.serializeAddress("payload", "delegate", data.delegate);
        payload = vm.serializeAddress("payload", "delegator", data.delegator);
        payload = vm.serializeString("payload", "label", data.label);
        payload = vm.serializeBytes("payload", "signature", data.signature);
        return payload;
    }

    function _getRemovePayload() private returns (string memory) {
        string memory payload = "";
        payload = vm.serializeAddress("payload", "safe", data.safe);
        payload = vm.serializeAddress("payload", "delegator", data.delegator);
        payload = vm.serializeBytes("payload", "signature", data.signature);
        return payload;
    }

    function _getHash() private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId)"),
                        keccak256("Safe Transaction Service"),
                        keccak256("1.0"),
                        block.chainid
                    )
                ),
                keccak256(
                    abi.encode(keccak256("Delegate(address delegateAddress,uint256 totp)"), data.delegate, data.totp)
                )
            )
        );
    }
}
