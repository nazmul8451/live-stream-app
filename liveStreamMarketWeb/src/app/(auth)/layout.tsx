import { AppBackground } from "@/components/layout/AppBackground";
import { AuthShowcase } from "@/components/layout/AuthShowcase";
import { TopBar } from "@/components/layout/TopBar";

/**
 * Shell for every signed-out screen.
 *
 * Built as a site, not a phone screen that happens to open in a browser: real
 * navigation stays visible, the page fills the window, and the form sits in a
 * panel beside the product rather than alone in a narrow centred column.
 * Below `lg` it collapses to that single column, because there a single
 * column is the right answer.
 */
export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="relative flex min-h-dvh flex-col">
      <AppBackground />
      <TopBar />

      <div className="flex flex-1 lg:grid lg:grid-cols-[1.1fr_minmax(480px,0.9fr)] xl:grid-cols-[1.2fr_minmax(540px,0.8fr)]">
        {/* Product half — desktop only. */}
        <section className="hidden lg:block">
          <AuthShowcase />
        </section>

        {/* Form half. The left hairline reads as a seam between two halves of
            a page rather than a card dropped onto a background. */}
        <section className="flex items-center justify-center border-hairline px-5 py-12 sm:px-10 lg:border-l lg:bg-white/[0.015] lg:px-14 lg:py-16 xl:px-20">
          <div className="w-full max-w-[440px]">{children}</div>
        </section>
      </div>
    </div>
  );
}
