// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ScriptExtended} from "./ScriptExtended.s.sol";
import {Surl} from "./Surl.sol";
import {console} from "forge-std/console.sol";

// inspired by https://github.com/ind-igo/forge-safe

contract SafeUtil is ScriptExtended {
    using Surl for *;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct Status {
        address safe;
        uint256 chainId;
        uint256 nonce;
        uint256 threshold;
        address[] owners;
        address implementation;
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

    struct TransactionSimple {
        address safe;
        string txId;
        string txStatus;
        address to;
        uint256 value;
        bytes data;
        Operation operation;
        uint256 nonce;
        bytes32 hash;
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

    function isTransactionServiceAPIAvailable() public view returns (bool) {
        return !_strEq(getSafeBaseURL(), "");
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
        (uint256 status, bytes memory response) = endpoint.get(getHeaders());

        require(status == 200, "getSafes: Failed to get safes");

        return Status({
            safe: vm.parseJsonAddress(string(response), ".address.value"),
            chainId: vm.parseJsonUint(string(response), ".chainId"),
            nonce: vm.parseJsonUint(string(response), ".nonce"),
            threshold: vm.parseJsonUint(string(response), ".threshold"),
            owners: parseJsonAddressesFromValueKeys(string(response), ".owners"),
            implementation: vm.parseJsonAddress(string(response), ".implementation.value"),
            version: vm.parseJsonString(string(response), ".version")
        });
    }

    function getNextNonce(address safe) public returns (uint256) {
        string memory endpoint =
            string.concat(getSafesAPIBaseURL(), vm.toString(safe), "/multisig-transactions/?executed=false&limit=1");
        (uint256 status, bytes memory response) = endpoint.get(getHeaders());
        require(status == 200, "getNextNonce: Failed to get last pending transaction");

        uint256 lastPendingNonce = vm.keyExists(string(response), _indexedKey(".results", 0, ".nonce"))
            ? vm.parseJsonUint(string(response), _indexedKey(".results", 0, ".nonce"))
            : 0;

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
            (status, response) = endpoint.get(getHeaders());
            require(status == 200, "getNextNonce: Failed to get pending transaction");

            if (!vm.keyExists(string(response), _indexedKey(".results", 0, ".nonce"))) return nonce;
        }

        return ++lastPendingNonce;
    }

    function getSafes(address owner) public returns (address[] memory) {
        string memory endpoint = string.concat(getOwnersAPIBaseURL(), vm.toString(owner), "/safes/");
        (uint256 status, bytes memory response) = endpoint.get(getHeaders());

        require(status == 200, "getSafes: Failed to get safes");

        return vm.parseJsonAddressArray(string(response), ".safes");
    }

    function getDelegates(address safe) public returns (address[] memory) {
        string memory endpoint = string.concat(getDelegatesAPIBaseURL(), "?safe=", vm.toString(safe));
        (uint256 status, bytes memory response) = endpoint.get(getHeaders());

        require(status == 200, "getDelegates: Failed to get delegates");

        uint256 count = vm.parseJsonUint(string(response), ".count");
        address[] memory delegates = new address[](count);

        for (uint256 i = 0; i < count; ++i) {
            delegates[i] = vm.parseJsonAddress(string(response), _indexedKey(".results", i, ".delegate"));
        }

        return delegates;
    }

    function getPendingTransactions(address safe) public returns (TransactionSimple[] memory) {
        string memory endpoint = string.concat(getSafesAPIBaseURL(), vm.toString(safe), "/transactions/queued");
        (uint256 status, bytes memory response) = endpoint.get(getHeaders());
        require(status == 200, "getPendingTransactions: Failed to get pending transactions");

        uint256 length = 0;
        uint256 counter = 0;

        while (vm.keyExists(string(response), _indexedKey(".results", length, ".type"))) {
            if (_strEq(vm.parseJsonString(string(response), _indexedKey(".results", length, ".type")), "TRANSACTION")) {
                ++counter;
            }
            ++length;
        }

        TransactionSimple[] memory transactions = new TransactionSimple[](counter);
        counter = 0;
        for (uint256 i = 0; i < length; ++i) {
            if (
                !vm.keyExists(string(response), _indexedKey(".results", i, ".type"))
                    || !_strEq(vm.parseJsonString(string(response), _indexedKey(".results", i, ".type")), "TRANSACTION")
            ) {
                continue;
            }

            transactions[counter++] =
                getTransaction(vm.parseJsonString(string(response), _indexedKey(".results", i, ".transaction.id")));
        }

        return transactions;
    }

    function getTransaction(string memory txId) public returns (TransactionSimple memory) {
        string memory endpoint = string.concat(getTransactionsAPIBaseURL(), txId);
        (uint256 status, bytes memory response) = endpoint.get(getHeaders());

        require(status == 200, "getTransaction: Failed to get transaction");

        TransactionSimple memory transaction = TransactionSimple({
            safe: vm.parseJsonAddress(string(response), ".safeAddress"),
            txId: vm.parseJsonString(string(response), ".txId"),
            txStatus: vm.parseJsonString(string(response), ".txStatus"),
            to: address(0),
            value: 0,
            data: "",
            operation: Operation(vm.parseJsonUint(string(response), ".txData.operation")),
            nonce: vm.parseJsonUint(string(response), ".detailedExecutionInfo.nonce"),
            hash: vm.parseJsonBytes32(string(response), ".detailedExecutionInfo.safeTxHash")
        });

        try vm.parseJsonAddress(string(response), ".txInfo.to.value") returns (address to) {
            transaction.to = to;
        } catch {
            transaction.to = transaction.safe;
        }

        try vm.parseJsonUint(string(response), ".txInfo.value") returns (uint256 value) {
            transaction.value = value;
        } catch {}

        try vm.parseJsonBytes(string(response), ".txData.hexData") returns (bytes memory data) {
            transaction.data = data;
        } catch {}

        return transaction;
    }

    function getSafesAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseAPIURL("v1"), "safes/");
    }

    function getTransactionsAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseAPIURL("v1"), "transactions/");
    }

    function getOwnersAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseAPIURL("v1"), "owners/");
    }

    function getDelegatesAPIBaseURL() public view returns (string memory) {
        return string.concat(getSafeBaseAPIURL("v2"), "delegates/");
    }

    function getSafeBaseURL() public view returns (string memory) {
        if (
            block.chainid == 1 || block.chainid == 10 || block.chainid == 100 || block.chainid == 130
                || block.chainid == 137 || block.chainid == 143 || block.chainid == 146 || block.chainid == 42161
                || block.chainid == 43114 || block.chainid == 480 || block.chainid == 56 || block.chainid == 5000
                || block.chainid == 57073 || block.chainid == 59144 || block.chainid == 8453 || block.chainid == 9745
                || block.chainid == 999
        ) {
            return "https://safe-client.safe.global/";
        } else if (block.chainid == 1923) {
            return "https://gateway.safe.optimism.io/";
        } else if (block.chainid == 21000000) {
            return "https://safe-cgw-corn.safe.onchainden.com/";
        } else if (block.chainid == 239) {
            return "https://gateway.safe.tac.build/";
        } else if (block.chainid == 60808) {
            return "https://gateway.safe.gobob.xyz/";
        } else if (block.chainid == 80094) {
            return "https://gateway.safe.berachain.com/";
        } else {
            revert("getSafeBaseURL: Unsupported chain id");
        }
    }

    function getSafeBaseAPIURL(string memory version) public view returns (string memory) {
        return string.concat(getSafeBaseURL(), version, "/chains/", vm.toString(block.chainid), "/");
    }

    function getHeaders() internal view returns (string[] memory) {
        string[] memory headers;
        string memory safeApiKey = vm.envOr("SAFE_API_KEY", string(""));

        if (bytes(safeApiKey).length == 0) {
            headers = new string[](2);
        } else {
            headers = new string[](3);
            headers[2] = string.concat("Authorization: Bearer ", safeApiKey);
        }

        headers[0] = "Accept: application/json";
        headers[1] = "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36";

        return headers;
    }

    function parseJsonAddressesFromValueKeys(string memory response, string memory key)
        internal
        view
        returns (address[] memory)
    {
        uint256 length = 0;

        while (vm.keyExists(string(response), _indexedKey(key, length, ".value"))) {
            ++length;
        }

        address[] memory addresses = new address[](length);
        for (uint256 i = 0; i < length; ++i) {
            addresses[i] = vm.parseJsonAddress(string(response), _indexedKey(key, i, ".value"));
        }

        return addresses;
    }
}

contract SafeTransaction is SafeUtil {
    using Surl for *;

    bool internal simulateBeforeCreation;
    Transaction internal transaction;

    constructor() {
        simulateBeforeCreation = true;
    }

    function setSimulationOn() public {
        simulateBeforeCreation = true;
    }

    function setSimulationOff() public {
        simulateBeforeCreation = false;
    }

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

        if (transaction.operation == Operation.CALL) {
            string memory batchBuilderFileName = string.concat(
                "SafeBatchBuilder_", vm.toString(transaction.nonce), "_", vm.toString(transaction.safe), ".json"
            );
            _dumpBatchBuilderFile(batchBuilderFileName);
        }
    }

    function simulate(bool isCallOperation, address safe, address target, uint256 value, bytes memory data) public {
        bool simulateBeforeCreationCache = simulateBeforeCreation;
        simulateBeforeCreation = true;

        delete transaction;
        transaction.safe = safe;
        transaction.sender = address(0);
        transaction.to = target;
        transaction.value = value;
        transaction.data = data;
        transaction.operation = isCallOperation ? Operation.CALL : Operation.DELEGATECALL;
        _simulate();

        simulateBeforeCreation = simulateBeforeCreationCache;
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
        if (!simulateBeforeCreation) return;

        if (
            transaction.sender != address(0) && isSafeOwnerSimulate() && isTransactionServiceAPIAvailable()
                && !isSafeOwnerOrDelegate(transaction.safe, transaction.sender)
        ) {
            console.log(
                "Sender (%s) not authorized to execute a transaction on Safe (%s)", transaction.sender, transaction.safe
            );
            revert("Not authorized");
        }

        if (transaction.operation == Operation.CALL) {
            vm.prank(transaction.safe);
            (bool success, bytes memory result) = transaction.to.call{value: transaction.value}(transaction.data);
            require(success, string(result));
        } else {
            address multisendMock = address(new MultisendMock(transaction.safe));
            (bool success, bytes memory result) = multisendMock.call{value: transaction.value}(transaction.data);
            require(success, string(result));
        }
    }

    function _create() private {
        string memory payloadFileName = string.concat(
            "SafeTransaction_", vm.toString(transaction.nonce), "_", vm.toString(transaction.safe), ".json"
        );
        _dumpSafeTransaction(payloadFileName);

        if (transaction.operation == Operation.CALL) {
            string memory batchBuilderFileName = string.concat(
                "SafeBatchBuilder_", vm.toString(transaction.nonce), "_", vm.toString(transaction.safe), ".json"
            );
            _dumpBatchBuilderFile(batchBuilderFileName);
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

    function _getBatchBuilderFile() private returns (string memory) {
        string memory content = "";
        content = vm.serializeString("content", "chainId", vm.toString(block.chainid));
        content = vm.serializeUint("content", "createdAt", block.timestamp);

        string memory meta = "";
        meta = vm.serializeString("meta", "name", "Safe Transaction");
        meta = vm.serializeAddress("meta", "createdFromSafeAddress", transaction.safe);
        meta = vm.serializeAddress("meta", "createdFromOwnerAddress", transaction.sender);
        content = vm.serializeString("content", "meta", meta);

        string[] memory transactions = new string[](1);
        transactions[0] = vm.serializeAddress("transaction", "to", transaction.to);
        transactions[0] = vm.serializeString("transaction", "value", vm.toString(transaction.value));
        transactions[0] = vm.serializeBytes("transaction", "data", transaction.data);

        return vm.serializeString("content", "transactions", transactions);
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
        console.log("Safe transaction payload saved to %s", fileName);
        vm.writeJson(_getPayload(), string.concat(vm.projectRoot(), "/script/", fileName));
    }

    function _dumpBatchBuilderFile(string memory fileName) private {
        console.log("Safe Batch Builder file saved to %s", fileName);
        vm.writeJson(_getBatchBuilderFile(), string.concat(vm.projectRoot(), "/script/", fileName));
    }
}

contract SafeMultisendBuilder is SafeUtil {
    struct MultisendItem {
        address targetContract;
        uint256 value;
        bytes data;
    }

    MultisendItem[] internal multisendItems;

    function addMultisendItem(address targetContract, bytes memory data) public {
        addMultisendItem(targetContract, 0, data);
    }

    function addMultisendItem(address targetContract, uint256 value, bytes memory data) public {
        multisendItems.push(MultisendItem({targetContract: targetContract, value: value, data: data}));
    }

    function multisendItemExists() public view returns (bool) {
        return multisendItems.length > 0;
    }

    function executeMultisend(address safe, uint256 safeNonce) public {
        executeMultisend(safe, safeNonce, true, true);
    }

    function executeMultisend(address safe, uint256 safeNonce, bool isCallOnly, bool isSimulation) public {
        if (multisendItems.length == 0) return;

        console.log("\nExecuting the multicall via Safe (%s)", safe);

        SafeTransaction transaction = new SafeTransaction();

        if (!isSimulation) transaction.setSimulationOff();

        _dumpMultisendBatchBuilderFile(
            safe, string.concat("SafeBatchBuilder_", vm.toString(safeNonce), "_", vm.toString(safe), ".json")
        );

        transaction.create(
            false,
            safe,
            _getMultisendAddress(block.chainid, isCallOnly),
            _getMultisendValue(),
            _getMultisendCalldata(),
            safeNonce++
        );

        delete multisendItems;
    }

    function _getMultisendCalldata() internal view returns (bytes memory) {
        bytes memory data;
        for (uint256 i = 0; i < multisendItems.length; ++i) {
            data = bytes.concat(
                data,
                abi.encodePacked(
                    Operation.CALL,
                    multisendItems[i].targetContract,
                    multisendItems[i].value,
                    multisendItems[i].data.length,
                    multisendItems[i].data
                )
            );
        }
        return abi.encodeWithSignature("multiSend(bytes)", data);
    }

    function _getMultisendValue() internal view returns (uint256 value) {
        for (uint256 i = 0; i < multisendItems.length; ++i) {
            value += multisendItems[i].value;
        }
    }

    function _getMultisendAddress(uint256 chainId, bool isCallOnly) internal pure returns (address) {
        if (
            chainId == 1 || chainId == 10 || chainId == 100 || chainId == 130 || chainId == 137 || chainId == 143
                || chainId == 146 || chainId == 239 || chainId == 2390 || chainId == 2818 || chainId == 30
                || chainId == 42161 || chainId == 43114 || chainId == 480 || chainId == 5000 || chainId == 56
                || chainId == 57073 || chainId == 59144 || chainId == 60808 || chainId == 80094 || chainId == 8453
                || chainId == 9745 || chainId == 999
        ) {
            if (isCallOnly) return 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
            revert("getMultisendAddress: Unsupported multisend mode");
        } else {
            revert("getMultisendAddress: Unsupported chain");
        }
    }

    function _simulateMultisend(address caller) internal {
        console.log("Simulating the multisend call execution as %s", caller);

        vm.startPrank(caller);
        for (uint256 i = 0; i < multisendItems.length; ++i) {
            (bool success, bytes memory result) =
                multisendItems[i].targetContract.call{value: multisendItems[i].value}(multisendItems[i].data);

            require(success, string.concat("Multisend item ", vm.toString(i), " failed: ", string(result)));
        }
        vm.stopPrank();
    }

    function _dumpMultisendBatchBuilderFile(address safe, string memory fileName) internal {
        console.log("Safe Batch Builder file saved to %s", fileName);
        vm.writeJson(_getBatchBuilderFile(safe), string.concat(vm.projectRoot(), "/script/", fileName));
    }

    function _getBatchBuilderFile(address safe) private returns (string memory) {
        string memory content = "";
        content = vm.serializeString("content", "chainId", vm.toString(block.chainid));
        content = vm.serializeUint("content", "createdAt", block.timestamp);

        string memory meta = "";
        meta = vm.serializeString("meta", "name", "Safe Transaction");
        meta = vm.serializeAddress("meta", "createdFromSafeAddress", safe);
        content = vm.serializeString("content", "meta", meta);

        string[] memory transactions = new string[](multisendItems.length);

        for (uint256 i = 0; i < multisendItems.length; ++i) {
            transactions[i] = vm.serializeAddress("transaction", "to", multisendItems[i].targetContract);
            transactions[i] = vm.serializeString("transaction", "value", vm.toString(multisendItems[i].value));
            transactions[i] = vm.serializeBytes("transaction", "data", multisendItems[i].data);
        }

        return vm.serializeString("content", "transactions", transactions);
    }
}

contract MultisendMock is ScriptExtended {
    address internal immutable msgSender;

    constructor(address _msgSender) {
        msgSender = _msgSender;
    }

    function multiSend(bytes memory transactions) public payable {
        uint256 length;
        uint256 i;

        assembly {
            length := mload(transactions)
            i := 0x20
        }

        while (i < length) {
            uint256 operation;
            uint256 to;
            uint256 value;
            uint256 dataLength;
            uint256 data;

            assembly {
                operation := shr(0xf8, mload(add(transactions, i)))
                to := shr(0x60, mload(add(transactions, add(i, 0x01))))
                value := mload(add(transactions, add(i, 0x15)))
                dataLength := mload(add(transactions, add(i, 0x35)))
                data := add(transactions, add(i, 0x55))
            }

            if (operation == 0) {
                vm.prank(msgSender);
            } else {
                vm.prank(msgSender, true);
            }

            assembly {
                let success := 0
                switch operation
                case 0 { success := call(gas(), to, value, data, dataLength, 0, 0) }
                case 1 { success := delegatecall(gas(), to, data, dataLength, 0, 0) }
                if eq(success, 0) { revert(0, 0) }
                i := add(i, add(0x55, dataLength))
            }
        }
    }
}
