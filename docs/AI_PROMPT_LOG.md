# AI Prompt and Decision Log

Append-only record for transparent AI use. Record user-visible requests and implementation decisions, not hidden reasoning. Never include credentials, private mail bodies, or unrelated personal data.

## Entry template

```text
### YYYY-MM-DD HH:MM KST — actor

- Request/prompt:
- Scope/files:
- Decision/result:
- Disposition: adopted | modified | rejected
- Verification/evidence:
```

---

### 2026-09-23 — user / bootstrap

- Request/prompt: Create and run a bootstrap for the assignment with Conventional Commits containing what/why, a model-and-effort subagent catalog, sub-10KB PRD and AGENTS context files, domain-first CONTEXT, prevention of documentation-only work, E2E guidance for Google ARTEMIS/Chrome DevTools MCP/Python CDP, and a prompt conversation log.
- Scope/files: repository governance, testing guidance, local Git hooks, and prompt logging only; no assignment implementation or external submission.
- Decision/result: Use an isolated local Git repository, require `What:` and `Why:` commit sections, reject docs-only staged changes by default, cap concurrent independent subagents at three, and explicitly separate Android/browser/iOS evidence.
- Disposition: adopted with safety constraints.
- Verification/evidence: bootstrap contract test and generated-repository checks are required before this entry is considered complete.
