import { z } from "zod"

const emailSchema = z.object({
  email: z
    .string()
    .trim()
    .min(1, "Indique o e-mail.")
    .email("Indique um endereço de e-mail válido.")
    .transform((value) => value.toLowerCase()),
})

const passwordSchema = z
  .string()
  .min(8, "A palavra-passe deve ter pelo menos 8 caracteres.")

const signInSchema = emailSchema.extend({
  password: passwordSchema,
})

const passwordResetSchema = z
  .object({
    password: passwordSchema,
    confirmPassword: z.string().min(1, "Confirme a palavra-passe."),
  })
  .refine((value) => value.password === value.confirmPassword, {
    message: "As palavras-passe têm de coincidir.",
    path: ["confirmPassword"],
  })

const mfaCodeSchema = z.object({
  code: z
    .string()
    .trim()
    .regex(
      /^\d{6}$/,
      "Introduza o código de 6 dígitos da aplicação de autenticação."
    ),
})

const signInDefaultValues: z.input<typeof signInSchema> = {
  email: "",
  password: "",
}

const emailDefaultValues: z.input<typeof emailSchema> = {
  email: "",
}

const passwordResetDefaultValues: z.input<typeof passwordResetSchema> = {
  confirmPassword: "",
  password: "",
}

const mfaCodeDefaultValues: z.input<typeof mfaCodeSchema> = {
  code: "",
}

export {
  emailDefaultValues,
  emailSchema,
  mfaCodeDefaultValues,
  mfaCodeSchema,
  passwordResetDefaultValues,
  passwordResetSchema,
  signInDefaultValues,
  signInSchema,
}
