import { parseAbi } from "viem";

/** Mezo's veMEZO boost voter. */
export const boostVoterAbi = parseAbi([
  "function length() view returns (uint256)",
  "function gauges(uint256 index) view returns (address)",
  "function isAlive(address gauge) view returns (bool)",
  "function gaugeToBribe(address gauge) view returns (address)",
  "function weights(address gauge) view returns (uint256)",
  "function votes(uint256 tokenId, address gauge) view returns (uint256)",
  "function lastVoted(uint256 tokenId) view returns (uint256)",
]);

/** The incentive (bribe) contract attached to each boost gauge. */
export const incentiveAbi = parseAbi([
  "function rewardsListLength() view returns (uint256)",
  "function rewards(uint256 index) view returns (address)",
  "function tokenRewardsPerEpoch(address token, uint256 epochStart) view returns (uint256)",
  "function earned(address token, uint256 tokenId) view returns (uint256)",
]);

export const veMezoAbi = parseAbi([
  "function votingPowerOfNFT(uint256 tokenId) view returns (uint256)",
]);

export const vaultAbi = parseAbi([
  "function masterTokenId() view returns (uint256)",
  "function lockedAmount() view returns (uint256)",
  "function vote(address[] gauges, uint256[] weights)",
  "function harvest(address[] bribes, address[][] tokens)",
  "function claimRebase()",
  "function poke()",
]);

export const harvesterAbi = parseAbi([
  "struct Route { address from; address to; bool stable; address factory; }",
  "function lockMezo() returns (uint256)",
  "function swapToMusd(address tokenIn, uint256 amountIn, uint256 minMusdOut, Route[] routes) returns (uint256)",
  "function distribute(address token)",
]);

export const routerAbi = parseAbi([
  "struct Route { address from; address to; bool stable; address factory; }",
  "function defaultFactory() view returns (address)",
  "function getAmountsOut(uint256 amountIn, Route[] routes) view returns (uint256[])",
]);

/** MUSD's BTC/USD price feed. `fetchPrice` updates storage, so it is read with eth_call. */
export const priceFeedAbi = parseAbi(["function fetchPrice() view returns (uint256)"]);

export const erc20Abi = parseAbi([
  "function balanceOf(address account) view returns (uint256)",
]);
