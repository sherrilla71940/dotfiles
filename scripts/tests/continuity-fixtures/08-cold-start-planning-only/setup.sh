#!/usr/bin/env bash
# Runs inside the throwaway repository. This case has no fixture state by design, so
# there is nothing to align; the job is to seed enough of a tree that a planning
# question has something real to work with.
set -euo pipefail

mkdir -p src/queue src/jobs
cat > package.json <<'JSON'
{
  "name": "queue-service",
  "private": true,
  "dependencies": { "ioredis": "^5.4.1", "pg": "^8.12.0" }
}
JSON
cat > src/queue/client.js <<'JS'
const Redis = require('ioredis')

const connection = new Redis(process.env.REDIS_URL)

async function enqueue(name, payload, { delayMs = 0 } = {}) {
  const id = `${name}:${Date.now()}:${Math.random().toString(36).slice(2)}`
  const score = Date.now() + delayMs
  await connection.zadd('jobs:scheduled', score, JSON.stringify({ id, name, payload }))
  return id
}

async function claim(limit = 10) {
  const now = Date.now()
  const raw = await connection.zrangebyscore('jobs:scheduled', 0, now, 'LIMIT', 0, limit)
  if (raw.length === 0) return []
  await connection.zrem('jobs:scheduled', ...raw)
  return raw.map((entry) => JSON.parse(entry))
}

module.exports = { enqueue, claim, connection }
JS
cat > src/jobs/worker.js <<'JS'
const { claim } = require('../queue/client')

async function tick(handlers) {
  for (const job of await claim()) {
    const handler = handlers[job.name]
    if (!handler) continue
    await handler(job.payload)
  }
}

module.exports = { tick }
JS
git -c core.autocrlf=false add -A   # the warning is noise in a throwaway repo
git -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m "queue service"
