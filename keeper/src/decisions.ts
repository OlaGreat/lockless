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

export type RewardStep = "lockMezo" | "swapBtcToMusd" | "distributeMusd" | "distributeStMEZO";

/**
 * Orders the harvester's work after a harvest: MEZO becomes stMEZO and BTC becomes MUSD first,
 * then MUSD and stMEZO stream to stakers.
 */
export function planRewardSteps(balances: HarvesterBalances): RewardStep[] {
  const steps: RewardStep[] = [];
  if (balances.mezo > 0n) steps.push("lockMezo");
  if (balances.btc > 0n) steps.push("swapBtcToMusd");
  if (balances.musd > 0n || balances.btc > 0n) steps.push("distributeMusd");
  if (balances.stMEZO > 0n || balances.mezo > 0n) steps.push("distributeStMEZO");
  return steps;
}

function wait(reason: string): VoteDecision {
  return { vote: false, reason };
}
