"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { AuthHeader } from "@/components/auth/AuthHeader";
import { OtpInput } from "@/components/auth/OtpInput";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Field } from "@/components/ui/Field";
import { auth, pending } from "@/lib/auth";

type Errors = Partial<Record<"code" | "password" | "confirm", string>>;

export default function ResetPasswordPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [errors, setErrors] = useState<Errors>({});
  const [formError, setFormError] = useState<string>();
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const address = pending.email;
    // Same as the verify step: sessionStorage is not readable during render.
    if (!address) {
      router.replace("/forgot-password");
      return;
    }
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setEmail(address);
  }, [router]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const next: Errors = {};
    if (code.length < 6) next.code = "Enter the six-digit code from the email.";
    if (password.length < 8) next.password = "Use at least 8 characters.";
    // Checked here rather than after the request, so a mistyped confirmation
    // does not burn the single-use reset code.
    if (confirm !== password) next.confirm = "The two passwords do not match.";

    setErrors(next);
    if (Object.keys(next).length > 0) return;

    setFormError(undefined);
    setSubmitting(true);
    try {
      // Two calls, one screen: the code buys a single-use reset token, and
      // only that token is allowed to set the new password.
      await auth.verifyOtp(email, code, "resetPassword");
      await auth.resetPassword(password, confirm);
      router.replace("/login?reset=1");
    } catch (resetError) {
      setFormError(errorMessage(resetError));
      setSubmitting(false);
      setCode("");
    }
  }

  return (
    <>
      <AuthHeader
        title="Set a new password"
        back={{ href: "/forgot-password", label: "Back" }}
      >
        Enter the code we emailed to{" "}
        <span className="font-bold text-ink">{email || "your address"}</span>,
        then choose a new password.
      </AuthHeader>

      <form onSubmit={handleSubmit} noValidate className="space-y-6">
        {formError ? <Alert>{formError}</Alert> : null}

        <div className="space-y-2">
          <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
            Reset code
          </p>
          <OtpInput
            value={code}
            onChange={(next) => {
              setCode(next);
              if (errors.code) setErrors((e) => ({ ...e, code: undefined }));
            }}
            invalid={Boolean(errors.code)}
          />
          {errors.code ? (
            <p className="text-xs text-danger">{errors.code}</p>
          ) : null}
        </div>

        <Field
          label="New password"
          type="password"
          autoComplete="new-password"
          placeholder="At least 8 characters"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={errors.password}
        />

        <Field
          label="Confirm new password"
          type="password"
          autoComplete="new-password"
          placeholder="Type it again"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          error={errors.confirm}
        />

        <Button type="submit" size="lg" block loading={submitting}>
          Save new password
        </Button>
      </form>

      <p className="mt-6 text-center text-xs leading-relaxed text-ink-faint">
        Signing in elsewhere? Changing your password signs you out on every
        other device.
      </p>
    </>
  );
}
