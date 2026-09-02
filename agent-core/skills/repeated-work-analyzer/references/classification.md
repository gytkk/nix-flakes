# Classification

## Recommend `skill` when

- The procedure can be reused across multiple contexts.
- The main value is guidance, analysis, or a repeatable method.
- The work benefits from a stable trigger description and bundled references.

## Recommend `automation` when

- Timing or event triggers are central.
- The work coordinates multiple steps, state updates, or deliveries.
- The procedure behaves like an owned workflow rather than a reusable method.

## Recommend `template` when

- The same output shape recurs but the reasoning stays simple.
- The user mostly needs a scaffold, format, or boilerplate.

## Recommend `runbook` when

- The workflow is local to one workspace or system.
- It depends on specific files, state, channels, or operator rules.
- It is a procedure reference more than a generally reusable skill.

## Evidence threshold

- Strong: repeated at least 2 times with similar inputs and outputs.
- Medium: repeated once plus an explicit request to standardize it.
- Low: one-off work with weak recurrence signs.
