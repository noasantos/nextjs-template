import { z } from "zod"

export type AuthFormValidationMessages = {
  emailRequired: string
  emailInvalid: string
  passwordMin: string
  confirmPasswordRequired: string
  passwordsMatch: string
  mfaCodeFormat: string
}

export function createAuthFormSchemas(t: (key: keyof AuthFormValidationMessages) => string) {
  const emailSchema = z.object({
    email: z
      .string()
      .trim()
      .min(1, t("emailRequired"))
      .email(t("emailInvalid"))
      .transform((value) => value.toLowerCase()),
  })

  const passwordSchema = z.string().min(8, t("passwordMin"))

  const signInSchema = emailSchema.extend({
    password: passwordSchema,
  })

  const passwordResetSchema = z
    .object({
      password: passwordSchema,
      confirmPassword: z.string().min(1, t("confirmPasswordRequired")),
    })
    .refine((value) => value.password === value.confirmPassword, {
      message: t("passwordsMatch"),
      path: ["confirmPassword"],
    })

  const mfaCodeSchema = z.object({
    code: z
      .string()
      .trim()
      .regex(/^\d{6}$/, t("mfaCodeFormat")),
  })

  return {
    emailSchema,
    signInSchema,
    passwordResetSchema,
    mfaCodeSchema,
    emailDefaultValues: { email: "" } satisfies z.input<typeof emailSchema>,
    signInDefaultValues: { email: "", password: "" } satisfies z.input<typeof signInSchema>,
    passwordResetDefaultValues: {
      confirmPassword: "",
      password: "",
    } satisfies z.input<typeof passwordResetSchema>,
    mfaCodeDefaultValues: { code: "" } satisfies z.input<typeof mfaCodeSchema>,
  }
}
