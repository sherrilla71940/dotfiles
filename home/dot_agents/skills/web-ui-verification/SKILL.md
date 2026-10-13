---
name: web-ui-verification
description: Verify user-visible web UI changes in a running application, including affected routes, interaction states, and responsive behavior. Use after frontend implementation; use accessibility-review for a focused accessibility audit.
---

# Web UI verification

Use this skill when a frontend change affects rendered pages or user interactions. Follow the repository's setup and test instructions; this skill supplements project-specific checks.

1. Identify the changed route or flow and the behavior the change should produce. Include relevant loading, empty, error, success, and interaction states when the change affects them.
2. Run the project's useful checks, then start or connect to the application and exercise the changed flow in an available browser. Choose viewports that reflect the change, including a narrow viewport when responsive behavior is affected.
3. Check the rendered result, interaction behavior, and relevant console or network failures. Compare against supplied designs or screenshots when they are part of the request.
4. For keyboard or assistive-technology concerns, follow [accessibility-review](../accessibility-review/SKILL.md); avoid duplicating its full audit here.
5. Report what you actually checked and the browser, route, state, and viewport where useful. If the app, browser, reference, or a particular check is unavailable, say what remains unverified. Do not infer runtime or visual success from source inspection alone.

Use performance traces, Lighthouse, or network analysis only when the task or observed change calls for them and the required tools are available. State when that evidence could not be collected.
