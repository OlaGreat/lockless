import { render, screen } from "@testing-library/react";
import { parseEther } from "viem";
import { describe, expect, it, vi } from "vitest";
import type { Deployment } from "../config/deployment";
import { StatsBar } from "./StatsBar";

const apr = { bps: 1_234n as bigint | undefined };

vi.mock("../hooks/useVaultStats", () => ({
  useVaultStats: () => ({ lockedMezo: parseEther("79.31"), stakedStMezo: parseEther("12"), votingPower: parseEther("79.31") }),
}));
vi.mock("../hooks/useStakingApr", () => ({ useStakingApr: () => apr.bps }));

describe("StatsBar", () => {
  it("shows the live staking APR", () => {
    render(<StatsBar deployment={{} as Deployment} />);

    expect(screen.getByText("Staking APR")).toBeInTheDocument();
    expect(screen.getByText("12.3%")).toBeInTheDocument();
  });

  it("shows a dash before there is an APR", () => {
    apr.bps = undefined;

    render(<StatsBar deployment={{} as Deployment} />);

    expect(screen.getByText("Staking APR").nextSibling).toHaveTextContent("–");
  });

  it("keeps the vault figures", () => {
    render(<StatsBar deployment={{} as Deployment} />);

    expect(screen.getByText("MEZO locked forever")).toBeInTheDocument();
    expect(screen.getByText("stMEZO staked")).toBeInTheDocument();
  });
});
