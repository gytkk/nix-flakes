# Shared skills

This directory is the canonical catalog for repository-managed shared skills. `agent-core/manifest.toml` controls which skills each runtime receives, so a skill can have one source without being installed for every runtime.

The skills imported from [mattpocock/skills](https://github.com/mattpocock/skills) are `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grilling`, `prototype`, `research`, `resolving-merge-conflicts`, `tdd`, `wizard`, and `writing-for-agents`.

- Upstream version: `1.2.3`
- Upstream commit: `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`
- Retrieved: `2026-08-29`

The imported selection excludes user-invoked wrappers and setup workflows. Each retained directory contains its `SKILL.md` and any file that it directly references. Plugin manifests and runtime-specific UI metadata are excluded; required discovery metadata remains in `SKILL.md` frontmatter. `code-review` discovers repository configuration without the removed setup skill. The upstream MIT license is included in `LICENSE` and applies to the imported skills.

`pi-agent` is a separate import with its own [Pi skill license](pi-agent/LICENSE.md). The other skills are maintained locally.

## Quokka adaptations

The following guidance is independently rewritten from workflow ideas reviewed in [devsisters/quokka](https://github.com/devsisters/quokka/tree/4e39746192faed7e106f4d446884a4314bccbf37) on 2026-10-07. The reviewed snapshot is commit `4e39746192faed7e106f4d446884a4314bccbf37` on `develop`. No Quokka implementation, bundled library, third-party skill text, or company schema is copied.

| Source at the reviewed commit | Local selection and reason |
| --- | --- |
| `src/quokka/agents/main_agent_prompts.py`, `agent_context/main/README.md`, `agent_context/skills/core-kpi/SKILL.md` | [data-analysis](data-analysis/SKILL.md): define metric grain and base components, check joins and distinct counts, and verify coverage and totals. These checks add a data workflow beyond general evidence rules. |
| `agent_context/skills/causal-inference/references/reporting-guide.md` | `data-analysis`: distinguish invalid comparisons from inconclusive effects and disclose changes to the analyzed population. The private estimator, installation procedure, and fixed statistical thresholds are excluded. |
| `agent_context/skills/data-visualization/SKILL.md` | [data-visualization](data-visualization/SKILL.md): plot from source data, check scales and units, and inspect fonts and final rendering. Fixed palettes, sandbox paths, and automatic replacement of requested chart types are excluded. |
| `.agents/skills/quokka-skill-author/references/trigger-eval.md`, `.agents/skills/quokka-eval-creator/SKILL.md` | [writing-for-agents validation](writing-for-agents/BEHAVIOR-VALIDATION.md): positive and near-miss cases, successful load evidence, setup failures, and impact on existing cases. The Quokka CLI harness and live-query side effects are excluded. |

All three selections are exposed to OpenClaw, Codex, Claude, and Pi through the existing manifest and renderer. They add no always-loaded operating rules, runtime dependencies, credentials, or mutable workspace configuration.

The selection excludes game and company data skills, Quokka administration and deployment skills, and library-specific frontend skills because their tools and schemas do not apply generally. PR and commit workflows overlap existing operating rules. Usage-report analysis overlaps `user-friction-review` and requires Quokka's thread APIs. Mandatory designer interviews and fixed report sections are not adopted because they would impose unnecessary steps on unrelated work.

Shared skills describe required capabilities instead of naming one agent runtime. Runtime modules own packages, settings, plugins, and installation behavior, while the renderer selects skill sources only from this catalog.
