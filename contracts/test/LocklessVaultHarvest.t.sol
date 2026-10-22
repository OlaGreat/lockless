// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LocklessVault} from "../src/LocklessVault.sol";
import {MockBribe} from "./mocks/MockBribe.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultHarvestTest is VaultTestBase {
    address internal harvester = makeAddr("harvester");
    MockERC20 internal musd;
    MockERC20 internal btc;
    MockBribe internal bribeA;
    MockBribe internal bribeB;

    event RewardForwarded(address indexed token, uint256 amount);

    function setUp() public override {
        super.setUp();
        _depositAs(alice, 100 ether);
        vm.prank(owner);
        vault.setRewardsReceiver(harvester);

        musd = new MockERC20("Mezo USD", "MUSD");
        btc = new MockERC20("Bitcoin", "BTC");
        bribeA = new MockBribe(ve);
        bribeB = new MockBribe(ve);
        musd.mint(address(bribeA), 30 ether);
        btc.mint(address(bribeB), 2 ether);
        musd.mint(address(bribeB), 5 ether);
    }

    function test_HarvestSendsClaimedIncentivesToTheReceiver() public {
        (address[] memory bribes, address[][] memory tokens) = _bothBribes();

        vm.prank(keeper);
        vault.harvest(bribes, tokens);

        assertEq(musd.balanceOf(harvester), 35 ether);
        assertEq(btc.balanceOf(harvester), 2 ether);
    }

    function test_HarvestLeavesNothingInTheVault() public {
        (address[] memory bribes, address[][] memory tokens) = _bothBribes();

        vm.prank(keeper);
        vault.harvest(bribes, tokens);

        assertEq(musd.balanceOf(address(vault)), 0);
        assertEq(btc.balanceOf(address(vault)), 0);
    }

    function test_HarvestEmitsOneEventPerForwardedToken() public {
        (address[] memory bribes, address[][] memory tokens) = _bothBribes();

        vm.expectEmit(true, false, false, true, address(vault));
        emit RewardForwarded(address(musd), 35 ether);
        vm.expectEmit(true, false, false, true, address(vault));
        emit RewardForwarded(address(btc), 2 ether);
        vm.prank(keeper);
        vault.harvest(bribes, tokens);
    }

    function test_KeeperCanForwardStrayRewardTokens() public {
        musd.mint(address(vault), 4 ether);
        address[] memory tokens = new address[](1);
        tokens[0] = address(musd);

        vm.prank(keeper);
        vault.forwardRewards(tokens);

        assertEq(musd.balanceOf(harvester), 4 ether);
    }

    function test_ForwardingAnEmptyBalanceDoesNothing() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(btc);

        vm.prank(keeper);
        vault.forwardRewards(tokens);

        assertEq(btc.balanceOf(harvester), 0);
    }

    function test_RevertWhen_NonKeeperHarvests() public {
        (address[] memory bribes, address[][] memory tokens) = _bothBribes();

        vm.expectRevert(LocklessVault.OnlyKeeper.selector);
        vm.prank(alice);
        vault.harvest(bribes, tokens);
    }

    function test_RevertWhen_NonKeeperForwards() public {
        vm.expectRevert(LocklessVault.OnlyKeeper.selector);
        vm.prank(alice);
        vault.forwardRewards(new address[](0));
    }

    function test_RevertWhen_HarvestingWithoutRewardsReceiver() public {
        LocklessVault freshVault = new LocklessVault(ve, voter, distributor, owner, keeper);
        mezo.mint(alice, 1 ether);
        vm.startPrank(alice);
        mezo.approve(address(freshVault), 1 ether);
        freshVault.deposit(1 ether, alice);
        vm.stopPrank();
        (address[] memory bribes, address[][] memory tokens) = _bothBribes();

        vm.expectRevert(LocklessVault.NoRewardsReceiver.selector);
        vm.prank(keeper);
        freshVault.harvest(bribes, tokens);
    }

    function _bothBribes()
        internal
        view
        returns (address[] memory bribes, address[][] memory tokens)
    {
        bribes = new address[](2);
        bribes[0] = address(bribeA);
        bribes[1] = address(bribeB);

        tokens = new address[][](2);
        tokens[0] = new address[](1);
        tokens[0][0] = address(musd);
        tokens[1] = new address[](2);
        tokens[1][0] = address(btc);
        tokens[1][1] = address(musd);
    }
}
