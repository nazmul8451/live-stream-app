import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

/**
 * The app's standard surface: a dark panel with a hairline edge and a hard
 * radius. Everything that is not the page background sits on one of these.
 */
export function Card({
  children,
  className,
  as: Tag = "div",
  padded = true,
}: {
  children: ReactNode;
  className?: string;
  as?: "div" | "section" | "article" | "li";
  padded?: boolean;
}) {
  return (
    <Tag
      className={cn(
        "rounded-card border border-hairline bg-surface",
        padded && "p-4 sm:p-5",
        className,
      )}
    >
      {children}
    </Tag>
  );
}

/** A small all-caps heading, the app's section label. */
export function SectionLabel({
  children,
  className,
  action,
}: {
  children: ReactNode;
  className?: string;
  action?: ReactNode;
}) {
  return (
    <div className={cn("flex items-center justify-between gap-4", className)}>
      <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
        {children}
      </h2>
      {action}
    </div>
  );
}

/**
 * The pill badge used for categories, conditions and statuses.
 *
 * `tone` carries meaning, so an empty or unknown state gets the neutral tone
 * rather than borrowing a colour that implies something.
 */
export function Badge({
  children,
  tone = "neutral",
  className,
}: {
  children: ReactNode;
  tone?: "neutral" | "accent" | "success" | "warning" | "danger" | "violet";
  className?: string;
}) {
  const tones: Record<string, string> = {
    neutral: "bg-white/[0.06] text-ink-muted border-hairline",
    accent: "bg-accent/15 text-accent border-accent/25",
    success: "bg-success/15 text-success border-success/25",
    warning: "bg-gold/15 text-gold border-gold/25",
    danger: "bg-danger/15 text-danger border-danger/25",
    violet: "bg-violet/15 text-pink border-violet/25",
  };
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-pill border px-3 py-1",
        "text-[10px] font-black uppercase tracking-[0.1em] whitespace-nowrap",
        tones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

/**
 * Shown wherever a list has nothing in it.
 *
 * The app used to print a bare "No X found." under a heading; saying what the
 * person can do about it is more use than announcing the absence.
 */
export function EmptyState({
  icon,
  title,
  description,
  action,
  className,
}: {
  icon?: ReactNode;
  title: string;
  description?: string;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-3 rounded-card-lg",
        "border border-hairline bg-surface/60 px-6 py-14 text-center",
        className,
      )}
    >
      {icon ? (
        <div className="flex size-14 items-center justify-center rounded-2xl border border-hairline bg-white/[0.04] text-ink-dim">
          {icon}
        </div>
      ) : null}
      <p className="text-lg font-black text-ink">{title}</p>
      {description ? (
        <p className="max-w-sm text-sm leading-relaxed text-ink-muted">{description}</p>
      ) : null}
      {action ? <div className="pt-2">{action}</div> : null}
    </div>
  );
}

/** A loading placeholder shaped like the content it stands in for. */
export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      aria-hidden
      className={cn("animate-pulse rounded-xl bg-white/[0.06]", className)}
    />
  );
}
