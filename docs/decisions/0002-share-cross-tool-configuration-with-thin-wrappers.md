# ADR-0002: Share cross-tool configuration with thin wrappers

- Status: Accepted
- Date: 2026-08-11

## Context

Claude Code, Codex, and GitHub Copilot can use much of the same guidance, but they discover
instructions and skills through different paths and metadata. Copying a shared body into
each tool would make fixes drift. Forcing tool-specific behavior into neutral wording would
erase useful capabilities and still not solve incompatible frontmatter or discovery rules.

Codex also cannot import instruction fragments or path-scope them, and its personal skills
share `~/.agents/skills` with Copilot. Claude can discover the shared skills through links
while retaining a separate directory for Claude-only skills.

## Decision

- Store each shared instruction body once under `home/.chezmoitemplates/` and render it
  through thin tool-specific wrappers when metadata differs.
- Store portable skills once under `home/dot_agents/skills/`.
- Expose each portable skill to Claude with an individual chezmoi-managed symlink template
  under `home/dot_claude/skills/`. Individual links allow real Claude-only skill directories
  to coexist in the same target directory.
- Keep genuinely tool-specific instructions, rules, skills, and commands in that tool's
  source tree. Do not create neutral paraphrases of tool-specific content.
- Codex personal skills normally live in `~/.agents/skills`, which Copilot also scans. Treat
  them as portable shared skills. If one must be Codex-only, verify the current supported
  isolation options rather than assuming a plugin is required.

## Alternatives considered

- **Copy shared files into every tool tree:** simple discovery, but every edit creates
  synchronization work and drift risk.
- **Symlink the entire Claude skills directory:** fewer source entries, but prevents shared
  and Claude-only skills from coexisting at `~/.claude/skills`.
- **Make all content tool-neutral:** reduces wrappers, but removes valid tool-specific
  guidance and creates misleading near-duplicates.
- **Use plugins for every shared skill:** adds manifests, installation state, and client
  compatibility constraints where ordinary skill discovery already works.

## Consequences

Shared content has one body while each client receives the path and metadata it expects.
Adding a shared skill requires adding its Claude symlink template, and symlink behavior must
remain part of cross-platform verification. Tool-specific capabilities remain explicit.

## Reconsider when

- All target tools support a common import format or multiple configurable skill roots.
- Copilot stops scanning `~/.agents/skills`, allowing a standalone Codex-only directory.
- Claude supports an additional shared skill root without links.
- Chezmoi-managed symlinks become unreliable on a supported operating system.

## Related files and verification

- [`home/.chezmoitemplates/`](../../home/.chezmoitemplates/)
- [`home/dot_agents/skills/`](../../home/dot_agents/skills/)
- [`home/dot_claude/skills/`](../../home/dot_claude/skills/)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#adding-a-skill)
- `scripts/git-hooks/pre-commit` checks shared-skill parity and renders a temporary target.
