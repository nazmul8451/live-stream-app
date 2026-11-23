"use client";

import { useState } from "react";
import { cn } from "@/lib/cn";
import { mediaUrl } from "@/lib/api";
import { displayName, type UserSummary } from "@/lib/types";

const SIZES = {
  xs: "size-7 text-[10px]",
  sm: "size-9 text-xs",
  md: "size-11 text-sm",
  lg: "size-16 text-lg",
  xl: "size-24 text-2xl",
} as const;

/**
 * A user's picture, or their initials when there isn't one.
 *
 * Initials rather than a generic silhouette: in a list of sellers, a column of
 * identical grey heads tells you nothing, and most accounts here have no
 * photo. They are also the fallback when a stored photo fails to load, which
 * happens often enough — accounts carry paths to files that have since gone
 * from the bucket, and a row of broken-image glyphs reads as a broken page.
 */
export function Avatar({
  user,
  size = "md",
  className,
  ring,
}: {
  user: UserSummary | undefined;
  size?: keyof typeof SIZES;
  className?: string;
  /** A live show's host gets a ring, the way the app marks one. */
  ring?: boolean;
}) {
  const [failed, setFailed] = useState(false);
  const src = mediaUrl(user?.profile);
  const name = displayName(user);
  const initials = name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");

  return (
    <span
      className={cn(
        "relative inline-flex shrink-0 items-center justify-center overflow-hidden rounded-full",
        "bg-surface-high font-black text-ink-muted select-none",
        ring && "ring-2 ring-pink ring-offset-2 ring-offset-canvas",
        SIZES[size],
        className,
      )}
    >
      {src && !failed ? (
        /* Avatars come from an S3 bucket and a user-uploads host that are not
           in the image config, so the optimizer would reject them. */
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={src}
          alt=""
          loading="lazy"
          onError={() => setFailed(true)}
          className="size-full object-cover"
        />
      ) : (
        <span aria-hidden>{initials || "?"}</span>
      )}
    </span>
  );
}
