// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockBribe} from "./mocks/MockBribe.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {VaultTestBase} from "./utils/VaultTestBase.sol";

/// @notice Converting a lock must pay out the incentives it earned before Mezo burns it.
contract LocklessVaultConvertIncentivesTest is VaultTestBase {
    uint256 internal constant SEED = 1 ether;
    uint256 internal constant USER_LOCK = 500 ether;

    MockERC20 internal musd;
    MockERC20 internal btc;
    address internal gaugeA = makeAddr("gaugeA");
    address internal gaugeB = makeAddr("gaugeB");
    MockBribe internal bribeA;
    MockBribe internal bribeB;
    uint256 internal tokenId;

    event LockIncentivePaid(
        uint256 indexed tokenId, address indexed token, address indexed receiver, uint256 amount
    );

    function setUp() public override {
        super.setUp();
        _depositAs(owner, SEED);
        musd = new MockERC20("Mezo USD", "MUSD");
        btc = new MockERC20("Bitcoin", "BTC");
        bribeA = _registerBribe(gaugeA);
        bribeB = _registerBribe(gaugeB);

        tokenId = _createApprovedLock(alice, USER_LOCK);
        _voteFor(alice, tokenId, _bothGauges());
        vm.warp(block.timestamp + 1 weeks);
    }

    function test_PaysTheLocksUnclaimedIncentivesToTheReceiver() public {
        bribeA.addEarned(address(musd), tokenId, 40 ether);

        _convertTo(bob);

        assertEq(musd.balanceOf(bob), 40 ether);
    }

    function test_PaysIncentivesFromEveryGaugeTheLockVotedFor() public {
        bribeA.addEarned(address(musd), tokenId, 40 ether);
        bribeB.addEarned(address(btc), tokenId, 3 ether);
        bribeB.addEarned(address(musd), tokenId, 2 ether);

        _convertTo(bob);

        assertEq(musd.balanceOf(bob), 42 ether);
        assertEq(btc.balanceOf(bob), 3 ether);
    }

    function test_LeavesIncentivesEarnedByOtherLocks() public {
        uint256 master = vault.masterTokenId();
        bribeA.addEarned(address(musd), master, 25 ether);
        bribeA.addEarned(address(musd), tokenId, 40 ether);

        _convertTo(bob);

        assertEq(bribeA.earned(address(musd), master), 25 ether);
        assertEq(musd.balanceOf(bob), 40 ether);
    }

    function test_KeepsStrayTokensInTheVault() public {
        musd.mint(address(vault), 7 ether);
        bribeA.addEarned(address(musd), tokenId, 40 ether);

        _convertTo(bob);

        assertEq(musd.balanceOf(bob), 40 ether);
        assertEq(musd.balanceOf(address(vault)), 7 ether);
    }

    function test_EmitsAnEventForEachPaidIncentive() public {
        bribeA.addEarned(address(musd), tokenId, 40 ether);

        vm.expectEmit(true, true, true, true, address(vault));
        emit LockIncentivePaid(tokenId, address(musd), bob, 40 ether);
        _convertTo(bob);
    }

    function test_ConvertsALockWithNothingToClaim() public {
        _convertTo(bob);

        assertEq(stMEZO.balanceOf(bob), USER_LOCK);
        assertEq(musd.balanceOf(bob), 0);
    }

    function _convertTo(address receiver) internal {
        vm.prank(alice);
        vault.depositLock(tokenId, receiver);
    }

    function _registerBribe(address gauge) internal returns (MockBribe bribe) {
        bribe = new MockBribe(ve, address(voter));
        voter.setBribe(gauge, address(bribe));
    }

    function _bothGauges() internal view returns (address[] memory gauges) {
        gauges = new address[](2);
        gauges[0] = gaugeA;
        gauges[1] = gaugeB;
    }
}
