"use client";

import { useEffect, useState, type FormEvent } from "react";
import { AuthHeader } from "@/components/auth/AuthHeader";
import { OtpInput } from "@/components/auth/OtpInput";
import { Button } from "@/components/ui/Button";

const RESEND_SECONDS = 60;

export default function VerifyPage() {
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | undefined>();
  const [submitting, setSubmitting] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(RESEND_SECONDS);

  // TODO(integration): read the address from the signup step instead.
  const email = "you@example.com";

  useEffect(() => {
    if (secondsLeft <= 0) return;
    const timer = setTimeout(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearTimeout(timer);
  }, [secondsLeft]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (code.length < 6) {
      setError("Enter all six digits.");
      return;
    }
    setError(undefined);
    setSubmitting(true);
    // TODO(integration): POST /auth/verify-account.
    setTimeout(() => setSubmitting(false), 900);
  }

  return (
    <>
      <AuthHeader
        title="Check your email"
        back={{ href: "/signup", label: "Back" }}
      >
        We sent a 6-digit code to <span className="font-bold text-ink">{email}</span>.
        It expires in 10 minutes.
      </AuthHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-6">
        <OtpInput
          value={code}
          onChange={(next) => {
            setCode(next);
            if (error) setError(undefined);
          }}
          invalid={Boolean(error)}
          disabled={submitting}
        />

        {error ? (
          <p role="alert" className="text-center text-sm text-danger">
            {error}
          </p>
        ) : null}

        <Button
          type="submit"
          size="lg"
          block
          loading={submitting}
          disabled={code.length < 6}
        >
          Verify
        </Button>
      </form>

      <div className="mt-8 text-center text-sm">
        {secondsLeft > 0 ? (
          <p className="text-ink-dim">
            Didn&apos;t get it? You can ask for a new code in{" "}
            <span className="font-bold text-ink-muted tabular-nums">
              {secondsLeft}s
            </span>
          </p>
        ) : (
          <button
            type="button"
            onClick={() => setSecondsLeft(RESEND_SECONDS)}
            className="rounded-md font-bold text-accent transition-colors hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
          >
            Send a new code
          </button>
        )}
      </div>

      <p className="mt-4 text-center text-xs leading-relaxed text-ink-faint">
        Check your spam folder before asking for another one — a second code
        makes the first one stop working.
      </p>
    </>
  );
}
