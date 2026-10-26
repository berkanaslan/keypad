# Keypad for Mac

Keypad turns the Mac trackpad into a temporary numeric keypad. In any app, press a shortcut, tap numbers on the trackpad, and the number is typed into the field you were working in — no extra hardware, no network, nothing to set up beyond one permission. It is a native macOS app for the Mac App Store.

**Status:** Pre-release — repository foundations (RFC-0001) in place.

## Requirements

- macOS 26 or later
- Xcode 27

## Build and test

Run from the repository root.

```bash
swift format lint --recursive --strict Packages Keypad
```

```bash
swift test --package-path Packages/KeypadKit
```

```bash
xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Signed local builds and every other rule are in [AGENTS.md](AGENTS.md).

## Repository map

```
keypad/
├── .github/workflows/ci.yml   CI: lint, test, build
├── AGENTS.md                  rules for agents and contributors
├── CLAUDE.md                  imports AGENTS.md
├── Keypad.xcodeproj/          app target only
├── Keypad/                    app target: entry point, entitlements, assets, String Catalogs
├── Packages/KeypadKit/        all logic: KeypadCore, KeypadSystem, KeypadUI and their tests
└── docs/
    ├── glossary.md            domain terms
    ├── plans/                 implementation plans
    └── rfcs/                  design decisions
```

## Documentation

- [RFC process and index](docs/rfcs/README.md)
- [Glossary](docs/glossary.md)
- [Agent and contributor rules](AGENTS.md)

© 2026 Berkan Aslan. All rights reserved.
