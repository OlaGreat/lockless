import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { WalletPicker } from "./WalletPicker";

const options = [
  { id: "io.metamask", name: "MetaMask", icon: "data:image/svg+xml;base64,AAA" },
  { id: "io.rabby", name: "Rabby Wallet", icon: "data:image/svg+xml;base64,BBB" },
];

function renderPicker(overrides: Partial<Parameters<typeof WalletPicker>[0]> = {}) {
  const props = { options, onSelect: vi.fn(), onClose: vi.fn(), ...overrides };
  render(<WalletPicker {...props} />);
  return props;
}

describe("WalletPicker", () => {
  it("lists every wallet with its name and icon", () => {
    renderPicker();

    expect(screen.getByRole("button", { name: /MetaMask/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Rabby Wallet/ })).toBeInTheDocument();
    expect(screen.getByAltText("MetaMask")).toHaveAttribute("src", options[0]!.icon);
  });

  it("connects the wallet the user picks", () => {
    const props = renderPicker();

    fireEvent.click(screen.getByRole("button", { name: /Rabby Wallet/ }));

    expect(props.onSelect).toHaveBeenCalledWith("io.rabby");
  });

  it("shows which wallet is connecting and blocks other clicks", () => {
    renderPicker({ pendingId: "io.metamask" });

    expect(screen.getByRole("button", { name: /MetaMask/ })).toHaveTextContent("Connecting…");
    expect(screen.getByRole("button", { name: /Rabby Wallet/ })).toBeDisabled();
  });

  it("shows why the last attempt failed", () => {
    renderPicker({ error: "Rabby Wallet: wallet must has at least one account" });

    expect(screen.getByRole("alert")).toHaveTextContent("wallet must has at least one account");
  });

  it("explains what to do when no wallet is installed", () => {
    renderPicker({ options: [] });

    expect(screen.getByText(/No wallet found/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /MetaMask/ })).toHaveAttribute(
      "href",
      "https://metamask.io/download/",
    );
  });

  it("closes", () => {
    const props = renderPicker();

    fireEvent.click(screen.getByRole("button", { name: "Close" }));

    expect(props.onClose).toHaveBeenCalled();
  });
});
