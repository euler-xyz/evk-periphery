// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "evk/EVault/IEVault.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

interface IPermit2 {
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        // recipient address
        address to;
        // spender requested amount
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract TransferFromSender is EVCUtil {
    address public immutable permit2;

    error TFS_BadToken();

    constructor(address _permit2, address evc) EVCUtil(evc) {
        permit2 = _permit2;
    }

    function transferFromSenderPermit2(
        address token,
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external onlyEVCAccountOwner {
        address owner = _msgSender();

        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({token: token, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        IPermit2.SignatureTransferDetails memory transferDetails =
            IPermit2.SignatureTransferDetails({to: to, requestedAmount: amount});

        IPermit2(permit2).permitTransferFrom(permit, transferDetails, owner, signature);
    }

    function transferFromSender(address token, address to, uint256 amount) external onlyEVCAccountOwner {
        if (token.code.length == 0) revert TFS_BadToken();

        address from = _msgSender();

        (bool success, bytes memory data) = address(token).call(abi.encodeCall(IERC20.transferFrom, (from, to, amount)));

        if (!isEmptyOrTrueReturn(success, data)) RevertBytes.revertBytes(data);
    }

    function isEmptyOrTrueReturn(bool callSuccess, bytes memory data) private pure returns (bool) {
        return callSuccess && (data.length == 0 || (data.length >= 32 && abi.decode(data, (bool))));
    }
}
