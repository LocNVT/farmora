# Farmora — Claude Code Instructions

## 1. Project Overview

Farmora is a mobile animal farming simulation game.

Core gameplay loop:

Buy animals
→ Feed animals
→ Care for animals
→ Animals produce resources
→ Collect products
→ Sell products
→ Earn coins
→ Upgrade farm
→ Buy more/better animals

Target platform:

* Android
* iOS

Target orientation:

* Portrait
* Mobile-first UI

Technology:

* Godot 4.x
* GDScript
* 2D
* Local JSON save for MVP

---

## 2. Source of Truth

Before implementing anything, read the relevant project documents.

### Game Design

Read:

`docs/GDD.md`

This defines:

* Game vision
* Gameplay loop
* MVP scope
* Animals
* Products
* Buildings
* Economy
* Progression
* Offline progression
* Future features

### Visual Design

Read:

`docs/DESIGN.md`

This defines:

* Visual direction
* Color palette
* Typography
* Iconography
* Spacing
* Visual hierarchy
* Animal visual style
* Building visual style
* Animation principles
* Mobile visual rules

### UI Specification

Read:

`docs/UI_SPEC.md`

This defines:

* Screen layouts
* Navigation
* UI components
* Buttons
* Dialogs
* Animal interaction UI
* Shop
* Inventory
* Market
* Upgrade screens
* Offline rewards
* Tutorial
* Loading/empty/error states
* Interaction states

### Architecture

Read:

`docs/ARCHITECTURE.md`

This defines:

* Project architecture
* Folder structure
* Runtime state
* Static definitions
* Services
* Data flow
* Save/load architecture
* Dependencies
* Testing strategy

### Progress

Read:

`docs/PROGRESS.md`

This defines:

* Current phase
* Completed work
* Remaining work
* Known issues
* Next action

### Codex Review

Read:

`docs/CODEX_REVIEW.md`

This contains:

* Previous Codex reviews
* Findings
* Fixes
* Review status

---

# 3. Design Authority

The approved design documents are the source of truth.

Priority:

1. GDD.md
2. DESIGN.md
3. UI_SPEC.md
4. ARCHITECTURE.md
5. PROGRESS.md

Do not invent new gameplay systems or UI behavior when the design already specifies them.

If implementation conflicts with the design:

1. Stop.
2. Identify the conflict.
3. Explain the conflict.
4. Prefer the approved design.
5. Ask for clarification if the conflict cannot be resolved safely.

Do not silently change the design.

---

# 4. MVP Scope

Keep the MVP intentionally small.

MVP animals:

* Chicken
* Cow
* Pig

MVP products:

* Egg
* Milk
* Pork

MVP resources:

* Coins
* Feed

MVP systems:

* Farm grid
* Animal spawning
* Animal movement
* Animal selection
* Animal state
* Hunger
* Happiness
* Feeding
* Production
* Product collection
* Inventory
* Selling
* Economy
* Buildings
* Upgrades
* Save/load
* Autosave
* Offline progression

Breeding is NOT part of the MVP.

Do not implement future systems unless explicitly requested.

---

# 5. Development Philosophy

Implement incrementally.

Never implement the entire game in one task.

Each task should:

1. Understand the relevant design.
2. Inspect the existing implementation.
3. Create a small implementation plan.
4. Implement only the requested scope.
5. Run tests.
6. Run/build the game when applicable.
7. Verify behavior.
8. Update documentation.
9. Prepare the work for Codex review.

Prefer simple and maintainable solutions over premature complexity.

---

# 6. Phase-Based Development

Development is divided into phases.

### Phase 0 — Foundation

Implement:

* Godot project setup
* Folder structure
* Main scene
* Mobile portrait configuration
* Basic theme
* Design system foundation
* Basic reusable UI components
* Initial test infrastructure

Goal:

The game launches successfully and demonstrates the approved visual/UI foundation.

---

### Phase 1 — Farm

Implement:

* Farm scene
* Farm grid
* Basic terrain
* Camera
* Basic interaction
* Building placement foundation

---

### Phase 2 — Animals

Implement:

* Animal definitions
* Animal instances
* Animal spawning
* Animal movement
* Animal selection
* Animal states

---

### Phase 3 — Feeding

Implement:

* Feed inventory
* Feeding interaction
* Hunger
* Happiness
* Animal state updates

---

### Phase 4 — Production

Implement:

* Production timers
* Product generation
* Product collection
* Production UI

Production must be based on elapsed time/timestamps.

Do not implement production using frame counters.

---

### Phase 5 — Economy

Implement:

* Inventory
* Product selling
* Coins
* Shop
* Basic economy rules

---

### Phase 6 — Buildings

Implement:

* Building definitions
* Building instances
* Construction
* Capacity
* Upgrades

---

### Phase 7 — Save

Implement:

* Save
* Load
* Autosave
* Save versioning
* Corrupted/malformed save handling

---

### Phase 8 — Offline Progression

Implement:

* Last saved timestamp
* Offline elapsed time
* Offline production
* Offline reward calculation
* Offline reward UI

Offline progression must have a maximum cap of 8 hours for MVP.

---

### Phase 9 — Polish

Implement:

* Animations
* Feedback
* Audio
* Better transitions
* Juice
* UI polish
* Performance optimization

---

### Phase 10 — Mobile Validation

Validate:

* Android build
* iOS compatibility where applicable
* Portrait layout
* Touch interactions
* Different screen sizes
* Performance
* Memory usage
* Save/load reliability

---

# 7. Architecture Rules

Keep static definitions separate from runtime state.

Static definitions include:

* AnimalDefinition
* BuildingDefinition
* ProductDefinition
* UpgradeDefinition

Runtime state includes:

* AnimalInstance
* BuildingInstance
* PlayerState
* InventoryState
* FarmState

Do not mix configuration data with mutable runtime state unnecessarily.

Prefer data-driven systems.

---

# 8. Time-Based Systems

Any system involving time must use timestamps or elapsed time.

Examples:

* Animal production
* Offline progression
* Production cooldowns
* Timed rewards

Do NOT use:

* Frame count as persistent time
* Number of `_process()` calls as game time
* Frame-dependent production logic

The game must remain correct if FPS changes.

---

# 9. Mobile UI Rules

The game is mobile-first.

Always consider:

* Touch targets
* Portrait orientation
* Different aspect ratios
* Safe areas
* Readability
* One-handed interaction
* Visual hierarchy
* Minimal unnecessary text
* Clear feedback

Do not create desktop-first UI and adapt it later.

---

# 10. Placeholder Assets

During early development:

Use placeholders where final art assets are not available.

Do not block gameplay implementation waiting for final artwork.

However:

* Follow DESIGN.md for visual proportions.
* Follow DESIGN.md for colors.
* Follow UI_SPEC.md for layout.
* Clearly separate temporary assets from final assets.

Do not permanently replace designed visuals with developer-default UI.

---

# 11. Testing

Every implementation phase should include appropriate tests.

At minimum, test:

* Economy calculations
* Production calculations
* Inventory operations
* Save/load
* Offline progression
* Capacity rules
* Upgrade calculations

When fixing a bug:

1. Reproduce the bug.
2. Add or update a test when practical.
3. Fix the bug.
4. Run the relevant tests.
5. Run the full test suite when appropriate.

---

# 12. Documentation

After completing a task:

Update:

`docs/PROGRESS.md`

Include:

* What was implemented
* What was tested
* Known issues
* Remaining work
* Next action

Do not rewrite unrelated documentation.

---

# 13. Codex Review Workflow

After completing each implementation phase:

1. Run tests.
2. Build/run the project.
3. Review the implementation yourself.
4. Invoke Codex as a reviewer.
5. Give Codex the relevant implementation context and design documents.
6. Do NOT ask Codex to implement new features during review.

Codex is a reviewer, not the primary implementer.

---

# 14. Codex Finding Classification

When Codex returns findings, classify each finding as:

* VALID
* INVALID
* ALREADY_HANDLED
* NOT_APPLICABLE
* OPTIONAL

For VALID findings:

1. Fix the issue.
2. Run tests.
3. Re-check the implementation.
4. Ask Codex to review again when appropriate.

Do not blindly apply every Codex suggestion.

---

# 15. Review Status Format

Maintain this format in `docs/PROGRESS.md`:

## Review Status

### Claude Implementation

* Status: COMPLETE

### Codex Review

* Status: PASS

### Review Findings

* None

### Remaining Work

* ...

### Next Action

* ...

Possible Codex statuses:

* NOT_STARTED
* IN_PROGRESS
* PASS
* NEEDS_FIX

---

# 16. Scope Control

Do not:

* Implement future features without approval.
* Rewrite unrelated systems.
* Introduce unnecessary dependencies.
* Replace the architecture without justification.
* Change the visual design without approval.
* Expand MVP scope during implementation.

If you discover an improvement outside the current task:

Record it as a future task instead of implementing it immediately.

---

# 17. Before Starting Any Task

Before coding, answer internally:

1. What phase am I working on?
2. What design documents are relevant?
3. What existing systems are affected?
4. What is explicitly in scope?
5. What is explicitly out of scope?
6. How will this be tested?
7. What documentation needs to be updated?

Then implement.

---

# 18. Definition of Done

A task is NOT complete simply because the code compiles.

A task is complete when:

* Implementation matches the approved design.
* The requested functionality works.
* Relevant tests pass.
* No obvious regression is introduced.
* Mobile UI behavior is verified where applicable.
* Documentation is updated.
* PROGRESS.md is updated.
* Codex review is completed when required.
* Remaining issues are documented.

---

# 19. Important Rule

When uncertain, do not silently invent a solution.

Check:

`GDD.md`

then:

`DESIGN.md`

then:

`UI_SPEC.md`

then:

`ARCHITECTURE.md`

For architectural or design decisions, delegate the decision to an appropriate high-reasoning agent when possible. Only ask the user when the decision materially changes product requirements or requires explicit product-owner approval.

# 20. Agent Delegation & Token Optimization
a
Claude Code is the primary orchestrator.

The primary goal is to complete tasks with the required quality while minimizing unnecessary token usage.

Do NOT perform every task directly when a specialized agent/model can handle it more efficiently.

---

## 20.1 Orchestrator Responsibilities

The main Claude Code session is responsible for:

1. Understanding the user's request.
2. Reading the relevant project/design documents.
3. Breaking the task into appropriate subtasks.
4. Selecting the appropriate agent/model for each subtask.
5. Delegating work when beneficial.
6. Reviewing the returned results.
7. Integrating the results.
8. Running tests.
9. Running Codex review when required.
10. Updating documentation and progress.

The orchestrator should avoid doing low-complexity work itself when delegation is more token-efficient.

---

# 20.2 Model Selection

Use the cheapest model capable of completing the task correctly.

### Haiku

Prefer Haiku for simple, deterministic or mechanical tasks.

Examples:

* Small documentation updates
* Formatting
* Simple localization changes
* Renaming
* Simple file organization
* Straightforward test additions
* Simple repetitive code changes
* Reading and summarizing a small set of files
* Updating PROGRESS.md
* Updating changelog-style documentation
* Simple validation
* Finding obvious references/usages

Do NOT use Haiku for:

* Architecture decisions
* Complex debugging
* Large refactoring
* Ambiguous requirements
* Important gameplay design decisions
* Security-sensitive changes
* Complex state management

---

### Sonnet

Use Sonnet as the default implementation agent.

Examples:

* Normal feature implementation
* Gameplay systems
* UI implementation
* Godot scene implementation
* Service implementation
* Save/load implementation
* Inventory/economy systems
* Animal systems
* Production systems
* Medium-sized refactoring
* Bug fixes requiring code reasoning
* Integration between multiple systems

Sonnet should be the default when the task requires meaningful engineering reasoning but does not require deep architectural investigation.

---

### Opus

Use Opus selectively for high-complexity reasoning.

Examples:

* Architecture decisions
* Major refactoring
* Complex debugging
* Difficult performance problems
* Cross-system design problems
* Difficult concurrency/state problems
* Significant save-data migration issues
* Problems where multiple subsystems interact in unexpected ways
* Reviewing ambiguous or conflicting requirements
* High-impact technical decisions

Do NOT use Opus for routine implementation.

---

### Codex

Codex is primarily an independent reviewer.

Use Codex for:

* Code review
* Finding bugs
* Identifying edge cases
* Detecting architectural problems
* Reviewing implementation against requirements
* Reviewing implementation against DESIGN.md/UI_SPEC.md
* Checking regressions
* Checking test coverage

Do not delegate routine implementation to Codex unless explicitly requested.

The goal is to maintain reviewer independence.

---

# 20.3 Task Complexity Classification

Before implementing a non-trivial task, classify it:

### SIMPLE

Characteristics:

* One or two files
* Deterministic change
* Clear requirements
* Low risk
* No architecture impact

Preferred model:

`Haiku`

---

### MEDIUM

Characteristics:

* Multiple files
* Normal feature implementation
* Requires code reasoning
* Moderate integration
* Limited architectural impact

Preferred model:

`Sonnet`

---

### COMPLEX

Characteristics:

* Multiple systems
* Architecture impact
* Difficult debugging
* Significant state management
* Performance-sensitive
* Unclear requirements
* High regression risk

Preferred model:

`Opus`

---

# 20.4 Delegation Decision

Before doing implementation work, ask:

1. Is this task simple enough for Haiku?
2. Is this a normal engineering task for Sonnet?
3. Does this require Opus-level reasoning?
4. Can the task be safely delegated?
5. Can multiple independent subtasks be delegated in parallel?
6. Can the main context remain focused on orchestration?

Prefer delegation when it reduces context usage without reducing quality.

---

# 20.5 Parallel Delegation

When multiple tasks are independent, delegate them separately.

Example:

Phase implementation may be divided into:

```text
Agent A — Haiku
Update documentation

Agent B — Sonnet
Implement gameplay system

Agent C — Sonnet
Implement UI

Agent D — Haiku
Add straightforward tests
```

The orchestrator then integrates and verifies the results.

Do NOT parallelize tasks that modify the same files or depend heavily on each other's unfinished work.

---

# 20.6 Context Minimization

When delegating a task:

Do NOT send the entire project context unnecessarily.

Provide only:

* Relevant files
* Relevant design specification
* Relevant requirements
* Expected behavior
* Relevant tests
* Constraints

Avoid sending unrelated:

* Documentation
* Previous implementation details
* Large logs
* Unrelated source files
* Entire repository context

The goal is to minimize token consumption.

---

# 20.7 Review Before Delegation

After completing an implementation task, the orchestrator should review the result before invoking Codex.

Perform a lightweight review:

* Does the implementation match the requirement?
* Does it follow GDD.md?
* Does it follow DESIGN.md?
* Does it follow UI_SPEC.md?
* Does it follow ARCHITECTURE.md?
* Are obvious edge cases handled?
* Are tests present where appropriate?

If the issue is trivial, fix it using a low-cost agent/model.

If the issue requires architectural reasoning, delegate to Opus.

Then run Codex for independent review.

---

# 20.8 Codex Review Pipeline

Use the following workflow:

```text
User Request
     ↓
Claude Code Orchestrator
     ↓
Task Classification
     ↓
┌──────────┬──────────┬──────────┐
│  Haiku   │  Sonnet  │   Opus   │
│  Simple  │  Normal  │ Complex  │
└──────────┴──────────┴──────────┘
     ↓
Implementation
     ↓
Claude Review
     ↓
Tests
     ↓
Codex Review
     ↓
Findings
     ↓
Classify Findings
     ↓
┌────────────────────────────────┐
│ VALID / INVALID / OPTIONAL     │
└────────────────────────────────┘
     ↓
VALID findings
     ↓
Select cheapest capable model
     ↓
Fix
     ↓
Tests
     ↓
Codex Re-review
     ↓
PASS
```

---

# 20.9 Fixing Codex Findings

Do not automatically use Opus to fix every finding.

Choose the cheapest capable model.

Examples:

```text
Typo
    → Haiku

Simple null check
    → Haiku

Simple test failure
    → Haiku / Sonnet

Normal logic bug
    → Sonnet

Complex state bug
    → Sonnet / Opus

Architecture problem
    → Opus
```

The model used to fix a finding does not need to be the same model that originally implemented the feature.

---

# 20.10 Escalation Rule

Start with the cheapest reasonable model.

Escalate only when necessary.

Example:

```text
Haiku
  ↓
Unable to solve / insufficient reasoning
  ↓
Sonnet
  ↓
Still unresolved / architectural complexity
  ↓
Opus
```

Do not immediately escalate to Opus.

---

# 20.11 No Unnecessary Re-Reading

Agents should avoid repeatedly loading the same large documents.

When possible:

* Read only relevant sections.
* Reuse concise summaries.
* Reference existing artifacts.
* Avoid copying entire documents into prompts.
* Avoid reopening unrelated files.

The orchestrator should maintain a concise task summary when handing work between agents.

---

# 20.12 Agent Handoff Format

Every delegated task should contain:

```text
## Task

<what needs to be done>

## Context

<only relevant context>

## Requirements

- ...
- ...
- ...

## Relevant Files

- ...
- ...

## Design References

- docs/GDD.md
- docs/DESIGN.md
- docs/UI_SPEC.md

## Constraints

- ...
- ...

## Expected Result

<what the agent should produce>

## Verification

<how the result should be verified>
```

The agent should return:

```text
## Result

Status: COMPLETE / BLOCKED / FAILED

### Changes

- ...

### Tests

- ...

### Issues

- ...

### Follow-up

- ...
```

---

# 20.13 Do Not Delegate Blindly

Delegation is not automatically better.

Do NOT delegate when:

* The task is smaller than the delegation overhead.
* The main context already has all required information.
* The change is a one-line deterministic modification.
* The task requires immediate integration with the current reasoning.
* Delegation would create conflicting changes.

Use judgment.

---

# 20.14 Token Optimization Priority

Optimize in this order:

1. Avoid unnecessary context.
2. Delegate simple work to Haiku.
3. Use Sonnet for normal implementation.
4. Use Opus only for complex reasoning.
5. Keep Codex independent as reviewer.
6. Avoid duplicate reviews.
7. Avoid unnecessary re-reading.
8. Avoid unnecessary agent handoffs.

Quality must not be sacrificed merely to reduce token usage.

---

# 20.15 Phase Completion

At the end of every phase:

1. Confirm implementation scope.
2. Run tests.
3. Run/build the game.
4. Perform Claude review.
5. Invoke Codex review.
6. Classify findings.
7. Delegate fixes to the cheapest capable model.
8. Re-run tests.
9. Re-run Codex review if necessary.
10. Update `docs/PROGRESS.md`.

Only mark the phase as complete when:

```text
Claude Implementation
    = COMPLETE

Tests
    = PASS

Codex Review
    = PASS

Remaining Work
    = documented

Next Action
    = documented
```

---

# 20.16 Important Principle

The main Claude Code session is an orchestrator, not a worker that must personally perform every operation.

Prefer:

```text
Understand
   ↓
Decompose
   ↓
Delegate
   ↓
Review
   ↓
Integrate
   ↓
Test
   ↓
Codex
   ↓
Fix with cheapest capable model
   ↓
Verify
```

over:

```text
Claude Code does everything itself
```

The objective is:

**High quality + low unnecessary token consumption + independent review.**


# Autonomous Implementation & Review Workflow

## 1. Role

Claude Code is the primary implementation agent and task orchestrator.

For normal implementation tasks, work autonomously from implementation through verification and review.

Do not stop after implementation merely to ask the user to run tests, inspect the result, or relay review feedback.

The normal workflow is:

PLAN
→ IMPLEMENT
→ TEST
→ SELF-VERIFY
→ CODEX REVIEW
→ CLASSIFY FINDINGS
→ FIX VALID FINDINGS
→ RE-TEST
→ RE-REVIEW WHEN REQUIRED
→ UPDATE DOCS
→ CONTINUE

Only stop and ask the user when a genuine decision or blocker requires human input.

---

## 2. Source of Truth

Before implementing a task, inspect the relevant project documentation.

Priority:

1. Current task requirements
2. `docs/GDD.md`
3. `docs/DESIGN.md`
4. `docs/UI_SPEC.md`
5. `docs/ARCHITECTURE.md`
6. `docs/PROGRESS.md`
7. Existing implementation and tests

Do not invent behavior that conflicts with these documents.

`CLAUDE.md` defines project rules and workflow.

Detailed game design belongs in `docs/*.md`.

---

## 3. Task Workflow

For every meaningful task:

### Step 1 — Plan

Before editing:

* Identify relevant files.
* Read the relevant design and architecture sections.
* Identify dependencies and existing patterns.
* Determine implementation scope.
* Identify tests required.
* Identify potential regression risks.

Keep the plan concise.

### Step 2 — Implement

Implement the smallest correct solution.

Follow existing project conventions.

Do not prematurely implement future-phase functionality.

Do not introduce abstractions without a concrete need.

### Step 3 — Test

Run the most relevant automated tests.

For Godot tasks, prefer:

* Headless project validation
* GUT tests
* Relevant unit tests
* Relevant integration tests

When the task affects visuals or input:

* Run an appropriate visual/manual verification.
* Verify mobile portrait behavior when relevant.

### Step 4 — Self-Review

Before asking Codex to review:

* Re-read the changed files.
* Check for regressions.
* Check null/default/error cases.
* Check scene/node ownership.
* Check architecture boundaries.
* Check tests actually validate behavior rather than implementation details.
* Check documentation consistency.

Fix obvious issues immediately.

---

## 4. Codex Review

For meaningful implementation tasks, run Codex independently after Claude's own verification.

Use:

```powershell
codex exec --skip-git-repo-check -s read-only
```

Codex is an independent reviewer.

It must:

* Inspect the actual repository.
* Read the governing documentation.
* Inspect the implementation and tests.
* Verify the task requirements.
* Look for correctness, architecture, regressions, edge cases, and missing tests.
* Not modify files.
* Not rely solely on Claude's summary.

The review should distinguish real defects from optional improvements.

---

## 5. Review Findings Classification

Every Codex finding must be classified as one of:

* `VALID`
* `VALID_DEFERRED`
* `INVALID`
* `ALREADY_HANDLED`
* `NOT_APPLICABLE`
* `OPTIONAL`

### VALID

The implementation is incorrect, incomplete, unsafe, or violates an established requirement.

Action:

1. Fix it.
2. Run tests again.
3. Re-run Codex review if the fix is material.

### VALID_DEFERRED

The concern is real, but the correct implementation belongs to a later task/phase and implementing it now would prematurely expand scope.

Action:

1. Record it in `docs/PROGRESS.md` or the appropriate design/review document.
2. Explicitly identify the future task/phase.
3. Do not implement it prematurely.
4. Do not count it as an unresolved blocker for the current task.

### INVALID

The finding is based on an incorrect assumption or contradicts the project requirements.

Action:

* Document the reasoning.
* No code change required.

### ALREADY_HANDLED

The finding describes behavior that already exists.

Action:

* Point to the relevant implementation/test.
* No code change required.

### NOT_APPLICABLE

The finding does not apply to the current scope.

### OPTIONAL

Useful improvement, but not required for correctness.

Action:

* Do not block the task.
* Record only if it is useful for future work.

---

## 6. Fixing Codex Findings

Do not automatically use the most expensive model.

Choose the cheapest capable approach:

### Haiku

Use for:

* Simple mechanical fixes
* Test additions
* Documentation updates
* Small refactors
* Straightforward bug fixes

### Sonnet

Use for:

* Normal gameplay implementation
* UI
* Services
* State management
* Refactoring
* Multi-file changes

### Opus

Use for:

* Architecture decisions
* Difficult debugging
* Complex interactions
* Ambiguous requirements
* High-impact design changes

Codex remains an independent reviewer.

---

## 7. Re-Review Rules

Run Codex again when:

* A `VALID` finding was fixed.
* The fix changes architecture.
* The fix changes public behavior.
* The fix affects input/camera/save/state systems.
* The fix touches multiple important systems.
* Claude is uncertain whether the fix fully addresses the finding.

A tiny documentation-only change normally does not require another Codex review.

Do not repeatedly review trivial changes just to satisfy the workflow.

---

## 8. Task Completion Criteria

A meaningful task is complete only when:

```text
Implementation = COMPLETE
Verification = PASS
Codex Review = PASS
Unresolved VALID findings = 0
```

`VALID_DEFERRED` is allowed when properly documented.

Before marking the task complete:

* Update `docs/PROGRESS.md`.
* Update `docs/CODEX_REVIEW.md` when Codex was used.
* Record remaining work if applicable.
* Record the next recommended task.

---

## 9. Phase Completion

At the end of each major phase:

1. Run the complete test suite.
2. Perform full project verification.
3. Run a final Codex review of the phase.
4. Resolve all `VALID` findings.
5. Document `VALID_DEFERRED` findings.
6. Update `docs/PROGRESS.md`.
7. Confirm the phase completion criteria.

Do not start the next major phase until the current phase has passed final review.

---

## 10. When to Ask the User

Do NOT stop for normal implementation decisions that can be resolved from the existing design.

Ask the user only when one of these occurs:

* A product decision is required.
* Two authoritative documents genuinely contradict each other.
* A major architecture decision is not specified.
* A required dependency or credential is unavailable.
* The environment prevents verification.
* The requested change materially expands project scope.
* There is a destructive or irreversible action requiring confirmation.

Otherwise continue autonomously.

---

## 11. Review Status

Maintain this format in `docs/PROGRESS.md`:

```text
## Review Status

### Claude Implementation
- Status: COMPLETE

### Codex Review
- Status: PASS

### Review Findings
- None

### Remaining Work
- ...

### Next Action
- ...
```

If findings remain:

```text
## Review Status

### Claude Implementation
- Status: COMPLETE

### Codex Review
- Status: FINDINGS

### Review Findings
- VALID: ...
- VALID_DEFERRED: ...

### Remaining Work
- ...

### Next Action
- Fix VALID findings / continue with next task
```

---

## 12. Autonomous Continuation

When a task is complete and the next task is clearly defined by the current phase documentation:

* Do not wait for user confirmation.
* Continue to the next task.
* Preserve the same PLAN → IMPLEMENT → TEST → REVIEW workflow.

For example:

```text
Task 4 COMPLETE
→ Task 5 is clearly defined
→ Start Task 5 automatically
```

Only stop if a condition in "When to Ask the User" is triggered.

---

## 13. Final User Report

At the end of an autonomous run, provide a concise summary:

* What was implemented
* Tests/verification results
* Codex review result
* Findings fixed/deferred
* Current phase/task
* Next action

Do not dump the entire internal process unless requested.

# Context Compaction & Continuation

## Purpose

The project must remain resumable after Claude Code context compaction.

Never rely on conversation history as the source of truth for project progress.

The repository documentation must contain enough information to resume the current task after compaction.

---

## Before Context Gets Large

When the context becomes large or compaction is approaching:

1. Finish the current atomic subtask if possible.
2. Run relevant tests.
3. Update `docs/PROGRESS.md`.
4. Record the current implementation status.
5. Record unfinished work.
6. Record the exact next action.
7. Record any important decisions or discovered issues.
8. Update `docs/CODEX_REVIEW.md` if a review has occurred.

Do not leave important state only in conversation context.

---

## Progress Checkpoint

Maintain the following information in `docs/PROGRESS.md`:

```text
## Current Work

### Phase
Phase X — ...

### Task
Task X — ...

### Status
IN_PROGRESS / COMPLETE / BLOCKED

### Completed
- ...

### In Progress
- ...

### Remaining Work
- ...

### Important Decisions
- ...

### Tests
- ...

### Codex Review
- ...

### Next Action
- ...
```

---

## After Context Compaction

After compaction, immediately reconstruct the working context from the repository.

Read, in this order:

1. `CLAUDE.md`
2. `docs/PROGRESS.md`
3. `docs/GDD.md`
4. `docs/DESIGN.md`
5. `docs/ARCHITECTURE.md`
6. `docs/CODEX_REVIEW.md`
7. Relevant source files
8. Relevant tests

Do not assume previous conversation context is still available.

Do not ask the user to repeat the previous task if the required state can be recovered from the repository.

Determine:

* Current phase
* Current task
* What has already been implemented
* What remains
* Last verification result
* Last Codex review result
* Next action

Then continue autonomously.

---

## Continuation Rule

After reconstructing context:

```text
READ STATE
→ VERIFY CURRENT REPOSITORY
→ IDENTIFY NEXT ACTION
→ CONTINUE WORK
```

Do not restart completed work.

Do not redo completed tasks unless verification shows a regression.

Do not wait for user confirmation unless a genuine product decision, architecture conflict, blocker, or scope change requires it.

---

## Atomic Progress Checkpoints

For long tasks, update `docs/PROGRESS.md` at meaningful checkpoints:

* After planning
* After major implementation milestone
* After tests
* After Codex review
* After fixing findings
* Before starting another major task

Keep checkpoints concise.

---

## Autonomous Continuation

Context compaction is not a task boundary.

If the current task is still incomplete after compaction:

```text
resume current task
→ verify state
→ continue implementation
→ test
→ review
→ complete task
```

If the current task is complete:

```text
complete current task
→ update docs
→ start next defined task
```

Do not stop merely because context was compacted.

