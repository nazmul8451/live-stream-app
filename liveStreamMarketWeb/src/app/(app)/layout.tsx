import { AppBackground } from "@/components/layout/AppBackground";
import { AppShell } from "@/components/layout/AppShell";
import { AuthPromptProvider } from "@/components/providers/AuthPrompt";
import { SessionProvider } from "@/components/providers/SessionProvider";

/**
 * The shell for the platform itself.
 *
 * Everything under here is readable signed out — browsing, live shows, public
 * profiles — and the screens that genuinely need an account wrap themselves in
 * `RequireAuth` rather than the whole group doing it. A marketplace that
 * demands a login before it shows you anything has nothing to sign up for.
 */
export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <SessionProvider>
      <AuthPromptProvider>
        <AppBackground />
        <AppShell>{children}</AppShell>
      </AuthPromptProvider>
    </SessionProvider>
  );
}
