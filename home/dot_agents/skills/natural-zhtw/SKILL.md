---
name: natural-zhtw
description: "Produce natural Traditional Chinese for Taiwan (zh-TW). Load whenever drafting, translating into, substantially rewriting, or reviewing sentence-level zh-TW, including PR/MR descriptions, issues, technical documentation, comments, emails, messages, reports, UI copy, explanations, and English-to-Chinese translation. Also load when checking whether wording sounds unnatural, overly literal, overly formal, Mainland-influenced, translated, or AI-written."
user-invocable: false
---

# Natural Taiwan Chinese

Write zh-TW that reads as though a Taiwanese person wrote it for this context, not as translated
English. Preserve semantic fidelity rather than syntactic fidelity.

## Preserve, and adapt

**Preserve:** meaning, facts, numbers, dates, names, code identifiers, filenames, technical
behavior, requirements, level of certainty, causality, scope, important caveats, contractual and
legal meaning.

**Adapt freely:** wording, grammar, sentence structure and boundaries, information order, idioms,
emphasis, explicitness. Split one sentence into several or merge them, drop pronouns Chinese
would omit, replace passive with active, turn abstract noun-heavy phrasing into direct verbs.

Naturalization must never add a claim or drop a qualification.

## Register

| Context | Register |
| --- | --- |
| PR/MR, issue, code comment | concise, direct, professional |
| Internal workplace communication | natural professional Taiwanese |
| Technical documentation | clear, precise, moderately structured |
| Customer-facing or formal business | appropriately polished |
| Legal, regulatory, government | keep the formality it requires |
| Casual conversation | natural conversational Taiwan Chinese |

Natural does not mean informal; professional does not mean bureaucratic. An existing style or an
explicit request from the user outranks this table.

## Prefer the plain word

| Prefer | Over |
| --- | --- |
| `是` / `是因為` | `屬` |
| `這次` | `本次` |
| `在` | `於` |
| `如果` | `若` |
| `都` | `皆` / `全數` |
| `原本` / `現有` | `既有` |
| `還是會` / `仍會` | `仍照舊` |
| `請 PM 確認` | `提交 PM 決定` |
| `問題` / `錯誤` | `勘誤` |
| a direct clause | a noun phrase ending in `者` |

These are tendencies, not banned words — use the formal option when the audience or the meaning
genuinely calls for it.

**Warning cluster.** Any one of `屬 於 若 皆 全數 之 者 既有 勘誤 採集 刻意 仍照舊 提交……決定`
may be natural. Several of them in ordinary workplace writing is what makes engineering Chinese
read like a government report or AI output.

## Taiwan terminology

`程式` not `程序` · `專案` not `項目` · `元件` not `組件` · `設定` not `配置` · `呼叫 API` not
`調用 API` · `回傳` not `返回` · `伺服器` not `服務器` · `影片` not `視頻` · `建立` / `新增` not
`創建` · `資料` for data.

Do not Taiwanize source-of-truth terminology: project-specific terms, official government or
legal names, database field names, API names, identifiers, quoted UI strings. If `用戶接管` is the
official domain term, keep it.

Keep the English technical terms Taiwanese developers normally use: `rebase`, `DOM`, `API`, `DB`,
`tsconfig`, `PM`, `BE`, `FE`.

## Translationese

Signals that the source language still shows through: unnecessary pronouns, repeated `我們`,
English-style passives, long chains of `的`, nominalization where a verb belongs, English sentence
boundaries kept despite awkward flow, literally translated idioms.

| Instead of | Write |
| --- | --- |
| 我們進行了對這個問題的調查。 | 我們查了一下這個問題。 |
| 我們做出了移除該檢查的決定。 | 這次移除這項檢查。 |
| 這是目前唯一阻擋我們的事情。 | 目前就卡在這個問題。 |
| 該值將被靜默忽略。 | 這個值會直接被忽略，而且不會報錯。 |
| 已確認屬先前檢查程式殘留。 | 已確認是之前的檢核邏輯沒有移除。 |
| 唯一有資料遺失風險者 | 這項有資料被忽略的風險 |
| 此問題純粹是外觀上的問題。 | 這個不影響功能，只是顯示上的問題。 |
| 本次刻意不修改政府提供的範本檔。 | 這次先不修改政府提供的範本檔，等 PM 確認後再調整。 |

Do not overcorrect into compression either. Complete, direct sentences usually read better than
dense ones, and precision outranks brevity.

For a normal PR/MR, `問題` / `修改內容` / `驗證` / `待確認` are natural headings; use another
structure when it is clearer. Do not turn an ordinary PR into an RFC or an incident report.

## Do not rewrite quoted material

Leave quotations, regulatory wording, government field labels, existing UI strings, code,
identifiers, filenames and exact error messages exactly as they are unless the task asks to
change them.

## Final pass

Before returning substantial zh-TW prose, read it once and ask:

1. Would a Taiwanese person write it this way in this situation?
2. Can I still see English structure, or wording more formal than the context needs?
3. Are the facts, certainty, scope and identifiers unchanged?
