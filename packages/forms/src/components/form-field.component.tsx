import * as React from "react"

import { Label } from "@workspace/ui/components/label"
import { cn } from "@workspace/ui/lib/utils"

type FormFieldProps = React.ComponentProps<"div"> & {
  disabled?: boolean
  invalid?: boolean
  required?: boolean
}

function FormField({ className, disabled, invalid, required, ...props }: FormFieldProps) {
  return (
    <div
      data-slot="form-field"
      data-disabled={disabled ? "true" : undefined}
      data-invalid={invalid ? "true" : undefined}
      data-required={required ? "true" : undefined}
      className={cn("group/field grid gap-2", className)}
      {...props}
    />
  )
}

function FormFieldLabel({
  children,
  className,
  required,
  ...props
}: React.ComponentProps<typeof Label> & { required?: boolean }) {
  return (
    <Label data-slot="form-field-label" className={cn("gap-1", className)} {...props}>
      <span>{children}</span>
      {required ? (
        <span aria-hidden="true" className="text-destructive shrink-0">
          *
        </span>
      ) : null}
    </Label>
  )
}

function FormFieldDescription({ className, ...props }: React.ComponentProps<"p">) {
  return (
    <p
      data-slot="form-field-description"
      className={cn("text-muted-foreground text-xs/relaxed", className)}
      {...props}
    />
  )
}

function FormFieldError({ children, className, ...props }: React.ComponentProps<"p">) {
  if (!children) {
    return null
  }

  return (
    <p
      data-slot="form-field-error"
      role="alert"
      className={cn("text-destructive text-xs/relaxed", className)}
      {...props}
    >
      {children}
    </p>
  )
}

export { FormField, FormFieldDescription, FormFieldError, FormFieldLabel }
