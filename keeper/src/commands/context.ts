import type { PublicClient } from "viem";
import type { KeeperConfig } from "../config";
import { createReadClient } from "../mezo/chain";
import { multicallReader, type ContractReader } from "../mezo/reader";

export interface KeeperContext {
  config: KeeperConfig;
  client: PublicClient;
  reader: ContractReader;
  log: (message: string) => void;
  now: () => number;
}

export function createContext(config: KeeperConfig): KeeperContext {
  const client = createReadClient(config);
  return {
    config,
    client,
    reader: multicallReader(client),
    log: (message) => console.log(message),
    now: () => Math.floor(Date.now() / 1000),
  };
}
