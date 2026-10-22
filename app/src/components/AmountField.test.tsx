import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AmountField } from "./AmountField";

const TEN = 10n * 10n ** 18n;

describe("AmountField", () => {
  it("shows the balance with the token symbol", () => {
    render(<AmountField label="Deposit" symbol="MEZO" balance={TEN} value="" onChange={() => {}} />);

    expect(screen.getByText("Balance: 10.00 MEZO")).toBeInTheDocument();
  });

  it("fills in the whole balance when Max is pressed", () => {
    const onChange = vi.fn();
    render(<AmountField label="Deposit" symbol="MEZO" balance={TEN} value="" onChange={onChange} />);

    fireEvent.click(screen.getByRole("button", { name: "Max" }));

    expect(onChange).toHaveBeenCalledWith("10");
  });

  it("explains a problem with the typed amount", () => {
    render(<AmountField label="Deposit" symbol="MEZO" balance={TEN} value="11" onChange={() => {}} />);

    expect(screen.getByRole("alert")).toHaveTextContent("That is more than your balance");
  });

  it("stays quiet while the field is empty", () => {
    render(<AmountField label="Deposit" symbol="MEZO" balance={TEN} value="" onChange={() => {}} />);

    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });
});
