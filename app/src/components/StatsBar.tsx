import { useEffect, useState } from "react";
import type { Deployment } from "../config/deployment";
import { useVaultStats } from "../hooks/useVaultStats";
import { nextEpochStart } from "../lib/epoch";
import { formatCountdown, formatToken } from "../lib/format";

/** Protocol numbers across the top of the page. */
export function StatsBar({ deployment }: { deployment: Deployment }) {
  const stats = useVaultStats(deployment);
  const now = useNow();
  return (
    <section className="stats" aria-label="Lockless numbers">
      <Stat label="MEZO locked forever" value={amountOrDash(stats.lockedMezo)} />
      <Stat label="stMEZO staked" value={amountOrDash(stats.stakedStMezo)} />
      <Stat label="Master lock voting power" value={amountOrDash(stats.votingPower)} />
      <Stat label="Next epoch in" value={formatCountdown(nextEpochStart(now) - now)} />
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat">
      <span className="muted">{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function amountOrDash(amount: bigint | undefined): string {
  return amount === undefined ? "–" : formatToken(amount);
}

function useNow(): number {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  useEffect(() => {
    const timer = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 30_000);
    return () => clearInterval(timer);
  }, []);
  return now;
}
