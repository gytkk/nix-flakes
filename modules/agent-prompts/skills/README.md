# Shared skills

This directory contains a selected set of model-invoked skills from [mattpocock/skills](https://github.com/mattpocock/skills). Nix exposes each skill directory directly to Claude Code, Codex, and Pi, so evaluating the flake does not fetch that repository as an input.

- Upstream version: `1.2.3`
- Upstream commit: `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`
- Retrieved: `2026-08-29`

The selection excludes user-invoked wrappers and setup workflows. Each retained directory contains its `SKILL.md` and any file that it directly references. Plugin manifests and harness-specific agent metadata are excluded. `code-review` discovers repository configuration without the removed setup skill. The upstream MIT license is included in `LICENSE`.
