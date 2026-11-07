/** A reward stream as StMEZOStaking stores it. */
export interface Stream {
  ratePerSecond: bigint;
  periodFinish: bigint;
}

export interface AprInputs {
  musd: Stream;
  stMezo: Stream;
  totalStaked: bigint;
  /** MUSD paid for one MEZO, scaled by 1e18. stMEZO is worth one MEZO. */
  mezoPriceInMusd: bigint;
  now: bigint;
}

const YEAR = 365n * 24n * 60n * 60n;
const PRICE_SCALE = 10n ** 18n;
const BPS = 10_000n;
const DISPLAY_CAP_BPS = 1_000_000n;

/**
 * What stakers earn in a year at the current stream rates, as a share of the MUSD value of
 * everything staked, in basis points. Streams that have finished count as zero.
 */
export function stakingAprBps(inputs: AprInputs): bigint | undefined {
  const stakedValue = toMusd(inputs.totalStaked, inputs.mezoPriceInMusd);
  if (stakedValue === 0n) return undefined;
  const yearlyMusd = yearly(inputs.musd, inputs.now);
  const yearlyStMezoValue = toMusd(yearly(inputs.stMezo, inputs.now), inputs.mezoPriceInMusd);
  return ((yearlyMusd + yearlyStMezoValue) * BPS) / stakedValue;
}

/** An APR such as "12.3%", a dash when there is none, and a cap for tiny testnet stakes. */
export function formatApr(bps: bigint | undefined): string {
  if (bps === undefined) return "–";
  if (bps > DISPLAY_CAP_BPS) return "Over 10,000%";
  return `${(Number(bps) / 100).toFixed(1)}%`;
}

function yearly(stream: Stream, now: bigint): bigint {
  return stream.periodFinish > now ? stream.ratePerSecond * YEAR : 0n;
}

function toMusd(stMezo: bigint, mezoPriceInMusd: bigint): bigint {
  return (stMezo * mezoPriceInMusd) / PRICE_SCALE;
}
