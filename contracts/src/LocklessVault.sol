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

/// @title LocklessVault
/// @notice Holds one permanent veMEZO lock (the master lock) and issues stMEZO 1:1 for the MEZO
///         inside it.
contract LocklessVault is Ownable2Step, ReentrancyGuard {
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

    event Deposited(address indexed caller, address indexed receiver, uint256 amount);
    event LockDeposited(
        address indexed caller, address indexed receiver, uint256 indexed tokenId, uint256 amount
    );
    event MasterLockCreated(uint256 indexed tokenId);

    error ZeroAddress();
    error ZeroAmount();
    error NoMasterLock();
    error LockVotedThisEpoch();

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
    /// @dev The caller must own the lock and approve the vault first. A lock that voted in the
    ///      current epoch cannot be reset until the next one, so it is rejected.
    function depositLock(uint256 tokenId, address receiver) external nonReentrant {
        _requireNonZeroAddress(receiver);
        _requireMasterLock();
        _requireNotVotedThisEpoch(tokenId);

        veMEZO.transferFrom(msg.sender, address(this), tokenId);
        uint256 amount = _absorbLock(tokenId);
        stMEZO.mint(receiver, amount);

        emit LockDeposited(msg.sender, receiver, tokenId, amount);
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

    function _absorbLock(uint256 tokenId) private returns (uint256 amount) {
        _clearVotes(tokenId);
        _unlockIfPermanent(tokenId);
        amount = _lockedAmountOf(tokenId);
        veMEZO.merge(tokenId, masterTokenId);
    }

    function _clearVotes(uint256 tokenId) private {
        if (veMEZO.voted(tokenId)) voter.reset(tokenId);
    }

    function _unlockIfPermanent(uint256 tokenId) private {
        if (veMEZO.locked(tokenId).isPermanent) veMEZO.unlockPermanent(tokenId);
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

    function _requireNotVotedThisEpoch(uint256 tokenId) private view {
        if (voter.lastVoted(tokenId) >= _currentEpochStart()) revert LockVotedThisEpoch();
    }

    function _requireNonZeroAddress(address account) private pure {
        if (account == address(0)) revert ZeroAddress();
    }

    function _requireNonZeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }
}
