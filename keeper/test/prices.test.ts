import { describe, expect, it } from "vitest";
import { parseEther } from "viem";
import { readPriceBook } from "../src/mezo/prices";
import { valueInUsd } from "../src/valuation";
import { FakeReader } from "./support/fakeReader";

const contracts = {
  musd: "0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503",
  mezo: "0x7B7c000000000000000000000000000000000001",
  btc: "0x7b7C000000000000000000000000000000000000",
  btcPriceFeed: "0x86bCF0841622a5dAC14A313a15f96A95421b9366",
} as const;

describe("readPriceBook", () => {
  const reader = new FakeReader().on(contracts.btcPriceFeed, "fetchPrice", [], parseEther("81816.5"));

  it("prices BTC from Mezo's on-chain price feed", async () => {
    const prices = await readPriceBook(reader, contracts, 0.2);

    expect(valueInUsd([{ token: contracts.btc, amount: parseEther("2") }], prices)).toBe(163_633);
  });

  it("prices MUSD at one dollar", async () => {
    const prices = await readPriceBook(reader, contracts, 0.2);

    expect(valueInUsd([{ token: contracts.musd, amount: parseEther("7") }], prices)).toBe(7);
  });

  it("prices MEZO at the configured price", async () => {
    const prices = await readPriceBook(reader, contracts, 0.2);

    expect(valueInUsd([{ token: contracts.mezo, amount: parseEther("10") }], prices)).toBeCloseTo(2, 9);
  });
});
