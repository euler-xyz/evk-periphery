// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {ISwapper} from "../../src/Swaps/ISwapper.sol";
import {SwapperOwnable, Ownable, Swapper} from "../../src/Swaps/SwapperOwnable.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";

contract SwapperOwnableTest is EVaultTestBase {
    function testSwapperOwnable() public {
        address owner = makeAddr("owner");

        SwapperOwnable swapper =
            new SwapperOwnable(address(evc), owner, makeAddr("uniV2RouterStub"), makeAddr("uniV3RouterStub"));

        // only owner can call directly

        ISwapper.SwapParams memory params;
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        swapper.swap(params);
        vm.prank(owner);
        vm.expectRevert(Swapper.Swapper_UnknownHandler.selector);
        swapper.swap(params);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        swapper.repay(address(assetTST), address(eTST), 0, address(3));
        vm.prank(owner);
        swapper.repay(address(assetTST), address(eTST), 0, address(3));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        swapper.repayAndDeposit(address(assetTST), address(eTST), 0, address(3));
        vm.prank(owner);
        swapper.repayAndDeposit(address(assetTST), address(eTST), 0, address(3));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        swapper.deposit(address(assetTST), address(eTST), 0, address(3));
        vm.prank(owner);
        swapper.deposit(address(assetTST), address(eTST), 0, address(3));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        swapper.sweep(address(assetTST), 0, address(3));
        vm.prank(owner);
        swapper.sweep(address(assetTST), 0, address(3));

        bytes[] memory multicall = new bytes[](5);
        multicall[0] = abi.encodeCall(Swapper.repay, (address(assetTST), address(eTST), 0, address(3)));
        multicall[1] = abi.encodeCall(Swapper.repayAndDeposit, (address(assetTST), address(eTST), 0, address(3)));
        multicall[2] = abi.encodeCall(Swapper.deposit, (address(assetTST), address(eTST), 0, address(3)));
        multicall[3] = abi.encodeCall(Swapper.sweep, (address(assetTST), 0, address(3)));
        multicall[4] = abi.encodeCall(Swapper.swap, (params));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        swapper.multicall(multicall);
        vm.expectRevert(Swapper.Swapper_UnknownHandler.selector);
        vm.prank(owner);
        swapper.multicall(multicall);

        // only owner can call through EVC

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](1);
        items[0] = IEVC.BatchItem({
            targetContract: address(swapper),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(Swapper.swap, (params))
        });
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        evc.batch(items);
        items[0].onBehalfOfAccount = owner;
        vm.prank(owner);
        vm.expectRevert(Swapper.Swapper_UnknownHandler.selector);
        evc.batch(items);

        items[0].data = abi.encodeCall(Swapper.repay, (address(assetTST), address(eTST), 0, address(3)));
        items[0].onBehalfOfAccount = address(this);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        evc.batch(items);
        items[0].onBehalfOfAccount = owner;
        vm.prank(owner);
        evc.batch(items);

        items[0].data = abi.encodeCall(Swapper.repayAndDeposit, (address(assetTST), address(eTST), 0, address(3)));
        items[0].onBehalfOfAccount = address(this);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        evc.batch(items);
        items[0].onBehalfOfAccount = owner;
        vm.prank(owner);
        evc.batch(items);

        items[0].data = abi.encodeCall(Swapper.deposit, (address(assetTST), address(eTST), 0, address(3)));
        items[0].onBehalfOfAccount = address(this);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        evc.batch(items);
        items[0].onBehalfOfAccount = owner;
        vm.prank(owner);
        evc.batch(items);

        items[0].data = abi.encodeCall(Swapper.sweep, (address(assetTST), 0, address(3)));
        items[0].onBehalfOfAccount = address(this);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        evc.batch(items);
        items[0].onBehalfOfAccount = owner;
        vm.prank(owner);
        evc.batch(items);

        items[0].data = abi.encodeCall(Swapper.multicall, (multicall));
        items[0].onBehalfOfAccount = address(this);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        evc.batch(items);
        items[0].onBehalfOfAccount = owner;
        vm.prank(owner);
        vm.expectRevert(Swapper.Swapper_UnknownHandler.selector);
        evc.batch(items);
    }
}
