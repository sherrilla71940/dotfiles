# Invocation, normalization and validation

Read this at step 1 of `frontend-task-workflow`, before anything else. Nothing in the repository
is created, changed or fetched until this file's checks pass.

Claude Code passes the whole trailing text as `$ARGUMENTS`. It has no named-argument parser, and
its indexed placeholders (`$0`, `$1`) have no documented quote handling, so neither is used here:
one tokenizer runs over the raw text, and the echo-back in step 8 is what makes a misread visible
rather than silent.

## 1. Tokenize

Split `$ARGUMENTS` on whitespace, except inside quotes. A double-quoted span is one token with
the quotes removed, and a quote may open partway through a token, so `task="兩個 字"` is the
single token `task=兩個 字`. Single quotes work the same way; prefer double quotes.

Values containing spaces **must** be quoted. An unclosed quote is a malformed invocation — reject
it rather than guessing where the value ended.

## 2. Classify each token

In order, the first rule that matches wins:

| Token shape | Class |
| --- | --- |
| `--infer-task` | flag, same as `infer-task=true` |
| `--no-agent-test` | flag, same as `agent-test=false` |
| any other `--…` token | **error** — an unknown flag |
| `<key>=<value>` where `<key>` is known | option |
| `<key>=<value>` where `<key>` is unknown | **error** — never silently a material |
| anything else | bare |

A flag spelling exists only for the value that is *not* the default, which is why there is no
`--agent-test` and no `--no-infer-task`: both would be no-ops that read like decisions. Use the
`key=value` form to state a default explicitly.

The known keys, and the only ones accepted:

| Key | Values | Default |
| --- | --- | --- |
| `base` | a branch name on `origin`, with or without the `origin/` prefix | required |
| `task` | the task description | required unless inference is on |
| `infer-task` | `true` · `false` | `false` |
| `materials` | one path; repeatable, and extended by trailing bare tokens | none |
| `type` | a Conventional Commit type for the branch | inferred |
| `slug` | ASCII kebab-case branch slug | inferred |
| `branch` | the whole branch name, overriding `type`/`slug`/`suffix` | `{type}/{slug}/{suffix}` |
| `suffix` | last branch segment | `frontend` |
| `lang` | `en` · `zhtw`, covering the commit messages and the request text only | `zhtw` |
| `mode` | `commit` · `draft` | `commit` |
| `group` | `batch` · `single` | `batch` |
| `agent-test` | `true` · `false` | `true` |
| `cleanup` | `ask` · `auto` · `keep` | `ask` |

An unknown key is an error even when it looks like a path, because a mistyped option that became
a material would change what gets read without anyone noticing. If a real path contains `=`,
pass it as `materials=<path>`.

`test=` is not a key. It was one during design and is deliberately gone: `test=false` would read
as "this workflow does no testing", when manual testing is the one step that is never optional.
Reject it with that explanation and point at `agent-test`.

### Boolean values

`infer-task` and `agent-test` are the two booleans, and they accept exactly `true` and `false`.
Case is normalized, so `True` is fine. Nothing else is: `yes`, `no`, `1`, `0`, `on`, `off`, `y`,
`n` and an empty value are all rejected rather than interpreted. One spelling everywhere is worth
more than convenience here, because these two flags decide whether a task is read from materials
and whether any verification runs at all.

## 3. Fill the slots

Options bind to their own key, so their order never matters. Bare tokens fill the unfilled
positional slots **in order**:

1. `base`, if no `base=` was given;
2. `task`, if no `task=` was given and inference is off;
3. every remaining bare token is a material, appended after any `materials=` values.

This single rule covers both invocation styles, so they normalize to the same values:

```text
/frontend-task-workflow feat/CCTVPipiCons "污水管線 TV 檢視紀錄" "handoff.md" "screens.pptx"
/frontend-task-workflow base=feat/CCTVPipiCons task="污水管線 TV 檢視紀錄" materials="handoff.md" "screens.pptx"
/frontend-task-workflow task="污水管線 TV 檢視紀錄" materials="handoff.md" "screens.pptx" base=feat/CCTVPipiCons
/frontend-task-workflow feat/CCTVPipiCons --infer-task "handoff.md" "screens.pptx"
/frontend-task-workflow base=feat/CCTVPipiCons infer-task=true materials="handoff.md" "screens.pptx"
```

Flags and options carry their own meaning, so they can sit anywhere without disturbing the slots.
These two are the same invocation:

```text
/frontend-task-workflow feat/CCTVPipiCons "污水管線 TV 檢視紀錄" --no-agent-test "handoff.md"
/frontend-task-workflow feat/CCTVPipiCons --no-agent-test "污水管線 TV 檢視紀錄" "handoff.md"
```

When inference is on, the task slot is closed, so bare tokens after `base` are all materials.

## 4. Reject these

This is the structural pass: whether the invocation is coherent as written, answerable without
opening a single material. The semantic pass — whether the task itself is clear and matches the
material — comes in steps 6 and 7, and can only run after reading. Both stop the workflow; they
just answer different questions.

Stop on any of them. Report, and create nothing.

| Condition | Why it is not guessable |
| --- | --- |
| No `base` | There is no safe default; the base is also the request target. |
| Neither `task` nor inference | An omitted task is far more often a mistake than an intent. |
| Both `task` and inference | Two sources of task identity, no reason to prefer either. |
| An unknown `key=` token | Probably a typo in an option name. |
| A repeated option with a different value | Which one was meant is unknowable. `materials` is the one exception: it is repeatable and its values accumulate. |
| An option with an empty value, such as `task=` | An empty value is a slip, not an instruction. |
| An unknown value for `lang`, `mode`, `group` or `cleanup` | Falling back to a default would silently change behavior. |
| A boolean spelled anything but `true`/`false` | `agent-test=yes` is a guess about intent; see [Boolean values](#boolean-values). |
| An unclosed quote | The value's end is unknown. |
| A material path that does not exist or cannot be read | The plan would be built on material nobody read. |
| The token filling the `task` slot resolves to an existing file | It is a material, and the task was omitted. Ask for a task or `--infer-task`. |
| The token filling the `base` slot exists as a file, or contains whitespace | It is in the wrong position. |
| `branch=` given together with `type=`, `slug=` or `suffix=` | Two different branch names were described. |

Check material paths before touching git. Windows paths with backslashes are fine when quoted.

`origin/<base>` not existing on the remote is the same class of failure, but it can only be
detected after the fetch in step 2 of the workflow. Handle it there the same way: report near
matches from `git branch -r --list "origin/*<fragment>*"`, and create nothing.

## 5. Read the materials

Read every supplied material before planning, using the dedicated skill for its container type
(`pdf`, `pptx`, `xlsx`, `docx`) and an ordinary read for markdown, text and images, per the
global rule. Classify them under the global project-material rule in the same turn.

Say which materials you actually read, and name any you could only partly extract.

## 6. Infer the task, when asked

Only with `--infer-task` or `infer-task=true`:

1. Read the materials first.
2. Derive one concise human-readable task name, in the materials' own language.
3. Use that understanding — not just the name — for the branch type and slug.
4. Ask rather than guess when the materials describe several distinct tasks, contradict each
   other, or do not identify one task confidently. Offer the candidates you found.

Show the inferred task in the echo block marked `(inferred)`, so it is never mistaken for
something the user typed.

## 7. Cross-check an explicit task against the materials

With an explicit task, check it against what the materials actually describe. If they disagree
materially — a different screen, feature, or module — stop and show both readings before
implementing. Do not decide which one is right, and do not silently follow either.

A difference of wording, scope detail, or language is not a conflict. Only a different subject is.
## 8. Echo the resolved interpretation, always

One block, last, after the task is fully resolved — so it shows what will actually be used rather
than a placeholder that inference has not filled in yet. Even a clean invocation gets it, and it
comes before any git command, so a misread is visible while it is still cheap:

```text
base       feat/CCTVPipiCons
task       污水管線 TV 檢視紀錄           (explicit)
materials  handoff.md, screens.pptx
branch     feat/cctv-pipe-inspection-record/frontend   (type and slug inferred)
worktree   <repo>/.claude/worktrees/cctv-pipe-inspection-record
commit     commit · batch · zhtw
agent-test true        cleanup  ask
```

For a rejection, use the same block with the unresolved fields marked, followed by what is wrong
and the corrected invocation when it is reasonably clear:

```text
Rejected: no task, and inference was not requested.

base       feat/CCTVPipiCons
task       (missing) — "handoff.md" is an existing file, so it was read as a material
materials  handoff.md

Did you mean:
  /frontend-task-workflow feat/CCTVPipiCons --infer-task "handoff.md"
  /frontend-task-workflow feat/CCTVPipiCons "污水管線 TV 檢視紀錄" "handoff.md"

Nothing was created.
```

Normalize only what cannot change meaning: whitespace, a stripped `origin/` prefix, a trailing
path separator, quote removal, boolean letter case. Anything that could change the base, the task
identity, the branch name, which materials get read, whether verification runs, or the resulting
request must fail instead.
