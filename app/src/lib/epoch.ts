/** Mezo Earn epochs last one week and start every Thursday at 00:00 UTC. */
export const EPOCH_SECONDS = 7 * 24 * 60 * 60;

export function epochStart(timestamp: number): number {
  return timestamp - (timestamp % EPOCH_SECONDS);
}

export function nextEpochStart(timestamp: number): number {
  return epochStart(timestamp) + EPOCH_SECONDS;
}
