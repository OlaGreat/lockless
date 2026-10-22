/** What the mainnet veMEZO discount desk currently pays per locked MEZO: 60%. */
export const DESK_PAYOUT_BPS = 6_000n;

const BPS = 10_000n;

export interface ExitComparison {
  deskMezo: bigint;
  locklessStMEZO: bigint;
  extraWithLockless: bigint;
}

/** Compares selling a lock to the discount desk with converting it to stMEZO. */
export function compareExits(lockedMezo: bigint, deskPayoutBps = DESK_PAYOUT_BPS): ExitComparison {
  const deskMezo = (lockedMezo * deskPayoutBps) / BPS;
  return { deskMezo, locklessStMEZO: lockedMezo, extraWithLockless: lockedMezo - deskMezo };
}
