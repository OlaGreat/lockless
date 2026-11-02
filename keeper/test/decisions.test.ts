import { describe, expect, it } from "vitest";
import { btcSwapMinimum, decideVote, planConversions, planDistributions } from "../src/decisions";
import { EPOCH_SECONDS } from "../src/epoch";

const EPOCH = 2_900 * EPOCH_SECONDS;
const MIDDLE = EPOCH + 3 * 24 * 3_600;

describe("decideVote", () => {
  it("waits while the voting window is closed", () => {
    const decision = decideVote({ now: EPOCH + 60, lastVoted: 0, gaugeCount: 3 });

    expect(decision).toEqual({ vote: false, reason: "voting window is closed" });
  });

  it("waits when the vault already voted this epoch", () => {
    const decision = decideVote({ now: MIDDLE, lastVoted: EPOCH + 7_200, gaugeCount: 3 });

    expect(decision).toEqual({ vote: false, reason: "already voted this epoch" });
  });

  it("waits when no gauge pays incentives", () => {
    const decision = decideVote({ now: MIDDLE, lastVoted: 0, gaugeCount: 0 });

    expect(decision).toEqual({ vote: false, reason: "no gauge pays incentives this epoch" });
  });

  it("votes when the window is open, the vault has not voted and a gauge pays", () => {
    const decision = decideVote({ now: MIDDLE, lastVoted: EPOCH - 100, gaugeCount: 2 });

    expect(decision).toEqual({ vote: true });
  });
});

describe("planConversions", () => {
  const none = { mezo: 0n, btc: 0n, musd: 0n, stMEZO: 0n };

  it("does nothing when the harvester holds nothing to convert", () => {
    expect(planConversions({ ...none, musd: 5n, stMEZO: 5n })).toEqual([]);
  });

  it("locks MEZO into stMEZO", () => {
    expect(planConversions({ ...none, mezo: 5n })).toEqual(["lockMezo"]);
  });

  it("swaps BTC into MUSD", () => {
    expect(planConversions({ ...none, btc: 5n })).toEqual(["swapBtcToMusd"]);
  });

  it("locks MEZO before swapping BTC", () => {
    expect(planConversions({ ...none, mezo: 1n, btc: 1n })).toEqual(["lockMezo", "swapBtcToMusd"]);
  });
});

describe("planDistributions", () => {
  const none = { mezo: 0n, btc: 0n, musd: 0n, stMEZO: 0n };

  it("does nothing when there is no MUSD or stMEZO", () => {
    expect(planDistributions({ ...none, mezo: 5n, btc: 5n })).toEqual([]);
  });

  it("streams MUSD and stMEZO the harvester holds", () => {
    expect(planDistributions({ ...none, musd: 1n, stMEZO: 1n })).toEqual([
      "distributeMusd",
      "distributeStMEZO",
    ]);
  });
});

describe("btcSwapMinimum", () => {
  it("accepts 1% less than the router quotes", () => {
    expect(btcSwapMinimum(10_000n, 9_000n)).toEqual({ swap: true, minOut: 9_900n });
  });

  it("never asks for less than the oracle floor", () => {
    expect(btcSwapMinimum(10_000n, 9_950n)).toEqual({ swap: true, minOut: 9_950n });
  });

  it("skips the swap when the pool quotes below the oracle floor", () => {
    expect(btcSwapMinimum(9_000n, 9_700n)).toEqual({
      swap: false,
      reason: "the pool quotes more than 3% below Mezo's BTC price",
    });
  });
});
