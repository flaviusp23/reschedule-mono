# Scenario Runner Output

All 14 scenarios executed via `pnpm dev` (or `npx tsx src/main.ts`).

```
Settlement Schedule Reflow — Scenario Runner
Loading scenarios from: Reschedule-Flow/data/scenarios

======================================================================
Scenario: Delay Cascade
  Task A delayed by 2 hours pushes dependent B, which pushes dependent C
  Event: taskDelayed (T-001)
======================================================================
  Tasks: 3
  3 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-001 | WIRE-001 | 2026-03-02T17:00:00+02:00 | 2026-03-02T17:00:00+02:00 | 0           |
  T-002 | WIRE-002 | 2026-03-02T16:00:00+02:00 | 2026-03-02T18:00:00+02:00 | 120         | dep:T-001
  T-003 | WIRE-003 | 2026-03-02T17:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 120         | dep:T-002


======================================================================
Scenario: Blackout Window
  Channel goes offline 10AM-12PM, tasks must skip the blackout period
  Event: channelOffline
======================================================================
  Tasks: 2
  2 task(s) rescheduled due to constraint violations.

  Task  | Ref    | Original Start            | New Start                 | Delay (min) | Reasons
  ------+--------+---------------------------+---------------------------+-------------+----------
  T-010 | FX-010 | 2026-03-02T16:00:00+02:00 | 2026-03-02T16:00:00+02:00 | 0           | blackout
  T-011 | FX-011 | 2026-03-02T18:00:00+02:00 | 2026-03-02T13:00:00-05:00 | 120         | dep:T-010


======================================================================
Scenario: Multi-Constraint
  Cross-channel dependency cascade after a task delay — T-020 (CH-001) → T-021 (CH-002) → T-022 (CH-001)
  Event: taskDelayed (T-020)
======================================================================
  Tasks: 3
  3 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-020 | WIRE-020 | 2026-03-02T18:00:00+02:00 | 2026-03-02T18:00:00+02:00 | 0           |
  T-021 | FX-021   | 2026-03-02T17:00:00+02:00 | 2026-03-02T20:00:00+02:00 | 180         | dep:T-020
  T-022 | WIRE-022 | 2026-03-02T17:00:00+02:00 | 2026-03-02T21:00:00+02:00 | 240         | dep:T-021


======================================================================
Scenario: Channel Conflict
  Three independent tasks compete for the same channel time slot after a delay
  Event: taskDelayed (T-030)
======================================================================
  Tasks: 3
  3 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+---------------
  T-030 | WIRE-030 | 2026-03-02T17:00:00+02:00 | 2026-03-02T17:00:00+02:00 | 0           |
  T-031 | WIRE-031 | 2026-03-02T17:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 120         | conflict:T-030
  T-032 | WIRE-032 | 2026-03-02T19:00:00+02:00 | 2026-03-02T21:00:00+02:00 | 120         | conflict:T-031


======================================================================
Scenario: Impossible Schedule
  Regulatory hold overlaps a blackout window, making the schedule impossible
======================================================================
  ERROR [IMPOSSIBLE_SCHEDULE]: Cannot schedule task T-040: Regulatory hold overlaps blackout window (Emergency system maintenance)


======================================================================
Scenario: Weekend Rollover + DST
  Friday delay cascades over the weekend (with DST spring-forward on Mar 8) to Monday
  Event: taskDelayed (T-050)
======================================================================
  Tasks: 3
  3 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-050 | WIRE-050 | 2026-03-06T21:00:00+02:00 | 2026-03-06T21:00:00+02:00 | 0           |
  T-051 | WIRE-051 | 2026-03-06T16:00:00+02:00 | 2026-03-06T22:00:00+02:00 | 360         | dep:T-050
  T-052 | WIRE-052 | 2026-03-06T18:00:00+02:00 | 2026-03-09T09:00:00-04:00 | 4140        | dep:T-051


======================================================================
Scenario: Regulatory Hold Routing
  A regulatory hold locks 10AM-12PM on CH-001; a 4-hour task must route around it
======================================================================
  Tasks: 2
  1 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+---------------
  T-061 | WIRE-061 | 2026-03-02T15:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 240         | conflict:T-060


======================================================================
Scenario: Diamond Dependency
  DAG diamond: T-070 -> T-071 (CH-002) + T-072 (CH-001) -> T-073 (CH-002). Delay at root fans out and reconverges.
  Event: taskDelayed (T-070)
======================================================================
  Tasks: 4
  4 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-070 | WIRE-070 | 2026-03-02T17:00:00+02:00 | 2026-03-02T17:00:00+02:00 | 0           |
  T-071 | FX-071   | 2026-03-02T16:00:00+02:00 | 2026-03-02T18:00:00+02:00 | 120         | dep:T-070
  T-072 | WIRE-072 | 2026-03-02T16:00:00+02:00 | 2026-03-02T18:00:00+02:00 | 120         | dep:T-070
  T-073 | FX-073   | 2026-03-02T17:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 120         | dep:T-071


======================================================================
Scenario: Prep Time
  Tasks with prepTimeMinutes that extend total work: 60+60=120min, 30+30=60min, then 60min plain
  Event: taskDelayed (T-080)
======================================================================
  Tasks: 3
  3 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-080 | WIRE-080 | 2026-03-02T17:00:00+02:00 | 2026-03-02T17:00:00+02:00 | 0           |
  T-081 | WIRE-081 | 2026-03-02T17:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 120         | dep:T-080
  T-082 | WIRE-082 | 2026-03-02T18:00:00+02:00 | 2026-03-02T20:00:00+02:00 | 120         | dep:T-081


======================================================================
Scenario: Zero-Duration Milestone
  T-091 is a 0-minute checkpoint between T-090 and T-092 — sync point that takes no channel time
  Event: taskDelayed (T-090)
======================================================================
  Tasks: 3
  3 task(s) rescheduled due to constraint violations.

  Task  | Ref       | Original Start            | New Start                 | Delay (min) | Reasons
  ------+-----------+---------------------------+---------------------------+-------------+----------
  T-090 | WIRE-090  | 2026-03-02T18:00:00+02:00 | 2026-03-02T18:00:00+02:00 | 0           |
  T-091 | CHKPT-091 | 2026-03-02T16:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 180         | dep:T-090
  T-092 | WIRE-092  | 2026-03-02T16:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 180         | dep:T-091


======================================================================
Scenario: Multi-Channel Parallel
  T-100 (CH-001) and T-101 (CH-002) run in parallel; T-102 (CH-001) waits for both. Delay to T-101 pulls T-102 forward.
  Event: taskDelayed (T-101)
======================================================================
  Tasks: 3
  2 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-101 | FX-101   | 2026-03-02T19:00:00+02:00 | 2026-03-02T19:00:00+02:00 | 0           |
  T-102 | WIRE-102 | 2026-03-02T17:00:00+02:00 | 2026-03-02T21:00:00+02:00 | 240         | dep:T-101


======================================================================
Scenario: Dense Packing
  8 tasks fill a full Friday (8AM-4PM). A 1-hour delay causes the last task to roll over the weekend (+ DST) to Monday.
  Event: taskDelayed (T-110)
======================================================================
  Tasks: 8
  8 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+---------------------------
  T-110 | WIRE-110 | 2026-03-06T16:00:00+02:00 | 2026-03-06T16:00:00+02:00 | 0           |
  T-111 | WIRE-111 | 2026-03-06T16:00:00+02:00 | 2026-03-06T17:00:00+02:00 | 60          | dep:T-110
  T-112 | WIRE-112 | 2026-03-06T17:00:00+02:00 | 2026-03-06T18:00:00+02:00 | 60          | dep:T-111
  T-113 | WIRE-113 | 2026-03-06T18:00:00+02:00 | 2026-03-06T19:00:00+02:00 | 60          | dep:T-112
  T-114 | WIRE-114 | 2026-03-06T19:00:00+02:00 | 2026-03-06T20:00:00+02:00 | 60          | dep:T-113
  T-115 | WIRE-115 | 2026-03-06T20:00:00+02:00 | 2026-03-06T21:00:00+02:00 | 60          | dep:T-114
  T-116 | WIRE-116 | 2026-03-06T21:00:00+02:00 | 2026-03-06T22:00:00+02:00 | 60          | dep:T-115
  T-117 | WIRE-117 | 2026-03-06T22:00:00+02:00 | 2026-03-09T08:00:00-04:00 | 3840        | dep:T-116, operating-hours


======================================================================
Scenario: Multiple Blackouts
  Two pre-existing blackouts (10-11AM, 2-3PM) fragment Monday. A 360-minute task must span both gaps, filling all available time.
======================================================================
  Tasks: 2
  2 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+---------------------------
  T-120 | WIRE-120 | 2026-03-02T15:00:00+02:00 | 2026-03-02T15:00:00+02:00 | 0           | blackout
  T-121 | WIRE-121 | 2026-03-02T21:00:00+02:00 | 2026-03-03T08:00:00-05:00 | 1080        | dep:T-120, operating-hours


======================================================================
Scenario: Channel Offline Mid-Schedule
  channelOffline event injects an 11AM-12PM blackout. T-131 (120min starting 10AM) must span around it.
  Event: channelOffline
======================================================================
  Tasks: 3
  2 task(s) rescheduled due to constraint violations.

  Task  | Ref      | Original Start            | New Start                 | Delay (min) | Reasons
  ------+----------+---------------------------+---------------------------+-------------+----------
  T-131 | WIRE-131 | 2026-03-02T17:00:00+02:00 | 2026-03-02T17:00:00+02:00 | 0           | blackout
  T-132 | WIRE-132 | 2026-03-02T19:00:00+02:00 | 2026-03-02T13:00:00-05:00 | 60          | dep:T-131

Done.
```

**All 14 scenarios passed.** 204 tests confirmed via `pnpm test`.

| # | Scenario | Constraints Exercised | Result |
|---|---|---|---|
| 01 | Delay Cascade | Dependencies | 3 tasks rescheduled |
| 02 | Blackout Window | Blackout + pause/resume | 2 tasks rescheduled |
| 03 | Multi-Constraint | Cross-channel dependencies | 3 tasks rescheduled |
| 04 | Channel Conflict | Channel exclusivity | 3 tasks rescheduled |
| 05 | Impossible Schedule | Hold overlaps blackout | ERROR (correct) |
| 06 | Weekend Rollover + DST | Weekend skip + DST | 3 tasks rescheduled |
| 07 | Regulatory Hold Routing | Immovable hold routing | 1 task rescheduled |
| 08 | Diamond Dependency | DAG diamond fan-out/in | 4 tasks rescheduled |
| 09 | Prep Time | prepTimeMinutes | 3 tasks rescheduled |
| 10 | Zero-Duration Milestone | 0-min checkpoint | 3 tasks rescheduled |
| 11 | Multi-Channel Parallel | Parallel branches, join | 2 tasks rescheduled |
| 12 | Dense Packing | Full-day + weekend + DST | 8 tasks rescheduled |
| 13 | Multiple Blackouts | Fragmented day, pause/resume | 2 tasks rescheduled |
| 14 | Channel Offline Mid-Schedule | Injected blackout, pause/resume | 2 tasks rescheduled |
