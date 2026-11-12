# Players and Spectate

The **Players** page lists other players in the current server. Search matches
display names and usernames as literal, case-insensitive text; an optional `@`
prefix is accepted. Rows are keyed by UserId so duplicate display names remain
separate. Selecting a row shows its team, distance from your character in studs,
and whether its character is currently available. Missing positions display an
unknown distance, not zero.

**Spectate** follows the selected Humanoid using the local camera. It does not
teleport your character, share the target's actual camera orientation, or disable
your movement controls. **Stop Spectating**, **Stop All Features / End**, and
closing Diq release the camera. The previous camera subject/type are restored
while Diq still owns them; a game camera takeover is preserved instead.

Spectate stops when either character respawns, the target dies/leaves/streams
out, or the game replaces or takes control of the camera. It does not restart
automatically. Select Spectate again when the target is ready. An unloaded or
non-Humanoid character produces an actionable message.

The directory refreshes at most twice per second and reuses existing UI rows.
Join/leave events update it immediately. This feature uses standard client APIs,
requires no additional executor globals, and stores no player selection in
profiles. Each module instance owns its events and restores camera state on
Destroy, including when the entry point runs again.

`PlayerSystem.lua` retains the repository's returned-table loading convention:
`Init()`, `GetSnapshot()`, `Select(userId)`, `Spectate(userId?)`, `Stop(reason?)`,
`SetListener(callback)`, and `Destroy()`. Selection does not start spectating.

References: [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera)
and [instance streaming](https://create.roblox.com/docs/workspace/streaming).
Changing a camera subject does not guarantee distant areas are loaded. Custom
camera systems and game-specific team rules may require an adapter.

## Verification

`tests/Players.spec.luau` exercises the actual module and list component with
deterministic engine mocks: duplicate names, search, distance availability,
selection, switching targets, death/respawn, streaming loss, player departures,
camera takeover/replacement, restoration, and repeated cleanup. ControlCenter
tests cover the production Spectate/Stop buttons and End shortcut. Loader tests
cover reruns, failure rollback and the generated bundle.

These are compilation and mock checks, not a live Roblox/executor test. Live
acceptance needs two clients: verify orbit/zoom around a target, row spacing at
small window sizes, mouse/touch selection and scrolling, return to your own
camera, target departure/respawn, streaming and game-specific camera behavior.
