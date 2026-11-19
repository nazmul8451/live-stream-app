"use client";

import {
  useId,
  useState,
  type InputHTMLAttributes,
  type ReactNode,
} from "react";
import { cn } from "@/lib/cn";

interface FieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "size"> {
  label: string;
  /** Shown under the field. A message in `error` replaces it. */
  hint?: string;
  error?: string;
  leading?: ReactNode;
}

export function Field({
  label,
  hint,
  error,
  leading,
  className,
  id,
  type = "text",
  ...rest
}: FieldProps) {
  const generatedId = useId();
  const fieldId = id ?? generatedId;
  const describedBy = `${fieldId}-desc`;

  // A password field that cannot be revealed makes people retype from the
  // start after one mistyped character, which is where most sign-in failures
  // come from on a phone keyboard.
  const isPassword = type === "password";
  const [revealed, setRevealed] = useState(false);
  const inputType = isPassword && revealed ? "text" : type;

  return (
    <div className="flex flex-col gap-2">
      <label
        htmlFor={fieldId}
        className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim"
      >
        {label}
      </label>

      <div
        className={cn(
          "flex items-center gap-3 rounded-card border bg-surface px-4",
          "transition-colors focus-within:border-accent/60",
          error ? "border-danger/60" : "border-hairline",
        )}
      >
        {leading ? <span className="shrink-0 text-ink-dim">{leading}</span> : null}
        <input
          {...rest}
          id={fieldId}
          type={inputType}
          aria-invalid={error ? true : undefined}
          aria-describedby={error || hint ? describedBy : undefined}
          className={cn(
            "h-13 min-w-0 flex-1 bg-transparent py-3.5 text-[15px] font-medium text-ink",
            "placeholder:text-ink-faint focus:outline-none",
            className,
          )}
        />
        {isPassword ? (
          <button
            type="button"
            onClick={() => setRevealed((value) => !value)}
            // The control is an icon, so it needs its own name for screen
            // readers, and the state has to be announced, not just drawn.
            aria-label={revealed ? "Hide password" : "Show password"}
            aria-pressed={revealed}
            className="shrink-0 rounded-md p-1 text-ink-dim transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
          >
            {revealed ? <EyeOffIcon /> : <EyeIcon />}
          </button>
        ) : null}
      </div>

      {error || hint ? (
        <p
          id={describedBy}
          className={cn("text-xs", error ? "text-danger" : "text-ink-dim")}
        >
          {error ?? hint}
        </p>
      ) : null}
    </div>
  );
}

function EyeIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  );
}

function EyeOffIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M3 3l18 18M10.6 10.7a2 2 0 0 0 2.8 2.8M9.4 5.9A9.7 9.7 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a16.6 16.6 0 0 1-3.3 4M6.3 7.8A16.4 16.4 0 0 0 2.5 12S6 18.5 12 18.5a9.6 9.6 0 0 0 3.6-.7"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
