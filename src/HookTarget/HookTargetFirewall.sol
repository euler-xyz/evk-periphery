// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {Set, SetStorage} from "ethereum-vault-connector/Set.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {AmountCap} from "evk/EVault/shared/types/AmountCap.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @notice An interface for the SecurityValidator singleton contract.
interface ISecurityValidator {
    struct Attestation {
        uint256 deadline;
        bytes32[] executionHashes;
    }

    function getCurrentAttester() external view returns (address);
    function executeCheckpoint(bytes32 checkpointHash) external returns (bytes32);
    function hashAttestation(Attestation calldata attestation) external view returns (bytes32);
    function executionHashFrom(bytes32 checkpointHash, address caller, bytes32 executionHash)
        external
        view
        returns (bytes32);
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function storeAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function validateFinalState() external view;
}

/// @title HookTargetFirewall
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A hook target that integrates with the SecurityValidator contract.
contract HookTargetFirewall is IHookTarget, EVCUtil {
    using Set for SetStorage;

    /// @notice Struct to store policy information for a vault.
    struct PolicyStorage {
        /// @notice Whether the vault is authenticated.
        bool isAuthenticated;
        /// @notice The max operations counter threshold per 3 minutes that can be executed without attestation.
        uint32 operationCounterThreshold;
        /// @notice The normalized timestamp of the last update, rounded down to the nearest one minute interval.
        uint48 updateTimestampNormalized;
        /// @notice Packed operation counters for the last three one minute intervals. The least significant 32 bits
        /// represent the current one minute window.
        /// @dev Structured as [32 bits window][32 bits window][32 bits window].
        uint96 operationCountersPacked;
        /// @notice The constant amount threshold for incoming transfers.
        AmountCap inConstantAmountThreshold;
        /// @notice The accumulated amount threshold for incoming transfers.
        AmountCap inAccumulatedAmountThreshold;
        /// @notice The constant amount threshold for outgoing transfers.
        AmountCap outConstantAmountThreshold;
        /// @notice The accumulated amount threshold for outgoing transfers.
        AmountCap outAccumulatedAmountThreshold;
    }

    /// @notice Enum representing the type of transfer.
    enum TransferType {
        /// @notice Represents an incoming transfer.
        In,
        /// @notice Represents an outgoing transfer.
        Out
    }

    /// @custom:storage-location erc7201:euler.storage.HookTargetFirewall
    struct HookTargetFirewallStorage {
        /// @notice Mapping of vault addresses to their set of accepted attesters.
        mapping(address vault => SetStorage) attesters;
        /// @notice Mapping of vault addresses to their policy storage.
        mapping(address vault => PolicyStorage) policies;
        /// @notice Mapping of address prefixes to their operation counter.
        mapping(bytes19 addressPrefix => uint256) operationCounters;
    }

    // keccak256(abi.encode(uint256(keccak256("euler.storage.HookTargetFirewall")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant HookTargetFirewallStorageLocation =
        0xd3e74b2efd7e77af7296587b6de98af243f03ea83f111b434fed08f9d95e5500;

    /// @notice The number of bits used to represent each window in the packed operation counters.
    uint256 internal constant WINDOW_BITS = 32;

    /// @notice The duration of a single time window for operation counting.
    uint256 internal constant WINDOW_PERIOD = 60;

    /// @notice The EVault factory contract.
    GenericFactory internal immutable eVaultFactory;

    /// @notice The security validator contract.
    ISecurityValidator internal immutable validator;

    /// @notice The immutable ID of the attester controller
    bytes32 internal immutable controllerId;

    /// @notice Emitted when the attester controller ID is updated
    /// @param attesterControllerId The new attester controller ID
    event AttesterControllerUpdated(bytes32 attesterControllerId);

    /// @notice Emitted when the vault is authenticated.
    /// @param vault The address of the vault.
    event AuthenticateVault(address indexed vault);

    /// @notice Emitted when accepted attesters are inserted for a vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester.
    event AddPolicyAttester(address indexed vault, address attester);

    /// @notice Emitted when an accepted attester is removed for a vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester.
    event RemovePolicyAttester(address indexed vault, address attester);

    /// @notice Emitted when a policy thresholds are set for a vault.
    /// @param vault The address of the vault.
    /// @param operationCounterThreshold The max operations counter threshold per 3 minutes that can be executed
    /// without attestation.
    /// @param inConstantAmountThreshold The constant amount threshold for incoming transfers.
    /// @param inAccumulatedAmountThreshold The accumulated amount threshold for incoming transfers.
    /// @param outConstantAmountThreshold The constant amount threshold for outgoing transfers.
    /// @param outAccumulatedAmountThreshold The accumulated amount threshold for outgoing transfers.
    event SetPolicyThresholds(
        address indexed vault,
        uint32 operationCounterThreshold,
        uint16 inConstantAmountThreshold,
        uint16 inAccumulatedAmountThreshold,
        uint16 outConstantAmountThreshold,
        uint16 outAccumulatedAmountThreshold
    );

    /// @notice Error thrown when the caller is not authorized to perform an operation.
    error HTA_Unauthorized();

    /// @notice Constructor to initialize the contract with the EVC and validator addresses.
    /// @param _evc The address of the EVC contract.
    /// @param _eVaultFactory The address of the EVault factory contract.
    /// @param _securityValidator The address of the security validator contract.
    constructor(address _evc, address _eVaultFactory, address _securityValidator, bytes32 _controllerId)
        EVCUtil(_evc)
    {
        eVaultFactory = GenericFactory(_eVaultFactory);
        validator = ISecurityValidator(_securityValidator);
        controllerId = _controllerId;
        emit AttesterControllerUpdated(_controllerId);
    }

    /// @notice Fallback function to handle unexpected calls.
    fallback() external {}

    /// @notice Modifier to restrict access to only the governor of the specified vault.
    /// @param vault The address of the vault.
    modifier onlyGovernor(address vault) {
        if (_msgSender() != IEVault(vault).governorAdmin()) revert HTA_Unauthorized();
        _;
    }

    /// @inheritdoc IHookTarget
    /// @dev This function returns the expected magic value only if the caller is a proxy deployed by the recognized
    /// EVault factory.
    function isHookTarget() external view override returns (bytes4) {
        if (eVaultFactory.isProxy(msg.sender)) {
            return this.isHookTarget.selector;
        }
        return 0;
    }

    /// @notice Retrieves the address of the EVault factory contract
    /// @return The address of the EVault factory contract
    function getEVaultFactory() external view returns (address) {
        return address(eVaultFactory);
    }

    /// @notice Retrieves the address of the security validator contract
    /// @return The address of the security validator contract
    function getSecurityValidator() external view returns (address) {
        return address(validator);
    }

    /// @notice Retrieves the attester controller ID
    /// @return The bytes32 representation of the attester controller ID
    function getAttesterControllerId() external view returns (bytes32) {
        return controllerId;
    }

    /// @notice Adds an accepted attester to the policy for a given vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester to be added.
    function addPolicyAttester(address vault, address attester) external onlyEVCAccountOwner onlyGovernor(vault) {
        if (getHookTargetFirewallStorage().attesters[vault].insert(attester)) {
            emit AddPolicyAttester(vault, attester);
        }
    }

    /// @notice Removes an accepted attester from the policy for a given vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester to be removed.
    function removePolicyAttester(address vault, address attester) external onlyEVCAccountOwner onlyGovernor(vault) {
        if (getHookTargetFirewallStorage().attesters[vault].remove(attester)) {
            emit RemovePolicyAttester(vault, attester);
        }
    }

    /// @notice Retrieves the list of accepted attesters for a given vault.
    /// @param vault The address of the vault.
    /// @return An array of addresses representing the accepted attesters for the specified vault.
    function getPolicyAttesters(address vault) external view returns (address[] memory) {
        return getHookTargetFirewallStorage().attesters[vault].get();
    }

    /// @notice Sets the policy thresholds for a given vault.
    /// @param vault The address of the vault.
    /// @param operationCounterThreshold The max operations counter threshold per 3 minutes that can be executed
    /// without attestation.
    /// @param inConstantAmountThreshold The constant amount threshold for incoming transfers.
    /// @param inAccumulatedAmountThreshold The accumulated amount threshold for incoming transfers.
    /// @param outConstantAmountThreshold The constant amount threshold for outgoing transfers.
    /// @param outAccumulatedAmountThreshold The accumulated amount threshold for outgoing transfers.
    function setPolicyThresholds(
        address vault,
        uint32 operationCounterThreshold,
        uint16 inConstantAmountThreshold,
        uint16 inAccumulatedAmountThreshold,
        uint16 outConstantAmountThreshold,
        uint16 outAccumulatedAmountThreshold
    ) external onlyEVCAccountOwner onlyGovernor(vault) {
        PolicyStorage storage policyStorage = getHookTargetFirewallStorage().policies[vault];
        policyStorage.operationCounterThreshold = operationCounterThreshold;
        policyStorage.inConstantAmountThreshold = AmountCap.wrap(inConstantAmountThreshold);
        policyStorage.inAccumulatedAmountThreshold = AmountCap.wrap(inAccumulatedAmountThreshold);
        policyStorage.outConstantAmountThreshold = AmountCap.wrap(outConstantAmountThreshold);
        policyStorage.outAccumulatedAmountThreshold = AmountCap.wrap(outAccumulatedAmountThreshold);

        emit SetPolicyThresholds(
            vault,
            operationCounterThreshold,
            inConstantAmountThreshold,
            inAccumulatedAmountThreshold,
            outConstantAmountThreshold,
            outAccumulatedAmountThreshold
        );
    }

    /// @notice Retrieves the policy thresholds for a given vault.
    /// @param vault The address of the vault.
    /// @return operationCounterThreshold The max operations counter threshold per 3 minutes that can be executed
    /// without attestation.
    /// @return inConstantAmountThreshold The constant amount threshold for incoming transfers.
    /// @return inAccumulatedAmountThreshold The accumulated amount threshold for incoming transfers.
    /// @return outConstantAmountThreshold The constant amount threshold for outgoing transfers.
    /// @return outAccumulatedAmountThreshold The accumulated amount threshold for outgoing transfers.
    function getPolicyThresholds(address vault) external view returns (uint32, uint16, uint16, uint16, uint16) {
        PolicyStorage storage policyStorage = getHookTargetFirewallStorage().policies[vault];
        return (
            policyStorage.operationCounterThreshold,
            AmountCap.unwrap(policyStorage.inConstantAmountThreshold),
            AmountCap.unwrap(policyStorage.inAccumulatedAmountThreshold),
            AmountCap.unwrap(policyStorage.outConstantAmountThreshold),
            AmountCap.unwrap(policyStorage.outAccumulatedAmountThreshold)
        );
    }

    /// @notice Retrieves the resolved policy thresholds for a given vault.
    /// @param vault The address of the vault.
    /// @return operationCounterThreshold The max operations counter threshold per 3 minutes that can be executed
    /// without attestation.
    /// @return inConstantAmountThreshold The constant amount threshold for incoming transfers.
    /// @return inAccumulatedAmountThreshold The accumulated amount threshold for incoming transfers.
    /// @return outConstantAmountThreshold The constant amount threshold for outgoing transfers.
    /// @return outAccumulatedAmountThreshold The accumulated amount threshold for outgoing transfers.
    function getPolicyThresholdsResolved(address vault)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        PolicyStorage storage policyStorage = getHookTargetFirewallStorage().policies[vault];
        return (
            policyStorage.operationCounterThreshold,
            policyStorage.inConstantAmountThreshold.resolve(),
            policyStorage.inAccumulatedAmountThreshold.resolve(),
            policyStorage.outConstantAmountThreshold.resolve(),
            policyStorage.outAccumulatedAmountThreshold.resolve()
        );
    }

    /// @notice Retrieves the current operation counter for a given vault over the last 3 minutes.
    /// @dev This operation counter only counts operations that have been executed without attestation.
    /// @param vault The address of the vault
    /// @return The current operation counter for the vault
    function getOperationCounter(address vault) external view returns (uint256) {
        return updateVaultOperationCounter(getHookTargetFirewallStorage().policies[vault]) - 1;
    }

    /// @notice Saves an attestation.
    /// @param attestation The attestation data.
    /// @param attestationSignature The signature of the attestation.
    function saveAttestation(ISecurityValidator.Attestation calldata attestation, bytes calldata attestationSignature)
        external
    {
        validator.saveAttestation(attestation, attestationSignature);
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function deposit(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) {
            amount = IEVault(IEVault(msg.sender).asset()).balanceOf(caller());
        }
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function mint(uint256 amount, address receiver) external returns (uint256) {
        amount = IEVault(msg.sender).convertToAssets(amount);
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function skim(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) {
            uint256 balance = IEVault(IEVault(msg.sender).asset()).balanceOf(msg.sender);
            uint256 cash = IEVault(msg.sender).cash();
            amount = balance > cash ? balance - cash : 0;
        }
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256) {
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver, owner));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function redeem(uint256 amount, address receiver, address owner) external returns (uint256) {
        if (amount == type(uint256).max) {
            amount = IEVault(msg.sender).convertToAssets(IEVault(msg.sender).balanceOf(owner));
        }
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver, owner));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function borrow(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) amount = IEVault(msg.sender).cash();
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function repay(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) amount = IEVault(msg.sender).debtOf(receiver);
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function checkVaultStatus() external view returns (bytes4) {
        validator.validateFinalState();
        return 0;
    }

    /// @notice Retrieves the storage struct for HookTargetFirewall
    /// @return $ The HookTargetFirewallStorage struct storage slot
    function getHookTargetFirewallStorage() internal pure returns (HookTargetFirewallStorage storage $) {
        assembly {
            $.slot := HookTargetFirewallStorageLocation
        }
    }

    /// @notice Executes a checkpoint for a given transfer type and reference amount.
    /// @param transferType The type of transfer (In or Out).
    /// @param referenceAmount The reference amount for the transfer.
    /// @param hashable Additional data to be hashed.
    function executeCheckpoint(TransferType transferType, uint256 referenceAmount, bytes memory hashable) internal {
        PolicyStorage memory policy = getHookTargetFirewallStorage().policies[msg.sender];
        if (!policy.isAuthenticated) {
            authenticateVault(msg.sender);
        }

        address sender = caller();
        uint256 accountOperationCounter = updateAccountOperationCounter(sender);
        uint256 vaultOperationCounter = updateVaultOperationCounter(policy);
        uint256 accumulatedAmount = updateAccumulatedAmount(transferType, msg.sender, referenceAmount);
        (uint256 operationCounterThreshold, uint256 constantAmountThreshold, uint256 accumulatedAmountThreshold) =
            resolveThresholds(transferType, policy);

        if (
            vaultOperationCounter >= operationCounterThreshold || referenceAmount >= constantAmountThreshold
                || accumulatedAmount >= accumulatedAmountThreshold
        ) {
            if (!evc.isSimulationInProgress()) {
                // to prevent replay attacks, the hash must depend on:
                // - the vault address that is a caller of the hook target
                // - the operation type executed (function selector)
                // - the quantized reference amount that allows for runtime changes within an acceptable range
                // - the static parameters of the operation
                // - the authenticated account that executes the operation
                // - the operation counter associated with the authenticated account
                validator.executeCheckpoint(
                    keccak256(
                        abi.encode(
                            msg.sender,
                            bytes4(msg.data),
                            log1_01(referenceAmount),
                            hashable,
                            sender,
                            accountOperationCounter
                        )
                    )
                );

                // this check must be done after the checkpoint is executed so that at this point, in case the
                // storeAttestation function is used instead of the saveAttestation function, the current attester must
                // be
                // already defined by the validator contract
                if (!isAttestationInProgress()) {
                    revert HTA_Unauthorized();
                }
            }
        } else {
            // apply the operation counter update only if the checkpoint does not need to be executed
            getHookTargetFirewallStorage().policies[msg.sender] = policy;
        }
    }

    /// @notice Authenticates the vault if it is a proxy deployed by the recognized eVault factory.
    function authenticateVault(address vault) internal {
        if (eVaultFactory.isProxy(msg.sender)) {
            getHookTargetFirewallStorage().policies[vault].isAuthenticated = true;
            emit AuthenticateVault(msg.sender);
        } else {
            revert HTA_Unauthorized();
        }
    }

    /// @notice Updates the operation counter for a given account.
    /// @param account The account for which the operation counter is updated.
    /// @return The updated operation counter.
    function updateAccountOperationCounter(address account) internal returns (uint256) {
        mapping(bytes19 prefix => uint256 counter) storage operationCounters =
            getHookTargetFirewallStorage().operationCounters;
        bytes19 prefix = _getAddressPrefix(account);
        uint256 counter = operationCounters[prefix] + 1;
        operationCounters[prefix] = counter;
        return counter;
    }

    /// @notice Updates the accumulated amount for a given transfer type and vault.
    /// @param transferType The type of transfer (In or Out).
    /// @param vault The vault address.
    /// @param referenceAmount The reference amount for the transfer.
    /// @return The updated accumulated amount.
    function updateAccumulatedAmount(TransferType transferType, address vault, uint256 referenceAmount)
        internal
        returns (uint256)
    {
        StorageSlot.Uint256SlotType slot = StorageSlot.asUint256(keccak256(abi.encode(transferType, vault)));
        uint256 accumulatedAmount = StorageSlot.tload(slot) + referenceAmount;
        StorageSlot.tstore(slot, accumulatedAmount);
        return accumulatedAmount;
    }

    /// @notice Updates the vault operation counter.
    /// @dev The update is only applied in policy memory. For the update to be persisted, update the policy storage.
    /// @param policy The policy for the vault.
    /// @return The total updated vault operation counter over all the windows.
    function updateVaultOperationCounter(PolicyStorage memory policy) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - policy.updateTimestampNormalized;
        uint256 counters = policy.operationCountersPacked;

        if (timeElapsed >= WINDOW_PERIOD) {
            // shift based on windows passed (if > 2, this will zero out all counters)
            counters = (counters << ((timeElapsed / WINDOW_PERIOD) * WINDOW_BITS)) | 1;
        } else {
            // increment the counter for the current window
            counters = counters + 1;
        }

        policy.updateTimestampNormalized = uint48(block.timestamp - (block.timestamp % WINDOW_PERIOD));
        policy.operationCountersPacked = uint96(counters);

        return uint32(counters) + uint32(counters >> WINDOW_BITS) + uint32(counters >> (2 * WINDOW_BITS));
    }

    /// @notice Checks if an attestation is in progress.
    /// @return True if an attestation is in progress, false otherwise.
    function isAttestationInProgress() internal view returns (bool) {
        address currentAttester = validator.getCurrentAttester();
        return currentAttester != address(0)
            && getHookTargetFirewallStorage().attesters[msg.sender].contains(currentAttester);
    }

    /// @notice Resolves the thresholds for a given vault and transfer type.
    /// @param transferType The type of transfer (In or Out).
    /// @param policy The policy for the vault.
    /// @return operationCounterThreshold The operation counter threshold.
    /// @return constantAmountThreshold The resolved constant amount threshold.
    /// @return accumulatedAmountThreshold The resolved accumulated amount threshold.
    function resolveThresholds(TransferType transferType, PolicyStorage memory policy)
        internal
        pure
        returns (uint256 operationCounterThreshold, uint256 constantAmountThreshold, uint256 accumulatedAmountThreshold)
    {
        operationCounterThreshold = policy.operationCounterThreshold;
        if (operationCounterThreshold == 0) {
            operationCounterThreshold = type(uint256).max;
        }

        if (transferType == TransferType.In) {
            constantAmountThreshold = policy.inConstantAmountThreshold.resolve();
            accumulatedAmountThreshold = policy.inAccumulatedAmountThreshold.resolve();
        } else {
            constantAmountThreshold = policy.outConstantAmountThreshold.resolve();
            accumulatedAmountThreshold = policy.outAccumulatedAmountThreshold.resolve();
        }
    }

    /// @notice Calculates the logarithm base 1.01 of a given number.
    /// @param x The number to calculate the logarithm for.
    /// @return The logarithm base 1.01 of the given number.
    function log1_01(uint256 x) internal pure returns (uint256) {
        if (x == 0) return type(uint256).max;

        // log1.01(x) = ln(x) / ln(1.01) = lnWad(x * 1e18) / lnWad(1.01 * 1e18)
        return uint256(FixedPointMathLib.lnWad(int256(x * 1e18))) / 9950330853168082;
    }

    /// @notice Retrieves the caller address from the calldata.
    /// @return _caller The address of the caller.
    function caller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}
