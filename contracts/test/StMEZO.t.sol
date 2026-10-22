// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StMEZO} from "../src/StMEZO.sol";

contract StMEZOTest is Test {
    address internal vault = makeAddr("vault");
    address internal alice = makeAddr("alice");
    StMEZO internal token;

    function setUp() public {
        token = new StMEZO(vault);
    }

    function test_HasLocklessNameAndSymbol() public view {
        assertEq(token.name(), "Lockless Staked MEZO");
        assertEq(token.symbol(), "stMEZO");
        assertEq(token.decimals(), 18);
    }

    function test_RemembersItsVault() public view {
        assertEq(token.vault(), vault);
    }

    function test_VaultCanMint() public {
        vm.prank(vault);
        token.mint(alice, 5 ether);

        assertEq(token.balanceOf(alice), 5 ether);
        assertEq(token.totalSupply(), 5 ether);
    }

    function test_RevertWhen_CallerIsNotVault() public {
        vm.expectRevert(StMEZO.OnlyVault.selector);
        vm.prank(alice);
        token.mint(alice, 1 ether);
    }

    function test_RevertWhen_VaultIsZeroAddress() public {
        vm.expectRevert(StMEZO.ZeroVault.selector);
        new StMEZO(address(0));
    }
}
