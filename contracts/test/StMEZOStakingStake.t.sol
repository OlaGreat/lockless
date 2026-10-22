// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {StakingTestBase} from "./utils/StakingTestBase.sol";

contract StMEZOStakingStakeTest is StakingTestBase {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    function test_StakeMovesTokensIntoTheContract() public {
        _stakeAs(alice, 40 ether);

        assertEq(stToken.balanceOf(address(staking)), 40 ether);
        assertEq(stToken.balanceOf(alice), 0);
    }

    function test_StakeRecordsBalances() public {
        _stakeAs(alice, 40 ether);
        _stakeAs(bob, 60 ether);

        assertEq(staking.balanceOf(alice), 40 ether);
        assertEq(staking.balanceOf(bob), 60 ether);
        assertEq(staking.totalStaked(), 100 ether);
    }

    function test_StakeEmitsEvent() public {
        stToken.mint(alice, 5 ether);
        vm.startPrank(alice);
        stToken.approve(address(staking), 5 ether);

        vm.expectEmit(true, false, false, true, address(staking));
        emit Staked(alice, 5 ether);
        staking.stake(5 ether);
        vm.stopPrank();
    }

    function test_WithdrawReturnsTokens() public {
        _stakeAs(alice, 40 ether);

        vm.prank(alice);
        staking.withdraw(15 ether);

        assertEq(stToken.balanceOf(alice), 15 ether);
        assertEq(staking.balanceOf(alice), 25 ether);
        assertEq(staking.totalStaked(), 25 ether);
    }

    function test_WithdrawEmitsEvent() public {
        _stakeAs(alice, 40 ether);

        vm.expectEmit(true, false, false, true, address(staking));
        emit Withdrawn(alice, 40 ether);
        vm.prank(alice);
        staking.withdraw(40 ether);
    }

    function test_RevertWhen_StakingZero() public {
        vm.expectRevert(StMEZOStaking.ZeroAmount.selector);
        vm.prank(alice);
        staking.stake(0);
    }

    function test_RevertWhen_WithdrawingZero() public {
        vm.expectRevert(StMEZOStaking.ZeroAmount.selector);
        vm.prank(alice);
        staking.withdraw(0);
    }

    function test_RevertWhen_WithdrawingMoreThanStaked() public {
        _stakeAs(alice, 10 ether);

        vm.expectRevert(StMEZOStaking.InsufficientStake.selector);
        vm.prank(alice);
        staking.withdraw(11 ether);
    }
}
