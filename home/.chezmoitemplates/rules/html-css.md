# HTML / CSS / SCSS Guidelines

## Naming and selectors

- Default to BEM-style naming (`block__element--modifier-value`).
- Keep selector specificity low: style with class-based selectors, avoid **ID selectors** and deep selectors, and keep SCSS nesting shallow (`&` only for BEM elements/modifiers, states, and pseudo-selectors). This targets how you _style_, not the markup.
- Prefer `data-*` attributes for JavaScript hooks and behavior targeting so styling and behavior concerns stay distinct.
- `id` **attributes** in HTML are fine and often expected — form associations (`<label for>` / `<input id>`), accessibility relationships (`aria-labelledby`, `aria-describedby`), browser-native fragment links, testing hooks, and legacy integration. The specificity rule above only means: don't _style_ via the ID selector.

## Units

- Use relative units by default, choosing units by intent rather than habit:
  - `rem` — typography and shared spacing scales
  - `em` — sizing that should follow the component's own font size
  - `%` / `fr` / `minmax()` / `clamp()` — fluid layouts, grid tracks, and bounded responsive sizing
  - unitless `line-height` for text
  - `px` — borders, shadows, hairline details, and fixed assets where exact pixels are intentional

## Layout and responsive

- Use flexbox for one-dimensional, content-driven flow such as toolbars, inline groups, and wrapping rows. Use grid for two-dimensional, layout-driven structure such as page regions, card grids, and aligned tracks. Combine grid for outer structure with flexbox for inner alignment when both concerns exist.
- For responsive grids, prefer `repeat(auto-fit, minmax(min(MINW, 100%), 1fr))` over hard-coded column counts when column count should vary with available space. The inner `min(MINW, 100%)` clamp is required to prevent overflow below `MINW`. Use `auto-fill` to preserve empty slots; `auto-fit` otherwise. Pair with fluid gaps via `clamp()`.
- Use media queries for intentional layout changes at meaningful breakpoints, not for every small size adjustment.
- Prefer CSS Container Queries (`@container`) over media queries when styling sub-components (e.g. cards) that live inside dynamic grid/flex slots.
- For images that must fill a container without distorting, use `width: 100%` + `aspect-ratio` + `object-fit: cover`, with `object-position` set explicitly when the subject isn't centered.
- Avoid setting fixed `height`, especially on text-containing elements — prefer `min-height`, and let the layout system (`align-items`, grid row sizing, etc.) handle alignment instead of a hardcoded value.
- For sticky headers, use an explicit background and appropriate `z-index` so scrolling content does not bleed through.

## Layout Stability

- Avoid layout shift between loading and loaded states; reserve space when the final geometry is predictable.
- When using skeletons, size them to approximate the final content.
- When dialogs or overlays lock page scrolling, preserve scrollbar space with `scrollbar-gutter: stable` or an equivalent fallback.
- For animations and transitions, prefer compositor-friendly properties (transform, opacity) when appropriate; avoid animating layout-affecting properties (top, left, width, height) when an equivalent transform-based approach is available.

what section in html-css

## Overrides and output

- Avoid `!important` unless there is no safe alternative.
- Use `@layer` to control override order when integrating third-party/framework CSS.
- Avoid generating vendor prefixes (`-webkit-`, `-moz-`) unless legacy browser support is explicitly required.
