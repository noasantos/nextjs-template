/**
 * Validates skills/<name>/SKILL.md frontmatter and Cursor mirror symlinks.
 */
import { existsSync, lstatSync, readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(fileURLToPath(new URL(".", import.meta.url)), "../..")
const skillsDir = join(root, "skills")
const cursorSkillsDir = join(root, ".cursor/skills")

let errors = 0

function fail(msg: string): void {
  console.error(msg)
  errors += 1
}

for (const ent of readdirSync(skillsDir, { withFileTypes: true })) {
  if (!ent.isDirectory()) continue
  const folder = ent.name
  const skillPath = join(skillsDir, folder, "SKILL.md")
  if (!existsSync(skillPath)) continue

  const text = readFileSync(skillPath, "utf8")
  const fm = text.match(/^---\r?\n([\s\S]*?)\r?\n---/)
  if (!fm) {
    fail(`[skills] Missing YAML frontmatter: skills/${folder}/SKILL.md`)
    continue
  }
  const nameLine = fm[1].match(/^name:\s*([^\r\n]+)/m)
  if (!nameLine) {
    fail(`[skills] Missing name: in skills/${folder}/SKILL.md`)
    continue
  }
  const declared = nameLine[1].replace(/^["']|["']$/g, "").trim()
  if (declared !== folder) {
    fail(
      `[skills] Folder "${folder}" must match frontmatter name: "${declared}" (skills/${folder}/SKILL.md)`
    )
  }

  const cursorLink = join(cursorSkillsDir, folder, "SKILL.md")
  if (!existsSync(cursorLink)) {
    fail(
      `[skills] Missing Cursor mirror: .cursor/skills/${folder}/SKILL.md — run pnpm skills:sync-cursor`
    )
    continue
  }
  try {
    if (!lstatSync(cursorLink).isSymbolicLink()) {
      fail(
        `[skills] .cursor/skills/${folder}/SKILL.md must be a symlink to skills/${folder}/SKILL.md`
      )
    }
  } catch {
    fail(`[skills] Cannot stat .cursor/skills/${folder}/SKILL.md`)
  }
}

if (errors > 0) {
  process.exitCode = 1
} else {
  console.log("[skills] All SKILL.md entries validated (frontmatter + .cursor symlinks).")
}
