import { describe, expect, it } from "vitest";
import { walletOptions, type DetectedConnector } from "./wallets";

const generic: DetectedConnector = { id: "injected", name: "Injected", type: "injected" };
const metaMask: DetectedConnector = {
  id: "io.metamask",
  name: "MetaMask",
  type: "injected",
  icon: "data:image/svg+xml;base64,AAA",
};
const rabby: DetectedConnector = {
  id: "io.rabby",
  name: "Rabby Wallet",
  type: "injected",
  icon: "data:image/svg+xml;base64,BBB",
};

describe("walletOptions", () => {
  it("lists every wallet the browser announced", () => {
    const options = walletOptions([generic, metaMask, rabby]);

    expect(options.map((option) => option.name)).toEqual(["MetaMask", "Rabby Wallet"]);
  });

  it("hides the generic browser wallet when real wallets announced themselves", () => {
    const options = walletOptions([generic, metaMask]);

    expect(options.map((option) => option.id)).not.toContain("injected");
  });

  it("falls back to the generic browser wallet when nothing announced itself", () => {
    const options = walletOptions([generic]);

    expect(options).toEqual([{ id: "injected", name: "Browser wallet", icon: undefined }]);
  });

  it("keeps each wallet's icon", () => {
    expect(walletOptions([metaMask])[0]?.icon).toBe(metaMask.icon);
  });

  it("lists a wallet only once even if it announced itself twice", () => {
    expect(walletOptions([metaMask, { ...metaMask }])).toHaveLength(1);
  });

  it("returns nothing when no wallet is installed", () => {
    expect(walletOptions([])).toEqual([]);
  });
});
