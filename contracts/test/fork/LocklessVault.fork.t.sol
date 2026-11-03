// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LocklessVault} from "../../src/LocklessVault.sol";
import {StMEZO} from "../../src/StMEZO.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";
import {IBoostVoter} from "../../src/interfaces/IBoostVoter.sol";
import {IRewardsDistributor} from "../../src/interfaces/IRewardsDistributor.sol";
import {PrecompileTokenStandIn} from "../mocks/PrecompileTokenStandIn.sol";

interface IVeMEZOTestHelpers {
    function approve(address spender, uint256 tokenId) external;
}

interface IBoostVoterTestHelpers {
    function gauges(uint256 index) external view returns (address);
    function isAlive(address gauge) external view returns (bool);
    function addBribes(address gauge, address[] calldata tokens, uint256[] calldata amounts)
        external;
}

interface IRewardTestHelpers {
    function earned(address token, uint256 tokenId) external view returns (uint256);
}

interface IMinterTestHelpers {
    function updatePeriod() external returns (uint256);
    function activePeriod() external view returns (uint256);
}

interface IRewardsDistributorTestHelpers {
    function tokenLastBalance() external view returns (uint256);
}

/// @notice Runs the vault against the real Mezo testnet contracts on a local fork.
/// @dev Run with: RUN_FORK_TESTS=true forge test --match-path "test/fork/*"
contract LocklessVaultForkTest is Test {
    IVotingEscrow internal constant VE_MEZO =
        IVotingEscrow(0xaCE816CA2bcc9b12C59799dcC5A959Fb9b98111b);
    IBoostVoter internal constant VOTER = IBoostVoter(0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1);
    IRewardsDistributor internal constant DISTRIBUTOR =
        IRewardsDistributor(0x2962E8817ae716019F759d098e2caE658bDcAd04);
    IERC20 internal constant MEZO = IERC20(0x7B7c000000000000000000000000000000000001);
    IERC20 internal constant BTC = IERC20(0x7b7C000000000000000000000000000000000000);
    IERC20 internal constant MUSD = IERC20(0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503);
    IMinterTestHelpers internal constant MINTER =
        IMinterTestHelpers(0xe1952b3E980E43d3910d42088029341f436C1B74);
    /// @dev MEZO's total supply at DEFAULT_FORK_BLOCK, read from the live chain. Mezo sizes the
    ///      weekly rebase from it.
    uint256 internal constant RECORDED_MEZO_SUPPLY = 1_217_509_264_009_397_853_075_382_415;
    /// @dev The voter's maxVotingNum and the Mezo testnet block gas limit, read on 2026-11-03. The
    ///      worst-case conversion must leave a quarter of a block spare.
    uint256 internal constant MAX_GAUGES_PER_VOTE = 30;
    uint256 internal constant BLOCK_GAS_LIMIT = 10_000_000;
    uint256 internal constant EPOCH = 1 weeks;
    /// @dev A block every public RPC node has. One node lags the others by about a day.
    uint256 internal constant DEFAULT_FORK_BLOCK = 16_280_000;

    LocklessVault internal vault;
    StMEZO internal stMEZO;

    address internal owner = makeAddr("owner");
    address internal keeper = makeAddr("keeper");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
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
        _replaceTokenPrecompilesWithErc20s();
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

    function test_PaysARealLocksIncentivesWhenConverting() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        _voteAs(alice, tokenId);
        _addMezoIncentive(100 ether);
        vm.warp(block.timestamp + EPOCH);
        uint256 earned = _mezoEarnedOnFirstGauge(tokenId);

        vm.prank(alice);
        vault.depositLock(tokenId, bob);

        assertGt(earned, 0);
        assertEq(MEZO.balanceOf(bob), earned);
        assertEq(stMEZO.balanceOf(bob), 500 ether);
    }

    function test_LeavesTheMasterLocksRealIncentivesInPlace() public onlyWhenForking {
        _depositAs(owner, 1_000 ether);
        (address[] memory gauges, uint256[] memory weights) = _singleLiveGaugeVote();
        vm.prank(keeper);
        vault.vote(gauges, weights);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        _voteAs(alice, tokenId);
        _addMezoIncentive(100 ether);
        vm.warp(block.timestamp + EPOCH);
        uint256 masterEarned = _mezoEarnedOnFirstGauge(vault.masterTokenId());

        vm.prank(alice);
        vault.depositLock(tokenId, bob);

        assertGt(masterEarned, 0);
        assertEq(_mezoEarnedOnFirstGauge(vault.masterTokenId()), masterEarned);
    }

    function test_KeepsARealLocksPendingRebaseWhenConverting() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        _mirrorDistributorMezoState();
        _runNextWeeklyUpdate();
        _runNextWeeklyUpdate();
        uint256 pending = DISTRIBUTOR.claimable(tokenId);

        vm.prank(alice);
        vault.depositLock(tokenId, bob);

        assertGt(pending, 0);
        assertEq(stMEZO.balanceOf(bob), 500 ether + pending);
        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
    }

    function test_ConvertingALockThatVotedForThirtyGaugesFitsInABlock() public onlyWhenForking {
        _depositAs(owner, 1 ether);
        uint256 tokenId = _createApprovedLock(alice, 500 ether);
        address[] memory gauges = _liveGauges(MAX_GAUGES_PER_VOTE);
        _voteFor(alice, tokenId, gauges);
        _addMezoAndMusdIncentives(gauges, 10 ether);
        vm.warp(block.timestamp + EPOCH);
        (uint256 mezoEarned, uint256 musdEarned) = _earnedOn(gauges, tokenId);

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        vault.depositLock(tokenId, bob);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("gas to convert a lock on 30 gauges", gasUsed);

        assertGt(mezoEarned, 0);
        assertGt(musdEarned, 0);
        assertEq(MEZO.balanceOf(bob), mezoEarned);
        assertEq(MUSD.balanceOf(bob), musdEarned);
        assertLt(gasUsed, (BLOCK_GAS_LIMIT * 3) / 4);
    }

    function test_KeeperHarvestsRealIncentivesToTheReceiver() public onlyWhenForking {
        _depositAs(owner, 1_000 ether);
        (address[] memory gauges, uint256[] memory weights) = _singleLiveGaugeVote();
        vm.prank(keeper);
        vault.vote(gauges, weights);
        _addMezoIncentive(100 ether);
        vm.warp(block.timestamp + EPOCH);
        uint256 earned = _mezoEarnedOnFirstGauge(vault.masterTokenId());
        (address[] memory bribes, address[][] memory tokens) = _mezoClaimOnFirstGauge();

        vm.prank(keeper);
        vault.harvest(bribes, tokens);

        assertGt(earned, 0);
        assertEq(MEZO.balanceOf(harvester), earned);
        assertEq(MEZO.balanceOf(address(vault)), 0);
    }

    function test_ClaimsTheMasterLocksRealRebaseForStakers() public onlyWhenForking {
        _depositAs(owner, 1_000 ether);
        _mirrorDistributorMezoState();
        _runNextWeeklyUpdate();
        _runNextWeeklyUpdate();
        uint256 pending = DISTRIBUTOR.claimable(vault.masterTokenId());

        vault.claimRebase();

        assertGt(pending, 0);
        assertEq(vault.lockedAmount(), 1_000 ether + pending);
        assertEq(stMEZO.balanceOf(harvester), pending);
        assertEq(stMEZO.totalSupply(), vault.lockedAmount());
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

    function _addMezoIncentive(uint256 amount) internal {
        address briber = makeAddr("briber");
        _giveMezo(briber, amount);
        address[] memory tokens = new address[](1);
        tokens[0] = address(MEZO);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.startPrank(briber);
        MEZO.approve(address(VOTER), amount);
        IBoostVoterTestHelpers(address(VOTER)).addBribes(_firstLiveGauge(), tokens, amounts);
        vm.stopPrank();
    }

    function _mezoClaimOnFirstGauge()
        internal
        view
        returns (address[] memory bribes, address[][] memory tokens)
    {
        bribes = new address[](1);
        bribes[0] = VOTER.gaugeToBribe(_firstLiveGauge());
        tokens = new address[][](1);
        tokens[0] = new address[](1);
        tokens[0][0] = address(MEZO);
    }

    function _mezoEarnedOnFirstGauge(uint256 tokenId) internal view returns (uint256) {
        address bribe = VOTER.gaugeToBribe(_firstLiveGauge());
        return IRewardTestHelpers(bribe).earned(address(MEZO), tokenId);
    }

    function _voteFor(address user, uint256 tokenId, address[] memory gauges) internal {
        uint256[] memory weights = new uint256[](gauges.length);
        for (uint256 i = 0; i < gauges.length; i++) {
            weights[i] = 1;
        }
        vm.prank(user);
        VOTER.vote(tokenId, gauges, weights);
    }

    function _addMezoAndMusdIncentives(address[] memory gauges, uint256 amountEach) internal {
        address briber = makeAddr("briber");
        uint256 total = amountEach * gauges.length;
        _giveMezo(briber, total);
        deal(address(MUSD), briber, total);
        address[] memory tokens = new address[](2);
        tokens[0] = address(MEZO);
        tokens[1] = address(MUSD);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountEach;
        amounts[1] = amountEach;
        vm.startPrank(briber);
        MEZO.approve(address(VOTER), total);
        MUSD.approve(address(VOTER), total);
        for (uint256 i = 0; i < gauges.length; i++) {
            IBoostVoterTestHelpers(address(VOTER)).addBribes(gauges[i], tokens, amounts);
        }
        vm.stopPrank();
    }

    function _earnedOn(address[] memory gauges, uint256 tokenId)
        internal
        view
        returns (uint256 mezoEarned, uint256 musdEarned)
    {
        for (uint256 i = 0; i < gauges.length; i++) {
            IRewardTestHelpers bribe = IRewardTestHelpers(VOTER.gaugeToBribe(gauges[i]));
            mezoEarned += bribe.earned(address(MEZO), tokenId);
            musdEarned += bribe.earned(address(MUSD), tokenId);
        }
    }

    function _liveGauges(uint256 count) internal view returns (address[] memory gauges) {
        IBoostVoterTestHelpers helpers = IBoostVoterTestHelpers(address(VOTER));
        gauges = new address[](count);
        uint256 found = 0;
        for (uint256 i = 0; found < count; i++) {
            address gauge = helpers.gauges(i);
            if (helpers.isAlive(gauge)) gauges[found++] = gauge;
        }
    }

    /// @dev The MEZO precompile keeps balances and allowances outside EVM storage, so the stand-in
    ///      ERC20 is given the distributor's recorded balance, its standing approval to veMEZO and
    ///      the real total supply.
    function _mirrorDistributorMezoState() internal {
        address distributor = address(DISTRIBUTOR);
        _giveMezo(distributor, IRewardsDistributorTestHelpers(distributor).tokenLastBalance());
        vm.prank(distributor);
        MEZO.approve(address(VE_MEZO), type(uint256).max);
        _giveMezo(makeAddr("restOfSupply"), RECORDED_MEZO_SUPPLY - MEZO.totalSupply());
    }

    /// @dev Moves to the next epoch and runs Mezo's weekly update, which mints the rebase and
    ///      makes it claimable for every week a lock was held in full.
    function _runNextWeeklyUpdate() internal {
        vm.warp(block.timestamp + EPOCH);
        uint256 currentWeek = (block.timestamp / EPOCH) * EPOCH;
        while (MINTER.activePeriod() < currentWeek) {
            MINTER.updatePeriod();
        }
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

    /// @dev MEZO and BTC are native precompiles on Mezo. Their on-chain stubs call themselves, which
    ///      only works on the real chain, so the fork swaps in plain ERC20s at the same addresses.
    ///      Incentive contracts list BTC, so the vault reads BTC balances while converting.
    function _replaceTokenPrecompilesWithErc20s() internal {
        bytes memory standIn = address(new PrecompileTokenStandIn()).code;
        vm.etch(address(MEZO), standIn);
        vm.etch(address(BTC), standIn);
    }

    function _giveMezo(address user, uint256 amount) internal {
        PrecompileTokenStandIn(address(MEZO)).mint(user, amount);
    }

    /// @dev Voting is closed in the first and last hour of an epoch, so tests start mid-epoch.
    function _warpToMiddleOfNextEpoch() internal {
        uint256 nextEpochStart = (block.timestamp / EPOCH + 1) * EPOCH;
        vm.warp(nextEpochStart + 3 days);
    }
}
