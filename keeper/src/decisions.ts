import { epochStart, isVotingOpen } from "./epoch";

export interface VoteContext {
  /** Current time in seconds. */
  now: number;
  /** When the master lock last voted, in seconds. */
  lastVoted: number;
  /** How many gauges the vote plan would back. */
  gaugeCount: number;
}

export type VoteDecision = { vote: true } | { vote: false; reason: string };

/** Decides whether the keeper should cast the master lock's vote now. */
export function decideVote(context: VoteContext): VoteDecision {
  if (!isVotingOpen(context.now)) return wait("voting window is closed");
  if (context.lastVoted >= epochStart(context.now)) return wait("already voted this epoch");
  if (context.gaugeCount === 0) return wait("no gauge pays incentives this epoch");
  return { vote: true };
}

export interface HarvesterBalances {
  mezo: bigint;
  btc: bigint;
  musd: bigint;
  stMEZO: bigint;
}

export type Conversion = "lockMezo" | "swapBtcToMusd";
export type Distribution = "distributeMusd" | "distributeStMEZO";

/** The harvester's first job after a harvest: MEZO becomes stMEZO, BTC becomes MUSD. */
export function planConversions(balances: HarvesterBalances): Conversion[] {
  const steps: Conversion[] = [];
  if (balances.mezo > 0n) steps.push("lockMezo");
  if (balances.btc > 0n) steps.push("swapBtcToMusd");
  return steps;
}

/** Streams whatever MUSD and stMEZO the harvester holds once conversions are done. */
export function planDistributions(balances: HarvesterBalances): Distribution[] {
  const steps: Distribution[] = [];
  if (balances.musd > 0n) steps.push("distributeMusd");
  if (balances.stMEZO > 0n) steps.push("distributeStMEZO");
  return steps;
}

/** Accepts at most 1% less MUSD than the router quotes when swapping BTC incentives. */
const SLIPPAGE_BPS = 100n;

export type SwapDecision = { swap: true; minOut: bigint } | { swap: false; reason: string };

/**
 * Picks the minimum MUSD for a BTC swap. The harvester reverts below its oracle floor, so the
 * keeper never asks for less, and skips the swap when the pool cannot reach it.
 */
export function btcSwapMinimum(quoted: bigint, oracleFloor: bigint): SwapDecision {
  if (quoted < oracleFloor) {
    return { swap: false, reason: "the pool quotes more than 3% below Mezo's BTC price" };
  }
  const withSlippage = (quoted * (10_000n - SLIPPAGE_BPS)) / 10_000n;
  return { swap: true, minOut: withSlippage > oracleFloor ? withSlippage : oracleFloor };
}

function wait(reason: string): VoteDecision {
  return { vote: false, reason };
}
