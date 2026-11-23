"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { errorMessage } from "@/components/ui/Alert";

/**
 * Runs a write — place a bid, accept a trade, follow someone — and tracks the
 * three things the button needs to show for it: in flight, failed, done.
 *
 * Returning the error as a string rather than throwing keeps call sites from
 * wrapping every click handler in try/catch.
 *
 * The action is kept in a ref and refreshed on every render. It is nearly
 * always an inline arrow closing over state, so a `useCallback` that captured
 * the first one would keep calling it with the values from first render.
 */
export function useAction<Args extends unknown[], Result>(
  action: (...args: Args) => Promise<Result>,
) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string>();

  const actionRef = useRef(action);
  useEffect(() => {
    actionRef.current = action;
  });

  const run = useCallback(async (...args: Args): Promise<Result | undefined> => {
    setPending(true);
    setError(undefined);
    try {
      return await actionRef.current(...args);
    } catch (thrown) {
      setError(errorMessage(thrown));
      return undefined;
    } finally {
      setPending(false);
    }
  }, []);

  const clearError = useCallback(() => setError(undefined), []);

  return { run, pending, error, clearError };
}
