// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import type { CalendarChangeLogDTO } from "@workspace/supabase-data/modules/calendar/domain/dto/calendar-change-log.dto.codegen"

export interface CalendarChangeLogListParams {
  limit?: number
  offset?: number
}

export interface CalendarChangeLogListResult {
  rows: CalendarChangeLogDTO[]
}

interface CalendarChangeLogRepository {
  findById(id: string): Promise<CalendarChangeLogDTO | null>
  list(params: CalendarChangeLogListParams): Promise<CalendarChangeLogListResult>
  insert(data: Partial<CalendarChangeLogDTO>): Promise<CalendarChangeLogDTO>
  update(id: string, patch: Partial<CalendarChangeLogDTO>): Promise<CalendarChangeLogDTO>
  delete(id: string): Promise<void>
}

export { type CalendarChangeLogRepository }
