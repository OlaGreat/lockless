// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {StakingTestBase} from "./utils/StakingTestBase.sol";

contract StMEZOStakingExitTest is StakingTestBase {
    function setUp() public override {
        super.setUp();
        _addReward(address(musd));
    }

    function test_ExitReturnsTheWholeStakeAndAllRewards() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, 700 ether);
        vm.warp(block.timestamp + DURATION);
        uint256 owed = staking.earned(alice, address(musd));

        vm.prank(alice);
        staking.exit();

        assertEq(stToken.balanceOf(alice), 100 ether);
        assertEq(musd.balanceOf(alice), owed);
        assertEq(staking.balanceOf(alice), 0);
        assertEq(staking.totalStaked(), 0);
    }

    function test_RevertWhen_ExitingWithNothingStaked() public {
        vm.expectRevert(StMEZOStaking.ZeroAmount.selector);
        vm.prank(alice);
        staking.exit();
    }
}
