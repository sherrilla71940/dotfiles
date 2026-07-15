---
paths:
  - "**/*.{js,jsx,ts,tsx}"
---

# JavaScript Guidelines

*Applies to JavaScript and TypeScript files. See TypeScript Guidelines and React Guidelines below for language/framework-specific rules.*

### Declarations and naming

- Use `UPPER_SNAKE_CASE` only for true constants whose value is fixed, shared, and configuration-like — e.g., module-level limits, event names, storage keys, breakpoints, environment-derived constants.

### General JavaScript

- Prefer object/array spread and rest for shallow copies, merging, and omission instead of mutating with `Object.assign`, `delete`, or index assignment.
- Use boolean shortcuts for booleans, but compare strings, numbers, and collection lengths explicitly.
- Prefer immutable updates and avoid mutating function parameters; local mutation is fine when it's safe, clear, or improves performance/API alignment.
- Use a typed options object when a shared/exported function takes 3+ parameters, has multiple optional/boolean parameters, or the argument order is easy to mix up — destructure in the signature and provide defaults. For small local helpers, positional parameters are fine when call sites stay clear.
- Return values from array transformation/filtering callbacks; use `forEach` only for intentional side effects.
- Prefer returning objects for multiple outputs when named fields improve readability; use tuples when positional semantics are intentional and clear.
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

### Performance

- Code-split by route by default; lazy-load heavy or below-the-fold components (rich editors, charts, modals, admin panels, large third-party widgets).
- Pair lazy-loaded components with a fallback sized close to final content dimensions to avoid layout shift on resolution.
- Lazy-load offscreen images (`loading="lazy"`); never lazy-load the largest above-the-fold image — load it eagerly, with `fetchpriority="high"` if it's the LCP candidate.
- Use `srcset`/`sizes` so the browser fetches an appropriately sized image per viewport.
- Reserve layout space up front for anything async (images, embeds, ads) via explicit `width`/`height` or `aspect-ratio`, to avoid CLS.
- When initialization can run more than once, keep it idempotent — no duplicated listeners, timers, or requests.
- Prefetch only what's likely needed next (hovered route, next page); avoid speculative prefetching of large or rarely-used chunks.

### Validation and error handling

- Use explicit type conversion at boundaries: prefer `Number(value)` for numeric conversion and `parseInt(value, 10)` for parsing integers from strings.
- Catch errors at external boundaries only; do not blanket-wrap all functions.
- Handle edge cases and potential failure points explicitly; never swallow errors silently.
- Console logging is diagnostic only. When an operation affects the visible page, provide an appropriate user-facing error or fallback state.

### Large legacy files

- In long legacy JavaScript files that can't be safely split yet, use `//#region`/`//#endregion` sparingly to group related code (types, constants, DOM references, UI event wiring, business logic, initialization). Don't use regions as a substitute for extracting cohesive modules when refactoring is safe.
