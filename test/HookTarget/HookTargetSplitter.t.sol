// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {HookTargetSplitter} from "../../src/HookTarget/HookTargetSplitter.sol";
import "evk/EVault/shared/Constants.sol";

contract HookTargetMock is IHookTarget {
    bytes32 internal constant expectedVaultLocation = keccak256("expectedVault");
    bytes32 internal constant expectedCalldataHashLocation = keccak256("expectedCalldataHash");

    function setExpectedVault(address vault) external {
        bytes32 slot = expectedVaultLocation;
        assembly {
            sstore(slot, vault)
        }
    }

    function setExpectedCalldataHash(bytes32 dataHash) external {
        bytes32 slot = expectedCalldataHashLocation;
        assembly {
            sstore(slot, dataHash)
        }
    }

    function getExpectedVault() public view returns (address _expectedVault) {
        bytes32 slot = expectedVaultLocation;
        assembly {
            _expectedVault := sload(slot)
        }
    }

    function getExpectedCalldataHash() public view returns (bytes32 _expectedCalldataHash) {
        bytes32 slot = expectedCalldataHashLocation;
        assembly {
            _expectedCalldataHash := sload(slot)
        }
    }

    function isHookTarget() external view override returns (bytes4) {
        require(msg.sender == getExpectedVault(), "isHookTarget: Invalid vault");
        return this.isHookTarget.selector;
    }

    fallback() external {
        require(msg.sender == getExpectedVault(), "fallback: Invalid vault");
        require(keccak256(msg.data) == getExpectedCalldataHash(), "fallback: Invalid calldata");
    }
}

contract HookTargetMockFaulty is IHookTarget {
    function isHookTarget() external pure override returns (bytes4) {
        return 0;
    }
}

contract HookTargetSplitterTest is EVaultTestBase {
    HookTargetSplitter hookTargetSplitter;
    HookTargetSplitter hookTargetSplitterFaulty;
    HookTargetMock hookTargetMock1;
    HookTargetMock hookTargetMock2;
    HookTargetMockFaulty hookTargetMockFaulty;

    function setUp() public virtual override {
        super.setUp();

        hookTargetMock1 = new HookTargetMock();
        hookTargetMock2 = new HookTargetMock();
        hookTargetMockFaulty = new HookTargetMockFaulty();

        address[] memory hookTargets = new address[](2);
        hookTargets[0] = address(hookTargetMock1);
        hookTargets[1] = address(hookTargetMock2);
        hookTargetSplitter = new HookTargetSplitter(address(factory), address(eTST), hookTargets);
        hookTargetSplitter.forwardCall(
            address(hookTargetMock1), abi.encodeCall(HookTargetMock.setExpectedVault, address(eTST))
        );
        hookTargetSplitter.forwardCall(
            address(hookTargetMock2), abi.encodeCall(HookTargetMock.setExpectedVault, address(eTST))
        );

        hookTargets = new address[](1);
        hookTargets[0] = address(hookTargetMockFaulty);
        hookTargetSplitterFaulty = new HookTargetSplitter(address(factory), address(eTST), hookTargets);
    }

    function test_constructor() public {
        address[] memory hookTargets = new address[](1);

        vm.expectRevert();
        new HookTargetSplitter(address(0), address(eTST), hookTargets);

        vm.expectRevert();
        new HookTargetSplitter(address(factory), address(0), hookTargets);

        // succeeds
        new HookTargetSplitter(address(factory), address(eTST), hookTargets);

        hookTargets = new address[](11);
        for (uint160 i = 0; i < hookTargets.length; ++i) {
            hookTargets[i] = address(i);
        }

        vm.expectRevert();
        new HookTargetSplitter(address(factory), address(eTST), hookTargets);
    }

    function test_isHookTarget() public {
        eTST.setHookConfig(address(hookTargetSplitter), 5 | 10);
        (address hookTarget, uint32 hookedOps) = eTST.hookConfig();
        assertEq(hookTarget, address(hookTargetSplitter));
        assertEq(hookedOps, 5 | 10);

        vm.expectRevert();
        eTST.setHookConfig(address(hookTargetSplitterFaulty), 5 | 10);
    }

    function test_fallback() public {
        eTST.setHookConfig(address(hookTargetSplitter), OP_SKIM | OP_TOUCH);
        bytes memory data = abi.encodeCall(
            HookTargetMock.setExpectedCalldataHash,
            (
                keccak256(
                    abi.encodePacked(
                        abi.encodeCall(eTST.touch, ()),
                        abi.encodePacked(bytes4(0), eTST.asset(), eTST.oracle(), eTST.unitOfAccount()),
                        address(this)
                    )
                )
            )
        );

        // fails if non-vault governor calls
        vm.prank(address(1));
        vm.expectRevert();
        hookTargetSplitter.forwardCall(address(hookTargetMock1), data);

        // succeeds if vault governor calls
        hookTargetSplitter.forwardCall(address(hookTargetMock1), data);

        hookTargetSplitter.forwardCall(
            address(hookTargetMock2),
            abi.encodeCall(
                HookTargetMock.setExpectedCalldataHash,
                (
                    keccak256(
                        abi.encodePacked(
                            abi.encodeCall(eTST.touch, ()),
                            abi.encodePacked(bytes4(0), eTST.asset(), eTST.oracle(), eTST.unitOfAccount()),
                            address(this)
                        )
                    )
                )
            )
        );

        vm.expectRevert();
        hookTargetSplitter.forwardCall(address(hookTargetSplitterFaulty), "");

        vm.expectRevert();
        eTST.skim(0, address(0));

        eTST.touch();

        hookTargetSplitter.forwardCall(
            address(hookTargetMock1),
            abi.encodeCall(
                HookTargetMock.setExpectedCalldataHash,
                (
                    keccak256(
                        abi.encodePacked(
                            abi.encodeCall(eTST.skim, (0, address(0))),
                            abi.encodePacked(bytes4(0), eTST.asset(), eTST.oracle(), eTST.unitOfAccount()),
                            address(this)
                        )
                    )
                )
            )
        );
        hookTargetSplitter.forwardCall(
            address(hookTargetMock2),
            abi.encodeCall(
                HookTargetMock.setExpectedCalldataHash,
                (
                    keccak256(
                        abi.encodePacked(
                            abi.encodeCall(eTST.skim, (0, address(0))),
                            abi.encodePacked(bytes4(0), eTST.asset(), eTST.oracle(), eTST.unitOfAccount()),
                            address(this)
                        )
                    )
                )
            )
        );

        eTST.skim(0, address(0));
    }
}
