# Writing and prose quality

Apply these rules to documentation, comments, reports, prompts, PR descriptions, commit messages, and other substantive prose for users or future agents.
Treat prose as maintained work: ambiguity can affect later decisions and outputs.

## Preserve meaning

- Preserve source meaning before improving style or structure. Avoid unsupported facts, names, numbers, dates, quotations, citations, causal claims, or specifics; prefer evidence-backed statements.
- Avoid replacing uncertainty with invented specificity. Preserve or clarify uncertainty, or ask the author when it prevents an accurate result.
- Preserve exact identifiers, official names, quotations, and established terminology. When the author provides a writing sample, prefer its voice over generic polished prose.

## Write clearly and directly

- Write so readers without the immediate context can determine the intended meaning. Avoid ceremonial introductions such as `Let's dive in` or `Here is what you need to know`; state the main point first.
- Avoid vague or compressed phrasing. Prefer complete sentences with concrete subjects and verbs, and state actors, actions, conditions, ownership, and outcomes when they matter.
- Avoid elaborate wording, filler, repeated conclusions, excessive hedging, promotional language, unsupported importance claims, abstract noun chains, jargon, and metaphors that hide the mechanism. Prefer concise, concrete language and simple constructions such as `is`, `has`, and `does`.
- Define unfamiliar abbreviations and newly introduced terms at first use.

## Use natural prose

- Avoid forcing ideas into groups of three, cycling through synonyms, formulaic contrasts such as `not only X, but Y`, false ranges such as `from X to Y`, and generic conclusions. Prefer the clearest structure and terminology for the evidence.
- Avoid promotional adjectives, inflated significance, manufactured emphasis, rhetorical questions, aphorisms, dramatic conclusions, excessive headings, bold labels, decorative formatting, and emojis. Prefer neutral, proportionate prose.
- Treat suspected AI-writing patterns as warning signs, not automatic violations. Rewrite them when they reduce clarity, accuracy, or consistency with the intended voice.
- For technical, legal, and reference documentation, prefer neutral, plain language.

## Technical writing

- Explain current system behavior. Outside changelogs, release notes, and migration guides, avoid narrating documentation from the latest diff's perspective.
- Avoid comments and docstrings that restate code. Prefer explaining reasons, constraints, units, invariants, or behavior that the code does not reveal.
- Do not write comments or docstrings that span three or more lines. Keep each one to one or two lines.
- Avoid decorative section banners, ASCII boxes, separator comments, and lists used only to simulate structure. Prefer lists only for genuinely parallel or independently actionable items.

## Punctuation and style

These rules apply to agent-written prose, not code, commands, identifiers, URLs, generated content, or quotations whose original punctuation must be preserved.

- Use ASCII punctuation. Replace em dashes and en dashes with periods, commas, colons, parentheses, or revised sentence structure; use straight quotation marks (`"` and `'`) instead of curly quotation marks; and do not use double hyphens as sentence punctuation.
- Avoid unnecessary hyphens in compounds. Use them when grammar or clarity requires them, and preserve established spellings, official names, command-line flags, identifiers, and project conventions.
- Use sentence case for English headings.

## Korean prose

- Avoid uncommon prefixed or Sino-Korean nouns that compress an explanation. Prefer complete sentences with verbs. For example:
  - Prefer `아직 적재되지 않은 데이터` over `미적재 데이터`.
  - Prefer `값이나 동작이 달라지지 않는다` over `무영향`.
  - Prefer `변경 사항을 원래 코드에 역으로 반영한다` over `역반영`.
  - Prefer `코드만 읽어서는 알 수 없는 동작` over `비자명한 동작`.
- Avoid mechanically expanding familiar expressions. Keep terms such as `미확인`, `비정상`, `[추정]`, and `[미확인]` when their meaning is clear.
- Avoid informal uses of `박다`, `박아 넣다`, and `박아 두다`. Prefer the intended operation, such as `명시하다`, `포함하다`, `고정하다`, or `저장하다`.
- Avoid noun chains that make readers infer relationships. Prefer sentences that state what acts on what.
- Do not omit Korean particles, endings, predicates, or other sentence components when doing so makes relationships or responsibilities unclear. Headings and short list labels may remain phrases.
- Use Korean script in otherwise Korean prose instead of mixing in Chinese characters.
- Keep English when it is an official name or clearer than an unfamiliar literal translation. Avoid Korean transliterations that still need explanation; describe the meaning and include the original term in parentheses when useful.
- Use `관측` only to contrast what is defined or expected with data that actually appears. Otherwise prefer `데이터에 기록된`, `실제로 발생한`, or `활동 기록`.
- Avoid metaphorical policy or architecture statements. State their mechanism. For example, prefer `원본이 변경되어도 사본은 자동으로 갱신되지 않으므로 원문을 복사하지 않는다` over `사본은 따로 늙는다`.

## Final review

- Avoid repeated polishing passes. Before finalizing substantive prose, check it once against the applicable rules and correct material conflicts.
