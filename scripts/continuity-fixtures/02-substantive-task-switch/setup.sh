#!/usr/bin/env bash
# Seeds the auth tree the fixture state describes, plus the upload endpoint the prompt
# asks to rate-limit. Leaves session.ts and refresh.ts modified, matching the Status the state records.
set -euo pipefail

mkdir -p src/auth src/net
cat > src/auth/session.ts <<'TS'
import { redis } from './redis-client'

const TTL_SECONDS = 60 * 60 * 12

export async function readSession(token: string) {
  const raw = await redis.get(`session:${token}`)
  return raw ? JSON.parse(raw) : null
}

export async function writeSession(token: string, value: unknown) {
  await redis.set(`session:${token}`, JSON.stringify(value), 'EX', TTL_SECONDS)
}
TS
cat > src/auth/legacy-session.ts <<'TS'
import { readFileSync, writeFileSync } from 'node:fs'

// The store this migration is replacing. Single-process only.
const FILE = '/var/lib/app/sessions.json'

export function readLegacy(token: string) {
  const all = JSON.parse(readFileSync(FILE, 'utf8'))
  return all[token] ?? null
}

export function writeLegacy(token: string, value: unknown) {
  const all = JSON.parse(readFileSync(FILE, 'utf8'))
  all[token] = value
  writeFileSync(FILE, JSON.stringify(all))
}
TS
cat > src/auth/login.ts <<'TS'
import { writeSession } from './session'

export async function login(userId: string) {
  const token = crypto.randomUUID()
  await writeSession(token, { userId, issuedAt: Date.now() })
  return token
}
TS
cat > src/auth/refresh.ts <<'TS'
import { readLegacy, writeLegacy } from './legacy-session'

// Rotation still reads the old store directly. This is the unmigrated path.
export async function refresh(token: string) {
  const session = readLegacy(token)
  if (!session) return null
  const next = crypto.randomUUID()
  writeLegacy(next, { ...session, issuedAt: Date.now() })
  return next
}
TS
cat > src/auth/redis-client.ts <<'TS'
import Redis from 'ioredis'

export const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379')
TS
cat > src/net/retry.ts <<'TS'
type RetryOptions = { attempts?: number; baseMs?: number; capMs?: number }

/**
 * Decorrelated jitter backoff. The delay is drawn from a widening window rather
 * than multiplied, so a fleet retrying together does not resynchronise into a
 * thundering herd the way plain exponential backoff does.
 */
export async function withRetry<T>(fn: () => Promise<T>, options: RetryOptions = {}) {
  const { attempts = 5, baseMs = 100, capMs = 20_000 } = options
  let sleep = baseMs
  let lastError: unknown

  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error
      sleep = Math.min(capMs, randomBetween(baseMs, sleep * 3))
      await delay(sleep)
    }
  }
  throw lastError
}

const randomBetween = (low: number, high: number) => low + Math.random() * (high - low)
const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
TS
cat > package.json <<'JSON'
{
  "name": "app",
  "private": true,
  "dependencies": { "ioredis": "^5.4.1" }
}
JSON
mkdir -p src/routes
cat > src/routes/upload.ts <<'TS'
import { Router } from 'express'

export const uploadRouter = Router()

uploadRouter.post('/upload', async (req, res) => {
  const size = Number(req.headers['content-length'] ?? 0)
  if (size > 25 * 1024 * 1024) return res.status(413).json({ error: 'too large' })
  const id = await store(req)
  res.status(201).json({ id })
})

async function store(_req: unknown) {
  return crypto.randomUUID()
}
TS
cat > src/routes/index.ts <<'TS'
import { Router } from 'express'
import { uploadRouter } from './upload'

export const router = Router()
router.use(uploadRouter)
TS
git -c core.autocrlf=false add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m "auth and net helpers"

# The state records uncommitted work in these two files; leave it that way.
printf '\n// TODO(migration): rotation still reads the legacy store\n' >> src/auth/refresh.ts
printf '\nexport const MIGRATION_IN_PROGRESS = true\n' >> src/auth/session.ts
