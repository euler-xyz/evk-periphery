// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {
    ERC4626EVCCollateralFreezable,
    ERC4626EVCCollateral,
    ERC4626EVC
} from "../implementation/ERC4626EVCCollateralFreezable.sol";

interface IDSToken {
    function COMPLIANCE_SERVICE() external view returns (uint256);
    function getDSService(uint256) external view returns (address);
}

interface IComplianceServiceRegulated {
    function preTransferCheck(address, address, uint256) external view returns (uint256, string memory);
}

/// @title ERC4626EVCCollateralSecuritize
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible collateral-only ERC4626 vault implementation for Securitize RWA tokens.
contract ERC4626EVCCollateralSecuritize is ERC4626EVCCollateralFreezable {
    /// @notice The address of the compliance service.
    address public immutable complianceService;

    /// @notice Mapping indicating the balance for a specific address prefix.
    mapping(bytes19 addressPrefix => uint256) internal _addressPrefixBalances;

    /// @notice Emitted after a successful transfer executed via `seize`.
    event GovSeized(address indexed from, address indexed to, uint256 amount);

    /// @dev Initializes the contract.
    /// @param evc The EVC address.
    /// @param permit2 The address of the permit2 contract.
    /// @param admin The address of the governor admin.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    constructor(address evc, address permit2, address admin, address asset, string memory name, string memory symbol)
        ERC4626EVC(evc, permit2, asset, name, symbol)
        ERC4626EVCCollateralFreezable(admin)
    {
        complianceService = IDSToken(asset).getDSService(IDSToken(asset).COMPLIANCE_SERVICE());
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
        whenNotFrozen(to)
        returns (bool result)
    {
        if (!isTransferCompliant(to, amount)) revert NotAuthorized();
        address spender = _msgSender();
        uint256 previousAllowance = allowance(from, spender);
        _approve(from, spender, amount, false);
        result = ERC4626EVCCollateral.transferFrom(from, to, amount);
        _approve(from, spender, previousAllowance, false);
        emit GovSeized(from, to, amount);
    }

    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        whenNotFrozen(_msgSender())
        whenNotFrozen(to)
        returns (bool)
    {
        if (
            !isCommonOwner(_msgSender(), to)
                && !(evc.isControlCollateralInProgress() && isTransferCompliant(to, amount))
        ) {
            revert NotAuthorized();
        }
        return ERC4626EVCCollateral.transfer(to, amount);
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
        whenNotPaused
        whenNotFrozen(from)
        whenNotFrozen(to)
        returns (bool)
    {
        if (!isCommonOwner(from, to) && !(evc.isControlCollateralInProgress() && isTransferCompliant(to, amount))) {
            revert NotAuthorized();
        }
        return ERC4626EVCCollateral.transferFrom(from, to, amount);
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
        whenNotPaused
        whenNotFrozen(receiver)
        returns (uint256 shares)
    {
        if (!isCommonOwner(_msgSender(), receiver)) revert NotAuthorized();
        return ERC4626EVCCollateral.deposit(assets, receiver);
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
        whenNotPaused
        whenNotFrozen(receiver)
        returns (uint256 assets)
    {
        if (!isCommonOwner(_msgSender(), receiver)) revert NotAuthorized();
        return ERC4626EVCCollateral.mint(shares, receiver);
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

    /// @notice Checks whether two accounts share the same owner.
    /// @param account First account to compare.
    /// @param otherAccount Second account to compare.
    /// @return True if both accounts share a common owner, false otherwise.
    function isCommonOwner(address account, address otherAccount) public view virtual returns (bool) {
        address owner = evc.getAccountOwner(account);
        return owner != address(0) && _haveCommonOwner(owner, otherAccount);
    }

    /// @notice Performs a compliance check before transferring shares, according to the compliance service.
    /// @dev Simulates a transfer from the vault to the given address owner.
    /// @param to The owner of the address receiving the shares.
    /// @param amount The amount of shares to transfer.
    /// @return True if the transfer is allowed according to compliance, false otherwise.
    function isTransferCompliant(address to, uint256 amount) public view virtual returns (bool) {
        address toOwner = evc.getAccountOwner(to);
        if (toOwner == address(0)) return false;

        (uint256 code,) = IComplianceServiceRegulated(complianceService).preTransferCheck(
            address(this), toOwner, previewRedeem(amount)
        );
        return code == 0;
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
