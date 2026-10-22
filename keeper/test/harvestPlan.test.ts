import { describe, expect, it } from "vitest";
import { parseEther } from "viem";
import { readEarnedIncentives, toHarvestArguments } from "../src/mezo/harvestPlan";
import { FakeReader } from "./support/fakeReader";

const MUSD = "0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503";
const BTC = "0x7b7C000000000000000000000000000000000000";
const BRIBE_A = "0x00000000000000000000000000000000000000b1";
const BRIBE_B = "0x00000000000000000000000000000000000000b2";
const MASTER_TOKEN_ID = 77n;

describe("toHarvestArguments", () => {
  it("groups earned tokens by incentive contract", () => {
    const result = toHarvestArguments([
      { bribe: BRIBE_A, token: MUSD, amount: 5n },
      { bribe: BRIBE_B, token: BTC, amount: 1n },
      { bribe: BRIBE_A, token: BTC, amount: 2n },
    ]);

    expect(result.bribes).toEqual([BRIBE_A, BRIBE_B]);
    expect(result.tokens).toEqual([[MUSD, BTC], [BTC]]);
  });

  it("returns empty arrays when nothing was earned", () => {
    expect(toHarvestArguments([])).toEqual({ bribes: [], tokens: [] });
  });
});

describe("readEarnedIncentives", () => {
  it("keeps only the tokens the master lock has earned", async () => {
    const reader = new FakeReader()
      .on(BRIBE_A, "earned", [MUSD, MASTER_TOKEN_ID], parseEther("12"))
      .on(BRIBE_A, "earned", [BTC, MASTER_TOKEN_ID], 0n)
      .on(BRIBE_B, "earned", [MUSD, MASTER_TOKEN_ID], 0n);

    const earned = await readEarnedIncentives(reader, MASTER_TOKEN_ID, [
      { bribe: BRIBE_A, rewardTokens: [MUSD, BTC] },
      { bribe: BRIBE_B, rewardTokens: [MUSD] },
    ]);

    expect(earned).toEqual([{ bribe: BRIBE_A, token: MUSD, amount: parseEther("12") }]);
  });
});
