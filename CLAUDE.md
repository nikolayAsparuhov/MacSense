# MacSense — Project Rules

## Build hygiene (mandatory)

**At the end of every task, run a clean build and verify zero warnings + zero errors before reporting done.**

Command:

```bash
cd /Users/nikolai/Projects/Personal/MacSense
xcodebuild -project MacSense.xcodeproj -scheme MacSense -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "warning:|error:" | grep -v "Metadata extraction\|matching destinations\|RegisterExecutionPolicy"
```

If the grep prints nothing, build is clean.

If diagnostics appear, fix them before reporting the task complete:

- **Never suppress with `// swiftlint:disable`, `@available` shims, or unused-variable underscores** unless the rule itself is genuinely wrong for the case and the user has approved the suppression.
- **Never silence concurrency warnings** ("captured var self in concurrently-executing code", "main actor-isolated property cannot be accessed from outside actor", etc.) — fix the underlying isolation.
- **Never leave `// TODO` comments** for unresolved warnings.

## Adding a Swift file (do not run xcodegen)

`project.yml` is stale: `xcodegen generate` flattens the per-locale help folders
under `MacSense/Resources/Help/<lang>/` into one Resources directory and the
build fails with ~22 "Multiple commands produce ... .md" errors. Add new files to
`MacSense.xcodeproj/project.pbxproj` by hand instead — one `PBXBuildFile` entry,
one `PBXFileReference`, one line in the owning `PBXGroup`, one line in the
`Sources` build phase. Existing IDs follow `A1B2C3D4E5F60000AA0000<xx>` (build)
and `A1B2C3D4E5F60000FF0000<xx>` (file ref).

## Common warning categories + canonical fixes

| Warning | Fix |
|---|---|
| `reference to captured var 'self' in concurrently-executing code` | Re-capture `[weak self]` on the inner closure — don't rely on outer-scope capture chaining through nested Task/MainActor.run blocks. |
| `main actor-isolated static property cannot be accessed from outside actor` | Mark the static property `nonisolated` if its initializer is Sendable-safe; mark the init `nonisolated private init()` if it doesn't touch MainActor state. |
| `variable was never mutated; consider 'let'` | Change `var` to `let`. |
| `will never be executed` | Remove the dead branch — don't leave a "would-be" else arm anchored to a constant true/false. |
| `'onChange(of:initial:_:)' is only available in macOS 14.0` | Use the single-trailing-closure form `onChange(of: x) { newValue in ... }`. Deployment target is macOS 13. |

## Code style

- Tabs/spaces: follow existing project convention (4-space indent in `.swift`).
- File size: aim for ≤300 lines, hard cap 500. Split by responsibility, add a sibling file rather than growing one.
- Comments: only when *why* is non-obvious. No "what" comments duplicating identifier names.
- No emojis in code unless explicitly requested.
- Pure utility functions live in `Extensions/` or `Logic/` — no business logic, no UI dependencies.

## Concurrency

- Actors for I/O-heavy services (`StorageGraphScanner`, `CleaningEngine`, `ScanEngine`).
- `@MainActor` for ObservableObjects that publish to SwiftUI.
- `Task.detached(priority: .background)` for heavy on-launch work (e.g., snapshot hydration). Never block `init()` synchronously.
- `[weak self]` on every Task closure that captures self. Re-capture on every nested closure boundary.

## Build verification rule (recap)

The first thing after editing Swift code:

```bash
xcodebuild -project MacSense.xcodeproj -scheme MacSense -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "warning:|error:" | grep -v "Metadata extraction\|matching destinations\|RegisterExecutionPolicy"
```

Empty output → done. Non-empty → fix, repeat.
