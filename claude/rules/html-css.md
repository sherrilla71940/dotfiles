---
paths:
  - "**/*.{html,cshtml,css,scss,js,jsx,ts,tsx}"
---

# HTML / CSS / SCSS Guidelines

- Default to BEM-style naming (`block__element--modifier-value`).
- Keep selector specificity low: use class-based selectors, avoid IDs and deep selectors, and keep SCSS nesting shallow (`&` only for BEM elements/modifiers, states, and pseudo-selectors).
- Prefer `data-*` attributes for JavaScript hooks so styling and behavior concerns stay distinct.
- Use `id` only when required for accessibility relationships, form associations, browser-native linking, testing constraints, or legacy integration.
- Use relative units by default: `rem` for typography/spacing, `em` when sizing follows the component's own font size, `%`/`fr`/`clamp()` for fluid layouts, `ch` for readable text measure, unitless `line-height`, and `px` for borders, shadows, and fixed assets.
- Avoid `!important` unless there is no safe alternative.
- Use `@layer` to control override order when integrating third-party/framework CSS.
- Use flexbox for one-dimensional content-driven flow; use grid for two-dimensional layout-driven structure. Combine grid for outer structure with flexbox for inner alignment when both concerns exist.
- For responsive grids, prefer `repeat(auto-fit, minmax(min(MINW, 100%), 1fr))` over hard-coded column counts when column count should vary with available space. The inner `min(MINW, 100%)` clamp is required to prevent overflow below `MINW`. Use `auto-fill` to preserve empty slots; `auto-fit` otherwise. Pair with fluid gaps via `clamp()`.
- For images that must fill a container without distorting, use `width: 100%` + `aspect-ratio` + `object-fit: cover`, with `object-position` set explicitly when the subject isn't centered.
- Prefer CSS Container Queries (`@container`) over media queries when styling sub-components (e.g. cards) that live inside dynamic grid/flex slots.
- Avoid generating vendor prefixes (`-webkit-`, `-moz-`) unless legacy browser support is explicitly required.
- Avoid setting fixed `height`, especially on text-containing elements — prefer `min-height`, and let the layout system (`align-items`, grid row sizing, etc.) handle alignment instead of a hardcoded value.
