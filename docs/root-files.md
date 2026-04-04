# Root Files

**Essential files only:**

```
nextjs-template/
├── .cursor/                 # Cursor IDE config
├── .gitignore               # Git ignore rules
├── .husky/                  # Git hooks
├── apps/                    # Next.js applications
├── packages/                # Shared packages
├── scripts/                 # Automation scripts
├── skills/                  # AI agent skills
├── supabase/                # Supabase config
├── tests/                   # Test directory
├── docs/                    # Documentation
├── AGENTS.md                # AI agent instructions (MAIN)
├── README.md                # Quick index
├── package.json             # Dependencies & scripts
├── pnpm-workspace.yaml      # Workspace config
├── turbo.json               # Turborepo config
├── tsconfig.json            # TypeScript config
├── .oxlintrc.json           # Oxlint config
├── .oxfmtrc.json            # Oxfmt config (single source; see docs/tools/oxlint-oxfmt.md)
└── vitest.config.mts        # Vitest config
```

**NOT in root:**

- ❌ STATUS.md (in docs/)
- ❌ TEST-CULTURE.md (in docs/culture/)
- ❌ .eslintrc.js (using oxlint)
- ❌ .prettierrc (using oxfmt)
- ❌ eslint.config.js (using oxlint)

---

**For AI Agents:** This is the clean root structure. All documentation is in
`docs/`.
