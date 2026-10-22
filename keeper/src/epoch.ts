/** Mezo Earn epochs last one week and start every Thursday at 00:00 UTC. */
export const EPOCH_SECONDS = 7 * 24 * 60 * 60;

/** Voting is closed for the first and last hour of every epoch. */
const VOTE_BUFFER_SECONDS = 60 * 60;

export function epochStart(timestamp: number): number {
  return timestamp - (timestamp % EPOCH_SECONDS);
}

export function nextEpochStart(timestamp: number): number {
  return epochStart(timestamp) + EPOCH_SECONDS;
}

export function isVotingOpen(timestamp: number): boolean {
  const opensAfter = epochStart(timestamp) + VOTE_BUFFER_SECONDS;
  const closesAfter = nextEpochStart(timestamp) - VOTE_BUFFER_SECONDS;
  return timestamp > opensAfter && timestamp <= closesAfter;
}
