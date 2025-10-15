// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {
    ERC4626EVCCompatible, ERC4626EVCCompatibleCollateral
} from "../implementation/ERC4626EVCCompatibleCollateral.sol";

interface IDSToken {
    function COMPLIANCE_SERVICE() external view returns (uint256);
    function getDSService(uint256) external view returns (address);
}

interface IComplianceServiceRegulated {
    function preTransferCheck(address, address, uint256) external view returns (uint256, string memory);
}

/// @title ERC4626EVCCompatibleCollateralSecuritize
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible collateral-only ERC4626 vault implementation for Securitize RWA tokens.
contract ERC4626EVCCompatibleCollateralSecuritize is ERC4626EVCCompatibleCollateral, ReentrancyGuard {
    /// @notice The address of the compliance service.
    address public immutable complianceService;

    /// @notice The address of the governor admin.
    address public governorAdmin;

    /// @notice Mapping indicating the balance for a specific address prefix (EVC account family).
    mapping(bytes19 addressPrefix => uint256) internal _addressPrefixBalances;

    /// @notice Mapping indicating if a particular address prefix (EVC account family) is frozen.
    mapping(bytes19 addressPrefix => bool) internal _freezes;

    /// @notice Emitted when the governor admin is set.
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);

    /// @notice Emitted when an address prefix (EVC account family) is frozen.
    event GovFrozen(bytes19 indexed addressPrefix);

    /// @notice Emitted when an address prefix (EVC account family) is unfrozen.
    event GovUnfrozen(bytes19 indexed addressPrefix);

    /// @notice Emitted after a successful transfer executed via `seize`.
    event GovSeized(address indexed from, address indexed to, uint256 amount);

    /// @notice Error thrown when the address is invalid.
    error InvalidAddress();

    /// @notice Modifier to restrict access to the governor admin.
    modifier governorOnly() {
        if (governorAdmin != _msgSender()) revert NotAuthorized();
        _;
    }

    /// @dev Initializes the contract.
    /// @param evc The EVC address.
    /// @param permit2 The address of the permit2 contract.
    /// @param admin The address of the governor admin.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    constructor(address evc, address permit2, address admin, address asset, string memory name, string memory symbol)
        ERC4626EVCCompatible(evc, permit2, asset, name, symbol)
    {
        governorAdmin = admin;
        complianceService = IDSToken(asset).getDSService(IDSToken(asset).COMPLIANCE_SERVICE());
    }

    function setGovernorAdmin(address newGovernorAdmin) public virtual onlyEVCAccountOwner governorOnly {
        if (newGovernorAdmin == address(0)) revert InvalidAddress();
        if (newGovernorAdmin == governorAdmin) return;
        governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @notice Freezes all accounts sharing an address prefix.
    /// @param account The address whose prefix to freeze.
    function freeze(address account) public virtual onlyEVCAccountOwner governorOnly {
        if (evc.getAccountOwner(account) != account) revert InvalidAddress();
        bytes19 addressPrefix = _getAddressPrefix(account);
        if (_freezes[addressPrefix]) return;
        _freezes[addressPrefix] = true;
        emit GovFrozen(addressPrefix);
    }

    /// @notice Unfreezes all accounts sharing an address prefix.
    /// @param account The address whose prefix to unfreeze.
    function unfreeze(address account) public virtual onlyEVCAccountOwner governorOnly {
        if (evc.getAccountOwner(account) != account) revert InvalidAddress();
        bytes19 addressPrefix = _getAddressPrefix(account);
        if (!_freezes[addressPrefix]) return;
        _freezes[addressPrefix] = false;
        emit GovUnfrozen(addressPrefix);
    }

    /// @notice Seizes a certain amount of shares from an address.
    /// @param from The address to send shares from.
    /// @param to The address to send shares to.
    /// @param amount The amount of shares to transfer.
    /// @return result True if the transfer succeeded, otherwise false.
    function seize(address from, address to, uint256 amount)
        public
        virtual
        callThroughEVC
        nonReentrant
        onlyEVCAccountOwner
        governorOnly
        returns (bool result)
    {
        if (!isTransferCompliant(to, amount)) revert NotAuthorized();
        address spender = _msgSender();
        uint256 previousAllowance = allowance(from, spender);
        _approve(from, spender, amount, false);
        result = super.transferFrom(from, to, amount);
        _approve(from, spender, previousAllowance, false);
        emit GovSeized(from, to, amount);
    }

    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public virtual override callThroughEVC nonReentrant returns (bool) {
        address caller = _msgSender();
        if (isFrozen(caller)) revert NotAuthorized();
        if (!isCommonOwner(caller, to) && !(evc.isControlCollateralInProgress() && isTransferCompliant(to, amount))) {
            revert NotAuthorized();
        }
        return super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of shares from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        returns (bool)
    {
        if (isFrozen(from)) revert NotAuthorized();
        if (!isCommonOwner(from, to) && !(evc.isControlCollateralInProgress() && isTransferCompliant(to, amount))) {
            revert NotAuthorized();
        }
        return super.transferFrom(from, to, amount);
    }

    /// @notice Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        returns (uint256 shares)
    {
        if (!isCommonOwner(_msgSender(), receiver)) revert NotAuthorized();
        return super.deposit(assets, receiver);
    }

    /// @notice Mints a certain amount of shares for a receiver.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        returns (uint256 assets)
    {
        if (!isCommonOwner(_msgSender(), receiver)) revert NotAuthorized();
        return super.mint(shares, receiver);
    }

    /// @notice Withdraws a certain amount of assets for a receiver.
    /// @param assets The assets to withdraw.
    /// @param receiver The receiver of the withdrawal.
    /// @param owner The owner of the assets.
    /// @return shares The shares equivalent to the withdrawn assets.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        returns (uint256 shares)
    {
        if (isFrozen(owner)) revert NotAuthorized();
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems a certain amount of shares for a receiver.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the redemption.
    /// @param owner The owner of the shares.
    /// @return assets The assets equivalent to the redeemed shares.
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        returns (uint256 assets)
    {
        if (isFrozen(owner)) revert NotAuthorized();
        return super.redeem(shares, receiver, owner);
    }

    /// @notice Returns the balance for a specific address prefix.
    /// @param addressPrefix The address prefix (bytes19) whose balance is being queried.
    /// @return The balance associated with the given address prefix.
    function balanceOfAddressPrefix(bytes19 addressPrefix) public view virtual returns (uint256) {
        return _addressPrefixBalances[addressPrefix];
    }

    /// @notice Returns the balance for the EVC account family of a specific account.
    /// @param account The address whose prefix balance is being queried.
    /// @return The balance associated with the address prefix of the account.
    function balanceOfAddressPrefix(address account) public view virtual returns (uint256) {
        if (evc.getAccountOwner(account) != account) revert InvalidAddress();
        return _addressPrefixBalances[_getAddressPrefix(account)];
    }

    /// @notice Checks whether a given account is frozen based on its address prefix.
    /// @param account The account to check.
    /// @return True if the account is frozen, false otherwise.
    function isFrozen(address account) public view returns (bool) {
        bytes19 addressPrefix = _getAddressPrefix(account);
        return _freezes[addressPrefix];
    }

    /// @notice Performs a compliance check before transferring shares, according to the compliance service.
    /// @dev Simulates a transfer from the vault to the given address owner.
    /// @param to The owner of the address receiving the shares.
    /// @param amount The amount of shares to transfer.
    /// @return True if the transfer is allowed according to compliance, false otherwise.
    function isTransferCompliant(address to, uint256 amount) public view returns (bool) {
        address toOwner = evc.getAccountOwner(to);
        if (toOwner == address(0)) return false;

        (uint256 code,) =
            IComplianceServiceRegulated(complianceService).preTransferCheck(address(this), toOwner, amount);
        return code == 0;
    }

    /// @notice Checks whether two accounts share the same owner.
    /// @param account First account to compare.
    /// @param otherAccount Second account to compare.
    /// @return True if both accounts share a common owner, false otherwise.
    function isCommonOwner(address account, address otherAccount) public view returns (bool) {
        address owner = evc.getAccountOwner(account);
        return owner != address(0) && _haveCommonOwner(owner, otherAccount);
    }

    /// @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or
    /// `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding this
    /// function.
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);

        if (!_haveCommonOwner(from, to)) {
            if (from != address(0)) _addressPrefixBalances[_getAddressPrefix(from)] -= value;
            if (to != address(0)) _addressPrefixBalances[_getAddressPrefix(to)] += value;
        }
    }
}
