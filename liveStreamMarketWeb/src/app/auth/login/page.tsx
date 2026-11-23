import { Suspense } from "react";
import { GoogleReturn } from "./GoogleReturn";

/**
 * Where Google sign-in lands.
 *
 * The API finishes the OAuth handshake itself and redirects here with the
 * token pair on the query string (`PassportAuthController.googleAuthCallback`),
 * so this route's whole job is to bank them and get out of the way.
 */
export default function GoogleReturnPage() {
  return (
    <Suspense fallback={<Waiting />}>
      <GoogleReturn />
    </Suspense>
  );
}

function Waiting() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-canvas">
      <span
        role="status"
        aria-label="Signing you in"
        className="size-7 animate-spin rounded-full border-2 border-ink-dim border-t-transparent"
      />
    </div>
  );
}
