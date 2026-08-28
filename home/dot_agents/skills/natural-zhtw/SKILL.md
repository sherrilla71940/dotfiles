---
name: natural-zhtw
description: "Produce natural Traditional Chinese for Taiwan (zh-TW). Load whenever drafting, translating into, substantially rewriting, or reviewing sentence-level zh-TW, including PR/MR descriptions, issues, technical documentation, comments, emails, messages, reports, UI copy, explanations, and English-to-Chinese translation. Also load when checking whether wording sounds unnatural, overly literal, overly formal, Mainland-influenced, translated, or AI-written."
user-invocable: false
---

# Natural Taiwan Chinese

Produce zh-TW that sounds as if it were originally written by a fluent Taiwanese person for the actual context.

The goal is not merely grammatically correct Traditional Chinese. The writing should feel native to Taiwan and should not expose the structure or wording of another source language.

## Core principle

**Write for the target language, not from the source language.**

Preserve:

* intended meaning
* facts
* tone
* level of certainty
* technical precision
* important qualifications and distinctions

But freely adapt:

* wording
* grammar
* sentence structure
* sentence boundaries
* information order
* idioms
* emphasis
* level of explicitness

when doing so makes the zh-TW more natural.

For translation, preserve **semantic fidelity rather than syntactic fidelity**.

The ideal result should read as though a Taiwanese person originally wrote it in Chinese, not as though English was translated sentence by sentence.

---

## Match the actual register

Do not make everything casual.

Use the level of formality that fits the context:

* engineering PR/MR, issue, code comment → concise, direct, professional
* internal workplace communication → natural professional Taiwanese
* technical documentation → clear, precise, moderately structured
* customer-facing or formal business writing → appropriately polished
* legal, regulatory, government, or explicitly formal writing → preserve necessary formality
* casual conversation → natural conversational Taiwan Chinese

If the user supplies an existing style or explicitly requests a level of formality, follow it.

Natural does not mean informal. Professional does not mean bureaucratic.

---

# Translating into zh-TW

## Translate the message, not the words

When translating English or another language into zh-TW, first understand what the source is actually trying to communicate.

Do not mechanically map:

* word → word
* phrase → phrase
* English sentence → Chinese sentence
* English grammar → Chinese grammar

Instead ask:

> What would a Taiwanese person naturally say to communicate the same thing in this situation?

Use that wording.

### You may freely

* restructure sentences
* split one source sentence into several Chinese sentences
* combine several source sentences
* reorder information
* omit subjects or pronouns Chinese would naturally omit
* replace passive voice with active phrasing
* replace idioms with natural Taiwan equivalents
* replace literal metaphors with wording serving the same purpose
* convert abstract noun-heavy English into direct verbs
* remove redundancy required only by English grammar
* make relationships explicit when Chinese needs them for clarity
* make implicit wording more direct when that is natural in zh-TW

Do not preserve source-language structure merely because a literal translation is technically understandable.

## Preserve meaning, not phrasing

Do not freely change:

* facts
* numbers
* dates
* names
* code identifiers
* filenames
* technical behavior
* requirements
* contractual or legal meaning
* uncertainty
* causal relationships
* scope
* important caveats

Naturalization must not introduce new claims or lose meaningful information.

---

## Translation examples

### Engineering decision

English:

> We made the decision to leave this unchanged for now because we are still waiting for confirmation from the backend team.

Too literal:

> 我們做出了暫時維持此項不變的決定，因為我們仍在等待後端團隊的確認。

Natural:

> 這邊先不調整，等 BE 確認後再處理。

The natural version does not mirror the English grammar, but preserves the useful meaning.

---

### Blocking issue

English:

> This is the one thing blocking us right now.

Too literal:

> 這是目前唯一阻擋我們的事情。

Natural:

> 目前就卡在這個問題。

---

### Silent behavior

English:

> The value will be silently ignored.

Usually avoid:

> 該值將被靜默忽略。

Prefer, when this is the actual behavior:

> 這個值會直接被忽略，而且不會報錯。

Use specialized terminology only when the audience benefits from it.

---

### No functional impact

English:

> This issue does not have any impact on the upload process and is purely cosmetic.

Too source-shaped:

> 此問題不會對上傳流程造成任何影響，純粹是外觀上的問題。

Possible natural versions depending on the actual meaning:

> 這個不影響上傳功能，只是顯示上的問題。

or:

> 目前不影響功能，只是格式看起來不太一致。

Translate the intended meaning of "cosmetic"; do not automatically map the word itself.

---

# Avoid translationese

Before finalizing zh-TW based on another language, check whether the source language is still visible underneath the Chinese.

Common warning signs:

* unnecessary pronouns
* repeated `我們`
* English-style passive constructions
* long chains of `的`
* excessive nominalization
* abstract phrases where Chinese would use a direct verb
* preserving English sentence boundaries despite awkward Chinese flow
* literally translated metaphors or idioms
* unnatural emphasis patterns
* phrases that are grammatically correct but rarely used by Taiwanese speakers

For example:

Avoid:

> 我們進行了對這個問題的調查。

Prefer:

> 我們查了一下這個問題。

Or in a PR:

> 確認後發現問題出在……

Avoid:

> 我們做出了移除該檢查的決定。

Prefer:

> 這次移除這項檢查。

---

# Avoid over-formal and AI-polished zh-TW

Prefer the simplest wording that a Taiwanese person would naturally use in the context.

Do not choose a rarer, more literary, or more bureaucratic expression merely because it sounds precise.

Unless the context genuinely calls for formal wording, generally prefer:

* `是` / `是因為` over unnecessary `屬`
* `這次` over repeated `本次`
* `在` over unnecessary `於`
* `如果` over repeated `若`
* `都` over repeated `皆` / `全數`
* `原本` / `現有` over unnecessarily formal `既有`
* `還是會` / `仍會` over `仍照舊`
* `請 PM 確認` over `提交 PM 決定`
* `問題` / `錯誤` over `勘誤` for ordinary engineering issues
* direct clauses over noun phrases ending in `者`

These are tendencies, not banned words.

Use the formal alternative when it genuinely fits the audience or meaning.

## Warning clusters

Be especially alert when ordinary workplace writing contains many expressions such as:

* `屬`
* `於`
* `若`
* `皆`
* `全數`
* `之`
* `者`
* `既有`
* `勘誤`
* `採集`
* `刻意`
* `仍照舊`
* `提交……決定`

Any individual word may be natural. Repeated clustering often makes normal engineering Chinese sound like a government report or AI-generated documentation.

---

# Prefer direct Taiwanese phrasing

Too report-like:

> 已確認屬先前檢查程式殘留。

Prefer:

> 已確認是之前的檢核邏輯沒有移除。

---

Too deliberate:

> 本次刻意不修改政府提供的範本檔。

Prefer:

> 這次先不修改政府提供的範本檔，等 PM 確認後再調整。

---

Too compressed:

> 移除等於停止採集「工程編號」。

Prefer:

> 如果直接移除 `CONS_ID`，之後就不會檢查／匯入「工程編號」。

---

Too formal:

> 政府提供的範本檔本身有四處錯誤，全數提交 PM 決定。

Prefer:

> 另外檢查範本時發現 4 個問題，這次先不修改，請 PM 確認後再處理。

---

Too nominalized:

> 唯一有資料遺失風險者

Prefer:

> 這項有資料被忽略的風險

---

Too compressed:

> 修正渲染端而非 29 處推入點。

Prefer:

> 這次統一在畫面顯示端處理，不逐一修改 29 個加入錯誤資料的位置。

---

# Taiwan terminology

Prefer terminology normally used in Taiwan when there is a meaningful regional difference.

Typical software examples:

* `程式` rather than `程序` when referring to a software program
* `資料` where Taiwan usage naturally means data/information
* `專案` rather than Mainland-style `項目` for a software project
* `元件` rather than `組件` for UI/software components
* `設定` rather than unnecessary `配置`
* `呼叫 API` rather than `調用 API`
* `回傳` rather than `返回` for function/API return behavior
* `伺服器` rather than `服務器`
* `影片` rather than `視頻`
* `建立` / `新增` rather than `創建` when appropriate

Do not mechanically Taiwanize source-of-truth terminology.

Preserve:

* project-specific terms
* official government terminology
* legal or regulatory names
* database field names
* API names
* identifiers
* UI strings being quoted
* domain terminology

For example, if `用戶接管` is the official domain term, do not replace it merely because another word might be more common in general software writing.

---

# Engineering writing

For PR/MR descriptions, issues, investigation notes, technical documentation, and code-related communication:

* optimize for another engineer understanding the change quickly
* keep technical details precise
* use straightforward sentences
* explain why when the reason matters to implementation or review
* clearly distinguish verified facts from assumptions
* preserve code identifiers exactly
* keep familiar English technical terminology when Taiwanese developers normally use it
* do not translate technical terms merely for linguistic purity

Terms such as these are normally fine:

* `rebase`
* `DOM`
* `API`
* `DB`
* `tsconfig`
* `PM`
* `BE`
* `FE`
* `解析`
* `值域檢查`
* `回歸測試`

Avoid turning an ordinary PR into an RFC, incident report, academic paper, or government document unless the situation genuinely warrants that register.

For a normal PR/MR, natural headings often include:

* `問題`
* `修改內容`
* `驗證`
* `待確認`

Do not force this exact structure when another organization is clearer.

---

# Do not over-compress

Chinese permits compact wording, but excessive compression often makes AI-generated technical Chinese sound unnatural.

Prefer:

> 解析層原本的數字格式和值域檢查保留不動。因為目前已有「欄位不存在就略過」的處理，所以 115 年範本沒有這些欄位時不會受影響。

over:

> 解析層的數字格式與值域檢查刻意保留：本就有「欄位不存在則略過」的防護。

Prefer complete, direct sentences when they sound more natural.

Precision matters more than brevity, but natural simplicity is preferable to compressed sophistication.

---

# Do not over-edit source text

Do not silently rewrite or normalize:

* quotations
* official regulatory wording
* government field labels
* existing UI strings being discussed
* code
* identifiers
* filenames
* exact error messages

Preserve these unless the task explicitly asks to change them.

---

# Final native-language pass

Before returning substantial zh-TW prose, silently review it once.

Ask:

1. Would a Taiwanese person plausibly write this in this situation?
2. Does it sound as though it was originally written in Chinese?
3. Can I see English grammar or sentence structure underneath it?
4. Is any sentence more formal, literary, or bureaucratic than necessary?
5. Did I translate an expression word-for-word where Taiwanese Chinese would say it differently?
6. Are there Mainland-specific terms where a normal Taiwan equivalent would be preferable?
7. Are technical terms, facts, identifiers, and official domain terminology preserved?
8. Did naturalization accidentally change certainty, scope, causality, or factual meaning?
9. Can a dense noun phrase be expressed more naturally as a direct sentence?
10. Does the result sound competent and professional without sounding artificially polished?

If the wording is correct but a fluent Taiwanese speaker would naturally express the same idea differently, use the natural Taiwan-native version.

When translating, remember:

> **Same message does not require the same words.**
