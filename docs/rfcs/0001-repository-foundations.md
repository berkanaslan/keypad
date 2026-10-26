# RFC-0001: Repository Foundations

| Field      | Value                                        |
|------------|----------------------------------------------|
| Status     | Accepted                                     |
| Authors    | Claude (development lead), Berkan Aslan (PM) |
| Created    | 2026-10-26                                   |
| Depends on | RFC-0000                                     |

## 1. Summary

Set up the repository so that the first feature RFC (0002, keypad session) can be built, tested, signed and reviewed from day one: the final directory layout, the Xcode project and Swift package skeleton, signing and sandbox configuration, localization scaffolding, formatting, CI, and the documents that hold our rules (`AGENTS.md`, `CLAUDE.md`, `README.md`, glossary, RFC template).

No product behaviour is in scope. The app this RFC produces launches as an empty Dock app with an empty Settings window.

## 2. Repository layout

```
keypad/
├── .github/workflows/ci.yml
├── .gitignore
├── .swift-format
├── AGENTS.md                  rules for agents and contributors
├── CLAUDE.md                  imports AGENTS.md
├── README.md
├── Keypad.xcodeproj/          app target only
├── Keypad/                    app target sources and resources (synchronized folder)
│   ├── KeypadApp.swift        @main, composition root
│   ├── Keypad.entitlements
│   └── Resources/
│       ├── Assets.xcassets
│       ├── InfoPlist.xcstrings
│       └── Localizable.xcstrings
├── Packages/KeypadKit/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── KeypadCore/
│   │   ├── KeypadSystem/
│   │   └── KeypadUI/
│   └── Tests/
│       ├── KeypadCoreTests/
│       ├── KeypadSystemTests/
│       └── KeypadUITests/
└── docs/
    ├── glossary.md
    └── rfcs/
        ├── README.md          process and index
        ├── template.md
        └── NNNN-*.md
```

Code lives in exactly two roots, `Keypad/` and `Packages/KeypadKit/`; documentation and CI each have their own folder. A wrapping `App/` folder would add a path level without separating anything further.

## 3. Xcode project

- Written once in the synchronized-folder project format (`objectVersion = 77`, opens in Xcode 16 and later) and committed. One app target, `Keypad`, using synchronized folders: files added under `Keypad/` are picked up automatically, so the project file only changes when settings change.
- References the local package `Packages/KeypadKit` and links `KeypadCore`, `KeypadSystem` and `KeypadUI`.
- The shared scheme `Keypad` is committed (CI needs it).
- No `Info.plist` file: `GENERATE_INFOPLIST_FILE = YES` with `INFOPLIST_KEY_*` build settings.

| Setting | Value |
|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `io.berkan.keypad` |
| `PRODUCT_NAME` / display name | `Keypad` (the App Store name is decided in RFC-0006) |
| `MACOSX_DEPLOYMENT_TARGET` | `26.0` |
| `SWIFT_VERSION` | `6.0` (Swift 6 language mode, complete concurrency checking) |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS` | `YES` |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `0.1.0` / `1` |
| `CODE_SIGN_ENTITLEMENTS` / `ENABLE_HARDENED_RUNTIME` | `Keypad/Keypad.entitlements` / `YES` |
| `DEVELOPMENT_TEAM` / `CODE_SIGN_STYLE` | `4HYL3L2W4Z` / `Automatic` |
| `INFOPLIST_KEY_LSApplicationCategoryType` | `public.app-category.productivity` |
| `LOCALIZATION_PREFERS_STRING_CATALOGS` / `SWIFT_EMIT_LOC_STRINGS` | `YES` / `YES` |
| Development region / known regions | `en` / `en`, `tr`, `Base` |

Entitlements: `com.apple.security.app-sandbox` only. No network, file access or other capabilities.

## 4. Swift package

- `swift-tools-version: 6.2`, `platforms: [.macOS(.v26)]`, `defaultLocalization: "en"`, Swift 6 language mode for every target.
- Three library products and targets, matching RFC-0000 §9.2:

| Target | Depends on | Notes |
|---|---|---|
| `KeypadCore` | — | Imports Foundation only. Enforced by review and by the dependency graph. |
| `KeypadSystem` | `KeypadCore` | AppKit, Carbon, CoreGraphics adapters. |
| `KeypadUI` | `KeypadCore` | SwiftUI; owns its `Localizable.xcstrings` (accessed through `Bundle.module`). |

- One test target per module using Swift Testing, each with a smoke test so the pipeline is real from the first commit.
- No third-party dependencies. Adding one requires an RFC.

## 5. Signing

- Only team `4HYL3L2W4Z`, pinned in the project. `AGENTS.md` forbids any other team or identity on the development machine.
- Prerequisite for the PM: add the project owner's Apple developer account in Xcode → Settings → Accounts. Automatic signing cannot create the development profile without it. Until then, local command-line builds sign with `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=4HYL3L2W4Z`.
- CI builds unsigned (`CODE_SIGNING_ALLOWED=NO`). Distribution signing arrives with RFC-0007.

## 6. Localization

- String Catalogs from day one: `Localizable.xcstrings` in the app target and in `KeypadUI`, plus `InfoPlist.xcstrings` for the display name.
- Rule: a change that adds a user-facing string adds both its English and Turkish values in the same commit. The development lead translates; the PM reviews Turkish.
- No hard-coded user-facing strings outside catalogs.

## 7. Code quality

- Formatting with `swift format`, which ships with the Xcode toolchain, configured by `.swift-format` (4-space indentation, 120-column lines; remaining rules left to the builder). CI runs `swift format lint --recursive --strict`.
- Warnings are errors, in Xcode and in `swift build`.
- SwiftLint is not used: Apple's formatter covers what we need without a third-party tool.

## 8. Testing

- `swift test --package-path Packages/KeypadKit` runs all package tests.
- `xcodebuild -scheme Keypad build` verifies that the app target compiles and links.
- Manual QA (real trackpad) starts with RFC-0002.

## 9. Continuous integration

- GitHub Actions workflow `.github/workflows/ci.yml`.
- Triggers: pushes to `develop` and `main`, and pull requests into them. Feature branches are not built on push, to save macOS minutes.
- Runner: GitHub's `xcode-27` preview image (macOS 27, arm64) with Xcode 27.0 (27A266a, the local build) selected explicitly. The `macos-26` image ships only Xcode 26.x; switch to it once it carries Xcode 27.
- Steps: lint → package tests → unsigned app build.
- Cost: the repository is private, so macOS minutes count ten times against the plan's quota. One run should take about five minutes.
- Xcode Cloud is reconsidered in RFC-0007 for release builds; it needs an App Store Connect app record first.

## 10. Documents

| File | Content |
|---|---|
| `AGENTS.md` | Single source of truth for agents and contributors: product summary, language rules, git workflow, RFC process, architecture rules (dependency direction, no AppKit in Core, protocols at boundaries), allowed APIs (public only, no network), signing rule, localization rule, code style, build/test/lint commands, definition of done. |
| `CLAUDE.md` | Imports `AGENTS.md`, so every tool reads the same rules. |
| `README.md` | What Keypad is, status, requirements (macOS 26, Xcode 27), build and test commands, repository map, links to RFCs and glossary. Proprietary; all rights reserved; no license file. |
| `docs/glossary.md` | Domain terms: session, capture panel, HUD, buffer, commit, commit key, sticky, active area, layout, cell, action, target app, hand-off, reclaim. |
| `docs/rfcs/README.md` | RFC process, statuses, numbering, index table. |
| `docs/rfcs/template.md` | Sections: Summary, Motivation, Design, Alternatives considered, Risks, Rollout, Open questions. |

## 11. Definition of done

- `swift format lint` passes; `swift test` passes; `xcodebuild -scheme Keypad build` succeeds locally and in CI.
- The built app is sandboxed: `Keypad.entitlements` holds only the sandbox entitlement, and `codesign -d --entitlements -` shows nothing else except the `get-task-allow` that every Apple Development signature injects (distribution signing removes it). The app shows a placeholder Dock icon and an empty Settings window, and follows light and dark mode.
- English and Turkish catalogs exist and contain the display name.
- CI is green on `develop`.
- All documents in §10 exist and agree with RFC-0000.

## 12. Alternatives considered

| Alternative | Decision |
|---|---|
| XcodeGen or Tuist to generate the project | Rejected: an extra tool, and synchronized folders already remove the merge-conflict pain they solve. |
| One module instead of three | Rejected in RFC-0000 §9.2. |
| SwiftLint | Rejected: third-party; `swift format` is Apple's. |
| Xcode Cloud for CI now | Deferred to RFC-0007. |
| An `App/` folder around the code | Not needed (§2). |

## 13. Open questions

- **Bundle identifier `io.berkan.keypad`.** It can never change once the app is on the App Store. The PM confirms it.
- **Pushing to GitHub.** CI needs `develop` (and later `main`) on the remote. The PM confirms before the first push.
