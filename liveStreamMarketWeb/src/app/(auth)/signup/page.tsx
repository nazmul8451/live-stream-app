"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo, useState, type FormEvent } from "react";
import { AuthHeader } from "@/components/auth/AuthHeader";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { auth, pending } from "@/lib/auth";
import { Button } from "@/components/ui/Button";
import { Field } from "@/components/ui/Field";
import { legalPageUrls } from "@/lib/endpoints";
import { MEDIA_BASE_URL } from "@/lib/api";

type Errors = Partial<Record<"fullName" | "email" | "password" | "terms", string>>;

export default function SignUpPage() {
  return (
    <Suspense fallback={<FormSkeleton />}>
      <SignUpForm />
    </Suspense>
  );
}

function SignUpForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [errors, setErrors] = useState<Errors>({});
  const [formError, setFormError] = useState<string>();
  const [submitting, setSubmitting] = useState(false);

  const strength = useMemo(() => passwordStrength(password), [password]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const next: Errors = {};
    if (!fullName.trim()) next.fullName = "Enter your name.";
    if (!email.trim()) next.email = "Enter your email address.";
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()))
      next.email = "That does not look like an email address.";
    if (password.length < 8)
      next.password = "Use at least 8 characters.";
    if (!acceptedTerms)
      next.terms = "You need to accept the terms to create an account.";

    setErrors(next);
    if (Object.keys(next).length > 0) return;

    setFormError(undefined);
    setSubmitting(true);
    try {
      await auth.signUp({ name: fullName, email, password });
      const next = searchParams?.get("next");
      if (next) pending.setNext(next);
      router.push("/verify");
    } catch (error) {
      setFormError(errorMessage(error));
      setSubmitting(false);
    }
  }

  return (
    <>
      <AuthHeader title="Create your account">
        It takes a minute. You can browse first and sign up when you are ready
        to buy or trade.
      </AuthHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-5">
        {formError ? <Alert>{formError}</Alert> : null}

        <Field
          label="Full name"
          name="name"
          autoComplete="name"
          placeholder="Your name"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          error={errors.fullName}
        />

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
          hint="We send a 6-digit code here to confirm it is yours."
        />

        <div className="space-y-3">
          <Field
            label="Password"
            type="password"
            name="password"
            autoComplete="new-password"
            placeholder="At least 8 characters"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            error={errors.password}
          />
          {password ? <StrengthMeter score={strength.score} label={strength.label} /> : null}
        </div>

        <label className="flex cursor-pointer items-start gap-3 rounded-card border border-hairline bg-surface p-4">
          <input
            type="checkbox"
            checked={acceptedTerms}
            onChange={(e) => setAcceptedTerms(e.target.checked)}
            className="mt-0.5 size-5 shrink-0 cursor-pointer appearance-none rounded-md border border-hairline-strong bg-white/[0.04] checked:border-accent checked:bg-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          />
          <span className="text-[13px] leading-relaxed text-ink-muted">
            I accept the{" "}
            <LegalLink doc="terms-and-condition">Terms &amp; Conditions</LegalLink>{" "}
            and the{" "}
            <LegalLink doc="privacy-policy">Privacy Policy</LegalLink>.
          </span>
        </label>
        {errors.terms ? (
          <p className="-mt-2 text-xs text-danger">{errors.terms}</p>
        ) : null}

        <Button type="submit" size="lg" block loading={submitting}>
          Create account
        </Button>
      </form>

      <p className="mt-8 text-center text-sm text-ink-muted">
        Already have an account?{" "}
        <Link
          href="/login"
          className="rounded-md font-bold text-accent transition-colors hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
        >
          Sign in
        </Link>
      </p>
    </>
  );
}

/** The form's shape while the URL-dependent part streams in. */
function FormSkeleton() {
  return (
    <div aria-hidden className="space-y-5">
      <div className="h-10 w-56 animate-pulse rounded-lg bg-white/[0.06]" />
      <div className="h-5 w-64 animate-pulse rounded-lg bg-white/[0.04]" />
      <div className="h-[70px] animate-pulse rounded-card bg-white/[0.04]" />
      <div className="h-[70px] animate-pulse rounded-card bg-white/[0.04]" />
      <div className="h-[70px] animate-pulse rounded-card bg-white/[0.04]" />
      <div className="h-14 animate-pulse rounded-pill bg-white/[0.06]" />
    </div>
  );
}

function LegalLink({
  doc,
  children,
}: {
  doc: keyof typeof legalPageUrls;
  children: string;
}) {
  return (
    <a
      href={`${MEDIA_BASE_URL}${legalPageUrls[doc]}`}
      target="_blank"
      rel="noreferrer noopener"
      className="rounded-md font-bold text-accent underline-offset-2 hover:underline focus-visible:outline-2 focus-visible:outline-accent"
    >
      {children}
    </a>
  );
}

/**
 * A rough strength read, shown only as feedback.
 *
 * It is not a gate: the only rule the form enforces is the 8-character
 * minimum, so this never blocks someone whose password a meter dislikes.
 */
function passwordStrength(value: string): { score: 0 | 1 | 2 | 3; label: string } {
  if (value.length < 8) return { score: 0, label: "Too short" };
  let points = 0;
  if (value.length >= 12) points += 1;
  if (/[a-z]/.test(value) && /[A-Z]/.test(value)) points += 1;
  if (/\d/.test(value)) points += 1;
  if (/[^A-Za-z0-9]/.test(value)) points += 1;

  if (points <= 1) return { score: 1, label: "Weak" };
  if (points <= 2) return { score: 2, label: "Good" };
  return { score: 3, label: "Strong" };
}

function StrengthMeter({ score, label }: { score: 0 | 1 | 2 | 3; label: string }) {
  const colours = ["bg-danger", "bg-danger", "bg-gold", "bg-success"];
  return (
    <div className="flex items-center gap-3">
      <div className="flex flex-1 gap-1.5" aria-hidden>
        {[1, 2, 3].map((step) => (
          <span
            key={step}
            className={`h-1 flex-1 rounded-full transition-colors ${
              score >= step ? colours[score] : "bg-white/[0.08]"
            }`}
          />
        ))}
      </div>
      <span className="text-xs font-bold text-ink-dim">{label}</span>
    </div>
  );
}
