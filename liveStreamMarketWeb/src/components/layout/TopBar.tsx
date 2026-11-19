import Link from "next/link";
import { cn } from "@/lib/cn";

const NAV = [
  { href: "/marketplace", label: "Marketplace" },
  { href: "/live", label: "Live shows" },
  { href: "/trades", label: "Trades" },
  { href: "/sell", label: "Sell" },
];

/**
 * The bar across the top of every signed-out page.
 *
 * A phone app opens on a form; a web platform opens on a site you can look
 * around before committing. Keeping real navigation visible while signed out
 * is most of what makes the difference.
 */
export function TopBar({ variant = "auth" }: { variant?: "auth" | "app" }) {
  return (
    <header
      className={cn(
        "sticky top-0 z-40 w-full border-b border-hairline",
        "bg-canvas/70 backdrop-blur-xl",
      )}
    >
      <div className="mx-auto flex h-16 max-w-[1600px] items-center gap-8 px-5 sm:px-8 lg:h-[72px] lg:px-12">
        <Link
          href="/"
          className="flex shrink-0 items-center gap-2.5 rounded-md focus-visible:outline-2 focus-visible:outline-accent"
        >
          <span className="flex size-8 items-center justify-center rounded-[10px] bg-accent text-sm font-black text-[#0F172A]">
            A
          </span>
          <span className="text-base font-black tracking-[0.22em] text-ink">
            ARIES
          </span>
        </Link>

        <nav className="hidden flex-1 items-center gap-1 md:flex">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-pill px-3.5 py-2 text-sm font-bold text-ink-muted transition-colors hover:bg-white/[0.06] hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-2 md:ml-0">
          {variant === "auth" ? (
            <>
              <Link
                href="/login"
                className="hidden rounded-pill px-4 py-2 text-sm font-bold text-ink-muted transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-accent sm:inline-flex"
              >
                Sign in
              </Link>
              <Link
                href="/signup"
                className="inline-flex h-10 items-center rounded-pill bg-accent px-5 text-sm font-extrabold text-[#0F172A] transition-colors hover:bg-accent/90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
              >
                Create account
              </Link>
            </>
          ) : null}
        </div>
      </div>
    </header>
  );
}
