import { z } from "zod"

const emailOtpTypeSchema = z.enum([
  "signup",
  "invite",
  "magiclink",
  "recovery",
  "email_change",
  "email",
])

const optionalRedirectToSchema = z.string().trim().min(1).nullable().optional()

const authCallbackSearchParamsSchema = z.object({
  code: z.string().trim().min(1),
  redirectTo: optionalRedirectToSchema,
})

const authConfirmSearchParamsSchema = z.object({
  redirectTo: optionalRedirectToSchema,
  tokenHash: z.string().trim().min(1),
  type: emailOtpTypeSchema,
})

const authLogoutSearchParamsSchema = z.object({
  redirectTo: optionalRedirectToSchema,
})

export {
  authCallbackSearchParamsSchema,
  authConfirmSearchParamsSchema,
  authLogoutSearchParamsSchema,
  emailOtpTypeSchema,
}
