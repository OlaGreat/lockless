import { describe, expect, it } from "vitest";
import { amountError, parseAmount } from "./amount";

describe("parseAmount", () => {
  it("reads whole and decimal amounts", () => {
    expect(parseAmount("12")).toBe(12n * 10n ** 18n);
    expect(parseAmount("0.5")).toBe(5n * 10n ** 17n);
  });

  it("ignores surrounding spaces", () => {
    expect(parseAmount(" 3 ")).toBe(3n * 10n ** 18n);
  });

  it("returns null for anything that is not a number", () => {
    expect(parseAmount("")).toBeNull();
    expect(parseAmount("abc")).toBeNull();
    expect(parseAmount("-1")).toBeNull();
  });
});

describe("amountError", () => {
  const balance = 10n * 10n ** 18n;

  it("accepts an amount within the balance", () => {
    expect(amountError("4", balance)).toBeNull();
  });

  it("explains an unreadable amount", () => {
    expect(amountError("x", balance)).toBe("Enter a number");
  });

  it("rejects zero", () => {
    expect(amountError("0", balance)).toBe("Enter an amount above zero");
  });

  it("rejects more than the balance", () => {
    expect(amountError("11", balance)).toBe("That is more than your balance");
  });
});
