import { Suspense } from "react";
import { ProfileView } from "@/components/profile/ProfileView";

/**
 * Reading `params` is request work, so it happens inside the boundary rather
 * than in the page body. With Cache Components an `await params` out here
 * would stop the whole route from prerendering, and the shell around it is
 * perfectly static.
 */
export default function Page({ params }: PageProps<"/u/[id]">) {
  return (
    <Suspense fallback={<RouteFallback />}>
      <Resolved params={params} />
    </Suspense>
  );
}

async function Resolved({ params }: { params: PageProps<"/u/[id]">["params"] }) {
  const { id } = await params;
  return <ProfileView userId={id} />;
}

function RouteFallback() {
  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <span
        role="status"
        aria-label="Loading"
        className="size-6 animate-spin rounded-full border-2 border-ink-dim border-t-transparent"
      />
    </div>
  );
}
