// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LocklessVault} from "../src/LocklessVault.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultVotingTest is VaultTestBase {
    address internal gaugeA = makeAddr("gaugeA");
    address internal gaugeB = makeAddr("gaugeB");

    function setUp() public override {
        super.setUp();
        _depositAs(alice, 100 ether);
    }

    function test_KeeperVotesWithTheMasterLock() public {
        (address[] memory gauges, uint256[] memory weights) = _twoGaugeVote();

        vm.prank(keeper);
        vault.vote(gauges, weights);

        uint256 master = vault.masterTokenId();
        assertEq(voter.votedGauges(master), gauges);
        assertEq(voter.votedWeights(master), weights);
    }

    function test_RevertWhen_CallerIsNotKeeper() public {
        (address[] memory gauges, uint256[] memory weights) = _twoGaugeVote();

        vm.expectRevert(LocklessVault.OnlyKeeper.selector);
        vm.prank(alice);
        vault.vote(gauges, weights);
    }

    function test_RevertWhen_VotingWithoutMasterLock() public {
        LocklessVault freshVault = new LocklessVault(ve, voter, distributor, owner, keeper);
        (address[] memory gauges, uint256[] memory weights) = _twoGaugeVote();

        vm.expectRevert(LocklessVault.NoMasterLock.selector);
        vm.prank(keeper);
        freshVault.vote(gauges, weights);
    }

    function test_AnyoneCanPokeTheMasterLock() public {
        vm.prank(bob);
        vault.poke();

        assertEq(voter.pokeCount(vault.masterTokenId()), 1);
    }

    function test_RevertWhen_PokingWithoutMasterLock() public {
        LocklessVault freshVault = new LocklessVault(ve, voter, distributor, owner, keeper);

        vm.expectRevert(LocklessVault.NoMasterLock.selector);
        freshVault.poke();
    }

    function _twoGaugeVote()
        internal
        view
        returns (address[] memory gauges, uint256[] memory weights)
    {
        gauges = new address[](2);
        gauges[0] = gaugeA;
        gauges[1] = gaugeB;
        weights = new uint256[](2);
        weights[0] = 70;
        weights[1] = 30;
    }
}
