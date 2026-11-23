import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

/**
 * The band a form shows when the server said no.
 *
 * `role="alert"` rather than a plain paragraph: a message that appears after
 * a failed submit is useless to a screen reader if nothing announces it, and
 * the focus is still on the button that caused it.
 */
export function Alert({
  tone = "danger",
  children,
  className,
}: {
  tone?: "danger" | "success" | "info";
  children: ReactNode;
  className?: string;
}) {
  const tones = {
    danger: "border-danger/30 bg-danger/10 text-danger",
    success: "border-success/30 bg-success/10 text-success",
    info: "border-accent/30 bg-accent/10 text-accent",
  } as const;

  return (
    <div
      role="alert"
      className={cn(
        "rounded-card border px-4 py-3 text-sm font-medium leading-relaxed",
        tones[tone],
        className,
      )}
    >
      {children}
    </div>
  );
}

/** Turns whatever was thrown into a sentence worth showing someone. */
export function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message) return error.message;
  if (typeof error === "string" && error) return error;
  return "Something went wrong. Please try again.";
}
