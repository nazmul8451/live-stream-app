"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { SessionExpiredError } from "@/lib/api";

interface State<T> {
  data: T | undefined;
  error: Error | undefined;
  loading: boolean;
}

/**
 * Reads from the API inside a client component.
 *
 * The session lives in `localStorage`, so every authenticated read has to
 * happen in the browser; there is no token on the server to render with. This
 * is the one place that knows it, which keeps every screen from repeating the
 * same loading/error/abort dance.
 *
 * `key` decides when to re-run. It is a string rather than a dependency array
 * because the fetcher is usually an inline arrow function, and depending on
 * that identity re-runs the request on every render.
 */
export function useApi<T>(
  fetcher: (signal: AbortSignal) => Promise<T>,
  key: string,
  options: { enabled?: boolean } = {},
): State<T> & { reload: () => void } {
  const { enabled = true } = options;
  const [state, setState] = useState<State<T>>({
    data: undefined,
    error: undefined,
    loading: enabled,
  });
  const [nonce, setNonce] = useState(0);

  // Held in a ref so changing the fetcher's identity never re-triggers the
  // effect; `key` is the only thing that does. Written in an effect rather
  // than during render, and declared before the fetching effect so it is
  // already current by the time that one runs.
  const fetcherRef = useRef(fetcher);
  useEffect(() => {
    fetcherRef.current = fetcher;
  });

  useEffect(() => {
    if (!enabled) {
      // Clearing a disabled read is a reset, not a render-time derivation.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setState({ data: undefined, error: undefined, loading: false });
      return;
    }

    const controller = new AbortController();
    let active = true;
    setState((previous) => ({ ...previous, loading: true, error: undefined }));

    fetcherRef
      .current(controller.signal)
      .then((data) => {
        if (active) setState({ data, error: undefined, loading: false });
      })
      .catch((error: Error) => {
        if (!active || error?.name === "AbortError") return;
        setState({ data: undefined, error, loading: false });
      });

    return () => {
      active = false;
      controller.abort();
    };
  }, [key, nonce, enabled]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);
  return { ...state, reload };
}

/** True when the failure means "sign in again", not "try again". */
export function isSessionExpired(error: unknown): boolean {
  return error instanceof SessionExpiredError;
}
