"use client";

import Link from "next/link";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconBell } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { api } from "@/lib/api";
import { cn } from "@/lib/cn";
import { timeAgo } from "@/lib/format";
import { notifications } from "@/lib/resources";
import type { AppNotification } from "@/lib/types";

export default function NotificationsPage() {
  return (
    <RequireAuth>
      <Notifications />
    </RequireAuth>
  );
}

function Notifications() {
  const list = useApi((signal) => notifications.mine(signal), "notifications");
  const items = list.data ?? [];
  const unread = items.filter((item) => !item.isRead);

  const markAll = useAction(async () => {
    await api.patch("/notifications/read-all");
    list.reload();
  });

  return (
    <Container className="max-w-3xl pb-16">
      <PageHeader
        title="Notifications"
        description={
          unread.length > 0
            ? `${unread.length} unread.`
            : "Bids, offers, orders and follows land here."
        }
        action={
          unread.length > 0 ? (
            <Button
              variant="secondary"
              size="sm"
              loading={markAll.pending}
              onClick={() => void markAll.run()}
            >
              Mark all read
            </Button>
          ) : undefined
        }
      />

      {list.error ? <Alert className="mb-6">{list.error.message}</Alert> : null}
      {markAll.error ? <Alert className="mb-6">{markAll.error}</Alert> : null}

      {list.loading ? (
        <div className="space-y-2.5">
          {Array.from({ length: 5 }).map((_, index) => (
            <Skeleton key={index} className="h-20 w-full rounded-card" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<IconBell size={26} />}
          title="Nothing yet"
          description="You will hear when someone bids on your lot, offers a swap or buys something."
        />
      ) : (
        <ul className="space-y-2.5">
          {items.map((item) => (
            <li key={item._id}>
              <NotificationRow notification={item} onRead={list.reload} />
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}

function NotificationRow({
  notification,
  onRead,
}: {
  notification: AppNotification;
  onRead: () => void;
}) {
  const read = useAction(async () => {
    await notifications.markRead(notification._id);
    onRead();
  });

  const body = (
    <Card
      className={cn(
        "flex items-start gap-3.5 transition-colors",
        !notification.isRead && "border-accent/25 bg-accent/[0.05]",
      )}
    >
      <span
        aria-hidden
        className={cn(
          "mt-1.5 size-2 shrink-0 rounded-full",
          notification.isRead ? "bg-transparent" : "bg-accent",
        )}
      />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-black text-ink">{notification.title}</p>
        {notification.content ? (
          <p className="pt-0.5 text-[13px] leading-relaxed text-ink-muted">
            {notification.content}
          </p>
        ) : null}
        <p className="pt-1.5 text-[11px] font-bold text-ink-faint">
          {timeAgo(notification.createdAt)}
        </p>
      </div>
      {!notification.isRead ? (
        <button
          type="button"
          onClick={(event) => {
            event.preventDefault();
            void read.run();
          }}
          className="shrink-0 rounded-md text-[11px] font-black uppercase tracking-[0.08em] text-ink-dim hover:text-ink focus-visible:outline-2 focus-visible:outline-accent"
        >
          Mark read
        </button>
      ) : null}
    </Card>
  );

  // The API hands back an in-app path for the ones that point somewhere.
  return notification.actionUrl?.startsWith("/") ? (
    <Link href={notification.actionUrl} className="block">
      {body}
    </Link>
  ) : (
    body
  );
}
