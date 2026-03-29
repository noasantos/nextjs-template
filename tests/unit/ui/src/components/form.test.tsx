import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { useForm } from "react-hook-form"
import { describe, expect, it, vi } from "vitest"

import { Input } from "@workspace/ui/components/input"

import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
  useFormField,
} from "@workspace/ui/components/form"

function MisplacedUseFormField() {
  useFormField()
  return null
}

function TestForm({
  defaultValues = { email: "" },
  onSubmit = vi.fn(),
}: {
  defaultValues?: { email: string }
  onSubmit?: (data: { email: string }) => void
}) {
  const form = useForm({ defaultValues })
  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="email"
          rules={{ required: "Campo obrigatório" }}
          render={({ field }) => (
            <FormItem data-testid="item">
              <FormLabel>E-mail</FormLabel>
              <FormControl>
                <Input placeholder="you@example.com" {...field} />
              </FormControl>
              <FormDescription>Descrição do campo</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        <button type="submit">Enviar</button>
      </form>
    </Form>
  )
}

function FormWithStaticMessage() {
  const form = useForm({ defaultValues: { email: "ok@example.com" } })
  return (
    <Form {...form}>
      <FormField
        control={form.control}
        name="email"
        render={() => (
          <FormItem>
            <FormMessage>Aviso estático</FormMessage>
          </FormItem>
        )}
      />
    </Form>
  )
}

describe("Form primitives (react-hook-form)", () => {
  it("shows validation message when submit fails rules", async () => {
    const user = userEvent.setup()
    render(<TestForm />)

    await user.click(screen.getByRole("button", { name: "Enviar" }))

    expect(await screen.findByText("Campo obrigatório")).toHaveAttribute(
      "data-slot",
      "form-message"
    )
  })

  it("renders description and form item structure", () => {
    render(<TestForm defaultValues={{ email: "a@b.co" }} />)

    expect(screen.getByText("Descrição do campo")).toHaveAttribute(
      "data-slot",
      "form-description"
    )
    expect(screen.getByTestId("item")).toHaveAttribute("data-slot", "form-item")
  })

  it("FormMessage renders static children when there is no field error", () => {
    render(<FormWithStaticMessage />)
    expect(screen.getByText("Aviso estático")).toBeInTheDocument()
  })
})

describe("useFormField guard rails", () => {
  it("throws when useFormField is used outside FormField", () => {
    function OutsideFormField() {
      const form = useForm({ defaultValues: { email: "" } })
      return (
        <Form {...form}>
          <FormItem>
            <MisplacedUseFormField />
          </FormItem>
        </Form>
      )
    }

    expect(() => render(<OutsideFormField />)).toThrow(
      /useFormField deve ser usado dentro de <FormField>/
    )
  })

  it("throws when useFormField is used outside FormItem", () => {
    function Test() {
      const form = useForm({ defaultValues: { email: "" } })
      return (
        <Form {...form}>
          <FormField
            control={form.control}
            name="email"
            render={() => <FormLabel>Sem item</FormLabel>}
          />
        </Form>
      )
    }

    expect(() => render(<Test />)).toThrow(
      /useFormField deve ser usado dentro de <FormItem>/
    )
  })
})
