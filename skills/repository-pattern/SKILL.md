---
name: repository-pattern
description: >-
  Implements repository pattern and module layout in packages/supabase-data per
  GR-008 and GR-009. Use when adding database access, repositories, or new
  domain modules.
---

# Repository Pattern Skill

## Purpose

Implement the Repository Pattern correctly following GR-009 (Repository Pattern)
and GR-008 (Single Responsibility).

## When to Trigger

Auto-trigger when user:

- Wants to access database
- Mentions "repository" or "data access"
- Creates new domain module

## Skill Instructions

### **1. Module Structure**

```
packages/supabase-data/src/modules/{module}/
├── domain/
│   ├── dto/
│   │   └── {entity}.dto.ts
│   ├── schemas/
│   │   └── {entity}.schemas.ts
│   └── ports/
│       └── {entity}-repository.port.ts
└── infrastructure/
    ├── mappers/
    │   └── {entity}.mapper.ts
    └── repositories/
        └── {entity}-supabase.repository.ts
```

### **2. Repository Implementation**

```typescript
import type { Database } from "@workspace/supabase-infra/types/database"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"
import type { {Entity}DTO } from "../domain/dto/{entity}.dto"

export class {Entity}SupabaseRepository {
  constructor(private supabase: TypedSupabaseClient) {}

  async findById(id: string): Promise<{Entity}DTO | null> {
    const { data, error } = await this.supabase
      .from("{table}")
      .select()
      .eq("id", id)
      .single()

    if (error && error.code !== "PGRST116") throw error
    if (!data) return null

    return this.mapToDTO(data)
  }

  async findAll(): Promise<{Entity}DTO[]> {
    const { data, error } = await this.supabase
      .from("{table}")
      .select()
      .order("created_at", { ascending: false })

    if (error) throw error
    return data.map((d) => this.mapToDTO(d))
  }

  private mapToDTO(data: any): {Entity}DTO {
    return {
      id: data.id,
      // ... map fields
    }
  }
}
```

### **3. Enforce Rules**

- ✅ **GR-009**: Always use repositories
- ✅ **GR-008**: One repository per entity
- ✅ **Type Safety**: Use Database types
- ✅ **No Direct Access**: Never from apps layer

## Examples

### **User Request**

```
"Create a repository for tasks"
```

### **Skill Response**

1. **CREATE structure:**

   ```
   packages/supabase-data/src/modules/tasks/
   ├── domain/dto/task.dto.ts
   └── infrastructure/repositories/task-supabase.repository.ts
   ```

2. **IMPLEMENT repository:**
   - Define DTO
   - Create repository class
   - Add CRUD methods
   - Map to DTO

3. **CREATE tests:**
   ```
   tests/unit/supabase-data/modules/tasks/task-supabase.repository.test.ts
   ```

## Related Skills

- **[server-action-template](../server-action-template/)** - Use repositories in
  actions
- **[test-generator](../test-generator/)** - Test repositories
- **[single-responsibility](../single-responsibility/)** - One repo per entity

## References

- **[GR-009: Repository Pattern](../../docs/standards/rules/repository-pattern.md)**
- **[GR-008: Single Responsibility](../../docs/standards/rules/single-responsibility.md)**
- **[Architecture Layers](../../docs/architecture/layers.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
