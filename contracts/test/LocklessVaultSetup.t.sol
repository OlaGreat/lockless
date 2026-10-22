// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LocklessVault} from "../src/LocklessVault.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {IBoostVoter} from "../src/interfaces/IBoostVoter.sol";
import {IRewardsDistributor} from "../src/interfaces/IRewardsDistributor.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultSetupTest is VaultTestBase {
    function test_WiresMezoContracts() public view {
        assertEq(address(vault.veMEZO()), address(ve));
        assertEq(address(vault.mezo()), address(mezo));
        assertEq(address(vault.voter()), address(voter));
        assertEq(address(vault.rebaseDistributor()), address(distributor));
    }

    function test_DeploysStMEZOThatOnlyItCanMint() public view {
        assertEq(stMEZO.vault(), address(vault));
    }

    function test_SetsOwnerAndKeeper() public view {
        assertEq(vault.owner(), owner);
        assertEq(vault.keeper(), keeper);
    }

    function test_StartsWithoutMasterLock() public view {
        assertEq(vault.masterTokenId(), 0);
        assertEq(vault.lockedAmount(), 0);
    }

    function test_RevertWhen_VeMEZOIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        new LocklessVault(IVotingEscrow(address(0)), voter, distributor, owner, keeper);
    }

    function test_RevertWhen_VoterIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        new LocklessVault(ve, IBoostVoter(address(0)), distributor, owner, keeper);
    }

    function test_RevertWhen_DistributorIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        new LocklessVault(ve, voter, IRewardsDistributor(address(0)), owner, keeper);
    }

    function test_RevertWhen_KeeperIsZero() public {
        vm.expectRevert(LocklessVault.ZeroAddress.selector);
        new LocklessVault(ve, voter, distributor, owner, address(0));
    }
}
