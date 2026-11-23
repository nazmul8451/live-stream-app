"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { cn } from "@/lib/cn";
import { IconClose } from "./icons";

/**
 * A centred panel over the page, used for the handful of flows that are a
 * decision rather than a destination — proposing a swap, confirming a bid.
 *
 * Built on `<dialog>` so the browser supplies the modal behaviour that is
 * tedious and easy to get wrong by hand: focus trapping, inertness of the
 * page behind it, Escape to close, and a top-layer stacking context that no
 * `z-index` on the page can beat.
 */
export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  size = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  footer?: ReactNode;
  size?: "md" | "lg";
}) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    if (open && !element.open) element.showModal();
    if (!open && element.open) element.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      // A click on the backdrop lands on the dialog element itself; a click on
      // the panel lands on a child, so this closes only the former.
      onClick={(event) => {
        if (event.target === ref.current) onClose();
      }}
      className={cn(
        "m-auto w-[calc(100vw-2rem)] rounded-card-lg border border-hairline-strong bg-surface-raised",
        "p-0 text-ink backdrop:bg-black/70 backdrop:backdrop-blur-sm",
        size === "lg" ? "max-w-2xl" : "max-w-md",
      )}
    >
      <div className="flex items-start gap-4 border-b border-hairline px-5 py-4">
        <div className="min-w-0 flex-1">
          <h2 className="text-lg font-black tracking-tight text-ink">{title}</h2>
          {description ? (
            <p className="mt-1 text-[13px] leading-relaxed text-ink-muted">
              {description}
            </p>
          ) : null}
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="-mr-1 shrink-0 rounded-full p-1.5 text-ink-dim transition-colors hover:bg-white/[0.06] hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
        >
          <IconClose size={20} />
        </button>
      </div>

      <div className="max-h-[65vh] overflow-y-auto px-5 py-5">{children}</div>

      {footer ? (
        <div className="flex flex-col-reverse gap-2.5 border-t border-hairline px-5 py-4 sm:flex-row sm:justify-end">
          {footer}
        </div>
      ) : null}
    </dialog>
  );
}
