import { endpoints } from "./endpoints";
import { session } from "./session";

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "https://api.areisco.com/api/v1";

/** Host that serves uploaded media and the server-rendered legal pages. */
export const MEDIA_BASE_URL =
  process.env.NEXT_PUBLIC_MEDIA_URL ?? "https://api.areisco.com";

/** The envelope every endpoint responds with. */
export interface ApiEnvelope<T> {
  statusCode: number;
  success: boolean;
  message: string;
  data: T;
  meta?: { page: number; limit: number; total: number; totalPages: number };
}

export class ApiError extends Error {
  readonly status: number;
  readonly body: unknown;

  constructor(status: number, message: string, body?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.body = body;
  }
}

/** Raised when the session is gone for good and the user must sign in again. */
export class SessionExpiredError extends ApiError {
  constructor(message = "Your session has expired. Please log in again.") {
    super(401, message);
    this.name = "SessionExpiredError";
  }
}

type Json = Record<string, unknown>;

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: Json | unknown[] | FormData;
  /** Skip the Authorization header — for login, signup and the like. */
  anonymous?: boolean;
  /**
   * Extra headers. Used by password reset, which authenticates with a
   * short-lived reset token rather than the session's access token.
   */
  headers?: Record<string, string>;
  signal?: AbortSignal;
  /** Internal: prevents a refresh loop. */
  _retried?: boolean;
}

/**
 * Messages the API uses when a token is not merely stale but unusable — the
 * account was deleted or deactivated, or the token is malformed. Refreshing
 * cannot help with any of them, so the session is dropped instead.
 *
 * Mirrors the same list in the Flutter client's `_checkAndRefreshToken`.
 */
const UNRECOVERABLE = [
  "account is deleted",
  "account has been deleted",
  "user not found",
  "user does not exist",
  "account is deactivated",
  "jwt malformed",
  "invalid token",
  "invalid signature",
];

/**
 * A single in-flight refresh shared by every caller.
 *
 * Without this, a page that fires five requests at once on a stale token would
 * start five refreshes; four of them would present an already-rotated refresh
 * token and fail, signing the user out mid-session.
 */
let refreshInFlight: Promise<boolean> | null = null;

async function refreshAccessToken(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = (async () => {
    const refreshToken = session.refreshToken;
    if (!refreshToken) return false;

    try {
      const response = await fetch(`${API_BASE_URL}${endpoints.auth.refreshToken}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: `Bearer ${refreshToken}`,
        },
        body: JSON.stringify({ refreshToken }),
      });

      if (!response.ok) return false;

      const payload = (await response.json()) as ApiEnvelope<{
        accessToken?: string;
        refreshToken?: string;
      }>;
      const accessToken = payload?.data?.accessToken;
      if (!accessToken) return false;

      session.save({
        accessToken,
        ...(payload.data.refreshToken
          ? { refreshToken: payload.data.refreshToken }
          : {}),
      });
      return true;
    } catch {
      // Offline, or the refresh endpoint is down. Keep the tokens: the user is
      // not signed out by a flaky network.
      return false;
    } finally {
      refreshInFlight = null;
    }
  })();

  return refreshInFlight;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, anonymous = false, signal } = options;

  const headers: Record<string, string> = {
    Accept: "application/json",
    ...options.headers,
  };
  const isFormData = typeof FormData !== "undefined" && body instanceof FormData;
  if (body !== undefined && !isFormData) headers["Content-Type"] = "application/json";

  const token = anonymous ? "" : session.accessToken;
  if (token && !headers.Authorization) headers.Authorization = `Bearer ${token}`;

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers,
      signal,
      body: isFormData ? body : body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch (error) {
    if ((error as Error)?.name === "AbortError") throw error;
    throw new ApiError(0, "Could not reach the server. Check your connection.");
  }

  // 204 and friends carry nothing to parse.
  const text = await response.text();
  let payload: ApiEnvelope<T> | undefined;
  if (text) {
    try {
      payload = JSON.parse(text) as ApiEnvelope<T>;
    } catch {
      payload = undefined;
    }
  }

  if (response.ok) return payload?.data as T;

  const message =
    (payload as unknown as { message?: string })?.message ||
    `Request failed (${response.status})`;

  if (UNRECOVERABLE.some((needle) => message.toLowerCase().includes(needle))) {
    session.clear();
    throw new SessionExpiredError(message);
  }

  // A stale access token is worth one silent retry; a second 401 after a fresh
  // token means the session is genuinely over.
  if (response.status === 401 && !anonymous && !options._retried && session.refreshToken) {
    const refreshed = await refreshAccessToken();
    if (refreshed) return request<T>(path, { ...options, _retried: true });
    session.clear();
    throw new SessionExpiredError();
  }

  throw new ApiError(response.status, message, payload);
}

/** Returns the full envelope, for the endpoints that paginate via `meta`. */
async function requestWithMeta<T>(
  path: string,
  options: RequestOptions = {},
): Promise<ApiEnvelope<T>> {
  const headers: Record<string, string> = { Accept: "application/json" };
  const token = options.anonymous ? "" : session.accessToken;
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? "GET",
    headers,
    signal: options.signal,
  });
  const payload = (await response.json()) as ApiEnvelope<T>;
  if (!response.ok) {
    throw new ApiError(response.status, payload?.message ?? "Request failed", payload);
  }
  return payload;
}

export const api = {
  get: <T>(path: string, options?: Omit<RequestOptions, "method" | "body">) =>
    request<T>(path, { ...options, method: "GET" }),
  post: <T>(path: string, body?: Json | unknown[] | FormData, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "POST", body }),
  patch: <T>(path: string, body?: Json, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "PATCH", body }),
  put: <T>(path: string, body?: Json, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "PUT", body }),
  delete: <T>(path: string, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "DELETE" }),
  withMeta: requestWithMeta,
};

/**
 * Turns whatever the API hands back for an image into something `<img>` can
 * load. Uploads come back as bare paths (`/images/abc.jpg`); some records
 * carry absolute URLs; some carry nothing.
 */
export function mediaUrl(raw: unknown): string {
  const value = typeof raw === "string" ? raw.trim() : "";
  if (!value || value === "null" || value === "undefined") return "";
  if (
    value.startsWith("http://") ||
    value.startsWith("https://") ||
    value.startsWith("data:image/")
  ) {
    return value;
  }
  return `${MEDIA_BASE_URL}${value.startsWith("/") ? "" : "/"}${value}`;
}
