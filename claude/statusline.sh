#!/usr/bin/env bash
set -euo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Claude status line requires Node.js" >&2
  exit 1
fi

node -e '
let input = "";

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  input += chunk;
});
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input);
    const cwd = data.cwd ?? data.workspace?.current_dir ?? "";
    const model = data.model?.display_name ?? "";
    const repository = data.workspace?.repo;
    const used = data.context_window?.used_percentage;
    const parts = [];

    if (cwd) {
      parts.push(cwd.replace(/[\\/]+$/, "").split(/[\\/]/).pop());
    }
    if (repository?.owner && repository?.name) {
      parts.push(`${repository.owner}/${repository.name}`);
    }
    if (model) {
      parts.push(model);
    }
    if (Number.isFinite(used)) {
      parts.push(`ctx:${Math.round(used)}%`);
    }

    process.stdout.write(parts.join(" | "));
  } catch (error) {
    process.stderr.write(`Claude status line received invalid JSON: ${error.message}\n`);
    process.exitCode = 1;
  }
});
'
