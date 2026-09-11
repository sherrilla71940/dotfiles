#!/usr/bin/env bash
# Seeds the migrated PDF renderer the fixture state reports as finished, so the state's
# "clean; golden-file suite passes" is true of this tree and the status question has a real
# answer. Everything is committed: the point of this case is a task with nothing left.
set -euo pipefail

mkdir -p src/invoices test/golden

cat > src/invoices/renderer.ts <<'TS'
import PDFDocument from 'pdfkit'
import { loadSubsettedFont } from './fonts'

export function renderInvoice(invoice: { id: string; lines: string[] }) {
  const doc = new PDFDocument({ size: 'A4', margin: 56 })
  loadSubsettedFont(doc, 'Inter-Regular')
  doc.fontSize(18).text(`Invoice ${invoice.id}`)
  for (const line of invoice.lines) doc.fontSize(11).text(line)
  doc.end()
  return doc
}
TS

cat > src/invoices/fonts.ts <<'TS'
import { readFileSync } from 'node:fs'

// Kept from before the upstream move: upstream's loader cannot read the bundled
// subsetted fonts, and replacing those is a separate piece of work.
export function loadSubsettedFont(doc: { registerFont: (name: string, data: Buffer) => void }, name: string) {
  doc.registerFont(name, readFileSync(`assets/fonts/${name}.subset.ttf`))
}
TS

cat > test/golden/invoice-1001.txt <<'TXT'
Invoice INV-1001
Consulting, May 2026
Total 1320.00
TXT

cat > package.json <<'JSON'
{
  "name": "app",
  "private": true,
  "dependencies": { "pdfkit": "^0.15.0" }
}
JSON

git -c core.autocrlf=false add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m "move invoice renderer to upstream pdfkit"
