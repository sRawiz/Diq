-- Client-side player directory and camera following. No teleport or remote calls.
local PlayerSystem = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local roster, connections = {}, {}
local initialized, destroyed = false, false
local selected, watching, listener, saved, targetConnection
local message = "Select a player to view details."

local function characterData(player)
	local character = player and player.Character
	if not character or not character:IsDescendantOf(workspace) then return nil, nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil, character:FindFirstChildOfClass("Humanoid")
end
local function ready(player)
	local root, humanoid = characterData(player)
	return root and humanoid and humanoid.Health > 0 and humanoid or nil
end
local function publish()
	if listener and not destroyed then
		local ok = pcall(listener, PlayerSystem.GetSnapshot())
		if not ok then warn("[Diq] Player directory listener failed") end
	end
end
function PlayerSystem.GetSnapshot()
	local entries = {}
	local ownRoot = characterData(LocalPlayer)
	for id, player in roster do
		local root, humanoid = characterData(player)
		local team = player.Team
		local available = root ~= nil and humanoid ~= nil and humanoid.Health > 0
		table.insert(entries, {
			UserId = id, Name = player.Name, DisplayName = player.DisplayName or player.Name,
			Team = not player.Neutral and team and team.Name or "Neutral",
			Distance = ownRoot and root and (root.Position - ownRoot.Position).Magnitude or nil,
			Available = available, Watching = watching == id,
			Status = available and "Ready" or "Character unavailable / not loaded",
		})
	end
	table.sort(entries, function(a, b)
		local left, right = a.DisplayName:lower(), b.DisplayName:lower()
		return left == right and a.UserId < b.UserId or left < right
	end)
	return { Players = entries, SelectedUserId = selected, SpectatingUserId = watching, Message = message }
end
function PlayerSystem.SetListener(callback)
	listener = callback
	publish()
end
function PlayerSystem.Select(userId)
	if destroyed then return false, "Player directory is closed" end
	if userId ~= nil and not roster[userId] then return false, "Player has left the server" end
	selected = userId
	publish()
	return true
end
function PlayerSystem.Stop(reason)
	if targetConnection then targetConnection:Disconnect(); targetConnection = nil end
	local previous = saved
	saved, watching = nil, nil
	if previous then
		-- Release only values we still own; never fight a game camera or cutscene.
		pcall(function()
			local camera = previous.Camera
			if camera.CameraSubject == previous.Target and camera.CameraType == Enum.CameraType.Custom then
				local subject = previous.Subject
				if not subject or not subject:IsDescendantOf(workspace) then
					local _, humanoid = characterData(LocalPlayer)
					subject = humanoid
				end
				if subject then camera.CameraSubject = subject end
				if camera.CameraType == Enum.CameraType.Custom then
					camera.CameraType = previous.Type
					if previous.Type == Enum.CameraType.Scriptable then
						camera.CFrame, camera.Focus = previous.CFrame, previous.Focus
					end
				end
			end
		end)
	end
	message = reason or "Spectate stopped."
	publish()
	return true
end
function PlayerSystem.Spectate(userId)
	if destroyed then return false, "Player directory is closed" end
	local player = roster[userId or selected]
	if not player then return false, "Select a player who is still in the server" end
	local humanoid = ready(player)
	if not humanoid then return false, "Character is dead or not loaded. Try again when it is available." end
	local camera = workspace.CurrentCamera
	if not camera then return false, "Camera is unavailable. Try again in a moment." end
	if saved and (saved.Camera ~= camera or camera.CameraSubject ~= saved.Target or camera.CameraType ~= Enum.CameraType.Custom) then
		PlayerSystem.Stop("The game changed the camera. Select Spectate to try again.")
		return false, message
	end
	local previous = saved or { Camera = camera, Subject = camera.CameraSubject, Type = camera.CameraType,
		CFrame = camera.CFrame, Focus = camera.Focus }
	local beforeSubject, beforeType = camera.CameraSubject, camera.CameraType
	local ok = pcall(function() camera.CameraSubject = humanoid; camera.CameraType = Enum.CameraType.Custom end)
	if not ok then
		pcall(function()
			if camera.CameraSubject == humanoid and beforeSubject then camera.CameraSubject = beforeSubject end
			if camera.CameraType == Enum.CameraType.Custom then camera.CameraType = beforeType end
		end)
		return false, "This runtime could not change the camera"
	end
	previous.Target = humanoid
	saved = previous
	if targetConnection then targetConnection:Disconnect() end
	targetConnection = player.CharacterRemoving:Connect(function()
		PlayerSystem.Stop("Target respawning. Select Spectate again when ready.")
	end)
	selected, watching = player.UserId, player.UserId
	message = "Watching " .. (player.DisplayName or player.Name) .. ". Movement still controls your own character."
	publish()
	return true
end
function PlayerSystem.Init()
	if initialized or destroyed then return end
	initialized = true
	for _, player in Players:GetPlayers() do if player ~= LocalPlayer then roster[player.UserId] = player end end
	table.insert(connections, Players.PlayerAdded:Connect(function(player)
		if player ~= LocalPlayer then roster[player.UserId] = player; publish() end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		roster[player.UserId] = nil
		if selected == player.UserId then selected = nil end
		if watching == player.UserId then PlayerSystem.Stop("Player left the server.") else publish() end
	end))
	table.insert(connections, LocalPlayer.CharacterRemoving:Connect(function()
		if watching then PlayerSystem.Stop("Your character is respawning; spectate stopped.") end
	end))
	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if watching then PlayerSystem.Stop("The game replaced the camera; spectate stopped.") end
	end))
	local elapsed = 0
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then return end
		elapsed = 0
		if watching then
			local camera = workspace.CurrentCamera
			local humanoid = ready(roster[watching])
			if not humanoid or humanoid ~= saved.Target then
				PlayerSystem.Stop("Target character is no longer available; spectate stopped.")
				return
			elseif camera ~= saved.Camera or camera.CameraSubject ~= saved.Target or camera.CameraType ~= Enum.CameraType.Custom then
				PlayerSystem.Stop("The game took control of the camera; spectate stopped.")
				return
			end
		end
		publish()
	end))
end
function PlayerSystem.Destroy()
	if destroyed then return end
	destroyed = true
	listener = nil
	PlayerSystem.Stop()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections); table.clear(roster)
	selected = nil
end
return PlayerSystem
