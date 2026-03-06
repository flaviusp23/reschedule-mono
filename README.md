# Settlement Schedule Reflow Engine

A deterministic scheduling engine that reschedules financial settlement tasks when disruptions occur — delayed trades, counterparty failures, channel outages, regulatory holds — while respecting dependency ordering, channel exclusivity, operating hours, and blackout windows.

Built for [Capital33](https://github.com/flaviusp23)'s financial operations platform.

> **Monorepo structure** — This repository ties together the [engine](https://github.com/flaviusp23/Reschedule-Flow) and [demo UI](https://github.com/flaviusp23/reschedule-ui) as git submodules.
>
> **Note:** The UI is a **demo/playground only** — built to visualize and test the engine interactively. It is not production-ready and not intended for end-user deployment.

---

## Table of Contents

- [Problem Statement](#problem-statement)
- [Architecture](#architecture)
- [Core Algorithm](#core-algorithm)
- [Domain Model](#domain-model)
- [Error Handling](#error-handling)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Testing](#testing)
- [Scenarios](#scenarios)
- [Design Decisions](#design-decisions)
- [Known Limitations](#known-limitations)
- [Tech Stack](#tech-stack)

---

## Problem Statement

In financial settlement workflows, tasks execute across specific channels (e.g., Domestic Wire, FX Settlement) with strict time windows and ordering constraints. When a disruption occurs — a trade confirmation is delayed, a channel goes offline, or a regulatory review is imposed — the entire downstream schedule must be recomputed.

This engine solves that problem: given a set of settlement tasks, their dependency graph, channel assignments, and a disruption event, it produces a new conflict-free schedule in a single deterministic pass.

### What It Handles

| Constraint | Description |
|---|---|
| **Dependencies** | Task B cannot start until Task A completes (DAG ordering) |
| **Channel Exclusivity** | Only one task occupies a channel at any given time |
| **Operating Hours** | Channels operate on defined weekday windows (e.g., Mon-Fri 8AM-4PM ET) |
| **Blackout Windows** | Channels may have periods where no work can execute |
| **Regulatory Holds** | Immovable tasks that cannot be rescheduled — other tasks route around them |

### Disruption Events

| Event | Effect |
|---|---|
| `taskDelayed` | Moves a task's start time forward, cascading to dependents |
| `channelOffline` | Injects a blackout window on a channel |
| `regulatoryHold` | Marks a task as immovable (frozen in place) |

---

## Architecture

```
                    +--------------------------+
                    |     ReflowService        |  Service Facade
                    |  reflow() | handleDisr() |
                    +------+--------+----------+
                           |        |
                  +--------+        +----------+
                  |                             |
         +--------v--------+          +--------v--------+
         |   Converters     |          |  Event Handler  |
         | toDomain()/toDTO |          | applyDisruption |
         +--------+---------+          +--------+--------+
                  |                             |
                  +-------------+---------------+
                                |
                       +--------v--------+
                       |  Reflow Engine  |  Pure, Stateless
                       |    reflow()     |
                       +---+----+----+---+
                           |    |    |
              +------------+    |    +------------+
              |                 |                  |
     +--------v-----+  +-------v--------+  +------v-----------+
     | DAG (Kahn's  |  | Constraint     |  | Operating Hours  |
     | Topo Sort)   |  | Checker        |  | Engine           |
     +--------------+  | (Maker-Checker)|  | (Cursor-based)   |
                       +----------------+  +------------------+
```

### Three-Layer Design

1. **Service Facade** (`ReflowService`) — Public API. Accepts DTOs with ISO 8601 strings, returns DTOs. Orchestrates event handling and engine invocation.

2. **Event Handler** (`applyDisruption`) — Translates disruption events into mutated input DTOs using `structuredClone` for immutability. The caller's data is never modified.

3. **Reflow Engine** (`reflow`) — Pure, stateless, deterministic function. Accepts domain objects with Luxon `DateTime` values. Performs topological sort, locks regulatory holds, runs greedy placement, and validates output via an independent constraint checker.

### Data Flow

```
ReflowInputDTO          DisruptionEvent
(ISO strings)           (external input)
      |                       |
      |     applyDisruption() |  (structuredClone + mutate)
      |         +-------------+
      |         |
      v         v
  Mutated ReflowInputDTO
      |
      | toDomain()  (parse ISO -> Luxon DateTime, validate offsets + timezones)
      v
  ReflowInput (domain objects)
      |
      | reflow()  (topo sort -> lock holds -> greedy placement -> validate)
      v
  ReflowResult (domain objects)
      |
      | toDTO()  (serialize DateTime -> ISO strings)
      v
  ReflowResultDTO
```

---

## Core Algorithm

The engine executes in five phases:

### Phase 1: Input Validation

Checks for negative durations, unknown channel references, self-dependencies, unknown dependency references, and invalid timezone identifiers.

### Phase 2: Topological Sort (Kahn's Algorithm)

Builds a DAG from task dependencies and produces a deterministic processing order using Kahn's algorithm with a priority queue.

**Tiebreaker guarantee**: when multiple tasks have zero in-degree simultaneously, they are ordered by `(startDate ASC, docId ASC)`. This ensures identical input always produces identical output regardless of object insertion order.

**Cycle detection**: if the sorted result contains fewer tasks than the input, the remaining tasks form a cycle. A `CyclicDependencyError` is thrown with the IDs of all nodes in the cycle.

### Phase 3: Lock Regulatory Holds

All tasks marked `isRegulatoryHold: true` are processed first (in topological order). Their time slots are locked into the channel occupancy map as immovable intervals. Validation is strict:

- Hold must start within operating hours
- Hold must end within operating hours (or at the exact boundary, e.g., 4:00 PM on a [8,16) window)
- Hold must not overlap any blackout window
- Hold must not overlap another hold on the same channel
- All hold dependencies must already be resolved

Any violation throws `ImpossibleScheduleError` — the engine does not attempt to solve around invalid holds.

### Phase 4: Greedy Placement

Non-hold tasks are placed in topological order. For each task:

1. **Dependency constraint** — Start time is pushed to `max(originalStart, max(dependency.endDate))`.
2. **Channel conflict check** — If the proposed interval overlaps an existing slot, start is pushed past the conflicting slot's end.
3. **Operating hours snap** — If the start falls outside operating hours, it is snapped forward to the next available window.
4. **Convergence loop** — The end date is computed via `calculateEndDate` (which respects blackouts), then re-checked for channel conflicts. If a conflict is found (e.g., blackout avoidance pushed the end into a locked hold), the start is pushed forward and the loop repeats. Maximum 100 iterations with a hard error if exceeded.
5. **Blackout detection** — After convergence, the engine compares the actual end date against what it would be without blackouts. If they differ, a `blackout` reason is recorded.

**Zero-duration tasks** (milestones/checkpoints) skip channel occupancy entirely. They respect dependency ordering but consume no channel time. Their start and end dates are set to the same value.

### Phase 5: Post-Reflow Validation (Maker-Checker)

An independent `validateSchedule` function re-checks the entire output from first principles:

- Every task starts within its channel's operating hours
- No task starts inside a blackout window
- All dependencies are satisfied (predecessor ends before successor starts)
- No two tasks on the same channel have overlapping intervals

This is a safety net — if a bug in the placement algorithm produces an invalid schedule, the validator catches it and throws `ConstraintViolationError` rather than returning silently wrong results.

---

## Domain Model

The type system has two parallel layers: **DTOs** (I/O boundary, ISO 8601 strings) and **Domain** (internal, Luxon DateTime).

### Settlement Task

| Field | DTO Type | Domain Type | Description |
|---|---|---|---|
| `docId` | `string` | `string` | Unique task identifier |
| `taskReference` | `string` | `string` | Human-readable reference (e.g., `WIRE-001`) |
| `tradeOrderId` | `string` | `string` | Foreign key to trade order |
| `settlementChannelId` | `string` | `string` | Foreign key to settlement channel |
| `startDate` | `string` (ISO) | `DateTime` | Scheduled start time |
| `endDate` | `string` (ISO) | `DateTime` | Scheduled end time |
| `durationMinutes` | `number` | `number` | Work duration (>= 0) |
| `prepTimeMinutes` | `number?` | `number?` | Optional preparation time, added to duration |
| `isRegulatoryHold` | `boolean` | `boolean` | If true, task is immovable |
| `dependsOnTaskIds` | `string[]` | `string[]` | Prerequisite task IDs (DAG edges) |
| `taskType` | `SettlementTaskType` | `SettlementTaskType` | Spec-defined union (`marginCheck`, `fundTransfer`, `disbursement`, `complianceScreen`, `reconciliation`, `regulatoryHold`) + extensible via `string & {}` |

### Settlement Channel

| Field | DTO Type | Domain Type | Description |
|---|---|---|---|
| `docId` | `string` | `string` | Unique channel identifier |
| `name` | `string` | `string` | Display name (e.g., `Domestic Wire`) |
| `timezone` | `string` | `string` | IANA timezone (e.g., `America/New_York`) |
| `operatingHours` | `OperatingHourEntryDTO[]` | `OperatingHourEntry[]` | Per-weekday operating windows |
| `blackoutWindows` | `BlackoutWindowDTO[]` | `BlackoutWindow[]` | Periods of no activity |

**Operating Hour Entry**: `{ dayOfWeek: 0-6 (Sun-Sat), startHour, endHour }` — half-open interval `[startHour, endHour)`.

**Blackout Window**: `{ startDate, endDate, reason? }` — absolute time range where no work can execute.

### Disruption Event (Discriminated Union)

```typescript
type DisruptionEvent =
  | { type: 'taskDelayed';    taskId: string; newStartDate: string; reason?: string }
  | { type: 'channelOffline'; channelId: string; startDate: string; endDate: string; reason?: string }
  | { type: 'regulatoryHold'; taskId: string; reason?: string };
```

### Change Reasons (Discriminated Union)

Each moved task includes one or more reasons explaining why it was rescheduled:

```typescript
type ChangeReason =
  | { type: 'dependency';      blockingTaskId: string }
  | { type: 'channelConflict'; conflictingTaskId: string }
  | { type: 'operatingHours';  nextWindowStart: DateTime }
  | { type: 'blackout';        blackoutEnd: DateTime };
```

### DTO Envelope Pattern

All DTOs use a `DocumentDTO<Type, Data>` wrapper matching a document-store record format:

```json
{
  "docId": "T-001",
  "docType": "settlementTask",
  "data": {
    "taskReference": "WIRE-001",
    "startDate": "2026-03-02T08:00:00-05:00",
    ...
  }
}
```

The `toDomain()` converter unwraps `data` into flat domain objects. The `toDTO()` converter re-wraps them.

---

## Error Handling

All errors extend `ReflowError` with a `code` field from the `ReflowErrorCode` enum.

| Error Class | Code | When Thrown |
|---|---|---|
| `InvalidInputError` | `INVALID_INPUT` | Bad ISO dates, missing UTC offsets, invalid timezones, negative durations, unknown references, self-dependencies, inverted operating windows |
| `CyclicDependencyError` | `CYCLIC_DEPENDENCY` | Dependency graph contains a cycle. Includes `cyclePath: string[]` |
| `ImpossibleScheduleError` | `IMPOSSIBLE_SCHEDULE` | Regulatory hold conflicts (overlaps blackout, outside hours, overlapping holds), placement loop exceeded 100 iterations, no operating window within 7 days, exceeded 365-day scheduling horizon |
| `ConstraintViolationError` | `CONSTRAINT_VIOLATION` | Post-reflow maker-checker detected an invalid schedule (engine bug safety net). Includes `violations: string[]` |

### Validation Layers

1. **DTO boundary** — `toDomain()` validates ISO parsing, UTC offset presence, timezone validity
2. **Event handler** — `applyDisruption()` validates event-specific fields (date formats, reference existence)
3. **Engine input** — `validateInput()` checks structural integrity (references, durations, self-deps)
4. **DAG** — `topologicalSort()` detects cycles
5. **Engine output** — `validateSchedule()` independently verifies the final schedule

---

## Project Structure

```
reschedule-mono/
├── Reschedule-Flow/              <-- git submodule (engine)
│   ├── src/
│   │   ├── domain/
│   │   │   ├── types.ts              # DTO + Domain type definitions
│   │   │   ├── converters.ts         # toDomain() / toDTO() + day-of-week conversion
│   │   │   └── errors.ts             # Error hierarchy (ReflowError base + 4 subclasses)
│   │   ├── engine/
│   │   │   ├── dag.ts                # buildDAG() + topologicalSort() (Kahn's algorithm)
│   │   │   ├── reflow-engine.ts      # reflow() — core scheduling algorithm
│   │   │   └── constraint-checker.ts # validateSchedule() — post-reflow maker-checker
│   │   ├── events/
│   │   │   └── event-handler.ts      # applyDisruption() — event-to-mutation translation
│   │   ├── scheduling/
│   │   │   └── reflow-service.ts     # ReflowService — public facade
│   │   ├── utils/
│   │   │   └── operating-hours.ts    # Operating hours engine (5 exported functions)
│   │   └── main.ts                   # CLI scenario runner
│   ├── tests/                        # 204 tests across 9 test files
│   ├── data/scenarios/               # 14 JSON scenario files
│   └── package.json
├── reschedule-ui/                <-- git submodule (demo UI only, not production)
├── docs/
├── .gitmodules
└── README.md
```

---

## Getting Started

### Prerequisites

- **Node.js** >= 18
- **pnpm** >= 10
- **just** >= 1.0 (`npm install -g just-install`)

### Clone & Run

```bash
git clone --recurse-submodules https://github.com/flaviusp23/reschedule-mono.git
cd reschedule-mono
just install      # install deps for engine (pnpm) + UI (npm)
just test         # run all 204 engine tests
just ui           # start demo UI at http://localhost:5173
```

### All Justfile Commands

| Command | Description |
|---|---|
| `just install` | Install dependencies in both submodules |
| `just test` | Run all 204 engine tests |
| `just ui` | Start the demo UI dev server |
| `just build` | Build both engine and UI |
| `just typecheck` | TypeScript strict-mode check on the engine |
| `just demo` | Run the CLI scenario runner |
| `just pull` | Pull all submodules to latest |
| `just status` | Show git status of all submodules |

### Manual Setup (Without Just)

```bash
# Engine
cd Reschedule-Flow
pnpm install
pnpm typecheck    # TypeScript strict mode — zero errors
pnpm test         # Run all 204 tests
pnpm dev          # Run CLI scenario runner
pnpm build        # Bundles to dist/ via tsup (ESM + .d.ts declarations)

# Demo UI
cd ../reschedule-ui
npm install
npm run dev       # Starts Vite dev server
```

---

## Usage

### Programmatic API

```typescript
import { ReflowService } from './scheduling/reflow-service';
import type { ReflowInputDTO, DisruptionEvent } from './domain/types';

const service = new ReflowService();

// Direct reflow (no disruption event)
const result = service.reflow(inputDTO);

// Handle a disruption event
const event: DisruptionEvent = {
  type: 'taskDelayed',
  taskId: 'T-001',
  newStartDate: '2026-03-02T10:00:00-05:00',
  reason: 'Delayed trade confirmation',
};
const result = service.handleDisruption(inputDTO, event);

// Result shape
console.log(result.reflowId);       // UUID
console.log(result.computedAt);     // ISO timestamp
console.log(result.updatedTasks);   // All tasks with updated times
console.log(result.changes);        // Only tasks that moved, with reasons
console.log(result.explanation);    // Human-readable summary
```

### Input Format

```json
{
  "settlementTasks": [
    {
      "docId": "T-001",
      "docType": "settlementTask",
      "data": {
        "taskReference": "WIRE-001",
        "tradeOrderId": "TO-001",
        "settlementChannelId": "CH-001",
        "startDate": "2026-03-02T08:00:00-05:00",
        "endDate": "2026-03-02T09:00:00-05:00",
        "durationMinutes": 60,
        "isRegulatoryHold": false,
        "dependsOnTaskIds": [],
        "taskType": "settlement"
      }
    }
  ],
  "settlementChannels": [
    {
      "docId": "CH-001",
      "docType": "settlementChannel",
      "data": {
        "name": "Domestic Wire",
        "timezone": "America/New_York",
        "operatingHours": [
          { "dayOfWeek": 1, "startHour": 8, "endHour": 16 },
          { "dayOfWeek": 2, "startHour": 8, "endHour": 16 },
          { "dayOfWeek": 3, "startHour": 8, "endHour": 16 },
          { "dayOfWeek": 4, "startHour": 8, "endHour": 16 },
          { "dayOfWeek": 5, "startHour": 8, "endHour": 16 }
        ],
        "blackoutWindows": []
      }
    }
  ],
  "tradeOrders": [
    {
      "docId": "TO-001",
      "docType": "tradeOrder",
      "data": {
        "tradeOrderNumber": "ORD-2026-001",
        "instrumentId": "AAPL",
        "quantity": 1000,
        "settlementDate": "2026-03-02T16:00:00-05:00"
      }
    }
  ]
}
```

### CLI Scenario Runner

```bash
pnpm dev                                              # Run all 14 scenarios
npx tsx src/main.ts 01-delay-cascade.json              # Run single scenario by filename
npx tsx src/main.ts data/scenarios/12-dense-packing.json  # Run by full path
```

Reads all `data/scenarios/*.json` files (or a specific file) and runs them through the engine, printing a formatted changes table:

```
======================================================================
Scenario: Delay Cascade
  Three-task chain where T-001 is delayed by 2 hours, cascading to T-002 and T-003
  Event: taskDelayed (T-001)
======================================================================
  Reflow ID: a1b2c3d4-...
  Tasks: 3
  Reflowed 3 tasks; 3 were rescheduled.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+--------
  T-001 | WIRE-001 | 2026-03-02T08:00:00-05:00 | 2026-03-02T10:00:00-05:00 | 120         |
  T-002 | WIRE-002 | 2026-03-02T09:00:00-05:00 | 2026-03-02T11:00:00-05:00 | 120         | dep:T-001
  T-003 | WIRE-003 | 2026-03-02T10:00:00-05:00 | 2026-03-02T12:00:00-05:00 | 120         | dep:T-002
```

---

## Testing

```bash
cd Reschedule-Flow
pnpm test              # Run all 204 tests
pnpm test:watch        # Interactive watch mode
pnpm test -- tests/engine/reflow-engine.test.ts   # Run specific file
```

### Test Coverage by Module

| Test File | Tests | What It Covers |
|---|---|---|
| `converters.test.ts` | 20 | DTO/domain round-trip, ISO parsing, UTC offset validation, timezone validation, day-of-week mapping |
| `dag.test.ts` | 12 | Linear chains, diamonds, independent tasks, cycle detection, self-dependency, determinism, tiebreaker ordering |
| `operating-hours.test.ts` | 35 | isWithinOperatingHours, snapToNextOperatingWindow, getAvailableSlots, calculateEndDate, DST handling, blackout avoidance, multi-day spanning |
| `reflow-engine.test.ts` | 36 | Dependency push, channel conflicts, operating hours snap, blackout avoidance, regulatory holds, cascades, multi-dep, impossible schedules, zero-duration tasks, prepTime, convergence, duplicate ID rejection, operating hours validation |
| `constraint-checker.test.ts` | 8 | Operating hours violations, overlap detection, dependency ordering, blackout violations, adjacent task allowance |
| `event-handler.test.ts` | 14 | All 3 event types, immutability (original not mutated), validation errors, idempotent hold marking |
| `reflow-service.test.ts` | 8 | Facade delegation, result structure, ISO string output, input immutability, error propagation |
| `scenarios.test.ts` | 64 | End-to-end integration through full DTO pipeline using real JSON scenario files (14 scenarios) |
| `edge-blackout-start.test.ts` | 7 | Edge cases: conflict→blackout push, blackout at exact task end, cascading through blackouts |

---

## Scenarios

Fourteen scenario files in `data/scenarios/` exercise different constraint combinations:

### 01 — Delay Cascade

Three tasks in a linear dependency chain (`T-001 -> T-002 -> T-003`), each 60 minutes on the same channel. T-001 is delayed from 8AM to 10AM. The delay cascades through the entire chain: T-002 moves to 11AM, T-003 to 12PM.

### 02 — Blackout Window

Two tasks on the FX Settlement channel. A `channelOffline` event injects a 10AM-12PM blackout. T-010 (120min, starts 9AM) works from 9-10AM, pauses during the blackout, then resumes at 12PM-1PM. T-011 (depends on T-010) is pushed to 1PM.

### 03 — Multi-Constraint (Cross-Channel)

Three tasks across two channels: `T-020 (CH-001) -> T-021 (CH-002) -> T-022 (CH-001)`. T-020 is delayed to 11AM. The dependency cascade crosses channel boundaries — T-021 starts at 1PM on a different channel, then T-022 starts at 2PM back on the original channel.

### 04 — Channel Conflict

Three independent tasks competing for the same channel. T-030 is delayed from 8AM to 10AM, creating a cascade of channel conflicts: T-031 is pushed to 12PM, T-032 to 2PM. No dependency relationships — pure channel exclusivity enforcement.

### 05 — Impossible Schedule

A 240-minute regulatory hold (10AM-2PM) on a channel with an 11AM-1PM blackout window. The hold overlaps the blackout and cannot be moved. The engine correctly throws `ImpossibleScheduleError` with code `IMPOSSIBLE_SCHEDULE`.

### 06 — Weekend Rollover + DST

Friday delay cascades over the weekend with DST spring-forward (March 8, 2026). T-050 delayed to 2PM Friday, T-051 spans Friday→Monday, T-052 lands Monday 9AM EDT (not EST).

### 07 — Regulatory Hold Routing

A regulatory hold locks 10AM-12PM. A 240-minute task starting at 8AM must route around it, landing at 12PM-4PM via channel conflict resolution.

### 08 — Diamond Dependency

DAG diamond: `T-070 → T-071 (CH-002) + T-072 (CH-001) → T-073 (CH-002)`. Root delayed to 10AM. Parallel branches run on different channels at 11AM. Join node waits for both at 12PM.

### 09 — Prep Time

Tasks with `prepTimeMinutes` that extend total work: 60+60=120min, 30+30=60min, then 60min plain. Validates prep time is included in scheduling math.

### 10 — Zero-Duration Milestone

A 0-minute checkpoint (T-091) between two real tasks. Milestone has `startDate === endDate`, consumes no channel time, but still respects dependency ordering.

### 11 — Multi-Channel Parallel

T-100 (CH-001) and T-101 (CH-002) run in parallel. T-102 depends on both. Only T-101 is delayed — T-100 is unchanged, T-102 waits for the slower branch.

### 12 — Dense Packing

8 tasks fill a full Friday 8AM-4PM in a linear chain. A 1-hour delay cascades through all 7 downstream tasks. The last task rolls over the weekend + DST to Monday 8AM EDT.

### 13 — Multiple Blackouts

Two pre-existing blackouts (10-11AM, 2-3PM) fragment Monday. A 360-minute task spans all available gaps: [8-10)+[11-14)+[15-16)=360min. Dependent task rolls to Tuesday.

### 14 — Channel Offline Mid-Schedule

`channelOffline` event injects an 11AM-12PM blackout. T-131 (120min starting 10AM) works 60min before the blackout, pauses, then resumes at 12PM. T-132 pushed to 1PM.

---

## Design Decisions

### Why Kahn's Algorithm (Not DFS Topological Sort)?

Kahn's algorithm naturally supports a priority queue for deterministic tiebreaking. When multiple tasks are ready simultaneously, the queue orders them by `(startDate ASC, docId ASC)`. DFS-based topological sort would require a post-sort step to achieve the same determinism. Kahn's also gives cycle detection for free: if the sorted output is shorter than the input, the remaining nodes form a cycle.

### Why Half-Open Intervals `[start, end)`?

Half-open intervals eliminate ambiguity at boundaries. A channel operating `[8:00, 16:00)` means 16:00 is the first moment *outside* the window. Two adjacent tasks — one ending at 11:00 and another starting at 11:00 — do not overlap. This matches Luxon's `Interval` semantics and prevents off-by-one errors throughout the scheduling logic.

### Why Maker-Checker Post-Validation?

The constraint checker is intentionally independent of the placement algorithm. It knows nothing about *how* tasks were scheduled — it only verifies the *result* against the original constraints. This means:

- A bug in the greedy placement algorithm cannot produce a silently invalid schedule
- The constraint specification lives in one authoritative place
- The checker can be used independently (e.g., to validate manually-created schedules)

### Why `structuredClone` in Event Handler?

Financial systems require non-destructive operations. Calling `handleDisruption` twice with the same input must produce the same result. `structuredClone` deep-copies the entire DTO tree before mutation, ensuring the caller's data is never modified. This is cheaper than implementing a full immutable data structure and sufficient for the batch-processing use case.

### Why Lock Regulatory Holds Before Placement?

Regulatory holds are legal constraints that cannot be negotiated. Processing them first and locking their slots into the occupancy map ensures the greedy placement algorithm never considers moving them. This is simpler and more correct than treating them as high-priority tasks within the same placement loop.

### Why a 365-Day Deadline?

The `calculateEndDate` cursor algorithm advances day-by-day through operating windows. Without a deadline, a channel with no operating hours (misconfiguration) would loop indefinitely. The 365-day limit provides a practical bound while being generous enough for real scheduling scenarios.

### Why Day-of-Week Conversion?

Luxon uses ISO 8601 weekdays (1=Monday, 7=Sunday). The system's public API uses a more common convention (0=Sunday, 6=Saturday). The `luxonDayToSpecDay`/`specDayToLuxonDay` functions in `converters.ts` bridge this gap at every comparison point. The conversion is `weekday % 7` (Luxon→spec) and `day === 0 ? 7 : day` (spec→Luxon).

### Why Require Explicit UTC Offsets?

All ISO 8601 date strings must include an explicit UTC offset (e.g., `-05:00` or `Z`). Bare local times like `2026-03-02T08:00:00` are rejected. This prevents timezone ambiguity — a critical concern in financial systems where settlement deadlines are legally binding to specific moments in time.

---

## Known Limitations

| Area | Limitation | Upgrade Path |
|---|---|---|
| **Channel concurrency** | Each channel processes one task at a time (serial). No support for parallel channel capacity. | Add a `maxConcurrency` field to `SettlementChannel` and modify `findOverlap` to track occupancy counts instead of simple intervals. |
| **Placement optimality** | The greedy algorithm places tasks in topological order. It does not backtrack or globally optimize. A later task may displace an earlier one more efficiently, but the engine won't find that solution. | Replace greedy placement with constraint programming (e.g., OR-Tools) or integer linear programming for optimal placement. |
| **Holiday calendars** | Operating hours are defined per day-of-week. There is no concept of holidays or one-off closures beyond explicit blackout windows. | Add a `holidays: string[]` (ISO dates) field to channels, treated as non-operating days. |
| **Persistence** | The engine is pure and stateless. It does not persist schedules or track history. | Wrap the service with a persistence layer (e.g., Firestore, PostgreSQL) that stores snapshots of each reflow result. |
| **Multi-timezone channels** | Each channel has a single timezone. Tasks cannot span timezone changes. | Support per-task timezone overrides or a `transferTimezone` field for cross-border settlements. |
| **Real-time events** | The engine processes one disruption at a time. There is no event queue or streaming interface. | Add an event bus (e.g., Kafka, Redis Streams) that feeds disruptions to the service and publishes reflow results. |

---

## Tech Stack

| Tool | Version | Purpose |
|---|---|---|
| **TypeScript** | ^5.9 | Language (strict mode, ESM) |
| **Node.js** | >= 18 | Runtime |
| **pnpm** | >= 10 | Package manager |
| **Luxon** | ^3.7 | DateTime arithmetic, timezone handling, interval operations |
| **Vitest** | 1.6.1 | Test runner |
| **tsx** | ^4.7 | Development runner (TypeScript execution without build) |
| **tsup** | ^8.5 | Production bundler (ESM + declarations) |

### Configuration Highlights

- **`"type": "module"`** — Pure ESM throughout. No CommonJS.
- **`"moduleResolution": "Bundler"`** — Modern resolution compatible with `tsup` and `tsx`.
- **`"strict": true`** — Full TypeScript strict mode. No `any` escape hatches.
- **`"isolatedModules": true`** — Each file is a standalone module. No global type declarations.

---

## Related Repositories

| Repository | Description |
|---|---|
| [Reschedule-Flow](https://github.com/flaviusp23/Reschedule-Flow) | The scheduling engine (this README documents it) |
| [reschedule-ui](https://github.com/flaviusp23/reschedule-ui) | Demo UI only — Gantt-style timeline visualization for testing the engine (not production-ready) |
| [reschedule-mono](https://github.com/flaviusp23/reschedule-mono) | Monorepo tying engine + UI together as submodules |

## License

ISC
