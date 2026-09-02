# Consistency checklist

Use this when reviewing multiple app templates.

## Required shared fields

- `name`
- `version`
- `description`
- `sources`

## Strongly recommended shared fields

- Contract metadata describing the official source or schema
- Explicit token convention, such as a `$slot` prefix
- Sectioned template layout instead of one flat opaque blob
- Notes on strict vs open-ended areas

## Review questions

1. Does each template clearly cite the official source of truth?
2. Is the generator consuming template data rather than burying surface definitions in code?
3. Are official builtins separated from plugin or local extras?
4. Are token names stable and understandable across apps?
5. If one app is schema-driven and another is docs-driven, is that difference documented instead of hidden?
6. Can a new app template follow the same high-level shape without guessing?
7. Does the export validation step actually enforce the official contract where possible?

## Common failure modes

- Vendored schema exists but generator still hardcodes most surface names.
- Template metadata exists but official sources are not cited.
- Plugin groups leak into the official builtin template.
- One app uses sections while another collapses everything into flat lists.
- Open-ended parts of the official contract are treated as if they were fully enumerated.
