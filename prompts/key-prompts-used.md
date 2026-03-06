# Key AI Prompts Used — Selected Highlights

This document captures the most impactful prompts from the project, showing the reasoning behind each one. These aren't all the prompts — just the ones that shaped major decisions or caught real issues.

---

## 1. Requirements-First Exploration

> **"Analyze the requirements. I want to understand the domain, the flow, the constraints — then we plan a design and break it into phases."**

**Impact:** Established the domain model (Settlement Tasks, Channels, Trade Orders), identified operating hours math as the hardest subproblem, and produced a phased plan — all before writing a single line of code. This prevented the most common mistake: jumping into code and discovering misunderstood requirements halfway through.

---

## 2. Decision-Driven Algorithm Selection

> **"Explain all algorithm options with trade-offs, so I can understand each approach before we commit."**
>
> **"Now validate against requirements — make sure the approach covers all the constraints and edge cases."**

**Impact:** Instead of accepting the first recommendation, I explored three approaches (Greedy + Topological Sort, Constraint Propagation, Event Simulation) with full trade-off analysis. Pressure-tested the choice against the constraint set: dependencies, channel exclusivity, operating hours, blackouts. Confirmed Kahn's algorithm covers DAG ordering, cycle detection, and deterministic tiebreaking natively.

---

## 3. Tech Stack Validated With External Research

> **"Search on web, research deeply and make sure this is a good stack. Also search for forums, plans, system designs."**

**Impact:** Didn't trust AI training data alone. Web research confirmed: Vitest 10-20x faster than Jest in watch mode, pnpm strict dependency resolution, and — critically — Luxon is the only date library with `Interval.difference()`, the exact primitive needed for blackout window subtraction. This single API saved 200+ lines of manual interval math.

---

## 4. Architecture for Production — Event-Driven + Pure Core

> **"I want a hybrid approach: a pure stateless engine at the core, with an event-driven layer on top for disruption handling. Clean separation — the engine knows nothing about events."**

**Impact:** This drove the three-layer architecture: pure stateless engine (core algorithm) + event handler (disruption translation via `structuredClone`) + service facade (public API with DTO conversion). Each layer is independently testable, the core is deterministic and side-effect-free, and the event layer demonstrates domain-driven design with immutability guarantees.

---

## 5. Agent-Based Code Review After Every Phase

> **"Run the code-reviewer and silent-failure-hunter agents on this phase. Also run type-design-analyzer on the new types. Flag anything above medium confidence."**

**Impact:** After every implementation phase (which may span multiple prompts), I dispatch specialized review agents through the AI's plugin system. These agents — code-reviewer, silent-failure-hunter, type-design-analyzer, code-simplifier — run independently with no conversation context. They see the code as a fresh reviewer would. This is the heavyweight review: it catches bugs, silent failures, type design issues, and over-engineering at the phase boundary before they compound into the next phase. Multiple agents running in parallel means different lenses on the same code.

---

## 6. Git Diff Self-Verification Every 1-3 Prompts

> **"Run git diff. Review what you just wrote against the plan. Any drift? Any regressions? Anything missing?"**

**Impact:** Separately from the phase-level agent reviews, I run this lighter-weight check every 1-3 prompts during implementation. The AI reviews its own `git diff` output — the actual changes on disk, not its memory of what it thinks it wrote. This catches small issues in real time: accidental deletions, scope creep, forgotten edge cases, off-by-one errors in the implementation vs. the plan. The diff is the source of truth. I don't let the AI self-assess from memory — I make it read its own output and verify.

---

## 7. Full Spec Compliance Audit

> **"Explore the whole codebase and make sure we have implemented exactly as in the requirements."**

**Impact:** The highest-value review prompt. The AI cross-referenced every source file, test file, and scenario against every requirement in the spec. Produced a structured compliance matrix that caught two actionable gaps: unused metrics types that signaled incomplete work (removed), and missing prompt documentation (created). A 10-minute audit that replaced an hour of manual spec re-reading.

---

## 8. Refactor Pass — Simplify Before Shipping

> **"Review the changed code for reuse, quality, and efficiency. Simplify anything over-engineered. Only keep what's needed."**

**Impact:** After all phases pass and tests are green, I run a dedicated refactor pass over the entire codebase. This is where I look at the finished product holistically — not phase by phase. Common outcomes: extracting duplicated logic, removing speculative abstractions with only one caller, tightening types, and eliminating dead code. For this project, the refactor pass removed 4 unused interfaces and 2 dead converter functions (~30 lines) that the compliance audit had flagged. The goal: ship the simplest code that satisfies all requirements, nothing more.

---

## 9. Edge Case Stress Testing

> **"Ultrathink of edge cases. I want more sample data. I want a bigger test, scenarios — and after we make sure all of them work we will focus on CI/CD."**

**Impact:** This prompt produced 9 adversarial scenarios that stress-tested the engine in ways the original 5 couldn't. Each scenario isolates a specific complexity: DST spring-forward crossing a weekend (scenario 06), diamond DAG with parallel cross-channel branches (08), 8-task dense packing that fills an entire day and rolls over (12), consecutive blackout windows (13), and mid-schedule channel offline injection (14). The key insight: the engine passed all 146 existing tests, but these new scenarios revealed that the algorithm had never been tested with a task start landing exactly at a blackout boundary — which led directly to discovering the Constraint 3b bug.

---

## 10. Hard Requirements Line-by-Line Audit

> **"Do we still match the hard requirements? Every hard requirement is implemented and truly respected?"**
>
> *(followed by the full list of 7 constraints from the spec)*

**Impact:** The highest-severity bug in the project was found not by a test, not by a reviewer, but by this prompt. I pasted the exact constraint list from the spec and asked the AI to trace each one to its enforcement code with line numbers. Six of seven mapped cleanly. The seventh — "No processing during maintenance/blackout windows" — revealed a gap: when a dependency ends exactly at a blackout start (e.g., dep ends 10:00, blackout [10:00, 11:00)), the engine set `startDate = 10:00` without pushing past the blackout. `calculateEndDate` would skip the blackout during work computation, but the recorded start sat inside it. The fix (Constraint 3b) was 20 lines. The lesson: **audit against the original spec text, not against your tests** — tests only catch what you thought to test.

---

## 11. Multi-Agent Review Blast

> **"Now I want you to use ALL code review power — @code-reviewer, @silent-failure-hunter, @code-explorer — TO CATCH ALL ISSUES LIKE THIS."**

**Impact:** After the blackout-at-start bug shook confidence, I dispatched 5 specialized review agents in parallel for maximum coverage. Each agent sees the code independently with no conversation bias. The results were categorized by severity: 1 Critical (re-check loop also missing blackout push — C1), 5 Important (wrong dependency blame in zero-duration tasks, missing duplicate ID validation, silent invalid-interval returns, lossy reason deduplication, no operating-hours range checks). All 6 issues fixed in one pass with 8 new regression tests. The multi-agent approach works because different agents have different focus areas — what one misses, another catches.

---

## 12. Decisive Dead Code Removal

> **"Remove the unused metrics types. They're not needed — I don't want dead code in the submission."**

**Impact:** When the compliance audit surfaced unused `ReflowMetrics` and `SLABreach` types, the decision was immediate: delete them. Dead code that suggests incomplete work is worse than no code — it tells reviewers "this was planned but not finished." All tests still green after removal.

---

## Pattern Summary

| Phase | Key Prompt Pattern | Outcome |
|---|---|---|
| **Understand** | "Analyze requirements. Explain the domain first." | Domain model + risk identification |
| **Decide** | "Show all options with trade-offs. Validate against constraints." | Algorithm choice with evidence |
| **Validate** | "Search the web. Is this production-ready?" | Stack confirmed with current data |
| **Design** | "Pure core + event layer. Clean separation of concerns." | Three-layer architecture |
| **Agent Review** | "Run code-reviewer, silent-failure-hunter on this phase." | Independent multi-agent review after each phase |
| **Diff Check** | "Git diff. Verify your own changes against the plan." | Lightweight self-verification every 1-3 prompts |
| **Refactor** | "Simplify. Remove over-engineering. Only what's needed." | Post-implementation cleanup pass |
| **Audit** | "Audit the whole codebase against the spec." | Compliance matrix, gaps identified |
| **Edge Cases** | "Ultrathink edge cases. More sample data, bigger tests." | 9 adversarial scenarios, revealed Constraint 3b bug |
| **Hard Req Audit** | "Do we match every hard requirement? Line by line." | Found critical blackout-at-start gap in 7th constraint |
| **Agent Blast** | "Use ALL review agents. Catch everything like this." | 5 parallel agents → 6 issues found and fixed in one pass |
| **Clean** | "Remove it. I don't need dead code." | Clean submission, no loose ends |
