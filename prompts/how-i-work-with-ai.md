# How I Work With AI

## Overview

I treat AI as a **technical sparring partner**, not a code generator. The workflow has three distinct modes that map to different phases of a project:

1. **Architect mode** — I drive decisions one at a time. The AI presents options and trade-offs, I challenge recommendations, validate with external research, and commit only when satisfied.

2. **Implementation mode** — I provide the plan, the AI executes under my direction. Each phase produces a working, tested increment. I review output, run tests, and course-correct before proceeding.

3. **Review mode** — I use the AI as a tireless code reviewer. It searches for anti-patterns, audits spec compliance across every file, and surfaces gaps I might miss from being too close to the code. I make the decisions on what to fix, what to remove, and what to ship.

---

## Core Principles

### 1. Requirements First, Code Last

I never ask the AI to "build me X." The first prompt is always about understanding:

> "Analyze the requirements. I want to understand the domain, the flow, the constraints — then we plan."

Jumping to code without understanding requirements is the #1 cause of rework. AI is excellent at breaking down complex specs into digestible domain models and surfacing edge cases.

### 2. Decision-by-Decision, Not All-at-Once

I break complex architectural choices into isolated decisions. Each one gets its own exploration cycle: options, trade-offs, validation, commitment.

Compound decisions (choosing everything at once) lead to hidden coupling between choices. By isolating each decision, I can evaluate trade-offs clearly and change direction on one axis without affecting others.

### 3. Challenge Every Recommendation

I never accept the first answer:

> "Explain all options so I can understand perfectly."
> "Which approach is more production-ready?"
> "Search on web, research deeply and validate this stack."

AI models have biases toward certain patterns. By stress-testing recommendations, I get more thorough analysis than if I just accepted the initial suggestion.

### 4. Validate Against Production Standards

Every decision is validated against:
- **Spec requirements** — does it satisfy what's asked?
- **Production readiness** — would this hold up in a real system with real traffic?
- **Maintainability** — can someone else understand and extend this in 6 months?
- **Architectural soundness** — clean separation of concerns, proper error handling, testability?

### 5. External Validation Over Internal Knowledge

I don't trust the AI's training data alone for technology choices:

> "Search on web, research deeply."
> "Also search for forums, plans, system designs."

Tech ecosystems change fast. Current data beats training knowledge.

### 6. Agent-Based Code Review After Every Phase

I don't wait until the end to review. After every implementation phase completes (a phase may span multiple prompts), I dispatch specialized review agents through the AI's plugin and skill system:

- **code-reviewer agent** — audits the diff for bugs, logic errors, and style violations against project conventions
- **silent-failure-hunter agent** — scans for swallowed errors, empty catch blocks, and inappropriate fallback behavior
- **type-design-analyzer agent** — reviews any new types for proper encapsulation, invariant expression, and design quality
- **code-simplifier agent** — checks for over-engineering, unnecessary abstractions, and opportunities to reduce complexity

These agents run independently — they see the code, not the conversation. They have no context bias. If an agent flags something, I evaluate it and decide whether to fix or dismiss. This catches issues at the phase boundary, before they compound into the next phase.

### 7. Git Diff Self-Verification Every Few Prompts

Separately from the phase-level agent reviews, every 1-3 prompts I tell the AI to run `git diff` and review its own changes against the original plan. This is a lighter-weight check that runs more frequently:

> "Run git diff. Review what you just wrote. Does it match the plan? Any regressions?"

This forces the AI to confront what it actually wrote vs. what was intended. It catches drift, accidental deletions, forgotten edge cases, and scope creep before they accumulate. The diff is the source of truth — not the AI's memory of what it thinks it wrote.

### 8. Refactor Pass Before Shipping

After all phases are implemented and tests pass, I run a dedicated refactoring pass:

> "Review the changed code for reuse opportunities, code quality, and efficiency. Simplify anything that's over-engineered."

This is where I look at the codebase as a whole — not phase by phase, but as a finished product. Common outcomes: extracting duplicated logic into shared helpers, removing speculative abstractions that only have one caller, tightening types, and eliminating dead code. The goal is to ship the simplest code that satisfies all requirements — nothing more.

### 9. Clean Up Before You Ship

The final quality gate before submission:
- **Code smell sweep** — search for `any` types, callbacks, unused patterns
- **Spec compliance audit** — full matrix of requirements vs implementation
- **Dead code removal** — if it's not shipping, delete it

---

## Prompt Patterns I Use

| Pattern | Example | Purpose |
|---|---|---|
| **Exploration** | "Explain [topic] with all options and trade-offs" | Opens decision space before committing |
| **Pressure Test** | "Why is this production-ready? Explain again" | Forces deeper analysis, surfaces weaknesses |
| **Constraint** | "Consider [specific requirement]. Does this still hold?" | Tests decisions against new constraints |
| **Research** | "Search on web, research deeply and validate this" | Goes beyond AI training data |
| **Agent Review** | "Run code-reviewer and silent-failure-hunter on this phase" | Independent automated review after each phase |
| **Diff Check** | "Git diff. Review your own changes against the plan" | Frequent self-verification every 1-3 prompts |
| **Refactor** | "Simplify. Remove over-engineering. Only what's needed" | Post-implementation cleanup pass |
| **Compliance** | "Explore the whole codebase and make sure we match the requirements" | Systematic gap analysis |
| **Edge Case** | "Ultrathink of edge cases. I want more sample data, bigger tests" | Stress-tests the engine with adversarial scenarios |
| **Hard Req Audit** | "Do we still match the hard requirements? Every one truly respected?" | Line-by-line enforcement audit that catches real bugs |
| **Multi-Agent Blast** | "Use ALL code review power — code-reviewer, silent-failure-hunter — TO CATCH ALL ISSUES" | Maximum coverage review with 5 parallel agents |
| **Cleanup** | "Remove [unused feature]. I don't need it" | Decisive dead code elimination |

---

## Conversation Flow

```
Phase 1: UNDERSTAND        "Analyze requirements. What's the domain? What's the flow?"
Phase 2: EXPLORE           "What are the options? Explain each. Trade-offs?"
Phase 3: VALIDATE          "Is this production-ready? Search the web. Does this hold up?"
Phase 4: COMMIT            "Ok, let's go with this. Update the plan."
Phase 5: DESIGN            "System design with diagrams. Requirement traceability."
Phase 6: IMPLEMENT         "Execute the plan. Each phase = working commit."
   ├── every 1-3 prompts:  "Git diff. Verify your own changes."
   └── end of each phase:  "Run code-reviewer, silent-failure-hunter agents."
Phase 7: EDGE CASES        "Ultrathink edge cases. More sample data, bigger tests."
Phase 8: HARD REQ AUDIT    "Do we match every hard requirement? Line by line."
Phase 9: MULTI-AGENT BLAST "Use ALL review agents. Catch everything."
Phase 10: REFACTOR         "Simplify. Remove over-engineering. Only what's needed."
Phase 11: REVIEW           "Audit against spec. Search for code smells. Remove dead code."
```

---

## What I DON'T Do With AI

- **I don't ask it to write code without a design.** Code is the last step, not the first.
- **I don't accept first answers without challenge.** Every recommendation gets pressure-tested.
- **I don't skip external validation.** Web research confirms or corrects AI knowledge.
- **I don't make compound decisions.** One decision at a time, fully explored.
- **I don't treat AI as infallible.** It's a collaborator that needs direction, context, and oversight.
- **I don't keep dead code.** If the audit finds unused types or scaffolding, I remove them immediately.
- **I don't let AI self-assess from memory.** The diff is the source of truth. I make it verify against actual changes, not its recollection.

---

## Results

For this project, the AI-assisted workflow produced:

- **Design phase (~1 hour):** Algorithm validated against requirements, tech stack confirmed with web research, three-layer architecture with full requirement traceability matrix
- **Implementation phase:** 10 source files, 202 tests, 14 scenarios, zero type errors in strict mode — with agent reviews after each phase and diff checks every few prompts
- **Edge case + hard req audit phase:** 9 adversarial scenarios added (weekend/DST rollover, diamond DAGs, dense packing, consecutive blackouts, channel offline). Hard requirements audit caught a critical blackout-at-start bug that passed all existing tests — fixed and regression-tested
- **Multi-agent review phase:** 5 parallel review agents identified 6 issues (1 critical, 5 important). All fixed with 8 new tests in a single pass
- **Refactor + review phase (~30 minutes):** Code simplified, spec compliance matrix (all passing), 30 lines of dead code removed, final code smell audit clean

Zero rework from misunderstood requirements.
