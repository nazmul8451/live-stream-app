"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Dialog } from "@/components/ui/Dialog";
import { Field } from "@/components/ui/Field";
import { useAction } from "@/hooks/useAction";
import { api } from "@/lib/api";
import { endpoints } from "@/lib/endpoints";
import { uploads, users } from "@/lib/resources";

export default function SettingsPage() {
  return (
    <RequireAuth>
      <Settings />
    </RequireAuth>
  );
}

function Settings() {
  const { user, refresh, signOut, isSeller } = useSession();
  const router = useRouter();

  const [fullName, setFullName] = useState("");
  const [description, setDescription] = useState("");
  const [phone, setPhone] = useState("");
  const [saved, setSaved] = useState(false);
  const avatarInput = useRef<HTMLInputElement>(null);

  // The profile arrives after the first render, so the form fills in once it
  // does rather than being left empty or fighting the user's typing.
  useEffect(() => {
    if (!user) return;
    // Seeds the form once the profile arrives, then leaves the user's typing
    // alone.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setFullName(user.fullName ?? user.name ?? "");
    setDescription(user.description ?? "");
    setPhone(user.phone ?? "");
  }, [user]);

  const save = useAction(async () => {
    await users.updateProfile({
      name: fullName.trim(),
      fullName: fullName.trim(),
      description: description.trim(),
      ...(phone.trim() ? { phone: phone.trim() } : {}),
    });
    await refresh();
    setSaved(true);
  });

  const changeAvatar = useAction(async (file: File) => {
    const url = await uploads.image(file);
    await users.updateProfile({ profile: url });
    await refresh();
  });

  const switchRole = useAction(async () => {
    await users.switchRole(isSeller ? "BUYER" : "SELLER");
    await refresh();
  });

  return (
    <Container className="max-w-2xl pb-16">
      <PageHeader title="Settings" description="Your profile, password and account." />

      <div className="space-y-5">
        <Card className="space-y-5">
          <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
            Profile
          </h2>

          <div className="flex items-center gap-4">
            <Avatar user={user} size="lg" />
            <div className="space-y-1">
              <Button
                variant="secondary"
                size="sm"
                loading={changeAvatar.pending}
                onClick={() => avatarInput.current?.click()}
              >
                Change photo
              </Button>
              <p className="text-xs text-ink-dim">JPG or PNG, up to 25 MB.</p>
            </div>
            <input
              ref={avatarInput}
              type="file"
              accept="image/*"
              className="sr-only"
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) void changeAvatar.run(file);
                event.target.value = "";
              }}
            />
          </div>
          {changeAvatar.error ? <Alert>{changeAvatar.error}</Alert> : null}

          <form
            className="space-y-5"
            onSubmit={(event) => {
              event.preventDefault();
              setSaved(false);
              void save.run();
            }}
          >
            <Field
              label="Name"
              value={fullName}
              onChange={(event) => setFullName(event.target.value)}
            />
            <Field
              label="Phone"
              type="tel"
              value={phone}
              onChange={(event) => setPhone(event.target.value)}
              hint="Used for shipping questions only."
            />

            <div className="flex flex-col gap-2">
              <label
                htmlFor="bio"
                className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim"
              >
                About you
              </label>
              <textarea
                id="bio"
                rows={3}
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                placeholder="What you collect, what you are hunting for."
                className="rounded-card border border-hairline bg-surface px-4 py-3 text-[15px] font-medium text-ink placeholder:text-ink-faint focus:border-accent/60 focus:outline-none"
              />
            </div>

            <div className="rounded-card border border-hairline bg-white/[0.02] px-4 py-3">
              <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
                Email
              </p>
              <p className="pt-1 text-sm font-semibold text-ink">{user?.email}</p>
              <p className="pt-1 text-xs text-ink-dim">
                Your sign-in address cannot be changed here.
              </p>
            </div>

            {save.error ? <Alert>{save.error}</Alert> : null}
            {saved ? <Alert tone="success">Profile saved.</Alert> : null}

            <Button type="submit" loading={save.pending}>
              Save changes
            </Button>
          </form>
        </Card>

        <Card className="space-y-3">
          <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
            Account type
          </h2>
          <p className="text-sm leading-relaxed text-ink-muted">
            You are acting as a {isSeller ? "seller" : "buyer"}.{" "}
            {isSeller
              ? "Sellers can list items and run live shows."
              : "Switch to a seller account to list items and run live shows."}
          </p>
          {switchRole.error ? <Alert>{switchRole.error}</Alert> : null}
          <Button
            variant="secondary"
            loading={switchRole.pending}
            onClick={() => void switchRole.run()}
          >
            Switch to {isSeller ? "buyer" : "seller"}
          </Button>
        </Card>

        <ChangePasswordCard />

        <Card className="space-y-3">
          <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
            Session
          </h2>
          <Button
            variant="secondary"
            onClick={() => {
              signOut();
              router.replace("/marketplace");
            }}
          >
            Sign out
          </Button>
        </Card>

        <DeleteAccountCard
          onDeleted={() => {
            signOut();
            router.replace("/marketplace");
          }}
        />
      </div>
    </Container>
  );
}

function ChangePasswordCard() {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [done, setDone] = useState(false);
  const [mismatch, setMismatch] = useState<string>();

  const change = useAction(async () => {
    await api.post("/auth/change-password", {
      currentPassword: current,
      newPassword: next,
      confirmPassword: confirm,
    });
    setCurrent("");
    setNext("");
    setConfirm("");
    setDone(true);
  });

  function submit(event: FormEvent) {
    event.preventDefault();
    setDone(false);
    if (next.length < 8) {
      setMismatch("Use at least 8 characters.");
      return;
    }
    if (next !== confirm) {
      setMismatch("The two new passwords do not match.");
      return;
    }
    setMismatch(undefined);
    void change.run();
  }

  return (
    <Card className="space-y-5">
      <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
        Password
      </h2>
      <form onSubmit={submit} className="space-y-5">
        <Field
          label="Current password"
          type="password"
          autoComplete="current-password"
          value={current}
          onChange={(event) => setCurrent(event.target.value)}
        />
        <Field
          label="New password"
          type="password"
          autoComplete="new-password"
          value={next}
          onChange={(event) => setNext(event.target.value)}
        />
        <Field
          label="Confirm new password"
          type="password"
          autoComplete="new-password"
          value={confirm}
          onChange={(event) => setConfirm(event.target.value)}
          error={mismatch}
        />
        {change.error ? <Alert>{change.error}</Alert> : null}
        {done ? <Alert tone="success">Password changed.</Alert> : null}
        <Button type="submit" variant="secondary" loading={change.pending}>
          Change password
        </Button>
      </form>
    </Card>
  );
}

function DeleteAccountCard({ onDeleted }: { onDeleted: () => void }) {
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string>();
  const [working, setWorking] = useState(false);

  async function remove() {
    setWorking(true);
    setError(undefined);
    try {
      await api.delete(endpoints.auth.deleteAccount, {
        body: { password },
      } as never);
      onDeleted();
    } catch (deleteError) {
      setError(errorMessage(deleteError));
      setWorking(false);
    }
  }

  return (
    <>
      <Card className="space-y-3 border-danger/25">
        <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-danger">
          Delete account
        </h2>
        <p className="text-sm leading-relaxed text-ink-muted">
          This removes your listings, trades and history. Orders already in
          flight still have to complete. It cannot be undone.
        </p>
        <Button variant="danger" onClick={() => setOpen(true)}>
          Delete my account
        </Button>
      </Card>

      <Dialog
        open={open}
        onClose={() => setOpen(false)}
        title="Delete your account?"
        description="Everything you have listed, saved and traded goes with it. This cannot be undone."
        footer={
          <>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Keep my account
            </Button>
            <Button
              variant="danger"
              loading={working}
              disabled={!password}
              onClick={remove}
            >
              Delete for good
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field
            label="Confirm your password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          {error ? <Alert>{error}</Alert> : null}
        </div>
      </Dialog>
    </>
  );
}
