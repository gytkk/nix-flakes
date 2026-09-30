# Shared skills

This directory is the canonical catalog for repository-managed shared skills. `agent-core/manifest.toml` controls which skills each runtime receives, so a skill can have one source without being installed for every runtime.

The skills imported from [mattpocock/skills](https://github.com/mattpocock/skills) are `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grilling`, `prototype`, `research`, `resolving-merge-conflicts`, `tdd`, `wizard`, and `writing-for-agents`.

- Upstream version: `1.2.3`
- Upstream commit: `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`
- Retrieved: `2026-08-29`

The imported selection excludes user-invoked wrappers and setup workflows. Each retained directory contains its `SKILL.md` and any file that it directly references. Plugin manifests and runtime-specific UI metadata are excluded; required discovery metadata remains in `SKILL.md` frontmatter. `code-review` discovers repository configuration without the removed setup skill. The upstream MIT license is included in `LICENSE` and applies to the imported skills.

`pi-agent` and `typesafe-ai` are separate imports with their own [Pi skill license](pi-agent/LICENSE.md) and [TypeSafe skill license](typesafe-ai/LICENSE).

`publish-artifact-to-sites` is imported unchanged from [OpenAI's Data Analytics plugin](https://github.com/openai/plugins/blob/5fd93af4cd0c623e020d0cc7e9ce178b4ac1f70f/plugins/data-analytics/skills/publish-artifact-to-sites/SKILL.md), commit `5fd93af4cd0c623e020d0cc7e9ce178b4ac1f70f`, retrieved on `2026-09-30`. Its upstream plugin manifest declares `Proprietary`; the imported MIT license does not apply to this skill. It publishes validated Data Analytics report and dashboard snapshots and requires that plugin's `validate_artifact` and `export_artifact_package` tools plus callable `sites-building` and `sites-hosting` skills. Those dependencies are not installed by this catalog, and the two Sites skills are not present in the pinned public repository. The remaining skills are maintained locally.

Shared skills describe required capabilities instead of naming one agent runtime. Runtime modules own packages, settings, plugins, and installation behavior, while the renderer selects skill sources only from this catalog.
