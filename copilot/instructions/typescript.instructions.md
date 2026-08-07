---
applyTo: "**/*.{ts,tsx,mts}"
---

# TypeScript Guidelines

- For new TypeScript projects, default to `"strict": true` (including `strictNullChecks`). For legacy projects, keep existing settings unless asked to harden.
- Let TypeScript infer simple local return types; add explicit return types when inference is complex, recursive, generic-heavy, or materially improves readability.
- Require explicit types for exported/public APIs, module boundaries, callback contracts, complex generics, and places where inference is unclear or misleading.
- At external boundaries (`fetch`, storage, `postMessage`, env, JSON), parse as `unknown` and narrow before use.
- Normalize external date/time values into a single canonical format before dedupe, sort, comparison, or grouping logic.
- Avoid `any` by default; allow only for temporary migration, legacy interop, or third-party typing gaps with a short justification.
- Avoid unnecessary DOM query generics and assertions. Prefer null checks and `instanceof` narrowing; add element-specific types only when they improve safety or readability.
- Prefer narrowing (`typeof`, `in`, `instanceof`, discriminants) over assertions.
- Avoid non-null assertions (`!`) unless no safer path exists.
- Use discriminated unions for real variants, and use exhaustive `never` checks for domain/state-machine flows.
- Prefer union parameters over overloads when signatures differ only by argument type.
- For callbacks, do not mark parameters optional unless they are truly omitted at call time; use `() => void` when callback returns are ignored.
- Keep generics minimal and inference-friendly; avoid type parameters that do not relate multiple values.
- Prefer `interface` for extendable object shapes; use `type` for unions, mapped types, conditional types, and aliases.
- Use PascalCase for types/interfaces and `readonly` when mutation is not intended.
- Use primitive types (`string`, `number`, `boolean`, `symbol`, `object`) instead of boxed types, and avoid global `Function`.
- Control type widening intentionally: use `as const` for exact literal tuples/objects, use `satisfies` to validate object shapes while preserving inference, and combine them for readonly literal config when useful.
