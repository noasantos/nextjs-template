import { z } from "zod"

import { AUTH_ROLES } from "@workspace/supabase-auth/shared/auth-role"

const UserRoleDTOSchema = z.object({
  createdAt: z.string(),
  role: z.enum(AUTH_ROLES),
  userId: z.string().uuid(),
})

type UserRoleDTO = z.infer<typeof UserRoleDTOSchema>

export { UserRoleDTOSchema, type UserRoleDTO }
