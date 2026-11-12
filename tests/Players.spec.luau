-- INSERT_MOCKS
-- INSERT_MODULES
-- INSERT_UI_MODULES
local baseline = liveConnections()
local camera = Instance.new("Camera")
camera.Parent = workspace
camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, own.Character.Humanoid
camera.CFrame, camera.Focus = CFrame.lookAt(vec(0, 0, 0), vec(0, 0, 1)), CFrame.lookAt(vec(0, 0, 10), vec(0, 0, 11))
workspace.CurrentCamera = camera
local originalSubject = camera.CameraSubject
enemy.DisplayName = "Same Name"
local team = Instance.new("Team"); team.Name = "Red"; enemy.Team = team
enemy.Character.HumanoidRootPart.Position = own.Character.HumanoidRootPart.Position + vec(30, 0, 40)
local system = factories.PlayerSystem()
system.Init(); local initCount = liveConnections(); system.Init()
check(liveConnections() == initCount, "Init is idempotent")
local snapshot = system.GetSnapshot()
check(#snapshot.Players == 1 and snapshot.Players[1].UserId == enemy.UserId, "Directory excludes local player")
check(snapshot.Players[1].Distance == 50 and snapshot.Players[1].Team == "Red", "Distance uses own character and team uses Roblox team")
check(not system.Spectate() and not system.Select(999), "No selection and stale ids are actionable failures")
check(system.Select(enemy.UserId) and camera.CameraSubject == originalSubject, "Selecting does not move the camera")
check(system.Spectate() and camera.CameraSubject == enemy.Character.Humanoid, "Spectate follows selected humanoid")
check(system.GetSnapshot().SpectatingUserId == enemy.UserId, "Watching state reaches UI")
system.Stop()
check(camera.CameraSubject == originalSubject and camera.CameraType == Enum.CameraType.Custom, "Stop restores original camera")
local other = newPlayer("Another", "blue"); other.DisplayName = "Same Name"
Players.PlayerAdded:Fire(other)
snapshot = system.GetSnapshot()
check(#snapshot.Players == 2 and snapshot.Players[1].UserId ~= snapshot.Players[2].UserId, "Duplicate display names keep distinct stable identities")
system.Spectate(enemy.UserId); system.Spectate(other.UserId); system.Stop()
check(camera.CameraSubject == originalSubject, "Switch targets without losing original camera")
system.Spectate(enemy.UserId); enemy.Character.Humanoid.Health = 0; RunService.Heartbeat:Fire(0.5)
check(not system.GetSnapshot().SpectatingUserId and camera.CameraSubject == originalSubject, "Death restores camera")
check(not system.Spectate(enemy.UserId), "Dead targets cannot be watched")
enemy.Character.Humanoid.Health = 100
system.Spectate(enemy.UserId); enemy.CharacterRemoving:Fire(enemy.Character)
check(not system.GetSnapshot().SpectatingUserId and camera.CameraSubject == originalSubject, "Target respawn stops without hanging")
system.Spectate(enemy.UserId)
local root = enemy.Character.HumanoidRootPart; root.Parent = nil
RunService.Heartbeat:Fire(0.5)
check(not system.GetSnapshot().SpectatingUserId and not system.Spectate(enemy.UserId), "Streaming loss stops and reports unavailable target")
check(system.GetSnapshot().Players[1].Distance == nil, "Missing root is an unknown distance, never zero")
root.Parent = enemy.Character
system.Spectate(enemy.UserId); own.CharacterRemoving:Fire(own.Character)
check(not system.GetSnapshot().SpectatingUserId, "Local respawn stops spectate")
system.Spectate(enemy.UserId)
camera.CameraSubject = other.Character.Humanoid
RunService.Heartbeat:Fire(0.5)
check(not system.GetSnapshot().SpectatingUserId and camera.CameraSubject == other.Character.Humanoid, "External camera subject is not overwritten")
camera.CameraSubject = originalSubject
system.Spectate(enemy.UserId); camera.CameraType = Enum.CameraType.Scriptable
RunService.Heartbeat:Fire(0.5)
check(not system.GetSnapshot().SpectatingUserId and camera.CameraType == Enum.CameraType.Scriptable and camera.CameraSubject == enemy.Character.Humanoid,
	"Game camera takeover preserves both fields")
camera.CameraSubject = originalSubject
local frame, focus = camera.CFrame, camera.Focus
system.Spectate(enemy.UserId); camera.CFrame = CFrame.lookAt(vec(100, 100, 100), vec(100, 100, 101)); system.Stop()
check(camera.CameraType == Enum.CameraType.Scriptable and camera.CFrame == frame and camera.Focus == focus, "Scriptable original restores its framing")
camera.CameraType = Enum.CameraType.Custom
system.Spectate(enemy.UserId)
local replacement = Instance.new("Camera"); replacement.Parent = workspace
replacement.CameraType, replacement.CameraSubject = Enum.CameraType.Custom, originalSubject
workspace.CurrentCamera = replacement
check(not system.GetSnapshot().SpectatingUserId and camera.CameraSubject == originalSubject and replacement.CameraSubject == originalSubject,
	"Camera replacement releases old camera without modifying new camera")
system.Spectate(enemy.UserId); Players.PlayerRemoving:Fire(enemy)
check(system.GetSnapshot().SelectedUserId == nil and not system.GetSnapshot().SpectatingUserId and #system.GetSnapshot().Players == 1,
	"Departure immediately removes row, selection and target before Players updates")
Players.PlayerAdded:Fire(enemy)
for _ = 1, 20 do system.Spectate(enemy.UserId); system.Stop() end
check(liveConnections() == initCount, "Repeated spectate cycles do not accumulate target handlers")
system.Spectate(enemy.UserId); system.Destroy(); system.Destroy()
check(replacement.CameraSubject == originalSubject and liveConnections() == baseline, "Destroy restores camera and disconnects all service handlers")
check(not system.Spectate(enemy.UserId), "Destroyed service cannot restart")

-- Real list component: live filtering, row reuse, selection and departure cleanup.
local Lifecycle = importUI("core/Lifecycle")
local theme = importUI("core/Theme")()
local scope, elements = Lifecycle.new(), {}
local parent = Instance.new("Frame")
local ctx = { Parent = parent, Scope = scope, Theme = theme,
	Primitives = importUI("core/Primitives")(theme, function() return nil end),
	Register = function(obj, owner, resettable) Lifecycle.Register(elements, obj, owner, resettable) end }
local clicked
local widget = importUI("components/PlayerList")(ctx, function(id) clicked = id end)
local directory = parent:FindFirstChild("PlayerDirectory")
local search, list = directory.PlayerSearch, directory.PlayerRows
local emptyCount = liveConnections()
local values = {
	{ UserId = 2, Name = "Enemy", DisplayName = "Same Name", Team = "Red", Distance = 50, Available = true },
	{ UserId = 3, Name = "Another", DisplayName = "Same Name", Team = "Neutral", Available = false },
}
widget:SetPlayers(values, nil)
local row = list.Player_2
check(row.DisplayName.Text == "Same Name" and row.Distance.Text == "50 studs" and list.Player_3.Distance.Text == "—", "List shows names and distinguishes unknown distance")
local rowCount = liveConnections()
widget:SetPlayers(values, 2)
check(list.Player_2 == row and liveConnections() == rowCount, "Polling reuses rows and handlers")
search.Text = "@eNeMy"
check(row.Visible and not list.Player_3.Visible, "Search matches username case-insensitively with @ prefix")
search.Text = "same name"
check(row.Visible and list.Player_3.Visible, "Display-name search includes duplicate names")
search.Text = "["
check(not row.Visible and list.EmptyPlayers.Visible, "Search treats pattern characters literally and shows empty state")
search.Text = ""
row.Activated:Fire()
check(clicked == 2 and row.BackgroundTransparency == 0, "Row selection returns stable user id and marks selection")
values[1].Watching = true
widget:SetPlayers(values, 2)
check(row.DisplayName.Text == "Same Name · Watching", "Watched player has a visible status")
widget:SetPlayers({}, nil)
check(row.Destroyed and liveConnections() == emptyCount and list.EmptyPlayers.Text == "No other players in this server.", "Departures destroy rows and release handlers")
widget:Destroy(); scope:DisconnectAll(); parent:Destroy()
check(liveConnections() == baseline, "Component teardown releases every handler")
check(#warnings == 0, "No swallowed callback failures")
print("Players checks passed: " .. checks)
