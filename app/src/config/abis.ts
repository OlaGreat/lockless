import { erc20Abi, parseAbi } from "viem";

export { erc20Abi };

export const vaultAbi = parseAbi([
  "function deposit(uint256 amount, address receiver)",
  "function depositLock(uint256 tokenId, address receiver)",
  "function lockedAmount() view returns (uint256)",
  "function masterTokenId() view returns (uint256)",
]);

export const stakingAbi = parseAbi([
  "function stake(uint256 amount)",
  "function withdraw(uint256 amount)",
  "function claimRewards()",
  "function exit()",
  "function totalStaked() view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function earned(address account, address token) view returns (uint256)",
]);

export const veMezoAbi = parseAbi([
  "struct LockedBalance { int128 amount; uint256 end; bool isPermanent; uint256 boost; }",
  "function balanceOf(address owner) view returns (uint256)",
  "function ownerToNFTokenIdList(address owner, uint256 index) view returns (uint256)",
  "function locked(uint256 tokenId) view returns (LockedBalance)",
  "function escrowType(uint256 tokenId) view returns (uint8)",
  "function vestingEnd(uint256 tokenId) view returns (uint256)",
  "function voted(uint256 tokenId) view returns (bool)",
  "function getApproved(uint256 tokenId) view returns (address)",
  "function votingPowerOfNFT(uint256 tokenId) view returns (uint256)",
  "function approve(address spender, uint256 tokenId)",
  "function unlockPermanent(uint256 tokenId)",
]);

export const boostVoterAbi = parseAbi([
  "function lastVoted(uint256 tokenId) view returns (uint256)",
  "function reset(uint256 tokenId)",
]);
