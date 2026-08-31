# Prose quality

Apply these rules to documentation, comments, reports, prompts, commit messages, and other maintained prose.

## Accuracy and voice

- Preserve the source meaning, uncertainty, exact identifiers, official names, and quotations. Add facts or specifics only when evidence supports them.
- Prefer the author's established voice when a sample exists. Do not replace uncertainty with invented precision.
- Explain enough context that a reader can identify the actor, action, condition, and outcome without the immediate conversation.

## Clear prose

- State the main point first. Use complete sentences with concrete subjects and verbs.
- Remove filler, repeated conclusions, vague abstractions, promotional language, excessive hedging, and jargon that hides the mechanism.
- Prefer neutral, direct wording. Define unfamiliar abbreviations and use one term consistently for each concept.
- Use lists only for genuinely parallel items. Avoid decorative headings, forced groupings, rhetorical questions, and formulaic contrasts.

## Technical writing

- Describe current system behavior. Reserve change narration for changelogs, release notes, and migration guides.
- Comments and docstrings should explain reasons, constraints, units, invariants, or behavior the code does not reveal. Keep them to one or two lines.
- Keep documentation close to the maintained source of truth. Do not copy details that readers can obtain cheaply from current configuration or command output.

## Punctuation and formatting

- Use ASCII punctuation in prose. Use straight quotes and rewrite em dashes, en dashes, and double hyphens as sentence punctuation.
- Preserve established spelling and required hyphens in official names, identifiers, URLs, commands, and quotations.
- Keep each Markdown paragraph on one source line. Add line breaks only for Markdown structure or meaning.
- Use sentence case for English headings and avoid decorative formatting or emojis.

## Korean prose

- Prefer complete sentences with clear particles and predicates over compressed noun chains or uncommon prefixed and Sino-Korean nouns.
- Use precise verbs such as `명시하다`, `포함하다`, `고정하다`, and `저장하다` instead of informal `박다` expressions.
- Keep familiar concise terms when they are clear. Use Korean script in Korean prose, while retaining official English names when they are clearer than literal translations.
- Use `관측` only when contrasting actual data with defined or expected behavior. Otherwise state what the data records or what actually happened.
- State policy and architecture through their mechanism rather than metaphor.

## Final review

- Review substantive prose once for accuracy, clarity, and consistency, then stop polishing unless a material issue remains.
