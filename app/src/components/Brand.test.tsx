import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Brand } from "./Brand";

describe("Brand", () => {
  it("shows the Lockless name", () => {
    render(<Brand />);

    expect(screen.getByText("Lockless")).toBeInTheDocument();
  });

  it("shows the logo mark as decoration next to the name", () => {
    const { container } = render(<Brand />);

    const logo = container.querySelector("img");
    expect(logo).toHaveAttribute("src", "/logo-mark.svg");
    expect(logo).toHaveAttribute("alt", "");
  });
});
