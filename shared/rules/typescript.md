---
paths:
  - "**/*.{ts,tsx}"
---

# TypeScript Guidelines

- Default to `"strict": true` (including `strictNullChecks`) for new projects. Keep existing settings in legacy projects unless asked to harden them.
- Let TypeScript infer simple local types and return types; add explicit types for exported/public APIs, module boundaries, callback contracts, complex generics, recursive functions, and anywhere inference is unclear, misleading, or materially improves readability.
- At external boundaries (`fetch`, storage, `postMessage`, environment variables, JSON), treat incoming data as `unknown` and narrow or validate it before use.
- Normalize external date/time values into a single canonical format before dedupe, sorting, comparison, or grouping logic.
- Avoid `any` by default. Use it only for temporary migration, legacy interop, or third-party typing gaps, with a short justification.
- Prefer narrowing (`typeof`, `in`, `instanceof`, discriminated unions, user-defined type guards) over type assertions.
- Avoid non-null assertions (`!`) unless no safer path exists.
- Avoid unnecessary DOM query generics and assertions. Prefer null checks and `instanceof` narrowing; add element-specific types only when they improve safety or readability.
- Model impossible states with the type system where practical instead of relying on runtime conventions or comments. Prefer discriminated unions over optional-property combinations for domain variants and state machines, with exhaustive `never` checks where all cases should be handled.
- Prefer union parameters over overloads when signatures differ only by argument type.
- For callbacks, don't mark parameters optional unless callers may legitimately omit them. Use `() => void` when callback return values are intentionally ignored.
- Keep generics minimal and inference-friendly. Avoid type parameters that don't relate multiple values or improve type safety.
- Prefer `interface` for extendable object shapes. Use `type` for unions, mapped types, conditional types, tuples, primitives, and aliases.
- Use PascalCase for types and interfaces. Mark properties `readonly` when mutation is not intended.
- Use primitive types (`string`, `number`, `boolean`, `symbol`, `object`) instead of boxed types. Avoid the global `Function` type; prefer explicit function signatures.
- Control type widening intentionally: use `as const` for exact literal tuples and objects, `satisfies` to validate object shapes while preserving inference, and combine them when defining readonly configuration objects.
