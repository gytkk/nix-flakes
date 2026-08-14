# Writing and prose quality

Apply these rules to documentation, comments, reports, prompts, PR descriptions, commit messages, and other substantive prose written for users or future agents.
Treat prose as a maintained artifact whose ambiguity can propagate into later decisions and outputs.

## Preserve meaning

- Preserve the source meaning before improving style or structure.
- Never add facts, names, numbers, dates, quotes, citations, causal claims, or concrete details that are not supported by the source or available evidence.
- Do not replace uncertainty with invented specificity.
  Preserve or clarify the uncertainty, or ask the author when it blocks an accurate result.
- Preserve exact identifiers, official names, quotations, and established domain terminology.
  When the author provides a writing sample, prefer that voice over a generic polished style.

## Write clearly and directly

- Write so that a reader unfamiliar with the immediate context can determine the intended meaning from the text itself.
- State the main point without ceremonial introductions, conversational warm-ups, or announcements such as `Let's dive in` and `Here is what you need to know`.
- Prefer complete sentences with concrete subjects and verbs. Make actors, actions, conditions, ownership, and outcomes explicit when they matter.
- Prefer simple constructions such as `is`, `has`, and `does` when a more elaborate expression adds no meaning.
- Remove filler, repeated conclusions, excessive hedging, promotional language, and unsupported claims of importance.
- Avoid abstract noun chains, compressed jargon, and metaphors that hide the actual mechanism.
- Define unfamiliar abbreviations and newly introduced terms at first use.

## Avoid formulaic AI prose

- Do not force ideas into groups of three merely to make them appear complete.
- Do not cycle through synonyms when repeating the clearest term would be more precise.
- Avoid formulaic contrasts such as `not only X, but Y`, false ranges such as `from X to Y`, and generic conclusions that add no information.
- Avoid promotional adjectives, inflated statements about significance, and analysis that is not supported by concrete evidence.
- Do not manufacture emphasis with repeated sentence fragments, rhetorical questions, aphorisms, or uniformly dramatic conclusions.
- Avoid excessive headings, bold labels, decorative formatting, and emojis.
- Treat suspected AI-writing patterns as warning signs, not automatic violations.
  Rewrite them when they reduce clarity, accuracy, or consistency with the intended voice.
- Technical, legal, and reference documentation should remain neutral and plain.

## Technical writing

- Explain the current behavior of the system.
  Except in changelogs, release notes, and migration guides, do not narrate documentation from the perspective of the latest diff.
- Comments and docstrings should explain reasons, constraints, units, invariants, or behavior that cannot be inferred from the code.
- Do not restate what the code already says.
- Do not use decorative section banners, ASCII boxes, or separator comments.
- Use lists only when items are genuinely parallel or independently actionable.
  Do not convert ordinary prose into a list of bold inline headings.

## Punctuation and Style

These rules apply to prose written by the agent.
Do not alter code, commands, identifiers, URLs, generated content, or quotations whose original punctuation must be preserved.

- Always use plain ASCII characters rather than non-ASCII equivalents.
  - Replace them with a period, comma, colon, parentheses, or a restructured sentence.
  - Do not use em dashes (`—`) or en dashes (`–`).
  - Do not use double hyphens (`--`) as sentence punctuation.
  - Use straight ASCII quotation marks (`"` and `'`) instead of curly quotation marks (`“”` and `‘’`).
- Use hyphens in compound expressions only when grammar or clarity requires them:
  - Preserve established spellings, official names, command-line flags, identifiers, and project-specific conventions.
- Use sentence case for English headings rather than capitalizing every major word.

## Korean prose

When writing Korean:

- Prefer complete sentences with verbs over uncommon prefixed or Sino-Korean nouns that compress an explanation.
  For example:
  - Prefer `아직 적재되지 않은 데이터` over `미적재 데이터`.
  - Prefer `값이나 동작이 달라지지 않는다` over `무영향`.
  - Prefer `변경 사항을 원래 코드에 역으로 반영한다` over `역반영`.
  - Prefer `코드만 읽어서는 알 수 없는 동작` over `비자명한 동작`.
- Do not expand familiar expressions mechanically.
  Terms such as `미확인`, `비정상`, `[추정]`, and `[미확인]` are acceptable when their meaning is already clear.
- Replace informal uses of `박다`, `박아 넣다`, and `박아 두다` with the intended operation, such as `명시하다`, `포함하다`, `고정하다`, or `저장하다`.
- Avoid chains of nouns that require the reader to infer how the terms relate.
  Rewrite them as a sentence that states what acts on what.
- Do not mix Chinese characters into otherwise Korean prose.
- Keep an English term when it is an official name or clearer than a forced translation.
  Do not replace it with an unfamiliar literal translation.
- Do not use a Korean transliteration when readers would still need an explanation.
  Describe the meaning and include the original term in parentheses when useful.
- Use `관측` only when contrasting what is defined or expected with what actually appears in data.
  Otherwise use a concrete phrase such as `데이터에 기록된`, `실제로 발생한`, or `활동 기록`.
- Replace metaphorical policy or architecture statements with the mechanism they imply.
  For example, replace `사본은 따로 늙는다` with `원본이 변경되어도 사본은 자동으로 갱신되지 않으므로 원문을 복사하지 않는다`.

## Final review

Before finalizing substantive prose, reread it once against the applicable rules in this file.
