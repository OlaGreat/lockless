import { describe, expect, it } from "vitest";
import { formatCountdown, formatToken, shortAddress } from "./format";

describe("formatToken", () => {
  it("shows two decimals with thousands separators", () => {
    expect(formatToken(1_234_567_890_000_000_000_000n)).toBe("1,234.57");
  });

  it("shows zero plainly", () => {
    expect(formatToken(0n)).toBe("0.00");
  });

  it("respects other decimal counts", () => {
    expect(formatToken(2_500_000n, 6)).toBe("2.50");
  });
});

describe("formatCountdown", () => {
  it("shows days, hours and minutes", () => {
    expect(formatCountdown(2 * 86_400 + 4 * 3_600 + 10 * 60 + 59)).toBe("2d 4h 10m");
  });

  it("drops empty leading units", () => {
    expect(formatCountdown(3 * 3_600 + 5 * 60)).toBe("3h 5m");
  });

  it("never goes below zero", () => {
    expect(formatCountdown(-30)).toBe("0m");
  });
});

describe("shortAddress", () => {
  it("keeps the start and end of an address", () => {
    expect(shortAddress("0xFE2d98d719e5d23A04307c4C8d8Cc814c5fEF958")).toBe("0xFE2d…F958");
  });
});
