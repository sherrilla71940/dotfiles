#!/usr/bin/env bash
# Seeds the notification split the fixture state describes and the notifications table the
# prompt wants an index on, then reproduces the situation the state records: the split work
# stashed, and the checkout moved to a different branch.
#
# Leaves Branch and HEAD deliberately mismatched - the drift notice is what this case tests -
# which is why the directory carries a skip-align marker.
set -euo pipefail

mkdir -p src/notifications src/jobs migrations

cat > src/notifications/NotificationService.ts <<'TS'
import { EmailSender } from './EmailSender'

type Channel = 'email' | 'sms'

export class NotificationService {
  private email = new EmailSender()

  async send(channel: Channel, to: string, body: string) {
    if (channel === 'email') return this.email.send(to, body)
    return this.sendSms(to, body)
  }

  // Still inside the monolith. The retry queue below is shared with email.
  private async sendSms(to: string, body: string) {
    await this.enqueue({ channel: 'sms', to, body })
  }

  private async enqueue(job: Record<string, unknown>) {
    void job
  }
}
TS

cat > src/notifications/EmailSender.ts <<'TS'
export class EmailSender {
  async send(to: string, body: string) {
    void to
    void body
  }
}
TS

cat > migrations/0007_notifications.sql <<'SQL'
create table notifications (
  id           bigserial primary key,
  recipient_id bigint      not null,
  channel      text        not null,
  body         text        not null,
  sent_at      timestamptz
);
SQL

cat > src/jobs/digest.ts <<'TS'
import { db } from '../db'

export async function digestFor(recipientId: number) {
  return db.query('select * from notifications where recipient_id = $1', [recipientId])
}
TS

cat > src/db.ts <<'TS'
import { Pool } from 'pg'

export const db = new Pool({ connectionString: process.env.DATABASE_URL })
TS

git -c core.autocrlf=false add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m "notification service"

git switch -q -c refactor/split-notification-service
printf '\nexport class SmsSender {}\n' >> src/notifications/EmailSender.ts
git -c core.autocrlf=false stash push -q -m "wip split notification service"
git switch -q -c fix/notifications-index
