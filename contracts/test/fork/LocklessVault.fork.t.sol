// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LocklessVault} from "../../src/LocklessVault.sol";
import {StMEZO} from "../../src/StMEZO.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";
import {IBoostVoter} from "../../src/interfaces/IBoostVoter.sol";
import {IRewardsDistributor} from "../../src/interfaces/IRewardsDistributor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

interface IVeMEZOTestHelpers {
    function approve(address spender, uint256 tokenId) external;
}

interface IBoostVoterTestHelpers {
    function gauges(uint256 index) external view returns (address);
    function isAlive(address gauge) external view returns (bool);
}

/// @notice Runs the vault against the real Mezo testnet contracts on a local fork.
/// @dev Run with: RUN_FORK_TESTS=true FOUNDRY_PROFILE=fork forge test --match-path "test/fork/*"
contract LocklessVaultForkTest is Test {
    IVotingEscrow internal constant VE_MEZO =
        IVotingEscrow(0xaCE816CA2bcc9b12C59799dcC5A959Fb9b98111b);
    IBoostVoter internal constant VOTER = IBoostVoter(0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1);
    IRewardsDistributor internal constant DISTRIBUTOR =
        IRewardsDistributor(0x2962E8817ae716019F759d098e2caE658bDcAd04);
    IERC20 internal constant MEZO = IERC20(0x7B7c000000000000000000000000000000000001);
    uint256 internal constant EPOCH = 1 weeks;
    /// @dev A block every public RPC node has. One node lags the others by about a day.
    uint256 internal constant DEFAULT_FORK_BLOCK = 16_280_000;

    LocklessVault internal vault;
    StMEZO internal stMEZO;

    address internal owner = makeAddr("owner");
    address internal keeper = makeAddr("keeper");
    address internal alice = makeAddr("alice");
    address internal harvester = makeAddr("harvester");

    modifier onlyWhenForking() {
        if (!vm.envOr("RUN_FORK_TESTS", false)) {
            vm.skip(true);
            return;
        }
        _;
    }

    function setUp() public {
        if (!vm.envOr("RUN_FORK_TESTS", false)) return;
        _forkAtStableBlock();
        _replaceMezoPrecompileWithErc20();
        _warpToMiddleOfNextEpoch();
        vault = new LocklessVault(VE_MEZO, VOTER, DISTRIBUTOR, owner, keeper);
        stMEZO = vault.stMEZO();
        vm.prank(owner);
        vault.setRewardsReceiver(harvester);
    }

    function test_DepositCreatesARealPermanentMasterLock() public onlyWhenForking {
        _depositAs(alice, 1_000 ether);

        uint256 master = vault.masterTokenId();
        assertEq(VE_MEZO.ownerOf(master), address(vault));
        assertTrue(VE_MEZO.locked(master).isPermanent);
        assertEq(vault.lockedAmount(), 1_000 ether);
        assertEq(stMEZO.balanceOf(alice), 1_000 ether);
    }

    function test_SecondDepositGrowsTheRealMasterLock() public onlyWhenForking {
        _depositAs(alice, 1_000 ether);
        _depositAs(alice, 250 ether);

        assertEq(vault.lockedAmount(), 1_250 ether);
        assertEq(stMEZO.totalSupply(), 1_250 ether);
    }

    function test_ConvertsARealUserLock() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);

        vm.prank(alice);
        vault.depositLock(tokenId, alice);

        assertEq(stMEZO.balanceOf(alice), 500 ether);
        assertEq(vault.lockedAmount(), 501 ether);
    }

    function test_ConvertsARealPermanentLockOnceItsOwnerUnlocksIt() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        vm.startPrank(alice);
        VE_MEZO.lockPermanent(tokenId);
        VE_MEZO.unlockPermanent(tokenId);

        vault.depositLock(tokenId, alice);
        vm.stopPrank();

        assertEq(stMEZO.balanceOf(alice), 500 ether);
    }

    function test_RejectsARealLockThatIsStillPermanent() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        vm.prank(alice);
        VE_MEZO.lockPermanent(tokenId);

        vm.expectRevert(LocklessVault.UnlockPermanentLockFirst.selector);
        vm.prank(alice);
        vault.depositLock(tokenId, alice);
    }

    function test_ConvertsALockThatVotedLastEpoch() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        _voteAs(alice, tokenId);
        vm.warp(block.timestamp + EPOCH);

        vm.prank(alice);
        vault.depositLock(tokenId, alice);

        assertEq(stMEZO.balanceOf(alice), 500 ether);
    }

    function test_RejectsALockThatVotedThisEpoch() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        _voteAs(alice, tokenId);

        vm.expectRevert(LocklessVault.LockVotedThisEpoch.selector);
        vm.prank(alice);
        vault.depositLock(tokenId, alice);
    }

    function test_KeeperVotesARealBoostGauge() public onlyWhenForking {
        _depositAs(alice, 1_000 ether);
        (address[] memory gauges, uint256[] memory weights) = _singleLiveGaugeVote();

        vm.prank(keeper);
        vault.vote(gauges, weights);

        uint256 master = vault.masterTokenId();
        assertEq(VOTER.lastVoted(master), block.timestamp);
        assertTrue(VE_MEZO.voted(master));
    }

    function test_DepositsStillWorkAfterTheMasterLockVoted() public onlyWhenForking {
        _depositAs(alice, 1_000 ether);
        (address[] memory gauges, uint256[] memory weights) = _singleLiveGaugeVote();
        vm.prank(keeper);
        vault.vote(gauges, weights);

        _depositAs(alice, 10 ether);
        vault.poke();

        assertEq(vault.lockedAmount(), 1_010 ether);
    }

    function _depositAs(address user, uint256 amount) internal {
        _giveMezo(user, amount);
        vm.startPrank(user);
        MEZO.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }

    function _createApprovedLock(address user, uint256 amount) internal returns (uint256 tokenId) {
        _giveMezo(user, amount);
        vm.startPrank(user);
        MEZO.approve(address(VE_MEZO), amount);
        tokenId = VE_MEZO.createLock(amount, 52 weeks);
        IVeMEZOTestHelpers(address(VE_MEZO)).approve(address(vault), tokenId);
        vm.stopPrank();
    }

    function _voteAs(address user, uint256 tokenId) internal {
        (address[] memory gauges, uint256[] memory weights) = _singleLiveGaugeVote();
        vm.prank(user);
        VOTER.vote(tokenId, gauges, weights);
    }

    function _singleLiveGaugeVote()
        internal
        view
        returns (address[] memory gauges, uint256[] memory weights)
    {
        gauges = new address[](1);
        gauges[0] = _firstLiveGauge();
        weights = new uint256[](1);
        weights[0] = 1;
    }

    function _firstLiveGauge() internal view returns (address) {
        IBoostVoterTestHelpers helpers = IBoostVoterTestHelpers(address(VOTER));
        for (uint256 i = 0; i < 50; i++) {
            address gauge = helpers.gauges(i);
            if (helpers.isAlive(gauge)) return gauge;
        }
        revert("no live gauge");
    }

    /// @dev The public RPC balances across nodes at different heights, so the fork is pinned to
    ///      a block they all have. Override it with MEZO_FORK_BLOCK.
    function _forkAtStableBlock() internal {
        uint256 forkBlock = vm.envOr("MEZO_FORK_BLOCK", DEFAULT_FORK_BLOCK);
        vm.createSelectFork("mezo_testnet", forkBlock);
    }

    /// @dev MEZO is a native precompile on Mezo. Its on-chain stub calls itself, which only works
    ///      on the real chain, so the fork swaps in a plain ERC20 at the same address.
    function _replaceMezoPrecompileWithErc20() internal {
        vm.etch(address(MEZO), address(new MockERC20("Mezo", "MEZO")).code);
    }

    function _giveMezo(address user, uint256 amount) internal {
        MockERC20(address(MEZO)).mint(user, amount);
    }

    /// @dev Voting is closed in the first and last hour of an epoch, so tests start mid-epoch.
    function _warpToMiddleOfNextEpoch() internal {
        uint256 nextEpochStart = (block.timestamp / EPOCH + 1) * EPOCH;
        vm.warp(nextEpochStart + 3 days);
    }
}
