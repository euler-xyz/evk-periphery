// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";

interface IIdleCDO {
    function token() external view returns (address);
    function AATranche() external view returns (address);
    function depositAA(uint256 _amount) external returns (uint256);
    function withdrawAA(uint256 _amount) external returns (uint256);
}

/// @title SwapHandler
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Swap handler depositing/withdrawing from Idle's AA Tranche and transferring the proceeds to the appropriate
/// Euler EVK vault.
contract SwapHandler {
    using SafeERC20 for IERC20;

    address public immutable vaultToken;
    address public immutable vaultAATranche;
    address public immutable idleCDO;
    address public immutable token;
    address public immutable AATranche;

    constructor(address _vaultToken, address _vaultAATranche, address _idleCDO) {
        vaultToken = _vaultToken;
        vaultAATranche = _vaultAATranche;
        idleCDO = _idleCDO;
        token = IIdleCDO(idleCDO).token();
        AATranche = IIdleCDO(idleCDO).AATranche();

        require(
            IERC4626(vaultToken).asset() == token && IERC4626(vaultAATranche).asset() == AATranche,
            "Vault assets mismatch"
        );
    }

    function swapExactTokensForAATranche(uint256 amountIn) external {
        if (amountIn == type(uint256).max) {
            amountIn = IERC20(token).balanceOf(msg.sender);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).forceApprove(idleCDO, type(uint256).max);
        IERC20(AATranche).transfer(vaultAATranche, IIdleCDO(idleCDO).depositAA(amountIn));
    }

    function swapExactAATrancheForTokens(uint256 amountIn) external {
        if (amountIn == type(uint256).max) {
            amountIn = IERC20(AATranche).balanceOf(msg.sender);
        }

        IERC20(AATranche).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).transfer(vaultToken, IIdleCDO(idleCDO).withdrawAA(amountIn));
    }
}
