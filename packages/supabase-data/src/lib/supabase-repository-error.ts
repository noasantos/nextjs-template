class SupabaseRepositoryError extends Error {
  constructor(
    message: string,
    options?: {
      cause?: unknown
    }
  ) {
    super(message, options)
    this.name = "SupabaseRepositoryError"
  }
}

export { SupabaseRepositoryError }
