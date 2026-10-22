import { describe, expect, it } from "vitest";
import { lockActionLabel, toLockInfo } from "./lockView";

const VAULT = "0x9B137463d4E7986D7f535f9B79e28b4EF1938E9b";

describe("lockActionLabel", () => {
  it("names each step in plain words", () => {
    expect(lockActionLabel("convert")).toBe("Convert to stMEZO");
    expect(lockActionLabel("approve")).toBe("Allow Lockless to take this lock");
    expect(lockActionLabel("unlock-permanent")).toBe("Turn off permanent lock");
    expect(lockActionLabel("reset-votes")).toBe("Reset old votes");
    expect(lockActionLabel("wait-next-epoch")).toBe("Voted this week, try after Thursday");
    expect(lockActionLabel("not-supported")).toBe("This lock type cannot be converted");
  });
});

describe("toLockInfo", () => {
  const reads = {
    locked: { amount: 500n, end: 99n, isPermanent: true, boost: 0n },
    escrowType: 0,
    vestingEnd: 0n,
    voted: false,
    approved: VAULT,
    lastVoted: 12n,
  } as const;

  it("copies the lock's amount, end, permanence and vote history", () => {
    const info = toLockInfo(7n, reads, VAULT);

    expect(info).toMatchObject({ tokenId: 7n, amount: 500n, end: 99n, isPermanent: true });
    expect(info.lastVoted).toBe(12n);
  });

  it("treats escrow type 0 as a normal lock", () => {
    expect(toLockInfo(7n, reads, VAULT).isNormal).toBe(true);
    expect(toLockInfo(7n, { ...reads, escrowType: 2 }, VAULT).isNormal).toBe(false);
  });

  it("knows whether the vault is approved, regardless of letter case", () => {
    expect(toLockInfo(7n, { ...reads, approved: VAULT.toLowerCase() as `0x${string}` }, VAULT).approvedToVault).toBe(true);
    expect(toLockInfo(7n, { ...reads, approved: "0x0000000000000000000000000000000000000000" }, VAULT).approvedToVault).toBe(false);
  });
});
