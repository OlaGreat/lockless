// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {StakingTestBase} from "./utils/StakingTestBase.sol";

contract StMEZOStakingSetupTest is StakingTestBase {
    event RewardTokenAdded(address indexed token, address indexed distributor, uint256 duration);

    function test_RemembersStakingTokenAndOwner() public view {
        assertEq(address(staking.stakingToken()), address(stToken));
        assertEq(staking.owner(), owner);
    }

    function test_RevertWhen_StakingTokenIsZero() public {
        vm.expectRevert(StMEZOStaking.ZeroAddress.selector);
        new StMEZOStaking(IERC20(address(0)), owner);
    }

    function test_OwnerAddsRewardToken() public {
        _addReward(address(musd));

        (address rewardDistributor, uint256 duration,,,,) = staking.rewardData(address(musd));
        assertEq(staking.rewardTokensLength(), 1);
        assertEq(staking.rewardTokens(0), address(musd));
        assertEq(rewardDistributor, distributor);
        assertEq(duration, DURATION);
    }

    function test_AddingRewardTokenEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(staking));
        emit RewardTokenAdded(address(musd), distributor, DURATION);
        _addReward(address(musd));
    }

    function test_RevertWhen_NonOwnerAddsRewardToken() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        staking.addRewardToken(address(musd), distributor, DURATION);
    }

    function test_RevertWhen_RewardTokenAddedTwice() public {
        _addReward(address(musd));

        vm.expectRevert(StMEZOStaking.RewardTokenExists.selector);
        _addReward(address(musd));
    }

    function test_RevertWhen_RewardTokenIsZero() public {
        vm.expectRevert(StMEZOStaking.ZeroAddress.selector);
        _addReward(address(0));
    }

    function test_RevertWhen_DistributorIsZero() public {
        vm.expectRevert(StMEZOStaking.ZeroAddress.selector);
        vm.prank(owner);
        staking.addRewardToken(address(musd), address(0), DURATION);
    }

    function test_RevertWhen_DurationIsZero() public {
        vm.expectRevert(StMEZOStaking.ZeroDuration.selector);
        vm.prank(owner);
        staking.addRewardToken(address(musd), distributor, 0);
    }

    function test_RevertWhen_TooManyRewardTokens() public {
        uint256 max = staking.MAX_REWARD_TOKENS();
        for (uint256 i = 0; i < max; i++) {
            _addReward(address(new MockERC20("Reward", "RWD")));
        }

        vm.expectRevert(StMEZOStaking.TooManyRewardTokens.selector);
        _addReward(address(musd));
    }
}
