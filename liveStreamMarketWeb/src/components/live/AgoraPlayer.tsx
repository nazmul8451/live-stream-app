"use client";

import { useEffect, useRef, useState } from "react";
import type {
  IAgoraRTCClient,
  IAgoraRTCRemoteUser,
} from "agora-rtc-sdk-ng";
import { cn } from "@/lib/cn";
import { streams } from "@/lib/resources";

type Status = "connecting" | "waiting" | "playing" | "error";

/**
 * The viewer half of a live show.
 *
 * The SDK is imported inside the effect rather than at module scope: it
 * touches `window` and `navigator` as it loads, which would throw during the
 * server render of this page. Everything it creates is torn down on unmount,
 * because a client left joined keeps the camera feed — and the viewer count —
 * alive after the person has navigated away.
 */
export function AgoraPlayer({
  channelName,
  className,
  onViewerCount,
}: {
  channelName: string;
  className?: string;
  onViewerCount?: (count: number) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<Status>("connecting");
  const [message, setMessage] = useState<string>();

  useEffect(() => {
    if (!channelName) return;

    let client: IAgoraRTCClient | undefined;
    let cancelled = false;

    async function connect() {
      try {
        const { default: AgoraRTC } = await import("agora-rtc-sdk-ng");
        if (cancelled) return;

        // The server issues a per-viewer token; it also hands back the app id
        // so the browser does not need its own copy of it.
        const credentials = await streams.token(channelName, "audience");
        const appId =
          credentials?.appId ?? process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "";
        if (!appId) throw new Error("Live video is not configured.");
        if (cancelled) return;

        client = AgoraRTC.createClient({ mode: "live", codec: "vp8" });
        await client.setClientRole("audience");

        client.on("user-published", async (user: IAgoraRTCRemoteUser, mediaType) => {
          if (!client) return;
          await client.subscribe(user, mediaType);
          if (mediaType === "video" && containerRef.current) {
            user.videoTrack?.play(containerRef.current, { fit: "contain" });
            setStatus("playing");
          }
          if (mediaType === "audio") user.audioTrack?.play();
        });

        client.on("user-unpublished", (_user, mediaType) => {
          if (mediaType === "video") setStatus("waiting");
        });

        client.on("user-left", () => setStatus("waiting"));

        if (onViewerCount) {
          // Agora counts everyone in the channel, the host included; the
          // audience number people care about excludes them.
          const report = () =>
            onViewerCount(Math.max(0, (client?.remoteUsers.length ?? 1) - 1));
          client.on("user-joined", report);
          client.on("user-left", report);
        }

        await client.join(
          appId,
          credentials?.channelName ?? channelName,
          credentials?.token ?? null,
          credentials?.uid ?? null,
        );
        if (cancelled) return;
        setStatus((current) => (current === "playing" ? current : "waiting"));
      } catch (error) {
        if (cancelled) return;
        setStatus("error");
        setMessage(
          error instanceof Error ? error.message : "Could not connect to the show.",
        );
      }
    }

    void connect();

    return () => {
      cancelled = true;
      void (async () => {
        try {
          client?.removeAllListeners();
          await client?.leave();
        } catch {
          // Leaving a client that never finished joining throws; there is
          // nothing left to clean up either way.
        }
      })();
    };
  }, [channelName, onViewerCount]);

  return (
    <div
      className={cn(
        "relative aspect-[9/16] w-full overflow-hidden rounded-card-lg bg-black sm:aspect-video",
        className,
      )}
    >
      <div ref={containerRef} className="size-full" />

      {status !== "playing" ? (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-canvas-raised/80 px-6 text-center">
          {status === "error" ? (
            <>
              <p className="text-sm font-black text-ink">Video unavailable</p>
              <p className="max-w-xs text-xs leading-relaxed text-ink-muted">
                {message} You can still bid and chat below.
              </p>
            </>
          ) : (
            <>
              <span
                role="status"
                aria-label="Connecting"
                className="size-7 animate-spin rounded-full border-2 border-ink-dim border-t-transparent"
              />
              <p className="text-xs font-bold text-ink-dim">
                {status === "connecting"
                  ? "Connecting to the show…"
                  : "The host's camera is off"}
              </p>
            </>
          )}
        </div>
      ) : null}
    </div>
  );
}
