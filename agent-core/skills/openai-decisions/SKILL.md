---
name: openai-decisions
description: Use OpenAI's Decisions API when a feature needs a typed semantic judgment, such as routing, classification, ranking, verification, or an ordered quality score. Also use when brainstorming features built on semantic judgments, replacing a prompt-and-parse decision, or migrating TypeSafe/Jev judgments to gpt-6-luna.
---

# OpenAI decisions

Turn a bounded semantic question into a typed decision that application code can use. Read the [official Decisions guide](https://developers.openai.com/api/docs/guides/decisions) before implementation and inspect the project's installed SDK version. Use the dedicated `POST /v1/decisions` endpoint with `model: "gpt-6-luna"`; decision mode is not a Responses API flag.

## Design the judgment

1. Identify the evidence, the judgment, and the application action that consumes it. Use deterministic code for decisions fully described by rules.
2. Choose `predicate` for a yes/no probability, `choice` for a finite set of alternatives, or `score` for ordered levels. Define clear instructions and alternatives with distinct descriptions. Keep arbitrary object extraction on Responses Structured Outputs and tool execution on function calling.
3. Give every question a unique `name`. Send shared evidence as `input` and independent questions together in `questions`. Split dependent judgments into separate requests so later questions can use earlier answers.
4. Define how the application handles refusal, missing answers, API errors, and uncertain judgments. Decide fallback behavior before connecting the result to an action.
5. Evaluate on representative labeled examples. Select thresholds using the cost of false positives and false negatives. Recheck thresholds when migrating from Jev; probabilities and confidence are not interchangeable across APIs.

For ranking, score each candidate against the same rubric and combine dimensions, weights, and filters in code. For normalization, select from known candidates with a choice question and include a no-match alternative when candidates may be incomplete. Reevaluate judgments when their evidence changes; use explicit fallback or review paths when evidence cannot justify an action.

## Request and answer contract

The request contains `model`, `input`, and `questions`. Text evidence can be a string. For image evidence, use user messages containing `input_text` and `input_image` parts; images must be inline base64 data URLs. Follow the guide's exact message shape.

Every question has `type`, `name`, and `instructions`:

| Type | Additional request fields | Answer |
| --- | --- | --- |
| `predicate` | None | `probability`, from 0 to 1 |
| `choice` | `choices: [{value, description}]` | `choice`, `probabilities`, and `confidence` |
| `score` | `levels: [{label, description}]`, in ascending order | `score`, `probabilities`, and `confidence` |

Find answers by `name` in the response's `answers` array. Check for `type: "refusal"` and validate the expected answer type before reading its fields. Do not assume array order. A score is the probability-weighted mean of zero-based level indices and can be fractional. Choice confidence is separate from the probability assigned to the selected alternative.

Use a compatible OpenAI SDK (`openai` Python 3.26.0+ or JavaScript 7.30.0+), or an HTTP client. SDK callers use `client.decisions.create(...)`. Keep SDK dependencies in the consuming project; this skill does not install them.

## Local API access

In this repository's configured environments, run API clients with `with-openai COMMAND [ARG...]` to supply `OPENAI_API_KEY` from agenix only to that process and its children:

```bash
with-openai uv run app.py
with-openai node app.mjs
```

Clients must read the environment variable themselves. Do not print the key, put it in prompts or source files, or reuse Codex login credentials as API credentials. If the wrapper reports that the secret is unavailable, surface the activation problem before attempting a live request.

Validate request construction, named-answer handling, refusal, and fallback behavior offline before a live API check. A live check uses the user's configured API credentials and incurs API usage; perform it only when authorized.
