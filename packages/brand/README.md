# `@workspace/brand`

Pacote partilhado para **componentes de UI de produto** (composições, padrões visuais da marca, blocos reutilizáveis entre apps) construídos **em cima** de [`@workspace/ui`](../ui/README.md).

## O que entra aqui

- Componentes e layouts partilhados entre várias aplicações
- Composições que importam primitivos de `@workspace/ui/components/*`
- Estilização e variáncia de produto que **não** pertencem ao pacote shadcn
- **`ThemeProvider`** (`@workspace/brand/components/theme-provider`) — `next-themes` + atalho de tema para todas as apps

## O que **não** entra aqui

- Primitivos shadcn novos ou alterados manualmente → isso é só [`packages/ui`](../ui/README.md) **via CLI**
- Lógica só de uma app → `apps/<nome>/...`

## Estrutura em `src/`

| Pasta | Uso |
|-------|-----|
| `_providers/` | Providers de marca (ex.: `theme-provider.tsx`) |
| `_hooks/` | Hooks partilhados entre apps (quando existirem) |
| `components/` | Outros componentes de UI de produto (quando não forem só “provider”) |

## Como adicionar um componente ou provider

1. Colocar o ficheiro na pasta adequada (`_providers`, `_hooks` ou `components/`).
2. Declarar um subpath em `package.json` → `exports` (ex.: `"./components/<nome>": "./src/components/<nome>.tsx"`).
3. Consumir nas apps com import directo do subpath — **sem** barrel (`export * from` em `index.ts` público).

## Dependências

- `@workspace/ui` — primitivos shadcn/Tailwind partilhados
- `next-themes` — usado pelo `ThemeProvider` de marca

## Comandos

```bash
pnpm --filter @workspace/brand lint
pnpm --filter @workspace/brand typecheck
```

Ver também [AGENTS.md](./AGENTS.md) e a regra global em [AGENTS.md](../../AGENTS.md).
