/**
 * The bottom bar's icons, traced from the app's own SVGs
 * (`assets/icons/*-navBar.svg`) so the web bar reads as the same product on a
 * phone rather than a lookalike.
 *
 * Inlined rather than loaded from `/public`: the source files hard-code
 * `stroke="white"`, and the bar tints each icon by selection state, which an
 * `<img>` cannot do.
 */
import type { SVGProps } from "react";

type NavIconProps = SVGProps<SVGSVGElement> & { size?: number };

function NavIcon({ size = 21, children, ...rest }: NavIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      aria-hidden
      {...rest}
    >
      {children}
    </svg>
  );
}

export const NavHome = (p: NavIconProps) => (
  <NavIcon {...p}>
    <path
      d="M3.63 7.04016C2.73 7.74016 2 9.23016 2 10.3602V17.7702C2 20.0902 3.89 21.9902 6.21 21.9902H17.79C20.11 21.9902 22 20.0902 22 17.7802V10.5002C22 9.29016 21.19 7.74016 20.2 7.05016L14.02 2.72016C12.62 1.74016 10.37 1.79016 9.02 2.84016L3.63 7.04016Z"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path d="M12 17.99V14.99" strokeLinecap="round" strokeLinejoin="round" />
  </NavIcon>
);

export const NavBidSwap = (p: NavIconProps) => (
  <NavIcon {...p}>
    <path
      d="M10 7.0268C10.483 4.17323 12.9665 2 15.9575 2C19.2947 2 22 4.70532 22 8.0425C22 11.0335 19.8268 13.517 16.9732 14"
      strokeLinejoin="round"
    />
    <path
      d="M8 22C11.3137 22 14 19.3137 14 16C14 12.6863 11.3137 10 8 10C4.68629 10 2 12.6863 2 16C2 19.3137 4.68629 22 8 22Z"
      strokeLinejoin="round"
    />
    <path d="M2 8C2 5.23571 4.23571 3 7 3V5" />
    <path d="M22 16C22 18.7643 19.7643 21 17 21V19" />
  </NavIcon>
);

export const NavMessages = (p: NavIconProps) => (
  <NavIcon {...p}>
    <path d="M7.5 14.4736H16.5M7.5 9.48438H13" strokeLinejoin="round" />
    <path d="M2.00989 21.4487L6.58552 19.9807C8.08688 20.8109 9.78899 20.9937 11.6746 20.9937C18.1751 21.4487 21.9977 17.2443 21.9977 12.2602C22.1047 7.30419 19.9149 2.0807 11.5775 2.46969C4.30503 2.59894 2.00391 7.03781 2.00391 12.0219C2.00391 13.7262 2.35123 15.8127 3.60536 17.452L2.00989 21.4487Z" />
  </NavIcon>
);

export const NavProfile = (p: NavIconProps) => (
  <NavIcon {...p}>
    <path
      d="M11.8301 10.87C9.45006 10.79 7.56006 8.84 7.56006 6.44C7.56006 3.99 9.54006 2 12.0001 2C14.4501 2 16.4401 3.99 16.4401 6.44C16.4301 8.84 14.5401 10.79 12.1601 10.87C12.0601 10.86 11.9401 10.86 11.8301 10.87Z"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M7.15973 20.43C9.90973 22.27 14.4197 22.27 17.1697 20.43C19.5897 18.81 19.5897 16.17 17.1697 14.56C14.4297 12.73 9.91973 12.73 7.15973 14.56C4.73973 16.18 4.73973 18.82 7.15973 20.43Z"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </NavIcon>
);
