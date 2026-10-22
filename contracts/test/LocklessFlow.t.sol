// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RewardHarvester} from "../src/RewardHarvester.sol";
import {StMEZOStaking} from "../src/StMEZOStaking.sol";
import {MockBribe} from "./mocks/MockBribe.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

/// @notice Runs one full epoch through every Lockless contract together.
contract LocklessFlowTest is VaultTestBase {
    uint256 internal constant FEE_BPS = 1_000;
    uint256 internal constant INCENTIVE = 1_000 ether;
    uint256 internal constant REBASE = 20 ether;
    uint256 internal constant ROUNDING = 1e12;

    address internal treasury = makeAddr("treasury");
    MockERC20 internal musd;
    MockBribe internal bribe;
    StMEZOStaking internal staking;
    RewardHarvester internal harvester;

    function setUp() public override {
        super.setUp();
        musd = new MockERC20("Mezo USD", "MUSD");
        bribe = new MockBribe(ve);
        staking = new StMEZOStaking(stMEZO, owner);
        harvester =
            new RewardHarvester(new MockRouter(1), musd, staking, treasury, owner, keeper, FEE_BPS);

        vm.startPrank(owner);
        vault.setRewardsReceiver(address(harvester));
        staking.addRewardToken(address(musd), address(harvester), 7 days);
        staking.addRewardToken(address(stMEZO), address(harvester), 7 days);
        vm.stopPrank();
    }

    function test_StakersEarnMusdIncentivesAndRebaseFromOneEpoch() public {
        _depositAs(alice, 300 ether);
        _depositAs(bob, 100 ether);
        _stakeAll(alice);
        _stakeAll(bob);
        _keeperVotes();

        _nextEpochIncentivesArrive();
        _keeperHarvests();
        vault.claimRebase();
        _keeperDistributes();
        vm.warp(block.timestamp + 7 days);

        uint256 toStakers = INCENTIVE - (INCENTIVE * FEE_BPS) / 10_000;
        uint256 rebaseToStakers = REBASE - (REBASE * FEE_BPS) / 10_000;
        assertApproxEqAbs(staking.earned(alice, address(musd)), (toStakers * 3) / 4, ROUNDING);
        assertApproxEqAbs(staking.earned(bob, address(musd)), toStakers / 4, ROUNDING);
        assertApproxEqAbs(
            staking.earned(alice, address(stMEZO)), (rebaseToStakers * 3) / 4, ROUNDING
        );
        assertEq(musd.balanceOf(treasury), INCENTIVE - toStakers);
        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
    }

    function _stakeAll(address user) internal {
        uint256 balance = stMEZO.balanceOf(user);
        vm.startPrank(user);
        stMEZO.approve(address(staking), balance);
        staking.stake(balance);
        vm.stopPrank();
    }

    function _keeperVotes() internal {
        address[] memory gauges = new address[](1);
        gauges[0] = makeAddr("boostGauge");
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1;
        vm.prank(keeper);
        vault.vote(gauges, weights);
    }

    function _nextEpochIncentivesArrive() internal {
        vm.warp(block.timestamp + 7 days);
        musd.mint(address(bribe), INCENTIVE);
        mezo.mint(address(distributor), REBASE);
        distributor.setPending(vault.masterTokenId(), REBASE);
    }

    function _keeperHarvests() internal {
        address[] memory bribes = new address[](1);
        bribes[0] = address(bribe);
        address[][] memory tokens = new address[][](1);
        tokens[0] = new address[](1);
        tokens[0][0] = address(musd);
        vm.prank(keeper);
        vault.harvest(bribes, tokens);
    }

    function _keeperDistributes() internal {
        vm.startPrank(keeper);
        harvester.distribute(address(musd));
        harvester.distribute(address(stMEZO));
        vm.stopPrank();
    }
}
