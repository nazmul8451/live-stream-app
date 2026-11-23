"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import { auth } from "@/lib/auth";
import { endpoints } from "@/lib/endpoints";
import { session } from "@/lib/session";
import type { User } from "@/lib/types";

interface SessionValue {
  user: User | undefined;
  /** True until the first profile read settles, signed in or not. */
  loading: boolean;
  signedIn: boolean;
  /** The role the account is currently acting as. */
  isSeller: boolean;
  refresh: () => Promise<void>;
  signOut: () => void;
}

const SessionContext = createContext<SessionValue | undefined>(undefined);

/**
 * Holds the signed-in user for the whole app.
 *
 * Guest browsing is a first-class state here, not an error: the marketplace,
 * profiles and live shows are all readable signed out, and only the actions
 * that need an account prompt for one. So a missing token resolves to
 * `signedIn: false` quietly instead of bouncing anyone to a login form.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User>();
  const [loading, setLoading] = useState(true);
  const [hasToken, setHasToken] = useState(false);

  const load = useCallback(async () => {
    if (!session.isSignedIn) {
      // The token lives in localStorage, which render cannot read.
      setUser(undefined);
      setHasToken(false);
      setLoading(false);
      return;
    }
    setHasToken(true);
    try {
      const me = await api.get<User>(endpoints.user.profile);
      setUser(me);
      if (me?._id) session.save({ userId: me._id });
    } catch {
      // `api` already dropped the session if the token was unusable. Anything
      // else — offline, a 500 — leaves the token alone and the person stays
      // signed in; the next page will try again.
      setUser(undefined);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // The profile read is the external system this syncs with.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
    // Sign-in and sign-out both happen outside React, so the provider listens
    // rather than waiting for something to re-render it.
    return session.subscribe(() => void load());
  }, [load]);

  const signOut = useCallback(() => {
    auth.signOut();
    setUser(undefined);
    setHasToken(false);
  }, []);

  const value = useMemo<SessionValue>(
    () => ({
      user,
      loading,
      signedIn: hasToken,
      isSeller:
        user?.activeRole?.toUpperCase() === "SELLER" ||
        (user?.roles ?? []).some((role) => role.toUpperCase() === "SELLER"),
      refresh: load,
      signOut,
    }),
    [user, loading, hasToken, load, signOut],
  );

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  );
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext);
  if (!value) {
    throw new Error("useSession must be used inside <SessionProvider>.");
  }
  return value;
}

/**
 * Wraps a screen that makes no sense signed out — your orders, your inventory,
 * the checkout. Guests are sent to sign in with the current path attached so
 * they come back to where they were going.
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { signedIn, loading } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (loading || signedIn) return;
    const here =
      typeof window === "undefined"
        ? "/"
        : window.location.pathname + window.location.search;
    router.replace(`/login?next=${encodeURIComponent(here)}`);
  }, [loading, signedIn, router]);

  if (loading || !signedIn) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <span
          role="status"
          aria-label="Loading"
          className="size-6 animate-spin rounded-full border-2 border-ink-dim border-t-transparent"
        />
      </div>
    );
  }

  return <>{children}</>;
}
