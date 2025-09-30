// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IOFT, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @title OFTFeeCollector
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that converts fees on multiple EVaults and sends them cross-chain via LayerZero OFT adapter.
contract OFTFeeCollector is AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Role that can add and remove vaults from the list
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    /// @notice Role that can execute the fee collection process
    bytes32 public constant COLLECTOR_ROLE = keccak256("COLLECTOR_ROLE");

    /// @notice The ERC20 token used for fees (retrieved from the OFT adapter)
    IERC20 public feeToken;

    /// @notice The LayerZero OFT adapter contract used for cross-chain transfers
    address public oftAdapter;

    /// @notice The destination address on the target chain to receive collected fees
    address public dstAddress;

    /// @notice The LayerZero endpoint ID of the destination chain
    uint32 public dstEid;

    /// @notice Whether to use composed message for cross-chain communication
    bool public isComposedMsg;

    /// @notice Internal set of vault addresses from which fees are collected
    EnumerableSet.AddressSet internal _vaultsList;

    /// @notice Emitted when a vault is added to the list
    event VaultAdded(address indexed vault);

    /// @notice Emitted when a vault is removed from the list
    event VaultRemoved(address indexed vault);

    /// @notice Emitted when a vault asset is not the same as the fee token
    error InvalidVault();

    /// @notice Initializes the OFTFeeCollector contract
    /// @param _admin The address that will be granted the DEFAULT_ADMIN_ROLE
    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @notice Configures the OFTFeeCollector contract
    /// @param _oftAdapter The LayerZero OFT adapter contract address
    /// @param _dstAddress The destination address on the target chain
    /// @param _dstEid The LayerZero endpoint ID of the destination chain
    /// @param _isComposedMsg Whether to use composed message for cross-chain communication
    function configure(address _oftAdapter, address _dstAddress, uint32 _dstEid, bool _isComposedMsg)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_oftAdapter != address(0)) feeToken = IERC20(IOFT(_oftAdapter).token());
        oftAdapter = _oftAdapter;
        dstAddress = _dstAddress;
        dstEid = _dstEid;
        isComposedMsg = _isComposedMsg;
    }

    /// @notice Allows to recover any ERC20 tokens or native currency sent to this contract
    /// @param token The address of the token to recover. If address(0), the native currency is recovered.
    /// @param to The address to send the tokens to
    /// @param amount The amount of tokens to recover
    function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            require(success, "Native currency recovery failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Adds a vault to the list
    /// @param vault The address of the vault to add
    /// @return success True if the vault was successfully added, false if it was already in the list
    function addToVaultsList(address vault) external onlyRole(MAINTAINER_ROLE) returns (bool) {
        if (IEVault(vault).asset() != address(feeToken)) revert InvalidVault();

        bool success = _vaultsList.add(vault);
        if (success) emit VaultAdded(vault);
        return success;
    }

    /// @notice Removes a vault from the list
    /// @param vault The address of the vault to remove
    /// @return success True if the vault was successfully removed, false if it was not in the list
    function removeFromVaultsList(address vault) external onlyRole(MAINTAINER_ROLE) returns (bool) {
        bool success = _vaultsList.remove(vault);
        if (success) emit VaultRemoved(vault);
        return success;
    }

    /// @notice Collects fees from all vaults in the list and sends them cross-chain
    function collectFees() external onlyRole(COLLECTOR_ROLE) {
        address adapter = oftAdapter;
        if (oftAdapter == address(0)) return;

        uint256 length = _vaultsList.length();
        for (uint256 i = 0; i < length; ++i) {
            address vault = _vaultsList.at(i);
            try IEVault(vault).convertFees() {} catch {}
            try IEVault(vault).redeem(type(uint256).max, address(this), address(this)) {} catch {}
        }

        IERC20 token = feeToken;
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) return;

        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(dstAddress))),
            amountLD: balance,
            minAmountLD: balance,
            extraOptions: "",
            composeMsg: isComposedMsg ? abi.encode(0x01) : bytes(""),
            oftCmd: ""
        });
        MessagingFee memory fee = IOFT(adapter).quoteSend(sendParam, false);

        token.forceApprove(adapter, balance);
        IOFT(adapter).send{value: fee.nativeFee}(sendParam, fee, address(this));
    }

    /// @notice Checks if a vault is in the list
    /// @param vault The address of the vault to check
    /// @return True if the vault is in the list, false otherwise
    function isInVaultsList(address vault) external view returns (bool) {
        return _vaultsList.contains(vault);
    }

    /// @notice Returns the complete list of vault addresses
    /// @return An array containing all vault addresses in the list
    function getVaultsList() external view returns (address[] memory) {
        return _vaultsList.values();
    }
}
