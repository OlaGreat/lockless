import { fireEvent, render, screen } from "@testing-library/react";
import { parseEther } from "viem";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Deployment } from "../config/deployment";
import { SellPanel } from "./SellPanel";

const ACCOUNT = "0x0000000000000000000000000000000000000001";
const UNUSED = "0x0000000000000000000000000000000000000000";
const DEPLOYMENT: Deployment = {
  chainId: 31611,
  vault: UNUSED,
  stMEZO: "0x00000000000000000000000000000000000000a1",
  staking: UNUSED,
  harvester: UNUSED,
  router: "0x00000000000000000000000000000000000000a3",
  veMEZO: UNUSED,
  boostVoter: UNUSED,
  musd: UNUSED,
  mezo: "0x00000000000000000000000000000000000000a2",
};
const ROUTES = [{ from: DEPLOYMENT.stMEZO, to: DEPLOYMENT.mezo, stable: false, factory: DEPLOYMENT.router }];

const wallet = { balance: parseEther("50"), allowance: 0n };
const quote = { routes: ROUTES, quoted: parseEther("9.76") };
const send = vi.fn();

vi.mock("../hooks/useTokenAccount", () => ({ useTokenAccount: () => wallet }));
vi.mock("../hooks/useSellQuote", () => ({ useSellQuote: () => quote }));
vi.mock("../hooks/useTransaction", () => ({
  useTransaction: () => ({ state: { status: "idle" }, send, busy: false }),
}));

function renderWithAmount(amount: string) {
  render(<SellPanel deployment={DEPLOYMENT} account={ACCOUNT} />);
  fireEvent.change(screen.getByLabelText("Sell stMEZO"), { target: { value: amount } });
}

describe("SellPanel", () => {
  beforeEach(() => {
    wallet.allowance = 0n;
    quote.quoted = parseEther("9.76");
    send.mockClear();
  });

  it("explains that holders leave by selling, because the lock is permanent", () => {
    render(<SellPanel deployment={DEPLOYMENT} account={ACCOUNT} />);

    expect(screen.getByText(/cannot be redeemed/i)).toBeInTheDocument();
  });

  it("shows what the pool pays and how it compares with one for one", () => {
    renderWithAmount("10");

    expect(screen.getByText("9.76 MEZO")).toBeInTheDocument();
    expect(screen.getByText("2.4% below 1:1")).toBeInTheDocument();
    expect(screen.getByText("9.66 MEZO")).toBeInTheDocument();
  });

  it("says when the pool cannot fill the trade", () => {
    quote.quoted = 0n;

    renderWithAmount("10");

    expect(screen.getByText(/no liquidity/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Approve stMEZO" })).toBeDisabled();
  });

  it("asks for approval before the first sale", () => {
    renderWithAmount("10");

    fireEvent.click(screen.getByRole("button", { name: "Approve stMEZO" }));

    expect(send).toHaveBeenCalledWith("Approve stMEZO", expect.objectContaining({
      address: DEPLOYMENT.stMEZO,
      functionName: "approve",
      args: [DEPLOYMENT.router, parseEther("10")],
    }));
  });

  it("sells through the router with a 1% slippage limit once approved", () => {
    wallet.allowance = parseEther("10");
    renderWithAmount("10");

    fireEvent.click(screen.getByRole("button", { name: "Sell for MEZO" }));

    const [label, request] = send.mock.calls[0]!;
    expect(label).toBe("Sell stMEZO");
    expect(request).toMatchObject({
      address: DEPLOYMENT.router,
      functionName: "swapExactTokensForTokens",
    });
    expect(request.args.slice(0, 4)).toEqual([parseEther("10"), parseEther("9.6624"), ROUTES, ACCOUNT]);
  });
});
