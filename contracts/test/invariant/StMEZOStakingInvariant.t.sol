// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StMEZOStaking} from "../../src/StMEZOStaking.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {StakingHandler} from "./StakingHandler.sol";

/// @notice Properties that must hold after any sequence of staking actions.
contract StMEZOStakingInvariantTest is Test {
    uint256 private constant DURATION = 7 days;

    StMEZOStaking internal staking;
    MockERC20 internal stToken;
    MockERC20 internal musd;
    StakingHandler internal handler;

    function setUp() public {
        vm.warp(2_900 weeks);
        address owner = makeAddr("owner");
        address distributor = makeAddr("distributor");
        stToken = new MockERC20("Lockless Staked MEZO", "stMEZO");
        musd = new MockERC20("Mezo USD", "MUSD");
        staking = new StMEZOStaking(stToken, owner);
        vm.prank(owner);
        staking.addRewardToken(address(musd), distributor, DURATION);

        handler = new StakingHandler(staking, stToken, musd, distributor);
        targetContract(address(handler));
    }

    /// @dev The contract can always pay every staker what they have earned.
    function invariant_RewardsOwedNeverExceedTheBalance() public view {
        assertLe(handler.totalEarned(), musd.balanceOf(address(staking)));
    }

    /// @dev Nobody is ever paid more than was put in.
    function invariant_PaidOutNeverExceedsNotified() public view {
        assertLe(handler.totalClaimed() + handler.totalEarned(), handler.totalNotified());
    }

    /// @dev Every staked token is accounted for and held by the contract.
    function invariant_StakeIsFullyBacked() public view {
        assertEq(staking.totalStaked(), handler.totalStakedByActors());
        assertEq(stToken.balanceOf(address(staking)), staking.totalStaked());
    }
}
