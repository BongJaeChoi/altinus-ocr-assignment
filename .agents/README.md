# Subagent Use

`catalog.yaml` is a selection catalog, not authorization to spawn every role. The main agent owns the plan and final verification.

Before delegating, define:

- one independent question or file boundary;
- evidence the agent may read;
- files it may change, if any;
- exact returned format;
- stop condition.

Use `luna/low` for mechanical discovery, `terra/medium-high` for bounded analysis or routine device automation, and `sol/high` for implementation and complex verification. `sol/xhigh` is reserved for a final risk audit whose added rigor justifies the cost. Never run same-file writers concurrently.

There is intentionally no documentation-only writer. Documentation updates belong to the code, test, verified decision, or incident that caused them.
