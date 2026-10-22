import { formatEther } from "viem";
import { epochStart } from "../epoch";
import { vaultAbi, veMezoAbi } from "../mezo/abis";
import { readOpportunities } from "../mezo/opportunities";
import { readPriceBook } from "../mezo/prices";
import { planVote } from "../votePlan";
import type { KeeperContext } from "./context";
import { describePlan, type VotePlanReport } from "./describePlan";

/** Reads this epoch's gauges and works out the best vote for the master lock. */
export async function buildVotePlan(ctx: KeeperContext): Promise<VotePlanReport> {
  const masterTokenId = await readMasterTokenId(ctx);
  const votingPower = await readVotingPower(ctx, masterTokenId);
  const prices = await readPriceBook(ctx.reader, ctx.config.contracts, ctx.config.mezoUsdPrice);
  const opportunities = await readOpportunities(ctx.reader, {
    voter: ctx.config.contracts.boostVoter,
    masterTokenId,
    epochStart: BigInt(epochStart(ctx.now())),
    prices,
  });
  return { masterTokenId, votingPower, opportunities, plan: planVote(opportunities, votingPower) };
}

export async function runPlan(ctx: KeeperContext): Promise<void> {
  ctx.log(describePlan(await buildVotePlan(ctx)));
}

export async function readMasterTokenId(ctx: KeeperContext): Promise<bigint> {
  const [tokenId] = await ctx.reader.readAll<bigint>([
    { address: ctx.config.contracts.vault, abi: vaultAbi, functionName: "masterTokenId" },
  ]);
  if (!tokenId) throw new Error("The vault has no master lock yet. Make a first deposit.");
  return tokenId;
}

async function readVotingPower(ctx: KeeperContext, masterTokenId: bigint): Promise<number> {
  const [power] = await ctx.reader.readAll<bigint>([
    {
      address: ctx.config.contracts.veMEZO,
      abi: veMezoAbi,
      functionName: "votingPowerOfNFT",
      args: [masterTokenId],
    },
  ]);
  return Number(formatEther(power ?? 0n));
}
