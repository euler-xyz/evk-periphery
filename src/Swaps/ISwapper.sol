// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

/// @title ISwapper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Interface of a helper contracts, which handle swapping of tokens for the EVK
interface ISwapper {
    /// @title SwapParams
    /// @notice This struct holds all the parameters needed to carry out a swap
    struct SwapParams {
        // An id of the swap handler to use
        bytes32 handler;
        // Swap mode to execute
        // 0 - exact input swap
        // 1 - exect output swap
        // 2 - exact output swap and repay, targeting a debt amount of an account
        uint256 mode;
        // An EVC compatible account address
        address account;
        // Sold asset
        address tokenIn;
        // Bought asset
        address tokenOut;
        // Vault to which the unused input in exact output swap will be deposited back
        address vaultIn;
        // In swapping modes (0 and 1) - address of the intended recipient of the bought tokens
        // In swap and repay mode (2) - address of the liability vault of the account, where to repay debt
        // Note that if the swap uses off-chain encoded payload, the receiver might be ignored. The swapper
        // should verify the assets are in fact in the receiver address after the swap
        address receiver; // in TARGET_DEBT liability vault
        // In exact input mode (0) - ignored
        // In exact output mode (1) - amount of `tokenOut` to buy
        // In swap and repay mode (2) - amount of debt the account should have after swap and repay
        uint256 amountOut;
        // Timestamp after which the swap must revert
        uint256 deadline;
        // Auxilary payload for swap providers
        bytes data;
    }

    /// @notice Execute a swap according to the SwapParams configuraion
    /// @param params Configuration of the swap
    function swap(SwapParams calldata params) external;

    /// @notice Use the contract's token balance to repay debt of the account in a lending vault
    /// @param token The asset that is borrowed
    /// @param vault The lending vault where the debt is tracked
    /// @param repayAmount Amount of debt to repay
    /// @param account Receiver of the repay
    function repay(address token, address vault, uint256 repayAmount, address account) external;

    /// @notice Use the contract's token balance to repay debt of the account in a lending vault
    /// and deposit any remaining balance for the account in that same vault
    /// @param token The asset that is borrowed
    /// @param vault The lending vault where the debt is tracked
    /// @param repayAmount Amount of debt to repay
    /// @param account Receiver of the repay
    function repayAndDeposit(address token, address vault, uint256 repayAmount, address account) external;

    /// @notice Use all of the contract's token balance to execute a deposit for an account
    /// @param token Asset to deposit
    /// @param vault Vault to deposit the token to
    /// @param amountMin A minimum amount of tokens to deposit. If unavailable, the operation is a no-op
    /// @param account Receiver of the repay
    /// @dev Use amountMin to ignore dust
    function deposit(address token, address vault, uint256 amountMin, address account) external;

    /// @notice Transfer all tokens held by the contract
    /// @param token Token to transfer
    /// @param amountMin Minimum amount of tokens to transfer. If unavailable, the operation is a no-op
    /// @param to Address to send the tokens to
    function sweep(address token, uint256 amountMin, address to) external;

    /// @notice Call multiple functions of the contract
    /// @param calls Array of encoded payloads
    /// @dev Calls itself with regular external calls
    function multicall(bytes[] memory calls) external;
}
