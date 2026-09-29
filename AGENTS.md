# AGENTS.md

## Mission and safety boundary

Build and verify the Altinus Frontend Engineer camera/OCR assignment. This repository is local preparation until the user explicitly authorizes an external action. Never create a remote, push, submit, email, message a recruiter, cancel, or alter an application without a fresh request and the job-application safety checks.

## Required reading order

Before planning or editing:

1. `docs/CONTEXT.md` — authoritative domain facts, source priority, assumptions, risks.
2. `docs/PRD.md` — product requirements and acceptance criteria.
3. Relevant tests and production files.
4. `docs/E2E_TESTING.md` when touching runtime behavior or verification.
5. `docs/AI_PROMPT_LOG.md` only to recover prior decisions; append, do not rewrite history.

If sources conflict, follow the priority declared in `docs/CONTEXT.md` and record the conflict before coding.

## Working rules

- Keep this repository isolated from the parent career-project repository.
- Use test-driven development for behavior: write one failing test, observe the expected failure, implement the minimum, then refactor with tests green.
- Make small, reviewable changes. Do not mix unrelated refactors with requirement work.
- Do not invent device results, OCR accuracy, performance numbers, or employer expectations.
- Treat iOS and Android as separate verification surfaces. Passing Android does not imply iOS passes.
- Keep UI-thread work bounded. Camera capture, image decoding, preprocessing, and OCR require explicit performance reasoning.
- Permission denial, unavailable camera, OCR failure, malformed/rotated/large images, lifecycle transitions, and retry behavior are first-class states.
- Never commit secrets, signing credentials, personal tokens, or private application records except the exact user-approved evaluator bundle below. Do not broaden this exception:
  - `android/key.properties`
  - `android/evaluator-signing/artinus-ocr-upload.jks`
  - `lib/bootstrap/evaluator_credentials.dart`
- The three-file exception is dedicated, revocable take-home material for the Spark/no-billing assignment project, not production practice. Never add a Gemini API key, service-account/Firebase CLI token, Apple account/session, private Apple key, `.p12`, provisioning profile, former-employer asset, or unrelated signing identity.

## Documentation anti-work rule

Documentation exists to support executable work, a verified decision, or a required submission explanation. Do not create a standalone task whose only outcome is more documentation.

A documentation change must be coupled to at least one of:

- production code or tests changed in the same commit;
- a requirement/source change that alters acceptance criteria;
- a verified architecture decision needed before the next code change;
- an incident, failed experiment, or E2E result with reproducible evidence;
- a user-requested handoff or submission artifact.

The pre-commit hook rejects docs-only staged changes by default. A true documentation-only exception requires both `ALLOW_DOCS_ONLY=1` and a specific `DOCS_ONLY_REASON`. Never set this merely to bypass the gate.

## Git convention

Every commit message must use:

```text
type(optional-scope): imperative summary

What:
- Concrete change made.

Why:
- Requirement, defect, or tradeoff that required it.
```

Allowed types: `feat`, `fix`, `test`, `refactor`, `perf`, `build`, `ci`, `docs`, `chore`, `revert`. The subject states the outcome; `What` and `Why` must contain meaningful content. Use `.gitmessage` as the template.

## Subagent policy

- Use a subagent only for a bounded, independent question with a defined output.
- Consult `.agents/catalog.yaml` and choose the lowest-cost model/effort that can reliably do the task.
- Maximum concurrent subagents: 3.
- Use `file_finder` for targeted file, symbol, usage, configuration, and test searches; it is read-only and returns exact `path:line` evidence.
- `solution_planner` owns architecture and the execution plan but cannot write production code.
- A writer may start only from an approved task contract derived from `.agents/task-contract.yaml`.
- Parallel writers require dependency-ready contracts, disjoint allowed paths, and separate Git worktrees.
- Never let two agents edit the same file set concurrently.
- The main agent owns dependency manifests, app entry points, routing, dependency injection, integration, and other shared files.
- `flutter_task_executor` implements one contract with tests and cannot change the plan. It must stop and return on ambiguity, missing dependencies, path overlap, shared-file needs, or architecture changes.
- Keep dependent, short, or security-sensitive steps in the main agent.
- Review every returned claim against repository evidence before adoption.

## Prompt and AI-use log

After each meaningful user direction or AI-assisted implementation decision, append to `docs/AI_PROMPT_LOG.md`:

- timestamp and actor;
- prompt/request summary (verbatim only when useful and safe);
- affected files or decision;
- outcome: adopted, modified, or rejected;
- verification evidence.

Do not record hidden chain-of-thought, credentials, private mail content, or irrelevant personal information.

## Verification and completion

Before claiming completion:

1. Run focused unit/widget tests for changed behavior.
2. Run static analysis and the full relevant test suite.
3. Follow the platform matrix in `docs/E2E_TESTING.md`.
4. Run `scripts/check_context_budget.sh`.
5. Report exact commands and fresh results, including what could not be run.

Real-device preview and platform parity can only be marked complete from recorded runs on both target platforms. Chrome or Android automation is not evidence for native iOS behavior.
