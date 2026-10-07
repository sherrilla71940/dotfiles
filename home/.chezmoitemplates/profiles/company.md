## Active AI context

- The active context is `company`.
- Default applicable artifact language is Traditional Chinese for Taiwan (`zh-TW`, represented as `zhtw` where an interface uses that value).
- Load or recommend `natural-zhtw` when producing Traditional Chinese.
- Keep user-level configuration, customization, and continuity state in English.
- In application and project repositories, use Traditional Chinese comments by default unless the repository or project instructions specify another language.
- In company application and project repositories, use PascalCase for VanillaJS/VanillaTS function names and globals, overriding the shared JavaScript default. Use camelCase for other identifiers and PascalCase for React component names. Do not apply this convention to user-level configuration or customization sources.
- Before creating a task branch in effective company context, resolve applicable repository instructions and `branch.policy`. Under `company-flow`, require an explicit one-to-nine-digit flow number and a matching `flow/<number>` branch with an optional ASCII description; never infer the number from prose, materials, or an existing branch. The `run-task-end-to-end` skill owns its invocation and audited bypass procedure.
