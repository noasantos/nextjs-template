import type { ColumnDef } from "@tanstack/react-table"
import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { describe, expect, it } from "vitest"

import { DataTable } from "@workspace/ui/components/data-table"

type Row = { id: string; name: string }

const columns: ColumnDef<Row, string>[] = [
  {
    accessorKey: "name",
    header: "Nome",
    id: "name",
  },
]

describe("DataTable", () => {
  it("renders rows and header labels", () => {
    const data: Row[] = [{ id: "1", name: "Alice" }]
    render(<DataTable columns={columns} data={data} />)

    expect(screen.getByText("Nome")).toBeInTheDocument()
    expect(screen.getByText("Alice")).toBeInTheDocument()
  })

  it("shows empty state when there is no data", () => {
    render(<DataTable columns={columns} data={[]} emptyMessage="Nada por aqui" />)

    expect(screen.getByText("Nada por aqui")).toBeInTheDocument()
  })

  it("filters rows when filterColumnId is set", async () => {
    const user = userEvent.setup()
    const data: Row[] = [
      { id: "1", name: "Alice" },
      { id: "2", name: "Bob" },
    ]
    render(
      <DataTable
        columns={columns}
        data={data}
        filterColumnId="name"
        filterPlaceholder="Filtrar nome"
      />
    )

    const input = screen.getByPlaceholderText("Filtrar nome")
    await user.type(input, "Ali")

    expect(screen.getByText("Alice")).toBeInTheDocument()
    expect(screen.queryByText("Bob")).not.toBeInTheDocument()
  })

  it("paginates with next and previous controls", async () => {
    const user = userEvent.setup()
    const data: Row[] = Array.from({ length: 15 }, (_, i) => ({
      id: String(i),
      name: `User ${i}`,
    }))

    render(<DataTable columns={columns} data={data} />)

    const next = screen.getByRole("button", { name: "Seguinte" })
    const prev = screen.getByRole("button", { name: "Anterior" })

    expect(prev).toBeDisabled()
    expect(next).not.toBeDisabled()

    await user.click(next)

    expect(prev).not.toBeDisabled()
  })
})
