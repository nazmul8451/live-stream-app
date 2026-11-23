"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { AuthHeader } from "@/components/auth/AuthHeader";
import { OtpInput } from "@/components/auth/OtpInput";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { auth, pending } from "@/lib/auth";

const RESEND_SECONDS = 60;

export default function VerifyPage() {
  const router = useRouter();
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | undefined>();
  const [submitting, setSubmitting] = useState(false);
  const [resending, setResending] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(RESEND_SECONDS);

  // The address is banked by the signup step. It only exists in the browser,
  // so it is read after mount rather than during render.
  const [email, setEmail] = useState("");
  useEffect(() => {
    const address = pending.email;
    // Landing here cold — a bookmark, a reload in a new tab — means there is
    // nothing to verify against, so send them back to the step that sets it.
    // Banked by the signup step in sessionStorage, so it can only be read
    // after mount.
    if (!address) {
      router.replace("/signup");
      return;
    }
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setEmail(address);
  }, [router]);

  useEffect(() => {
    if (secondsLeft <= 0) return;
    const timer = setTimeout(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearTimeout(timer);
  }, [secondsLeft]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (code.length < 6) {
      setError("Enter all six digits.");
      return;
    }
    setError(undefined);
    setSubmitting(true);
    try {
      const { signedIn } = await auth.verifyOtp(email, code, "createAccount");
      const destination = pending.next || "/marketplace";
      pending.clear();
      // Verifying after signup returns a token pair, so the person lands in
      // the marketplace already signed in rather than on a login form.
      router.replace(signedIn ? destination : "/login");
    } catch (verifyError) {
      setError(errorMessage(verifyError));
      setSubmitting(false);
      setCode("");
    }
  }

  async function handleResend() {
    setResending(true);
    setError(undefined);
    try {
      await auth.resendOtp(email, "createAccount");
      setSecondsLeft(RESEND_SECONDS);
    } catch (resendError) {
      setError(errorMessage(resendError));
    } finally {
      setResending(false);
    }
  }

  return (
    <>
      <AuthHeader
        title="Check your email"
        back={{ href: "/signup", label: "Back" }}
      >
        We sent a 6-digit code to{" "}
        <span className="font-bold text-ink">{email || "your email"}</span>. It
        expires in 10 minutes.
      </AuthHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-6">
        {error ? <Alert>{error}</Alert> : null}

        <OtpInput
          value={code}
          onChange={(next) => {
            setCode(next);
            if (error) setError(undefined);
          }}
          invalid={Boolean(error)}
          disabled={submitting}
        />

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
            onClick={handleResend}
            disabled={resending}
            className="rounded-md font-bold text-accent transition-colors hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent disabled:opacity-50"
          >
            {resending ? "Sending…" : "Send a new code"}
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
