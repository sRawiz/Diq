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

1. Upload Main.lua and AimbotSystem.lua together before testing the remote loader.
2. In your own test map with another player, select Camera, enable Aimbot and
   Show FOV Circle, then press Q once to start aiming and again to stop. Camera mode uses the viewport center.
   Aim Activation Mode switches between Toggle and Hold. Aim Button selects
   Keyboard/Right Mouse/Left Mouse; Keyboard Aim Button captures a custom key.
   Changing the key/mode and re-enabling the master switch reset aiming to OFF.
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
