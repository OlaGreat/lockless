import { describe, expect, it } from "vitest";
import {
  allocateVotes,
  expectedIncentives,
  type GaugeOpportunity,
  type VoteAllocation,
} from "../src/allocation";

const GAUGE_A = "0x000000000000000000000000000000000000000a";
const GAUGE_B = "0x000000000000000000000000000000000000000b";
const GAUGE_C = "0x000000000000000000000000000000000000000c";
const POWER = 1_000_000;

function opportunity(gauge: `0x${string}`, incentiveUsd: number, otherVotes: number): GaugeOpportunity {
  return { gauge, incentiveUsd, otherVotes };
}

function totalVotes(allocations: VoteAllocation[]): number {
  return allocations.reduce((sum, allocation) => sum + allocation.votes, 0);
}

function votesFor(allocations: VoteAllocation[], gauge: string): number {
  return allocations.find((allocation) => allocation.gauge === gauge)?.votes ?? 0;
}

function marginalReturn(item: GaugeOpportunity, votes: number): number {
  return (item.incentiveUsd * item.otherVotes) / (item.otherVotes + votes) ** 2;
}

describe("allocateVotes", () => {
  it("allocates nothing without voting power", () => {
    expect(allocateVotes([opportunity(GAUGE_A, 100, 1_000)], 0)).toEqual([]);
  });

  it("allocates nothing when no gauge pays incentives", () => {
    expect(allocateVotes([opportunity(GAUGE_A, 0, 1_000)], POWER)).toEqual([]);
  });

  it("puts all votes on the only paying gauge", () => {
    const allocations = allocateVotes(
      [opportunity(GAUGE_A, 100, 1_000), opportunity(GAUGE_B, 0, 1_000)],
      POWER,
    );

    expect(allocations).toHaveLength(1);
    expect(votesFor(allocations, GAUGE_A)).toBeCloseTo(POWER, 6);
  });

  it("splits evenly between identical gauges", () => {
    const allocations = allocateVotes(
      [opportunity(GAUGE_A, 100, 50_000), opportunity(GAUGE_B, 100, 50_000)],
      POWER,
    );

    expect(votesFor(allocations, GAUGE_A)).toBeCloseTo(POWER / 2, 3);
    expect(votesFor(allocations, GAUGE_B)).toBeCloseTo(POWER / 2, 3);
  });

  it("uses exactly the available voting power", () => {
    const allocations = allocateVotes(
      [
        opportunity(GAUGE_A, 500, 200_000),
        opportunity(GAUGE_B, 80, 10_000),
        opportunity(GAUGE_C, 300, 2_000_000),
      ],
      POWER,
    );

    expect(totalVotes(allocations)).toBeCloseTo(POWER, 3);
  });

  it("gives more votes to the gauge paying more per existing vote", () => {
    const allocations = allocateVotes(
      [opportunity(GAUGE_A, 400, 100_000), opportunity(GAUGE_B, 100, 100_000)],
      POWER,
    );

    expect(votesFor(allocations, GAUGE_A)).toBeGreaterThan(votesFor(allocations, GAUGE_B));
  });

  it("still votes for a paying gauge nobody has voted on yet", () => {
    const allocations = allocateVotes(
      [opportunity(GAUGE_A, 50, 0), opportunity(GAUGE_B, 1_000, 5_000_000)],
      POWER,
    );

    expect(votesFor(allocations, GAUGE_A)).toBeGreaterThan(0);
  });

  it("equalises the return of the last vote across the chosen gauges", () => {
    const items = [
      opportunity(GAUGE_A, 500, 200_000),
      opportunity(GAUGE_B, 120, 30_000),
      opportunity(GAUGE_C, 900, 1_500_000),
    ];
    const allocations = allocateVotes(items, POWER);

    const returns = allocations.map((allocation) => {
      const item = items.find((candidate) => candidate.gauge === allocation.gauge)!;
      return marginalReturn(item, allocation.votes);
    });
    expect(Math.max(...returns) / Math.min(...returns)).toBeLessThan(1.01);
  });

  it("earns more than splitting votes in proportion to incentives", () => {
    const items = [
      opportunity(GAUGE_A, 500, 4_000_000),
      opportunity(GAUGE_B, 120, 30_000),
      opportunity(GAUGE_C, 900, 1_500_000),
    ];
    const totalIncentive = items.reduce((sum, item) => sum + item.incentiveUsd, 0);
    const proportional = items.map((item) => ({
      gauge: item.gauge,
      votes: (POWER * item.incentiveUsd) / totalIncentive,
    }));

    const optimal = expectedIncentives(items, allocateVotes(items, POWER));

    expect(optimal).toBeGreaterThan(expectedIncentives(items, proportional));
  });

  it("earns at least as much as backing only the best single gauge", () => {
    const items = [
      opportunity(GAUGE_A, 500, 200_000),
      opportunity(GAUGE_B, 120, 30_000),
      opportunity(GAUGE_C, 900, 1_500_000),
    ];
    const bestSingle = Math.max(
      ...items.map((item) => expectedIncentives(items, [{ gauge: item.gauge, votes: POWER }])),
    );

    expect(expectedIncentives(items, allocateVotes(items, POWER))).toBeGreaterThanOrEqual(
      bestSingle,
    );
  });
});

describe("expectedIncentives", () => {
  it("pays each gauge's incentive in proportion to our share of its votes", () => {
    const items = [opportunity(GAUGE_A, 100, 3_000), opportunity(GAUGE_B, 40, 0)];
    const allocations = [
      { gauge: GAUGE_A, votes: 1_000 },
      { gauge: GAUGE_B, votes: 10 },
    ] satisfies VoteAllocation[];

    expect(expectedIncentives(items, allocations)).toBeCloseTo(25 + 40, 9);
  });

  it("ignores gauges we did not vote for", () => {
    expect(expectedIncentives([opportunity(GAUGE_A, 100, 3_000)], [])).toBe(0);
  });
});
