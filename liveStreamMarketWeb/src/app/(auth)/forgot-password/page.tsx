"use client";

import { useState, type FormEvent } from "react";
import { AuthHeader } from "@/components/auth/AuthHeader";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Field } from "@/components/ui/Field";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | undefined>();
  const [submitting, setSubmitting] = useState(false);
  const [sent, setSent] = useState(false);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      setError("Enter the email address on your account.");
      return;
    }
    setError(undefined);
    setSubmitting(true);
    // TODO(integration): POST /auth/forget-password.
    setTimeout(() => {
      setSubmitting(false);
      setSent(true);
    }, 900);
  }

  if (sent) {
    return (
      <>
        <AuthHeader title="Check your email">
          If an account exists for{" "}
          <span className="font-bold text-ink">{email.trim()}</span>, a reset
          code is on its way.
        </AuthHeader>

        {/* Deliberately not "we sent it": confirming which addresses have
            accounts lets anyone test a list of emails against the platform. */}
        <div className="space-y-3">
          <ButtonLink href="/reset-password" size="lg" block>
            I have a code
          </ButtonLink>
          <Button
            variant="ghost"
            size="lg"
            block
            onClick={() => setSent(false)}
          >
            Use a different address
          </Button>
        </div>
      </>
    );
  }

  return (
    <>
      <AuthHeader
        title="Reset your password"
        back={{ href: "/login", label: "Back to sign in" }}
      >
        Enter the email on your account and we will send you a code to set a
        new password.
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
          error={error}
        />

        <Button type="submit" size="lg" block loading={submitting}>
          Send reset code
        </Button>
      </form>
    </>
  );
}
