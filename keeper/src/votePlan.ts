import {
  allocateVotes,
  expectedIncentives,
  type Address,
  type GaugeOpportunity,
  type VoteAllocation,
} from "./allocation";

/** Mezo's boost voter accepts at most this many gauges in one vote. */
export const MAX_GAUGES_PER_VOTE = 30;

/** Vote weights are relative. This scale keeps six digits of precision. */
export const WEIGHT_SCALE = 1_000_000n;

export interface VoteArguments {
  gauges: Address[];
  weights: bigint[];
}

export interface VotePlan extends VoteArguments {
  allocations: VoteAllocation[];
  expectedIncentivesUsd: number;
}

/** Builds the vote the vault should cast this epoch. */
export function planVote(
  opportunities: GaugeOpportunity[],
  votingPower: number,
  maxGauges = MAX_GAUGES_PER_VOTE,
): VotePlan {
  const allocations = allocateWithinLimit(opportunities, votingPower, maxGauges);
  return {
    allocations,
    ...toVoteArguments(allocations),
    expectedIncentivesUsd: expectedIncentives(opportunities, allocations),
  };
}

/** Turns an allocation into the parallel arrays `LocklessVault.vote` expects. */
export function toVoteArguments(allocations: VoteAllocation[]): VoteArguments {
  const sorted = sortByVotes(allocations);
  const total = sorted.reduce((sum, allocation) => sum + allocation.votes, 0);
  return {
    gauges: sorted.map((allocation) => allocation.gauge),
    weights: sorted.map((allocation) => toWeight(allocation.votes, total)),
  };
}

/** When too many gauges qualify, keeps the ones deserving most votes and re-spreads over them. */
function allocateWithinLimit(
  opportunities: GaugeOpportunity[],
  votingPower: number,
  maxGauges: number,
): VoteAllocation[] {
  const allocations = allocateVotes(opportunities, votingPower);
  if (allocations.length <= maxGauges) return allocations;

  const kept = new Set(sortByVotes(allocations).slice(0, maxGauges).map((a) => a.gauge));
  return allocateVotes(
    opportunities.filter((item) => kept.has(item.gauge)),
    votingPower,
  );
}

function toWeight(votes: number, total: number): bigint {
  const weight = BigInt(Math.floor((votes / total) * Number(WEIGHT_SCALE)));
  return weight > 0n ? weight : 1n;
}

function sortByVotes(allocations: VoteAllocation[]): VoteAllocation[] {
  return [...allocations].sort((a, b) => b.votes - a.votes);
}
