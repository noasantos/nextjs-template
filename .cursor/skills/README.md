# Cursor Agent Skills (project)

This directory mirrors the canonical skill definitions in
`skills/<skill-name>/SKILL.md` using **one folder per skill**, as required by
[Cursor Agent Skills](https://www.cursor.com/docs/context/skills).

## Layout

```
.cursor/skills/<skill-name>/SKILL.md  →  ../../../skills/<skill-name>/SKILL.md
```

Folder name **must** match YAML `name:` in the frontmatter (Cursor requirement).

Each `SKILL.md` includes YAML frontmatter:

- `name` — lowercase identifier (must match the folder name)
- `description` — what the skill does and when to use it (used for discovery)

## Keeping `.cursor/skills` in sync

Canonical content lives in **`skills/<skill-name>/SKILL.md`**. After adding or
renaming a skill, regenerate symlinks from the repo root:

```bash
pnpm skills:sync-cursor
```

(`scripts/skills/sync-cursor-skills.sh` creates `mkdir -p` + `ln -sf` for every
`skills/*/SKILL.md`.)

## Usage

- In Agent chat: `/skill-name` or attach the skill via the Skills UI.
- **Edit only** `skills/<skill-name>/SKILL.md`; never replace the symlink target
  with a standalone copy here.

**Last updated:** 2026-04-06
