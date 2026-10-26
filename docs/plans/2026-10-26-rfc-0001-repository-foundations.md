# RFC-0001 Repository Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A repository where an empty, sandboxed, signed Keypad Dock app builds, its package tests pass, formatting is enforced, CI is defined, and the project's rules are written down.

**Architecture:** All logic lives in the local Swift package `Packages/KeypadKit` (targets `KeypadCore`, `KeypadSystem`, `KeypadUI`); the Xcode project holds only the thin `Keypad` app target, which links the three products. Each module gets a smoke test so the pipeline is real.

**Tech Stack:** Xcode 27, Swift 6.4 toolchain (Swift 6 language mode), SwiftPM tools 6.2, Swift Testing, SwiftUI, `swift format`, GitHub Actions.

**Spec:** `docs/rfcs/0001-repository-foundations.md` (umbrella: `docs/rfcs/0000-vision-and-architecture.md`)

## Global Constraints

- Branch: all work on `chore/repository-foundations` (from `develop`); merged into `develop` with `--no-ff` at the end. Nothing is pushed without the PM's explicit OK.
- Commits: Conventional Commits, English, each ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Deployment target macOS `26.0`; `swift-tools-version: 6.2`; `platforms: [.macOS(.v26)]`; Swift 6 language mode everywhere.
- Bundle identifier `io.berkan.keypad`; product and display name `Keypad`; `MARKETING_VERSION = 0.1.0`; `CURRENT_PROJECT_VERSION = 1`.
- Signing: `DEVELOPMENT_TEAM = 4HYL3L2W4Z`, `CODE_SIGN_STYLE = Automatic` in the project. Never any other team. Until the project owner's developer account is in Xcode's accounts, local builds override with `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=4HYL3L2W4Z` on the command line only.
- Entitlements: `com.apple.security.app-sandbox = true` only; hardened runtime on.
- No third-party dependencies; no network.
- Localization: development region `en`; every catalog has `en` and `tr` values; no user-facing string outside a String Catalog.
- Formatting: `.swift-format` with 4-space indentation and 120-column lines; `swift format lint --recursive --strict` must print nothing.
- Warnings are errors: `.treatAllWarnings(as: .error)` in every package target; `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` in the app target.
- zsh has `noclobber` on: overwrite files with the Write tool, or `>|` in the shell.

## Review Focus

1. **Wrong signing team.** The built app must report `TeamIdentifier=4HYL3L2W4Z` — checked in Task 2 Step 6.
2. **Fresh clone.** A clean clone must lint, test and build with no local state (user data ignored, shared scheme committed, no absolute paths) — checked in Task 5 Step 1.
3. **Turkish system language.** Turkish resources must ship in both the package bundle and the app bundle — checked by `placeholderIsTranslatedToTurkish` (Task 1) and the `tr.lproj` check (Task 2 Step 7).
4. **Sandbox drift.** The Release build must carry only the sandbox entitlement — checked in Task 2 Step 6.
5. **CI/local mismatch.** CI must run the exact commands used locally — Task 3 runs every workflow command locally before committing.

---

### Task 1: KeypadKit package with three modules

**Files:**
- Create: `.gitignore`
- Create: `.swift-format`
- Create: `Packages/KeypadKit/Package.swift`
- Create: `Packages/KeypadKit/Sources/KeypadCore/CoreModule.swift`
- Create: `Packages/KeypadKit/Sources/KeypadSystem/SystemModule.swift`
- Create: `Packages/KeypadKit/Sources/KeypadUI/SettingsView.swift`
- Create: `Packages/KeypadKit/Sources/KeypadUI/Bundle+KeypadUI.swift`
- Create: `Packages/KeypadKit/Sources/KeypadUI/Resources/Localizable.xcstrings`
- Test: `Packages/KeypadKit/Tests/KeypadCoreTests/CoreModuleTests.swift`
- Test: `Packages/KeypadKit/Tests/KeypadSystemTests/SystemModuleTests.swift`
- Test: `Packages/KeypadKit/Tests/KeypadUITests/LocalizationTests.swift`

**Interfaces:**
- Produces: library products `KeypadCore`, `KeypadSystem`, `KeypadUI`.
- Produces: `public enum CoreModule { public static let name: String }` (`"KeypadCore"`), `public enum SystemModule { public static let name: String }` (`"KeypadSystem"`).
- Produces: `public struct SettingsView: View { public init() }` — shows the localized key `settings.placeholder`.
- Produces: `extension Bundle { static var keypadUI: Bundle }` (internal; returns `.module`).

- [ ] **Step 1: Confirm branch**

Run: `git branch --show-current`
Expected: `chore/repository-foundations`

- [ ] **Step 2: Write `.gitignore` and `.swift-format`**

`.gitignore` ignores: `.DS_Store`, `.build/`, `.swiftpm/`, `build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`.
`.swift-format` is `swift format dump-configuration` output with `"indentation": { "spaces": 4 }` and `"lineLength": 120`.

- [ ] **Step 3: Write the failing tests**

```swift
// CoreModuleTests.swift
import Testing
@testable import KeypadCore

@Test func moduleLinks() {
    #expect(CoreModule.name == "KeypadCore")
}
```

```swift
// SystemModuleTests.swift
import Testing
@testable import KeypadSystem

@Test func moduleLinks() {
    #expect(SystemModule.name == "KeypadSystem")
}
```

```swift
// LocalizationTests.swift
import Foundation
import Testing
@testable import KeypadUI

@Test func shipsEnglishAndTurkish() {
    #expect(Set(Bundle.keypadUI.localizations).isSuperset(of: ["en", "tr"]))
}

@Test func placeholderIsTranslatedToTurkish() throws {
    let path = try #require(Bundle.keypadUI.path(forResource: "tr", ofType: "lproj"))
    let turkish = try #require(Bundle(path: path))
    #expect(turkish.localizedString(forKey: "settings.placeholder", value: nil, table: nil) == "Ayarlar burada görünecek.")
}
```

(`String(localized:bundle:locale:)` does not select a language — `locale` only formats interpolations — so the Turkish check loads the `tr.lproj` sub-bundle.)

- [ ] **Step 4: Run tests to verify they fail**

Run: `swift test --package-path Packages/KeypadKit`
Expected: FAIL — no `Package.swift` yet.

- [ ] **Step 5: Write `Packages/KeypadKit/Package.swift`**

Package `KeypadKit`, `defaultLocalization: "en"`, `platforms: [.macOS(.v26)]`, three library products of the same names, targets:
`KeypadCore` (no dependencies), `KeypadSystem` (→ `KeypadCore`), `KeypadUI` (→ `KeypadCore`, `resources: [.process("Resources")]`), and test targets `KeypadCoreTests`, `KeypadSystemTests`, `KeypadUITests` each depending on its module. Every target gets `swiftSettings: [.treatAllWarnings(as: .error)]`, defined once in a shared constant.

- [ ] **Step 6: Implement the modules**

`CoreModule.name = "KeypadCore"`; `SystemModule.name = "KeypadSystem"`; `Bundle.keypadUI` returns `.module`; `SettingsView` renders `Text("settings.placeholder", bundle: .keypadUI)` with standard padding and a minimum frame of 420 × 240 points.
`Localizable.xcstrings`: source language `en`, key `settings.placeholder` = en `Settings will appear here.`, tr `Ayarlar burada görünecek.`, both `translated`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit`
Expected: 4 tests passed, 0 failures.

- [ ] **Step 8: Lint**

Run: `swift format lint --recursive --strict Packages`
Expected: no output, exit code 0.

- [ ] **Step 9: Commit**

```bash
git add .gitignore .swift-format Packages
git commit -m "chore(package): scaffold KeypadKit with Core, System and UI modules"
```

---

### Task 2: Keypad app target

**Files:**
- Create: `Keypad.xcodeproj/project.pbxproj`
- Create: `Keypad.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `Keypad.xcodeproj/xcshareddata/xcschemes/Keypad.xcscheme`
- Create: `Keypad/KeypadApp.swift`
- Create: `Keypad/Keypad.entitlements`
- Create: `Keypad/Resources/Assets.xcassets/Contents.json`
- Create: `Keypad/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Keypad/Resources/InfoPlist.xcstrings`
- Create: `Keypad/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: products `KeypadCore`, `KeypadSystem`, `KeypadUI`; `SettingsView()` (Task 1).
- Produces: scheme `Keypad`; build product `Keypad.app`.

- [ ] **Step 1: Write `KeypadApp.swift`**

`@main struct KeypadApp: App` whose only scene is `Settings { SettingsView() }` (a Dock app with no main window; ⌘, opens Settings). It imports `KeypadUI` only.

- [ ] **Step 2: Write entitlements, assets and catalogs**

- `Keypad.entitlements`: plist with `com.apple.security.app-sandbox` = `true`, nothing else.
- `Assets.xcassets`: `AppIcon` set with the standard macOS slots and no images (the placeholder icon until RFC-0006).
- `InfoPlist.xcstrings`: `CFBundleDisplayName` and `CFBundleName` = `Keypad` in `en` and `tr`.
- `Localizable.xcstrings`: source language `en`, empty `strings` (the app target has no strings of its own yet).

- [ ] **Step 3: Write the Xcode project**

Hand-written `project.pbxproj`, `objectVersion = 77`:
- A `PBXFileSystemSynchronizedRootGroup` for `Keypad/`, with a `PBXFileSystemSynchronizedBuildFileExceptionSet` keeping `Keypad.entitlements` out of target membership.
- `XCLocalSwiftPackageReference` with `relativePath = Packages/KeypadKit`, and `XCSwiftPackageProductDependency` entries for the three products, linked by the `Keypad` target.
- `developmentRegion = en`; `knownRegions = (en, tr, Base)`.
- Build settings: every value in Global Constraints, plus `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.productivity`, `INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Berkan Aslan. All rights reserved."`, `CODE_SIGN_ENTITLEMENTS = Keypad/Keypad.entitlements`, `ENABLE_HARDENED_RUNTIME = YES`, `SWIFT_VERSION = 6.0`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `SWIFT_EMIT_LOC_STRINGS = YES`, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- Debug and Release configurations.

The shared scheme `Keypad` builds and launches the `Keypad` target; its Test action is empty (package tests run through `swift test`).

- [ ] **Step 4: Verify the project opens cleanly**

Run: `xcodebuild -project Keypad.xcodeproj -list`
Expected: target `Keypad`, configurations `Debug` and `Release`, scheme `Keypad`; package `KeypadKit` resolved, no errors.

- [ ] **Step 5: Build Debug and Release (signed)**

Run:
```bash
for c in Debug Release; do xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration $c \
  -derivedDataPath build/DerivedData CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=4HYL3L2W4Z build | tail -1; done
```
Expected: `** BUILD SUCCEEDED **` twice.

- [ ] **Step 6: Verify team and entitlements**

Run: `codesign -dvv build/DerivedData/Build/Products/Release/Keypad.app 2>&1 | grep TeamIdentifier`
Expected: `TeamIdentifier=4HYL3L2W4Z`

Run: `codesign -d --entitlements - --xml build/DerivedData/Build/Products/Release/Keypad.app | plutil -p -`
Expected: exactly `"com.apple.security.app-sandbox" => true`. (Debug additionally carries Xcode's injected `com.apple.security.get-task-allow`; that is expected.)

- [ ] **Step 7: Verify bundle metadata and Turkish resources**

Run: `plutil -extract CFBundleIdentifier raw build/DerivedData/Build/Products/Release/Keypad.app/Contents/Info.plist; plutil -extract LSMinimumSystemVersion raw build/DerivedData/Build/Products/Release/Keypad.app/Contents/Info.plist; ls build/DerivedData/Build/Products/Release/Keypad.app/Contents/Resources | grep lproj`
Expected: `io.berkan.keypad`, `26.0`, and both `en.lproj` and `tr.lproj`.

- [ ] **Step 8: Build unsigned (the CI configuration)**

Run: `xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build | tail -1`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Launch check**

Run: `open build/DerivedData/Build/Products/Release/Keypad.app && sleep 2 && pgrep -x Keypad`
Expected: a PID. The PM confirms visually: a Dock icon (generic placeholder); ⌘, opens a Settings window reading "Settings will appear here." and following light/dark mode. Quit the app afterwards.

- [ ] **Step 10: Lint and commit**

Run: `swift format lint --recursive --strict Packages Keypad` → no output.

```bash
git add Keypad.xcodeproj Keypad
git commit -m "chore(app): add sandboxed Keypad app target linking KeypadKit"
```

---

### Task 3: Continuous integration

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: scheme `Keypad` (Task 2); package path `Packages/KeypadKit` (Task 1).

- [ ] **Step 1: Write the workflow**

Workflow `CI`: triggers `push` and `pull_request` on branches `develop` and `main`; `concurrency` group per ref with `cancel-in-progress: true`. One job `verify` on `macos-26`, `timeout-minutes: 20`, steps:
1. `actions/checkout@v5`
2. Select Xcode 27: `sudo xcode-select -s /Applications/Xcode_27.0.app` (confirm the exact path in the actions/runner-images macOS 26 README when writing; if Xcode 27 is not on `macos-26`, use the `xcode-27` image label it documents), then `xcodebuild -version`.
3. Lint: `swift format lint --recursive --strict Packages Keypad`
4. Test: `swift test --package-path Packages/KeypadKit`
5. Build: `xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`

- [ ] **Step 2: Validate YAML**

Run: `ruby -ryaml -e 'w = YAML.load_file(".github/workflows/ci.yml"); puts w["jobs"]["verify"]["steps"].size'`
Expected: `5`

- [ ] **Step 3: Run the workflow's commands locally**

Run steps 3–5 of the workflow verbatim from the repository root.
Expected: lint prints nothing; tests pass; `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: lint, test and build on develop and main"
```

---

### Task 4: Project documents

**Files:**
- Create: `AGENTS.md`
- Create: `CLAUDE.md`
- Modify: `README.md`
- Create: `docs/glossary.md`
- Create: `docs/rfcs/README.md`
- Create: `docs/rfcs/template.md`

**Interfaces:**
- Consumes: the commands verified in Tasks 1–3, copied verbatim.

- [ ] **Step 1: Write `AGENTS.md`**

Sections, in this order, each stating rules as short imperatives:
1. Product (two sentences from RFC-0000 §1) and links to RFC-0000 and the glossary.
2. Language: English for code, docs, RFCs and commits; the PM may write Turkish or English in chat.
3. Process: one RFC at a time (`docs/rfcs/`); implementation plans in `docs/plans/YYYY-MM-DD-<topic>.md`; the PM accepts RFCs.
4. Git: branch from `develop` before the first commit (`feature/`, `bugfix/`, `chore/`, `refactor/`, `docs/`); merge into `develop` with `--no-ff`; `main` only receives `develop` at release (`--no-ff`, tag `vX.Y.Z`); Conventional Commits; never push without the PM's OK.
5. Architecture: module table from RFC-0000 §9.2; dependencies point to `KeypadCore`; no AppKit in `KeypadCore`; system services behind Core protocols.
6. Platform rules: public APIs only, no private frameworks, no network, App Sandbox, macOS 26 minimum, SwiftUI first and AppKit only where SwiftUI lacks the API, system materials and controls only.
7. Signing: team `4HYL3L2W4Z` only; never any other team or identity on the machine; the command-line identity override from Global Constraints.
8. Localization: String Catalogs only; `en` and `tr` in the same commit as the string.
9. Code style: self-explanatory code; comments only for a non-obvious reason; DRY, SOLID, KISS; warnings are errors; `swift format` config is the source of truth.
10. Commands: lint, test, signed build, unsigned build — exactly as in Tasks 1–3.
11. Definition of done: lint clean, tests pass, both languages present, RFC and glossary updated when behaviour or terms change.

- [ ] **Step 2: Write `CLAUDE.md`**

Content: one line, `@AGENTS.md`.

- [ ] **Step 3: Rewrite `README.md`**

Title `Keypad for Mac`, one-paragraph description, status (`Pre-release — RFC-0001 implemented`), requirements (macOS 26, Xcode 27), the commands from AGENTS.md §10, a repository map (RFC-0001 §2), links to `docs/rfcs/README.md`, `docs/glossary.md`, `AGENTS.md`, and `© 2026 Berkan Aslan. All rights reserved.`

- [ ] **Step 4: Write `docs/glossary.md`**

Alphabetical table *Term | Meaning* covering exactly: action, active area, buffer, capture panel, cell, commit, commit key, hand-off, HUD, layout, reclaim, session, sticky, target app. Definitions follow RFC-0000 §8 and §9.3.

- [ ] **Step 5: Write `docs/rfcs/README.md` and `docs/rfcs/template.md`**

README: purpose, numbering (`NNNN-kebab-title.md`, next free number), statuses (`Draft → Accepted → Implemented`, or `Superseded`), cadence (one at a time), who accepts (the PM), and an index table *RFC | Title | Status* listing 0000 (Accepted) and 0001 (Accepted).
Template: the header table (Status, Authors, Created, Depends on) and the sections Summary, Motivation, Design, Alternatives considered, Risks, Rollout, Open questions.

- [ ] **Step 6: Verify links and commands**

Run: `for f in docs/rfcs/0000-vision-and-architecture.md docs/rfcs/0001-repository-foundations.md docs/glossary.md docs/rfcs/README.md docs/rfcs/template.md AGENTS.md; do test -f $f && echo ok $f; done`
Expected: six `ok` lines. Every command block in `AGENTS.md` and `README.md` was copied from a step that passed.

- [ ] **Step 7: Commit**

```bash
git add AGENTS.md CLAUDE.md README.md docs/glossary.md docs/rfcs/README.md docs/rfcs/template.md
git commit -m "docs: add agent rules, README, glossary and RFC process"
```

---

### Task 5: Final verification and merge

**Files:**
- Modify: `docs/rfcs/0001-repository-foundations.md` (status)
- Modify: `docs/rfcs/README.md` (index)

- [ ] **Step 1: Verify from a fresh clone**

Run:
```bash
D=$(mktemp -d) && git clone -q --branch chore/repository-foundations . "$D/keypad" && cd "$D/keypad" && \
swift format lint --recursive --strict Packages Keypad && swift test --package-path Packages/KeypadKit 2>&1 | tail -1 && \
xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build | tail -1
```
Expected: no lint output, a passing test summary, `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Check the definition of done**

Walk RFC-0001 §11 point by point; every point maps to a passed step above (CI green on `develop` is checked after the PM approves the first push).

- [ ] **Step 3: Mark RFC-0001 Implemented and commit**

Set `Status` to `Implemented` in the RFC and in the index.

```bash
git add docs/rfcs
git commit -m "docs(rfc): mark RFC-0001 implemented"
```

- [ ] **Step 4: Merge into develop**

```bash
git checkout develop
git merge --no-ff chore/repository-foundations -m "Merge branch 'chore/repository-foundations' into develop"
git branch -d chore/repository-foundations
```
Expected: merge commit on `develop`; `git log --graph` shows the branch.

- [ ] **Step 5: Ask the PM about pushing**

Stop. Ask the PM for permission to push `develop` and `main` to `origin` so CI can run. Push only on an explicit yes.
