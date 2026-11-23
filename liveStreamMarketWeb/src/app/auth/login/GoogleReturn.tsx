"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { endpoints } from "@/lib/endpoints";
import { session } from "@/lib/session";
import type { User } from "@/lib/types";

export function GoogleReturn() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const accessToken = searchParams?.get("accessToken") ?? "";
    const refreshToken = searchParams?.get("refreshToken") ?? "";

    if (!accessToken) {
      // The tokens arrive on the URL, which render cannot read on the server.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setFailed(true);
      return;
    }

    session.save({ accessToken, ...(refreshToken ? { refreshToken } : {}) });

    // The tokens are in the URL the browser just loaded, so they are in
    // history and in any referrer this page sends. Replacing the entry before
    // anything else runs is the only way to keep them out of both.
    void (async () => {
      try {
        const me = await api.get<User>(endpoints.user.profile);
        if (me?._id) session.save({ userId: me._id, userEmail: me.email ?? "" });
      } catch {
        // A profile that will not load is not a failed sign-in; the shell
        // retries it on the next page.
      }
      router.replace("/marketplace");
    })();
  }, [searchParams, router]);

  if (!failed) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-canvas">
        <span
          role="status"
          aria-label="Signing you in"
          className="size-7 animate-spin rounded-full border-2 border-ink-dim border-t-transparent"
        />
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-4 bg-canvas px-6 text-center">
      <h1 className="text-xl font-black text-ink">That sign-in did not complete</h1>
      <p className="max-w-sm text-sm leading-relaxed text-ink-muted">
        Google sent us back without a token. Nothing has changed on your
        account — try again, or sign in with your email and password.
      </p>
      <Link
        href="/login"
        className="rounded-pill bg-accent px-6 py-3 text-sm font-extrabold text-[#0F172A] transition-colors hover:bg-accent/90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        Back to sign in
      </Link>
    </div>
  );
}
