/**
 * The sign-in, sign-up and password-reset calls.
 *
 * The API's auth endpoints are shaped a little unusually, and the quirks are
 * easier to absorb here once than at five call sites:
 *
 *  - `verify-account` serves two flows. After signup it returns a token pair
 *    and the account is live. After "forgot password" it returns a one-shot
 *    `token` that only `reset-password` accepts.
 *  - `reset-password` authenticates with that token in the header rather than
 *    with a session, and the server reads it from any of three header names.
 *  - `refresh-token` reads an httpOnly cookie the server set at login, so the
 *    browser has to be told to send credentials for it.
 */
import { api, API_BASE_URL } from "./api";
import { endpoints } from "./endpoints";
import { session } from "./session";
import type { User } from "./types";

interface TokenPair {
  accessToken: string;
  refreshToken?: string;
  role?: string;
  /** The reset token, when this came from the forgot-password flow. */
  token?: string;
}

export type OtpPurpose = "createAccount" | "resetPassword";

/** Where a verified OTP should take the person next. */
const PENDING_EMAIL = "pendingEmail";
const PENDING_PURPOSE = "pendingOtpPurpose";
const RESET_TOKEN = "resetToken";
const PENDING_NEXT = "pendingNext";

function remember(key: string, value: string) {
  try {
    window.sessionStorage.setItem(key, value);
  } catch {
    // Private mode. The flow still works inside this page; only a reload
    // mid-flow would lose it, and that sends the person back a step.
  }
}

function recall(key: string): string {
  try {
    return window.sessionStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}

function forget(key: string) {
  try {
    window.sessionStorage.removeItem(key);
  } catch {
    /* nothing to clean up */
  }
}

export const pending = {
  get email() {
    return recall(PENDING_EMAIL);
  },
  get purpose(): OtpPurpose {
    return (recall(PENDING_PURPOSE) as OtpPurpose) || "createAccount";
  },
  get resetToken() {
    return recall(RESET_TOKEN);
  },
  /** Where to land once the account is live. */
  get next() {
    return recall(PENDING_NEXT);
  },
  setNext(path: string) {
    remember(PENDING_NEXT, path);
  },
  set(email: string, purpose: OtpPurpose) {
    remember(PENDING_EMAIL, email);
    remember(PENDING_PURPOSE, purpose);
  },
  setResetToken(token: string) {
    remember(RESET_TOKEN, token);
  },
  clear() {
    forget(PENDING_EMAIL);
    forget(PENDING_PURPOSE);
    forget(RESET_TOKEN);
    forget(PENDING_NEXT);
  },
};

function store(tokens: TokenPair, email?: string) {
  session.save({
    accessToken: tokens.accessToken,
    ...(tokens.refreshToken ? { refreshToken: tokens.refreshToken } : {}),
    ...(email ? { userEmail: email } : {}),
  });
}

export const auth = {
  async login(email: string, password: string): Promise<void> {
    const data = await api.post<TokenPair>(
      endpoints.auth.login,
      { email: email.trim().toLowerCase(), password },
      { anonymous: true },
    );
    store(data, email.trim().toLowerCase());
    // The id is not in the login response, so the profile call doubles as the
    // first proof that the new token works.
    try {
      const me = await api.get<User>(endpoints.user.profile);
      if (me?._id) session.save({ userId: me._id });
    } catch {
      // A profile that fails to load is not a failed sign-in; the shell will
      // retry it on the next page.
    }
  },

  /** Creates the account and sends the 6-digit code. */
  async signUp(input: {
    name: string;
    email: string;
    password: string;
  }): Promise<void> {
    const email = input.email.trim().toLowerCase();
    await api.post(
      endpoints.auth.signUp,
      { name: input.name.trim(), email, password: input.password },
      { anonymous: true },
    );
    pending.set(email, "createAccount");
  },

  /**
   * Checks the code. After signup this signs the person in; after a password
   * reset it banks the one-shot token and leaves them signed out.
   */
  async verifyOtp(
    email: string,
    code: string,
    purpose: OtpPurpose,
  ): Promise<{ signedIn: boolean }> {
    const data = await api.post<TokenPair>(
      endpoints.auth.verifyAccount,
      { email: email.trim().toLowerCase(), oneTimeCode: code },
      { anonymous: true },
    );

    if (purpose === "resetPassword") {
      const token = data?.token ?? data?.accessToken ?? "";
      pending.setResetToken(token);
      return { signedIn: false };
    }

    if (data?.accessToken) {
      store(data, email.trim().toLowerCase());
      try {
        const me = await api.get<User>(endpoints.user.profile);
        if (me?._id) session.save({ userId: me._id });
      } catch {
        /* see login() */
      }
      return { signedIn: true };
    }
    return { signedIn: false };
  },

  async forgotPassword(email: string): Promise<void> {
    const address = email.trim().toLowerCase();
    await api.post(
      endpoints.auth.forgotPassword,
      { email: address },
      { anonymous: true },
    );
    pending.set(address, "resetPassword");
  },

  async resendOtp(email: string, purpose: OtpPurpose): Promise<void> {
    await api.post(
      endpoints.auth.resendOtp,
      { email: email.trim().toLowerCase(), authType: purpose },
      { anonymous: true },
    );
  },

  async resetPassword(newPassword: string, confirmPassword: string): Promise<void> {
    const token = pending.resetToken;
    if (!token) {
      throw new Error("That reset link has expired. Ask for a new code.");
    }
    // The server accepts the token under any of these three names depending on
    // the route it came through; the Flutter client sends all three, so this
    // one does too rather than betting on which.
    await api.post(
      endpoints.auth.resetPassword,
      { newPassword, confirmPassword },
      {
        anonymous: true,
        headers: {
          Authorization: `Bearer ${token}`,
          token,
          "forget-password-token": token,
        },
      },
    );
    pending.clear();
  },

  signOut(): void {
    // Best effort: the server wants to clear its cookie, but the session is
    // over on this device either way, so nothing waits on the response.
    const token = session.accessToken;
    if (token) {
      void fetch(`${API_BASE_URL}/auth/logout`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        credentials: "include",
        keepalive: true,
      }).catch(() => {});
    }
    session.clear();
    pending.clear();
  },
};

/** Google sign-in is a redirect the API owns end to end. */
export const googleSignInUrl = `${API_BASE_URL}/auth/google`;
