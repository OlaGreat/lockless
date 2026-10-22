import { describe, expect, it } from "vitest";
import { DEFAULT_RPC_URL, parseConfig } from "../src/config";

const deployment = {
  chainId: 31611,
  startBlock: 16299753,
  vault: "0x9B137463d4E7986D7f535f9B79e28b4EF1938E9b",
  stMEZO: "0x8D51b916fcd05492Ae152fF28B826885A665106c",
  staking: "0x2387b3383E89c164781d173B7Aa14d9c46eD2642",
  harvester: "0x22bc2df58D96CBc5f2599f2C25D1E565974749EE",
  veMEZO: "0xaCE816CA2bcc9b12C59799dcC5A959Fb9b98111b",
  boostVoter: "0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1",
  rebaseDistributor: "0x2962E8817ae716019F759d098e2caE658bDcAd04",
  router: "0x9a1ff7FE3a0F69959A3fBa1F1e5ee18e1A9CD7E9",
  musd: "0x118917a40FAF1CD7a13dB0Ef56C86De7973Ac503",
  mezo: "0x7B7c000000000000000000000000000000000001",
};
const KEY = `0x${"ab".repeat(32)}`;

describe("parseConfig", () => {
  it("reads contract addresses from the deployment file", () => {
    const config = parseConfig(deployment, {});

    expect(config.chainId).toBe(31611);
    expect(config.contracts.vault).toBe(deployment.vault);
    expect(config.contracts.boostVoter).toBe(deployment.boostVoter);
  });

  it("adds Mezo testnet's BTC token and price feed", () => {
    const config = parseConfig(deployment, {});

    expect(config.contracts.btc).toBe("0x7b7C000000000000000000000000000000000000");
    expect(config.contracts.btcPriceFeed).toBe("0x86bCF0841622a5dAC14A313a15f96A95421b9366");
  });

  it("uses the public Mezo testnet RPC unless told otherwise", () => {
    expect(parseConfig(deployment, {}).rpcUrl).toBe(DEFAULT_RPC_URL);
    expect(parseConfig(deployment, { MEZO_RPC_URL: "http://localhost:8545" }).rpcUrl).toBe(
      "http://localhost:8545",
    );
  });

  it("reads an optional keeper private key", () => {
    expect(parseConfig(deployment, {}).privateKey).toBeUndefined();
    expect(parseConfig(deployment, { PRIVATE_KEY: KEY }).privateKey).toBe(KEY);
  });

  it("reads the MEZO price used to value MEZO incentives", () => {
    expect(parseConfig(deployment, {}).mezoUsdPrice).toBe(0);
    expect(parseConfig(deployment, { MEZO_USD_PRICE: "0.25" }).mezoUsdPrice).toBe(0.25);
  });

  it("rejects a deployment with a missing or invalid address", () => {
    expect(() => parseConfig({ ...deployment, vault: "not-an-address" }, {})).toThrow(/vault/);
  });

  it("rejects a malformed private key", () => {
    expect(() => parseConfig(deployment, { PRIVATE_KEY: "0x1234" })).toThrow(/PRIVATE_KEY/);
  });

  it("rejects a chain it has no settings for", () => {
    expect(() => parseConfig({ ...deployment, chainId: 1 }, {})).toThrow(/chain 1/);
  });
});
