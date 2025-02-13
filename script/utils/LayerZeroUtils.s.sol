// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {stdJson} from "forge-std/StdJson.sol";
import {ScriptUtils, ScriptExtended, Vm, console} from "../utils/ScriptUtils.s.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {ILayerZeroEndpointV2, IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IMessageLibManager} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

interface IEndpointV2 is ILayerZeroEndpointV2 {
    function eid() external view returns (uint32);
    function delegates(address oapp) external view returns (address);
}

contract LayerZeroUtil is ScriptExtended {
    using stdJson for string;

    struct DeploymentInfo {
        uint256 chainId;
        uint32 eid;
        string chainKey;
        address endpointV2;
        address executor;
        address sendUln302;
        address receiveUln302;
    }

    uint256 internal constant MAX_DEPLOYMENTS = 10;

    function getRawMetadata() public returns (string memory) {
        string[] memory inputs = new string[](3);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = getMatadataAPIURL();
        bytes memory result = vm.ffi(inputs);

        require(result.length != 0, "getRawMetadata: failed to get metadata");

        return string(result);
    }

    function getDeploymentInfo(uint256 chainId) public returns (DeploymentInfo memory) {
        return getDeploymentInfo(getRawMetadata(), chainId);
    }

    function getDeploymentInfo(string memory metadata, uint256 chainId)
        public
        view
        returns (DeploymentInfo memory result)
    {
        string[] memory keys = vm.parseJsonKeys(metadata, ".");

        for (uint256 i = 0; i < keys.length; ++i) {
            string memory key = string.concat(".", keys[i]);
            string memory deploymentsKey = string.concat(key, ".deployments");

            if (
                metadata.readUintOr(string.concat(key, ".chainDetails.nativeChainId"), 0) != chainId
                    || !vm.keyExists(metadata, deploymentsKey)
            ) continue;

            for (uint256 j = 0; j < MAX_DEPLOYMENTS; ++j) {
                if (!vm.keyExists(metadata, _indexedKey(deploymentsKey, j, ".endpointV2"))) {
                    continue;
                }

                result = DeploymentInfo({
                    chainId: chainId,
                    eid: uint32(vm.parseUint(metadata.readStringOr(_indexedKey(deploymentsKey, j, ".eid"), "0"))),
                    chainKey: metadata.readStringOr(_indexedKey(deploymentsKey, j, ".chainKey"), ""),
                    endpointV2: metadata.readAddressOr(_indexedKey(deploymentsKey, j, ".endpointV2.address"), address(0)),
                    executor: metadata.readAddressOr(_indexedKey(deploymentsKey, j, ".executor.address"), address(0)),
                    sendUln302: metadata.readAddressOr(_indexedKey(deploymentsKey, j, ".sendUln302.address"), address(0)),
                    receiveUln302: metadata.readAddressOr(
                        _indexedKey(deploymentsKey, j, ".receiveUln302.address"), address(0)
                    )
                });

                break;
            }

            if (
                result.endpointV2 != address(0) && result.executor != address(0) && result.sendUln302 != address(0)
                    && result.receiveUln302 != address(0)
            ) {
                break;
            }
        }

        require(
            result.endpointV2 == address(0)
                || (result.executor != address(0) && result.sendUln302 != address(0) && result.receiveUln302 != address(0)),
            "getDeploymentInfo: executor, sendUln302, or receiveUln302 is not set"
        );
    }

    function getDVNAddresses(string[] memory dvns, string memory chainKey)
        public
        returns (string[] memory, address[] memory)
    {
        return getDVNAddresses(getRawMetadata(), dvns, chainKey);
    }

    function getDVNAddresses(string memory metadata, string[] memory dvns, string memory chainKey)
        public
        view
        returns (string[] memory dvnNames, address[] memory dvnAddresses)
    {
        string memory key = string.concat(".", chainKey, ".dvns");
        require(vm.keyExists(metadata, key), "getDVNAddresses: dvns not found for a given chainKey");

        string[] memory keys = vm.parseJsonKeys(metadata, key);
        dvnNames = new string[](dvns.length);
        dvnAddresses = new address[](dvns.length);
        uint256 index;

        for (uint256 i = 0; i < dvns.length; ++i) {
            for (uint256 j = 0; j < keys.length; ++j) {
                if (
                    _strEq(metadata.readStringOr(string.concat(key, ".", keys[j], ".canonicalName"), ""), dvns[i])
                        && !metadata.readBoolOr(string.concat(key, ".", keys[j], ".lzReadCompatible"), false)
                        && !metadata.readBoolOr(string.concat(key, ".", keys[j], ".deprecated"), false)
                ) {
                    dvnNames[index] = dvns[i];
                    dvnAddresses[index++] = _toAddress(keys[j]);
                    break;
                }
            }
        }

        assembly {
            mstore(dvnNames, index)
            mstore(dvnAddresses, index)
        }
    }

    function getMatadataAPIURL() public pure returns (string memory) {
        return "https://metadata.layerzero-api.com/v1/metadata";
    }
}

contract LayerZeroReadConfig is ScriptUtils {
    function run() public {
        LayerZeroUtil lzUtil = new LayerZeroUtil();
        string memory lzMetadata = lzUtil.getRawMetadata();
        vm.makePersistent(address(lzUtil));
        uint256[] memory srcChainIds = getBridgeConfigSrcChainIds();

        for (uint256 i = 0; i < srcChainIds.length; ++i) {
            uint256 chainId = srcChainIds[i];
            uint256[] memory dstChainIds = getBridgeConfigDstChainIds(chainId);

            BridgeAddresses memory bridgeAddresses =
                deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", chainId));

            if (bridgeAddresses.oftAdapter == address(0)) {
                console.log("OFT Adapter not deployed for chain %s. Skipping...", chainId);
                console.log("--------------------------------");
                continue;
            }

            LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(lzMetadata, chainId);

            require(selectFork(chainId), "Fork not selected");
            require(IEndpointV2(info.endpointV2).eid() == info.eid, "Endpoint eid mismatch");

            address sendLib = IEndpointV2(info.endpointV2).getSendLibrary(bridgeAddresses.oftAdapter, info.eid);
            (address receiveLib, bool isDefault) =
                IEndpointV2(info.endpointV2).getReceiveLibrary(bridgeAddresses.oftAdapter, info.eid);

            console.log("OFT Adapter configuration for chain %s (eid %s):", chainId, info.eid);
            console.log("    OFT adapter: %s", bridgeAddresses.oftAdapter);
            console.log("    lzEndpoint: %s", info.endpointV2);
            console.log("    send library: %s", sendLib);
            console.log("    receive library: %s", receiveLib);
            console.log("    receive library is default: %s", isDefault);

            for (uint256 j = 0; j < dstChainIds.length; ++j) {
                uint256 chainIdOther = dstChainIds[j];

                LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(lzMetadata, chainIdOther);

                {
                    ExecutorConfig memory executorConfig = abi.decode(
                        IMessageLibManager(info.endpointV2).getConfig(
                            bridgeAddresses.oftAdapter, sendLib, infoOther.eid, 1
                        ),
                        (ExecutorConfig)
                    );
                    console.log("    send library config for chain id %s (eid %s):", chainIdOther, infoOther.eid);
                    console.log("        max message size: %s", executorConfig.maxMessageSize);
                    console.log("        executor: %s", executorConfig.executor);
                }

                {
                    UlnConfig memory sendUlnConfig = abi.decode(
                        IMessageLibManager(info.endpointV2).getConfig(
                            bridgeAddresses.oftAdapter, sendLib, infoOther.eid, 2
                        ),
                        (UlnConfig)
                    );
                    console.log("        confirmations: %s", sendUlnConfig.confirmations);
                    console.log("        requiredDVNCount: %s", sendUlnConfig.requiredDVNCount);
                    console.log("        optionalDVNCount: %s", sendUlnConfig.optionalDVNCount);
                    console.log("        optionalDVNThreshold: %s", sendUlnConfig.optionalDVNThreshold);
                    for (uint256 k = 0; k < sendUlnConfig.requiredDVNCount; ++k) {
                        console.log("        requiredDVNs[%s]: %s", k, sendUlnConfig.requiredDVNs[k]);
                    }
                    for (uint256 k = 0; k < sendUlnConfig.optionalDVNCount; ++k) {
                        console.log("        optionalDVNs[%s]: %s", k, sendUlnConfig.optionalDVNs[k]);
                    }
                }

                {
                    UlnConfig memory receiveUlnConfig = abi.decode(
                        IMessageLibManager(info.endpointV2).getConfig(
                            bridgeAddresses.oftAdapter, receiveLib, infoOther.eid, 2
                        ),
                        (UlnConfig)
                    );
                    console.log("    receive library config for chain id %s (eid %s):", chainIdOther, infoOther.eid);
                    console.log("        confirmations: %s", receiveUlnConfig.confirmations);
                    console.log("        requiredDVNCount: %s", receiveUlnConfig.requiredDVNCount);
                    console.log("        optionalDVNCount: %s", receiveUlnConfig.optionalDVNCount);
                    console.log("        optionalDVNThreshold: %s", receiveUlnConfig.optionalDVNThreshold);
                    for (uint256 k = 0; k < receiveUlnConfig.requiredDVNCount; ++k) {
                        console.log("        requiredDVNs[%s]: %s", k, receiveUlnConfig.requiredDVNs[k]);
                    }
                    for (uint256 k = 0; k < receiveUlnConfig.optionalDVNCount; ++k) {
                        console.log("        optionalDVNs[%s]: %s", k, receiveUlnConfig.optionalDVNs[k]);
                    }
                }

                console.log(
                    "    peer for chain id %s (eid %s): %s",
                    chainIdOther,
                    infoOther.eid,
                    address(uint160(uint256(IOAppCore(bridgeAddresses.oftAdapter).peers(infoOther.eid))))
                );

                {
                    bytes memory enforcedOptions =
                        OAppOptionsType3(bridgeAddresses.oftAdapter).enforcedOptions(infoOther.eid, 1);
                    console.log(
                        string.concat(
                            "    msgType 1 enforced options are ",
                            enforcedOptions.length > 0 ? "SET" : "NOT SET",
                            " for chain id ",
                            vm.toString(chainIdOther),
                            " (eid ",
                            vm.toString(infoOther.eid),
                            ")"
                        )
                    );

                    enforcedOptions = OAppOptionsType3(bridgeAddresses.oftAdapter).enforcedOptions(infoOther.eid, 2);
                    console.log(
                        string.concat(
                            "    msgType 2 enforced options are ",
                            enforcedOptions.length > 0 ? "SET" : "NOT SET",
                            " for chain id ",
                            vm.toString(chainIdOther),
                            " (eid ",
                            vm.toString(infoOther.eid),
                            ")"
                        )
                    );
                }
            }
            console.log("--------------------------------");
        }
    }

    function getLayerZeroConfig() public {
        LayerZeroUtil lzUtil = new LayerZeroUtil();
        string memory lzMetadata = lzUtil.getRawMetadata();
        vm.makePersistent(address(lzUtil));
        uint256[] memory srcChainIds = getBridgeConfigSrcChainIds();
        string memory globalConfig;

        for (uint256 i = 0; i < srcChainIds.length; ++i) {
            uint256 chainId = srcChainIds[i];
            uint256[] memory dstChainIds = getBridgeConfigDstChainIds(chainId);

            LayerZeroUtil.DeploymentInfo memory info = lzUtil.getDeploymentInfo(lzMetadata, chainId);
            string memory eid = vm.toString(info.eid);

            vm.serializeString(eid, "chainKey", info.chainKey);
            vm.serializeString(eid, "chainId", vm.toString(chainId));
            vm.serializeAddress(
                eid,
                "oftAdapter",
                deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", chainId)).oftAdapter
            );
            vm.serializeAddress(
                eid, "eul", deserializeTokenAddresses(getAddressesJson("TokenAddresses.json", chainId)).EUL
            );

            string memory routes;
            for (uint256 j = 0; j < dstChainIds.length; ++j) {
                uint256 chainIdOther = dstChainIds[j];
                LayerZeroUtil.DeploymentInfo memory infoOther = lzUtil.getDeploymentInfo(lzMetadata, chainIdOther);
                string memory eidOther = vm.toString(infoOther.eid);
                string memory key = string.concat("route.", eidOther);

                vm.serializeString(key, "chainKey", infoOther.chainKey);
                vm.serializeString(key, "chainId", vm.toString(chainIdOther));
                vm.serializeAddress(
                    key,
                    "oftAdapter",
                    deserializeBridgeAddresses(getAddressesJson("BridgeAddresses.json", chainIdOther)).oftAdapter
                );
                string memory route = vm.serializeAddress(
                    key, "eul", deserializeTokenAddresses(getAddressesJson("TokenAddresses.json", chainIdOther)).EUL
                );
                routes = vm.serializeString(string.concat("routes.", eid), eidOther, route);
            }

            string memory chainConfig = vm.serializeString(eid, "routes", routes);
            globalConfig = vm.serializeString("globalConfig", eid, chainConfig);
        }

        vm.writeJson(globalConfig, string.concat(vm.projectRoot(), "/script/layerZeroConfig.json"));
    }
}

contract LayerZeroSendEUL is ScriptUtils {
    function run(uint256 dstChainId, address dstAddress, uint256 amount)
        public
        returns (MessagingReceipt memory, OFTReceipt memory)
    {
        ERC20 eul = ERC20(tokenAddresses.EUL);
        (address oftAdapter, uint256 fee, bytes memory data) = getSendCalldata(dstChainId, dstAddress, amount, 0);

        startBroadcast();
        eul.approve(oftAdapter, amount);
        (bool success, bytes memory result) = oftAdapter.call{value: fee}(data);
        stopBroadcast();

        require(success && result.length > 0, "send failed");
        return abi.decode(result, (MessagingReceipt, OFTReceipt));
    }

    function getSendCalldata(uint256 dstChainId, address dstAddress, uint256 amount, uint256 nativeFeeMultiplierBps)
        public
        returns (address to, uint256 value, bytes memory data)
    {
        IOFT oftAdapter = IOFT(bridgeAddresses.oftAdapter);

        SendParam memory sendParam = SendParam(
            (new LayerZeroUtil()).getDeploymentInfo(dstChainId).eid,
            bytes32(uint256(uint160(dstAddress))),
            amount,
            amount,
            "",
            "",
            ""
        );
        MessagingFee memory fee = oftAdapter.quoteSend(sendParam, false);
        fee.nativeFee = fee.nativeFee * ((1e4 + nativeFeeMultiplierBps) / 1e4);

        return (bridgeAddresses.oftAdapter, fee.nativeFee, abi.encodeCall(IOFT.send, (sendParam, fee, dstAddress)));
    }
}
