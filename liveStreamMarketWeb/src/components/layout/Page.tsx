import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

/** The one content width the whole platform uses. */
export function Container({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("mx-auto w-full max-w-[1600px] px-4 sm:px-6 lg:px-10", className)}>
      {children}
    </div>
  );
}

export function PageHeader({
  title,
  description,
  action,
  className,
}: {
  title: string;
  description?: ReactNode;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-end justify-between gap-4 pb-6 pt-7 sm:pt-9",
        className,
      )}
    >
      <div className="min-w-0 space-y-1.5">
        <h1 className="text-2xl font-black tracking-tight text-ink sm:text-[1.75rem]">
          {title}
        </h1>
        {description ? (
          <p className="max-w-2xl text-sm leading-relaxed text-ink-muted">
            {description}
          </p>
        ) : null}
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  );
}
