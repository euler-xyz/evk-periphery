// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IOFT, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {FeeCollectorUtil, IERC20, SafeERC20} from "../Util/FeeCollectorUtil.sol";

/// @title OFTFeeCollector
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Collects and converts fees from multiple vaults, then sends them cross-chain via a LayerZero OFT adapter.
contract OFTFeeCollector is FeeCollectorUtil {
    using SafeERC20 for IERC20;

    /// @notice Role that can execute the fee collection process
    bytes32 public constant COLLECTOR_ROLE = keccak256("COLLECTOR_ROLE");

    /// @notice The LayerZero OFT adapter contract used for cross-chain transfers
    address public oftAdapter;

    /// @notice The destination address on the target chain to receive collected fees
    address public dstAddress;

    /// @notice The LayerZero endpoint ID of the destination chain
    uint32 public dstEid;

    /// @notice Bytes passed as part of the composed message
    bytes public composeMsg;

    /// @notice Bytes passed as part of the extra options
    bytes public extraOptions;

    /// @notice Error thrown when the OFT adapter token is not the same as the fee token
    error InvalidOFTAdapter();

    /// @notice Error thrown when the destination address is the zero address
    error InvalidDstAddress();

    /// @notice Initializes the OFTFeeCollector contract
    /// @param _evc The address of the EVC contract
    /// @param _admin The address that will be granted the DEFAULT_ADMIN_ROLE
    /// @param _feeToken The address of the ERC20 token used for fees
    constructor(address _evc, address _admin, address _feeToken) FeeCollectorUtil(_evc, _admin, _feeToken) {}

    /// @notice Allows the contract to receive ETH
    receive() external payable {}

    /// @notice Configures the OFTFeeCollector contract for cross-chain fee transfers
    /// @param _oftAdapter The LayerZero OFT adapter contract address
    /// @param _dstAddress The destination address on the target chain to receive fees
    /// @param _dstEid The LayerZero endpoint ID of the destination chain
    /// @param _composeMsg Bytes passed as part of the composed message
    /// @param _extraOptions Bytes passed as part of the extra options
    function configure(
        address _oftAdapter,
        address _dstAddress,
        uint32 _dstEid,
        bytes memory _composeMsg,
        bytes memory _extraOptions
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_oftAdapter != address(0) && address(feeToken) != IOFT(_oftAdapter).token()) {
            revert InvalidOFTAdapter();
        }

        if (_dstAddress == address(0)) {
            revert InvalidDstAddress();
        }

        oftAdapter = _oftAdapter;
        dstAddress = _dstAddress;
        dstEid = _dstEid;
        composeMsg = _composeMsg;
        extraOptions = _extraOptions;
    }

    /// @notice Collects and converts fees from all vaults, then sends them cross-chain to the configured destination.
    function collectFees() external virtual override onlyRole(COLLECTOR_ROLE) {
        address adapter = oftAdapter;
        if (adapter == address(0)) return;

        _convertAndRedeemFees();

        IERC20 token = feeToken;
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) return;

        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(dstAddress))),
            amountLD: balance,
            minAmountLD: 0,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });
        MessagingFee memory fee = IOFT(adapter).quoteSend(sendParam, false);

        if (address(this).balance >= fee.nativeFee) {
            token.forceApprove(adapter, balance);
            IOFT(adapter).send{value: fee.nativeFee}(sendParam, fee, address(this));
        }
    }
}
