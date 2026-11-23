import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  /**
   * The root is the marketplace. Done here rather than with a `redirect()` in
   * a root page component: with partial prefetching on, a page whose whole job
   * is to throw NEXT_REDIRECT cannot be prerendered, and Next logs a failed
   * segment validation on every request for it.
   */
  async redirects() {
    return [{ source: "/", destination: "/marketplace", permanent: false }];
  },

  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
