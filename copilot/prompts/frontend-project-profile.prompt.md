---
description: 'Analyze the current project for frontend profile evidence and write English/zh-TW reports to the project-profiles archive.'
name: 'Frontend Project Profile'
argument-hint: 'optional project name, target role, or target brief'
agent: 'Frontend Project Profile Analyst'
---

# Frontend Project Profile

Use the `Frontend Project Profile Analyst` agent to analyze the current project for frontend developer profile material.

Treat the current workspace or active project as the project to analyze unless the user provides a different folder, repository, project name, target role, or target brief in the prompt arguments.

Default to the full bilingual project report. Only use quick, chat-only, or alternate output when the prompt arguments explicitly request it.

Produce the agent's standard bilingual project reports and write them to the configured project-profiles archive:

`$HOME/Documents/2026 work/copilot-asset-manager/local/archives/project-profiles/<project-name>`

The report must remain frontend-first while including backend context that helps explain frontend architecture, API boundaries, auth/role constraints, deployment, or full-stack credibility. Preserve the product's own project name for the folder, including Traditional Chinese names such as `桃園GIS`, unless path-hostile characters must be normalized.

Include the agent's professional-focused sections:

- `Use This Now` summary for immediate profile and technical discussion use
- personal contribution confidence labels so project evidence is not confused with confirmed personal ownership
- business translation that turns frontend work into user, operational, and business value
- bilingual glossary for natural English and Traditional Chinese profile/technical discussion phrasing

If the project-profiles archive is not writable from the current workspace, stop and explain that `copilot-asset-manager` should be opened as an additional workspace folder. Do not silently write reports into the analyzed project.

After writing the reports, respond with a concise summary of the two report paths, the top profile-worthy frontend findings, and any confirmation questions needed before the user uses stronger profile claims.

