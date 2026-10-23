// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {Errors} from "ethereum-vault-connector/Errors.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IERC1271} from "ethereum-vault-connector/interfaces/IERC1271.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import {GovernorAccessControlV2} from "../../src/Governor/GovernorAccessControlV2.sol";
import {GovernorAccessControlEmergencyV2} from "../../src/Governor/GovernorAccessControlEmergencyV2.sol";

bytes4 constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

contract AcceptingSigner {
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return ERC1271_MAGIC_VALUE;
    }
}

/// @dev Submits a permit from inside an EVC call to itself, whose onBehalfOfAccount the EVC does not authenticate.
contract NestedPermitCaller {
    IEVC internal immutable evc;

    constructor(IEVC _evc) {
        evc = _evc;
    }

    function run(address onBehalfOfAccount, address signer, bytes calldata data, bytes calldata signature) external {
        evc.call(address(this), onBehalfOfAccount, 0, abi.encodeCall(this.submitPermit, (signer, data, signature)));
    }

    function submitPermit(address signer, bytes calldata data, bytes calldata signature) external {
        uint256 nonce = evc.getNonce(bytes19(bytes20(signer)), 0);
        evc.permit(signer, address(this), 0, nonce, block.timestamp, 0, data, signature);
    }

    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(ERC1271_MAGIC_VALUE);
    }
}

contract GovernorAccessControlV2Test is EVaultTestBase {
    GovernorAccessControlEmergencyV2 internal governor;
    NestedPermitCaller internal caller;
    address internal wildcardHolder;
    address internal newGovernor;

    function setUp() public override {
        super.setUp();
        wildcardHolder = makeAddr("wildcardHolder");
        newGovernor = makeAddr("newGovernor");
        caller = new NestedPermitCaller(evc);

        governor = new GovernorAccessControlEmergencyV2(address(evc), admin);
        bytes32 wildCard = governor.WILD_CARD();
        vm.prank(admin);
        governor.grantRole(wildCard, wildcardHolder);
        eTST.setGovernorAdmin(address(governor));
    }

    function test_isGovernorAccessControlV2_returnsItsSelector() public view {
        assertEq(governor.isGovernorAccessControlV2(), GovernorAccessControlV2.isGovernorAccessControlV2.selector);
    }

    function test_doesNotAnswerTheV1Marker() public {
        bytes4 v1Marker = bytes4(keccak256("isGovernorAccessControl()"));

        (bool success, bytes memory result) = address(governor).staticcall(abi.encodeWithSelector(v1Marker));
        assertFalse(success && result.length >= 32 && abi.decode(result, (bytes4)) == v1Marker);

        vm.prank(wildcardHolder);
        (success, result) = address(governor).staticcall(abi.encodeWithSelector(v1Marker));
        assertFalse(success && result.length >= 32 && abi.decode(result, (bytes4)) == v1Marker);
    }

    function test_isValidSignature_calledByEVC_reverts(bytes32 hash, bytes calldata signature) public {
        vm.prank(address(evc));
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        IERC1271(address(governor)).isValidSignature(hash, signature);
    }

    function test_nestedPermit_withGovernorAsSigner_reverts() public {
        bytes memory data = _setGovernorAdminThroughEVC(address(governor));

        vm.expectRevert(Errors.EVC_NotAuthorized.selector);
        caller.run(wildcardHolder, address(governor), data, abi.encode(address(caller)));

        assertEq(eTST.governorAdmin(), address(governor));
    }

    /// @dev Control for the test above: the same permit executes when the signer accepts the signature.
    function test_nestedPermit_withAcceptingSigner_executes() public {
        AcceptingSigner signer = new AcceptingSigner();
        vm.prank(address(governor));
        eTST.setGovernorAdmin(address(signer));

        caller.run(wildcardHolder, address(signer), _setGovernorAdminThroughEVC(address(signer)), "");

        assertEq(eTST.governorAdmin(), newGovernor);
    }

    function _setGovernorAdminThroughEVC(address signer) internal view returns (bytes memory) {
        return abi.encodeCall(
            IEVC.call, (address(eTST), signer, 0, abi.encodeCall(IGovernance.setGovernorAdmin, (newGovernor)))
        );
    }
}
