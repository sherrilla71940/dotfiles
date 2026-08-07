---
description: 'Synthesize archived frontend project reports into English/zh-TW project archive materials.'
name: 'Project Archive Synthesis'
argument-hint: 'optional target role, target brief, company type, market, or project folders'
agent: 'Project Archive Synthesizer'
---

# Project Archive Synthesis

Use the `Project Archive Synthesizer` agent to turn archived frontend project profile reports into a bilingual project archive strategy.

Treat the project-profiles archive as the source of truth unless the user provides a different archive folder or specific project folders in the prompt arguments:

`$HOME/Documents/2026 work/copilot-asset-manager/local/archives/project-profiles`

Default to all project folders that contain `frontend-project-profile.en.md` and/or `frontend-project-profile.zh-TW.md`. If the user provides a target role, target brief, company type, location market, profile constraint, or selected project list, use those arguments to prioritize the synthesis.

Write the bilingual archive reports to:

`$HOME/Documents/2026 work/copilot-asset-manager/local/archives/project-profiles/archive-synthesis`

Create or update these files:

- `project-archive-synthesis.en.md`
- `project-archive-synthesis.zh-TW.md`

The synthesis must produce immediate profile-planning material and deeper supporting analysis:

- `Use This Now` summary for quick profile and technical discussion use
- overall frontend professional positioning
- project ranking and recommendation for profile, archive, technical discussion, or background use
- master profile bullet bank with contribution confidence labels
- skill matrix across projects
- business translation across project themes
- technical discussion story index
- role-description match analysis when a role or JD is provided
- bilingual pitch and glossary for natural English and Traditional Chinese phrasing
- open questions, missing metrics, and next actions

Use existing project reports as evidence. Do not re-analyze original source repositories unless a report is missing, contradictory, clearly stale, or the user explicitly requests verification. Do not invent ownership, metrics, client names, production scale, business outcomes, or backend responsibilities.

If the project-profiles archive is not writable from the current workspace, stop and explain that `copilot-asset-manager` should be opened as an additional workspace folder. Do not silently write reports into an unrelated repository.

After writing the reports, respond with a concise summary of the two report paths, the strongest professional positioning, the top project themes, and any confirmation questions needed before the user applies with stronger claims.

