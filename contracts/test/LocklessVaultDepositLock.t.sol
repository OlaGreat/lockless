// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LocklessVault} from "../src/LocklessVault.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultDepositLockTest is VaultTestBase {
    uint256 internal constant SEED = 1 ether;
    uint256 internal constant USER_LOCK = 500 ether;

    event LockDeposited(
        address indexed caller, address indexed receiver, uint256 indexed tokenId, uint256 amount
    );

    function setUp() public override {
        super.setUp();
        _depositAs(owner, SEED);
    }

    function test_MergesUserLockIntoMasterLock() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);

        vm.prank(alice);
        vault.depositLock(tokenId, alice);

        assertEq(vault.lockedAmount(), SEED + USER_LOCK);
        assertEq(ve.ownerOf(tokenId), address(0));
    }

    function test_MintsStMEZOEqualToTheLockedMezo() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);

        vm.prank(alice);
        vault.depositLock(tokenId, alice);

        assertEq(stMEZO.balanceOf(alice), USER_LOCK);
        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
    }

    function test_CanMintToAnotherReceiver() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);

        vm.prank(alice);
        vault.depositLock(tokenId, bob);

        assertEq(stMEZO.balanceOf(bob), USER_LOCK);
    }

    function test_AcceptsPermanentLocks() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);
        vm.prank(alice);
        ve.lockPermanent(tokenId);

        vm.prank(alice);
        vault.depositLock(tokenId, alice);

        assertEq(stMEZO.balanceOf(alice), USER_LOCK);
    }

    function test_ClearsVotesFromAnEarlierEpoch() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);
        _voteAs(alice, tokenId);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(alice);
        vault.depositLock(tokenId, alice);

        assertEq(stMEZO.balanceOf(alice), USER_LOCK);
    }

    function test_EmitsLockDeposited() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);

        vm.expectEmit(true, true, true, true, address(vault));
        emit LockDeposited(alice, bob, tokenId, USER_LOCK);
        vm.prank(alice);
        vault.depositLock(tokenId, bob);
    }

    function test_RevertWhen_LockVotedThisEpoch() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);
        _voteAs(alice, tokenId);

        vm.expectRevert(LocklessVault.LockVotedThisEpoch.selector);
        vm.prank(alice);
        vault.depositLock(tokenId, alice);
    }

    function test_RevertWhen_CallerDoesNotOwnTheLock() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);

        vm.expectRevert();
        vm.prank(bob);
        vault.depositLock(tokenId, bob);
    }

    function test_RevertWhen_ReceiverIsZero() public {
        uint256 tokenId = _createApprovedLock(alice, USER_LOCK);

        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        vm.prank(alice);
        vault.depositLock(tokenId, address(0));
    }

    function test_RevertWhen_NoMasterLockExists() public {
        LocklessVault freshVault = new LocklessVault(ve, voter, distributor, owner, keeper);
        uint256 tokenId = _createLock(alice, USER_LOCK);
        vm.prank(alice);
        ve.approve(address(freshVault), tokenId);

        vm.expectRevert(LocklessVault.NoMasterLock.selector);
        vm.prank(alice);
        freshVault.depositLock(tokenId, alice);
    }

    function _createLock(address user, uint256 amount) internal returns (uint256 tokenId) {
        mezo.mint(user, amount);
        vm.startPrank(user);
        mezo.approve(address(ve), amount);
        tokenId = ve.createLock(amount, 52 weeks);
        vm.stopPrank();
    }

    function _createApprovedLock(address user, uint256 amount) internal returns (uint256 tokenId) {
        tokenId = _createLock(user, amount);
        vm.prank(user);
        ve.approve(address(vault), tokenId);
    }

    function _voteAs(address user, uint256 tokenId) internal {
        address[] memory gauges = new address[](1);
        gauges[0] = makeAddr("gauge");
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1;
        vm.prank(user);
        voter.vote(tokenId, gauges, weights);
    }
}
