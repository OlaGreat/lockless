import type { WalletClient } from "viem";
import { decideVote } from "../decisions";
import { boostVoterAbi, vaultAbi } from "../mezo/abis";
import { sendAndWait } from "../mezo/chain";
import type { KeeperContext } from "./context";
import { describePlan } from "./describePlan";
import { buildVotePlan } from "./plan";

/** Casts the master lock's vote for this epoch when it is time to. */
export async function runVote(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  const report = await buildVotePlan(ctx);
  ctx.log(describePlan(report));

  const decision = decideVote({
    now: ctx.now(),
    lastVoted: await readLastVoted(ctx, report.masterTokenId),
    gaugeCount: report.plan.gauges.length,
  });
  if (!decision.vote) {
    ctx.log(`Not voting: ${decision.reason}.`);
    return;
  }

  const link = await sendAndWait(ctx.client, signer, {
    address: ctx.config.contracts.vault,
    abi: vaultAbi,
    functionName: "vote",
    args: [report.plan.gauges, report.plan.weights],
  });
  ctx.log(`Voted: ${link}`);
}

async function readLastVoted(ctx: KeeperContext, masterTokenId: bigint): Promise<number> {
  const [lastVoted] = await ctx.reader.readAll<bigint>([
    {
      address: ctx.config.contracts.boostVoter,
      abi: boostVoterAbi,
      functionName: "lastVoted",
      args: [masterTokenId],
    },
  ]);
  return Number(lastVoted ?? 0n);
}
