local Trolling = {}
local Players = game:GetService("Players")
local animations = {
	{ Name = "Wave", R6 = 128777973, R15 = 507770239 },
	{ Name = "Point", R6 = 128853357, R15 = 507770453 },
	{ Name = "Cheer", R6 = 129423030, R15 = 507770677 },
	{ Name = "Laugh", R6 = 129423131, R15 = 507770818 },
	{ Name = "Dance 1", R6 = 182435998, R15 = 507771019, Looped = true },
	{ Name = "Dance 2", R6 = 182436842, R15 = 507776043, Looped = true },
	{ Name = "Dance 3", R6 = 182436935, R15 = 507777268, Looped = true },
}
local clips, names = {}, {}
for _, clip in animations do
	clips[clip.Name] = clip
	table.insert(names, clip.Name)
end
local active
local destroyed = false

function Trolling.GetAnimations()
	return table.clone(names)
end

function Trolling.Stop()
	local playback = active
	if not playback then return end
	active = nil
	for _, connection in playback.Connections do
		connection:Disconnect()
	end
	if playback.Timeout then task.cancel(playback.Timeout) end
	pcall(function() playback.Track:Stop() end)
	playback.Track:Destroy()
	playback.Animation:Destroy()
end

function Trolling.Play(name, onLoadFailure)
	if destroyed then return false, "Trolling is closed." end
	local clip = clips[name]
	if not clip then return false, "Unknown animation." end
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not character:IsDescendantOf(workspace) then
		return false, "Wait for your character to spawn, then try again."
	end
	local rig = humanoid.RigType.Name
	local id = clip[rig]
	if not id then return false, "This animation requires an R6 or R15 character." end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return false, "Your character has no Animator. Try again after respawning." end

	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = "rbxassetid://" .. id
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	local loadError = ("Could not load %s for %s. Try again or choose another emote."):format(name, rig)
	if not ok then
		animation:Destroy()
		return false, loadError
	end

	Trolling.Stop()
	local playback = { Animation = animation, Track = track, Connections = {} }
	active = playback
	local function stopCurrent()
		if active == playback then Trolling.Stop() end
	end
	local function finish()
		if active ~= playback then return end
		local loaded = track.Length > 0
		Trolling.Stop()
		if not loaded then
			if onLoadFailure then onLoadFailure(loadError)
			else warn("[Diq] " .. loadError) end
		end
	end
	local connected = playback.Connections
	table.insert(connected, player.CharacterRemoving:Connect(function(removing)
		if removing == character then stopCurrent() end
	end))
	table.insert(connected, humanoid.Died:Connect(stopCurrent))
	table.insert(connected, animator.Destroying:Connect(stopCurrent))
	table.insert(connected, track.Ended:Connect(finish))
	local played = pcall(function()
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = clip.Looped == true
		track:Play()
	end)
	if not played then
		stopCurrent()
		return false, ("Could not play %s for %s. Try again after respawning."):format(name, rig)
	end
	if active == playback and track.Length == 0 then
		-- The engine can return a track before it has fetched the animation data.
		playback.Timeout = task.delay(8, function()
			playback.Timeout = nil
			if active == playback and track.Length == 0 then finish() end
		end)
	end
	return true
end

function Trolling.Destroy()
	destroyed = true
	Trolling.Stop()
end

return Trolling
