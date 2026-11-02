// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockRewardsDistributor} from "./mocks/MockRewardsDistributor.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

/// @notice Converting a lock must keep the rebase it has not claimed yet.
contract LocklessVaultConvertRebaseTest is VaultTestBase {
    uint256 internal constant SEED = 1 ether;
    uint256 internal constant USER_LOCK = 500 ether;
    uint256 internal constant REBASE = 6 ether;

    uint256 internal tokenId;

    function setUp() public override {
        super.setUp();
        _depositAs(owner, SEED);
        tokenId = _createApprovedLock(alice, USER_LOCK);
    }

    function test_MintsStMEZOForTheLocksPendingRebase() public {
        _givePendingRebase(tokenId, REBASE);

        _convertTo(bob);

        assertEq(stMEZO.balanceOf(bob), USER_LOCK + REBASE);
        assertEq(vault.lockedAmount(), SEED + USER_LOCK + REBASE);
    }

    function test_KeepsTheRebaseOfAnExpiredLock() public {
        _givePendingRebase(tokenId, REBASE);
        vm.warp(block.timestamp + 53 weeks);

        _convertTo(bob);

        assertEq(stMEZO.balanceOf(bob), USER_LOCK + REBASE);
        assertEq(mezo.balanceOf(address(vault)), 0);
    }

    function test_KeepsEveryStMEZOBackedAfterConverting() public {
        _givePendingRebase(tokenId, REBASE);
        vm.warp(block.timestamp + 53 weeks);

        _convertTo(bob);

        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
    }

    function test_RevertWhen_ThePendingRebaseCannotBeClaimedYet() public {
        _givePendingRebase(tokenId, REBASE);
        distributor.setPeriodStarted(false);

        vm.expectRevert(MockRewardsDistributor.UpdatePeriod.selector);
        _convertTo(bob);
    }

    function test_ConvertsBeforeThePeriodStartsWhenNoRebaseIsPending() public {
        distributor.setPeriodStarted(false);

        _convertTo(bob);

        assertEq(stMEZO.balanceOf(bob), USER_LOCK);
    }

    function _givePendingRebase(uint256 lockId, uint256 amount) internal {
        mezo.mint(address(distributor), amount);
        distributor.setPending(lockId, amount);
    }

    function _convertTo(address receiver) internal {
        vm.prank(alice);
        vault.depositLock(tokenId, receiver);
    }
}
