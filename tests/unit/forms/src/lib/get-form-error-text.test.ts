import { describe, expect, it } from "vitest"

import { getFormErrorText } from "@workspace/forms/lib/get-form-error-text"

describe("getFormErrorText", () => {
  it("returns undefined for empty values", () => {
    expect(getFormErrorText(undefined)).toBeUndefined()
    expect(getFormErrorText(null)).toBeUndefined()
  })

  it("returns string errors directly", () => {
    expect(getFormErrorText("Required field")).toBe("Required field")
  })

  it("returns the first nested message from arrays", () => {
    expect(
      getFormErrorText([null, { message: "" }, { message: "Nested failure" }])
    ).toBe("Nested failure")
  })

  it("returns object message values when present", () => {
    expect(getFormErrorText({ message: "Validation failed" })).toBe(
      "Validation failed"
    )
  })
})
