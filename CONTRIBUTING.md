# Contributing to MacSense

Thanks for considering a contribution! This guide covers what we expect from PRs and issues so the maintainers can review them quickly.

## Reporting bugs

Open an [issue](https://github.com/nikolayAsparuhov/MacSense/issues/new) with:

- macOS version (`sw_vers -productVersion`)
- Mac model (`sysctl hw.model`)
- Steps to reproduce
- What you expected vs. what happened
- Logs if relevant — open Console.app, filter by "MacSense"
- Screenshots if visual

## Suggesting features

Open a [discussion](https://github.com/nikolayAsparuhov/MacSense/discussions) first if you're not sure the idea fits. For confirmed work, open an issue tagged `enhancement` and describe:

- The problem you're solving (not just the solution)
- Who benefits
- Sketch / screenshot if UI-related

## Pull requests

### Before opening a PR

1. **Build must be clean.** No warnings, no errors:

   ```bash
   xcodebuild -project MacSense.xcodeproj -scheme MacSense \
              -configuration Debug -destination 'platform=macOS' build 2>&1 \
     | grep -E "warning:|error:" \
     | grep -v "Metadata extraction\|matching destinations\|RegisterExecutionPolicy"
   ```

   Empty output = good.

2. **No `// TODO:` left behind** for things you can fix in the same PR.

3. **No suppression directives** unless the rule itself is genuinely wrong:
   - No `// swiftlint:disable`
   - No silenced concurrency warnings
   - No unused-variable underscores

4. **UI changes** include at least one before/after screenshot in the PR description.

### Code style

- 4-space indentation in Swift
- Tabs in shell scripts and pbxproj
- Files ≤ 300 lines preferred, 500 hard cap
- No comments that just describe what the code does — well-named identifiers handle that
- Comments OK when explaining *why* something non-obvious was done

### Architecture conventions

- **Models** are plain structs in `MacSense/Models/`
- **Services** are actors in `MacSense/Services/` for I/O-heavy work
- **ViewModels** (`AppState`) is `@MainActor` — never write to it from a background thread without `await MainActor.run`
- **Views** in `MacSense/Views/<section>/` use the existing `GlossyCard`, `Theme.Palette`, `HeroLanding` design primitives
- `Task.detached(priority: .background)` for any heavy on-launch work — never block `init()`
- `[weak self]` on every Task closure that captures self, including nested closures

### Adding a new dev tool to scan

Add an entry to `DevCacheCatalog.all` in `MacSense/Models/DevCacheTool.swift` with:

- `id` — short stable key
- `displayName` — what shows in the UI
- `symbol` — SF Symbol fallback
- `textMark` — 1–3 char badge (`"py"`, `"rb"`, `"go"`)
- `accent` — brand color
- `paths` — known cache locations (one per real directory the tool creates)
- `explanation` — one-sentence "what gets removed and what doesn't"

That's it — the scanner picks it up automatically.

### Commit style

[Conventional Commits](https://www.conventionalcommits.org):

```
feat: add NuGet cache scanner
fix: storage scan auto-triggered on idle
docs: clarify SMAppService limitation in README
refactor: hoist publicIP fetch into AppState
```

Co-author trailers welcome.

## Code of conduct

Be kind. No harassment, no slurs, no spam. Maintainers reserve the right to close issues / PRs / discussions that violate this.

## Questions?

Open a [discussion](https://github.com/nikolayAsparuhov/MacSense/discussions). We're happy to help you get oriented.
