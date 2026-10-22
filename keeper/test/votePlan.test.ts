import { describe, expect, it } from "vitest";
import type { Address, GaugeOpportunity } from "../src/allocation";
import { planVote, toVoteArguments, WEIGHT_SCALE } from "../src/votePlan";

function gaugeAddress(index: number): Address {
  return `0x${index.toString(16).padStart(40, "0")}`;
}

function opportunity(index: number, incentiveUsd: number, otherVotes: number): GaugeOpportunity {
  return { gauge: gaugeAddress(index), incentiveUsd, otherVotes };
}

describe("toVoteArguments", () => {
  it("returns parallel gauge and weight arrays ordered by votes", () => {
    const result = toVoteArguments([
      { gauge: gaugeAddress(1), votes: 25 },
      { gauge: gaugeAddress(2), votes: 75 },
    ]);

    expect(result.gauges).toEqual([gaugeAddress(2), gaugeAddress(1)]);
    expect(result.weights).toEqual([(WEIGHT_SCALE * 3n) / 4n, WEIGHT_SCALE / 4n]);
  });

  it("never sends a zero weight", () => {
    const result = toVoteArguments([
      { gauge: gaugeAddress(1), votes: 1e-12 },
      { gauge: gaugeAddress(2), votes: 1 },
    ]);

    expect(result.weights.every((weight) => weight >= 1n)).toBe(true);
  });

  it("returns empty arrays for no allocations", () => {
    expect(toVoteArguments([])).toEqual({ gauges: [], weights: [] });
  });
});

describe("planVote", () => {
  it("keeps at most the allowed number of gauges", () => {
    const opportunities = Array.from({ length: 10 }, (_, i) => opportunity(i + 1, 100, 1_000));

    const plan = planVote(opportunities, 1_000_000, 4);

    expect(plan.allocations).toHaveLength(4);
    expect(plan.gauges).toHaveLength(4);
  });

  it("re-spreads all voting power over the kept gauges", () => {
    const opportunities = Array.from({ length: 10 }, (_, i) => opportunity(i + 1, 100 + i, 1_000));

    const plan = planVote(opportunities, 1_000_000, 4);

    const total = plan.allocations.reduce((sum, allocation) => sum + allocation.votes, 0);
    expect(total).toBeCloseTo(1_000_000, 3);
  });

  it("keeps the gauges that deserve the most votes", () => {
    const opportunities = [
      opportunity(1, 10, 1_000_000),
      opportunity(2, 500, 1_000),
      opportunity(3, 400, 1_000),
    ];

    const plan = planVote(opportunities, 1_000_000, 2);

    expect(plan.gauges.sort()).toEqual([gaugeAddress(2), gaugeAddress(3)].sort());
  });

  it("reports the incentives the plan expects to earn", () => {
    const plan = planVote([opportunity(1, 100, 0)], 1_000, 30);

    expect(plan.expectedIncentivesUsd).toBeCloseTo(100, 6);
  });

  it("returns an empty plan when nothing pays", () => {
    const plan = planVote([opportunity(1, 0, 1_000)], 1_000, 30);

    expect(plan.gauges).toEqual([]);
    expect(plan.expectedIncentivesUsd).toBe(0);
  });
});
