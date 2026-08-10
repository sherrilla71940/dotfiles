# React Guidelines

- Avoid nested ternaries in JSX. Use a simple ternary (`condition ? a : b`) only for short, single-condition, single-line branches. For anything nested, multi-line, or with more than one condition — including rendering one of several mutually exclusive branches — assign to a `let` via `if`/`else if`/`else` (or use early returns) before the `return`, then interpolate that variable in JSX.
- Keep renders pure.
- Use effects only for external synchronization and always clean up subscriptions/listeners.
- Use `useLayoutEffect` instead of `useEffect` only when the effect measures or mutates the DOM (e.g. reading layout, adjusting scroll/focus/position) before paint to prevent visible flicker; default to `useEffect` otherwise since `useLayoutEffect` blocks paint.
- Keep hook declarations together at the top level of the component (after any required constants), then helpers, then JSX. Never call hooks conditionally or inside loops, nested functions, or helper functions.
- Prefer composition over passing props through multiple intermediate components solely to reach a distant child. When intermediary components don't use the values themselves, prefer composition or context over prop drilling.
- Avoid deriving state that can be computed from props.
- When the next state depends on the previous state, use the functional updater (`setState(prev => ...)`) instead of reading captured state.
- Avoid premature memoization; use `useMemo` or `useCallback` only when they meaningfully improve performance. Do not memoize trivial components, cheap calculations, or already-stable props or handlers.
- Split out a component when a chunk of JSX represents a distinct, nameable concern (e.g. a list item, a header, a form section) or is reused or likely to be reused elsewhere — don't wait for the file to become hard to read. Keep trivial, single-use markup inline rather than extracting it solely to shorten the parent.

## TanStack Query (React Query) Guidelines

- After a mutation that changes server-side data, keep the cache consistent — either invalidate the affected queries (`queryClient.invalidateQueries`) to trigger a refetch, or update the cache directly (`queryClient.setQueryData`) if the mutation response already contains the updated data. Never leave a mutation without one of the two, or cached data will become stale.
- Prefer `setQueryData` over `invalidateQueries` when the mutation response already contains the complete updated data — it avoids an unnecessary network round trip. Use `invalidateQueries` when the response is partial, when multiple affected queries cannot be updated safely by hand, or when correctness matters more than avoiding the refetch.
- Scope invalidation to the specific affected query keys rather than invalidating broadly (for example, an entire top-level key), unless a broader invalidation is intentional. Overly broad invalidation causes unrelated components to refetch unnecessarily.
- Use consistent, structured query keys (for example, `['todos', todoId]`) so related queries can be targeted and invalidated predictably.
