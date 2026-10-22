import type { Address } from "viem";
import type { Deployment } from "../config/deployment";
import { useTransaction } from "../hooks/useTransaction";
import { nextLockAction, type LockInfo } from "../lib/lockAction";
import { lockRequest } from "../lib/lockRequest";
import { lockActionLabel } from "../lib/lockView";
import { formatToken } from "../lib/format";
import { ExitComparisonCard } from "./ExitComparisonCard";
import { TxStatus } from "./TxStatus";

interface LockCardProps {
  lock: LockInfo;
  deployment: Deployment;
  account: Address;
  now: number;
}

/** One veMEZO lock with the next step to turn it into stMEZO. */
export function LockCard({ lock, deployment, account, now }: LockCardProps) {
  const tx = useTransaction();
  const action = nextLockAction(lock, now);
  const request = lockRequest(action, lock.tokenId, deployment, account);

  return (
    <article className="lock">
      <header className="lock__header">
        <h3>veMEZO #{lock.tokenId.toString()}</h3>
        <span className="badge">{lock.isPermanent ? "Permanent" : `Unlocks ${unlockDate(lock.end)}`}</span>
      </header>
      <p className="lock__amount">{formatToken(lock.amount)} MEZO locked</p>
      <ExitComparisonCard lockedMezo={lock.amount} />
      <button
        className="button button--wide"
        disabled={!request || tx.busy}
        onClick={() => request && tx.send(lockActionLabel(action), request)}
      >
        {lockActionLabel(action)}
      </button>
      <TxStatus state={tx.state} />
    </article>
  );
}

function unlockDate(end: bigint): string {
  return new Date(Number(end) * 1000).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}
