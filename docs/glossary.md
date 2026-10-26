# Glossary

| Term | Meaning |
|---|---|
| Action | What a cell does when tapped: enter a digit, enter the decimal separator, or delete the last character. Later RFCs add operators, commit keys and sliders. |
| Active area | The part of the physical trackpad, stored as a normalized rectangle, that maps onto the layout. Touches outside it are ignored. |
| Buffer | The number being entered during a session. It is shown in the HUD and typed into the target app on commit. |
| Capture panel | The full-screen key panel Keypad shows during a session. It receives trackpad touches and swallows pointer input so nothing reaches the app underneath. |
| Cell | One rectangle of a layout's grid, bound to an action. |
| Commit | Typing the buffer into the target app, followed by the commit key. |
| Commit key | The keyboard key that triggers a commit — Return, Tab or an arrow. It is sent to the target app after the buffer and keeps its meaning there. |
| Hand-off | Giving focus back to the target app before typing: yield activation, activate the target, wait for its activation notification. |
| HUD | The Liquid Glass overlay in the middle of the capture panel: target app, number display, key grid and hint. |
| Layout | A grid of rows and columns whose cells map to actions, stored as data. |
| Reclaim | Re-activating Keypad and its capture panel after a commit in a sticky session. |
| Session | The time between opening Keypad with its shortcut and closing it with Esc, the shortcut, or a commit in a non-sticky session. |
| Sticky | The session mode, on by default, in which the session stays open after a commit. |
| Target app | The app that was frontmost when the session started. Commits type into it. |
