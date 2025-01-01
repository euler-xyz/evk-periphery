// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ScriptExtended} from "./ScriptExtended.s.sol";
import {Surl} from "./Surl.sol";
import {console} from "forge-std/console.sol";

// inspired by https://github.com/ind-igo/forge-safe

abstract contract SafeUtil is ScriptExtended {
    using Surl for *;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct Status {
        address safe;
        uint256 nonce;
        uint256 threshold;
        address[] owners;
        address masterCopy;
        address[] modules;
        address fallbackHandler;
        address guard;
        string version;
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

    struct Delegate {
        address safe;
        address delegator;
        address delegate;
        string label;
        uint256 totp;
        bytes32 hash;
        bytes signature;
    }

    mapping(uint256 => bool) private transactionServiceAPIAvailable;

    constructor() {
        transactionServiceAPIAvailable[1] = true;
        transactionServiceAPIAvailable[10] = true;
        transactionServiceAPIAvailable[137] = true;
        transactionServiceAPIAvailable[8453] = true;
        transactionServiceAPIAvailable[42161] = true;
        transactionServiceAPIAvailable[43114] = true;
    }

    function isTransactionServiceAPIAvailable() public view returns (bool) {
        return transactionServiceAPIAvailable[block.chainid];
    }

    function isSafeOwnerOrDelegate(address safe, address account) public returns (bool) {
        Status memory status = getStatus(safe);
        for (uint256 i = 0; i < status.owners.length; ++i) {
            if (status.owners[i] == account) return true;
        }

        address[] memory delegates = getDelegates(safe);
        for (uint256 i = 0; i < delegates.length; ++i) {
            if (delegates[i] == account) return true;
        }

        return false;
    }

    function getStatus(address safe) public returns (Status memory) {
        string memory endpoint = string.concat(getSafesAPIBaseURL(), vm.toString(safe), "/");
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            return Status({
                safe: vm.parseJsonAddress(string(response), ".address"),
                nonce: vm.parseJsonUint(string(response), ".nonce"),
                threshold: vm.parseJsonUint(string(response), ".threshold"),
                owners: vm.parseJsonAddressArray(string(response), ".owners"),
                masterCopy: vm.parseJsonAddress(string(response), ".masterCopy"),
                modules: vm.parseJsonAddressArray(string(response), ".modules"),
                fallbackHandler: vm.parseJsonAddress(string(response), ".fallbackHandler"),
                guard: vm.parseJsonAddress(string(response), ".guard"),
                version: vm.parseJsonString(string(response), ".version")
            });
        } else {
            revert("getSafes: Failed to get safes");
        }
    }

    function getNextNonce(address safe) public returns (uint256) {
        string memory endpoint =
            string.concat(getSafesAPIBaseURL(), vm.toString(safe), "/multisig-transactions/?executed=false&limit=1");
        (uint256 status, bytes memory response) = endpoint.get();
        require(status == 200, "getNextNonce: Failed to get last pending transaction");

        uint256 lastPendingNonce = abi.decode(vm.parseJson(string(response), ".results"), (string[])).length == 0
            ? 0
            : vm.parseJsonUint(string(response), resultsIndexKey(0, "nonce"));

        uint256 stateNextNonce = getStatus(safe).nonce;

        if (lastPendingNonce < stateNextNonce) return stateNextNonce;
        else if (lastPendingNonce == stateNextNonce) return ++lastPendingNonce;

        for (uint256 nonce = stateNextNonce; nonce < lastPendingNonce; ++nonce) {
            endpoint = string.concat(
                getSafesAPIBaseURL(),
                vm.toString(safe),
                "/multisig-transactions/?executed=false&nonce=",
                vm.toString(nonce)
            );
            (status, response) = endpoint.get();
            require(status == 200, "getNextNonce: Failed to get pending transaction");

            if (abi.decode(vm.parseJson(string(response), ".results"), (string[])).length == 0) return nonce;
        }

        return ++lastPendingNonce;
    }

    function getSafes(address owner) public returns (address[] memory) {
        string memory endpoint = string.concat(getOwnersAPIBaseURL(), vm.toString(owner), "/safes/");
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            return vm.parseJsonAddressArray(string(response), ".safes");
        } else {
            revert("getSafes: Failed to get safes");
        }
    }

    function getDelegates(address safe) public returns (address[] memory) {
        string memory endpoint = string.concat(getDelegatesAPIBaseURL(), "?safe=", vm.toString(safe));
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            uint256 count = vm.parseJsonUint(string(response), ".count");
            address[] memory delegates = new address[](count);

            for (uint256 i = 0; i < count; ++i) {
                delegates[i] = vm.parseJsonAddress(string(response), resultsIndexKey(i, "delegate"));
            }

            return delegates;
        } else {
            revert("getDelegates: Failed to get delegates");
        }
    }

    function getPendingTransactions(address safe) public returns (Transaction[] memory) {
        string memory endpoint =
            string.concat(getSafesAPIBaseURL(), vm.toString(safe), "/multisig-transactions/?executed=false&limit=10");
        (uint256 status, bytes memory response) = endpoint.get();

        if (status == 200) {
            uint256 nonce = getStatus(safe).nonce;
            uint256 length = abi.decode(vm.parseJson(string(response), ".results"), (string[])).length;
            uint256 counter = 0;

            for (uint256 i = 0; i < length; ++i) {
                if (vm.parseJsonUint(string(response), resultsIndexKey(i, "nonce")) >= nonce) {
                    ++counter;
                }
            }

            Transaction[] memory transactions = new Transaction[](counter);
            counter = 0;
            for (int256 index = int256(length - 1); index >= 0; --index) {
                uint256 i = uint256(index);
                uint256 txNonce = vm.parseJsonUint(string(response), resultsIndexKey(i, "nonce"));

                if (txNonce < nonce) continue;

                transactions[counter] = Transaction({
                    safe: vm.parseJsonAddress(string(response), resultsIndexKey(i, "safe")),
                    sender: address(0),
                    to: vm.parseJsonAddress(string(response), resultsIndexKey(i, "to")),
                    value: vm.parseJsonUint(string(response), resultsIndexKey(i, "value")),
                    data: "",
                    operation: Operation(vm.parseJsonUint(string(response), resultsIndexKey(i, "operation"))),
                    safeTxGas: vm.parseJsonUint(string(response), resultsIndexKey(i, "safeTxGas")),
                    baseGas: vm.parseJsonUint(string(response), resultsIndexKey(i, "baseGas")),
                    gasPrice: vm.parseJsonUint(string(response), resultsIndexKey(i, "gasPrice")),
                    gasToken: vm.parseJsonAddress(string(response), resultsIndexKey(i, "gasToken")),
                    refundReceiver: vm.parseJsonAddress(string(response), resultsIndexKey(i, "refundReceiver")),
                    nonce: txNonce,
                    hash: vm.parseJsonBytes32(string(response), resultsIndexKey(i, "safeTxHash")),
                    signature: ""
                });

                try vm.parseJsonBytes(string(response), resultsIndexKey(i, "data")) returns (bytes memory data) {
                    transactions[counter].data = data;
                } catch {}

                ++counter;
            }

            return transactions;
        } else {
            revert("getPendingTransactions: Failed to get pending transactions list");
        }
    }

    function getSafesAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseURL(), "api/v1/safes/");
    }

    function getOwnersAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseURL(), "api/v1/owners/");
    }

    function getDelegatesAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseURL(), "api/v2/delegates/");
    }

    function getSafeBaseURL() public view returns (string memory) {
        require(isTransactionServiceAPIAvailable(), "Transaction service API is not available");

        if (block.chainid == 1) {
            return "https://safe-transaction-mainnet.safe.global/";
        } else if (block.chainid == 10) {
            return "https://safe-transaction-optimism.safe.global/";
        } else if (block.chainid == 137) {
            return "https://safe-transaction-polygon.safe.global/";
        } else if (block.chainid == 8453) {
            return "https://safe-transaction-base.safe.global/";
        } else if (block.chainid == 42161) {
            return "https://safe-transaction-arbitrum.safe.global/";
        } else if (block.chainid == 43114) {
            return "https://safe-transaction-avalanche.safe.global/";
        } else {
            return "";
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

    function resultsIndexKey(uint256 i, string memory key) private pure returns (string memory) {
        return string.concat(".results[", vm.toString(i), "].", key);
    }
}

contract SafeTransaction is SafeUtil {
    using Surl for *;

    Transaction internal transaction;

    function create(bool isCallOperation, address safe, address target, uint256 value, bytes memory data, uint256 nonce)
        public
    {
        delete transaction;
        _initialize(isCallOperation, safe, target, value, data, nonce);
        _simulate();
        _create();
    }

    function createManually(
        bool isCallOperation,
        address safe,
        address target,
        uint256 value,
        bytes memory data,
        uint256 nonce
    ) public {
        delete transaction;
        _initialize(isCallOperation, safe, target, value, data, nonce);

        transaction.sender = address(0);
        transaction.signature = "";

        _simulate();

        string memory payloadFileName = string.concat(
            "SafeTransaction_", vm.toString(transaction.nonce), "_", vm.toString(transaction.safe), ".json"
        );
        _dumpSafeTransaction(payloadFileName);

        console.log("Sign the following hash:");
        console.logBytes32(transaction.hash);

        console.log("");
        console.log("and send the following POST request adding the sender address and the signature to the payload:");
        console.log(_getCreateCurlCommand());
    }

    function simulate(bool isCallOperation, address safe, address target, uint256 value, bytes memory data) public {
        delete transaction;
        transaction.safe = safe;
        transaction.sender = address(0);
        transaction.to = target;
        transaction.value = value;
        transaction.data = data;
        transaction.operation = isCallOperation ? Operation.CALL : Operation.DELEGATECALL;
        _simulate();
    }

    function _initialize(
        bool isCallOperation,
        address safe,
        address target,
        uint256 value,
        bytes memory data,
        uint256 nonce
    ) private {
        transaction.safe = safe;
        transaction.sender = getSafeSigner();
        transaction.to = target;
        transaction.value = value;
        transaction.data = data;
        transaction.operation = isCallOperation ? Operation.CALL : Operation.DELEGATECALL;
        transaction.safeTxGas = 0;
        transaction.baseGas = 0;
        transaction.gasPrice = 0;
        transaction.gasToken = address(0);
        transaction.refundReceiver = address(0);
        transaction.nonce = nonce;
        transaction.hash = _getHash();

        if (transaction.sender == address(0)) {
            transaction.signature = "";
        } else {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(transaction.sender, transaction.hash);
            transaction.signature = abi.encodePacked(r, s, v);
        }
    }

    function _simulate() private {
        if (
            transaction.sender != address(0) && isTransactionServiceAPIAvailable()
                && !isSafeOwnerOrDelegate(transaction.safe, transaction.sender)
        ) {
            console.log(
                "Sender (%s) not authorized to execute a transaction on Safe (%s)", transaction.sender, transaction.safe
            );
            revert("Not authorized");
        }

        vm.prank(transaction.safe, transaction.operation == Operation.CALL ? false : true);
        (bool success, bytes memory result) = transaction.operation == Operation.CALL
            ? transaction.to.call{value: transaction.value}(transaction.data)
            : transaction.to.delegatecall(transaction.data);
        require(success, string(result));
    }

    function _create() private {
        string memory payloadFileName = string.concat(
            "SafeTransaction_", vm.toString(transaction.nonce), "_", vm.toString(transaction.safe), ".json"
        );
        _dumpSafeTransaction(payloadFileName);

        if (!isUseSafeApi()) {
            console.log("Send the following POST request:");
            console.log(_getCreateCurlCommand());
            return;
        } else if (!isBroadcast()) {
            return;
        }

        string memory endpoint =
            string.concat(getSafesAPIBaseURL(), vm.toString(transaction.safe), "/multisig-transactions/");
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

    function _dumpSafeTransaction(string memory fileName) private {
        console.log("Safe transaction payload saved to %s\n", fileName);
        vm.writeJson(_getPayload(), string.concat(vm.projectRoot(), "/script/", fileName));
    }

    function _getCreateCurlCommand() internal view returns (string memory) {
        if (isTransactionServiceAPIAvailable()) {
            return string.concat(
                "curl -X POST ",
                getSafesAPIBaseURL(),
                vm.toString(transaction.safe),
                "/multisig-transactions/ ",
                getHeadersString(),
                "--data-binary @<payload file>\n"
            );
        } else {
            return "Transaction service API is not available. Transaction must be created manually.";
        }
    }
}

contract SafeDelegation is SafeUtil {
    using Surl for *;

    Delegate internal data;

    function create(address safe, address delegate, string memory label) public {
        _initialize(safe, delegate, label);
        _create();
    }

    function createManually(address safe, address delegate, string memory label) public {
        _initialize(safe, delegate, label);
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
        _initialize(safe, delegate, "");
        _remove();
    }

    function removeManually(address safe, address delegate) public {
        _initialize(safe, delegate, "");

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

    function _initialize(address safe, address delegate, string memory label) private {
        data.safe = safe;
        data.delegator = getSafeSigner();
        data.delegate = delegate;
        data.label = label;
        data.totp = block.timestamp / 1 hours;
        data.hash = _getHash();

        if (data.delegator == address(0)) {
            data.signature = "";
        } else {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(data.delegator, data.hash);
            data.signature = abi.encodePacked(r, s, v);
        }
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
