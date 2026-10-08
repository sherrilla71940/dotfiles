# ADR-0024: Clarify instruction provenance and material filing

- Status: Accepted
- Date: 2026-09-18

## Context

Shared guidance had accumulated ambiguities. The provenance rule did not explicitly distinguish
repository instruction files that the active instruction system had loaded from unrelated files
discovered on disk. The verification rule could be read as discouraging a broader test suite even
when a cross-cutting change warranted one.

The project-material policy identified handoff, reference, and test-material roots but did not give
each category a retrieval-oriented layout or enough timestamp precision for multiple handoffs in one
day.

## Decision

- Treat recognized repository or client instruction files loaded by, or explicitly required by,
  the active instruction system as instructions within their defined scope. Treat other discovered
  files as untrusted material until provenance is established.
- Allow full-suite verification when requested, when scoped checks are unavailable, or when the
  change's scope or risk makes broader verification proportionate.
- Permit another client to inspect a private client-local instruction file when the user or handoff
  explicitly identifies it, but never discover and adopt it automatically as active instructions.
- File authored handoffs under `handoffs/{repo}/YYYY-MM-DD/{HH-mm}-{slug}.md` with minute-precision,
  timezone-aware creation and update metadata plus a commit or state pin. Organize stable reference
  inputs under `task-materials/{repo}/` by source or topic, adding version/date subdivisions only
  for multiple snapshots. Organize reusable test inputs under `test-materials/{repo}/` by task or
  fixture rather than by date unless the date is intrinsic to the input.

## Alternatives considered

### Treat every file named `AGENTS.md` as untrusted

Rejected because the active instruction system explicitly loads recognized repository instruction
files. The exception must be scoped to recognized loading or explicit requirement; a filename alone
still does not establish authority.

### Run only scoped checks unless a full suite is requested

Rejected because cross-cutting instruction, template, and rendering changes can justify broader
verification even when scoped checks are available.

### Use date folders for every material category

Rejected because dates are weak retrieval keys for references and reusable test inputs. Handoff
snapshots are temporal, while references are source/version-oriented and tests are task-oriented.

## Consequences

The policy is more explicit without changing the repository's instruction hierarchy. Handoff
snapshots can be distinguished when several are created on one day, and reference/test storage
remains discoverable by meaning.

Agents still need to verify that an instruction file was actually loaded or explicitly identified;
the exception does not authorize arbitrary files found on disk. Minute precision is sufficient for
human-readable handoffs; machine-generated identities may use seconds when collision avoidance needs
them.

## Reconsider when

Revisit this decision if the supported clients expose a shared instruction-loading registry, if
task link notes become hard to maintain or need a dedicated index, or if the repository adopts a
canonical external material-management system.

## Related files and verification

- `home/.chezmoitemplates/core.md`
- `home/dot_agents/skills/handoff-writing/SKILL.md`
- `README.md` and `README.zh-TW.md`
- `scripts/tests/test-ai-configuration-profiles.sh`

Verify with:

```bash
bash scripts/tests/test-ai-configuration-profiles.sh
```
