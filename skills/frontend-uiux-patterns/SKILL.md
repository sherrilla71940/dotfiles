---
name: frontend-uiux-patterns
description: 'Frontend UI/UX pattern guidance for implementing or reviewing forms, validation feedback, data tables, sticky headers, responsive overflow, modals, popovers, drawers, destructive actions, empty states, error states, loading states, and async UI behavior in web UI.'
---

## When to Use This Skill

Use this skill for detailed guidance on how to build:
- Forms
- Data tables
- Modals, dialogs, popovers, drawers, or other overlays
- Loading states and async UI patterns

## Forms

- For async submit actions, make the submitting state explicit and prevent accidental duplicate submission while the request is in flight.
- Show validation feedback near the relevant field, avoid premature error states before user interaction, and use form-level summaries for submit-level or multi-field failures when helpful.
- Preserve user input on recoverable validation or save errors unless clearing the form is intentionally part of the workflow.
- Avoid disabling actions without explanation; if an action is unavailable, explain why and how to enable it when possible.
- Warn users before discarding meaningful unsaved changes.

## Data Tables

- Make tables responsive and usable on small screens by wrapping the table in a scroll container with `overflow: auto`.
- For horizontal overflow, collapse less critical columns or reflow into a more readable format when scrolling alone is not enough.
- For vertical overflow, keep headers visible with `position: sticky`; give them an explicit background and stacking order so content does not bleed through while scrolling.
- When sticky table headers need reliable borders, shadows, or layered backgrounds, prefer `border-collapse: separate` with `border-spacing: 0`; collapsed borders can render inconsistently with sticky positioning.

## Modals, Dialogs, And Overlays

- For modal dialogs, move focus into the dialog, trap focus while open, prevent background interaction, and restore focus to the triggering element on close.
- For modal dialogs, prefer `Escape` and an explicit close control; do not rely on outside-click close unless accidental dismissal is acceptable for the workflow.
- For informational popovers, prefer `Escape` and outside-click close unless there is a clear reason to require explicit dismissal.
- For non-modal drawers and interactive popovers, manage focus intentionally and restore focus to the triggering element on close when it improves keyboard and screen-reader usability.
- For dialogs or overlays with scrollable content, reset scroll position on reopen unless preserving prior position is intentionally part of the workflow.
- When dialogs or overlays lock background scroll, preserve scrollbar space with `scrollbar-gutter: stable` or an equivalent fallback to avoid layout shifts.

## Async UI States
- When async work affects visible page state, show a loading state and clear it only after the relevant work completes or fails.
- Prefer existing project patterns, shared components, and established copy before introducing new loading-state variants.
- If none exist, use skeletons when the final layout is known and the wait is noticeable.
- Avoid layout shift between loading and loaded states.
