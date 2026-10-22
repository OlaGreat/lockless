import { formatEther } from "viem";
import { epochStart, isVotingOpen, nextEpochStart } from "../epoch";
import { boostVoterAbi, erc20Abi, vaultAbi } from "../mezo/abis";
import type { ContractCall } from "../mezo/reader";
import type { KeeperContext } from "./context";

const stakingAbi = [
  { type: "function", name: "totalStaked", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
] as const;

/** Prints where the vault stands this epoch. */
export async function runStatus(ctx: KeeperContext): Promise<void> {
  const { contracts } = ctx.config;
  const calls: ContractCall[] = [
    { address: contracts.vault, abi: vaultAbi, functionName: "masterTokenId" },
    { address: contracts.vault, abi: vaultAbi, functionName: "lockedAmount" },
    { address: contracts.stMEZO, abi: erc20Abi, functionName: "balanceOf", args: [contracts.staking] },
    { address: contracts.staking, abi: stakingAbi, functionName: "totalStaked" },
  ];
  const [masterTokenId, locked, , staked] = await ctx.reader.readAll<bigint>(calls);
  const lastVoted = masterTokenId ? await readLastVoted(ctx, masterTokenId) : 0;
  const now = ctx.now();

  ctx.log(
    [
      `Master lock: ${masterTokenId ? `#${masterTokenId}` : "not created yet"}`,
      `MEZO locked: ${formatEther(locked ?? 0n)}`,
      `stMEZO staked: ${formatEther(staked ?? 0n)}`,
      `Voted this epoch: ${lastVoted >= epochStart(now) ? "yes" : "no"}`,
      `Voting window: ${isVotingOpen(now) ? "open" : "closed"}`,
      `Next epoch: ${new Date(nextEpochStart(now) * 1000).toUTCString()}`,
    ].join("\n"),
  );
}

async function readLastVoted(ctx: KeeperContext, masterTokenId: bigint): Promise<number> {
  const [lastVoted] = await ctx.reader.readAll<bigint>([
    { address: ctx.config.contracts.boostVoter, abi: boostVoterAbi, functionName: "lastVoted", args: [masterTokenId] },
  ]);
  return Number(lastVoted ?? 0n);
}
