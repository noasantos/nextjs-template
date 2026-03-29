import { render, screen } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FieldLegend,
  FieldSeparator,
  FieldSet,
  FieldTitle,
} from "@workspace/ui/components/field"

describe("Field primitives (admin forms)", () => {
  it("renders FieldSet with legend and grouped fields", () => {
    render(
      <FieldSet data-testid="fs">
        <FieldLegend variant="legend">Secção</FieldLegend>
        <FieldGroup data-testid="fg">
          <Field data-testid="f" orientation="horizontal">
            <FieldLabel htmlFor="x">Nome</FieldLabel>
            <FieldContent>
              <FieldTitle>Título</FieldTitle>
              <FieldDescription>Ajuda</FieldDescription>
            </FieldContent>
          </Field>
        </FieldGroup>
      </FieldSet>
    )

    expect(screen.getByTestId("fs")).toHaveAttribute("data-slot", "field-set")
    expect(screen.getByText("Secção")).toHaveAttribute("data-variant", "legend")
    expect(screen.getByTestId("f")).toHaveAttribute(
      "data-orientation",
      "horizontal"
    )
    expect(screen.getByText("Ajuda")).toHaveAttribute(
      "data-slot",
      "field-description"
    )
  })

  it("FieldError renders children when provided", () => {
    render(<FieldError>Erro direto</FieldError>)
    expect(screen.getByRole("alert")).toHaveTextContent("Erro direto")
  })

  it("FieldError renders a single message from errors array", () => {
    render(<FieldError errors={[{ message: "Único" }]} />)
    expect(screen.getByRole("alert")).toHaveTextContent("Único")
  })

  it("FieldError renders a list for multiple distinct errors", () => {
    render(
      <FieldError
        errors={[{ message: "A" }, { message: "B" }, { message: "A" }]}
      />
    )
    const alert = screen.getByRole("alert")
    expect(alert.querySelectorAll("li")).toHaveLength(2)
    expect(alert).toHaveTextContent("A")
    expect(alert).toHaveTextContent("B")
  })

  it("FieldError returns null when there is no content", () => {
    const { container } = render(<FieldError errors={[]} />)
    expect(container).toBeEmptyDOMElement()
  })

  it("FieldSeparator renders optional label over the separator", () => {
    render(<FieldSeparator>ou</FieldSeparator>)
    expect(screen.getByText("ou")).toHaveAttribute(
      "data-slot",
      "field-separator-content"
    )
  })
})
