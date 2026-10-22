// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RewardHarvester} from "../src/RewardHarvester.sol";
import {HarvesterTestBase} from "./utils/HarvesterTestBase.sol";

contract RewardHarvesterLockMezoTest is HarvesterTestBase {
    uint256 internal constant MEZO_INCENTIVE = 50 ether;

    event MezoLocked(uint256 amount);

    function test_LocksAllMezoIntoTheVaultForStMEZO() public {
        mezo.mint(address(harvester), MEZO_INCENTIVE);

        vm.prank(keeper);
        harvester.lockMezo();

        assertEq(mezo.balanceOf(address(harvester)), 0);
        assertEq(stToken.balanceOf(address(harvester)), MEZO_INCENTIVE);
    }

    function test_ReturnsTheLockedAmount() public {
        mezo.mint(address(harvester), MEZO_INCENTIVE);

        vm.prank(keeper);
        uint256 locked = harvester.lockMezo();

        assertEq(locked, MEZO_INCENTIVE);
    }

    function test_EmitsMezoLocked() public {
        mezo.mint(address(harvester), MEZO_INCENTIVE);

        vm.expectEmit(false, false, false, true, address(harvester));
        emit MezoLocked(MEZO_INCENTIVE);
        vm.prank(keeper);
        harvester.lockMezo();
    }

    function test_RevertWhen_ThereIsNoMezo() public {
        vm.expectRevert(RewardHarvester.NothingToLock.selector);
        vm.prank(keeper);
        harvester.lockMezo();
    }

    function test_RevertWhen_CallerIsNotKeeper() public {
        mezo.mint(address(harvester), MEZO_INCENTIVE);

        vm.expectRevert(RewardHarvester.OnlyKeeper.selector);
        vm.prank(alice);
        harvester.lockMezo();
    }
}
