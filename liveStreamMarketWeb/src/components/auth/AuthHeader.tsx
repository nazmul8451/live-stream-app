import Link from "next/link";
import type { ReactNode } from "react";

export function AuthHeader({
  title,
  children,
  back,
}: {
  title: string;
  children?: ReactNode;
  back?: { href: string; label: string };
}) {
  return (
    <header className="mb-8 space-y-3">
      {back ? (
        <Link
          href={back.href}
          className="-ml-1 inline-flex items-center gap-1.5 rounded-md py-1 text-sm font-bold text-ink-muted transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden>
            <path
              d="M15 19l-7-7 7-7"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          {back.label}
        </Link>
      ) : null}

      <h1 className="text-3xl font-black tracking-tight text-ink sm:text-[2rem]">
        {title}
      </h1>
      {children ? (
        <p className="text-[15px] leading-relaxed text-ink-muted">{children}</p>
      ) : null}
    </header>
  );
}
