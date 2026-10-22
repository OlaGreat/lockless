import { epochStart } from "./epoch";

/** What a user holds in one veMEZO lock, as far as converting it is concerned. */
export interface LockInfo {
  tokenId: bigint;
  amount: bigint;
  end: bigint;
  isPermanent: boolean;
  /** Only normal locks can merge. Managed and locked-in-managed ones cannot. */
  isNormal: boolean;
  vestingEnd: bigint;
  /** veMEZO's voted flag. It stays set until the votes are reset. */
  voted: boolean;
  lastVoted: bigint;
  approvedToVault: boolean;
}

export type LockAction =
  | "convert"
  | "approve"
  | "unlock-permanent"
  | "reset-votes"
  | "wait-next-epoch"
  | "not-supported";

/** The next step a user takes to turn this lock into stMEZO. */
export function nextLockAction(lock: LockInfo, now: number): LockAction {
  if (!canMerge(lock, now)) return "not-supported";
  if (votedThisEpoch(lock, now)) return "wait-next-epoch";
  if (lock.isPermanent) return lock.voted ? "reset-votes" : "unlock-permanent";
  return lock.approvedToVault ? "convert" : "approve";
}

function canMerge(lock: LockInfo, now: number): boolean {
  return lock.isNormal && lock.vestingEnd <= BigInt(now);
}

function votedThisEpoch(lock: LockInfo, now: number): boolean {
  return lock.lastVoted >= BigInt(epochStart(now));
}
