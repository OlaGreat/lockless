import { describe, expect, it } from "vitest";
import { compareExits, DESK_PAYOUT_BPS } from "./exitComparison";

const MEZO = 10n ** 18n;

describe("compareExits", () => {
  it("uses the discount desk's current 60% payout by default", () => {
    expect(DESK_PAYOUT_BPS).toBe(6_000n);
  });

  it("compares the desk's payout with Lockless's one-for-one stMEZO", () => {
    expect(compareExits(1_000n * MEZO)).toEqual({
      deskMezo: 600n * MEZO,
      locklessStMEZO: 1_000n * MEZO,
      extraWithLockless: 400n * MEZO,
    });
  });

  it("accepts a different desk payout", () => {
    expect(compareExits(1_000n * MEZO, 5_000n).deskMezo).toBe(500n * MEZO);
  });
});
