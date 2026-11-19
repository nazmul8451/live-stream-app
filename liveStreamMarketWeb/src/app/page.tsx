import { redirect } from "next/navigation";

/**
 * The marketplace will live here. Until it is built, the root sends people to
 * sign in rather than showing a placeholder that looks like a broken home
 * page.
 */
export default function RootPage() {
  redirect("/login");
}
