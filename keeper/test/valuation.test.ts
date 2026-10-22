import { describe, expect, it } from "vitest";
import { createPriceBook, valueInUsd } from "../src/valuation";

const MUSD = "0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503";
const BTC = "0x7b7C000000000000000000000000000000000000";
const UNKNOWN = "0x00000000000000000000000000000000000000ff";

const prices = createPriceBook([
  { token: MUSD, usd: 1, decimals: 18 },
  { token: BTC, usd: 100_000, decimals: 18 },
]);

describe("valueInUsd", () => {
  it("values MUSD at one dollar per token", () => {
    expect(valueInUsd([{ token: MUSD, amount: 250n * 10n ** 18n }], prices)).toBe(250);
  });

  it("adds up several tokens", () => {
    const amounts = [
      { token: MUSD, amount: 50n * 10n ** 18n },
      { token: BTC, amount: 10n ** 15n },
    ] as const;

    expect(valueInUsd([...amounts], prices)).toBeCloseTo(150, 9);
  });

  it("counts tokens without a known price as zero", () => {
    expect(valueInUsd([{ token: UNKNOWN, amount: 10n ** 30n }], prices)).toBe(0);
  });

  it("matches token addresses regardless of letter case", () => {
    const lowercase = MUSD.toLowerCase() as `0x${string}`;

    expect(valueInUsd([{ token: lowercase, amount: 10n ** 18n }], prices)).toBe(1);
  });

  it("respects token decimals", () => {
    const sixDecimals = createPriceBook([{ token: UNKNOWN, usd: 1, decimals: 6 }]);

    expect(valueInUsd([{ token: UNKNOWN, amount: 2_500_000n }], sixDecimals)).toBe(2.5);
  });
});
