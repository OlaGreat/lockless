import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { Deployment } from "../config/deployment";
import { ConvertPanel } from "./ConvertPanel";

vi.mock("../hooks/useUserLocks", () => ({ useUserLocks: () => [] }));

const ACCOUNT = "0x0000000000000000000000000000000000000001";

function renderPanel() {
  render(<ConvertPanel deployment={{} as Deployment} account={ACCOUNT} />);
}

describe("ConvertPanel", () => {
  it("says converting pays out the lock's incentives and rebase", () => {
    renderPanel();

    expect(screen.getByText(/pays you the incentives the lock has earned/i)).toBeInTheDocument();
    expect(screen.getByText(/adds its pending rebase as stMEZO/i)).toBeInTheDocument();
  });

  it("asks owners to claim incentives from gauges the lock no longer votes for", () => {
    renderPanel();

    expect(screen.getByText(/no longer votes for/i)).toBeInTheDocument();
  });

  it("no longer claims that rewards stay with the old lock", () => {
    renderPanel();

    expect(screen.queryByText(/stay with the old lock/i)).not.toBeInTheDocument();
  });

  it("says when the wallet holds no locks", () => {
    renderPanel();

    expect(screen.getByText("This wallet holds no veMEZO locks.")).toBeInTheDocument();
  });
});
