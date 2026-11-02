// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StMEZOStaking} from "../../src/StMEZOStaking.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice Drives StMEZOStaking with random stakes, withdrawals, claims, top-ups and time jumps.
contract StakingHandler is Test {
    uint256 private constant MAX_AMOUNT = 1_000_000 ether;
    uint256 private constant MAX_JUMP = 30 days;

    StMEZOStaking public immutable staking;
    MockERC20 public immutable stToken;
    MockERC20 public immutable musd;
    address public immutable distributor;

    address[] public actors;
    uint256 public totalNotified;
    uint256 public totalClaimed;

    constructor(StMEZOStaking staking_, MockERC20 stToken_, MockERC20 musd_, address distributor_) {
        staking = staking_;
        stToken = stToken_;
        musd = musd_;
        distributor = distributor_;
        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("carol"));
    }

    function stake(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 1, MAX_AMOUNT);
        stToken.mint(actor, amount);
        vm.startPrank(actor);
        stToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        uint256 staked = staking.balanceOf(actor);
        if (staked == 0) return;
        vm.prank(actor);
        staking.withdraw(bound(amount, 1, staked));
    }

    function claim(uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 before = musd.balanceOf(actor);
        vm.prank(actor);
        staking.claimRewards();
        totalClaimed += musd.balanceOf(actor) - before;
    }

    function notify(uint256 amount) external {
        amount = bound(amount, 1 ether, MAX_AMOUNT);
        musd.mint(distributor, amount);
        vm.startPrank(distributor);
        musd.approve(address(staking), amount);
        staking.notifyRewardAmount(address(musd), amount);
        vm.stopPrank();
        totalNotified += amount;
    }

    function jump(uint256 seconds_) external {
        vm.warp(block.timestamp + bound(seconds_, 1, MAX_JUMP));
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function totalEarned() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            sum += staking.earned(actors[i], address(musd));
        }
    }

    function totalStakedByActors() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            sum += staking.balanceOf(actors[i]);
        }
    }

    function _actor(uint256 seed) private view returns (address) {
        return actors[seed % actors.length];
    }
}
