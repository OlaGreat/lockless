import type { Address } from "viem";
import type { LockAction, LockInfo } from "./lockAction";

const NORMAL_ESCROW = 0;

const LABELS: Record<LockAction, string> = {
  convert: "Convert to stMEZO",
  approve: "Allow Lockless to take this lock",
  "unlock-permanent": "Turn off permanent lock",
  "reset-votes": "Reset old votes",
  "wait-next-epoch": "Voted this week, try after Thursday",
  "not-supported": "This lock type cannot be converted",
};

/** The button text for a lock's next step. */
export function lockActionLabel(action: LockAction): string {
  return LABELS[action];
}

/** Raw values read from veMEZO and the boost voter for one lock. */
export interface LockReads {
  locked: { amount: bigint; end: bigint; isPermanent: boolean; boost: bigint };
  escrowType: number;
  vestingEnd: bigint;
  voted: boolean;
  approved: Address;
  lastVoted: bigint;
}

export function toLockInfo(tokenId: bigint, reads: LockReads, vault: Address): LockInfo {
  return {
    tokenId,
    amount: reads.locked.amount,
    end: reads.locked.end,
    isPermanent: reads.locked.isPermanent,
    isNormal: reads.escrowType === NORMAL_ESCROW,
    vestingEnd: reads.vestingEnd,
    voted: reads.voted,
    lastVoted: reads.lastVoted,
    approvedToVault: reads.approved.toLowerCase() === vault.toLowerCase(),
  };
}
