---
name: theme-template-authoring
description: Discover official theme surfaces, structure app templates, and keep multi-app theme template layouts consistent.
---

## When to use

Use when creating or revising app theme templates, schema-driven theme exporters, or cross-app template conventions.

## References

- Workflow: `workflow.md`
- Consistency checklist: `consistency-checklist.md`

## Core rules

1. Start from official sources first: published schema, builtin docs, runtime help, or upstream source definitions.
2. Record every official source in the template metadata with stable refs or URLs.
3. Separate official surfaces from plugin or app-extension extras when the platform distinguishes them.
4. Prefer data templates over hardcoded mappings in generators whenever the target surface set is reasonably stable.
5. Keep template structure consistent across apps: metadata, sources, value-schema notes, sections, and explicit token conventions.
6. If official schema is partial, document exactly what is strict and what remains open-ended.
7. After changes, validate both the generated export and the template-layout consistency against sibling app templates.
