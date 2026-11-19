import type { ButtonHTMLAttributes, ReactNode } from "react";
import Link from "next/link";
import { cn } from "@/lib/cn";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "outline";
type Size = "sm" | "md" | "lg";

const VARIANTS: Record<Variant, string> = {
  // The app's filled accent button: light periwinkle with dark ink on it.
  primary:
    "bg-accent text-[#0F172A] hover:bg-accent/90 shadow-lg shadow-accent/25 disabled:shadow-none",
  // A filled-looking button that stays quiet beside a primary one.
  secondary: "bg-white/[0.08] text-ink hover:bg-white/[0.12] border border-hairline",
  ghost: "text-ink-muted hover:text-ink hover:bg-white/[0.06]",
  danger: "bg-danger text-white hover:bg-danger/90",
  outline:
    "border border-accent/50 text-accent hover:bg-accent/10 bg-accent/[0.08]",
};

const SIZES: Record<Size, string> = {
  sm: "h-9 px-4 text-[13px] rounded-pill gap-1.5",
  md: "h-12 px-6 text-sm rounded-pill gap-2",
  lg: "h-14 px-7 text-base rounded-pill gap-2",
};

interface BaseProps {
  variant?: Variant;
  size?: Size;
  /** Fill the row, the way the app's CTA buttons do. */
  block?: boolean;
  loading?: boolean;
  leading?: ReactNode;
  trailing?: ReactNode;
  children?: ReactNode;
  className?: string;
}

function classes({ variant = "primary", size = "md", block, className }: BaseProps) {
  return cn(
    "inline-flex items-center justify-center font-extrabold tracking-tight",
    "transition-colors duration-150 active:scale-[0.98] motion-reduce:active:scale-100",
    "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
    "disabled:cursor-not-allowed disabled:opacity-50",
    VARIANTS[variant],
    SIZES[size],
    block && "w-full",
    className,
  );
}

export function Button({
  variant,
  size,
  block,
  loading,
  leading,
  trailing,
  children,
  className,
  disabled,
  ...rest
}: BaseProps & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={classes({ variant, size, block, className })}
    >
      {loading ? <Spinner /> : leading}
      {children}
      {!loading && trailing}
    </button>
  );
}

export function ButtonLink({
  href,
  variant,
  size,
  block,
  leading,
  trailing,
  children,
  className,
}: BaseProps & { href: string }) {
  return (
    <Link href={href} className={classes({ variant, size, block, className })}>
      {leading}
      {children}
      {trailing}
    </Link>
  );
}

export function Spinner({ className }: { className?: string }) {
  return (
    <span
      role="status"
      aria-label="Loading"
      className={cn(
        "size-4 animate-spin rounded-full border-2 border-current border-t-transparent",
        className,
      )}
    />
  );
}
