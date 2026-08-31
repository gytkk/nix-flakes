import { describe, expect, test } from "bun:test";
import {
  combinedProfile,
  isToolProfile,
  toolsForProfile,
} from "../files/extensions/tool-profiles/policy";

const baseTools = ["read", "bash", "edit", "write", "enable_tools"];
const optionalTools = [
  "web_search",
  "mcp",
  "subagent",
  "subagent_wait",
];

describe("tool profile selection", () => {
  test("lite keeps only the base tools", () => {
    expect(toolsForProfile(baseTools, optionalTools, "lite")).toEqual(
      baseTools,
    );
  });

  test("research enables only available research tools", () => {
    expect(toolsForProfile(baseTools, optionalTools, "research")).toEqual([
      ...baseTools,
      "web_search",
      "mcp",
    ]);
  });

  test("delegation enables only available subagent tools", () => {
    expect(toolsForProfile(baseTools, optionalTools, "delegation")).toEqual([
      ...baseTools,
      "subagent",
      "subagent_wait",
    ]);
  });

  test("full enables every available optional tool without duplicates", () => {
    expect(
      toolsForProfile([...baseTools, "read"], optionalTools, "full"),
    ).toEqual([...baseTools, ...optionalTools]);
  });
});

describe("additive profile transitions", () => {
  test("combines research and delegation as full", () => {
    expect(combinedProfile("research", "delegation")).toBe("full");
    expect(combinedProfile("delegation", "research")).toBe("full");
  });

  test("keeps repeated and full requests stable", () => {
    expect(combinedProfile("lite", "research")).toBe("research");
    expect(combinedProfile("research", "research")).toBe("research");
    expect(combinedProfile("full", "delegation")).toBe("full");
  });
});

test("accepts only supported profile names", () => {
  expect(isToolProfile("lite")).toBeTrue();
  expect(isToolProfile("full")).toBeTrue();
  expect(isToolProfile("unknown")).toBeFalse();
});
