# CLAUDE.md

## Core Principles

### Scope and priority

- Apply rules in this order when conflicts occur: language/framework-specific > file-type-specific > general.
- Edit source-of-truth files, not generated output (for example: `.ts` over `.js`, `.scss` over `.css`). Only compile or generate output if explicitly requested.

### Response behavior

- Always respond in English. This instruction wins over any language-specific rule in a conflict.
- Be concise and actionable.
- **Handling missing/ambiguous information:** if any input needed for a task — source files, specs, data, or these instructions themselves — is incomplete, unreadable, ambiguous, or missing, do not guess or silently fill the gap. Instead:
  1. State what is unclear/missing and where (file, line number, section, field/parameter name, or whatever locator fits).
  2. State what's needed from the user to resolve it.
  3. Prefix the flag with `⚠️ Needs clarification:` so it's easy to spot.
  - If other parts of the task are unaffected by the gap, implement those and clearly separate what's done from what's blocked.
  - **Minor, low-stakes ambiguity** (e.g., a formatting preference with no real consequence) can be resolved with a stated default instead — say what was assumed and why.
  - The bar: if a wrong guess would break something, change output correctness, or require rework, flag it. Otherwise, assume and proceed.
- After implementation, summarize:
  - What changed
  - Why it changed
  - Any assumptions or remaining risks

### Engineering principles

- Keep changes minimal, scoped, and architecture-aware.
- Prefer root-cause fixes over surface-level patches.
- Before changing shared modules, inspect their callers and preserve existing contracts. If dependent files must change, identify them in the plan and update them together.
- Avoid over-engineering. Do not introduce abstractions, layers, or utilities until they are clearly justified by duplication, variation, or complexity.
- Apply Clean Code principles pragmatically:
  - Favor SRP, DRY, low coupling, and high cohesion.
  - Prefer intentional duplication over premature abstraction when it keeps the code easier to read and change.
- Reuse existing utilities, services, and shared modules before creating new ones.

### Security

- Prevent common web vulnerabilities (XSS, injection, unsafe deserialization, CSRF gaps).
- Treat client-side validation and escaping as defense-in-depth, not a trust boundary.
- Never rely on client-side checks for authorization or critical validation.
- Escape or sanitize user-generated content whenever bypassing framework protections (e.g., `dangerouslySetInnerHTML` or `innerHTML`).
- Never hardcode secrets, API keys, or access tokens.

### Readability and documentation

- Prefer the clearest correct code over the shortest or cleverest code.
- Favor descriptive names and straightforward control flow over explanatory comments and clever abstractions.
- Use JSDoc for exported/public APIs and non-obvious functions: explain purpose, usage constraints, parameters, and return values.
- Use standard comments sparingly, for implementation notes that explain *why* a non-obvious decision or workaround was used.

### Git hooks

- When git hooks report issues, fix the reported issues instead of bypassing the hooks.

---

## Company Coding Style

- Use PascalCase for VanillaJS/VanillaTS function names and globals (company standard), and for React component names only. Use camelCase for all other identifiers.
- All code comments should be in zh-tw.

---

## JavaScript Guidelines

*Applies to JavaScript and TypeScript files. See TypeScript Guidelines and React Guidelines below for language/framework-specific rules.*

### Declarations and naming

- Use `UPPER_SNAKE_CASE` only for true constants whose value is fixed, shared, and configuration-like — e.g., module-level limits, event names, storage keys, breakpoints, environment-derived constants.

### General JavaScript

- Prefer object/array spread and rest for shallow copies, merging, and omission instead of mutating with `Object.assign`, `delete`, or index assignment.
- Use `Object.hasOwn` (or `Object.prototype.hasOwnProperty.call(...)`) instead of calling `hasOwnProperty` directly on an object.
- Use boolean shortcuts for booleans, but compare strings, numbers, and collection lengths explicitly.
- Prefer immutable updates and avoid mutating function parameters; local mutation is fine when it's safe, clear, or improves performance/API alignment.
- Use a typed options object when a shared/exported function takes 3+ parameters, has multiple optional/boolean parameters, or the argument order is easy to mix up — destructure in the signature and provide defaults. For small local helpers, positional parameters are fine when call sites stay clear.
- Return values from array transformation/filtering callbacks; use `forEach` only for intentional side effects.
- Prefer returning objects for multiple outputs when named fields improve readability; use tuples when positional semantics are intentional and clear.
- Avoid nested ternaries and selection operators as control flow; use clear `if` statements when logic branches or causes side effects.
- Parenthesize mixed logical, comparison, and arithmetic operators when precedence isn't immediately obvious.
- Do not invent APIs, classes, fields, or event names. Verify them from local types, callers, docs, or existing implementations; leave an explicit `TODO:` only when a real integration detail is unavailable.
- Avoid creating standalone functions for trivial one-liners by default; inline the logic unless naming it improves readability, testability, or reuse.
- Prefer existing project patterns, shared components, and established copy for UI states/feedback before introducing new variants.

### Asynchronous code

- Prefer `async`/`await`.
- Remember that `await` pauses only the current async function — synchronous array methods (`forEach`, `filter`, `some`, `every`, `reduce`) do not wait for async callbacks.
- Use `for...of` with `await` for sequential async workflows where ordering, dependencies, rate limits, or step-by-step error handling matter.
- Use `Promise.all` or `Promise.allSettled` with promises from `map` for parallel work when ordering doesn't matter and concurrency is safe.
- For async filtering or validation, resolve all promises first, then apply synchronous `filter`/`some`/`every` logic to the resolved results.
- For user-triggered async flows (submit, filter, search, tab changes), cancel prior in-flight work when a newer action supersedes it — don't rely only on ignoring stale responses.
- If parallel async work comes from a large or user-controlled list, batch it or use a concurrency limit instead of one unbounded `Promise.all(items.map(...))`.
- Use `AbortController` when async work or event listeners can outlive their initiating UI state, component, request, or page section; cancel on teardown or when newer work supersedes it.

### Performance and lifecycle

- When initialization can run more than once, keep it idempotent — setup should not duplicate event listeners, timers, DOM nodes, or requests.

### Validation and error handling

- Use explicit type conversion at boundaries: prefer `Number(value)` for numeric conversion and `parseInt(value, 10)` for parsing integers from strings.
- Catch errors at external boundaries only; do not blanket-wrap all functions.
- Handle edge cases and potential failure points explicitly; never swallow errors silently.
- Console logging is diagnostic only. When an operation affects the visible page, provide an appropriate user-facing error or fallback state.

### Large legacy files

- In long legacy JavaScript files that can't be safely split yet, use `//#region`/`//#endregion` sparingly to group related code (types, constants, DOM references, UI event wiring, business logic, initialization). Don't use regions as a substitute for extracting cohesive modules when refactoring is safe.

---

## TypeScript Guidelines

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

---

## React Guidelines

- Avoid nested ternaries in JSX. Use a simple ternary (`condition ? a : b`) only for short, single-condition, single-line branches. For anything nested, multi-line, or with more than one condition — including rendering one of several mutually exclusive branches — assign to a `let` via `if`/`else if`/`else` (or use early returns) before the `return`, then interpolate that variable in JSX.
- Keep renders pure.
- Use effects only for external synchronization and always clean up subscriptions/listeners.
- Use `useLayoutEffect` instead of `useEffect` only when the effect measures or mutates the DOM (e.g. reading layout, adjusting scroll/focus/position) before paint to prevent visible flicker; default to `useEffect` otherwise since `useLayoutEffect` blocks paint.
- Keep hook order stable: hooks first, then helpers, then JSX.
- Prefer composition over prop drilling.
- Avoid deriving state that can be computed from props.
- Avoid premature memoization; when memoization is applied, use `useMemo` or `useCallback` only when it meaningfully improves performance. Do not memoize trivial components, cheap calculations, or stable props/handlers unnecessarily.
- Split out a component when a chunk of JSX represents a distinct, nameable concern (e.g. a list item, a header, a form section) or is reused/likely reused elsewhere — don't wait for the file to become hard to read. Keep trivial, single-use markup inline rather than extracting it just to shorten the parent.

---

## TanStack Query (React Query) Guidelines

- After a mutation that changes server-side data, keep the cache consistent — either invalidate the affected queries (`queryClient.invalidateQueries`) to trigger a refetch, or update the cache directly (`queryClient.setQueryData`) if the mutation response already contains the updated data. Never leave a mutation without one of the two, or cached data goes stale.
- Prefer `setQueryData` over `invalidateQueries` when the mutation response already contains the full updated shape — it avoids an unnecessary network round trip. Use `invalidateQueries` when the response is partial, when other queries/keys are affected that can't be safely hand-patched, or when correctness matters more than avoiding the refetch.
- Scope invalidation to the specific affected query keys rather than invalidating broadly (e.g. a whole top-level key), unless a broader invalidation is intentional — over-broad invalidation causes unrelated components to refetch needlessly.
- Use consistent, structured query keys (e.g. `['todos', todoId]`) so related queries can be targeted or invalidated together predictably.

---

## HTML / CSS / SCSS Guidelines

- Default to BEM-style naming (`block__element--modifier-value`).
- Keep selector specificity low: use class-based selectors, avoid IDs and deep selectors, and keep SCSS nesting shallow (`&` only for BEM elements/modifiers, states, and pseudo-selectors).
- Prefer `data-*` attributes for JavaScript hooks so styling and behavior concerns stay distinct.
- Use `id` only when required for accessibility relationships, form associations, browser-native linking, testing constraints, or legacy integration.
- Use relative units by default: `rem` for typography/spacing, `em` when sizing follows the component's own font size, `%`/`fr`/`clamp()` for fluid layouts, `ch` for readable text measure, unitless `line-height`, and `px` for borders, shadows, and fixed assets.
- Avoid `!important` unless there is no safe alternative.
- Use `@layer` to control override order when integrating third-party/framework CSS.
- Use flexbox for one-dimensional content-driven flow; use grid for two-dimensional layout-driven structure. Combine grid for outer structure with flexbox for inner alignment when both concerns exist.
