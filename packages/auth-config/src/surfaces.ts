/**
 * App surface definitions for this workspace.
 *
 * Defines which post-auth surfaces exist, where each one lives, and which role
 * is routed to which surface. Consumed by `@workspace/supabase-auth/shared/app-destination`.
 *
 * When adopting this template for a different product:
 *  - Rename or remove surface keys (e.g. drop `space` for a single-surface app).
 *  - Update `APP_SEGMENT_PATHS` paths to match the app's route structure.
 *  - Update `ROLE_APP_MAP` to reflect the product's role-to-surface routing rules.
 *  - Update `APP_SURFACE_LABELS` for the product's UI copy.
 *  - Set `NEXT_PUBLIC_SPACE_APP_URL` in `.env` when the `space` surface is a separate deployment.
 */
import type { AuthRole } from "@workspace/auth-config/roles"

/**
 * Named app surfaces and their default post-auth path.
 *
 * `web`   — primary app, served on the main origin.
 * `space` — professional workspace, may be deployed on a separate origin
 *           (configured via `NEXT_PUBLIC_SPACE_APP_URL`).
 */
const APP_SEGMENT_PATHS = {
  web: "/dashboard",
  space: "/dashboard",
} as const

type AppSegmentKey = keyof typeof APP_SEGMENT_PATHS

/**
 * Maps each role to the surface the user should land on after sign-in.
 */
const ROLE_APP_MAP: Record<AuthRole, AppSegmentKey> = {
  admin: "web",
  patient: "web",
  psychologist: "space",
}

/**
 * Human-readable label for each surface, shown on the `/continue` chooser page.
 */
const APP_SURFACE_LABELS: Record<AppSegmentKey, string> = {
  web: "Patient area",
  space: "Professional workspace",
}

export { APP_SEGMENT_PATHS, APP_SURFACE_LABELS, ROLE_APP_MAP, type AppSegmentKey }
