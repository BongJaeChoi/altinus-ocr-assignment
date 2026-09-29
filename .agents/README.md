# Subagent Use

`catalog.yaml` is a selection catalog, not authorization to spawn every role. The main agent owns approval, shared files, integration, and final verification.

Before delegating, define:

- one independent question or file boundary;
- evidence the agent may read;
- files it may change, if any;
- exact returned format;
- stop condition.

## Default workflow

1. Use `file_finder` for frequent path, symbol, usage, configuration, and test lookup. It returns exact evidence and never edits.
2. Use `solution_planner` once requirements are stable. It writes an execution-ready plan and a contract per task; it never writes production code.
3. Complete foundation/shared-file changes sequentially under the main agent.
4. Run up to three `flutter_task_executor` instances only for dependency-ready contracts with disjoint allowed paths and isolated Git worktrees.
5. Integrate through the main agent, then run the full relevant suite.
6. Run platform verification and code review only after integration is green.

Copy `.agents/task-contract.yaml` to `.agents/tasks/<task-id>.yaml` and replace the example values before dispatch. The template itself must never be executed as a task.

## Model and scope rules

- Use `luna/low` for mechanical discovery.
- Use `terra/medium` for plan-following implementation; escalate only as recorded in the catalog.
- Use `sol/high` for architecture and complex verification.
- Reserve `sol/xhigh` for an unresolved release-critical review risk.
- Never run same-file writers concurrently.
- Executors cannot modify plans or shared files. They return a change request to the main agent.
- A prose plan without dependencies, file ownership, tests, commands, and stop conditions is not executable.

There is intentionally no documentation-only writer. Documentation updates belong to the code, test, verified decision, or incident that caused them.
