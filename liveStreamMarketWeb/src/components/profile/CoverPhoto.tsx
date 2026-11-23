"use client";

import { useState, type ReactNode } from "react";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";

/**
 * The banner behind a profile.
 *
 * Falls back to the gradient whenever there is no cover *or* the stored one
 * fails to load — accounts carry paths to images that have since been removed
 * from the bucket, and a broken-image glyph stretched across the top of a
 * profile looks like the page itself is broken.
 */
export function CoverPhoto({
  src,
  className,
  children,
}: {
  src: string | undefined;
  className?: string;
  children?: ReactNode;
}) {
  const [failed, setFailed] = useState(false);
  const url = mediaUrl(src);
  const usable = url && !failed;

  return (
    <div
      className={cn(
        "relative h-36 overflow-hidden rounded-card-lg border border-hairline bg-surface sm:h-48",
        className,
      )}
    >
      {usable ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={url}
          alt=""
          onError={() => setFailed(true)}
          className="size-full object-cover"
        />
      ) : (
        <div className="size-full bg-gradient-to-br from-bloom-violet/60 via-bloom-magenta/40 to-bloom-blue/60" />
      )}
      {children}
    </div>
  );
}
