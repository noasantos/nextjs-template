import { z } from "zod"

const ProfileDTOSchema = z.object({
  avatarUrl: z.string().nullable(),
  createdAt: z.string(),
  email: z.string().email(),
  fullName: z.string().nullable(),
  updatedAt: z.string(),
  userId: z.string().uuid(),
})

type ProfileDTO = z.infer<typeof ProfileDTOSchema>

export { ProfileDTOSchema, type ProfileDTO }
