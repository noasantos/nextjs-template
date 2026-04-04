# Cursor Agent Skills (project)

This directory mirrors the canonical skill definitions in
`skills/<skill-name>/SKILL.md` using **one folder per skill**, as required by
[Cursor Agent Skills](https://www.cursor.com/docs/context/skills).

## Layout

```
.cursor/skills/<skill-name>/SKILL.md  →  ../../../skills/<skill-name>/SKILL.md
```

Each `SKILL.md` includes YAML frontmatter:

- `name` — lowercase identifier (must match the folder name)
- `description` — what the skill does and when to use it (used for discovery)

## Usage

- In Agent chat: `/skill-name` or attach the skill via the Skills UI.
- Source of truth for edits: `skills/<skill-name>/SKILL.md` (then this symlink
  stays in sync).

**Last updated:** 2026-04-04
