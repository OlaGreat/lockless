import { describe, expect, it } from "vitest";
import { parseEther } from "viem";
import { readOpportunities } from "../src/mezo/opportunities";
import { createPriceBook } from "../src/valuation";
import { FakeReader } from "./support/fakeReader";

const VOTER = "0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1";
const MUSD = "0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503";
const BTC = "0x7b7C000000000000000000000000000000000000";
const GAUGE_LIVE = "0x00000000000000000000000000000000000000a1";
const GAUGE_DEAD = "0x00000000000000000000000000000000000000a2";
const GAUGE_NEW = "0x00000000000000000000000000000000000000a3";
const BRIBE_LIVE = "0x00000000000000000000000000000000000000b1";
const BRIBE_DEAD = "0x00000000000000000000000000000000000000b2";
const BRIBE_NEW = "0x00000000000000000000000000000000000000b3";
const MASTER_TOKEN_ID = 77n;
const EPOCH_START = 1_754_524_800n;

const prices = createPriceBook([
  { token: MUSD, usd: 1, decimals: 18 },
  { token: BTC, usd: 100_000, decimals: 18 },
]);

function fakeChain(): FakeReader {
  return new FakeReader()
    .on(VOTER, "length", [], 3n)
    .on(VOTER, "gauges", [0n], GAUGE_LIVE)
    .on(VOTER, "gauges", [1n], GAUGE_DEAD)
    .on(VOTER, "gauges", [2n], GAUGE_NEW)
    .on(VOTER, "isAlive", [GAUGE_LIVE], true)
    .on(VOTER, "isAlive", [GAUGE_DEAD], false)
    .on(VOTER, "isAlive", [GAUGE_NEW], true)
    .on(VOTER, "gaugeToBribe", [GAUGE_LIVE], BRIBE_LIVE)
    .on(VOTER, "gaugeToBribe", [GAUGE_DEAD], BRIBE_DEAD)
    .on(VOTER, "gaugeToBribe", [GAUGE_NEW], BRIBE_NEW)
    .on(VOTER, "weights", [GAUGE_LIVE], parseEther("100"))
    .on(VOTER, "weights", [GAUGE_DEAD], parseEther("5"))
    .on(VOTER, "weights", [GAUGE_NEW], 0n)
    .on(VOTER, "votes", [MASTER_TOKEN_ID, GAUGE_LIVE], parseEther("20"))
    .on(VOTER, "votes", [MASTER_TOKEN_ID, GAUGE_NEW], 0n)
    .on(BRIBE_LIVE, "rewardsListLength", [], 1n)
    .on(BRIBE_LIVE, "rewards", [0n], MUSD)
    .on(BRIBE_NEW, "rewardsListLength", [], 2n)
    .on(BRIBE_NEW, "rewards", [0n], BTC)
    .on(BRIBE_NEW, "rewards", [1n], MUSD)
    .on(BRIBE_LIVE, "tokenRewardsPerEpoch", [MUSD, EPOCH_START], parseEther("50"))
    .on(BRIBE_NEW, "tokenRewardsPerEpoch", [BTC, EPOCH_START], parseEther("0.001"))
    .on(BRIBE_NEW, "tokenRewardsPerEpoch", [MUSD, EPOCH_START], 0n);
}

const query = {
  voter: VOTER,
  masterTokenId: MASTER_TOKEN_ID,
  epochStart: EPOCH_START,
  prices,
} as const;

describe("readOpportunities", () => {
  it("skips gauges that are no longer alive", async () => {
    const opportunities = await readOpportunities(fakeChain(), query);

    expect(opportunities.map((item) => item.gauge)).toEqual([GAUGE_LIVE, GAUGE_NEW]);
  });

  it("values each gauge's incentives for the epoch in USD", async () => {
    const opportunities = await readOpportunities(fakeChain(), query);

    expect(opportunities[0]?.incentiveUsd).toBe(50);
    expect(opportunities[1]?.incentiveUsd).toBeCloseTo(100, 9);
  });

  it("counts only other voters' votes, not the vault's own", async () => {
    const opportunities = await readOpportunities(fakeChain(), query);

    expect(opportunities[0]?.otherVotes).toBe(80);
    expect(opportunities[1]?.otherVotes).toBe(0);
  });

  it("keeps the incentive contract and its tokens for harvesting", async () => {
    const opportunities = await readOpportunities(fakeChain(), query);

    expect(opportunities[1]?.bribe).toBe(BRIBE_NEW);
    expect(opportunities[1]?.rewardTokens).toEqual([BTC, MUSD]);
  });
});
