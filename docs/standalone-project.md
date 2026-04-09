# memory-lancedb-pro Standalone Project Guide

> Updated: 2026-04-09  
> Scope: the standalone enhanced edition in this workspace

## Overview

This project packages the Dreaming-enhanced `memory-lancedb-pro` work into a standalone OpenClaw memory plugin project rather than a loose collection of local patches.

It keeps the original long-term memory capabilities:

- LanceDB-backed storage
- hybrid retrieval
- lifecycle scoring and tiering
- smart extraction
- reflection persistence and injection

And adds a Dreaming compatibility layer so `memory-lancedb-pro` can remain the active memory plugin while still producing Dreaming-compatible artifacts for OpenClaw.

## Project Shape

```text
memory-lancedb-pro/
├── index.ts
├── cli.ts
├── openclaw.plugin.json
├── package.json
├── src/
├── test/
├── docs/
└── README.md
```

This is enough structure to maintain the plugin as an independent repository.

## What This Project Owns

- OpenClaw memory plugin registration
- memory capture, retrieval, recall, and lifecycle maintenance
- Dreaming-compatible file generation:
  - `memory/.dreams/short-term-recall.json`
  - `memory/.dreams/phase-signals.json`
  - `DREAMS.md`
  - optional phase reports under `memory/dreaming/`

## Runtime Requirements

- OpenClaw host runtime
- Node.js
- plugin dependencies installed locally with `npm install`
- at least one embedding provider

If this directory was created by copying another plugin install, make sure dependencies are present before loading it through `plugins.load.paths`.

## OpenClaw Setup

Minimal setup:

```json
{
  "plugins": {
    "load": {
      "paths": ["/path/to/memory-lancedb-pro"]
    },
    "slots": {
      "memory": "memory-lancedb-pro"
    },
    "entries": {
      "memory-lancedb-pro": {
        "enabled": true,
        "config": {
          "embedding": {
            "provider": "openai-compatible",
            "apiKey": "${OPENAI_API_KEY}",
            "model": "text-embedding-3-small"
          },
          "autoCapture": true,
          "autoRecall": true,
          "smartExtraction": true,
          "dreaming": {
            "enabled": true,
            "frequency": "0 3 * * *"
          }
        }
      }
    }
  }
}
```

Then validate and restart:

```bash
openclaw config validate
openclaw gateway restart
openclaw plugins info memory-lancedb-pro
```

## Validation Targets

At minimum, treat these as acceptance criteria:

- plugin loads successfully
- core memory write/retrieve flow works
- Dreaming config is accepted under `plugins.entries.memory-lancedb-pro.config`
- the following files exist in the workspace:
  - `DREAMS.md`
  - `memory/.dreams/short-term-recall.json`
  - `memory/.dreams/phase-signals.json`

Recommended checks:

```bash
node --test test/dreaming-compatibility.test.mjs
node --test test/config-session-strategy-migration.test.mjs
node test/plugin-manifest-regression.mjs
```

## Recommended Reading

- [README.md](../README.md)
- [Dreaming Compatibility Design](./dreaming-compatibility.md)
- [Memory Architecture Analysis](./memory_architecture_analysis.md)
- [OpenClaw Integration Playbook](./openclaw-integration-playbook.md)
