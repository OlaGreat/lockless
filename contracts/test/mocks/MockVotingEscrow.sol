// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";

/// @notice Follows the veMEZO rules Lockless relies on: ownership, permanent locks, merge and
///         the voted flag. Error names match the real contract.
contract MockVotingEscrow is IVotingEscrow {
    uint256 public constant MAX_LOCK_TIME = 4 * 365 days;

    IERC20 private immutable _token;
    uint256 private _nextTokenId = 1;

    mapping(uint256 tokenId => address) private _owners;
    mapping(uint256 tokenId => address) private _approvals;
    mapping(uint256 tokenId => LockedBalance) private _locked;
    mapping(uint256 tokenId => bool) public voted;

    error NotApprovedOrOwner();
    error NotOwner();
    error AlreadyVoted();
    error PermanentLock();
    error NotPermanentLock();
    error SameNFT();
    error ZeroAmount();

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        if (!isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
        _;
    }

    constructor(IERC20 token_) {
        _token = token_;
    }

    function token() external view returns (address) {
        return address(_token);
    }

    function createLock(uint256 value, uint256 lockDuration) external returns (uint256) {
        return createLockFor(value, lockDuration, msg.sender);
    }

    function createLockFor(uint256 value, uint256 lockDuration, address to)
        public
        returns (uint256 tokenId)
    {
        if (value == 0) revert ZeroAmount();
        _token.transferFrom(msg.sender, address(this), value);
        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _locked[tokenId] = LockedBalance(_toInt128(value), block.timestamp + lockDuration, false, 0);
    }

    function increaseAmount(uint256 tokenId, uint256 value) external onlyApprovedOrOwner(tokenId) {
        _addToLock(tokenId, value);
    }

    function depositFor(uint256 tokenId, uint256 value) external {
        _addToLock(tokenId, value);
    }

    function lockPermanent(uint256 tokenId) external onlyApprovedOrOwner(tokenId) {
        if (_locked[tokenId].isPermanent) revert PermanentLock();
        _locked[tokenId].isPermanent = true;
        _locked[tokenId].end = 0;
    }

    function unlockPermanent(uint256 tokenId) external onlyApprovedOrOwner(tokenId) {
        if (voted[tokenId]) revert AlreadyVoted();
        if (!_locked[tokenId].isPermanent) revert NotPermanentLock();
        _locked[tokenId].isPermanent = false;
        _locked[tokenId].end = block.timestamp + MAX_LOCK_TIME;
    }

    function merge(uint256 from, uint256 to)
        external
        onlyApprovedOrOwner(from)
        onlyApprovedOrOwner(to)
    {
        if (voted[from]) revert AlreadyVoted();
        if (from == to) revert SameNFT();
        if (_locked[from].isPermanent) revert PermanentLock();
        _locked[to].amount += _locked[from].amount;
        delete _locked[from];
        delete _owners[from];
        delete _approvals[from];
    }

    function locked(uint256 tokenId) external view returns (LockedBalance memory) {
        return _locked[tokenId];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function approve(address spender, uint256 tokenId) external {
        if (_owners[tokenId] != msg.sender) revert NotOwner();
        _approvals[tokenId] = spender;
    }

    function transferFrom(address from, address to, uint256 tokenId)
        external
        onlyApprovedOrOwner(tokenId)
    {
        if (_owners[tokenId] != from) revert NotOwner();
        _owners[tokenId] = to;
        delete _approvals[tokenId];
    }

    function voting(uint256 tokenId, bool hasVoted) external {
        voted[tokenId] = hasVoted;
    }

    function isApprovedOrOwner(address spender, uint256 tokenId) public view returns (bool) {
        return _owners[tokenId] == spender || _approvals[tokenId] == spender;
    }

    function _addToLock(uint256 tokenId, uint256 value) private {
        if (value == 0) revert ZeroAmount();
        _token.transferFrom(msg.sender, address(this), value);
        _locked[tokenId].amount += _toInt128(value);
    }

    function _toInt128(uint256 value) private pure returns (int128) {
        return SafeCast.toInt128(SafeCast.toInt256(value));
    }
}
