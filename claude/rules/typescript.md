---
paths:
  - "**/*.{ts,tsx}"
---

# TypeScript Guidelines

- Default to `"strict": true` (including `strictNullChecks`) for new projects. Keep existing settings in legacy projects unless asked to harden them.
- Let TypeScript infer simple local return types; add explicit return types when inference is complex, recursive, generic-heavy, or materially improves readability.
- Require explicit types for exported/public APIs, module boundaries, callback contracts, complex generics, and anywhere inference is unclear or misleading.
- At external boundaries (`fetch`, storage, `postMessage`, env, JSON), parse as `unknown` and narrow before use.
- Normalize external date/time values into a single canonical format before dedupe, sort, comparison, or grouping logic.
- Avoid `any` by default; allow it only for temporary migration, legacy interop, or third-party typing gaps, with a short justification.
- Avoid unnecessary DOM query generics and assertions — prefer null checks and `instanceof` narrowing; add element-specific types only when they improve safety or readability.
- Prefer narrowing (`typeof`, `in`, `instanceof`, discriminants) over assertions.
- Avoid non-null assertions (`!`) unless no safer path exists.
- Use discriminated unions for real variants, with exhaustive `never` checks for domain/state-machine flows.
- Prefer union parameters over overloads when signatures differ only by argument type.
- For callbacks, don't mark parameters optional unless they're truly omitted at call time; use `() => void` when callback returns are ignored.
- Keep generics minimal and inference-friendly; avoid type parameters that don't relate multiple values.
- Prefer `interface` for extendable object shapes; use `type` for unions, mapped types, conditional types, and aliases.
- Use PascalCase for types/interfaces, and `readonly` when mutation isn't intended.
- Use primitive types (`string`, `number`, `boolean`, `symbol`, `object`) instead of boxed types; avoid the global `Function` type.
- Control type widening intentionally: use `as const` for exact literal tuples/objects, `satisfies` to validate object shapes while preserving inference, and combine them for readonly literal config when useful.
