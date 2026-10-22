import { describe, expect, it } from "vitest";
import { describePlan } from "../src/commands/describePlan";
import type { GaugeOpportunityWithRewards } from "../src/mezo/opportunities";
import { planVote } from "../src/votePlan";

const GAUGE = "0x00000000000000000000000000000000000000a1";

describe("describePlan", () => {
  it("lists the master lock, each backed gauge and the expected earnings", () => {
    const opportunities: GaugeOpportunityWithRewards[] = [
      { gauge: GAUGE, bribe: GAUGE, rewardTokens: [], incentiveUsd: 120, otherVotes: 0 },
    ];
    const text = describePlan({
      masterTokenId: 42n,
      votingPower: 1_500,
      opportunities,
      plan: planVote(opportunities, 1_500),
    });

    expect(text).toContain("Master lock #42");
    expect(text).toContain("1,500.00");
    expect(text).toContain(GAUGE);
    expect(text).toContain("100.0%");
    expect(text).toContain("$120.00");
  });

  it("says so when no gauge pays this epoch", () => {
    const text = describePlan({
      masterTokenId: 42n,
      votingPower: 1_500,
      opportunities: [],
      plan: planVote([], 1_500),
    });

    expect(text).toContain("No gauge pays incentives this epoch");
  });
});
