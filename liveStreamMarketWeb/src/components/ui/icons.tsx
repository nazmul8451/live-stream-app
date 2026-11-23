/**
 * The icon set, drawn rather than installed.
 *
 * One stroke weight and one 24px grid across the whole platform, which is what
 * keeps a nav row from looking like it was assembled from three icon packs.
 * Every icon is `aria-hidden`: the label beside it, or the control's own
 * `aria-label`, is the accessible name.
 */
import type { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function Icon({ size = 22, children, ...rest }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      {...rest}
    >
      {children}
    </svg>
  );
}

export const IconHome = (p: IconProps) => (
  <Icon {...p}>
    <path d="M3 10.5 12 3l9 7.5" />
    <path d="M5 9.8V20h5v-5.5h4V20h5V9.8" />
  </Icon>
);

export const IconLive = (p: IconProps) => (
  <Icon {...p}>
    <rect x="2.5" y="6" width="13" height="12" rx="3" />
    <path d="m15.5 11 6-3.2v8.4l-6-3.2z" />
  </Icon>
);

export const IconSwap = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 8h12l-3-3" />
    <path d="M20 16H8l3 3" />
  </Icon>
);

export const IconTag = (p: IconProps) => (
  <Icon {...p}>
    <path d="M3.5 12.3V5.2a1.7 1.7 0 0 1 1.7-1.7h7.1c.5 0 .9.2 1.2.5l7 7a1.7 1.7 0 0 1 0 2.4l-6.6 6.6a1.7 1.7 0 0 1-2.4 0l-7-7a1.7 1.7 0 0 1-.5-1.2Z" />
    <circle cx="8" cy="8" r="1.4" />
  </Icon>
);

export const IconSearch = (p: IconProps) => (
  <Icon {...p}>
    <circle cx="11" cy="11" r="7" />
    <path d="m20 20-3.5-3.5" />
  </Icon>
);

export const IconBell = (p: IconProps) => (
  <Icon {...p}>
    <path d="M18 8.5a6 6 0 1 0-12 0c0 5-2 6.5-2 6.5h16s-2-1.5-2-6.5Z" />
    <path d="M13.7 19a2 2 0 0 1-3.4 0" />
  </Icon>
);

export const IconChat = (p: IconProps) => (
  <Icon {...p}>
    <path d="M21 11.5a8.5 8.5 0 0 1-12.3 7.6L3 21l1.9-5.7A8.5 8.5 0 1 1 21 11.5Z" />
  </Icon>
);

export const IconUser = (p: IconProps) => (
  <Icon {...p}>
    <circle cx="12" cy="8" r="3.6" />
    <path d="M4.5 20a7.5 7.5 0 0 1 15 0" />
  </Icon>
);

export const IconHeart = (p: IconProps) => (
  <Icon {...p}>
    <path d="M12 20s-7.5-4.5-7.5-9.6A4.4 4.4 0 0 1 12 7.4a4.4 4.4 0 0 1 7.5 3C19.5 15.5 12 20 12 20Z" />
  </Icon>
);

export const IconBox = (p: IconProps) => (
  <Icon {...p}>
    <path d="M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5z" />
    <path d="M3.5 7.5 12 12l8.5-4.5M12 12v9" />
  </Icon>
);

export const IconPlus = (p: IconProps) => (
  <Icon {...p}>
    <path d="M12 5v14M5 12h14" />
  </Icon>
);

export const IconChevronRight = (p: IconProps) => (
  <Icon {...p}>
    <path d="m9 5 7 7-7 7" />
  </Icon>
);

export const IconChevronDown = (p: IconProps) => (
  <Icon {...p}>
    <path d="m5 9 7 7 7-7" />
  </Icon>
);

export const IconClose = (p: IconProps) => (
  <Icon {...p}>
    <path d="M6 6l12 12M18 6 6 18" />
  </Icon>
);

export const IconCheck = (p: IconProps) => (
  <Icon {...p}>
    <path d="m5 12.5 4.5 4.5L19 7.5" />
  </Icon>
);

export const IconGavel = (p: IconProps) => (
  <Icon {...p}>
    <path d="m13.5 4.5 6 6M16.5 1.5l6 6M10.5 7.5l6 6" />
    <path d="m12 9-8 8 3 3 8-8M3 22h8" />
  </Icon>
);

export const IconTruck = (p: IconProps) => (
  <Icon {...p}>
    <path d="M2.5 6.5h11v9h-11zM13.5 10h4l3 3v2.5h-7z" />
    <circle cx="7" cy="17.5" r="1.8" />
    <circle cx="17" cy="17.5" r="1.8" />
  </Icon>
);

export const IconStar = (p: IconProps) => (
  <Icon {...p}>
    <path d="m12 3.5 2.6 5.4 5.9.8-4.3 4.1 1 5.9-5.2-2.8-5.2 2.8 1-5.9L3.5 9.7l5.9-.8z" />
  </Icon>
);

export const IconShield = (p: IconProps) => (
  <Icon {...p}>
    <path d="M12 3 5 6v6c0 4.2 2.9 7.6 7 9 4.1-1.4 7-4.8 7-9V6z" />
    <path d="m9 12 2 2 4-4" />
  </Icon>
);

export const IconLogOut = (p: IconProps) => (
  <Icon {...p}>
    <path d="M9.5 4.5H6a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h3.5" />
    <path d="M16 15.5 19.5 12 16 8.5M19.5 12H9" />
  </Icon>
);

export const IconSettings = (p: IconProps) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 14.5a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5v.2a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3h.1a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8v.1a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1Z" />
  </Icon>
);

export const IconWallet = (p: IconProps) => (
  <Icon {...p}>
    <path d="M3.5 7.5A2 2 0 0 1 5.5 5.5H18a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5.5a2 2 0 0 1-2-2Z" />
    <path d="M16 12h2.5" />
  </Icon>
);
