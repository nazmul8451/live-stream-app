"use client";

import { useEffect, useState } from "react";

/**
 * False on the server and during hydration, true from the first effect on.
 *
 * The session is a JWT in `localStorage`, the same place the Flutter app keeps
 * it, so the server cannot know whether anyone is signed in and the prerendered
 * HTML is always the signed-out version. Anything that renders differently for
 * a signed-in person has to wait for this, or React hydrates a signed-out shell
 * against signed-in markup and throws the whole tree away.
 */
export function useMounted(): boolean {
  const [mounted, setMounted] = useState(false);
  // The whole point of this hook: flip after hydration so the markup React
  // hydrates matches what the server sent.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => setMounted(true), []);
  return mounted;
}
