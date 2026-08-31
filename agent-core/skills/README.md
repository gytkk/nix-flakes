# Shared skills

This directory is the canonical catalog for repository-managed shared skills. `agent-core/manifest.toml` controls which skills each runtime receives, so a skill can have one source without being installed for every runtime.

The following skills came from [mattpocock/skills](https://github.com/mattpocock/skills):

- Upstream version: `1.2.3`
- Upstream commit: `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`
- Retrieved: `2026-08-29`

The imported selection excludes user-invoked wrappers and setup workflows. Each retained directory contains its `SKILL.md` and any file that it directly references. Plugin manifests and runtime-specific UI metadata are excluded; required discovery metadata remains in `SKILL.md` frontmatter. `code-review` discovers repository configuration without the removed setup skill. The upstream MIT license is included in `LICENSE` and applies to the imported skills.

Shared skills describe required capabilities instead of naming one agent runtime. Runtime modules own packages, settings, plugins, and installation behavior, while the renderer selects skill sources only from this catalog.
