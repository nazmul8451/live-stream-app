"use client";

import { useRouter, useSearchParams } from "next/navigation";
import {
  Suspense,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { Container } from "@/components/layout/Page";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { EmptyState, Skeleton } from "@/components/ui/Card";
import { IconChat, IconSearch } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { timeAgo } from "@/lib/format";
import { chats } from "@/lib/resources";
import { chatEvents, onAny } from "@/lib/socket";
import {
  chatPreview,
  displayName,
  messageSenderId,
  type Chat,
  type Message,
  type UserSummary,
} from "@/lib/types";

/**
 * Messages.
 *
 * Two panes side by side once there is room for both, one pane below that —
 * and which pane you are looking at lives in the URL, so the browser's back
 * button walks out of a thread the way it should and a conversation can be
 * linked to.
 *
 * Everything updates over the socket the app already uses: a new message
 * lands in the open thread and moves its conversation to the top of the list
 * without anyone reloading anything.
 */
export default function MessagesPage() {
  return (
    <RequireAuth>
      <Suspense fallback={<MessagesSkeleton />}>
        <Messages />
      </Suspense>
    </RequireAuth>
  );
}

function Messages() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { user } = useSession();
  const meId = user?._id ?? "";

  const list = useApi((signal) => chats.list(signal), "chats");
  const conversations = useMemo(() => list.data ?? [], [list.data]);

  const [search, setSearch] = useState("");
  const activeId = searchParams?.get("chat") ?? "";
  const wantedUser = searchParams?.get("user") ?? "";

  // The list is the server's state, so a new message anywhere re-reads it
  // rather than this screen trying to patch it by hand.
  const reloadList = list.reload;
  useEffect(() => {
    if (!meId) return;
    return onAny(chatEvents.listChanged(meId), () => reloadList());
  }, [meId, reloadList]);

  const open = useCallback(
    (chatId: string) => {
      const next = new URLSearchParams(searchParams?.toString() ?? "");
      next.set("chat", chatId);
      next.delete("user");
      router.replace(`/messages?${next}`, { scroll: false });
    },
    [router, searchParams],
  );

  // Arriving from a trade or a profile with ?user= opens that person's thread.
  useEffect(() => {
    if (!wantedUser || conversations.length === 0) return;
    const match = conversations.find((chat) =>
      (chat.participants ?? []).some((person) => person._id === wantedUser),
    );
    if (match) open(match._id);
  }, [wantedUser, conversations, open]);

  const active = conversations.find((chat) => chat._id === activeId);

  const filtered = search.trim()
    ? conversations.filter((chat) =>
        displayName(otherPerson(chat, meId))
          .toLowerCase()
          .includes(search.trim().toLowerCase()),
      )
    : conversations;

  if (list.loading && conversations.length === 0) return <MessagesSkeleton />;

  if (list.error && conversations.length === 0) {
    return (
      <Container className="py-16">
        <Alert>
          {list.error.message}{" "}
          <button
            type="button"
            onClick={() => list.reload()}
            className="font-black underline underline-offset-2"
          >
            Try again
          </button>
        </Alert>
      </Container>
    );
  }

  if (conversations.length === 0) {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconChat size={26} />}
          title="No conversations"
          description="Message a seller from a listing, or a trader from one of their items, and the thread starts here."
        />
      </Container>
    );
  }

  return (
    <Container className="pb-6">
      {/*
        The pane fills what is left of the window rather than a fixed height,
        so the thread scrolls inside itself on a laptop and on a phone instead
        of the whole page scrolling under a stuck composer.
      */}
      <div
        className={cn(
          "grid gap-4 py-5",
          // What is left of the window once the bars are out of it: the top
          // bar plus the phone search row, the page padding, and the tab bar
          // the shell reserves with `pb-24` / `md:pb-16`. Getting this wrong
          // is what puts the composer underneath the tab bar.
          "h-[calc(100dvh-16rem)] md:h-[calc(100dvh-14rem)] lg:h-[calc(100dvh-11rem)]",
          "lg:grid-cols-[340px_minmax(0,1fr)]",
        )}
      >
        <section
          aria-label="Conversations"
          className={cn(
            "flex min-h-0 flex-col overflow-hidden rounded-card-lg border border-hairline bg-surface",
            active ? "hidden lg:flex" : "flex",
          )}
        >
          <div className="border-b border-hairline p-3">
            <label className="flex items-center gap-2.5 rounded-pill border border-hairline bg-canvas-raised px-3.5 focus-within:border-accent/50">
              <IconSearch size={16} className="shrink-0 text-ink-dim" />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search people"
                aria-label="Search conversations"
                className="h-9 min-w-0 flex-1 bg-transparent text-[13px] font-medium text-ink placeholder:text-ink-faint focus:outline-none"
              />
            </label>
          </div>

          <ul className="min-h-0 flex-1 divide-y divide-hairline overflow-y-auto">
            {filtered.length === 0 ? (
              <li className="px-4 py-10 text-center text-xs text-ink-faint">
                No one matches “{search.trim()}”.
              </li>
            ) : (
              filtered.map((chat) => (
                <li key={chat._id}>
                  <ConversationRow
                    chat={chat}
                    meId={meId}
                    active={chat._id === activeId}
                    onSelect={() => open(chat._id)}
                  />
                </li>
              ))
            )}
          </ul>
        </section>

        {active ? (
          <Thread
            key={active._id}
            chat={active}
            meId={meId}
            onBack={() => router.replace("/messages", { scroll: false })}
            onSent={() => list.reload()}
          />
        ) : (
          <section className="hidden min-h-0 items-center justify-center rounded-card-lg border border-hairline bg-surface lg:flex">
            <p className="text-sm text-ink-dim">Pick a conversation.</p>
          </section>
        )}
      </div>
    </Container>
  );
}

function otherPerson(chat: Chat, meId: string): UserSummary | undefined {
  const others = (chat.participants ?? []).filter((person) => person._id !== meId);
  // The server already filters you out; this is only a guard for the case
  // where it has not.
  return others[0] ?? chat.participants?.[0];
}

function ConversationRow({
  chat,
  meId,
  active,
  onSelect,
}: {
  chat: Chat;
  meId: string;
  active: boolean;
  onSelect: () => void;
}) {
  const person = otherPerson(chat, meId);
  const preview = chatPreview(chat);
  const unread = chat.unreadCount ?? 0;

  return (
    <button
      type="button"
      onClick={onSelect}
      aria-current={active}
      className={cn(
        "flex w-full items-center gap-3 px-3.5 py-3 text-left transition-colors",
        "focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-accent",
        active ? "bg-white/[0.07]" : "hover:bg-white/[0.03]",
      )}
    >
      <Avatar user={person} size="md" />
      <div className="min-w-0 flex-1">
        <p
          className={cn(
            "truncate text-sm",
            unread > 0 ? "font-black text-ink" : "font-bold text-ink",
          )}
        >
          {displayName(person)}
        </p>
        <p
          className={cn(
            "truncate text-xs",
            unread > 0 ? "font-semibold text-ink-muted" : "text-ink-dim",
          )}
        >
          {preview.text}
        </p>
      </div>
      <div className="flex shrink-0 flex-col items-end gap-1">
        <span className="text-[11px] font-bold text-ink-faint">
          {timeAgo(preview.at)}
        </span>
        {unread > 0 ? (
          <span className="inline-flex min-w-5 items-center justify-center rounded-full bg-accent px-1.5 text-[10px] font-black text-[#0F172A]">
            {unread > 99 ? "99+" : unread}
          </span>
        ) : null}
      </div>
    </button>
  );
}

function Thread({
  chat,
  meId,
  onBack,
  onSent,
}: {
  chat: Chat;
  meId: string;
  onBack: () => void;
  onSent: () => void;
}) {
  const person = otherPerson(chat, meId);
  const history = useApi(
    (signal) => chats.messages(chat._id, signal),
    `messages-${chat._id}`,
  );

  const [live, setLive] = useState<Message[]>([]);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string>();
  const endRef = useRef<HTMLDivElement>(null);

  // Opening a chat marks its messages seen server-side, so the list needs
  // re-reading to drop the unread badge. Once per chat: the refresh changes
  // the list, and reacting to that would ask for another one.
  const refreshed = useRef<string>("");
  const onSentRef = useRef(onSent);
  useEffect(() => {
    onSentRef.current = onSent;
  });
  useEffect(() => {
    if (history.loading || refreshed.current === chat._id) return;
    refreshed.current = chat._id;
    onSentRef.current();
  }, [history.loading, chat._id]);

  useEffect(() => {
    return onAny(chatEvents.message(chat._id), (payload) => {
      const message = unwrapMessage(payload);
      if (!message) return;
      setLive((previous) =>
        previous.some((item) => item._id === message._id)
          ? previous
          : [...previous, message],
      );
    });
  }, [chat._id]);

  const all = useMemo(() => {
    // The API sorts newest first for its own paging; a thread reads oldest at
    // the top, so it is flipped here before anything renders it.
    const ordered = [...(history.data ?? [])].reverse();
    const seen = new Set<string>();
    return [...ordered, ...live].filter((message) => {
      if (!message?._id || seen.has(message._id)) return false;
      seen.add(message._id);
      return true;
    });
  }, [history.data, live]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ block: "end" });
  }, [all.length]);

  async function send(event: FormEvent) {
    event.preventDefault();
    const body = text.trim();
    if (!body || sending) return;
    setSending(true);
    setError(undefined);
    try {
      const sent = await chats.send(chat._id, { text: body });
      if (sent?._id) {
        setLive((previous) =>
          previous.some((item) => item._id === sent._id)
            ? previous
            : [...previous, sent],
        );
      }
      setText("");
      onSent();
    } catch (sendError) {
      setError(errorMessage(sendError));
    } finally {
      setSending(false);
    }
  }

  return (
    <section
      aria-label={`Conversation with ${displayName(person)}`}
      className={cn(
        "flex min-h-0 flex-col overflow-hidden",
        // On a phone a conversation is its own screen, the way it is in the
        // app: over the search row and the tab bar, with its own header,
        // rather than a short pane squeezed between them.
        "fixed inset-0 z-50 bg-canvas",
        "lg:static lg:z-auto lg:rounded-card-lg lg:border lg:border-hairline lg:bg-surface",
      )}
    >
      <header className="flex items-center gap-3 border-b border-hairline bg-canvas/90 px-3 py-3 backdrop-blur-xl pt-[max(0.75rem,env(safe-area-inset-top))] lg:bg-transparent lg:px-3.5 lg:pt-3 lg:backdrop-blur-none">
        <button
          type="button"
          onClick={onBack}
          aria-label="Back to conversations"
          className="-ml-1 flex size-9 shrink-0 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-white/[0.06] hover:text-ink focus-visible:outline-2 focus-visible:outline-accent lg:hidden"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden>
            <path
              d="M15 19l-7-7 7-7"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
        <Avatar user={person} size="sm" />
        <p className="min-w-0 flex-1 truncate text-sm font-black text-ink">
          {displayName(person)}
        </p>
      </header>

      <div className="min-h-0 flex-1 space-y-2 overflow-y-auto px-3.5 py-4">
        {history.loading ? (
          <div className="space-y-3">
            <Skeleton className="h-10 w-2/3" />
            <Skeleton className="ml-auto h-10 w-1/2" />
            <Skeleton className="h-10 w-3/5" />
          </div>
        ) : all.length === 0 ? (
          <p className="pt-16 text-center text-xs text-ink-faint">
            No messages yet. Say hello.
          </p>
        ) : (
          all.map((message, index) => {
            const mine = messageSenderId(message) === meId;
            const previous = all[index - 1];
            // Only the first message in a run needs the gap above it.
            const startsRun =
              !previous || messageSenderId(previous) !== messageSenderId(message);
            // Order updates are the platform talking, not a person, so they
            // sit in the middle rather than taking a side.
            if (message.messageType === "order_update") {
              return (
                <div key={message._id} className="flex justify-center py-1.5">
                  <p className="max-w-[90%] rounded-xl border border-hairline bg-white/[0.03] px-3 py-2 text-center text-[11px] font-semibold leading-relaxed text-ink-muted">
                    {message.metadata?.statusLabel ? (
                      <span className="block pb-0.5 text-[10px] font-black uppercase tracking-[0.1em] text-accent">
                        {message.metadata.statusLabel}
                      </span>
                    ) : null}
                    {message.text}
                    {message.metadata?.trackingNumber ? (
                      <span className="block pt-0.5 text-[10px] font-bold text-ink-dim">
                        {message.metadata.trackingNumber}
                      </span>
                    ) : null}
                  </p>
                </div>
              );
            }

            return (
              <div
                key={message._id}
                className={cn(
                  "flex",
                  mine ? "justify-end" : "justify-start",
                  startsRun && index > 0 && "pt-2",
                )}
              >
                <div className="max-w-[85%] space-y-1 sm:max-w-[70%]">
                  {message.messageType === "trade_proposal" ? (
                    <p className="px-1 text-[10px] font-black uppercase tracking-[0.1em] text-pink">
                      Swap proposal
                    </p>
                  ) : null}

                  {message.image ? (
                    <span className="block overflow-hidden rounded-[22px] border border-hairline">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={mediaUrl(message.image)}
                        alt=""
                        className="max-h-64 w-full object-cover"
                      />
                    </span>
                  ) : null}

                  {message.text ? (
                    <p
                      className={cn(
                        "rounded-[22px] px-3.5 py-2.5 text-[13px] leading-relaxed break-words",
                        // The app squares off the corner nearest the sender,
                        // which is what makes a run of bubbles read as one
                        // person talking.
                        mine
                          ? "rounded-br-[4px] bg-[#929BF5] font-semibold text-[#0F0B1E]"
                          : "rounded-bl-[4px] bg-[#1E1E2C] text-ink",
                      )}
                    >
                      {message.text}
                    </p>
                  ) : null}

                  <p
                    className={cn(
                      "flex items-center gap-1 px-1 text-[10px] font-bold text-ink-faint",
                      mine ? "justify-end" : "justify-start",
                    )}
                  >
                    {timeAgo(message.createdAt)}
                    {mine && message.seen ? <span>· Seen</span> : null}
                  </p>
                </div>
              </div>
            );
          })
        )}
        <div ref={endRef} />
      </div>

      {error ? (
        <p role="alert" className="px-4 pb-2 text-xs text-danger">
          {error}
        </p>
      ) : null}

      <form
        onSubmit={send}
        className="flex gap-2 border-t border-hairline p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] lg:pb-3"
      >
        <input
          value={text}
          onChange={(event) => setText(event.target.value)}
          placeholder="Write a message…"
          aria-label="Message"
          className="h-11 min-w-0 flex-1 rounded-pill border border-hairline bg-canvas-raised px-4 text-[13px] font-medium text-ink placeholder:text-ink-faint focus:border-accent/50 focus:outline-none"
        />
        <Button type="submit" loading={sending} disabled={!text.trim()}>
          Send
        </Button>
      </form>
    </section>
  );
}

/** The socket sends the message itself; some deployments wrap it in `data`. */
function unwrapMessage(payload: unknown): Message | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const source = payload as Record<string, unknown>;
  const candidate = (source.data ?? source) as Record<string, unknown>;
  return candidate && typeof candidate === "object" && "_id" in candidate
    ? (candidate as unknown as Message)
    : undefined;
}

function MessagesSkeleton() {
  return (
    <Container className="pb-6">
      <div className="grid h-[calc(100dvh-16rem)] gap-4 py-5 md:h-[calc(100dvh-14rem)] lg:h-[calc(100dvh-11rem)] lg:grid-cols-[340px_minmax(0,1fr)]">
        <Skeleton className="rounded-card-lg" />
        <Skeleton className="hidden rounded-card-lg lg:block" />
      </div>
    </Container>
  );
}
