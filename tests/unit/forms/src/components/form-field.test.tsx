import { render, screen } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import {
  FormField,
  FormFieldDescription,
  FormFieldError,
  FormFieldLabel,
} from "@workspace/forms/components/form-field"

describe("form-field components", () => {
  it("renders state markers on the field container", () => {
    render(
      <FormField data-testid="field" disabled invalid required>
        body
      </FormField>
    )

    expect(screen.getByTestId("field")).toHaveAttribute("data-disabled", "true")
    expect(screen.getByTestId("field")).toHaveAttribute("data-invalid", "true")
    expect(screen.getByTestId("field")).toHaveAttribute("data-required", "true")
  })

  it("renders labels, descriptions, and errors", () => {
    render(
      <>
        <FormFieldLabel htmlFor="email" required>
          E-mail
        </FormFieldLabel>
        <FormFieldDescription>Descrição</FormFieldDescription>
        <FormFieldError>Erro</FormFieldError>
      </>
    )

    expect(screen.getByText("E-mail")).toBeInTheDocument()
    expect(screen.getByText("*")).toBeInTheDocument()
    expect(screen.getByText("Descrição")).toBeInTheDocument()
    expect(screen.getByRole("alert")).toHaveTextContent("Erro")
  })

  it("omits the error node when there is no message", () => {
    const { container } = render(<FormFieldError>{null}</FormFieldError>)

    expect(container).toBeEmptyDOMElement()
  })
})
