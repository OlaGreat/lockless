// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RewardHarvester} from "../src/RewardHarvester.sol";
import {HarvesterTestBase} from "./utils/HarvesterTestBase.sol";

contract RewardHarvesterDistributeTest is HarvesterTestBase {
    uint256 internal constant HARVESTED = 1_000 ether;
    uint256 internal constant FEE = (HARVESTED * FEE_BPS) / 10_000;

    event Distributed(address indexed token, uint256 toStakers, uint256 fee);

    function test_SendsTheFeeToTheTreasury() public {
        musd.mint(address(harvester), HARVESTED);

        vm.prank(keeper);
        harvester.distribute(address(musd));

        assertEq(musd.balanceOf(treasury), FEE);
    }

    function test_FundsStakersWithTheRest() public {
        musd.mint(address(harvester), HARVESTED);

        vm.prank(keeper);
        harvester.distribute(address(musd));

        (,,, uint256 rate,,) = staking.rewardData(address(musd));
        assertEq(musd.balanceOf(address(staking)), HARVESTED - FEE);
        assertEq(rate, (HARVESTED - FEE) / 7 days);
        assertEq(musd.balanceOf(address(harvester)), 0);
    }

    function test_DistributesRebaseStMEZOTheSameWay() public {
        stToken.mint(address(harvester), HARVESTED);

        vm.prank(keeper);
        harvester.distribute(address(stToken));

        assertEq(stToken.balanceOf(treasury), FEE);
        assertEq(stToken.balanceOf(address(staking)), HARVESTED - FEE);
    }

    function test_EmitsDistributed() public {
        musd.mint(address(harvester), HARVESTED);

        vm.expectEmit(true, false, false, true, address(harvester));
        emit Distributed(address(musd), HARVESTED - FEE, FEE);
        vm.prank(keeper);
        harvester.distribute(address(musd));
    }

    function test_SkipsTheTreasuryWhenTheFeeIsZero() public {
        vm.prank(owner);
        harvester.setFeeBps(0);
        musd.mint(address(harvester), HARVESTED);

        vm.prank(keeper);
        harvester.distribute(address(musd));

        assertEq(musd.balanceOf(treasury), 0);
        assertEq(musd.balanceOf(address(staking)), HARVESTED);
    }

    function test_RevertWhen_ThereIsNothingToDistribute() public {
        vm.expectRevert(RewardHarvester.NothingToDistribute.selector);
        vm.prank(keeper);
        harvester.distribute(address(musd));
    }

    function test_RevertWhen_CallerIsNotKeeper() public {
        musd.mint(address(harvester), HARVESTED);

        vm.expectRevert(RewardHarvester.OnlyKeeper.selector);
        vm.prank(alice);
        harvester.distribute(address(musd));
    }
}
