// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LocklessVault} from "../src/LocklessVault.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultAdminTest is VaultTestBase {
    address internal newKeeper = makeAddr("newKeeper");
    address internal harvester = makeAddr("harvester");

    event KeeperUpdated(address indexed keeper);
    event RewardsReceiverUpdated(address indexed receiver);

    function test_OwnerCanChangeTheKeeper() public {
        vm.prank(owner);
        vault.setKeeper(newKeeper);

        assertEq(vault.keeper(), newKeeper);
    }

    function test_ChangingTheKeeperEmitsEvent() public {
        vm.expectEmit(true, false, false, false, address(vault));
        emit KeeperUpdated(newKeeper);
        vm.prank(owner);
        vault.setKeeper(newKeeper);
    }

    function test_RevertWhen_NonOwnerChangesTheKeeper() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        vault.setKeeper(newKeeper);
    }

    function test_RevertWhen_NewKeeperIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        vm.prank(owner);
        vault.setKeeper(address(0));
    }

    function test_StartsWithoutRewardsReceiver() public view {
        assertEq(vault.rewardsReceiver(), address(0));
    }

    function test_OwnerCanSetTheRewardsReceiver() public {
        vm.prank(owner);
        vault.setRewardsReceiver(harvester);

        assertEq(vault.rewardsReceiver(), harvester);
    }

    function test_SettingTheRewardsReceiverEmitsEvent() public {
        vm.expectEmit(true, false, false, false, address(vault));
        emit RewardsReceiverUpdated(harvester);
        vm.prank(owner);
        vault.setRewardsReceiver(harvester);
    }

    function test_RevertWhen_NonOwnerSetsTheRewardsReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        vault.setRewardsReceiver(harvester);
    }

    function test_RevertWhen_RewardsReceiverIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        vm.prank(owner);
        vault.setRewardsReceiver(address(0));
    }
}
