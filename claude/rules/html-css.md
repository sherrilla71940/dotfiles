---
paths:
  - "**/*.{html,cshtml,css,scss,js,jsx,ts,tsx}"
---

# HTML / CSS / SCSS Guidelines

## Naming & selectors

- Default to BEM-style naming (`block__element--modifier-value`).
- Keep selector specificity low: style with class-based selectors, avoid **ID selectors** and deep selectors, and keep SCSS nesting shallow (`&` only for BEM elements/modifiers, states, and pseudo-selectors). This targets how you *style*, not the markup.
- Prefer `data-*` attributes for JavaScript hooks so styling and behavior concerns stay distinct.
- `id` **attributes** in HTML are fine and often expected — form associations (`<label for>` / `<input id>`), accessibility relationships (`aria-labelledby`, `aria-describedby`), browser-native fragment links, testing hooks, and legacy integration. The specificity rule above only means: don't *style* via the ID selector.

## Units

- Use relative units by default:
  - `rem` — typography and spacing
  - `em` — sizing that should follow the component's own font size
  - `%` / `fr` / `clamp()` — fluid layouts
  - `ch` — readable text measure
  - unitless `line-height`
  - `px` — borders, shadows, and fixed assets

## Layout & responsive

- Use flexbox for one-dimensional content-driven flow; use grid for two-dimensional layout-driven structure. Combine grid for outer structure with flexbox for inner alignment when both concerns exist.
- For responsive grids, prefer `repeat(auto-fit, minmax(min(MINW, 100%), 1fr))` over hard-coded column counts when column count should vary with available space. The inner `min(MINW, 100%)` clamp is required to prevent overflow below `MINW`. Use `auto-fill` to preserve empty slots; `auto-fit` otherwise. Pair with fluid gaps via `clamp()`.
- For images that must fill a container without distorting, use `width: 100%` + `aspect-ratio` + `object-fit: cover`, with `object-position` set explicitly when the subject isn't centered.
- Prefer CSS Container Queries (`@container`) over media queries when styling sub-components (e.g. cards) that live inside dynamic grid/flex slots.
- Avoid setting fixed `height`, especially on text-containing elements — prefer `min-height`, and let the layout system (`align-items`, grid row sizing, etc.) handle alignment instead of a hardcoded value.

## Overrides & output

- Avoid `!important` unless there is no safe alternative.
- Use `@layer` to control override order when integrating third-party/framework CSS.
- Avoid generating vendor prefixes (`-webkit-`, `-moz-`) unless legacy browser support is explicitly required.
