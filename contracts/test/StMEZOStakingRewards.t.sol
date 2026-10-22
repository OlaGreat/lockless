// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {StakingTestBase} from "./utils/StakingTestBase.sol";

contract StMEZOStakingRewardsTest is StakingTestBase {
    uint256 internal constant REWARD = 700 ether;
    /// @dev Integer division of the reward rate loses a few wei per second.
    uint256 internal constant ROUNDING = 1e12;

    event RewardAdded(address indexed token, uint256 amount);
    event RewardPaid(address indexed account, address indexed token, uint256 amount);

    function setUp() public override {
        super.setUp();
        _addReward(address(musd));
    }

    function test_NotifyPullsTokensAndStartsAPeriod() public {
        _notify(musd, REWARD);

        (,, uint256 periodFinish, uint256 rate, uint256 lastUpdate,) =
            staking.rewardData(address(musd));
        assertEq(musd.balanceOf(address(staking)), REWARD);
        assertEq(rate, REWARD / DURATION);
        assertEq(lastUpdate, block.timestamp);
        assertEq(periodFinish, block.timestamp + DURATION);
    }

    function test_NotifyEmitsRewardAdded() public {
        musd.mint(distributor, REWARD);
        vm.startPrank(distributor);
        musd.approve(address(staking), REWARD);

        vm.expectEmit(true, false, false, true, address(staking));
        emit RewardAdded(address(musd), REWARD);
        staking.notifyRewardAmount(address(musd), REWARD);
        vm.stopPrank();
    }

    function test_SingleStakerEarnsTheWholeRewardOverThePeriod() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);

        vm.warp(block.timestamp + DURATION);

        assertApproxEqAbs(staking.earned(alice, address(musd)), REWARD, ROUNDING);
    }

    function test_EarningStopsWhenThePeriodEnds() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);

        vm.warp(block.timestamp + DURATION * 3);

        assertApproxEqAbs(staking.earned(alice, address(musd)), REWARD, ROUNDING);
    }

    function test_StakersShareInProportionToStake() public {
        _stakeAs(alice, 100 ether);
        _stakeAs(bob, 300 ether);
        _notify(musd, REWARD);

        vm.warp(block.timestamp + DURATION);

        assertApproxEqAbs(staking.earned(alice, address(musd)), 175 ether, ROUNDING);
        assertApproxEqAbs(staking.earned(bob, address(musd)), 525 ether, ROUNDING);
    }

    function test_LateStakerOnlyEarnsAfterJoining() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);
        vm.warp(block.timestamp + DURATION / 2);

        _stakeAs(bob, 100 ether);
        vm.warp(block.timestamp + DURATION / 2);

        assertApproxEqAbs(staking.earned(alice, address(musd)), 525 ether, ROUNDING);
        assertApproxEqAbs(staking.earned(bob, address(musd)), 175 ether, ROUNDING);
    }

    function test_NothingAccruesWhileNobodyStakes() public {
        _notify(musd, REWARD);
        vm.warp(block.timestamp + DURATION / 2);

        _stakeAs(alice, 100 ether);
        vm.warp(block.timestamp + DURATION / 2);

        assertApproxEqAbs(staking.earned(alice, address(musd)), REWARD / 2, ROUNDING);
    }

    function test_ClaimPaysEarnedRewards() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);
        vm.warp(block.timestamp + DURATION);
        uint256 owed = staking.earned(alice, address(musd));

        vm.prank(alice);
        staking.claimRewards();

        assertEq(musd.balanceOf(alice), owed);
        assertEq(staking.earned(alice, address(musd)), 0);
    }

    function test_ClaimEmitsRewardPaid() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);
        vm.warp(block.timestamp + DURATION);
        uint256 owed = staking.earned(alice, address(musd));

        vm.expectEmit(true, true, false, true, address(staking));
        emit RewardPaid(alice, address(musd), owed);
        vm.prank(alice);
        staking.claimRewards();
    }

    function test_WithdrawKeepsEarnedRewards() public {
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);
        vm.warp(block.timestamp + DURATION / 2);

        vm.prank(alice);
        staking.withdraw(100 ether);
        vm.warp(block.timestamp + DURATION / 2);

        assertApproxEqAbs(staking.earned(alice, address(musd)), REWARD / 2, ROUNDING);
    }

    function test_NotifyDuringAPeriodRollsOverTheLeftover() public {
        _notify(musd, REWARD);
        vm.warp(block.timestamp + DURATION / 2);

        _notify(musd, REWARD);

        (,, uint256 periodFinish, uint256 rate,,) = staking.rewardData(address(musd));
        uint256 leftover = (DURATION / 2) * (REWARD / DURATION);
        assertEq(rate, (REWARD + leftover) / DURATION);
        assertEq(periodFinish, block.timestamp + DURATION);
    }

    function test_StakingTokenCanAlsoBeAReward() public {
        _addReward(address(stToken));
        _stakeAs(alice, 100 ether);
        _notify(stToken, 70 ether);
        vm.warp(block.timestamp + DURATION);

        vm.startPrank(alice);
        staking.claimRewards();
        staking.withdraw(100 ether);
        vm.stopPrank();

        assertApproxEqAbs(stToken.balanceOf(alice), 170 ether, ROUNDING);
    }

    function test_TracksEachRewardTokenSeparately() public {
        _addReward(address(stToken));
        _stakeAs(alice, 100 ether);
        _notify(musd, REWARD);
        _notify(stToken, 70 ether);

        vm.warp(block.timestamp + DURATION);

        assertApproxEqAbs(staking.earned(alice, address(musd)), REWARD, ROUNDING);
        assertApproxEqAbs(staking.earned(alice, address(stToken)), 70 ether, ROUNDING);
    }

    function test_RevertWhen_CallerIsNotTheDistributor() public {
        musd.mint(alice, REWARD);
        vm.startPrank(alice);
        musd.approve(address(staking), REWARD);

        vm.expectRevert(StMEZOStaking.OnlyDistributor.selector);
        staking.notifyRewardAmount(address(musd), REWARD);
        vm.stopPrank();
    }

    function test_RevertWhen_RewardTokenIsUnknown() public {
        vm.expectRevert(StMEZOStaking.UnknownRewardToken.selector);
        vm.prank(distributor);
        staking.notifyRewardAmount(makeAddr("unknown"), REWARD);
    }

    function test_RevertWhen_NotifyingZero() public {
        vm.expectRevert(StMEZOStaking.ZeroAmount.selector);
        vm.prank(distributor);
        staking.notifyRewardAmount(address(musd), 0);
    }

    function testFuzz_PaidRewardsNeverExceedFunding(
        uint96 reward,
        uint96 aliceStake,
        uint96 bobStake,
        uint32 elapsed
    ) public {
        reward = uint96(bound(reward, DURATION, type(uint96).max));
        aliceStake = uint96(bound(aliceStake, 1, type(uint96).max));
        bobStake = uint96(bound(bobStake, 1, type(uint96).max));
        _stakeAs(alice, aliceStake);
        _stakeAs(bob, bobStake);
        _notify(musd, reward);
        vm.warp(block.timestamp + elapsed);

        vm.prank(alice);
        staking.claimRewards();
        vm.prank(bob);
        staking.claimRewards();

        assertLe(musd.balanceOf(alice) + musd.balanceOf(bob), reward);
    }
}
