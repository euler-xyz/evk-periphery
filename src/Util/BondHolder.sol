// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title BondHolder
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Contract that allows users to provide vault shares and become junior tranche holders.
/// Users can earn additional vault shares through fee distribution mechanisms that send vault shares
/// directly to this contract, increasing the exchange rate between what users bonded and what they can unbond.
contract BondHolder is EVCUtil {
    using Math for uint256;

    /// @notice The delay period before users can complete unbonding after initiating it.
    uint256 public constant UNBOND_DELAY = 30 days;

    /// @dev The virtual amount added to total bond shares and vault share balance to prevent manipulation
    /// and division by zero, following EVK-style accounting.
    uint256 internal constant VIRTUAL_AMOUNT = 1e6;

    /// @dev Mapping from vault address to account address to bond shares amount.
    mapping(address vault => mapping(address account => uint256 amount)) private _bondShares;

    /// @dev Mapping from vault address to total bond shares issued.
    mapping(address vault => uint256 amount) private _totalBondShares;

    /// @dev Mapping from vault address to account address to unbond unlock timestamp.
    mapping(address vault => mapping(address account => uint256 timestamp)) private _unbondTimestamp;

    /// @dev Mapping from vault address to account address to locked vault shares amount for unbonding.
    mapping(address vault => mapping(address account => uint256 amount)) private _unbondAssets;

    /// @notice Error thrown when attempting to bond or initiate unbond while an unbond is already in progress.
    error UnbondInProgress();

    /// @notice Error thrown when attempting to cancel an unbond that was not initiated.
    error UnbondNotInitiated();

    /// @notice Error thrown when attempting to unbond before the delay period has passed or when unbond was not
    /// initiated.
    error UnbondNotReady();

    /// @notice Error thrown when attempting to bond or initiate unbond with zero shares.
    error ZeroShares();

    /// @notice Emitted when a user initiates an unbond.
    /// @param vault The vault address.
    /// @param account The account initiating the unbond.
    /// @param bondShares The amount of bond shares being unbonded.
    /// @param vaultShares The amount of vault shares locked for unbonding.
    /// @param unlockTimestamp The timestamp when the unbond can be completed.
    event InitiateUnbond(
        address indexed vault, address indexed account, uint256 bondShares, uint256 vaultShares, uint256 unlockTimestamp
    );

    /// @notice Emitted when a user cancels an unbond in progress.
    /// @param vault The vault address.
    /// @param account The account canceling the unbond.
    /// @param bondShares The amount of bond shares restored.
    /// @param vaultShares The amount of vault shares that were locked.
    event CancelUnbond(address indexed vault, address indexed account, uint256 bondShares, uint256 vaultShares);

    /// @notice Emitted when a user bonds vault shares.
    /// @param vault The vault address.
    /// @param account The account bonding shares.
    /// @param vaultShares The amount of vault shares bonded.
    /// @param bondShares The amount of bond shares received.
    event Bond(address indexed vault, address indexed account, uint256 vaultShares, uint256 bondShares);

    /// @notice Emitted when a user completes an unbond.
    /// @param vault The vault address.
    /// @param account The account completing the unbond.
    /// @param receiver The address receiving the vault shares.
    /// @param vaultShares The amount of vault shares withdrawn.
    event Unbond(address indexed vault, address indexed account, address indexed receiver, uint256 vaultShares);

    /// @dev Initializes the contract.
    /// @param evc The EVC address.
    constructor(address evc) EVCUtil(evc) {}

    /// @notice Returns the bond shares amount for a given vault and account.
    /// @param vault The vault address.
    /// @param account The account address.
    /// @return The amount of bond shares held by the account.
    function bondSharesOf(address vault, address account) public view returns (uint256) {
        return _bondShares[vault][account];
    }

    /// @notice Returns the total bond shares issued for a given vault.
    /// @param vault The vault address.
    /// @return The total amount of bond shares issued.
    function totalBond(address vault) public view returns (uint256) {
        return _totalBondShares[vault];
    }

    /// @notice Returns the unlock timestamp for an account's unbond in a given vault.
    /// @param vault The vault address.
    /// @param account The account address.
    /// @return The timestamp when the unbond can be completed, or 0 if no unbond is in progress.
    function unbondTimestamp(address vault, address account) public view returns (uint256) {
        return _unbondTimestamp[vault][account];
    }

    /// @notice Returns the amount of vault shares locked for unbonding for a given vault and account.
    /// @param vault The vault address.
    /// @param account The account address.
    /// @return The amount of vault shares locked for unbonding, or 0 if no unbond is in progress.
    function unbondAssets(address vault, address account) public view returns (uint256) {
        return _unbondAssets[vault][account];
    }

    /// @notice Checks if an account can complete their unbond for a given vault.
    /// @param vault The vault address.
    /// @param account The account address.
    /// @return True if the unbond delay has passed and the account can complete the unbond.
    function canUnbond(address vault, address account) public view returns (bool) {
        uint256 timestamp = _unbondTimestamp[vault][account];
        return timestamp != 0 && timestamp <= block.timestamp;
    }

    /// @notice Returns the total assets that would be covered by the bond shares if converted using the vault's
    /// exchange rate.
    /// @param vault The vault address.
    /// @return The total assets value, or 0 if the conversion fails.
    function totalAssetsCover(address vault) public view returns (uint256) {
        try IERC4626(vault).convertToAssets(_totalBondShares[vault]) returns (uint256 assets) {
            return assets;
        } catch {
            return 0;
        }
    }

    /// @notice Initiates the unbonding process for the caller's bond shares in a given vault.
    /// @dev The bond shares are immediately removed from the total, and the vault shares are locked
    /// until the unbond delay period passes. The exchange rate is calculated at initiation time,
    /// so users won't benefit from fees that arrive during the delay period.
    /// @param vault The vault address to unbond from.
    function initiateUnbond(address vault) public {
        address account = _msgSender();
        if (_unbondTimestamp[vault][account] != 0) revert UnbondInProgress();

        uint256 shares = _bondShares[vault][account];
        if (shares == 0) revert ZeroShares();

        uint256 unlockTimestamp = block.timestamp + UNBOND_DELAY;
        uint256 assets = _convertToAssets(vault, shares, Math.Rounding.Floor);

        _unbondTimestamp[vault][account] = unlockTimestamp;
        _unbondAssets[vault][account] = assets;
        _bondShares[vault][account] = 0;
        _totalBondShares[vault] -= shares;

        emit InitiateUnbond(vault, account, shares, assets, unlockTimestamp);
    }

    /// @notice Cancels an unbonding process in progress, restoring bond shares to the account.
    /// @dev The locked vault shares are converted back to bond shares at the current exchange rate.
    /// This means the user may receive slightly different bond shares than originally locked,
    /// depending on whether fees were distributed during the unbond period.
    /// @param vault The vault address to cancel the unbond for.
    function cancelUnbond(address vault) public {
        address account = _msgSender();
        if (_unbondTimestamp[vault][account] == 0) revert UnbondNotInitiated();

        uint256 assets = _unbondAssets[vault][account];
        uint256 shares = _convertToShares(vault, assets, Math.Rounding.Floor);
        if (shares == 0) revert ZeroShares();

        _unbondTimestamp[vault][account] = 0;
        _unbondAssets[vault][account] = 0;
        _bondShares[vault][account] += shares;
        _totalBondShares[vault] += shares;

        emit CancelUnbond(vault, account, shares, assets);
    }

    /// @notice Bonds vault shares for the caller, converting them to bond shares at the current exchange rate.
    /// @dev The exchange rate improves as fees are distributed to this contract, increasing the value
    /// of bond shares over time. Users cannot bond while an unbond is in progress.
    /// @param vault The vault address to bond shares from.
    /// @param amount The amount of vault shares to bond.
    function bond(address vault, uint256 amount) public {
        address account = _msgSender();
        if (_unbondTimestamp[vault][account] != 0) revert UnbondInProgress();

        uint256 shares = _convertToShares(vault, amount, Math.Rounding.Floor);
        if (shares == 0) revert ZeroShares();

        SafeERC20.safeTransferFrom(IERC20(vault), account, address(this), amount);
        _bondShares[vault][account] += shares;
        _totalBondShares[vault] += shares;

        emit Bond(vault, account, amount, shares);
    }

    /// @notice Completes the unbonding process, transferring the locked vault shares to the receiver.
    /// @dev Can only be called after the unbond delay period has passed since initiation.
    /// @param vault The vault address to unbond from.
    /// @param receiver The address to receive the vault shares.
    function unbond(address vault, address receiver) public {
        address account = _msgSender();
        uint256 timestamp = _unbondTimestamp[vault][account];
        if (timestamp == 0 || timestamp > block.timestamp) revert UnbondNotReady();

        uint256 assets = _unbondAssets[vault][account];
        _unbondTimestamp[vault][account] = 0;
        _unbondAssets[vault][account] = 0;

        SafeERC20.safeTransfer(IERC20(vault), receiver, assets);

        emit Unbond(vault, account, receiver, assets);
    }

    /// @dev Converts vault shares to bond shares using the current exchange rate.
    /// @param vault The vault address.
    /// @param assets The amount of vault shares to convert.
    /// @param rounding The rounding direction to use.
    /// @return The amount of bond shares equivalent to the vault shares.
    function _convertToShares(address vault, uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(
            _totalBondShares[vault] + VIRTUAL_AMOUNT, IERC20(vault).balanceOf(address(this)) + VIRTUAL_AMOUNT, rounding
        );
    }

    /// @dev Converts bond shares to vault shares using the current exchange rate.
    /// @param vault The vault address.
    /// @param shares The amount of bond shares to convert.
    /// @param rounding The rounding direction to use.
    /// @return The amount of vault shares equivalent to the bond shares.
    function _convertToAssets(address vault, uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(
            IERC20(vault).balanceOf(address(this)) + VIRTUAL_AMOUNT, _totalBondShares[vault] + VIRTUAL_AMOUNT, rounding
        );
    }
}
