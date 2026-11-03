// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StMEZO} from "./StMEZO.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IBoostVoter} from "./interfaces/IBoostVoter.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IReward} from "./interfaces/IReward.sol";
import {ILocklessVault} from "./interfaces/ILocklessVault.sol";

/// @title LocklessVault
/// @notice Holds one permanent veMEZO lock (the master lock) and issues stMEZO 1:1 for the MEZO
///         inside it.
contract LocklessVault is ILocklessVault, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Any valid duration works because the lock becomes permanent in the same transaction.
    uint256 private constant MASTER_LOCK_DURATION = 2 weeks;
    uint256 private constant EPOCH = 1 weeks;

    IVotingEscrow public immutable veMEZO;
    IERC20 public immutable mezo;
    IBoostVoter public immutable voter;
    IRewardsDistributor public immutable rebaseDistributor;
    StMEZO public immutable stMEZO;

    uint256 public masterTokenId;
    address public keeper;
    address public rewardsReceiver;

    event Deposited(address indexed caller, address indexed receiver, uint256 amount);
    event LockDeposited(
        address indexed caller, address indexed receiver, uint256 indexed tokenId, uint256 amount
    );
    event MasterLockCreated(uint256 indexed tokenId);
    event LockIncentivePaid(
        uint256 indexed tokenId, address indexed token, address indexed receiver, uint256 amount
    );
    event RewardForwarded(address indexed token, uint256 amount);
    event RebaseDistributed(uint256 amount);
    event KeeperUpdated(address indexed keeper);
    event RewardsReceiverUpdated(address indexed receiver);

    error ZeroAddress();
    error ZeroAmount();
    error NoMasterLock();
    error LockVotedThisEpoch();
    error UnlockPermanentLockFirst();
    error OnlyKeeper();
    error NoRewardsReceiver();
    error RewardsReceiverAlreadySet();

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert OnlyKeeper();
        _;
    }

    constructor(
        IVotingEscrow veMEZO_,
        IBoostVoter voter_,
        IRewardsDistributor rebaseDistributor_,
        address owner_,
        address keeper_
    ) Ownable(owner_) {
        _requireNonZeroAddress(address(veMEZO_));
        _requireNonZeroAddress(address(voter_));
        _requireNonZeroAddress(address(rebaseDistributor_));
        _requireNonZeroAddress(keeper_);

        veMEZO = veMEZO_;
        mezo = IERC20(veMEZO_.token());
        voter = voter_;
        rebaseDistributor = rebaseDistributor_;
        keeper = keeper_;
        stMEZO = new StMEZO(address(this));
    }

    /// @notice Locks MEZO into the master lock and mints the same amount of stMEZO.
    function deposit(uint256 amount, address receiver) external nonReentrant {
        _requireNonZeroAmount(amount);
        _requireNonZeroAddress(receiver);

        _pullMezo(amount);
        _lockIntoMaster(amount);
        stMEZO.mint(receiver, amount);

        emit Deposited(msg.sender, receiver, amount);
    }

    /// @notice Merges an existing veMEZO lock into the master lock and mints stMEZO for its MEZO.
    /// @dev The caller must own the lock and approve the vault first. Two kinds of lock are
    ///      rejected: one that voted this epoch (votes can only be reset next epoch), and a
    ///      permanent one (veMEZO forbids unlocking it in the block it changes owner, so its
    ///      owner unlocks it first).
    function depositLock(uint256 tokenId, address receiver) external nonReentrant {
        _requireNonZeroAddress(receiver);
        _requireMasterLock();
        _requireNotVotedThisEpoch(tokenId);
        _requireNotPermanent(tokenId);

        veMEZO.transferFrom(msg.sender, address(this), tokenId);
        _payLockIncentives(tokenId, receiver);
        uint256 paidOutRebase = _claimLockRebase(tokenId);
        uint256 amount = _absorbLock(tokenId) + _lockLooseMezo(paidOutRebase);
        stMEZO.mint(receiver, amount);

        emit LockDeposited(msg.sender, receiver, tokenId, amount);
    }

    /// @notice Splits the master lock's votes across boost gauges for this epoch.
    /// @param gauges Boost gauges to vote for.
    /// @param weights Relative weight for each gauge, in the same order.
    function vote(address[] calldata gauges, uint256[] calldata weights) external onlyKeeper {
        _requireMasterLock();
        voter.vote(masterTokenId, gauges, weights);
    }

    /// @notice Refreshes the master lock's recorded votes after its MEZO balance changed.
    function poke() external {
        _requireMasterLock();
        voter.poke(masterTokenId);
    }

    /// @notice Claims the incentives the master lock earned and passes them to the rewards
    ///         receiver.
    /// @param bribes Incentive contracts of the gauges the master lock voted for.
    /// @param tokens Reward tokens to claim from each incentive contract, in the same order.
    function harvest(address[] calldata bribes, address[][] calldata tokens)
        external
        onlyKeeper
        nonReentrant
    {
        _requireMasterLock();
        _requireRewardsReceiver();
        voter.claimBribes(bribes, tokens, masterTokenId);
        _forwardAll(tokens);
    }

    /// @notice Passes any reward tokens sitting in the vault to the rewards receiver.
    function forwardRewards(address[] calldata tokens) external onlyKeeper nonReentrant {
        _requireRewardsReceiver();
        _forwardEach(tokens);
    }

    /// @notice Claims the master lock's veMEZO rebase and mints the growth as stMEZO rewards.
    function claimRebase() external nonReentrant {
        _requireMasterLock();
        rebaseDistributor.claim(masterTokenId);
        _distributeRebase();
    }

    /// @notice Mints stMEZO for MEZO that reached the master lock without a deposit, such as a
    ///         rebase that someone else claimed for it.
    function distributeRebase() external nonReentrant {
        _distributeRebase();
    }

    /// @notice Replaces the account allowed to vote and harvest.
    function setKeeper(address newKeeper) external onlyOwner {
        _requireNonZeroAddress(newKeeper);
        keeper = newKeeper;
        emit KeeperUpdated(newKeeper);
    }

    /// @notice Sets the contract that receives harvested incentives and rebase stMEZO.
    /// @dev Can be set only once, so the owner can never redirect what stakers earn.
    function setRewardsReceiver(address newReceiver) external onlyOwner {
        _requireNonZeroAddress(newReceiver);
        _requireNoRewardsReceiver();
        rewardsReceiver = newReceiver;
        emit RewardsReceiverUpdated(newReceiver);
    }

    /// @notice MEZO currently held in the master lock.
    function lockedAmount() public view returns (uint256) {
        if (masterTokenId == 0) return 0;
        return _lockedAmountOf(masterTokenId);
    }

    function _pullMezo(uint256 amount) private {
        mezo.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _lockIntoMaster(uint256 amount) private {
        mezo.forceApprove(address(veMEZO), amount);
        if (masterTokenId == 0) {
            _createMasterLock(amount);
        } else {
            veMEZO.increaseAmount(masterTokenId, amount);
        }
    }

    function _createMasterLock(uint256 amount) private {
        uint256 tokenId = veMEZO.createLock(amount, MASTER_LOCK_DURATION);
        veMEZO.lockPermanent(tokenId);
        masterTokenId = tokenId;
        emit MasterLockCreated(tokenId);
    }

    function _distributeRebase() private {
        _requireRewardsReceiver();
        uint256 growth = _unbackedMezo();
        if (growth == 0) return;
        stMEZO.mint(rewardsReceiver, growth);
        emit RebaseDistributed(growth);
    }

    /// @dev Returns zero rather than reverting if veMEZO ever reports less than the supply.
    function _unbackedMezo() private view returns (uint256) {
        uint256 locked = lockedAmount();
        uint256 supply = stMEZO.totalSupply();
        return locked > supply ? locked - supply : 0;
    }

    function _forwardAll(address[][] calldata tokenGroups) private {
        for (uint256 i = 0; i < tokenGroups.length; i++) {
            _forwardEach(tokenGroups[i]);
        }
    }

    function _forwardEach(address[] calldata tokens) private {
        for (uint256 i = 0; i < tokens.length; i++) {
            _forwardBalance(IERC20(tokens[i]));
        }
    }

    function _forwardBalance(IERC20 token) private {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) return;
        token.safeTransfer(rewardsReceiver, balance);
        emit RewardForwarded(address(token), balance);
    }

    /// @dev Must run while the vault owns the lock and before its votes are reset: Mezo pays
    ///      incentives to the lock's current owner, and a reset forgets which gauges it voted for.
    ///      One claim covers every gauge, and each distinct token is measured and sent once.
    function _payLockIncentives(uint256 tokenId, address receiver) private {
        address[] memory bribes = _votedBribes(tokenId);
        if (bribes.length == 0) return;
        address[][] memory tokenGroups = _rewardTokensOfEach(bribes);
        address[] memory tokens = _distinct(tokenGroups);
        uint256[] memory balancesBefore = _balancesOf(tokens);
        voter.claimBribes(bribes, tokenGroups, tokenId);
        _sendGains(tokenId, tokens, balancesBefore, receiver);
    }

    /// @dev The incentive contracts of the gauges a lock votes for, skipping any gauge without one.
    function _votedBribes(uint256 tokenId) private view returns (address[] memory bribes) {
        address[] memory candidates = new address[](_votedGaugeCount(tokenId));
        for (uint256 i = 0; i < candidates.length; i++) {
            candidates[i] = voter.gaugeToBribe(voter.gaugeVote(tokenId, i));
        }
        return _withoutZeroAddresses(candidates);
    }

    /// @dev The voter exposes no length for a lock's gauge list, so this counts until a read fails.
    function _votedGaugeCount(uint256 tokenId) private view returns (uint256 count) {
        while (_hasVotedGaugeAt(tokenId, count)) {
            count++;
        }
    }

    function _hasVotedGaugeAt(uint256 tokenId, uint256 index) private view returns (bool) {
        try voter.gaugeVote(tokenId, index) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    function _rewardTokensOfEach(address[] memory bribes)
        private
        view
        returns (address[][] memory tokenGroups)
    {
        tokenGroups = new address[][](bribes.length);
        for (uint256 i = 0; i < bribes.length; i++) {
            tokenGroups[i] = _rewardTokensOf(IReward(bribes[i]));
        }
    }

    function _rewardTokensOf(IReward bribe) private view returns (address[] memory tokens) {
        tokens = new address[](bribe.rewardsListLength());
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i] = bribe.rewards(i);
        }
    }

    function _balancesOf(address[] memory tokens) private view returns (uint256[] memory balances) {
        balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = IERC20(tokens[i]).balanceOf(address(this));
        }
    }

    /// @dev Flattens token lists into one list with each token once, in first-seen order.
    function _distinct(address[][] memory groups) private pure returns (address[] memory tokens) {
        address[] memory seen = new address[](_totalLength(groups));
        uint256 count = 0;
        for (uint256 i = 0; i < groups.length; i++) {
            for (uint256 j = 0; j < groups[i].length; j++) {
                if (!_contains(seen, count, groups[i][j])) seen[count++] = groups[i][j];
            }
        }
        tokens = _firstItems(seen, count);
    }

    function _totalLength(address[][] memory groups) private pure returns (uint256 total) {
        for (uint256 i = 0; i < groups.length; i++) {
            total += groups[i].length;
        }
    }

    function _contains(address[] memory list, uint256 length, address item)
        private
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < length; i++) {
            if (list[i] == item) return true;
        }
        return false;
    }

    function _withoutZeroAddresses(address[] memory list)
        private
        pure
        returns (address[] memory kept)
    {
        address[] memory buffer = new address[](list.length);
        uint256 count = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] != address(0)) buffer[count++] = list[i];
        }
        kept = _firstItems(buffer, count);
    }

    function _firstItems(address[] memory list, uint256 count)
        private
        pure
        returns (address[] memory items)
    {
        items = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            items[i] = list[i];
        }
    }

    function _sendGains(
        uint256 tokenId,
        address[] memory tokens,
        uint256[] memory balancesBefore,
        address receiver
    ) private {
        for (uint256 i = 0; i < tokens.length; i++) {
            _sendGain(tokenId, IERC20(tokens[i]), balancesBefore[i], receiver);
        }
    }

    function _sendGain(uint256 tokenId, IERC20 token, uint256 balanceBefore, address receiver)
        private
    {
        uint256 balance = token.balanceOf(address(this));
        if (balance <= balanceBefore) return;
        uint256 gain = balance - balanceBefore;
        token.safeTransfer(receiver, gain);
        emit LockIncentivePaid(tokenId, address(token), receiver, gain);
    }

    /// @dev Must run before the merge burns the lock. Mezo adds the rebase to a live lock, but
    ///      pays an expired lock's rebase out as MEZO to its owner, the vault at this point.
    ///      Returns the MEZO paid out that way.
    function _claimLockRebase(uint256 tokenId) private returns (uint256 paidOut) {
        if (rebaseDistributor.claimable(tokenId) == 0) return 0;
        uint256 balanceBefore = mezo.balanceOf(address(this));
        rebaseDistributor.claim(tokenId);
        return mezo.balanceOf(address(this)) - balanceBefore;
    }

    function _lockLooseMezo(uint256 amount) private returns (uint256) {
        if (amount == 0) return 0;
        _lockIntoMaster(amount);
        return amount;
    }

    function _absorbLock(uint256 tokenId) private returns (uint256 amount) {
        _clearVotes(tokenId);
        amount = _lockedAmountOf(tokenId);
        veMEZO.merge(tokenId, masterTokenId);
    }

    function _clearVotes(uint256 tokenId) private {
        if (veMEZO.voted(tokenId)) voter.reset(tokenId);
    }

    function _lockedAmountOf(uint256 tokenId) private view returns (uint256) {
        return uint256(int256(veMEZO.locked(tokenId).amount));
    }

    function _currentEpochStart() private view returns (uint256) {
        return (block.timestamp / EPOCH) * EPOCH;
    }

    function _requireMasterLock() private view {
        if (masterTokenId == 0) revert NoMasterLock();
    }

    function _requireRewardsReceiver() private view {
        if (rewardsReceiver == address(0)) revert NoRewardsReceiver();
    }

    function _requireNoRewardsReceiver() private view {
        if (rewardsReceiver != address(0)) revert RewardsReceiverAlreadySet();
    }

    function _requireNotVotedThisEpoch(uint256 tokenId) private view {
        if (voter.lastVoted(tokenId) >= _currentEpochStart()) revert LockVotedThisEpoch();
    }

    function _requireNotPermanent(uint256 tokenId) private view {
        if (veMEZO.locked(tokenId).isPermanent) revert UnlockPermanentLockFirst();
    }

    function _requireNonZeroAddress(address account) private pure {
        if (account == address(0)) revert ZeroAddress();
    }

    function _requireNonZeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }
}
