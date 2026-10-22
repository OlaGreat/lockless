// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LocklessVault} from "../src/LocklessVault.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultDepositTest is VaultTestBase {
    event Deposited(address indexed caller, address indexed receiver, uint256 amount);
    event MasterLockCreated(uint256 indexed tokenId);

    function test_FirstDepositCreatesPermanentMasterLockOwnedByVault() public {
        _depositAs(alice, 100 ether);

        uint256 master = vault.masterTokenId();
        IVotingEscrow.LockedBalance memory lock = _masterLock();
        assertGt(master, 0);
        assertEq(ve.ownerOf(master), address(vault));
        assertTrue(lock.isPermanent);
        assertEq(_lockedAmount(master), 100 ether);
    }

    function test_FirstDepositAnnouncesMasterLock() public {
        _fundAndApprove(alice, 1 ether);

        vm.expectEmit(true, false, false, false, address(vault));
        emit MasterLockCreated(1);
        vm.prank(alice);
        vault.deposit(1 ether, alice);
    }

    function test_LaterDepositsGrowTheSameMasterLock() public {
        _depositAs(alice, 100 ether);
        uint256 master = vault.masterTokenId();

        _depositAs(bob, 40 ether);

        assertEq(vault.masterTokenId(), master);
        assertEq(_lockedAmount(master), 140 ether);
    }

    function test_MintsStMEZOOneToOne() public {
        _depositAs(alice, 100 ether);
        _depositAs(bob, 40 ether);

        assertEq(stMEZO.balanceOf(alice), 100 ether);
        assertEq(stMEZO.balanceOf(bob), 40 ether);
    }

    function test_PullsMezoFromCaller() public {
        _fundAndApprove(alice, 100 ether);

        vm.prank(alice);
        vault.deposit(60 ether, alice);

        assertEq(mezo.balanceOf(alice), 40 ether);
        assertEq(mezo.balanceOf(address(vault)), 0);
    }

    function test_CanMintToAnotherReceiver() public {
        _fundAndApprove(alice, 10 ether);

        vm.prank(alice);
        vault.deposit(10 ether, bob);

        assertEq(stMEZO.balanceOf(bob), 10 ether);
        assertEq(stMEZO.balanceOf(alice), 0);
    }

    function test_EmitsDeposited() public {
        _fundAndApprove(alice, 10 ether);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposited(alice, bob, 10 ether);
        vm.prank(alice);
        vault.deposit(10 ether, bob);
    }

    function test_ReportsLockedAmount() public {
        _depositAs(alice, 75 ether);

        assertEq(vault.lockedAmount(), 75 ether);
    }

    function test_RevertWhen_AmountIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAmount.selector);
        vm.prank(alice);
        vault.deposit(0, alice);
    }

    function test_RevertWhen_ReceiverIsZero() public {
        _fundAndApprove(alice, 1 ether);

        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        vm.prank(alice);
        vault.deposit(1 ether, address(0));
    }

    function testFuzz_SupplyAlwaysEqualsLockedMezo(uint96 first, uint96 second) public {
        vm.assume(first > 0 && second > 0);

        _depositAs(alice, first);
        _depositAs(bob, second);

        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
        assertEq(vault.lockedAmount(), uint256(first) + uint256(second));
    }
}
