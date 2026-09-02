# ADR-0010: Normalize the whole working tree to LF

- Status: Accepted
- Date: 2026-09-02

## Context

Chezmoi copies source bytes verbatim, so an applied target keeps whatever line endings the
working copy had at apply time. With `core.autocrlf=true` on Windows, Git commits LF and checks
out CRLF, so the working copy that chezmoi reads is CRLF while every blob in the index is LF.

`.gitattributes` previously pinned `eol=lf` on seven paths only: shell scripts and generated
shell profiles, where a CRLF interpreter line breaks at runtime. Everything else was left to
`core.autocrlf`. The result on this machine was 215 of 327 tracked files checked out CRLF, with
four more holding mixed endings, and therefore 211 targets rendered with endings that did not
match a freshly checked-out source.

The workflow guide documented that churn as expected and told agents to read past it: trust
`git diff` for content, let the EOL-only hunks apply. That instruction is correct and it is
still not sufficient, because it asks every reader to separate signal from noise on every diff.
On 2026-09-02 that separation failed. A two-line edit to `git-commit-action/SKILL.md` rendered
in `chezmoi diff` as a 118-line whole-file replacement, and the session reported it as
pre-existing drift rather than inspecting it. The real change was found only by diffing the
target against the rendered source with carriage returns stripped.

Line endings also resist casual verification here. On Git Bash, `grep $'\r'` reports nothing
because the CR is stripped by text-mode input before `grep` sees it, and `grep '\r'` matches a
literal `r` because `\r` has no meaning in a POSIX basic regular expression. Both return a
confident clean result on a CRLF file, and both did during the investigation above.

## Decision

Pin every file to LF in the working tree with `* text=auto eol=lf`, and keep the pre-existing
explicit `text eol=lf` lines so binary misdetection cannot leave CRLF in an interpreter line.

Renormalize once so the working tree and the applied targets match the new attribute, rather
than letting files convert piecemeal as Git happens to touch them.

## Alternatives considered

- **Keep tolerating the churn:** the documented status quo, needing no change and no
  renormalization. Rejected because the churn is not merely cosmetic. It hid a real change
  from a session that was specifically looking at that diff, and the mitigation it offers is a
  judgment every reader must repeat correctly every time.
- **Pin `*.md` only:** the narrower fix this repository's guide previously contemplated, and
  enough for the case that exposed the problem. Rejected because markdown is 61 of the 215
  CRLF files. Python scripts, JSON settings, PowerShell scripts and the bundled XSD schemas
  drift identically, so the narrow fix leaves most of the noise in place.
- **Set `core.autocrlf=false` per machine:** removes the conversion at its source and needs no
  attribute changes. Rejected for the reason ADR-0006 rejected a per-machine `sourceDir`: it is
  unmanaged state outside the repository, so a new or reimaged machine silently returns to the
  old behavior with nothing to detect it.
- **Record nothing and treat it as an incidental edit:** rejected because the workflow guide
  had already ruled that a repository-wide `eol=lf` needs a record, and a later session finding
  the attribute without the reasoning would face exactly the ambiguity ADR-0001 exists to
  prevent.

## Consequences

`chezmoi diff` now reports only hunks that change content, so a small real change is visible
as a small diff.

The one-time renormalization rewrote 219 working-tree files and 211 targets. No content
changed: every index blob was already LF, `git diff` was empty across the tree afterward, and
each differing target was compared against its rendered source with carriage returns stripped
before the apply.

A renormalizing checkout does not happen through `git checkout-index -a -f` alone, which honors
the stat cache and leaves existing files untouched. The working tree has to be removed and
restored. After that, Git reports every restored file as modified until the index stat entries
are refreshed, which looks alarming and means nothing; `git diff --stat` stays empty throughout.

Binary files now depend on `text=auto` detection. A file that is misdetected needs an explicit
`-text` line rather than a change to the global rule.

Any tool that requires CRLF would now receive LF. The repository tracks no `.bat` or `.cmd`
files, and PowerShell, VS Code and Windows Terminal all read LF.

## Reconsider when

- A tracked file genuinely requires CRLF at runtime, such as a Windows batch script.
- The repository stops being applied on Windows, which removes the conversion entirely.
- Git changes the precedence between `core.autocrlf` and the `eol` attribute.

## Related files and verification

- [`.gitattributes`](../../.gitattributes)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#line-endings)
- [`AGENTS.md`](../../AGENTS.md)

```bash
git ls-files --eol | awk '{print $2}' | sort | uniq -c   # every entry w/lf or w/none
tr -cd '\r' < <file> | wc -c                             # a single file, 0 when clean
```
