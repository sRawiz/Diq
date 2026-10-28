# Aimbot regression checks

Run with the official Windows Luau release binaries (`luau.exe` and
`luau-compile.exe`) in a directory of your choice:

```powershell
python tests/run_aimbot.py --luau-dir C:/path/to/luau
```

The runner compiles the repository's Lua files and executes the production
Aimbot module against mock Roblox services. Tests cover selection and lock
retention, respawn, team changes, dead/offscreen targets, R15 torso fallback,
wall checks, maximum distance, GUI inset alignment, frame-rate response,
keyboard focus, menus, window focus, mouse capability/error handling and
idempotent initialization/destruction.

These are logic tests, not evidence of compatibility with a particular game
camera, Roblox engine version or executor. The mocked camera tests exponential
response factors, not real camera rotations or mouse sensitivity.

## Live acceptance checks

1. Upload Main.lua, AimbotSystem.lua and DiqUILib.lua together before testing the remote loader.
2. In your own test map with another player, select Camera, enable Aimbot and
   Show FOV Circle, then press Q once to start aiming and again to stop. Camera mode uses the viewport center.
   Aim Activation Mode switches between Toggle and Hold. Aim Button selects
   Keyboard/Right Mouse/Left Mouse; Keyboard Aim Button captures a custom key.
   Changing the key/mode and re-enabling the master switch reset aiming to OFF.
   Press T while aiming to cycle to the next eligible target; Next Target Button
   changes that key. Aim and Next Target buttons cannot be the same key.
3. Toggle aiming off, kill/respawn a target, change teams and move behind a
   wall with Wall Check enabled. The old target must no longer be followed.
4. Check Mouse mode with both a free cursor and a locked cursor. The FOV follows
   the cursor when free and the viewport center when locked. Selection and
   movement use that same origin. Unsupported mousemoverel is reported in UI;
   a throwing implementation logs a warning and falls back to Camera.
5. Type in a TextBox, open the Roblox menu and switch away from the window.
   No aiming should occur while blocked. Returning from another window requires
   pressing the configured activation button again.
6. Disable Aimbot, close the panel and run the loader again. The overlay must
   disappear and the old controller must stop affecting the camera.

The controller currently targets player characters, not NPCs, and performs no
projectile-speed or ballistic prediction. Mouse behavior depends on executor
input support and the game's sensitivity. A custom camera that updates after
the controller's Last+1 render priority can override camera aiming.

The on-screen status shows activation ON/OFF and the last tracking state. Use
Combat > Diagnose Aimbot to print a snapshot and rejection counts to Output.
Same team, Outside FOV, Off screen, Blocked by wall and unavailable characters
are reported separately. This diagnostic reflects the last evaluated frame;
it does not prove a custom game camera accepted the final camera orientation.

## Target selection

The default Balanced priority combines normalized crosshair distance (70%)
and physical distance from the local character (30%). Lower scores win:
`weight * pixels/FOV + (1-weight) * studs/(studs+100)`.
The distance term reaches 0.5 at 100 studs. This is a ranking heuristic,
not an AI prediction of threat, weapon range or line of fire.

Combat > Target Priority also offers Closest to Crosshair, Closest Player,
and Keep Current Target. Crosshair Weight affects Balanced only: 100% uses
crosshair distance alone; 0% uses physical distance alone. All modes retain
the FOV, health, team, maximum-distance and optional wall filters.

The current target is validated every frame. Auto Switch to Better Target is
OFF by default: Balanced ranks the initial acquisition, then the controller
retains that target until it becomes invalid or the user requests another.
If Auto Switch is ON, other players are compared at 10 Hz.
A challenger must improve the score by more than 20% and at least
0.025 Balanced score, 8 pixels in crosshair mode, or 3 studs in nearest mode.
It must remain best over successive scans for Target Switch Delay (default
200 ms), so switching may take about 200-300 ms after a challenger appears.
Invalid targets are replaced immediately, without this delay. Sticky priority
never switches a still-valid target. Exact-score ties use the lower UserId.

Regression tests cover combined-score weighting, physical-distance ranking,
enumeration-independent ties, sustained challengers, near-tie stability,
interrupted challengers and immediate replacement of dead targets.

Manual selection cycles through a score-sorted snapshot of eligible players.
That order is retained across presses so camera-induced ranking changes do not
bounce between two players. Ineligible players are removed and newly eligible
players are appended in score order. A single candidate stays selected; no
candidates clears the lock. Manual selection still applies all eligibility
filters and is blocked while typing, in menus, unfocused, or editing either
aim keybind. Returning from a keybind edit requires activating aim again.

Additional regressions cover three-player cycling while scores change, cycle
wrap, manual mode stability, key rebinding/conflicts and cancellation on focus
loss or input capture. UI hook wiring has been compiled and inspected, but
interactive keybind behavior still needs a live executor check.
