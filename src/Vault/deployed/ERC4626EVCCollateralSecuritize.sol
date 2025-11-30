// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IPerspective} from "../../Perspectives/implementation/interfaces/IPerspective.sol";
import {
    ERC4626EVCCollateralFreezable,
    ERC4626EVCCollateralCapped,
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
    /// @notice Mapping indicating the balance for a specific address prefix.
    mapping(bytes19 addressPrefix => uint256) internal _addressPrefixBalances;

    /// @notice Address of a perspective contract which whitelists controllers allowed to transfer shares in
    /// liquidation.
    address public controllerPerspective;

    /// @notice Emitted after a successful transfer executed via `seize`.
    event GovSeized(address indexed from, address indexed to, uint256 amount);

    /// @notice Event emitted when controller perspective is set
    event GovSetControllerPerspective(address indexed controllerPerspective);

    /// @dev Initializes the contract.
    /// @param evc The EVC address.
    /// @param permit2 The address of the permit2 contract.
    /// @param admin The address of the governor admin.
    /// @param controllerPerspectiveAddress The address of the perspective contract which verifies controllers which are
    /// whitelisted to execute liquidation transfer.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    constructor(
        address evc,
        address permit2,
        address admin,
        address controllerPerspectiveAddress,
        address asset,
        string memory name,
        string memory symbol
    ) ERC4626EVC(evc, permit2, asset, name, symbol) ERC4626EVCCollateralCapped(admin) {
        if (controllerPerspectiveAddress == address(0)) revert InvalidAddress();
        controllerPerspective = controllerPerspectiveAddress;

        emit GovSetControllerPerspective(controllerPerspectiveAddress);
    }

    /// @notice Seizes a certain amount of shares from an address.
    /// @dev Only allows share transfers to a compliant address.
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
        whenNotPaused
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
    /// @dev Only allows share transfers between the accounts of the same owner or to a compliant address when in the
    /// liquidation context.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return result A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        whenNotFrozen(_msgSender())
        whenNotFrozen(to)
        returns (bool result)
    {
        _requireTransferAuthorized(_msgSender(), to, amount);
        result = ERC4626EVCCollateral.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of shares from a sender to a recipient.
    /// @dev Only allows share transfers between the accounts of the same owner or to a compliant address when in the
    /// liquidation context.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return result A boolean indicating whether the transfer was successful.
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        whenNotFrozen(from)
        whenNotFrozen(to)
        returns (bool result)
    {
        _requireTransferAuthorized(from, to, amount);
        result = ERC4626EVCCollateral.transferFrom(from, to, amount);
    }

    /// @notice Deposits a certain amount of assets for a receiver.
    /// @dev Only allows deposits to an account that belongs to the message sender.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    /// @dev If called directly (not through EVC batch), the sender's owner address needs to be registered in EVC
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        whenNotFrozen(receiver)
        takeSnapshot
        returns (uint256 shares)
    {
        if (!isCommonOwner(_msgSender(), receiver)) revert NotAuthorized();
        shares = ERC4626EVCCollateral.deposit(assets, receiver);
        evc.requireVaultStatusCheck();
    }

    /// @notice Mints a certain amount of shares for a receiver.
    /// @dev Only allows deposits to an account that belongs to the message sender.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    /// @dev If called directly (not through EVC batch), the sender's owner address needs to be registered in EVC
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        whenNotFrozen(receiver)
        takeSnapshot
        returns (uint256 assets)
    {
        if (!isCommonOwner(_msgSender(), receiver)) revert NotAuthorized();
        assets = ERC4626EVCCollateral.mint(shares, receiver);
        evc.requireVaultStatusCheck();
    }

    /// @notice Sets a perspective contract to whitelist allowed controllers
    /// @param _controllerPerspective The perspective contract to set.
    /// @dev Only whitelisted controllers are allowed, otherwise users would be able to set a trivial controller
    /// which would be allowed to transfer shares through a liquidation flow.
    function setControllerPerspective(address _controllerPerspective) public onlyEVCAccountOwner governorOnly {
        if (_controllerPerspective == address(0)) revert InvalidAddress();

        controllerPerspective = _controllerPerspective;

        emit GovSetControllerPerspective(_controllerPerspective);
    }

    /// @notice Returns the balance for a specific address prefix.
    /// @param addressPrefix The address prefix (bytes19) whose balance is being queried.
    /// @return The balance associated with the given address prefix.
    function balanceOfAddressPrefix(bytes19 addressPrefix)
        public
        view
        nonReentrantView(bytes4(keccak256("balanceOfAddressPrefix(bytes19)")))
        returns (uint256)
    {
        return _addressPrefixBalances[addressPrefix];
    }

    /// @notice Returns the balance for the EVC account family of a specific account.
    /// @param account The address whose prefix balance is being queried.
    /// @return The balance associated with the address prefix of the account.
    function balanceOfAddressPrefix(address account)
        public
        view
        nonReentrantView(bytes4(keccak256("balanceOfAddressPrefix(address)")))
        returns (uint256)
    {
        if (evc.getAccountOwner(account) != account) revert InvalidAddress();
        return _addressPrefixBalances[_getAddressPrefix(account)];
    }

    /// @notice Checks whether two accounts share the same owner.
    /// @dev Requires the account to have a registered owner on the EVC before the interaction.
    /// @param account First account to compare.
    /// @param otherAccount Second account to compare.
    /// @return True if both accounts share a common owner, false otherwise.
    function isCommonOwner(address account, address otherAccount) public view returns (bool) {
        address owner = evc.getAccountOwner(account);
        return owner != address(0) && _haveCommonOwner(owner, otherAccount);
    }

    /// @notice Performs a compliance check before transferring shares, according to the compliance service.
    /// @dev Requires the account to have a registered owner on the EVC before the interaction. Simulates a transfer
    /// from the vault to the given address owner.
    /// @param to The owner of the address receiving the shares.
    /// @param amount The amount of shares to transfer.
    /// @return True if the transfer is allowed according to compliance, false otherwise.
    function isTransferCompliant(address to, uint256 amount)
        public
        view
        nonReentrantView(this.isTransferCompliant.selector)
        returns (bool)
    {
        address toOwner = evc.getAccountOwner(to);
        if (toOwner == address(0)) return false;

        address complianceService = IDSToken(asset()).getDSService(IDSToken(asset()).COMPLIANCE_SERVICE());

        (uint256 code,) = IComplianceServiceRegulated(complianceService)
            .preTransferCheck(address(this), toOwner, previewRedeem(amount));
        return code == 0;
    }

    function _requireTransferAuthorized(address from, address to, uint256 amount) internal view {
        if (!isCommonOwner(from, to)) {
            // EVC ensures that during `controlCollateral` call there is exactly one controller enabled
            address[] memory controllers = evc.getControllers(from);
            if (!(evc.isControlCollateralInProgress() && IPerspective(controllerPerspective).isVerified(controllers[0])
                        && isTransferCompliant(to, amount))) {
                revert NotAuthorized();
            }
        }
    }

    /// @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or
    /// `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding this
    /// function.
    /// @dev Updates the address prefix balances for easy tracking of the Ultimate Beneficial Owners.
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);

        if (!_haveCommonOwner(from, to)) {
            if (from != address(0)) _addressPrefixBalances[_getAddressPrefix(from)] -= value;
            if (to != address(0)) _addressPrefixBalances[_getAddressPrefix(to)] += value;
        }
    }

    /// @notice Updates the cache with any necessary changes, i.e. interest accrual that may affect the snapshot.
    /// @dev No-op for this contract.
    function _updateCache() internal virtual override {}
}
