# Portable skills

This directory is the canonical source for repository-managed portable skills. `agent-core/manifest.toml` controls which skills each runtime receives.

The following skills came from [mattpocock/skills](https://github.com/mattpocock/skills):

- Upstream version: `1.2.3`
- Upstream commit: `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`
- Retrieved: `2026-08-29`

The selection excludes user-invoked wrappers and setup workflows. Each retained directory contains its `SKILL.md` and any file that it directly references. Plugin manifests and runtime-specific agent metadata are excluded. `code-review` discovers repository configuration without the removed setup skill. The upstream MIT license is included in `LICENSE` and applies to the imported skills.

`devils-advocate`, `parallel-research-merge`, and `pi-agent` were consolidated from this repository's former runtime-local skill trees. Runtime-specific metadata may remain inside a portable skill when another runtime can safely ignore it.
