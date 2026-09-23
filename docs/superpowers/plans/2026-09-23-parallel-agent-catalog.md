# Parallel Agent Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broad Flutter implementer with a planner plus bounded executor pool and add a fast read-only file finder.

**Architecture:** The bootstrap template remains the reusable source of truth, while the generated assignment repository mirrors its operational files. A shell contract test proves generated catalogs contain the new roles, omit the old role, and include a task contract before template and generated files are changed.

**Tech Stack:** YAML, Markdown, Bash, Git hooks, `rg`/`grep` repository search.

## Global Constraints

- Keep `AGENTS.md` below 10,240 bytes.
- Maximum concurrent subagents remains 3.
- Parallel writers require independent dependencies, non-overlapping paths, and isolated worktrees.
- The main agent owns shared files and final integration.
- No remote, push, submission, or recruiter communication.

---

### Task 1: Add the failing bootstrap contract

**Files:**
- Modify: `/Users/bongjae/Documents/취업프로젝트/wanted-applications/altinus-frontend/bootstrap-tools/test_bootstrap.sh`

**Interfaces:**
- Consumes: generated `.agents/catalog.yaml`, `.agents/task-contract.yaml`, `AGENTS.md`.
- Produces: regression assertions for the planner, file finder, executor, removed broad implementer, and task-contract fields.

- [ ] **Step 1: Extend the generated-file list and role assertions**

Add `.agents/task-contract.yaml` to the required files. Assert that `solution_planner`, `file_finder`, and `flutter_task_executor` exist; assert that `flutter_implementer` does not; assert the task contract contains `depends_on`, `allowed_paths`, `acceptance_criteria`, `verification_commands`, and `stop_and_return_when`.

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
./test_bootstrap.sh
```

Expected: `FAIL` because the generated catalog lacks `solution_planner` or `.agents/task-contract.yaml` is missing.

### Task 2: Update the reusable bootstrap template

**Files:**
- Modify: `/Users/bongjae/Documents/취업프로젝트/wanted-applications/altinus-frontend/bootstrap-tools/template/.agents/catalog.yaml`
- Modify: `/Users/bongjae/Documents/취업프로젝트/wanted-applications/altinus-frontend/bootstrap-tools/template/.agents/README.md`
- Modify: `/Users/bongjae/Documents/취업프로젝트/wanted-applications/altinus-frontend/bootstrap-tools/template/AGENTS.md`
- Create: `/Users/bongjae/Documents/취업프로젝트/wanted-applications/altinus-frontend/bootstrap-tools/template/.agents/task-contract.yaml`

**Interfaces:**
- Consumes: approved design spec and current catalog schema.
- Produces: reusable planner/executor/file-finder roles and execution gates.

- [ ] **Step 1: Replace the broad implementer role**

Define `solution_planner` as `gpt-5.6-sol/high` with plan-only rights. Define reusable `flutter_task_executor` as `gpt-5.6-terra/medium` with one-contract write scope and explicit escalation/stop rules.

- [ ] **Step 2: Add the file finder**

Define `file_finder` as `gpt-5.6-luna/low`, read-only, returning exact `path:line` evidence and related tests without design interpretation.

- [ ] **Step 3: Add the task contract and orchestration rules**

Create a concrete YAML example containing task ID, dependencies, allowed/forbidden/shared paths, inputs, acceptance criteria, tests, commands, stop conditions, and handoff evidence. Document wave gating, worktree isolation, and main-agent ownership of shared files.

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
./test_bootstrap.sh
```

Expected: `PASS: bootstrap contract`.

### Task 3: Synchronize the generated assignment repository

**Files:**
- Modify: `.agents/catalog.yaml`
- Modify: `.agents/README.md`
- Modify: `AGENTS.md`
- Create: `.agents/task-contract.yaml`

**Interfaces:**
- Consumes: the tested template files from Task 2.
- Produces: the active repository agent architecture.

- [ ] **Step 1: Apply the tested template content**

Copy the four tested operational files into the corresponding assignment repository paths without changing their semantics.

- [ ] **Step 2: Verify template parity and repository constraints**

Run:

```bash
cmp -s .agents/catalog.yaml ../wanted-applications/altinus-frontend/bootstrap-tools/template/.agents/catalog.yaml
cmp -s .agents/README.md ../wanted-applications/altinus-frontend/bootstrap-tools/template/.agents/README.md
cmp -s .agents/task-contract.yaml ../wanted-applications/altinus-frontend/bootstrap-tools/template/.agents/task-contract.yaml
cmp -s AGENTS.md ../wanted-applications/altinus-frontend/bootstrap-tools/template/AGENTS.md
./scripts/check_context_budget.sh
git diff --check
```

Expected: all commands exit 0 and `AGENTS.md` remains below 10,240 bytes.

### Task 4: Commit and final verification

**Files:**
- Modify: `docs/AI_PROMPT_LOG.md` only if execution evidence changes the recorded decision.
- Verify: all files changed by Tasks 1–3.

**Interfaces:**
- Consumes: green bootstrap contract and synchronized active files.
- Produces: a clean local repository commit with no remote changes.

- [ ] **Step 1: Run full verification**

Run the bootstrap contract, YAML/text assertions, shell syntax checks, size budget, whitespace check, Git status, and remote-count check.

- [ ] **Step 2: Commit the active repository changes**

```bash
git add AGENTS.md .agents docs/superpowers/plans/2026-09-23-parallel-agent-catalog.md
git commit -m "refactor(agents): split planning from parallel execution" \
  -m $'What:\n- Add a solution planner, bounded executor pool, file finder, and task contract.\n\nWhy:\n- Reduce the serial implementation bottleneck while preserving safe ownership and integration gates.'
```

- [ ] **Step 3: Confirm local-only state**

Run:

```bash
git status --short
git remote -v
git log -1 --format='%h %s'
```

Expected: clean status, no remotes, and the new local commit at HEAD.
