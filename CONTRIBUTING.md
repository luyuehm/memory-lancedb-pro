# Contributing to memory-lancedb-pro

Thanks for helping improve `memory-lancedb-pro`.

## What to contribute

- Bug fixes with clear reproduction + regression test
- Stability and observability improvements
- Performance and retrieval quality improvements
- Docs/examples that reduce integration mistakes

## Engineering principles

1. **Evidence-first**: include commands/tests proving behavior.
2. **Minimal fix surface**: avoid unrelated refactors in bug-fix PRs.
3. **Backward compatibility**: call out config/schema/tooling impact.
4. **Host-real validation**: not only unit tests; include OpenClaw host path when relevant.

## PR Checklist

- [ ] Problem statement with reproducible symptom
- [ ] Root cause explained
- [ ] Minimal code change linked to root cause
- [ ] Tests added/updated
- [ ] `npm test` passes
- [ ] `npm run test:openclaw-host` passes (when applicable)
- [ ] Release/readiness impact documented

## Commit message style

Use conventional style where possible:

- `fix(...)`: bug fixes
- `feat(...)`: new behavior
- `docs(...)`: documentation only
- `chore(...)`: maintenance/tooling
- `test(...)`: tests only

## Recommended issue/PR structure

### PR
- Summary
- Problem
- Root Cause
- Changes
- Validation
- Risks / Boundaries

### Issue
- Expected behavior
- Actual behavior
- Reproduction steps
- Environment

## Scope discipline

- One PR should address one primary problem.
- If additional refactor is unavoidable, explain why.
- Keep noisy formatting-only changes separate.

## Security & safety

- Do not commit secrets/tokens.
- Avoid exposing private data in fixtures/logs.
- Be explicit about any destructive command paths.
