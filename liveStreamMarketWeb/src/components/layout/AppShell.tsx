"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  Suspense,
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";
import { Avatar } from "@/components/ui/Avatar";
import {
  IconBell,
  IconBox,
  IconChat,
  IconChevronRight,
  IconGavel,
  IconHome,
  IconLive,
  IconLogOut,
  IconPlus,
  IconSearch,
  IconSettings,
  IconSwap,
  IconTruck,
  IconUser,
} from "@/components/ui/icons";
import {
  NavBidSwap,
  NavHome,
  NavMessages,
  NavProfile,
} from "@/components/ui/navIcons";
import { Dialog } from "@/components/ui/Dialog";
import { useAuthGuard } from "@/components/providers/AuthPrompt";
import { useSession } from "@/components/providers/SessionProvider";
import { useApi } from "@/hooks/useApi";
import { useMounted } from "@/hooks/useMounted";
import { cn } from "@/lib/cn";
import { chats, notifications } from "@/lib/resources";
import { displayName } from "@/lib/types";

const PRIMARY_NAV = [
  { href: "/marketplace", label: "Marketplace", icon: IconHome },
  { href: "/live", label: "Live shows", icon: IconLive },
  { href: "/trades", label: "Trades", icon: IconSwap },
  { href: "/sell", label: "Sell", icon: IconGavel },
] as const;

/**
 * The frame every signed-in screen sits in.
 *
 * Desktop gets one bar with navigation, search and the account menu. Phones
 * get a thin bar and a bottom tab row, which is where a thumb is — the same
 * split the Flutter app makes, rather than squeezing a desktop header onto a
 * 390px screen.
 */
export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="relative flex min-h-dvh flex-col">
      {/* The bar reads the query string for the search box, so it streams in
          separately from the page under it. */}
      <Suspense fallback={<div className="h-16 border-b border-hairline lg:h-[72px]" />}>
        <AppTopBar />
      </Suspense>
      <main className="flex-1 pb-24 md:pb-16">{children}</main>
      {/* Reads the path for its selected tab, so it streams in like the top
          bar rather than blocking the whole route from prerendering. */}
      <Suspense fallback={null}>
        <MobileTabBar />
      </Suspense>
    </div>
  );
}

function AppTopBar() {
  const pathname = usePathname();
  const { user, signedIn } = useSession();
  const mounted = useMounted();

  return (
    <header className="sticky top-0 z-40 w-full border-b border-hairline bg-canvas/80 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-[1600px] items-center gap-4 px-4 sm:gap-6 sm:px-6 lg:h-[72px] lg:px-10">
        <Link
          href="/marketplace"
          className="flex shrink-0 items-center gap-2.5 rounded-md focus-visible:outline-2 focus-visible:outline-accent"
        >
          <span className="flex size-8 items-center justify-center rounded-[10px] bg-accent text-sm font-black text-[#0F172A]">
            A
          </span>
          <span className="hidden text-base font-black tracking-[0.22em] text-ink sm:block">
            ARIES
          </span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {PRIMARY_NAV.map((item) => {
            const active =
              pathname === item.href || pathname.startsWith(`${item.href}/`);
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "rounded-pill px-3.5 py-2 text-sm font-bold transition-colors",
                  "focus-visible:outline-2 focus-visible:outline-accent",
                  active
                    ? "bg-white/[0.08] text-ink"
                    : "text-ink-muted hover:bg-white/[0.05] hover:text-ink",
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <SearchBox className="ml-auto hidden max-w-sm flex-1 lg:flex" />

        <div className="ml-auto flex items-center gap-1 lg:ml-0">
          <Link
            href="/messages"
            aria-label="Messages"
            className="hidden rounded-full p-2.5 text-ink-muted transition-colors hover:bg-white/[0.06] hover:text-ink focus-visible:outline-2 focus-visible:outline-accent sm:inline-flex"
          >
            <IconChat size={21} />
          </Link>
          <NotificationBell />
          {mounted && signedIn ? (
            <AccountMenu />
          ) : !mounted ? (
            // Reserves the avatar's space so the bar does not jump when the
            // session resolves a frame later.
            <span aria-hidden className="size-9 shrink-0" />
          ) : (
            <div className="flex items-center gap-2 pl-1">
              <Link
                href="/login"
                className="hidden rounded-pill px-3 py-2 text-sm font-bold text-ink-muted transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-accent sm:inline-flex"
              >
                Sign in
              </Link>
              <Link
                href="/signup"
                className="inline-flex h-9 items-center rounded-pill bg-accent px-4 text-[13px] font-extrabold text-[#0F172A] transition-colors hover:bg-accent/90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
              >
                Join
              </Link>
            </div>
          )}
        </div>
      </div>

      {/* Phones put search on its own row rather than cramming it beside the
          logo, where it would be too narrow to read what you typed. */}
      <div className="border-t border-hairline px-4 py-2.5 lg:hidden">
        <SearchBox />
      </div>

      {user?.status === "restricted" ? (
        <p className="bg-danger/15 px-4 py-2 text-center text-xs font-bold text-danger">
          Your account is restricted. Buying, selling and trading are paused.
        </p>
      ) : null}
    </header>
  );
}

function SearchBox({ className }: { className?: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [value, setValue] = useState("");

  // Keep the box showing what the results are actually filtered by, including
  // after a back navigation.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setValue(searchParams?.get("q") ?? "");
  }, [searchParams]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const query = value.trim();
    router.push(query ? `/marketplace?q=${encodeURIComponent(query)}` : "/marketplace");
  }

  return (
    <form onSubmit={handleSubmit} role="search" className={cn("flex w-full", className)}>
      <label className="flex w-full items-center gap-2.5 rounded-pill border border-hairline bg-surface px-4 transition-colors focus-within:border-accent/50">
        <IconSearch size={18} className="shrink-0 text-ink-dim" />
        <input
          type="search"
          value={value}
          onChange={(event) => setValue(event.target.value)}
          placeholder="Search cards, sellers, shows"
          aria-label="Search the marketplace"
          className="h-10 min-w-0 flex-1 bg-transparent text-sm font-medium text-ink placeholder:text-ink-faint focus:outline-none"
        />
      </label>
    </form>
  );
}

function NotificationBell() {
  const { signedIn } = useSession();
  const { data } = useApi(
    (signal) => notifications.mine(signal),
    "notifications-badge",
    { enabled: signedIn },
  );

  const unread = (data ?? []).filter((item) => !item.isRead).length;

  return (
    <Link
      href="/notifications"
      aria-label={unread > 0 ? `Notifications, ${unread} unread` : "Notifications"}
      className="relative rounded-full p-2.5 text-ink-muted transition-colors hover:bg-white/[0.06] hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
    >
      <IconBell size={21} />
      {unread > 0 ? (
        <span className="absolute right-1.5 top-1.5 flex size-[18px] items-center justify-center rounded-full bg-danger text-[10px] font-black text-white">
          {unread > 9 ? "9+" : unread}
        </span>
      ) : null}
    </Link>
  );
}

const ACCOUNT_LINKS = [
  { href: "/profile", label: "Your profile", icon: IconUser },
  { href: "/orders", label: "Purchases", icon: IconTruck },
  { href: "/inventory", label: "Your inventory", icon: IconBox },
  { href: "/sell", label: "Seller tools", icon: IconGavel },
  { href: "/settings", label: "Settings", icon: IconSettings },
] as const;

function AccountMenu() {
  const { user, signOut } = useSession();
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const pathname = usePathname();

  // Any navigation closes it; without this the panel survives a route change
  // and hangs over the new page.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => setOpen(false), [pathname]);

  useEffect(() => {
    if (!open) return;
    function onPointerDown(event: MouseEvent) {
      if (!containerRef.current?.contains(event.target as Node)) setOpen(false);
    }
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  return (
    <div ref={containerRef} className="relative pl-1">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Account menu"
        className="rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        <Avatar user={user} size="sm" />
      </button>

      {open ? (
        <div
          role="menu"
          className="absolute right-0 top-[calc(100%+10px)] w-64 overflow-hidden rounded-card border border-hairline-strong bg-surface-raised shadow-2xl shadow-black/60"
        >
          <div className="flex items-center gap-3 border-b border-hairline px-4 py-3.5">
            <Avatar user={user} size="md" />
            <div className="min-w-0">
              <p className="truncate text-sm font-black text-ink">
                {displayName(user)}
              </p>
              <p className="truncate text-xs text-ink-dim">{user?.email}</p>
            </div>
          </div>

          <nav className="p-1.5">
            {ACCOUNT_LINKS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                role="menuitem"
                className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-bold text-ink-muted transition-colors hover:bg-white/[0.06] hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
              >
                <item.icon size={19} className="text-ink-dim" />
                {item.label}
              </Link>
            ))}
          </nav>

          <div className="border-t border-hairline p-1.5">
            <button
              type="button"
              role="menuitem"
              onClick={signOut}
              className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-bold text-danger transition-colors hover:bg-danger/10 focus-visible:outline-2 focus-visible:outline-accent"
            >
              <IconLogOut size={19} />
              Sign out
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

/**
 * The phone bar, built to match `CustomBottomNavbar` in the Flutter app:
 * same five slots in the same order, the same raised Sell button in the
 * middle, the same selected pill, label and underline dot, and the same
 * surface, edge and shadows.
 *
 * Messages, Sell and Profile ask for an account the way the app's AuthGuard
 * does, so a guest can still reach everything that is browse-only.
 */
const TABS = [
  { href: "/marketplace", label: "Home", icon: NavHome },
  { href: "/trades", label: "Marketplace", icon: NavBidSwap },
  { href: "/messages", label: "Message", icon: NavMessages, needsAccount: true },
  { href: "/profile", label: "Profile", icon: NavProfile, needsAccount: true },
] as const;

function MobileTabBar() {
  const pathname = usePathname();
  const router = useRouter();
  const { signedIn } = useSession();
  const { requireAccount } = useAuthGuard();
  const [sellOpen, setSellOpen] = useState(false);

  // The badge the app puts on the Messages tab.
  const { data: conversations } = useApi(
    (signal) => chats.list(signal),
    "chats-badge",
    { enabled: signedIn },
  );
  const unread = (conversations ?? []).reduce(
    (sum, chat) => sum + (chat.unreadCount ?? 0),
    0,
  );

  function go(href: string, needsAccount: boolean) {
    if (!needsAccount) {
      router.push(href);
      return;
    }
    requireAccount(() => router.push(href), {
      title:
        href === "/messages"
          ? "Sign in to access Messages"
          : "Sign in to view your Profile",
      description:
        href === "/messages"
          ? "Guest mode is browse-only. Sign in or create an account to message other traders and view offers."
          : "Sign in or create an account to view your trade history, manage listings and update profile settings.",
    });
  }

  const items = [
    ...TABS.slice(0, 2),
    null, // the Sell button sits in the middle
    ...TABS.slice(2),
  ];

  return (
    <>
      <nav
        aria-label="Primary"
        className={cn(
          "fixed inset-x-0 bottom-0 z-40 rounded-t-[28px] border-t-[1.2px] border-nav-edge",
          "bg-canvas-raised pb-[env(safe-area-inset-bottom)] md:hidden",
          "shadow-[0_-8px_30px_rgba(0,0,0,0.7),0_-2px_20px_rgba(139,155,255,0.05)]",
        )}
      >
        <ul className="mx-auto flex max-w-lg items-stretch px-2 pt-2.5 pb-2.5">
          {items.map((tab) =>
            tab === null ? (
              <li key="sell" className="flex-1">
                <SellButton onOpen={() => setSellOpen(true)} />
              </li>
            ) : (
              <li key={tab.href} className="flex-1">
                <TabButton
                  label={tab.label}
                  icon={tab.icon}
                  active={
                    pathname === tab.href || pathname.startsWith(`${tab.href}/`)
                  }
                  badge={tab.href === "/messages" ? unread : 0}
                  onClick={() =>
                    go(tab.href, "needsAccount" in tab && tab.needsAccount)
                  }
                />
              </li>
            ),
          )}
        </ul>
      </nav>

      <SellOptionsSheet open={sellOpen} onClose={() => setSellOpen(false)} />
    </>
  );
}

function TabButton({
  label,
  icon: Icon,
  active,
  badge,
  onClick,
}: {
  label: string;
  icon: (props: { size?: number }) => React.ReactElement;
  active: boolean;
  badge: number;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-current={active ? "page" : undefined}
      className="flex w-full flex-col items-center justify-center gap-[3px] focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-accent"
    >
      <span className="relative">
        <span
          className={cn(
            "flex items-center justify-center rounded-2xl px-2.5 py-1 transition-colors duration-250",
            active ? "bg-accent/15 text-accent" : "text-white/55",
          )}
        >
          <Icon size={21} />
        </span>

        {badge > 0 ? (
          <span className="absolute -top-0.5 right-0.5 inline-flex min-h-4 min-w-4 items-center justify-center rounded-[10px] border-[1.5px] border-canvas-raised bg-nav-badge px-1 text-[9px] font-black leading-none text-white shadow-[0_2px_6px_rgba(255,75,103,0.6)]">
            {badge > 99 ? "99+" : badge}
          </span>
        ) : null}
      </span>

      <span
        className={cn(
          "text-[10.5px] tracking-[0.2px]",
          active ? "font-bold text-accent" : "font-medium text-white/55",
        )}
      >
        {label}
      </span>

      {/* The active dot under the label. */}
      <span
        aria-hidden
        className={cn(
          "h-[3px] rounded-sm transition-all duration-250",
          active ? "w-3.5 bg-accent" : "w-0 bg-transparent",
        )}
      />
    </button>
  );
}

function SellButton({ onOpen }: { onOpen: () => void }) {
  const { requireAccount } = useAuthGuard();

  return (
    <button
      type="button"
      onClick={() =>
        requireAccount(onOpen, {
          title: "Sign in to Sell",
          description:
            "Guest mode is browse-only. Sign in to add inventory and start trading with others.",
        })
      }
      className="flex w-full flex-col items-center justify-center gap-[3px] focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-accent"
      aria-label="Sell"
    >
      {/* Written as a literal gradient rather than `from-*`/`to-*` utilities:
          the two stops are one-off brand values, and this way the button
          cannot quietly lose its fill if the token names change. */}
      <span
        className="flex size-[38px] items-center justify-center rounded-full text-canvas-raised shadow-[0_4px_12px_rgba(139,155,255,0.45)]"
        style={{
          backgroundImage: "linear-gradient(135deg, #A5B4FF 0%, #6E80FF 100%)",
        }}
      >
        <IconPlus size={24} />
      </span>
      <span className="text-[10.5px] font-extrabold tracking-[0.2px] text-accent">
        Sell
      </span>
      <span aria-hidden className="h-[3px] w-0" />
    </button>
  );
}

/**
 * The app's "What would you like to do?" sheet. Both choices open the same
 * form; the trade one arrives with "open to trades" already on.
 */
function SellOptionsSheet({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const router = useRouter();

  function choose(path: string) {
    onClose();
    router.push(path);
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="What would you like to do?"
      description="Both start from the same form — only the defaults differ."
    >
      <div className="space-y-3">
        <SellOption
          tone="accent"
          title="Trading"
          subtitle="List an item specifically for trading with another user."
          onClick={() => choose("/sell/new?mode=trade")}
          icon={<IconSwap size={22} />}
        />
        <SellOption
          tone="success"
          title="Add to inventory"
          subtitle="Save products to your inventory for giveaways and auctions in your live shows."
          onClick={() => choose("/sell/new")}
          icon={<IconBox size={22} />}
        />
      </div>
    </Dialog>
  );
}

function SellOption({
  tone,
  title,
  subtitle,
  icon,
  onClick,
}: {
  tone: "accent" | "success";
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex w-full items-center gap-3.5 rounded-2xl border bg-surface-raised p-4 text-left",
        "transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        tone === "accent"
          ? "border-accent/35 hover:border-accent/60"
          : "border-success/35 hover:border-success/60",
      )}
    >
      <span
        className={cn(
          "flex size-11 shrink-0 items-center justify-center rounded-full",
          tone === "accent" ? "bg-accent/15 text-accent" : "bg-success/15 text-success",
        )}
      >
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-[15px] font-black tracking-wide text-ink">
          {title}
        </span>
        <span className="block pt-1 text-xs leading-relaxed text-ink-muted">
          {subtitle}
        </span>
      </span>
      <IconChevronRight size={20} className="shrink-0 text-ink-faint" />
    </button>
  );
}
