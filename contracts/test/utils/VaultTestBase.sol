// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {LocklessVault} from "../../src/LocklessVault.sol";
import {StMEZO} from "../../src/StMEZO.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockVotingEscrow} from "../mocks/MockVotingEscrow.sol";
import {MockBoostVoter} from "../mocks/MockBoostVoter.sol";
import {MockRewardsDistributor} from "../mocks/MockRewardsDistributor.sol";

abstract contract VaultTestBase is Test {
    /// @dev Two days into an epoch, away from the epoch flip.
    uint256 internal constant START_TIME = 2_900 weeks + 2 days;

    MockERC20 internal mezo;
    MockVotingEscrow internal ve;
    MockBoostVoter internal voter;
    MockRewardsDistributor internal distributor;
    LocklessVault internal vault;
    StMEZO internal stMEZO;

    address internal owner = makeAddr("owner");
    address internal keeper = makeAddr("keeper");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public virtual {
        vm.warp(START_TIME);
        mezo = new MockERC20("Mezo", "MEZO");
        ve = new MockVotingEscrow(mezo);
        voter = new MockBoostVoter(ve);
        distributor = new MockRewardsDistributor(ve);
        vault = new LocklessVault(ve, voter, distributor, owner, keeper);
        stMEZO = vault.stMEZO();
    }

    function _fundAndApprove(address user, uint256 amount) internal {
        mezo.mint(user, amount);
        vm.prank(user);
        mezo.approve(address(vault), amount);
    }

    function _depositAs(address user, uint256 amount) internal {
        _fundAndApprove(user, amount);
        vm.prank(user);
        vault.deposit(amount, user);
    }

    function _masterLock() internal view returns (IVotingEscrow.LockedBalance memory) {
        return ve.locked(vault.masterTokenId());
    }

    function _lockedAmount(uint256 tokenId) internal view returns (uint256) {
        return uint256(int256(ve.locked(tokenId).amount));
    }
}
