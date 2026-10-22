import { describe, expect, it } from "vitest";
import { decideVote, planRewardSteps } from "../src/decisions";
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

describe("planRewardSteps", () => {
  const none = { mezo: 0n, btc: 0n, musd: 0n, stMEZO: 0n };

  it("does nothing when the harvester holds nothing", () => {
    expect(planRewardSteps(none)).toEqual([]);
  });

  it("locks MEZO and then distributes the stMEZO it becomes", () => {
    expect(planRewardSteps({ ...none, mezo: 5n })).toEqual(["lockMezo", "distributeStMEZO"]);
  });

  it("swaps BTC and then distributes the MUSD it becomes", () => {
    expect(planRewardSteps({ ...none, btc: 5n })).toEqual(["swapBtcToMusd", "distributeMusd"]);
  });

  it("distributes MUSD and stMEZO already held", () => {
    expect(planRewardSteps({ ...none, musd: 1n, stMEZO: 1n })).toEqual([
      "distributeMusd",
      "distributeStMEZO",
    ]);
  });

  it("runs conversions before distributions", () => {
    expect(planRewardSteps({ mezo: 1n, btc: 1n, musd: 1n, stMEZO: 1n })).toEqual([
      "lockMezo",
      "swapBtcToMusd",
      "distributeMusd",
      "distributeStMEZO",
    ]);
  });
});
