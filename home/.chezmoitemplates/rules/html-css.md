# HTML / CSS / SCSS Guidelines

Apply only to web UI markup, styling, and DOM behavior.

## Naming and selectors

- Follow the project's existing class-naming convention. When none exists for authored reusable CSS/SCSS, prefer clear BEM-style names (`block__element--modifier-value`).
- Keep selector specificity low: style with class-based selectors, avoid **ID selectors** and deep selectors, and keep SCSS nesting shallow. Use `&` for modifiers, states, pseudo-selectors, and selectors meaningfully scoped to the current component; do not recreate long DOM hierarchies. This targets how you _style_, not the markup.
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

- Use media queries for intentional layout changes at meaningful breakpoints, not for every small size adjustment.
- Prefer CSS Container Queries (`@container`) over media queries when styling sub-components (e.g. cards) that live inside dynamic grid/flex slots.
- For images that must fill a container without distorting, use `width: 100%` + `aspect-ratio` + `object-fit: cover`, with `object-position` set explicitly when the subject isn't centered.
- Avoid setting fixed `height`, especially on text-containing elements — prefer `min-height`, and let the layout system (`align-items`, grid row sizing, etc.) handle alignment instead of a hardcoded value.
- For sticky headers, use an explicit background and appropriate `z-index` so scrolling content does not bleed through.
- Wrap wide tables in a scroll container with `overflow: auto`. When horizontal scrolling alone is not enough, collapse less critical columns or reflow into a more readable format.

## Layout Stability

- Avoid layout shift between loading and loaded states; reserve space when the final geometry is predictable.
- When using skeletons, size them to approximate the final content.
- When dialogs or overlays lock page scrolling, preserve scrollbar space with `scrollbar-gutter: stable` or an equivalent fallback.
- Reset the scroll position of a dialog or overlay when it reopens, unless preserving the previous position is intentionally part of the workflow.
- For animations and transitions, prefer compositor-friendly properties (transform, opacity) when appropriate; avoid animating layout-affecting properties (top, left, width, height) when an equivalent transform-based approach is available.
- When both state changes should animate, declare `transition` on the element's base state. A transition declared only in `:hover` or `:focus` applies on entry but not on exit.

## Generated assets

- When browser behavior does not match edited source and the project generates CSS or JavaScript, confirm that the relevant assets were rebuilt and loaded before changing source logic. Treat timestamps, build logs, source maps, and network responses as evidence rather than relying on one signal alone.

## Overrides and output

- Avoid `!important` unless there is no safe alternative.
- Use `@layer` to control override order when integrating third-party/framework CSS.
- Avoid generating vendor prefixes (`-webkit-`, `-moz-`) unless legacy browser support is explicitly required.
