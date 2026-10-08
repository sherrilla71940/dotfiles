---
name: accessibility-review
description: Review, design, or implement web accessibility for a user flow, including keyboard and focus behavior, semantics, forms, dynamic updates, and verification.
---

# Accessibility review

Use this skill for focused accessibility work. Apply the project's stated accessibility target. If none is stated, use WCAG 2.2 AA as the review baseline and identify that assumption in the result.

## Review the user flow

1. Identify the tasks a user must complete and the relevant states: initial, loading, error, success, and dismissal.
2. Inspect semantic HTML, accessible names, roles, states, relationships, document language, and meaningful text alternatives. Prefer native controls when they provide the needed behavior.
3. Walk the flow with a keyboard. Check operation, focus order, visibility, movement into and out of overlays, and focus restoration.
4. Check applicable visual, form, media, and dynamic-content requirements. Include reflow, contrast, text resizing, input help, status announcements, and motion where relevant.
5. Run available accessibility tools when practical. Verify their findings in the rendered interface and use manual interaction for behavior a scanner cannot establish. Add a screen reader check when the affected flow or risk warrants it.

## Report findings

For each finding, name the affected component or location, the user impact, the observed behavior, the relevant success criterion when established, a concrete fix, and a way to verify it. Rank by user impact. Distinguish a confirmed failure from a potential issue that still needs interaction or assistive-technology testing.

Do not infer a WCAG violation from a code pattern alone. A framework helper, heading level, CSS unit, ARIA attribute, or animation declaration can be relevant evidence without proving the user-facing result. State what was actually tested and what remains unverified.

Consult the current [WCAG recommendation](https://www.w3.org/TR/WCAG22/) and [ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/) for detailed criteria and widget behavior instead of maintaining a local copy of the standards.
