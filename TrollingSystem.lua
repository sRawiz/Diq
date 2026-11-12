local ModuleOptions = ...
local Runtime = type(ModuleOptions) == "table" and ModuleOptions.Runtime
local Trolling = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local armPoses = {
	R6 = {
		{ Joint = "Right Shoulder", Roll = -55, MinPitch = 18, MaxPitch = 48 },
	},
	R15 = {
		{ Joint = "RightShoulder", Roll = -38, MinPitch = 12, MaxPitch = 28 },
		{ Joint = "RightElbow", Roll = 0, MinPitch = 30, MaxPitch = 63 },
	},
}
local animations = {
	{ Name = "Wave", R6 = 128777973, R15 = 507770239 },
	{ Name = "Point", R6 = 128853357, R15 = 507770453 },
	{ Name = "Cheer", R6 = 129423030, R15 = 507770677 },
	{ Name = "Laugh", R6 = 129423131, R15 = 507770818 },
	{ Name = "Dance 1", R6 = 182435998, R15 = 507771019, Looped = true },
	{ Name = "Dance 2", R6 = 182436842, R15 = 507776043, Looped = true },
	{ Name = "Dance 3", R6 = 182436935, R15 = 507777268, Looped = true },
	{ Name = "Jerk Off", Poses = armPoses },
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
	playback.Cleanup()
end

local function beginPlayback(player, character, humanoid, playback)
	Trolling.Stop()
	active = playback
	local function stopCurrent()
		if active == playback then Trolling.Stop() end
	end
	playback.Connections = {
		player.CharacterRemoving:Connect(function(removing)
			if removing == character then stopCurrent() end
		end),
		humanoid.Died:Connect(stopCurrent),
	}
	return stopCurrent
end

local function getJointFrame(joint)
	if not joint then return end
	if joint:IsA("Motor6D") then
		return joint.Part0 and joint.Part1 and joint.C0
	end
	if joint:IsA("AnimationConstraint") and joint.IsKinematic then
		local attachment = joint.Attachment0
		return attachment and joint.Attachment1 and attachment.CFrame
	end
end

local function playPose(player, character, humanoid, poses)
	local joints = {}
	for _, pose in poses do
		local joint = character:FindFirstChild(pose.Joint, true)
		local frame = getJointFrame(joint)
		if not frame then return false, "This character's arm joints do not support the gesture." end
		local basis = frame.Rotation
		local inverse = basis:Inverse()
		local roll = CFrame.Angles(0, 0, math.rad(pose.Roll))
		table.insert(joints, {
			Joint = joint,
			Start = inverse * roll * CFrame.Angles(math.rad(pose.MinPitch), 0, 0) * basis,
			Finish = inverse * roll * CFrame.Angles(math.rad(pose.MaxPitch), 0, 0) * basis,
		})
	end

	local function restorePose()
		for _, state in joints do
			local joint = state.Joint
			if state.Last and joint.Parent and joint.Transform == state.Last then
				joint.Transform = state.Baseline
			end
		end
	end
	local playback = { Cleanup = restorePose }
	local stopCurrent = beginPlayback(player, character, humanoid, playback)
	for _, state in joints do
		table.insert(playback.Connections, state.Joint.Destroying:Connect(stopCurrent))
	end

	local elapsed = 0
	local function step(dt)
		if active ~= playback then return end
		if player.Character ~= character or humanoid.Health <= 0 then stopCurrent(); return end
		elapsed += dt
		local progress = (1 + math.sin(elapsed * 2.4 * 2 * math.pi)) * 0.5
		local weight = math.min(elapsed / 0.12, 1)
		for _, state in joints do
			local joint = state.Joint
			if not joint:IsDescendantOf(character) or not getJointFrame(joint) then
				stopCurrent()
				return
			end
			-- Keep the most recent pose supplied by the Animator or another writer.
			local current = joint.Transform
			if current ~= state.Last then state.Baseline = current end
			joint.Transform = state.Baseline:Lerp(state.Start:Lerp(state.Finish, progress), weight)
			state.Last = joint.Transform
		end
	end
	local connection = Runtime and Runtime.Scheduler:Connect("Trolling.ArmGesture", "PreSimulation", 0, step, stopCurrent)
		or RunService.PreSimulation:Connect(step)
	table.insert(playback.Connections, connection)
	return true
end

local function playClip(player, character, humanoid, clip, rig, onLoadFailure)
	local name = clip.Name
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return false, "Your character has no Animator. Try again after respawning." end

	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = "rbxassetid://" .. clip[rig]
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	local loadError = ("Could not load %s for %s. Try again or choose another emote."):format(name, rig)
	if not ok then
		animation:Destroy()
		return false, loadError
	end

	local function releaseTrack()
		pcall(function() track:Stop() end)
		track:Destroy()
		animation:Destroy()
	end
	local playback = { Cleanup = releaseTrack }
	local stopCurrent = beginPlayback(player, character, humanoid, playback)
	local function finish()
		if active ~= playback then return end
		local loaded = track.Length > 0
		Trolling.Stop()
		if not loaded then
			if onLoadFailure then onLoadFailure(loadError)
			else warn("[Diq] " .. loadError) end
		end
	end
	table.insert(playback.Connections, animator.Destroying:Connect(stopCurrent))
	table.insert(playback.Connections, track.Ended:Connect(finish))
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
	if rig ~= "R6" and rig ~= "R15" then return false, "This animation requires an R6 or R15 character." end
	if clip.Poses then return playPose(player, character, humanoid, clip.Poses[rig]) end
	return playClip(player, character, humanoid, clip, rig, onLoadFailure)
end

function Trolling.Destroy()
	destroyed = true
	Trolling.Stop()
end

return Trolling
