# `@workspace/core` — pacote comum do monorepo

Este documento é a **fonte de verdade** para o que entra em `packages/core`,
como os apps devem consumir, e como isso se relaciona com os outros pacotes
(`@workspace/ui`, `@workspace/brand`, etc.).

## Objetivo

`@workspace/core` concentra **infraestrutura de front-end partilhada** entre
todas as apps:

- **Providers** — React Query, tema (`next-themes`), composição com
  `@workspace/ui` (Toaster, Tooltip)
- **Componentes** — peças reutilizáveis que não são primitives shadcn (ex.:
  `ThemeProvider` com atalho de teclado)
- **Hooks** — utilitários transversais (ex.: `useMounted` para evitar mismatch
  de hidratação)

Regra mental: **se mais de uma app precisa do mesmo comportamento**, o código
deve viver em `packages/core` (ou noutro pacote de domínio claro), **não**
copiado em `apps/`.

## O que **não** vai no core

| Conteúdo                                                              | Onde colocar                                                                                                                |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Primitives / shadcn                                                   | `@workspace/ui` (CLI apenas; ver `packages/ui/AGENTS.md`)                                                                   |
| Auth, sessão, Supabase                                                | `@workspace/supabase-auth`, `@workspace/supabase-data`, `@workspace/supabase-infra`                                         |
| Formulários partilhados                                               | `@workspace/forms`                                                                                                          |
| Logging estruturado                                                   | `@workspace/logging`                                                                                                        |
| UI de produto “marca” escrita à mão (composições acima de primitives) | `@workspace/brand` **ou** novos ficheiros em `packages/core/src/components/` se forem infra transversal — ver secção abaixo |
| Lógica de **uma** app só                                              | `apps/<nome>/`                                                                                                              |

## Estrutura de pastas (`packages/core/src`)

```
src/
├── providers/
│   ├── app-providers.provider.tsx   # AppProviders (Query + Theme + Tooltip + Toaster)
│   └── query-client.ts              # createQueryClient, getBrowserQueryClient
├── components/
│   └── theme-provider.component.tsx # ThemeProvider + useTheme (next-themes + atalho "d")
└── hooks/
    └── use-mounted.hook.ts          # Hidratação segura
```

**Sem `index.ts` barrel** — cada módulo exposto tem entrada explícita em
`package.json` → `exports` (alinhado com GR-001).

## Exports (`package.json`)

| Import                                      | Ficheiro                                      |
| ------------------------------------------- | --------------------------------------------- |
| `@workspace/core/providers/app`             | `src/providers/app-providers.provider.tsx`    |
| `@workspace/core/providers/query-client`    | `src/providers/query-client.ts`               |
| `@workspace/core/components/theme-provider` | `src/components/theme-provider.component.tsx` |
| `@workspace/core/hooks/use-mounted`         | `src/hooks/use-mounted.hook.ts`               |

## Uso nas apps

### Layout raiz

```tsx
// apps/example/app/_providers/app-providers.example.tsx
"use client"

import type { ReactNode } from "react"
import { AppProviders as WorkspaceAppProviders } from "@workspace/core/providers/app"

export function AppProviders({ children }: { children: ReactNode }) {
  return <WorkspaceAppProviders>{children}</WorkspaceAppProviders>
}
```

O ficheiro usa o sufixo **`*.example.tsx`** porque `apps/example` é app
template: ao fazer fork, podes renomear para `app-providers.tsx` e ajustar
imports. Hooks só desta app: `app/_hooks/*.example.ts` (ver
`app/_hooks/AGENTS.md`).

### Tema num client component

```tsx
import { useTheme } from "@workspace/core/components/theme-provider"
```

### React Query (testes ou override)

```tsx
import { createQueryClient } from "@workspace/core/providers/query-client"
```

## Relação com `@workspace/brand`

O pacote `@workspace/brand` mantém **apenas** o subpath histórico:

- `@workspace/brand/components/theme-provider` → reexporta
  `@workspace/core/components/theme-provider`

Isto evita quebrar referências antigas e documentação. **Código novo deve
importar de `@workspace/core`.**

## Relação com `@workspace/ui`

`AppProviders` importa `Toaster` e `TooltipProvider` de `@workspace/ui`. O core
**depende** de `@workspace/ui`; o inverso não (ui não depende de core).

## Checklist para novos contributos

1. O código é usado (ou será) por mais do que uma app? Se não, fica na app.
2. É primitive shadcn? → `packages/ui` via CLI.
3. É provider/hook/componente de infra partilhada? → `packages/core` no sítio
   certo acima.
4. Adicionar export em `packages/core/package.json` → `exports` (sem barrel
   `index.ts`).
5. Atualizar este documento se introduzires uma categoria nova.

## Ver também

- [packages/core/AGENTS.md](../../packages/core/AGENTS.md) — guia rápido e
  comandos
- [Golden Rules — front partilhado](../standards/golden-rules.md)
- [Regra Cursor: shared-packages-first](../../.cursor/rules/shared-packages-first.mdc)
