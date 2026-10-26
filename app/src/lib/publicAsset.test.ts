import { describe, expect, it } from "vitest";
import { publicAsset } from "./publicAsset";

describe("publicAsset", () => {
  it("serves files from the site root by default", () => {
    expect(publicAsset("logo-mark.svg", "/")).toBe("/logo-mark.svg");
  });

  it("serves files from a sub-path such as GitHub Pages", () => {
    expect(publicAsset("logo-mark.svg", "/lockless/")).toBe("/lockless/logo-mark.svg");
  });

  it("does not double a slash when the file path starts with one", () => {
    expect(publicAsset("/logo-mark.svg", "/lockless/")).toBe("/lockless/logo-mark.svg");
  });

  it("uses the base the app was built with when none is given", () => {
    expect(publicAsset("logo-mark.svg")).toBe(`${import.meta.env.BASE_URL}logo-mark.svg`);
  });
});
