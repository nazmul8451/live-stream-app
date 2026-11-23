"use client";

import { useRouter } from "next/navigation";
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { useSession } from "./SessionProvider";
import { Button } from "@/components/ui/Button";
import { Dialog } from "@/components/ui/Dialog";

interface Prompt {
  title: string;
  description: string;
  /** Where to come back to once there is an account. */
  next: string;
}

interface GuardValue {
  /**
   * Runs `action` when there is an account behind it. A guest gets the
   * sign-in panel instead, worded for whatever they were trying to do.
   */
  requireAccount: (action: () => void, prompt?: Partial<Prompt>) => void;
  signedIn: boolean;
}

const GuardContext = createContext<GuardValue | undefined>(undefined);

const DEFAULT: Omit<Prompt, "next"> = {
  title: "Sign in to continue",
  description:
    "Browsing is open to everyone. Bidding, buying and trading need an account so there is someone on the other end of the deal.",
};

/**
 * The current path, read when the panel opens rather than through
 * `usePathname()`.
 *
 * This provider wraps every page, and a URL hook here would mark the whole
 * app as request-dependent, which with Cache Components means no route under
 * it can be prerendered at all.
 */
function currentPath(): string {
  if (typeof window === "undefined") return "/marketplace";
  return window.location.pathname + window.location.search;
}

/**
 * Guest mode.
 *
 * A first-time visitor lands in the marketplace, not on a login form, and can
 * look at everything: listings, live shows, profiles. The account is asked for
 * at the moment it is actually needed, and the panel says what it is for, so
 * the request makes sense instead of arriving as a wall.
 *
 * This mirrors the AuthGuard bottom sheet in the Flutter app rather than
 * redirecting, because a redirect loses the page the person was reading.
 */
export function AuthPromptProvider({ children }: { children: ReactNode }) {
  const { signedIn } = useSession();
  const router = useRouter();
  const [prompt, setPrompt] = useState<Prompt>();

  const requireAccount = useCallback(
    (action: () => void, custom?: Partial<Prompt>) => {
      if (signedIn) {
        action();
        return;
      }
      setPrompt({ ...DEFAULT, next: currentPath(), ...custom });
    },
    [signedIn],
  );

  const value = useMemo<GuardValue>(
    () => ({ requireAccount, signedIn }),
    [requireAccount, signedIn],
  );

  // Coming back to where they were is the whole point of asking here rather
  // than at the door.
  const next = encodeURIComponent(prompt?.next ?? "/marketplace");

  return (
    <GuardContext.Provider value={value}>
      {children}

      <Dialog
        open={Boolean(prompt)}
        onClose={() => setPrompt(undefined)}
        title={prompt?.title ?? DEFAULT.title}
        description={prompt?.description ?? DEFAULT.description}
        footer={
          <>
            <Button variant="ghost" onClick={() => setPrompt(undefined)}>
              Keep browsing
            </Button>
            <Button
              variant="secondary"
              onClick={() => router.push(`/login?next=${next}`)}
            >
              Sign in
            </Button>
            <Button onClick={() => router.push(`/signup?next=${next}`)}>
              Create account
            </Button>
          </>
        }
      >
        <ul className="space-y-2.5 text-[13px] leading-relaxed text-ink-muted">
          <li>Bid in live shows and win lots.</li>
          <li>Buy outright, with payment held until the item arrives.</li>
          <li>Offer swaps on anything marked open to trades.</li>
          <li>Follow sellers and get told when they go live.</li>
        </ul>
      </Dialog>
    </GuardContext.Provider>
  );
}

export function useAuthGuard(): GuardValue {
  const value = useContext(GuardContext);
  if (!value) {
    throw new Error("useAuthGuard must be used inside <AuthPromptProvider>.");
  }
  return value;
}
