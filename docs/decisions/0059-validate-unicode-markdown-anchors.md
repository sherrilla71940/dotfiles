# ADR-0059: Validate Unicode Markdown heading anchors

- Status: Accepted
- Date: 2026-10-13

## Context

The staged-source Markdown link checker claimed to validate heading fragments, but it removed
non-ASCII letters from heading slugs and did not inspect links containing them. The new
Traditional Chinese README link to the parallel-work section therefore passed the check even
though its ASCII-only fragment did not match the heading anchor GitHub generates. GitHub keeps
Chinese letters in heading anchors.

## Decision

Keep the existing AWK checker and use its locale-aware alphanumeric class for heading slugs
and relative-link fragments. Link the Traditional Chinese README to the heading's actual
Unicode fragment. Add a focused fixture that accepts that fragment and rejects the
ASCII-only fragment that previously passed.

## Alternatives considered

- Drop the fragment from the README link. This would avoid the broken link but land readers
  at the top of a broader guide and leave the checker blind to the next Unicode fragment.
- Add an English-only heading or a manual HTML anchor to the Chinese guide. That would make
  the link depend on a second heading or anchor rather than the visible section title.
- Replace the AWK checker with a full Markdown parser. The current issue needs only a
  small character-class correction; a new parser would add a dependency and more upkeep.

## Consequences

The checker now validates Chinese heading fragments when run under a UTF-8 locale. Existing
ASCII links follow the same path. A non-UTF-8 locale or Markdown syntax outside the checker's
supported subset can still limit coverage; report an observed mismatch before expanding the
checker further.

## Reconsider when

Revisit the checker if a supported host lacks a UTF-8 locale or another real Markdown link
escapes its supported syntax.

## Related files and verification

- README.zh-TW.md
- scripts/git-hooks/markdown-anchors.awk
- scripts/tests/test-markdown-anchors.sh
- scripts/tests/run-git-bash-tests.ps1

Run the focused fixture and the staged-source pre-commit hook.
