import { compareExits } from "../lib/exitComparison";
import { formatToken } from "../lib/format";

/** Shows why converting beats selling a lock to the discount desk. */
export function ExitComparisonCard({ lockedMezo }: { lockedMezo: bigint }) {
  const exits = compareExits(lockedMezo);
  return (
    <div className="comparison">
      <div>
        <span className="muted">Discount desk pays</span>
        <strong>{formatToken(exits.deskMezo)} MEZO</strong>
      </div>
      <div>
        <span className="muted">Lockless gives</span>
        <strong>{formatToken(exits.locklessStMEZO)} stMEZO</strong>
      </div>
      <div className="comparison__gain">+{formatToken(exits.extraWithLockless)} more</div>
    </div>
  );
}
