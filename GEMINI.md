# Effective Coding & Surgical Execution Rules

## 1. Quota & Context Conservation (Anti-Overtooling Protocol)
* **Direct Inspection Over Auxiliary Scaffolding**: Never create temporary scratch scripts (e.g. custom Python parsers, regex tokenizers, or one-off test harnesses) for simple bug fixes, syntax errors, or localized issues.
* **Line-Targeted Triage**: When a compiler, linter, or runtime error provides a file path and line number, inspect that exact range directly with `view_file`. Spot the issue, apply the fix with `replace_file_content`, and verify once.
* **Minimize Tool Round-Trips**: Do not chain speculative tool calls. Plan tool actions mentally before invoking them to avoid wasting token quota and execution time.
* **Avoid Context Flooding**: Keep intermediate outputs compact. Do not dump multi-megabyte payloads or massive chunks into context when checking localized code.

## 2. Planning Mode Protocol
* **When to Plan**: Only create an `implementation_plan.md` and block for user approval when:
  - Performing major architectural refactors.
  - Adding complex, multi-module subsystems with high ambiguity.
  - Making breaking design changes requiring user decisions.
* **When NOT to Plan (Execute Immediately)**:
  - Trivially simple one-off bug fixes or syntax errors.
  - Minor follow-ups to an existing workflow.
  - Purely investigatory queries ("explain how X works", "where is Y defined?").
  - Formatting, renaming, or localized single-function tweaks.

## 3. Code Modification Standards
* **Surgical Edits**: Always use `replace_file_content` for precise, single contiguous block modifications. Never rewrite or overwrite an entire file when only a localized patch is needed.
* **Preserve Integrity**: Maintain existing comments, type annotations, and docstrings unless explicitly directed to modify them.
* **Single Source of Truth**: When working with modular code that compiles or bundles into a single distribution file (e.g. `bundle.py`), always edit the module source files directly and run the bundler, rather than manually patching the generated bundle.

## 4. Environment & Tool Execution Constraints
* **No `cd` Commands**: Never run shell `cd` commands. Always set the working directory via the execution parameter `Cwd`.
* **No Polling Loops**: Never run background commands that poll in a loop or sleep. Rely on reactive completion notifications.
* **Direct Error Resolution**: If a tool or command fails, diagnose the immediate failure cause directly rather than writing a meta-script to investigate the failure.

## 5. Luau / Roblox Executor Best Practices
* **Header Directives**: Bundled distribution scripts must maintain `--!nocheck` and `--!nolint` at line 1–2 before any non-comment tokens to prevent false-positive static linter warnings in in-app editors.
* **Adonis Anticheat Bypass**: Keep the raw Adonis bypass clean, un-pcalled, and un-scanned at the top of the bundle unless explicitly directed otherwise.
* **Virtual Input Safety**: Use internal virtual input functions rather than OS-level mouse clicks to avoid accidentally clicking overlay GUI toggles.
