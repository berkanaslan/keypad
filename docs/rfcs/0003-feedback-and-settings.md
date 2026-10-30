# RFC-0003: Feedback and Settings

| Field      | Value                                        |
|------------|----------------------------------------------|
| Status     | Accepted                                     |
| Authors    | Claude (development lead), Berkan Aslan (PM) |
| Created    | 2026-10-30                                   |
| Depends on | RFC-0000, RFC-0002                           |

## Summary

Give Keypad its own key sounds and a choice of haptic pattern, and the Settings window, persistence and lifecycle controls that RFC-0000 planned as RFC-0004. The PM merged the two RFCs on 2026-10-30, because the feedback choices only make sense once Settings can show them.

Keypad ships four original key sounds and the three system haptic patterns. Feedback, the shortcut, the active trackpad area and the sticky behaviour become settings that persist. The Dock menu can disable and enable Keypad, and Settings can turn on launch at login.

## Motivation

- **Feedback (QA, RFC-0002):** the haptic is faint, and the sound ("Tink") reads as a Mac alert, not a key. The PM wants a sound like the iPhone's on-screen keyboard click.
- **Settings:** RFC-0002 shipped fixed defaults. Users can't change the shortcut, shrink the active area, turn off sticky sessions (the PM noticed "the overlay stays open"), or switch feedback off. RFC-0000 G1, G2, G5 and G7 all need a Settings window.

## Design

### Scope

| In scope | Deferred to |
|---|---|
| Four bundled key sounds, three haptic patterns, a feedback player that follows the settings | — |
| Settings model, persistence, Settings window with General, Keypad and Feedback tabs | — |
| Shortcut recorder, active-area editor, stay-open toggle | — |
| Dock menu with Disable/Enable Keypad and Settings…, disabled state | — |
| Launch at login toggle (off by default) | RFC-0005 offers it pre-selected during onboarding |
| Permission state in Settings | RFC-0005 |
| Layout picker | RFC-0008 adds it with the layout editor |

### Key sounds

The iPhone's keyboard click is Apple's own recording. macOS doesn't offer it to apps, and copying it into an App Store app is not an option. Instead Keypad ships four original sounds made for it, synthesised in code from the parameters below. On 2026-10-30 the PM listened to them, each as single taps and a fast six-tap run, and chose to ship all four with **Wood** as the default.

| Sound (EN / TR) | Character | Body: frequency Hz · level · decay ms | Transient: band-passed noise | Length | Peak |
|---|---|---|---|---|---|
| **Wood / Ahşap** (default) | Short wooden tock, mid-pitched | 1150 · 1.0 · 10, 2700 · 0.5 · 5, 4400 · 0.25 · 3 | 3000 Hz, Q 1.0, level 0.3, decay 1.5 ms | 60 ms | −14 dBFS |
| **Soft / Yumuşak** | Soft tick over a low tock, closest to the iPhone | 190 · 0.6 · 12, 1600 · 0.3 · 4 | 2400 Hz, Q 1.2, level 1.0, decay 4 ms | 50 ms | −14 dBFS |
| **Deep / Derin** | Lower and rounder, like a fingertip on a desk | 650 · 1.0 · 14, 1500 · 0.4 · 7 | 1800 Hz, Q 1.0, level 0.25, decay 2 ms | 70 ms | −13 dBFS |
| **Crisp / İnce** | Very short, high and light | 3400 · 1.0 · 3, 6100 · 0.4 · 2 | 5000 Hz, Q 1.0, level 0.3, decay 1 ms | 25 ms | −16 dBFS |

- The generator from the listening session is committed as `Tools/KeySounds/generate.swift`. It writes the files the PM heard; the build uses its output, uncompressed, 48 kHz, mono.
- The sound plays when a tap completes (F10), at the Mac's output volume; a muted Mac plays nothing. There is no separate volume control.
- Rapid taps must not clip or lag: each sound is loaded once, before the first session, and a new tap may cut the previous sound short.

### Haptic patterns

macOS lets apps choose one of three haptic patterns and nothing else; strength can't be set through a public API. Keypad offers all three (PM, 2026-10-30):

| Pattern (EN / TR) | `NSHapticFeedbackManager.FeedbackPattern` |
|---|---|
| Standard / Standart | `.generic` (today's pattern) |
| Light / Hafif | `.alignment` |
| Pronounced / Belirgin | `.levelChange` |

- The haptic plays on touch-down (F10), with `performanceTime: .now`.
- The names are the development lead's guess at how the patterns feel. QA checks the order on a real trackpad and renames them if it's wrong.
- **Default:** Standard until the PM picks one by feel in QA (open question 1).
- Trackpads without Force Touch play nothing. The setting stays available.

### Settings model (`KeypadCore`)

One value type holds every setting. It's `Codable`, `Equatable` and `Sendable`, and every field has a default:

| Setting | Type | Default |
|---|---|---|
| `isEnabled` | `Bool` | on |
| `shortcut` | `Shortcut` (virtual key code + `ShortcutModifiers`: ⌘ ⌃ ⌥ ⇧) | ⌃⌥K |
| `activeArea` | `ActiveArea` | whole surface |
| `staysOpenAfterTyping` | `Bool` | on |
| `haptics` | on/off + `HapticPattern` (`standard`, `light`, `pronounced`) | on, Standard |
| `sound` | on/off + `KeySound` (`wood`, `soft`, `deep`, `crisp`) | on, Wood |

- Launch at login isn't stored: `SMAppService` is its source of truth, so Settings can never disagree with System Settings.
- **Validation lives in Core:**
  - A `Shortcut` is valid when the key is F1–F20 (with or without modifiers), or when it uses **at least two modifiers, one of them ⌘ or ⌃**, such as ⌃⌥K or ⌘⇧K.
    - With one modifier, almost every letter is already an app shortcut (⌘Q, ⌘C) or a text-editing key (⌃A, ⌃K). A Carbon hotkey would take it away from every app.
    - Since macOS 15, ⌥-only and ⌥⇧-only hotkeys are no longer accepted.
    - fn/🌐 is never part of a shortcut, and modifier-only shortcuts are invalid (F3, F4). The `.function` and `.numericPad` flags that macOS sets on arrow and function keys are ignored.
  - `ActiveArea` keeps itself inside the trackpad and at least **20 %** of its width and height. A degenerate area used to crash hit-testing; it can't be stored now.
- **Decoding is forgiving:** a missing or unreadable field falls back to its default, so future versions can add settings without a migration step.
- `SessionConfiguration` is built from the settings: layout Numpad, the active area, sticky. A change applies from the next session; Settings is hidden while a session is open anyway (F9).

New Core protocols: `SettingsStore` (load, save) and `LoginItemController` (status, register, unregister), both named in RFC-0000 §9.2.

### Persistence (`KeypadSystem`)

`UserDefaultsSettingsStore` saves the whole settings value as one JSON-encoded entry in the app's `UserDefaults`, with a version number. One entry is written atomically and versioned in one place, and Core stays free of `@AppStorage`. Settings save as soon as they change; there is no Apply button.

### Feedback player (`KeypadSystem`)

`SystemFeedbackPlayer` gets the current feedback settings from the composition root whenever they change. It plays the selected pattern on `.touchDown` and the selected sound on `.keyAccepted`, and does nothing for a kind that's off. The sound files live in `KeypadSystem`'s resources.

### Settings window

Opening and look:
- A regular window titled "Keypad Settings".
- Clicking the Dock icon opens it, and so do the Dock menu's "Settings…" and ⌘, in the app menu.
- Launching Keypad opens no window, as today. A launch at login and a launch from Finder can't be told apart without extra work, and RFC-0005 owns the first-run experience.
- Apple-standard toolbar tabs, each hosting a SwiftUI `Form` with the grouped style used by System Settings.

Why not SwiftUI's `Settings` scene:
- That scene can only be opened from inside SwiftUI (`openSettings`).
- The Dock click and the Dock menu arrive in the app delegate.
- The only other way in, the `showSettingsWindow:` selector, is undocumented and forbidden by AGENTS.md.

So the window is an AppKit window (`NSTabViewController` with toolbar tabs) whose tabs are SwiftUI views. It is ordered out during a session and comes back afterwards, as today.

**General**
- *Enable Keypad*: the same switch as the Dock menu.
- *Open at login*: registers or unregisters `SMAppService.mainApp`. It shows the real status. If macOS needs the user's approval, a note and an "Open Login Items…" button (`SMAppService.openSystemSettingsLoginItems()`) appear. It is off until the user turns it on, because App Review Guideline 2.4.5(iii) requires consent first.
- *Shortcut*: the recorder (below).

**Keypad**
- *Active area*: the editor (below).
- *Stay open after typing*: the sticky switch, with a footer explaining it.

**Feedback**
- *Haptic feedback*: on/off, and a pattern picker. Choosing a pattern performs it once; it is felt when the choice is made with a trackpad click, because the finger is still on the surface (F10).
- *Key sound*: on/off, and a sound picker. Choosing a sound plays it once.
- A picker is disabled while its switch is off.

There's no About tab. The app menu's standard "About Keypad" panel shows the version and the copyright from `Info.plist`. A tab would only repeat it.

### Shortcut recorder

A control built in-house: no third-party dependency (AGENTS.md §9), and only a small subset of what such packages do is needed.

- Its label shows the current shortcut. Key names come from the active keyboard layout, the way the decimal separator does in RFC-0002.
- Clicking it starts recording ("Type a shortcut…"). While recording, the global shortcut is unregistered, so pressing the current shortcut records it instead of opening a session.
- **The next valid key combination** becomes the new shortcut. Keypad registers it right away. If macOS refuses it, an error shows and the previous shortcut stays.
- **Esc** or a click elsewhere cancels.
- **An invalid combination** shows how to make a valid one and keeps recording.
- **Reset** restores ⌃⌥K.
- **While Keypad is disabled**, a new shortcut is checked by registering it briefly and unregistering it again.
- **A refused saved shortcut:** if the saved shortcut can't be registered later, for example after a macOS update or because another app took it, the refusal message stays under the recorder until a working shortcut is recorded. That covers launch too. This applies only while Keypad is enabled.
- Some shortcuts are taken by macOS itself (⌘Space, ⌃↑). They may register yet never reach Keypad, and no public API reveals them. The recorder can't warn about these; QA checks that the error path at least covers refused registrations.

### Active-area editor

- A trackpad-shaped preview: a rounded rectangle in a generic trackpad proportion, drawn with system colours and materials.
- The active area sits inside it as a rectangle with the Numpad grid drawn in, and four corner handles.
  - Dragging the rectangle moves it; dragging a corner resizes it.
  - The area can't leave the trackpad or shrink below 20 % (enforced in Core).
- **Live touches:** while the Settings window is key, fingers on the trackpad show as dots in the preview, so users can see where the area lies on their physical trackpad.
  - F2 was verified only for the full-screen capture panel. In Settings the pointer isn't frozen, and AppKit may deliver trackpad touches only to the view under the pointer.
  - So a short spike comes before the editor. If touches reach any view in the window, a touch view covers the whole Keypad tab without blocking clicks or drags.
  - If they can't be shown reliably, the live dots are dropped, and so is the footer's second sentence.
- "Use Whole Trackpad" restores the default.
- VoiceOver: the area is one adjustable element. Its value reads the size and position; increment and decrement resize it in 5 % steps.

### Dock menu and disabled state

- The Dock menu shows "Disable Keypad" or "Enable Keypad", then "Settings…".
- **Disabled:** the shortcut is unregistered, the state persists across launches, and the Dock icon is drawn dimmed through `NSDockTile`. That's a language-neutral cue with no badge, which would read as a notification count. The General tab's switch follows the same state.

### Strings

New keys, each with English and Turkish values. `settings.placeholder` is removed.

| Key | English | Turkish |
|---|---|---|
| `settings.window.title` | Keypad Settings | Keypad Ayarları |
| `settings.open` | Settings… | Ayarlar… |
| `settings.tab.general` | General | Genel |
| `settings.tab.keypad` | Keypad | Tuş Takımı |
| `settings.tab.feedback` | Feedback | Geri Bildirim |
| `settings.enabled` | Enable Keypad | Keypad'i etkinleştir |
| `settings.enabled.footer` | While Keypad is disabled, its shortcut does nothing. | Keypad devre dışıyken kısayolu hiçbir şey yapmaz. |
| `settings.openAtLogin` | Open at login | Girişte aç |
| `settings.openAtLogin.approval` | Allow Keypad in Login Items in System Settings. | Sistem Ayarları'ndaki Giriş Öğeleri'nde Keypad'e izin verin. |
| `settings.openAtLogin.openLoginItems` | Open Login Items… | Giriş Öğeleri'ni Aç… |
| `settings.shortcut` | Shortcut | Kısayol |
| `settings.shortcut.recording` | Type a shortcut… | Bir kısayol yazın… |
| `settings.shortcut.invalid` | Use two modifier keys, including ⌘ or ⌃, with a key — or a function key. | Bir tuşla birlikte, biri ⌘ veya ⌃ olan iki değiştirici tuş ya da bir fonksiyon tuşu kullanın. |
| `settings.shortcut.refused` | macOS didn't accept this shortcut. Try another one. | macOS bu kısayolu kabul etmedi. Başka bir kısayol deneyin. |
| `settings.shortcut.reset` | Reset | Sıfırla |
| `settings.activeArea` | Active area | Etkin alan |
| `settings.activeArea.footer` | Drag the area or its corners. Touch the trackpad to see where your fingers land. | Alanı veya köşelerini sürükleyin. Parmaklarınızın nereye denk geldiğini görmek için trackpad'e dokunun. |
| `settings.activeArea.reset` | Use Whole Trackpad | Tüm Trackpad'i Kullan |
| `settings.staysOpen` | Stay open after typing | Yazdıktan sonra açık kal |
| `settings.staysOpen.footer` | Return, Tab and the arrows type the number and keep the keypad open for the next one. | Return, Tab ve oklar sayıyı yazar ve tuş takımını bir sonraki sayı için açık tutar. |
| `settings.haptics` | Haptic feedback | Dokunsal geri bildirim |
| `settings.haptics.pattern` | Pattern | Desen |
| `settings.haptics.footer` | Felt when you touch a key. Needs a Force Touch trackpad. | Bir tuşa dokunduğunuzda hissedilir. Force Touch trackpad gerektirir. |
| `haptic.standard` / `.light` / `.pronounced` | Standard / Light / Pronounced | Standart / Hafif / Belirgin |
| `settings.sound` | Key sound | Tuş sesi |
| `settings.sound.choice` | Sound | Ses |
| `sound.wood` / `.soft` / `.deep` / `.crisp` | Wood / Soft / Deep / Crisp | Ahşap / Yumuşak / Derin / İnce |
| `dock.disable` | Disable Keypad | Keypad'i Devre Dışı Bırak |
| `dock.enable` | Enable Keypad | Keypad'i Etkinleştir |

Accessibility strings for the active-area editor are added with the editor, in both languages.

### Testing

- **Unit (Swift Testing, test-first):**
  - settings defaults;
  - a `Codable` round trip, and decoding with missing or invalid fields;
  - shortcut validation: one modifier, ⌥-only and ⌥⇧-only, modifier-only, F-keys, and the ignored `.function` flag;
  - active-area clamping and the minimum size;
  - the session configuration built from settings;
  - the feedback player choosing nothing when a kind is off (through a fake);
  - the settings model saving on change;
  - the recorder state machine: start, valid, invalid, refused, cancel, reset.
- **Manual QA on a real trackpad:**
  - every sound and pattern, with the haptic order checked against the names;
  - sound latency in a fast tap run;
  - shortcut changes, including a refused one, recording the current shortcut, recording while disabled, and an F-key shortcut on a laptop keyboard;
  - the active-area editor with live touches, and a session that respects the new area;
  - sticky off;
  - Disable/Enable from the Dock menu and from Settings, across a relaunch;
  - the dimmed Dock icon;
  - open at login on, off and needing approval;
  - the Settings window in dark mode and in Turkish;
  - VoiceOver on the editor.

## Alternatives considered

| Alternative | Decision |
|---|---|
| Keep RFC-0003 (feedback) and RFC-0004 (settings) separate | Merged by the PM: the feedback choices need Settings to exist. |
| The iPhone keyboard click | Not offered by macOS, and Apple's recording can't be copied into the app. Original sounds instead. |
| System sounds such as Tink or Pop | Rejected in QA: they read as alerts. |
| A haptic strength slider | No public API; only the three patterns exist. |
| A volume slider for the key sound | Not needed: the Mac's volume and the sound switch cover it. |
| SwiftUI `Settings` scene | Can't be opened from the Dock without an undocumented selector. AppKit window hosting SwiftUI instead. |
| A third-party shortcut recorder package | Not without its own RFC (AGENTS.md §9); the in-house control is small. |
| One `UserDefaults` key per setting with `@AppStorage` | Rejected: ties Core to SwiftUI and spreads versioning over many keys. |
| An About tab | Repeats the standard About panel. |
| A layout picker with only "Numpad" in it | A control with one choice; RFC-0008 adds it when there are layouts to pick. |
| A badge on the Dock icon for the disabled state | Reads as a notification count. A dimmed icon instead. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| The three haptic patterns feel almost the same on some trackpads | Medium | QA on the PM's trackpad; rename or drop a pattern if two are indistinguishable. |
| Sound latency or clipping in fast tap runs | Low | Sounds load once before the first session. If QA hears lag, the player moves to a lower-latency audio path without changing the settings. |
| Live touches don't reach the Settings window the way they reach the capture panel | Medium | A spike before the editor; without them the editor still works, just without dots. |
| macOS tightens hotkey rules again (as with ⌥-only in macOS 15) | Low | Validation lives in one Core type; a refused registration already shows a message. |
| A chosen shortcut registers but macOS keeps it for itself | Medium | Not detectable through public API. The user notices that nothing happens and records another shortcut; Reset restores ⌃⌥K. |
| `SMAppService` needs approval, or the user removes Keypad from Login Items | Medium | Settings always shows the real status and the "Open Login Items…" path. |
| A dimmed Dock icon is too subtle | Low | The Dock menu and General tab always state the truth. |
| Settings decode fails after a future change | Low | Field-by-field fallback to defaults; version number in the stored entry. |

## Rollout

1. Settings model, validation and store, test-first.
2. Feedback: generate the sounds, extend the player, wire it to settings.
3. Settings window with the three tabs and the switches.
4. Dock menu and disabled state.
5. Open at login.
6. Shortcut recorder.
7. Live-touch spike in the Settings window, then the active-area editor.
8. QA as above. The PM picks the default haptic pattern; record the result here.

Done when every unit test passes, the QA list passes, and lint and CI are green.

## Open questions

1. **Default haptic pattern:** the PM picks it by feel in QA. Until then, Standard.
2. **Names:** are Wood, Soft, Deep and Crisp, and Standard, Light and Pronounced, the names the PM wants in Settings?
3. **Development-lead calls the PM may overrule:**
   - shortcuts need two modifiers including ⌘ or ⌃, or a function key;
   - no window at launch until RFC-0005;
   - no About tab;
   - no layout picker until RFC-0008;
   - a dimmed Dock icon for the disabled state;
   - launch at login off until onboarding asks.
