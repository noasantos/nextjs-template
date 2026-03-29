function getFormErrorText(error: unknown): string | undefined {
  if (!error) {
    return undefined
  }

  if (typeof error === "string") {
    return error
  }

  if (Array.isArray(error)) {
    for (const item of error) {
      const nestedMessage = getFormErrorText(item)

      if (nestedMessage) {
        return nestedMessage
      }
    }

    return undefined
  }

  if (typeof error === "object" && "message" in error) {
    const message = error.message

    if (typeof message === "string" && message.length > 0) {
      return message
    }
  }

  return undefined
}

export { getFormErrorText }
