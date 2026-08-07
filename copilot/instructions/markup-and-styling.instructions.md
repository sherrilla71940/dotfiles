---
applyTo: '**/*.{html,cshtml,css,scss,sass,ts,tsx,js,jsx,mts,vue}'
---

# Markup and Styling

- Default to BEM-style (`block__element--modifier-value`) naming.
- Keep selector specificity low:
  - Use class-based selectors
  - avoid escalating specificity with IDs/deep selectors
  - Keep nesting shallow (in SCSS, use `&` only for BEM elements/modifiers, states, and pseudo-selectors)
- Prefer `data-*` attributes for JavaScript hooks and behavior targeting so styling and behavior concerns stay distinct.
- Use `id` only when required for accessibility relationships, form associations, browser-native linking, testing constraints, or legacy integration.
- Use relative units by default, choosing units by intent rather than habit.
  - Use `rem` for typography and shared spacing scales; use `em` when sizing should follow the component's own font size.
  - Use `%`, `fr`, `minmax()`, and `clamp()` for fluid layouts, grid tracks, and bounded responsive sizing.
  - Use `ch` for readable text measure.
  - Use unitless `line-height` for text.
  - Use `px` for borders, shadows, hairline details, and fixed assets where exact pixels are intentional.
- Avoid `!important` unless there is no safe alternative.
- Use `@layer` to control override order when integrating third-party/framework CSS.
- Choose layout primitives by intent:
  - Use flexbox for one-dimensional, content-driven flow such as toolbars, inline groups, and wrapping rows.
  - Use grid for two-dimensional, layout-driven structure such as page regions, card grids, and aligned tracks.
  - Use `repeat(auto-fit, minmax(...))` or `repeat(auto-fill, minmax(...))` for responsive grids when items should reflow without extra breakpoints.
  - Use media queries for intentional layout changes at meaningful breakpoints, not for every small size adjustment.
  - Combine grid for outer structure with flexbox for inner alignment when both concerns exist.
