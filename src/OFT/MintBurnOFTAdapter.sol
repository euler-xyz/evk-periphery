// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {OFTCore} from "layerzero/oft-evm/OFTCore.sol";
import {ERC20BurnableMintable} from "../ERC20/deployed/ERC20BurnableMintable.sol";

/// @title MintBurnOFTAdapter
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/) based on
/// https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/MintBurnOFTAdapter.sol
/// @notice A variant of the standard OFT Adapter that uses an existing ERC20's mint and burn mechanisms for cross-chain
/// transfers.
/// @dev Inherits from OFTCore and provides implementations for _debit and _credit functions using a mintable and
/// burnable token.
contract MintBurnOFTAdapter is OFTCore {
    /// @dev The underlying ERC20 token with mint and burn functionality.
    ERC20BurnableMintable internal immutable innerToken;

    /**
     * @notice Initializes the MintBurnOFTAdapter contract.
     *
     * @param _token The address of the underlying ERC20 token.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _delegate The address of the delegate.
     *
     * @dev Calls the OFTCore constructor with the token's decimals, the endpoint, and the delegate.
     */
    constructor(address _token, address _lzEndpoint, address _delegate)
        OFTCore(IERC20Metadata(_token).decimals(), _lzEndpoint, _delegate)
        Ownable(_delegate)
    {
        innerToken = ERC20BurnableMintable(_token);
    }

    /**
     * @notice Retrieves the address of the underlying ERC20 token.
     *
     * @return The address of the adapted ERC20 token.
     *
     * @dev In the case of MintBurnOFTAdapter, address(this) and erc20 are NOT the same contract.
     */
    function token() public view returns (address) {
        return address(innerToken);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the underlying token to send.
     *
     * @return requiresApproval True if approval is required, false otherwise.
     *
     * @dev In this MintBurnOFTAdapter, approval is required because it `burnFrom` function is used.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return true;
    }

    /**
     * @notice Burns tokens from the sender's balance to prepare for sending.
     *
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     *
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     *
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, i.e., 1 token in, 1 token out.
     *      If the 'innerToken' applies something like a transfer fee, the default will NOT work.
     *      A pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        // Burns tokens from the caller.
        innerToken.burnFrom(_from, amountSentLD);
    }

    /**
     * @notice Mints tokens to the specified address upon receiving them.
     *
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     *
     * @return amountReceivedLD The amount of tokens actually received in local decimals.
     *
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, i.e., 1 token in, 1 token out.
     *      If the 'innerToken' applies something like a transfer fee, the default will NOT work.
     *      A pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _credit(address _to, uint256 _amountLD, uint32 /* _srcEid */ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // Mints the tokens and transfers to the recipient.
        innerToken.mint(_to, _amountLD);
        // In the case of NON-default OFTAdapter, the amountLD MIGHT not be equal to amountReceivedLD.
        return _amountLD;
    }
}
