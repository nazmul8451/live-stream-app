/**
 * Where the browser keeps the signed-in session.
 *
 * The API issues the same JWT pair the Flutter app uses, so the key names match
 * `SharePrefsHelper` there. Storage is wrapped because every access can throw —
 * Safari in private mode, blocked site data, or a server render where there is
 * no `window` at all — and a thrown error here would take the whole page down.
 */

const ACCESS_TOKEN = "accessToken";
const REFRESH_TOKEN = "refreshToken";
const USER_ID = "userId";
const USER_EMAIL = "userEmail";

type Listener = () => void;
const listeners = new Set<Listener>();

function read(key: string): string {
  if (typeof window === "undefined") return "";
  try {
    return window.localStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}

function write(key: string, value: string): void {
  if (typeof window === "undefined") return;
  try {
    if (value) window.localStorage.setItem(key, value);
    else window.localStorage.removeItem(key);
  } catch {
    // A session that cannot be persisted still works for this tab; it just
    // does not survive a reload. That is better than refusing to sign in.
  }
}

export const session = {
  get accessToken(): string {
    return read(ACCESS_TOKEN);
  },
  get refreshToken(): string {
    return read(REFRESH_TOKEN);
  },
  get userId(): string {
    return read(USER_ID);
  },
  get userEmail(): string {
    return read(USER_EMAIL);
  },
  get isSignedIn(): boolean {
    return read(ACCESS_TOKEN).length > 0;
  },

  save(tokens: {
    accessToken?: string;
    refreshToken?: string;
    userId?: string;
    userEmail?: string;
  }): void {
    if (tokens.accessToken !== undefined) write(ACCESS_TOKEN, tokens.accessToken);
    if (tokens.refreshToken !== undefined) write(REFRESH_TOKEN, tokens.refreshToken);
    if (tokens.userId !== undefined) write(USER_ID, tokens.userId);
    if (tokens.userEmail !== undefined) write(USER_EMAIL, tokens.userEmail);
    notify();
  },

  clear(): void {
    write(ACCESS_TOKEN, "");
    write(REFRESH_TOKEN, "");
    write(USER_ID, "");
    write(USER_EMAIL, "");
    notify();
  },

  /** Subscribe to sign-in/sign-out so UI can react without a reload. */
  subscribe(listener: Listener): () => void {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },
};

function notify(): void {
  for (const listener of listeners) listener();
}
