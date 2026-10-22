import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ExitComparisonCard } from "./ExitComparisonCard";

describe("ExitComparisonCard", () => {
  it("shows what the desk pays, what Lockless gives and the difference", () => {
    render(<ExitComparisonCard lockedMezo={1_000n * 10n ** 18n} />);

    expect(screen.getByText("600.00 MEZO")).toBeInTheDocument();
    expect(screen.getByText("1,000.00 stMEZO")).toBeInTheDocument();
    expect(screen.getByText("+400.00 more")).toBeInTheDocument();
  });
});
