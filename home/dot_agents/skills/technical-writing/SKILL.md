---
name: technical-writing
description: "Google Technical Writing style rules for READMEs, design documents, PR and MR descriptions, doc comments, and code comments. Load when drafting or substantially rewriting one of those and the prose runs longer than a few sentences. Not for ordinary chat replies, short inline notes, or commit messages — a commit body is written for someone who has just read the diff, so `git-commit-reference` governs it instead."
---

# Technical Writing Rules

Apply these rules when writing or editing technical prose. They follow Google's Technical Writing courses.

## Words

- **Define terms:** Define an unfamiliar term before its first use, or link to an existing definition.
- **Consistent terminology:** Use the same term for the same concept every time. Do not switch synonyms.
- **Acronyms:** Give an acronym its full expansion on first use, then use the acronym thereafter.
- **Unambiguous pronouns:** Replace an ambiguous pronoun (_it_, _they_, _this_, _that_) with the noun it refers to when the reference is more than a few words away.

## Active Voice

- **Prefer active voice:** Prefer active voice over passive voice. Name the actor before the verb.
- **Strong verbs:** Prefer strong verbs over weak verbs plus a noun.
  - **BAD:** perform a calculation of the total
  - **GOOD:** calculate the total
- **Eliminate existential openings:** Reduce _"there is"_ and _"there are"_ openings. Start with the real subject instead.

## Clear Sentences

- **One idea per sentence:** Express one idea per sentence. Split a long sentence into several short ones.
- **Break out complex conditions:** Convert a long sentence that lists conditions or steps into a list.
- **Remove filler:** Remove filler that adds no information, such as _basically_, _really_, _crucial_, or _in order to_.
- **Front-load main points:** Put the main point at the start of the sentence, not buried after clauses.

## Paragraphs

- **Topic sentences:** Start each paragraph with a topic sentence that states its main point.
- **Single topic per paragraph:** Keep each paragraph to one topic. Move an unrelated idea to its own paragraph.
- **Paragraph length:** Limit a paragraph to roughly three to five sentences.
- **Core questions:** Answer _what_, _why_, and _how_ for the reader within the surrounding paragraphs.

## Lists and Tables

- **Prefer lists over block text:** Prefer a bulleted or numbered list over a run-on paragraph of related items so readers can scan the content.
- **Bulleted lists:** Use a bulleted list when the order of items does not matter.
- **Numbered lists:** Use a numbered list when the order matters, such as sequential steps or ranked items.
- **Introduce lists cleanly:** Introduce each list with a sentence that says what the list represents, and end that sentence with a colon.
- **Parallel structure:** Keep list items parallel in grammar, capitalization, and punctuation.
- **Imperative verbs for steps:** Start each item of a numbered list with an imperative verb, such as _"Download"_, _"Configure"_, or _"Start"_.
- **Avoid embedded lists:** Avoid embedded (run-in) lists inside a sentence. Break them out into a real list.
- **Tables for multi-attribute comparisons:** Use a table when each item has several comparable attributes. Give every column a clear heading.

## Audience & Clarity

- **Know the audience:** Identify the audience and write to their level of prior knowledge.
- **Prerequisites first:** State prerequisites before the steps that depend on them.
- **Concrete claims:** Prefer concrete, verifiable statements over vague claims.
  - **BAD:** The build is usually fast.
  - **GOOD:** The build finishes in under 30 seconds on a clean checkout.

---

## Example Transformation

### Before (Wordy & Passive)

> There are several steps that need to be taken in order to perform an installation of the server. It is basically pretty fast, but a config file must be created first by the developer.

### After (Google Tech Writing Style)

> To install the server, complete these steps:
>
> 1. Create a configuration file named `config.json` in the root directory.
> 2. Run `./install.sh`.
>
> The installation completes in under 15 seconds on standard hardware.
