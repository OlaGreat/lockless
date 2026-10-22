import type { GaugeOpportunityWithRewards } from "../mezo/opportunities";
import type { VotePlan } from "../votePlan";

export interface VotePlanReport {
  masterTokenId: bigint;
  votingPower: number;
  opportunities: GaugeOpportunityWithRewards[];
  plan: VotePlan;
}

const usd = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });
const amount = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** Renders a vote plan as plain text for the terminal. */
export function describePlan(report: VotePlanReport): string {
  const header = `Master lock #${report.masterTokenId} with ${amount.format(report.votingPower)} voting power`;
  if (report.plan.allocations.length === 0) {
    return `${header}\nNo gauge pays incentives this epoch, so there is nothing to vote for.`;
  }
  return [header, ...gaugeLines(report), `Expected incentives: ${usd.format(report.plan.expectedIncentivesUsd)}`].join("\n");
}

function gaugeLines(report: VotePlanReport): string[] {
  const byGauge = new Map(report.opportunities.map((item) => [item.gauge, item]));
  return report.plan.allocations.map((allocation) => {
    const item = byGauge.get(allocation.gauge);
    const share = ((allocation.votes / report.votingPower) * 100).toFixed(1);
    const incentive = usd.format(item?.incentiveUsd ?? 0);
    return `  ${allocation.gauge}  ${share}% of votes  pays ${incentive}  others hold ${amount.format(item?.otherVotes ?? 0)}`;
  });
}
