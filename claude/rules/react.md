---
paths:
  - "**/*.{js,jsx,ts,tsx}"
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

## TanStack Query (React Query) Guidelines

- After a mutation that changes server-side data, keep the cache consistent — either invalidate the affected queries (`queryClient.invalidateQueries`) to trigger a refetch, or update the cache directly (`queryClient.setQueryData`) if the mutation response already contains the updated data. Never leave a mutation without one of the two, or cached data goes stale.
- Prefer `setQueryData` over `invalidateQueries` when the mutation response already contains the full updated shape — it avoids an unnecessary network round trip. Use `invalidateQueries` when the response is partial, when other queries/keys are affected that can't be safely hand-patched, or when correctness matters more than avoiding the refetch.
- Scope invalidation to the specific affected query keys rather than invalidating broadly (e.g. a whole top-level key), unless a broader invalidation is intentional — over-broad invalidation causes unrelated components to refetch needlessly.
- Use consistent, structured query keys (e.g. `['todos', todoId]`) so related queries can be targeted or invalidated together predictably.
