---
name: karpathy-guidelines
description: Coding discipline for avoiding common LLM mistakes when writing, reviewing, or refactoring code by surfacing assumptions, keeping solutions simple and surgical, and defining verifiable success criteria.
license: MIT
---

# Karpathy Guidelines

Apply this workflow to coding tasks. Global and project instructions remain the
source of truth for safety, approvals, tools, Git, testing, and delivery.

## 1. Make the Problem Explicit

Before coding:

- State the intended outcome and distinguish known facts from assumptions.
- Surface materially different interpretations and their consequences instead
  of choosing silently.
- Name meaningful tradeoffs and recommend the simplest viable path.

## 2. Prefer the Simplest Sufficient Solution

Write the minimum code needed for the requested outcome:

- Do not add speculative features, configurability, or abstractions.
- Do not generalize a single-use path without evidence that reuse is needed.
- Do not add handling for impossible scenarios.
- If the implementation is substantially larger than the problem, simplify it
  before finishing.

## 3. Keep Changes Surgical

Every changed line should trace to the requested outcome:

- Match the existing style and structure.
- Do not refactor, reformat, or clean up unrelated code.
- Do not remove pre-existing dead code unless asked.
- Remove only the imports, variables, or helpers made obsolete by your change.

## 4. Work Against Verifiable Goals

Convert the request into observable success criteria before implementation:

- A bug fix should reproduce the failure and then demonstrate the fix.
- A feature should cover its intended behavior and relevant failure cases.
- A refactor should preserve behavior before and after the change.
- Each nontrivial plan step should name its verification evidence.

[karpathy-post]: https://x.com/karpathy/status/2015883857489522876
