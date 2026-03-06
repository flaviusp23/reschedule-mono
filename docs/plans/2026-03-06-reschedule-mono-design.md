# Reschedule Mono — Design Document

> Date: 2026-03-06
> Status: Approved
> Repos: https://github.com/flaviusp23/reschedule-mono

## Overview

Parent monorepo that ties together the engine and UI as git submodules, with a justfile for common operations.

## Repository Map

| Repo | URL | Role | Submodule folder |
|------|-----|------|-----------------|
| reschedule-mono | https://github.com/flaviusp23/reschedule-mono | Parent monorepo | (root) |
| Reschedule-Flow | https://github.com/flaviusp23/Reschedule-Flow | Settlement engine | `Reschedule-Flow/` |
| reschedule-ui | https://github.com/flaviusp23/reschedule-ui | Demo UI | `reschedule-ui/` |

## Directory Structure

```
reschedule-mono/
├── Reschedule-Flow/              ← git submodule (engine)
│   ├── src/
│   ├── data/scenarios/
│   ├── tests/
│   ├── package.json
│   └── tsconfig.json
├── reschedule-ui/                ← git submodule (UI)
│   ├── src/
│   │   ├── components/
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   ├── vite.config.ts
│   └── tailwind.config.ts
├── justfile
├── .gitmodules
└── README.md
```

## Submodule Setup Commands

```bash
# Initialize the mono repo
git init reschedule-mono
cd reschedule-mono

# Add submodules
git submodule add https://github.com/flaviusp23/Reschedule-Flow.git Reschedule-Flow
git submodule add https://github.com/flaviusp23/reschedule-ui.git reschedule-ui
```

## .gitmodules

```ini
[submodule "Reschedule-Flow"]
    path = Reschedule-Flow
    url = https://github.com/flaviusp23/Reschedule-Flow.git

[submodule "reschedule-ui"]
    path = reschedule-ui
    url = https://github.com/flaviusp23/reschedule-ui.git
```

## Justfile

```just
# reschedule-mono justfile

# Pull all submodules to latest
pull:
    git submodule update --remote --merge

# Install dependencies in both submodules
install:
    cd Reschedule-Flow && pnpm install
    cd reschedule-ui && pnpm install

# Start the UI dev server
dev:
    cd reschedule-ui && pnpm dev

# Run tests across both submodules
test:
    cd Reschedule-Flow && pnpm test
    cd reschedule-ui && pnpm test

# Build both projects
build:
    cd Reschedule-Flow && pnpm build
    cd reschedule-ui && pnpm build

# Typecheck both projects
typecheck:
    cd Reschedule-Flow && pnpm typecheck
    cd reschedule-ui && pnpm typecheck

# Show git status of all submodules
status:
    @echo "── Reschedule-Flow ──"
    @cd Reschedule-Flow && git status --short
    @echo ""
    @echo "── reschedule-ui ──"
    @cd reschedule-ui && git status --short

# Run the CLI scenario runner
demo:
    cd Reschedule-Flow && pnpm dev
```

## UI ↔ Engine Link

The UI references the engine as a local dependency (no HTTP layer):

```json
// reschedule-ui/package.json
{
  "dependencies": {
    "reschedule-flow": "link:../Reschedule-Flow"
  }
}
```

Vite resolves TypeScript source directly — no engine build step needed during UI development.

## Developer Setup

```bash
git clone --recurse-submodules https://github.com/flaviusp23/reschedule-mono.git
cd reschedule-mono
just install
just dev
```
