import { parseEther } from "viem";
import { describe, expect, it } from "vitest";
import { describePriceVsPar, minimumReceived, sellRoute, swapDeadline } from "./sellQuote";

const ST_MEZO = "0x0000000000000000000000000000000000000001";
const MEZO = "0x0000000000000000000000000000000000000002";
const FACTORY = "0x0000000000000000000000000000000000000003";

describe("minimumReceived", () => {
  it("accepts 1% less than the quote by default", () => {
    expect(minimumReceived(10_000n)).toBe(9_900n);
  });

  it("uses a custom slippage", () => {
    expect(minimumReceived(10_000n, 50n)).toBe(9_950n);
  });
});

describe("describePriceVsPar", () => {
  it("says how far below one MEZO per stMEZO the pool pays", () => {
    expect(describePriceVsPar(parseEther("100"), parseEther("97.6"))).toBe("2.4% below 1:1");
  });

  it("says when the pool pays more than one MEZO per stMEZO", () => {
    expect(describePriceVsPar(parseEther("100"), parseEther("100.3"))).toBe("0.3% above 1:1");
  });

  it("says when the pool pays exactly one for one", () => {
    expect(describePriceVsPar(parseEther("5"), parseEther("5"))).toBe("at 1:1");
  });
});

describe("sellRoute", () => {
  it("swaps stMEZO for MEZO through the volatile pool", () => {
    expect(sellRoute(ST_MEZO, MEZO, FACTORY)).toEqual([
      { from: ST_MEZO, to: MEZO, stable: false, factory: FACTORY },
    ]);
  });
});

describe("swapDeadline", () => {
  it("gives the swap twenty minutes", () => {
    expect(swapDeadline(1_000)).toBe(2_200n);
  });
});
