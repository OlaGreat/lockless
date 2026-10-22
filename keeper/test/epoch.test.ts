import { describe, expect, it } from "vitest";
import { EPOCH_SECONDS, epochStart, isVotingOpen, nextEpochStart } from "../src/epoch";

const HOUR = 3_600;
const THURSDAY_MIDNIGHT = 2_900 * EPOCH_SECONDS;

describe("epochStart", () => {
  it("returns the timestamp itself on an epoch boundary", () => {
    expect(epochStart(THURSDAY_MIDNIGHT)).toBe(THURSDAY_MIDNIGHT);
  });

  it("rounds down to the Thursday the epoch began", () => {
    expect(epochStart(THURSDAY_MIDNIGHT + 3 * 24 * HOUR)).toBe(THURSDAY_MIDNIGHT);
  });
});

describe("nextEpochStart", () => {
  it("returns the following Thursday", () => {
    expect(nextEpochStart(THURSDAY_MIDNIGHT + HOUR)).toBe(THURSDAY_MIDNIGHT + EPOCH_SECONDS);
  });
});

describe("isVotingOpen", () => {
  it("is closed during the first hour of an epoch", () => {
    expect(isVotingOpen(THURSDAY_MIDNIGHT + HOUR)).toBe(false);
  });

  it("opens right after the first hour", () => {
    expect(isVotingOpen(THURSDAY_MIDNIGHT + HOUR + 1)).toBe(true);
  });

  it("is still open exactly one hour before the next epoch", () => {
    expect(isVotingOpen(THURSDAY_MIDNIGHT + EPOCH_SECONDS - HOUR)).toBe(true);
  });

  it("is closed during the last hour of an epoch", () => {
    expect(isVotingOpen(THURSDAY_MIDNIGHT + EPOCH_SECONDS - HOUR + 1)).toBe(false);
  });
});
