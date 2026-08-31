export const OPTIONAL_TOOL_GROUPS = {
  research: [
    "web_search",
    "source_check",
    "fetch_content",
    "get_search_content",
    "mcp",
    "mcpScript",
  ],
  delegation: [
    "subagent",
    "subagent_wait",
    "subagent_supervisor",
    "intercom",
  ],
} as const;

export type ToolProfile = "lite" | "research" | "delegation" | "full";
export type OptionalGroup = Exclude<ToolProfile, "lite" | "full">;

const PROFILE_NAMES = ["lite", "research", "delegation", "full"] as const;
export const OPTIONAL_TOOL_NAMES = new Set<string>([
  ...OPTIONAL_TOOL_GROUPS.research,
  ...OPTIONAL_TOOL_GROUPS.delegation,
]);

function unique(names: readonly string[]): string[] {
  return [...new Set(names)];
}

export function isToolProfile(value: string): value is ToolProfile {
  return (PROFILE_NAMES as readonly string[]).includes(value);
}

export function toolsForProfile(
  baseTools: readonly string[],
  availableOptionalTools: readonly string[],
  profile: ToolProfile,
): string[] {
  const enabledOptional =
    profile === "full"
      ? OPTIONAL_TOOL_NAMES
      : profile === "lite"
        ? new Set<string>()
        : new Set<string>(OPTIONAL_TOOL_GROUPS[profile]);

  return unique([
    ...baseTools,
    ...availableOptionalTools.filter((name) => enabledOptional.has(name)),
  ]);
}

export function combinedProfile(
  current: ToolProfile,
  requested: OptionalGroup | "full",
): ToolProfile {
  if (current === "full" || requested === "full") return "full";
  if (current === "lite" || current === requested) return requested;
  return "full";
}
