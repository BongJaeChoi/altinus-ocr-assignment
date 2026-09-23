# Parallel Agent Execution Design

## Decision

Replace the broad `flutter_implementer` role with a gated planner-and-executor workflow. A `solution_planner` owns architecture and an execution-ready plan. A reusable `flutter_task_executor` implements exactly one approved task contract. Up to three executors may run concurrently only when dependencies, file ownership, and verification commands are independent.

Add a dedicated `file_finder` because targeted repository search is frequent, cheap, and naturally read-only. It returns exact paths, symbols, tests, and evidence without making design or implementation decisions.

## Evidence

- OpenAI's current multi-agent guide recommends parallel agents for concrete, independent workstreams such as separate implementation components and test suites. It warns against parallel agents for ordered reasoning chains or shared mutable resources: <https://developers.openai.com/api/docs/guides/responses-multi-agent>.
- OpenAI's model guidance positions `gpt-5.6-luna` for efficient high-volume work, `gpt-5.6-terra` for balanced work, and `gpt-5.6-sol` for work needing stronger judgment: <https://developers.openai.com/api/docs/guides/latest-model?model=gpt-5.6>.

## Roles

### `file_finder`

- Model: `gpt-5.6-luna`, effort `low`.
- Mode: read-only.
- Uses `rg --files`, `rg -n`, and focused repository inspection.
- Returns `path:line`, relevance, related tests, and unknowns.
- Does not interpret requirements, propose architecture, or edit files.

### `solution_planner`

- Model: `gpt-5.6-sol`, effort `high`.
- Mode: plan-only.
- Produces one implementation plan and one task contract per executable unit.
- Locks interfaces, task dependencies, file ownership, shared-file changes, tests, commands, and stop conditions before execution.
- Does not write production code.

### `flutter_task_executor`

- Default model: `gpt-5.6-terra`, effort `medium`.
- Escalates to `terra/high` for lifecycle, concurrency, native plugin, or hard diagnosis work; uses `sol/high` only when the planner or main agent records why.
- Receives exactly one task contract and uses red-green-refactor within its allowed paths.
- Cannot edit the plan, shared files, or another task's paths.
- Stops and returns when the contract is ambiguous, a dependency is missing, or an architecture change is required.

## Execution gates

1. `docs/IMPLEMENTATION_PLAN.md` and task contracts exist and have been approved.
2. Every task lists dependencies, allowed paths, forbidden/shared paths, acceptance criteria, tests, verification commands, and stop conditions.
3. A task starts only after all `depends_on` tasks pass their verification.
4. Parallel writers use separate Git worktrees and never own overlapping files.
5. The main agent alone modifies shared files such as dependency manifests, application entry points, routing, and dependency injection.
6. The main agent reviews diffs, integrates work, and runs the full suite after every wave.
7. Device agents do not share the same physical device or automation session concurrently.

## Planned waves for this assignment

```text
requirements/context
        ↓
solution_planner
        ↓
foundation contract (sequential)
        ↓
camera task ∥ OCR task ∥ presentation task
        ↓
main-agent integration and full tests
        ↓
Android E2E ∥ iOS verification ∥ code review
```

The exact Flutter file boundaries are not invented during bootstrap. The planner must derive them after the framework, packages, interfaces, and project scaffold are approved.

## Rejected alternatives

- One end-to-end Flutter implementer: simple but creates a large context, long critical path, and weak ownership boundaries.
- Permanent agent per feature directory: explicit but over-specialized before the code structure exists.
- Parallel execution based only on a prose plan: rejected because it lacks machine-checkable ownership and stop conditions.

