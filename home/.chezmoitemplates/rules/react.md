# React Guidelines

Apply these rules only to React components, hooks, and React-specific libraries. For non-React JavaScript or TypeScript, follow the language rules instead.

- Avoid nested ternaries in JSX. Use a simple ternary (`condition ? a : b`) only for short, single-condition, single-line branches. For anything nested, multi-line, or with more than one condition — including rendering one of several mutually exclusive branches — assign to a `let` via `if`/`else if`/`else` (or use early returns) before the `return`, then interpolate that variable in JSX.
- Keep renders pure.
- Use effects only for external synchronization and always clean up subscriptions/listeners.
- Use `useLayoutEffect` instead of `useEffect` only when the effect measures or mutates the DOM (e.g. reading layout, adjusting scroll/focus/position) before paint to prevent visible flicker; default to `useEffect` otherwise since `useLayoutEffect` blocks paint.
- Keep hook declarations together at the top level of the component (after any required constants), then helpers, then JSX. Never call hooks conditionally or inside loops, nested functions, or helper functions.
- Prefer composition over passing props through multiple intermediate components solely to reach a distant child. When intermediary components don't use the values themselves, prefer composition or context over prop drilling.
- Define component types outside other components; nesting them recreates the type on each render and resets descendant state.
- Avoid deriving state that can be computed from props.
- When the initial state is expensive to compute, pass a function to `useState(() => ...)` so it runs once instead of on every render.
- When the next state depends on the previous state, use the functional updater (`setState(prev => ...)`) instead of reading captured state.
- Avoid premature memoization; use `useMemo` or `useCallback` only when they meaningfully improve performance. Do not memoize trivial components, cheap calculations, or already-stable props or handlers.
- When boolean props accumulate to select a variant (`<Card isCompact isFeatured>`), prefer one explicit variant prop or separate composed components over combinations that multiply with each new flag.
- Split out a component when a chunk of JSX represents a distinct, nameable concern (e.g. a list item, a header, a form section) or is reused or likely to be reused elsewhere — don't wait for the file to become hard to read. Keep trivial, single-use markup inline rather than extracting it solely to shorten the parent.

## TanStack Query (React Query) Guidelines

- After a mutation, update affected cache entries with `queryClient.setQueryData` only when the response is authoritative for those entries; invalidate other affected queries with `queryClient.invalidateQueries` using the narrowest reliably correct keys. If no cached data is affected, neither action is needed.
- Use consistent, structured query keys (for example, `['todos', todoId]`) so related queries can be targeted and invalidated predictably.
- Do not mirror query data into local component state unless it intentionally represents an independently editable draft or snapshot. Otherwise, use query data directly or derive values from it.
