"use client";

import Link from "next/link";
import { useState, type FormEvent } from "react";
import { AuthHeader } from "@/components/auth/AuthHeader";
import { Button } from "@/components/ui/Button";
import { Field } from "@/components/ui/Field";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [submitting, setSubmitting] = useState(false);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    // Validation runs here rather than on the server round trip so a typo in
    // the email does not cost a request and a wait.
    const next: typeof errors = {};
    if (!email.trim()) next.email = "Enter your email address.";
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()))
      next.email = "That does not look like an email address.";
    if (!password) next.password = "Enter your password.";

    setErrors(next);
    if (Object.keys(next).length > 0) return;

    setSubmitting(true);
    // TODO(integration): POST /auth/login, store the token pair, then route.
    setTimeout(() => setSubmitting(false), 900);
  }

  return (
    <>
      <AuthHeader title="Welcome back">
        Sign in to bid, trade and track your orders.
      </AuthHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-5">
        <Field
          label="Email"
          type="email"
          name="email"
          autoComplete="email"
          inputMode="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          error={errors.email}
        />

        <div className="space-y-2">
          <Field
            label="Password"
            type="password"
            name="password"
            autoComplete="current-password"
            placeholder="Your password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            error={errors.password}
          />
          <div className="flex justify-end">
            <Link
              href="/forgot-password"
              className="rounded-md text-[13px] font-bold text-accent transition-colors hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
            >
              Forgot password?
            </Link>
          </div>
        </div>

        <Button type="submit" size="lg" block loading={submitting}>
          Sign in
        </Button>
      </form>

      <Divider>or</Divider>

      <Button variant="secondary" size="lg" block leading={<GoogleMark />}>
        Continue with Google
      </Button>

      <p className="mt-8 text-center text-sm text-ink-muted">
        New to ARIES?{" "}
        <Link
          href="/signup"
          className="rounded-md font-bold text-accent transition-colors hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
        >
          Create an account
        </Link>
      </p>

      <p className="mt-4 text-center text-sm text-ink-dim">
        <Link
          href="/marketplace"
          className="rounded-md font-bold transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
        >
          Browse without signing in →
        </Link>
      </p>
    </>
  );
}

function Divider({ children }: { children: string }) {
  return (
    <div className="my-6 flex items-center gap-4">
      <span className="h-px flex-1 bg-hairline" />
      <span className="text-[11px] font-black uppercase tracking-[0.15em] text-ink-faint">
        {children}
      </span>
      <span className="h-px flex-1 bg-hairline" />
    </div>
  );
}

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden>
      <path
        fill="#4285F4"
        d="M22.5 12.2c0-.8-.1-1.5-.2-2.2H12v4.3h5.9a5 5 0 0 1-2.2 3.3v2.7h3.6c2.1-1.9 3.2-4.8 3.2-8.1Z"
      />
      <path
        fill="#34A853"
        d="M12 23c2.9 0 5.4-1 7.2-2.7l-3.6-2.7c-1 .7-2.3 1.1-3.6 1.1-2.8 0-5.2-1.9-6-4.4H2.3v2.8A10.9 10.9 0 0 0 12 23Z"
      />
      <path
        fill="#FBBC05"
        d="M6 14.3a6.5 6.5 0 0 1 0-4.2V7.3H2.3a11 11 0 0 0 0 9.8L6 14.3Z"
      />
      <path
        fill="#EA4335"
        d="M12 5.4c1.6 0 3 .5 4.1 1.6l3.1-3.1A10.6 10.6 0 0 0 12 1 10.9 10.9 0 0 0 2.3 7.3L6 10.1c.8-2.5 3.2-4.7 6-4.7Z"
      />
    </svg>
  );
}
