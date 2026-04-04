# Meta-Prompt for Skill Updates

## Purpose

Automatically update all skills to stay synchronized with:

- Golden Rules in `docs/standards/rules/`
- Architecture docs in `docs/architecture/`
- Best practices in `docs/guides/`

## Trigger

Run when:

- Golden Rules are updated
- Architecture docs change
- Monthly maintenance
- User reports outdated skill

## Update Process

### **1. Scan Documentation**

```bash
# Read all Golden Rules
find docs/standards/rules/ -name "*.md" -type f

# Read architecture docs
find docs/architecture/ -name "*.md" -type f

# Read guides
find docs/guides/ -name "*.md" -type f
```

### **2. Compare with Skills**

For each skill in `skills/*/SKILL.md`:

1. **EXTRACT** rule references
2. **VERIFY** rules still exist
3. **CHECK** for updated content
4. **IDENTIFY** gaps

### **3. Update Skills**

For each skill:

```markdown
# {Skill Name}

## Purpose

[Update if docs changed]

## When to Trigger

[Update based on new patterns]

## Skill Instructions

[Update code examples]

## Examples

[Update with current best practices]

## Related Skills

[Update cross-references]

## References

- **[GR-XXX: Rule Name](../../docs/standards/rules/{file}.md)** ← Verify links
- **[Architecture Guide](../../docs/architecture/{file}.md)** ← Verify links

---

**Skill Version:** {auto-increment} **Last Updated:** {current-date}
**Auto-Update:** Enabled via meta-prompt
```

### **4. Validate**

```bash
# Check all skill links work
find skills/ -name "SKILL.md" -exec grep -l "\.md" {} \;

# Verify skill structure
for skill in skills/*/SKILL.md; do
  echo "Checking $skill"
  # Verify sections exist
  grep -q "## Purpose" $skill || echo "Missing Purpose section"
  grep -q "## When to Trigger" $skill || echo "Missing When to Trigger section"
  grep -q "## Skill Instructions" $skill || echo "Missing Skill Instructions section"
  grep -q "## References" $skill || echo "Missing References section"
done
```

### **5. Generate Report**

```markdown
# Skill Update Report

**Date:** 2026-04-04 **Skills Updated:** 15 **Skills Created:** 0 **Skills
Deprecated:** 0

## Changes

### server-action-template

- Updated logging examples (GR-005)
- Added JSDoc requirements (GR-021)
- Updated ActionResult pattern (GR-017)

### test-location-guide

- Added RLS test emphasis (GR-016)
- Updated decision tree
- Added mirror structure examples

## Validation

✅ All skill links verified ✅ All sections present ✅ All examples current ✅
All rules referenced correctly
```

## AI Agent Instructions

When running skill updates:

1. **READ** all Golden Rules
2. **COMPARE** with skill content
3. **UPDATE** outdated sections
4. **VERIFY** all links work
5. **INCREMENT** version number
6. **GENERATE** update report
7. **REMIND** user of changes

## Automation

Add to CI/CD:

```yaml
# .github/workflows/skill-update.yml
name: Update Skills

on:
  schedule:
    - cron: "0 0 1 * *" # Monthly
  push:
    paths:
      - "docs/standards/rules/**"
      - "docs/architecture/**"

jobs:
  update-skills:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update Skills
        run: pnpm skills:update
      - name: Commit Changes
        run: |
          git config --local user.email "bot@template.com"
          git config --local user.name "Skill Bot"
          git add skills/
          git commit -m "chore: auto-update skills" || echo "No changes"
          git push
```

## Manual Trigger

```bash
# Update all skills
pnpm skills:update

# Update specific skill
pnpm skills:update -- server-action-template

# Validate skills
pnpm skills:validate

# Generate report
pnpm skills:report
```

---

**Meta-Prompt Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled
