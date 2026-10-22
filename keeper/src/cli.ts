import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { config as loadEnv } from "dotenv";
import { parseConfig } from "./config";
import { createContext, type KeeperContext } from "./commands/context";
import { runHarvest } from "./commands/harvest";
import { runPlan } from "./commands/plan";
import { runStatus } from "./commands/status";
import { runVote } from "./commands/vote";
import { createSigningClient } from "./mezo/chain";

const here = dirname(fileURLToPath(import.meta.url));
const USAGE = "Usage: pnpm keeper <status | plan | vote | harvest | epoch>";

loadEnv({ path: [resolve(here, "../.env"), resolve(here, "../../contracts/.env")] });

const commands: Record<string, (ctx: KeeperContext) => Promise<void>> = {
  status: runStatus,
  plan: runPlan,
  vote: (ctx) => runVote(ctx, createSigningClient(ctx.config)),
  harvest: (ctx) => runHarvest(ctx, createSigningClient(ctx.config)),
  epoch: async (ctx) => {
    const signer = createSigningClient(ctx.config);
    await runHarvest(ctx, signer);
    await runVote(ctx, signer);
  },
};

async function main(): Promise<void> {
  const command = commands[process.argv[2] ?? "status"];
  if (!command) throw new Error(USAGE);
  await command(createContext(parseConfig(readDeployment(), process.env)));
}

function readDeployment(): Record<string, unknown> {
  const path = process.env.DEPLOYMENT_FILE ?? resolve(here, "../../contracts/deployments/31611.json");
  return JSON.parse(readFileSync(path, "utf8"));
}

main().catch((error: Error) => {
  console.error(error.message);
  process.exit(1);
});
