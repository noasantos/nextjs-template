# `@workspace/brand`

Pacote para **componentes de UI de produto** (composições, padrões visuais da
marca, blocos reutilizáveis entre apps) construídos **em cima** de
[`@workspace/ui`](../ui/README.md).

## ThemeProvider — implementação em `@workspace/core`

O **`ThemeProvider`** (`next-themes` + atalho de teclado) está implementado em
**`@workspace/core`**.

- **Import preferido:** `@workspace/core/components/theme-provider`
- **Compatibilidade:** `@workspace/brand/components/theme-provider` continua a
  existir e **reexporta** o mesmo módulo (não duplica código).

Documentação:
[docs/architecture/core-package.md](../../docs/architecture/core-package.md).

## O que entra aqui

- Componentes e layouts partilhados entre várias aplicações (composições acima
  de `@workspace/ui`)
- Estilização e variância de produto que **não** pertencem ao pacote shadcn
- Novos ficheiros em `src/components/` com subpath em `package.json` → `exports`

## O que **não** entra aqui

- Primitivos shadcn → [`packages/ui`](../ui/README.md) **via CLI**
- Providers/hooks de infra transversal (React Query, tema base, etc.) →
  [`@workspace/core`](../core/README.md)
- Lógica só de uma app → `apps/<nome>/...`

## Estrutura em `src/`

| Pasta         | Uso                                              |
| ------------- | ------------------------------------------------ |
| `_providers/` | Apenas reexport do theme (implementação no core) |
| `components/` | UI de produto quando existir                     |

## Dependências

- `@workspace/core` — ThemeProvider canónico
- `@workspace/ui` — primitivos partilhados (quando composições precisarem)

## Comandos

```bash
pnpm --filter @workspace/brand lint
pnpm --filter @workspace/brand typecheck
```

Ver também [AGENTS.md](./AGENTS.md).
