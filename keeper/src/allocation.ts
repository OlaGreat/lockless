export type Address = `0x${string}`;

/** One boost gauge the vault could vote for this epoch. */
export interface GaugeOpportunity {
  gauge: Address;
  /** USD value of the incentives posted on the gauge for this epoch. */
  incentiveUsd: number;
  /** Votes already on the gauge from everyone else. */
  otherVotes: number;
}

export interface VoteAllocation {
  gauge: Address;
  votes: number;
}

interface Candidate {
  gauge: Address;
  incentive: number;
  others: number;
}

/**
 * Gauges with few votes are treated as if others hold at least this share of our power.
 * Without it, one wei of our votes would look like it captures a gauge's whole incentive,
 * even though other voters can still join before the epoch ends.
 */
const DEFAULT_MIN_OTHER_VOTES_SHARE = 0.01;
const PRICE_SEARCH_STEPS = 200;

/**
 * Splits voting power across gauges to maximise the incentives earned.
 *
 * A gauge pays `incentive * votes / (others + votes)`, so each extra vote earns less. The best
 * split gives every chosen gauge the same return on its last vote (water-filling). At a marginal
 * return `price`, a gauge wants `sqrt(incentive * others / price) - others` votes, so the search
 * looks for the price at which the gauges want exactly our voting power.
 */
export function allocateVotes(
  opportunities: GaugeOpportunity[],
  votingPower: number,
  minOtherVotesShare = DEFAULT_MIN_OTHER_VOTES_SHARE,
): VoteAllocation[] {
  if (votingPower <= 0) return [];
  const candidates = toCandidates(opportunities, votingPower * minOtherVotesShare);
  if (candidates.length === 0) return [];

  const price = findClearingPrice(candidates, votingPower);
  return scaleToPower(votesAtPrice(candidates, price), votingPower);
}

/** Incentives the allocation would earn if no one else changed their votes. */
export function expectedIncentives(
  opportunities: GaugeOpportunity[],
  allocations: VoteAllocation[],
): number {
  const byGauge = new Map(opportunities.map((item) => [item.gauge, item]));
  return allocations.reduce((sum, allocation) => {
    const item = byGauge.get(allocation.gauge);
    return item ? sum + shareOfIncentive(item, allocation.votes) : sum;
  }, 0);
}

function shareOfIncentive(item: GaugeOpportunity, votes: number): number {
  const totalOnGauge = item.otherVotes + votes;
  if (totalOnGauge === 0) return 0;
  return (item.incentiveUsd * votes) / totalOnGauge;
}

function toCandidates(opportunities: GaugeOpportunity[], minOthers: number): Candidate[] {
  return opportunities
    .filter((item) => item.incentiveUsd > 0)
    .map((item) => ({
      gauge: item.gauge,
      incentive: item.incentiveUsd,
      others: Math.max(item.otherVotes, minOthers),
    }));
}

function wantedVotes(candidate: Candidate, price: number): number {
  const votes = Math.sqrt((candidate.incentive * candidate.others) / price) - candidate.others;
  return Math.max(0, votes);
}

function totalWantedVotes(candidates: Candidate[], price: number): number {
  return candidates.reduce((sum, candidate) => sum + wantedVotes(candidate, price), 0);
}

function votesAtPrice(candidates: Candidate[], price: number): VoteAllocation[] {
  return candidates
    .map((candidate) => ({ gauge: candidate.gauge, votes: wantedVotes(candidate, price) }))
    .filter((allocation) => allocation.votes > 0);
}

/** Searches, on a log scale, for the marginal return at which gauges want all our votes. */
function findClearingPrice(candidates: Candidate[], votingPower: number): number {
  let high = Math.max(...candidates.map((candidate) => candidate.incentive / candidate.others));
  let low = high;
  while (totalWantedVotes(candidates, low) < votingPower) low /= 2;

  for (let step = 0; step < PRICE_SEARCH_STEPS; step++) {
    const middle = Math.sqrt(low * high);
    if (totalWantedVotes(candidates, middle) > votingPower) low = middle;
    else high = middle;
  }
  return low;
}

function scaleToPower(allocations: VoteAllocation[], votingPower: number): VoteAllocation[] {
  const total = allocations.reduce((sum, allocation) => sum + allocation.votes, 0);
  return allocations.map((allocation) => ({
    gauge: allocation.gauge,
    votes: (allocation.votes * votingPower) / total,
  }));
}
