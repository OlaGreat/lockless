// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LocklessVault} from "../src/LocklessVault.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

contract LocklessVaultRebaseTest is VaultTestBase {
    uint256 internal constant DEPOSIT = 100 ether;
    uint256 internal constant REBASE = 7 ether;

    address internal harvester = makeAddr("harvester");

    event RebaseDistributed(uint256 amount);

    function setUp() public override {
        super.setUp();
        _depositAs(alice, DEPOSIT);
        vm.prank(owner);
        vault.setRewardsReceiver(harvester);
        mezo.mint(address(distributor), REBASE);
        distributor.setPending(vault.masterTokenId(), REBASE);
    }

    function test_ClaimRebaseGrowsTheMasterLock() public {
        vault.claimRebase();

        assertEq(vault.lockedAmount(), DEPOSIT + REBASE);
    }

    function test_ClaimRebaseMintsTheGrowthToTheRewardsReceiver() public {
        vault.claimRebase();

        assertEq(stMEZO.balanceOf(harvester), REBASE);
        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
    }

    function test_AnyoneCanClaimTheRebase() public {
        vm.prank(bob);
        vault.claimRebase();

        assertEq(stMEZO.balanceOf(harvester), REBASE);
    }

    function test_DistributeRebaseCatchesClaimsMadeByOthers() public {
        distributor.claim(vault.masterTokenId());

        vault.distributeRebase();

        assertEq(stMEZO.balanceOf(harvester), REBASE);
        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
    }

    function test_DistributeRebaseEmitsTheMintedAmount() public {
        distributor.claim(vault.masterTokenId());

        vm.expectEmit(false, false, false, true, address(vault));
        emit RebaseDistributed(REBASE);
        vault.distributeRebase();
    }

    function test_DistributeRebaseWithoutGrowthMintsNothing() public {
        vault.distributeRebase();

        assertEq(stMEZO.balanceOf(harvester), 0);
        assertEq(stMEZO.totalSupply(), DEPOSIT);
    }

    function test_ClaimingTwiceDoesNotMintTwice() public {
        vault.claimRebase();
        vault.claimRebase();

        assertEq(stMEZO.balanceOf(harvester), REBASE);
    }

    function test_RevertWhen_DistributingWithoutRewardsReceiver() public {
        LocklessVault freshVault = new LocklessVault(ve, voter, distributor, owner, keeper);

        vm.expectRevert(LocklessVault.NoRewardsReceiver.selector);
        freshVault.distributeRebase();
    }

    function test_RevertWhen_ClaimingWithoutMasterLock() public {
        LocklessVault freshVault = new LocklessVault(ve, voter, distributor, owner, keeper);

        vm.expectRevert(LocklessVault.NoMasterLock.selector);
        freshVault.claimRebase();
    }
}
