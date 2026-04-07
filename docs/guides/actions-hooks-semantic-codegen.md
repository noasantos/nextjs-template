# Actions & Hooks Semantic Codegen (Phase B)

**Pipeline de codegen semântico** para preencher automaticamente os TODOs
deixados pelo codegen determinístico (Phase A).

## Visão Geral

O processo de codegen acontece em duas fases:

### Phase A - Determinístico

- **Script:** `pnpm codegen:actions-hooks --write`
- **O que faz:** Gera estrutura, imports, auth, logging
- **Resultado:** Stubs com TODOs nos lugares certos
- **Limitação:** Não sabe as regras de negócio específicas

### Phase B - Semântico → Determinístico

- **Scripts:**
  - `pnpm codegen:actions-semantic-plan` (LLM/analista)
  - `pnpm codegen:actions-fill-todos` (determinístico)
- **O que faz:** Analisa semanticamente e preenche TODOs
- **Resultado:** Implementações completas e tipadas

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│  Phase A (Determinístico)                                   │
│  pnpm codegen:actions-hooks --write                         │
│                                                             │
│  Gera:                                                      │
│  - Estrutura de arquivos                                    │
│  - Imports corretos                                         │
│  - Autenticação (getClaims)                                 │
│  - Logging estruturado                                      │
│  - TODOs nos lugares certos                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase B.1 (Semântico - LLM)                                │
│  pnpm codegen:actions-semantic-plan                         │
│                                                             │
│  Gera: config/action-semantic-plan.json                     │
│  - Input schemas específicos                                │
│  - Output schemas                                           │
│  - Repository calls                                         │
│  - Regras de auth                                           │
│  - Metadata de logging                                      │
│  - Cache invalidation                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase B.2 (Determinístico)                                 │
│  pnpm codegen:actions-fill-todos --plan ...                 │
│                                                             │
│  Gera: Código TypeScript completo                           │
│  - Lê JSON semântico                                        │
│  - Aplica templates                                         │
│  - Preenche TODOs                                           │
│  - Gera código final                                        │
└─────────────────────────────────────────────────────────────┘
```

## Workflow

### 1. Gerar Phase A (Stubs)

```bash
pnpm codegen:actions-hooks --write
```

Isso gera ~290 actions + ~146 hooks com TODOs.

### 2. Analisar Semanticamente (LLM)

```bash
pnpm codegen:actions-semantic-plan
```

**Output:** `config/action-semantic-plan.json`

Este JSON contém o plano semântico para cada action.

**Exemplo de entrada JSON:**

```json
{
  "version": 1,
  "generatedAt": "2026-04-07T10:00:00.000Z",
  "actions": [
    {
      "domainId": "catalog",
      "table": "reference_values",
      "method": "list",
      "actionName": "listReferenceValuesAction",
      "inputSchema": {
        "zodSchema": "z.object({\n  scope: z.string().optional(),\n  limit: z.number().int().positive().max(100).default(50),\n  offset: z.number().int().nonnegative().default(0),\n})",
        "typeName": "ListReferenceValuesInput",
        "fields": [
          {
            "name": "scope",
            "type": "string",
            "validation": [],
            "required": false,
            "description": "Filter by scope"
          },
          {
            "name": "limit",
            "type": "number",
            "validation": ["int", "positive", "max(100)"],
            "required": false,
            "description": "Pagination limit"
          }
        ]
      },
      "outputSchema": {
        "returnType": "Promise<{ data: ReferenceValuesDTO[]; total: number }>",
        "fields": [
          { "name": "data", "type": "ReferenceValuesDTO[]", "source": "row" },
          { "name": "total", "type": "number", "source": "computed" }
        ]
      },
      "repositoryCall": {
        "method": "list",
        "arguments": [
          "{ scope: validated.scope, limit: validated.limit, offset: validated.offset }"
        ],
        "errorHandling": true
      },
      "auth": {
        "tenantScoping": false,
        "customChecks": []
      },
      "logging": {
        "successMetadata": [
          "count: data.length",
          "total",
          "scope: validated.scope"
        ],
        "errorMetadata": ["input: JSON.stringify(input)"]
      },
      "cacheInvalidation": {
        "invalidateKeys": ["[\"catalog\",\"reference-values\"]"],
        "optimisticUpdate": false
      },
      "notes": [
        "✅ Catalog tables are public read-only",
        "⚠️ Consider caching for frequently accessed reference values"
      ]
    }
  ],
  "meta": {
    "generator": "llm-agent",
    "modelUsed": "llm-analyst",
    "confidence": "high",
    "requiresHumanReview": true
  }
}
```

### 3. Preencher TODOs (Determinístico)

```bash
pnpm codegen:actions-fill-todos --plan config/action-semantic-plan.json
```

Isso lê o JSON e gera código TypeScript completo.

**Resultado:**

```typescript
"use server"

import { z } from "zod"

import { requireAuth } from "@workspace/supabase-data/lib/auth/require-auth"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { ReferenceValuesSupabaseRepository } from "@workspace/supabase-data/modules/catalog/infrastructure/repositories/reference-values-supabase.repository.codegen"
import { logServerEvent } from "@workspace/logging/server"

/**
 * Input schema for ListReferenceValuesAction
 */
const ListReferenceValuesInputSchema = z.object({
  scope: z.string().optional(),
  limit: z.number().int().positive().max(100).default(50),
  offset: z.number().int().nonnegative().default(0),
})

/**
 * Input type for ListReferenceValuesAction
 */
export type ListReferenceValuesInput = z.infer<
  typeof ListReferenceValuesInputSchema
>

/**
 * ListReferenceValuesAction Server Action
 *
 * @param input - Action input
 */
export async function listReferenceValuesAction(
  input: ListReferenceValuesInput
): Promise<{ data: ReferenceValuesDTO[]; total: number }> {
  const startedAt = Date.now()

  // 1. Auth check (SSOT via requireAuth)
  const claims = await requireAuth({
    action: "list_reference-values",
  })

  const userId = claims.sub

  try {
    // 2. Validate input
    const validated = ListReferenceValuesInputSchema.parse(input)

    // 3. Create auth client + repository
    const supabase = await createServerAuthClient()
    const repository = new ReferenceValuesSupabaseRepository(supabase)

    // 4. Execute operation
    const result = await repository.list({
      scope: validated.scope,
      limit: validated.limit,
      offset: validated.offset,
    })

    // 5. Log success
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "catalog.reference-values.list",
      durationMs: Date.now() - startedAt,
      eventFamily: "action.lifecycle",
      eventName: "list_reference-values_success",
      operation: "list",
      operationType: "action",
      outcome: "success",
      count: result.length,
      total: result.length,
      scope: validated.scope,
      service: "supabase-data",
    })

    // 6. Return result
    return { data: result, total: result.length }
  } catch (error) {
    // 7. Log error
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "catalog.reference-values.list",
      durationMs: Date.now() - startedAt,
      eventFamily: "action.lifecycle",
      eventName: "list_reference-values_failed",
      operation: "list",
      operationType: "action",
      outcome: "failure",
      error,
      input: JSON.stringify(input),
      service: "supabase-data",
    })

    throw error
  }
}
```

## Como Funciona a Análise Semântica

### O LLM/Analista Deve Considerar:

1. **Schema do Banco:**
   - Tipos de colunas (string, number, boolean, etc.)
   - Constraints (NOT NULL, UNIQUE, etc.)
   - FKs e relacionamentos

2. **Regras de Negócio:**
   - Quais campos são required vs optional?
   - Validações específicas (ex: email, CPF, etc.)
   - Regras de tenant isolation

3. **Auth & Authorization:**
   - Precisa de role específico?
   - Tenant scoping necessário?
   - Custom checks?

4. **Performance:**
   - Paginação necessária?
   - Cache invalidation strategy
   - Optimistic updates seguros?

5. **Logging & Observability:**
   - Quais metadados são úteis para debug?
   - Quais IDs devem ser logados?
   - Correlation IDs?

## Validação

Após gerar o código:

```bash
# Typecheck
pnpm typecheck

# Lint
pnpm lint

# Forbidden patterns
pnpm check:forbidden
```

## Related

- [Backend codegen](./backend-codegen.md)
- [Data access pattern](../architecture/data-access-pattern.md)
- [LLM-to-LLM prompt](./llm-prompt-action-hook-codegen.md)
