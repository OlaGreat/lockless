// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {RewardHarvester} from "../../src/RewardHarvester.sol";
import {StMEZOStaking} from "../../src/StMEZOStaking.sol";
import {IRouter} from "../../src/interfaces/IRouter.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRouter} from "../mocks/MockRouter.sol";
import {MockLocklessVault} from "../mocks/MockLocklessVault.sol";

abstract contract HarvesterTestBase is Test {
    uint256 internal constant FEE_BPS = 1_000;
    uint256 internal constant BTC_PRICE_IN_MUSD = 100_000;

    MockERC20 internal musd;
    MockERC20 internal btc;
    MockERC20 internal stToken;
    MockERC20 internal mezo;
    MockLocklessVault internal vault;
    MockRouter internal router;
    StMEZOStaking internal staking;
    RewardHarvester internal harvester;

    address internal owner = makeAddr("owner");
    address internal keeper = makeAddr("keeper");
    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice");
    address internal poolFactory = makeAddr("poolFactory");

    function setUp() public virtual {
        vm.warp(2_900 weeks);
        musd = new MockERC20("Mezo USD", "MUSD");
        btc = new MockERC20("Bitcoin", "BTC");
        stToken = new MockERC20("Lockless Staked MEZO", "stMEZO");
        mezo = new MockERC20("Mezo", "MEZO");
        vault = new MockLocklessVault(mezo, stToken);
        router = new MockRouter(BTC_PRICE_IN_MUSD);
        musd.mint(address(router), 1_000_000_000 ether);

        staking = new StMEZOStaking(stToken, owner);
        harvester =
            new RewardHarvester(router, musd, staking, vault, treasury, owner, keeper, FEE_BPS);

        vm.startPrank(owner);
        staking.addRewardToken(address(musd), address(harvester), 7 days);
        staking.addRewardToken(address(stToken), address(harvester), 7 days);
        vm.stopPrank();
    }

    function _btcToMusdRoute() internal view returns (IRouter.Route[] memory routes) {
        routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(btc), address(musd), false, poolFactory);
    }
}
