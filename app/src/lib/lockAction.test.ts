import { describe, expect, it } from "vitest";
import { nextLockAction, type LockInfo } from "./lockAction";

const WEEK = 7 * 24 * 3600;
const EPOCH = 2_900 * WEEK;
const NOW = EPOCH + 2 * 24 * 3600;

const readyLock: LockInfo = {
  tokenId: 7n,
  amount: 500n * 10n ** 18n,
  end: BigInt(NOW + 52 * WEEK),
  isPermanent: false,
  isNormal: true,
  vestingEnd: 0n,
  voted: false,
  lastVoted: 0n,
  approvedToVault: true,
};

describe("nextLockAction", () => {
  it("converts a normal lock that the vault may move", () => {
    expect(nextLockAction(readyLock, NOW)).toBe("convert");
  });

  it("asks for approval first when the vault may not move the lock", () => {
    expect(nextLockAction({ ...readyLock, approvedToVault: false }, NOW)).toBe("approve");
  });

  it("lets the vault clear votes from an earlier epoch itself", () => {
    const lock = { ...readyLock, voted: true, lastVoted: BigInt(EPOCH - WEEK) };

    expect(nextLockAction(lock, NOW)).toBe("convert");
  });

  it("waits for the next epoch when the lock voted this epoch", () => {
    const lock = { ...readyLock, voted: true, lastVoted: BigInt(EPOCH + 3600 * 2) };

    expect(nextLockAction(lock, NOW)).toBe("wait-next-epoch");
  });

  it("asks the owner to unlock a permanent lock first", () => {
    expect(nextLockAction({ ...readyLock, isPermanent: true }, NOW)).toBe("unlock-permanent");
  });

  it("asks the owner to reset old votes before unlocking a permanent lock", () => {
    const lock = {
      ...readyLock,
      isPermanent: true,
      voted: true,
      lastVoted: BigInt(EPOCH - WEEK),
    };

    expect(nextLockAction(lock, NOW)).toBe("reset-votes");
  });

  it("does not support managed or grant locks", () => {
    expect(nextLockAction({ ...readyLock, isNormal: false }, NOW)).toBe("not-supported");
  });

  it("does not support grant locks that are still vesting", () => {
    expect(nextLockAction({ ...readyLock, vestingEnd: BigInt(NOW + WEEK) }, NOW)).toBe(
      "not-supported",
    );
  });
});
