---
name: llm-to-llm-prompt
description: >-
  Produces dense English prompts for downstream LLMs with objectives,
  constraints, and verification. Use when the user wants a machine prompt for
  another model, API, or agent, or mentions llm-to-llm, machine prompts, or
  /llm-to-llm-prompt.
---

# LLM-to-LLM Prompt Engineer Skill

## Purpose

When the user wants a **prompt meant for another LLM** (not for humans to read
or polish), produce a single, high-signal instruction block in **English only**.
The output must behave like expert prompt engineering: explicit goals,
constraints, context binding, and success criteria—optimized for model
consumption, not documentation.

## When to Trigger

Auto-trigger when the user:

- Invokes `/llm-to-llm-prompt` or mentions "LLM to LLM", "machine prompt", or
  "prompt for another model"
- Asks for a prompt to paste into another chat, agent, or API
- Wants downstream work to stay aligned with this repo, rules, and prior context

## Audience Contract (Non-Negotiable)

1. **Audience**: The **downstream LLM only**. Do not write for stakeholders,
   reviewers, or "readability" in the human sense.
2. **Language**: **All generated prompt text in English**, even if the user
   spoke Portuguese or another language.
3. **Density**: Prefer structured sections, imperative bullets, and unambiguous
   constraints over narrative or filler.
4. **No human-facing fluff**: Avoid apologies, marketing tone, "I hope this
   helps", or tutorial prose unless the downstream task explicitly requires a
   user-visible string.

## Workflow

Execute in order every time:

### 1. Restate and tighten the user request

- Extract **intent** (what must change or be produced).
- List **non-negotiables** (stack, patterns, files, invariants).
- Note **explicit exclusions** (what must not happen).

### 2. Bind to context

Use whatever is available in the conversation or workspace (open files, rules,
skills, prior decisions):

- **Project constraints**: architecture rules, testing policy, auth/data
  patterns.
- **Relevant paths/modules**: only name what matters for the task.
- **Definitions**: if the user uses ambiguous terms, resolve them in one line in
  the prompt (or mark `ASSUMPTION:` for the downstream model to confirm).

### 3. Emit the LLM-to-LLM prompt

The deliverable is **only** the prompt for the other model (plus a one-line note
to the user if something was assumed). Use the template below.

## Output Template (Copy-Paste Ready)

Use this structure for the generated prompt body:

```markdown
## ROLE

[One line: what the downstream model is]

## OBJECTIVE

[Measurable outcome; single primary goal]

## INPUTS YOU HAVE

- [Context slice 1: repo area, rule, or fact]
- [Context slice 2]

## TASK

[Ordered steps the downstream model must follow]

## CONSTRAINTS

- MUST: [...]
- MUST NOT: [...]
- STACK / PATTERNS: [...]

## OUTPUT FORMAT

[Exact format: code blocks, JSON schema, file paths, test commands, etc.]

## VERIFICATION

[How the downstream model checks success before finishing]

## AMBIGUITY

- ASSUMPTION: [...] (only if unavoidable)
```

Adapt section headings if the task is trivial, but **never** drop OBJECTIVE,
CONSTRAINTS, OUTPUT FORMAT, and VERIFICATION for non-trivial work.

## Quality Bar (Prompt Engineering)

- **Specificity**: Names, paths, and behaviors beat vague adjectives.
- **Scope control**: One primary objective; secondary goals only if clearly
  separable.
- **Failure modes**: Mention what to avoid (security, breaking changes, wrong
  layer).
- **Alignment**: If this monorepo has documented invariants (auth, logging,
  actions, migrations), **surface them in CONSTRAINTS** when relevant—do not
  assume the other model has seen this chat.

## Anti-Patterns

- Producing a "nice email" or document for humans instead of an execution
  contract for a model.
- Mixing languages inside the generated prompt.
- Omitting verification when code or config is produced.
- Dumping entire files verbatim; **summarize** binding constraints instead.
