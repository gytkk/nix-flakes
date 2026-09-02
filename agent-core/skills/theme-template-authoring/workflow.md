# Workflow

1. Find the official contract.
   - Prefer published JSON schema, official docs, runtime help, or upstream source structs.
   - Save vendored machine-readable schema locally when reproducibility matters.
2. Find official non-schema semantics.
   - Look for docs that explain meanings, fallback rules, optional groups, naming rules, or extension points.
   - Capture gaps where the schema alone is not enough.
3. Build the template shape.
   - Include metadata: `name`, `version`, `description`, `sources`.
   - Include contract notes: schema URL/ref, token prefix, strict vs open-ended areas.
   - Break surfaces into explicit sections instead of one giant flat mapping.
4. Separate layers.
   - Official builtins in one template.
   - Plugin, extension, or local extras in separate templates if applicable.
5. Refactor the generator.
   - Compute exporter slots from canonical theme data.
   - Render the app template from slots.
   - Validate the rendered output against official schema or documented constraints.
6. Check cross-app consistency.
   - Compare sibling templates for shared structure, naming, and metadata fields.
   - Keep differences intentional and documented.
7. Verify end to end.
   - Regenerate outputs.
   - Confirm export validation passes.
   - Summarize what is official, what is derived, and what is still heuristic.
