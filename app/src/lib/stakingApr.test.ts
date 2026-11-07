import { parseEther } from "viem";
import { describe, expect, it } from "vitest";
import { formatApr, stakingAprBps } from "./stakingApr";

const NOW = 1_000_000n;
const LIVE = NOW + 1_000n;
const ENDED = NOW - 1n;
const NONE = { ratePerSecond: 0n, periodFinish: 0n };
/** 1e12 wei a second is 31.536 tokens a year. */
const SMALL_RATE = 1_000_000_000_000n;
/** Worth 315.36 MUSD at 0.1 MUSD per MEZO, so 31.536 MUSD a year is 10%. */
const STAKED = parseEther("3153.6");

function stream(ratePerSecond: bigint, periodFinish: bigint) {
  return { ratePerSecond, periodFinish };
}

describe("stakingAprBps", () => {
  it("annualises an MUSD stream against the MUSD value of the stake", () => {
    const apr = stakingAprBps({
      musd: stream(SMALL_RATE, LIVE),
      stMezo: NONE,
      totalStaked: STAKED,
      mezoPriceInMusd: parseEther("0.1"),
      now: NOW,
    });

    expect(apr).toBe(1_000n);
  });

  it("values the stMEZO stream at the MEZO price", () => {
    const apr = stakingAprBps({
      musd: NONE,
      stMezo: stream(SMALL_RATE * 5n, LIVE),
      totalStaked: STAKED,
      mezoPriceInMusd: parseEther("0.1"),
      now: NOW,
    });

    expect(apr).toBe(500n);
  });

  it("adds both streams together", () => {
    const apr = stakingAprBps({
      musd: stream(SMALL_RATE, LIVE),
      stMezo: stream(SMALL_RATE * 5n, LIVE),
      totalStaked: STAKED,
      mezoPriceInMusd: parseEther("0.1"),
      now: NOW,
    });

    expect(apr).toBe(1_500n);
  });

  it("ignores a stream that has finished", () => {
    const apr = stakingAprBps({
      musd: stream(SMALL_RATE, ENDED),
      stMezo: stream(SMALL_RATE * 5n, LIVE),
      totalStaked: STAKED,
      mezoPriceInMusd: parseEther("0.1"),
      now: NOW,
    });

    expect(apr).toBe(500n);
  });

  it("has no APR while nobody is staked", () => {
    const apr = stakingAprBps({
      musd: stream(SMALL_RATE, LIVE),
      stMezo: NONE,
      totalStaked: 0n,
      mezoPriceInMusd: parseEther("0.1"),
      now: NOW,
    });

    expect(apr).toBeUndefined();
  });

  it("has no APR without a MEZO price", () => {
    const apr = stakingAprBps({
      musd: stream(SMALL_RATE, LIVE),
      stMezo: NONE,
      totalStaked: STAKED,
      mezoPriceInMusd: 0n,
      now: NOW,
    });

    expect(apr).toBeUndefined();
  });
});

describe("formatApr", () => {
  it("shows one decimal", () => {
    expect(formatApr(1_234n)).toBe("12.3%");
  });

  it("shows a dash when there is no APR", () => {
    expect(formatApr(undefined)).toBe("–");
  });

  it("caps very large testnet figures", () => {
    expect(formatApr(5_000_000n)).toBe("Over 10,000%");
  });
});
