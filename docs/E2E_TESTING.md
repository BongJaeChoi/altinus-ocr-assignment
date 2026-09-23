# E2E Testing Guide

## Evidence policy

Use deterministic framework integration tests for repeatability and real-device runs for camera truth. Record date, commit, device model, OS, build mode, scenario, result, and artifact path. Never infer iOS success from Android or browser tooling.

## Test layers

1. Unit: state machine, error mapping, stale-result protection, cleanup decisions.
2. Widget/component: permission, preview shell, processing, result, empty, error, retry.
3. Framework integration: full flow with fake camera/OCR adapters.
4. Native real device: actual permissions, preview, capture, OCR, lifecycle, orientation.

## Android — Google ARTEMIS

ARTEMIS is an Android UI automation system with CLI, MCP, and Python SDK surfaces. It does not currently establish native iOS coverage.

### Local setup

```bash
git clone https://github.com/google/artemis.git
cd artemis
./start.sh
```

Install its MCP configuration only after reviewing the generated command and repository path:

```bash
uv run artemis mcp --generate-config codex
# or install supported editor configurations
uv run artemis mcp --install all
```

### Exploration-first workflow

1. Connect exactly one intended Android device/emulator and confirm with `adb devices -l`.
2. Install a debug build containing no production secrets.
3. Explore the live UI before encoding a scenario; collect semantic labels and stable locators.
4. Prefer dynamic/text/accessibility locators; coordinates are a documented fallback.
5. Use the `flash` profile for routine flows. Escalate to `pro` for plan/checkpoint/ADB-heavy diagnosis.

Example exploratory run:

```bash
uv run artemis run \
  "Open the Altinus OCR app, grant camera permission, verify preview, capture printed text, wait for OCR, verify non-empty result, then retry" \
  --profile flash
```

Minimum Android scenarios:

- permission grant and happy path;
- first denial, permanent denial/settings recovery;
- repeated capture taps while processing;
- empty/unreadable text and injected OCR failure;
- background/foreground during preview and processing;
- portrait/landscape behavior if rotation is supported;
- retry after each recoverable failure.

On ARTEMIS/tool failure, preserve the command, device state, logs, screenshot, and diagnosis. Do not turn a tool failure into an app pass/fail claim.

## Chrome DevTools MCP

Chrome DevTools MCP controls and inspects Chrome. In this native assignment it is a support tool for Flutter DevTools, optional web harnesses, trace/network/console inspection, and browser-rendered artifacts. It is not a native camera E2E runner.

Suggested Codex MCP server command:

```text
npx -y chrome-devtools-mcp@latest --no-usage-statistics --no-performance-crux
```

Safety and use:

- Launch an isolated Chrome profile; connected clients can read and change browser content.
- Do not open private email, application portals, tokens, or unrelated signed-in sessions.
- Use screenshots, console messages, network requests, and performance traces only for browser/DevTools claims.
- Never cite a Chrome run as proof of native Android/iOS camera permission or capture behavior.

## Python CDP

Use a direct Chrome DevTools Protocol connection only for reproducible browser diagnostics not covered by the MCP workflow.

Start an isolated Chrome instance on macOS:

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/altinus-cdp-profile \
  about:blank
```

Discovery and connection outline:

```python
import json
import urllib.request

with urllib.request.urlopen("http://127.0.0.1:9222/json/version") as response:
    version = json.load(response)

print(version["webSocketDebuggerUrl"])
```

Connect a reviewed CDP client to that loopback WebSocket, subscribe only to required domains, save bounded artifacts, then close Chrome and remove the isolated temporary profile. Do not expose port 9222 beyond loopback. CDP results do not substitute for native app E2E.

## iOS verification

Because ARTEMIS and Chrome CDP do not cover native iOS camera behavior, use:

- framework integration tests with deterministic adapters;
- XCTest/XCUITest where stable native automation adds value;
- a real iPhone manual run for permission, preview, capture, OCR, lifecycle, rotation, and retry;
- Xcode/device logs and dated screenshots/video as evidence.

If no real iPhone is available, report iOS real-device verification as blocked, not passed.

## Run record template

```text
Date/time (KST):
Commit:
Platform/device/OS:
Build mode:
Scenario:
Expected:
Observed:
Result: PASS | FAIL | BLOCKED
Artifacts:
Notes/follow-up:
```
