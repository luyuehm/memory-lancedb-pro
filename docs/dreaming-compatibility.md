# Dreaming Compatibility Design

> Updated: 2026-04-09  
> Relevant files: `src/dreaming.ts`, `index.ts`, `openclaw.plugin.json`, `test/dreaming-compatibility.test.mjs`

## Problem

The original `memory-lancedb-pro` could act as the active OpenClaw memory plugin, but it did not expose Dreaming settings in its schema and did not emit the Dreaming files that OpenClaw expects.

That meant users had to choose one of two unsatisfying options:

- keep `memory-lancedb-pro` active and lose Dreaming UI support
- switch back to `memory-core` and lose `memory-lancedb-pro` as the active memory slot

## Goal

Keep `memory-lancedb-pro` as the active memory plugin while making it Dreaming-compatible enough for OpenClaw's Dreaming UI and status readers.

## Compatibility Contract

The OpenClaw host mainly cares about two things:

1. The selected memory plugin schema must contain `dreaming`
2. The workspace must contain Dreaming-compatible artifacts

Required outputs:

- `memory/.dreams/short-term-recall.json`
- `memory/.dreams/phase-signals.json`
- `DREAMS.md` or `dreams.md`

## Implementation

### `src/dreaming.ts`

This module handles:

- Dreaming config parsing
- five-field cron matching
- candidate scoring and selection
- session corpus generation
- short-term store writing
- phase signal writing
- `DREAMS.md` maintenance
- optional per-phase reports

### `index.ts`

The plugin runtime wires Dreaming in by:

- extending `PluginConfig`
- parsing `config.dreaming`
- scheduling Dreaming sweeps from the background service
- triggering an extra sweep after reflection writes

### `openclaw.plugin.json`

The manifest now exposes:

- Dreaming config schema
- UI hints for Dreaming settings

### Tests

`test/dreaming-compatibility.test.mjs` covers:

- config parsing
- cron slot matching
- Dreaming artifact generation

## Files Produced

### `short-term-recall.json`

Represents active short-term entries and promoted entries, including path/range/snippet metadata.

### `phase-signals.json`

Represents light and REM phase hit counts used by host status readers.

### `DREAMS.md`

Human-readable Dream Diary output using the standard markers:

- `<!-- openclaw:dreaming:diary:start -->`
- `<!-- openclaw:dreaming:diary:end -->`

### `memory/.dreams/session-corpus/YYYY-MM-DD.md`

Internal compatibility corpus used to give short-term entries stable file paths and line ranges.

## Current Boundary

This is a compatibility implementation, not a full clone of `memory-core`.

Notably:

- it does not create `memory-core` managed cron metadata
- cron-managed status in the UI may remain partial
- it uses plugin memory and reflection data rather than `memory-core` internals

## Validation

```bash
node --test test/dreaming-compatibility.test.mjs
openclaw plugins info memory-lancedb-pro
openclaw config get plugins.entries.memory-lancedb-pro.config.dreaming
```

Check for:

- accepted Dreaming config
- loaded plugin
- generated workspace artifacts
