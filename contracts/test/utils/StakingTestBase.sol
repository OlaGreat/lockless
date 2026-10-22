// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StMEZOStaking} from "../../src/StMEZOStaking.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

abstract contract StakingTestBase is Test {
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant START_TIME = 2_900 weeks;

    MockERC20 internal stToken;
    MockERC20 internal musd;
    StMEZOStaking internal staking;

    address internal owner = makeAddr("owner");
    address internal distributor = makeAddr("distributor");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public virtual {
        vm.warp(START_TIME);
        stToken = new MockERC20("Lockless Staked MEZO", "stMEZO");
        musd = new MockERC20("Mezo USD", "MUSD");
        staking = new StMEZOStaking(stToken, owner);
    }

    function _addReward(address token) internal {
        vm.prank(owner);
        staking.addRewardToken(token, distributor, DURATION);
    }

    function _stakeAs(address user, uint256 amount) internal {
        stToken.mint(user, amount);
        vm.startPrank(user);
        stToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }
}
