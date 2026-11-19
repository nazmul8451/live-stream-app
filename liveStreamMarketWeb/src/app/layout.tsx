import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

// The Flutter app ships Inter; using the same face keeps the two platforms
// looking like one product rather than two takes on it.
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "ARIES — Live collectible auctions and trades",
    template: "%s · ARIES",
  },
  description:
    "Buy, sell and trade collectibles. Watch live auctions, make offers and swap cards with verified sellers.",
};

export const viewport: Viewport = {
  themeColor: "#02010a",
  // The app's bottom bar sits against the home indicator; the web shell needs
  // the same safe-area insets to do that on iOS.
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${inter.variable} h-full`}>
      <body className="bg-canvas text-ink min-h-full antialiased">
        {children}
      </body>
    </html>
  );
}
