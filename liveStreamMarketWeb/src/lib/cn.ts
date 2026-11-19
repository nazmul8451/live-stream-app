/**
 * Join class names, dropping anything falsy.
 *
 * Deliberately not `tailwind-merge`: nothing here relies on a later class
 * overriding an earlier one, and the extra dependency would run on every
 * render for no gain.
 */
export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}
