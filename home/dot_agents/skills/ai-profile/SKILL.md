---
name: ai-profile
description: Inspect or change the machine's personal or company context, or extend the context schema.
argument-hint: "[show|select|extend] [personal|company]"
---

# AI context

This repository exposes one machine-local selector:

- ai_context: personal or company; defaults to personal.

The selected context composes the shared instructions with one context layer. Personal uses English artifact defaults; company uses Traditional Chinese for Taiwan. Repository instructions can override the machine context for work in that repository.

## Show

Read the current values from chezmoi data and report the default when ai_context is unset. Resolve the rendered result with the repository's profile template; do not infer it from the current client or response language.

## Select

Change ai_context in the machine-local chezmoi configuration. Do not change repository source or apply configuration as part of a profile selection. The values are local and are not committed.

## Extend

Treat a new context, selector, or composition rule as repository architecture work. Update the canonical resolver, both README languages, setup guidance, and profile-render checks. Keep profile applicability separate from client reach.

Use the current client’s skill invocation syntax. If the request only selects an existing context, do not extend the schema.
