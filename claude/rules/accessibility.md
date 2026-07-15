---
paths:
  - "**/*.{html,cshtml,css,scss,js,jsx,ts,tsx}"
---

# Accessibility Guidelines

- Prefer native semantic HTML before ARIA. Use buttons, links, labels, headings, landmarks, lists, tables, and form controls for their intended purpose.
- Every interactive control needs a clear accessible name, visible focus, keyboard access, and a predictable disabled/loading/error state.
- Do not put click handlers on non-interactive elements. If a custom widget is unavoidable, provide role, state, `tabindex`, Enter/Space behavior, and documented focus management.
- Dialogs and blocking overlays must move focus inside, keep focus contained, close with Escape unless unsafe, prevent background interaction, and restore focus to the trigger.
- Forms need visible labels, helpful instructions, `autocomplete` where relevant, linked error text, and preserved user input after recoverable failures.
- Announce important async updates with an appropriate live region when the change is not otherwise obvious.
- Do not rely on color, shape, position, hover, drag, or gesture alone to communicate or operate important functionality.
- Provide useful alt text for informative images and empty alt text for decorative images.
- Keep text, UI controls, focus indicators, and meaningful graphics above WCAG AA contrast expectations.
- Respect reduced-motion preferences and avoid autoplaying media with sound.

Use the @/skills/accessibility-review skill for WCAG mapping, accessibility audits, keyboard walkthroughs, screen reader checks, axe/pa11y/Lighthouse guidance, framework-specific remediation, a formal review comment, or any time you feel it would be helpful to go beyond these always-on guardrails.
