import { render, screen } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@workspace/ui/components/table"

describe("Table primitives", () => {
  it("renders table inside a scroll container with caption", () => {
    render(
      <Table data-testid="tbl">
        <TableCaption>Legenda</TableCaption>
        <TableHeader>
          <TableRow>
            <TableHead>A</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow>
            <TableCell>1</TableCell>
          </TableRow>
        </TableBody>
        <TableFooter>
          <TableRow>
            <TableCell colSpan={1}>Rodapé</TableCell>
          </TableRow>
        </TableFooter>
      </Table>
    )

    expect(screen.getByTestId("tbl")).toBeInTheDocument()
    expect(screen.getByText("Legenda")).toHaveAttribute("data-slot", "table-caption")
    expect(screen.getByText("1")).toHaveAttribute("data-slot", "table-cell")
    expect(screen.getByText("Rodapé")).toBeInTheDocument()
  })
})
