---
applyTo: "**/*.{js,jsx,mjs,cjs,ts,tsx,mts}"
---

# JavaScript Standards

## Scope

Applies to JavaScript and TypeScript files. For TypeScript-specific guidelines, see `typescript.instructions.md`. For React-specific guidelines, see `react.instructions.md`.

## Declarations and Naming

- Prefer `const`; use `let` only when reassignment is required; never use `var`.
- Use `camelCase` for most variables and constants.
- Use `UPPER_SNAKE_CASE` only for true constants whose value is fixed, shared, and configuration-like, such as module-level limits, event names, storage keys, breakpoints, or environment-derived constants.

## General JavaScript

- Prefer object/array literals (`{}` / `[]`) over constructors (`new Object()` / `new Array()`).
- Prefer object and array spread/rest for shallow copies, merging, and omission instead of mutating with `Object.assign`, `delete`, or index assignment.
- Use `Object.hasOwn` or `Object.prototype.hasOwnProperty.call(...)` instead of calling `hasOwnProperty` directly on an object.
- Use strict equality (`===`, `!==`) except intentional `== null` checks.
- Use boolean shortcuts for booleans, but compare strings, numbers, and collection lengths explicitly.
- Prefer immutable updates and avoid mutating function parameters; allow local mutation only when safe, clear, or improves performance/API alignment.
- Prefer rest parameters over `arguments`; use default parameters instead of reassigning parameters, and place default parameters last.
- Use a typed options object when a shared/exported function takes 3+ parameters, has multiple optional/boolean parameters, or the argument order is easy to mix up; destructure directly in the signature and provide defaults when relevant. For small local helpers, keep positional parameters when the call sites remain clearer and the argument meaning is obvious from local context.
- Prefer ES6+ and declarative array methods for synchronous data transformations when feasible. Use loops when control flow requires it, such as `await` in sequential work.
- Return values from array transformation/filtering callbacks; use `forEach` only for intentional side effects.
- Prefer returning objects for multiple outputs when named fields improve readability; use tuples when positional semantics are intentional and clear.
- Use template literals over string concatenation.
- Use braces for `if`/`else`/loop bodies, even for single-line blocks.
- Use braces around `case` and `default` clauses that declare `let`, `const`, `function`, or `class` bindings.
- Avoid nested ternaries and selection operators used as control flow; use clear `if` statements when logic branches or causes side effects.
- Parenthesize mixed logical, comparison, and arithmetic operators when precedence is not immediately obvious.
- Use descriptive variable names. Descriptive names are 90% of documentation.
- Use JSDoc directly above exported/public functions, types, interfaces, shared helpers, and functions whose purpose, contract, side effects, or usage constraints are not obvious from the name/signature, so editor hover help stays useful.
- Use inline `//` comments for local implementation notes when a block, condition, workaround, ordering requirement, performance tradeoff, or domain rule is not obvious from the surrounding code.
- Use block comments (`/* ... */`) sparingly for multi-line implementation notes when a whole section depends on non-obvious context, ordering, browser behavior, performance constraints, or domain rules. Do not use block comments as API docs; use JSDoc for that.
- Prefer ESM `import`/`export` over `require`/`module.exports` in modern JavaScript/TypeScript code if the project supports it.
- Keep imports at the top of the module, avoid duplicate imports from the same path, and avoid exporting mutable bindings.
- Avoid dynamic code execution (`eval`, `new Function`, and string-based `setTimeout`/`setInterval`); prefer callbacks, JSON parsing, and safe property access.
- Do not invent APIs, classes, fields, or event names. Verify them from local types, callers, documentation, or existing implementations; leave an explicit `TODO:` only when a real integration detail is unavailable.
- Avoid creating standalone functions for trivial one-liners by default; inline the logic where it is used unless naming it improves readability, testability, or reuse.
- Prefer existing project patterns, shared components, and established copy for UI states and feedback before introducing new variants.

## DOM and Browser APIs

- Use optional chaining only when a missing DOM element is acceptable for an optional one-off action. For required elements, validate once near initialization and throw a clear error if missing. Store the element in a variable when it is used multiple times or the action is complex.
- Prefer `addEventListener` over inline `on*` handlers (for vanilla JavaScript), and use listener options (`once`, `passive`, `signal`) intentionally.
- In legacy non-module scripts, wrap private runtime code in an IIFE. When external callers need access, attach a small, explicit API to one existing project global or `window`; avoid leaking unrelated globals.
- Keep `DOMContentLoaded` handlers thin: call initialization functions from them, but keep business logic, rendering, data parsing, and event handlers in named functions outside the callback.
- Prefer `data-*` attributes for JavaScript DOM targeting. Use `id` only for unique document-level targets, accessibility relationships, browser-native linking, testing constraints, or legacy integration. Keep class names reserved for styling hooks, and avoid encoding element types in attribute values (for example: `data-action="submit"` instead of `data-type="button"`).

## Asynchronous code and promises
- Prefer `async/await`.
- Remember that `await` pauses only the current async function; synchronous array methods such as `forEach`, `filter`, `some`, `every`, and `reduce` do not wait for async callbacks.
- Use `for...of` with `await` for sequential async flows where order, dependencies, rate limits, or step-by-step error handling matter.
- Use `Promise.all` or `Promise.allSettled` with promises created from `map` for parallel async work when task order does not matter and concurrency is safe.
- For async filtering or validation, resolve promises first, then run synchronous `filter`, `some`, or `every` logic on the resolved results.
- For user-triggered async flows such as submit, filter, search, or tab changes, cancel prior in-flight work when a newer action supersedes it; do not rely only on ignoring stale responses.
- If parallel async work comes from a large or user-controlled list, process items in small batches or use a concurrency limit instead of one unbounded `Promise.all(items.map(...))`.
- Use `AbortController` when async work or event listeners can outlive their initiating UI state, component, request, or page section; cancel on teardown or when a newer user action supersedes older work.

## Performance and lifecycle

- When initialization can run more than once, keep it idempotent so setup does not duplicate event listeners, timers, DOM nodes, or requests.
- Lazy-load non-critical resources (e.g., `loading="lazy"` for off-screen images/iframes).
- Defer/split non-critical JavaScript (`type="module"`, dynamic `import()`).
- Use `requestAnimationFrame` for visual updates in scroll/resize handlers and complex animations.
- Use debounce for high-frequency events where only the final value matters, such as search input, filtering, or resize recalculation.
- Use throttle for continuous feedback that should update at a steady rate, such as scroll position, drag movement, or progress indicators.

## Validation and error handling

- Use explicit type conversion at the boundary. Prefer `Number(value)` for numeric conversion and `parseInt(value, 10)` when parsing integers from strings.
- Use `Number.isNaN` instead of global `isNaN` to avoid implicit coercion.
- Use `Number.isFinite` for numeric validation to avoid coercion pitfalls (`isFinite('123') === true`), accidental acceptance of `NaN`/`Infinity`, and non-number inputs passing checks.
- For user-facing API requests or async operations, provide loading, empty, success, and failure states that match the existing UI patterns.
- Catch errors at external boundaries only; do not blanket-wrap all functions.
- Handle edge cases and potential failure points explicitly; do not swallow errors silently.
- Console logging is diagnostic only; when an operation affects the visible page, provide an appropriate user-facing error or fallback state.

## Large legacy files

- In long legacy JavaScript files that cannot be safely split yet, use `//#region` / `//#endregion` sparingly to group related code such as types, constants, DOM references, UI event wiring, business logic, and initialization. Do not use regions as a substitute for extracting cohesive modules when refactoring is safe.
