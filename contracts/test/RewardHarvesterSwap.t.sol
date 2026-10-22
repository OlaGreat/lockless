// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RewardHarvester} from "../src/RewardHarvester.sol";
import {IRouter} from "../src/interfaces/IRouter.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {HarvesterTestBase} from "./utils/HarvesterTestBase.sol";

contract RewardHarvesterSwapTest is HarvesterTestBase {
    uint256 internal constant BTC_IN = 0.5 ether;
    uint256 internal constant MUSD_OUT = BTC_IN * BTC_PRICE_IN_MUSD;

    event Swapped(address indexed tokenIn, uint256 amountIn, uint256 musdOut);

    function setUp() public override {
        super.setUp();
        btc.mint(address(harvester), BTC_IN);
    }

    function test_KeeperSwapsARewardTokenIntoMusd() public {
        vm.prank(keeper);
        harvester.swapToMusd(address(btc), BTC_IN, MUSD_OUT, _btcToMusdRoute());

        assertEq(musd.balanceOf(address(harvester)), MUSD_OUT);
        assertEq(btc.balanceOf(address(harvester)), 0);
    }

    function test_SwapReturnsTheMusdReceived() public {
        vm.prank(keeper);
        uint256 musdOut = harvester.swapToMusd(address(btc), BTC_IN, 0, _btcToMusdRoute());

        assertEq(musdOut, MUSD_OUT);
    }

    function test_SwapEmitsEvent() public {
        vm.expectEmit(true, false, false, true, address(harvester));
        emit Swapped(address(btc), BTC_IN, MUSD_OUT);
        vm.prank(keeper);
        harvester.swapToMusd(address(btc), BTC_IN, 0, _btcToMusdRoute());
    }

    function test_RevertWhen_OutputIsBelowTheMinimum() public {
        IRouter.Route[] memory routes = _btcToMusdRoute();

        vm.expectRevert(MockRouter.InsufficientOutputAmount.selector);
        vm.prank(keeper);
        harvester.swapToMusd(address(btc), BTC_IN, MUSD_OUT + 1, routes);
    }

    function test_RevertWhen_RouteIsEmpty() public {
        vm.expectRevert(RewardHarvester.InvalidRoute.selector);
        vm.prank(keeper);
        harvester.swapToMusd(address(btc), BTC_IN, 0, new IRouter.Route[](0));
    }

    function test_RevertWhen_RouteDoesNotStartAtTheTokenIn() public {
        IRouter.Route[] memory routes = _btcToMusdRoute();
        routes[0].from = address(stToken);

        vm.expectRevert(RewardHarvester.InvalidRoute.selector);
        vm.prank(keeper);
        harvester.swapToMusd(address(btc), BTC_IN, 0, routes);
    }

    function test_RevertWhen_RouteDoesNotEndInMusd() public {
        IRouter.Route[] memory routes = _btcToMusdRoute();
        routes[0].to = address(stToken);

        vm.expectRevert(RewardHarvester.InvalidRoute.selector);
        vm.prank(keeper);
        harvester.swapToMusd(address(btc), BTC_IN, 0, routes);
    }

    function test_RevertWhen_CallerIsNotKeeper() public {
        IRouter.Route[] memory routes = _btcToMusdRoute();

        vm.expectRevert(RewardHarvester.OnlyKeeper.selector);
        vm.prank(alice);
        harvester.swapToMusd(address(btc), BTC_IN, 0, routes);
    }
}
