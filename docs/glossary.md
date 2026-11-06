# Glossary

| Term | Meaning |
|---|---|
| Action | What a cell does when tapped: enter a digit, enter the decimal separator, or delete the last character. Later RFCs add operators, commit keys and sliders. |
| Active area | The part of the physical trackpad, stored as a normalized rectangle, that maps onto the layout. A stationary tap outside it is ignored; a finger that travels outside it wakes the pointer. |
| Buffer | The number being entered during a session. It is shown in the HUD and typed into the target app on commit. |
| Capture panel | The full-screen key panel Keypad shows during a session. It receives trackpad touches. In keypad mode it swallows pointer input so nothing reaches the app underneath; in pointer mode it lets mouse input through. |
| Cask | The Homebrew recipe that installs Keypad: `Casks/keypad.rb` in the tap, pointing at a release's DMG and its SHA-256. |
| Cell | One rectangle of a layout's grid, bound to an action. |
| Commit | Typing the buffer into the target app, followed by the commit key. |
| Commit key | The keyboard key that triggers a commit — Return, Tab or an arrow. It is sent to the target app after the buffer and keeps its meaning there. |
| Delivery wait | The pause after typing a commit, before Keypad reclaims focus or closes, so the posted keys reach the target app instead of Keypad (50 ms + 5 ms per keystroke). |
| Disabled | The state, set from the Dock menu or Settings, in which Keypad's shortcut is unregistered and its Dock icon is dimmed. It persists across launches. |
| Hand-off | Giving focus back to the target app before typing: yield activation, activate the target, wait for its activation notification. |
| Haptic pattern | One of the three system haptics Keypad can play on touch-down: Standard, Light or Pronounced. |
| HUD | The Liquid Glass overlay in the middle of the capture panel: target app, number display, key grid and hint. |
| Key sound | One of Keypad's four bundled sounds played when a tap completes: Wood (default), Soft, Deep or Crisp. |
| Keypad mode | The session mode in which the pointer is frozen and pointer input is swallowed. Every session opens in it. |
| Layout | A grid of rows and columns whose cells map to actions, stored as data. |
| Notice | A short, non-interactive message Keypad shows without opening a session, e.g. when secure input is on or the permission has just been granted. |
| Pointer mode | The session mode, entered when a finger travels outside the active area, in which the trackpad works normally there. A click closes the session, and a touch in the active area returns to keypad mode. |
| Reclaim | Re-activating Keypad and its capture panel after a commit in a sticky session. |
| Session | The time between opening Keypad with its shortcut and closing it with Esc, the shortcut, a commit in a non-sticky session, a click in pointer mode, or another app becoming active. |
| Sticky | The session mode, on by default, in which the session stays open after a commit. |
| Tap | The Homebrew repository `berkanaslan/homebrew-tap` that holds Keypad's cask. |
| Target app | The app that was frontmost when the session started. Commits type into it. |
| Transient overlay | A system screen that takes the keyboard and trackpad without activating another app, such as Spotlight or Mission Control. It does not end the session. |
