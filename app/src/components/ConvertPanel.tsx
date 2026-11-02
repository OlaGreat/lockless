import type { Address } from "viem";
import type { Deployment } from "../config/deployment";
import { useUserLocks } from "../hooks/useUserLocks";
import { LockCard } from "./LockCard";

/** Lists the wallet's veMEZO locks so each can become liquid stMEZO. */
export function ConvertPanel({ deployment, account }: { deployment: Deployment; account: Address }) {
  const locks = useUserLocks(deployment, account);
  const now = Math.floor(Date.now() / 1000);
  return (
    <div className="panel">
      <p className="panel__intro">
        Already locked MEZO for years? Convert the lock into stMEZO one for one, instead of selling it to the
        discount desk at 60%. Converting pays you the incentives the lock has earned on the gauges it votes for
        and adds its pending rebase as stMEZO. If it earned incentives on gauges it no longer votes for, claim
        those on Mezo first.
      </p>
      {locks.length === 0 ? (
        <p className="muted">This wallet holds no veMEZO locks.</p>
      ) : (
        <div className="locks">
          {locks.map((lock) => (
            <LockCard key={lock.tokenId.toString()} lock={lock} deployment={deployment} account={account} now={now} />
          ))}
        </div>
      )}
    </div>
  );
}
