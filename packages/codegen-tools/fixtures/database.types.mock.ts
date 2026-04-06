/**
 * Hand-written fixture for codegen tests — not Supabase CLI output.
 * No real project data.
 */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: {
      demo_widget_events: {
        Insert: {
          created_at?: string
          id?: string
          widget_id: string
        }
        Relationships: [
          {
            columns: ["widget_id"]
            foreignKeyName: "demo_widget_events_widget_id_fkey"
            isOneToOne: false
            referencedColumns: ["id"]
            referencedRelation: "demo_widgets"
          },
        ]
        Row: {
          created_at: string
          id: string
          widget_id: string
        }
        Update: {
          created_at?: string
          id?: string
          widget_id?: string
        }
      }
      demo_widgets: {
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Relationships: []
        Row: {
          created_at: string
          id: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
      }
    }
    Views: {
      demo_widgets_ro: {
        Row: {
          id: string
          name: string
        }
        Relationships: []
      }
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      demo_status: "active" | "archived"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}
