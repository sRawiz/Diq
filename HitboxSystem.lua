local ModuleOptions = ...
local Runtime = type(ModuleOptions) == "table" and ModuleOptions.Runtime
local HitboxSystem = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Config = { Enabled = false, Size = 5, Transparency = 0.5, TargetPart = "Head", TeamCheck = true }
local initialized, destroyed = false, false
local connection
local owner, originals, active = {}, {}, {}
local function restore(part)
	if Runtime then Runtime.Properties:Release(owner, part)
	else
		local snapshot = originals[part]
		if snapshot then
			for key, data in snapshot do
				pcall(function() if part[key] == data.last then part[key] = data.value end end)
			end
		end
		originals[part] = nil
	end
	active[part] = nil
end
local function restoreAll() for part in active do restore(part) end end
local function set(part, key, value)
	if Runtime then assert(Runtime.Properties:Set(owner, part, key, value), "Hitbox property write failed")
	else
		originals[part] = originals[part] or {}
		local fields = originals[part]
		fields[key] = fields[key] or { value = part[key] }
		fields[key].last = value
		if part[key] ~= value then part[key] = value end
	end
end
local function update()
	if destroyed or not Config.Enabled then return end
	local mark = {}
	for _, player in (Runtime and Runtime.Registry:GetPlayers() or Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		local teammate = Config.TeamCheck and not LocalPlayer.Neutral and not player.Neutral
			and player.Team ~= nil and player.Team == LocalPlayer.Team
		if teammate then continue end
		local record = Runtime and Runtime.Registry:Get(player)
		local character = player.Character
		local humanoid = record and record.Humanoid or (character and character:FindFirstChildOfClass("Humanoid"))
		local root = record and record.Root or (character and character:FindFirstChild("HumanoidRootPart"))
		local part = character and character:FindFirstChild(Config.TargetPart)
		if not root or not humanoid or humanoid.Health <= 0 or not part or not part:IsA("BasePart") then continue end
		-- Snapshot exact instances before mutation, including late-arriving parts.
		active[part] = mark
		set(part, "Size", Vector3.new(Config.Size, Config.Size, Config.Size))
		set(part, "Transparency", Config.Transparency)
		set(part, "CanCollide", false)
	end
	for part, seen in active do if seen ~= mark then restore(part) end end
end
local function bind()
	if initialized and Config.Enabled and not connection then
		connection = Runtime and Runtime.Scheduler:Connect("Hitbox.Update", "PreSimulation", 0, update, function() HitboxSystem.SetEnabled(false) end)
			or RunService.PreSimulation:Connect(update)
	elseif not Config.Enabled and connection then connection:Disconnect(); connection = nil end
end
function HitboxSystem.SetEnabled(value)
	if destroyed then return false end
	Config.Enabled = value == true; bind()
	if not Config.Enabled then restoreAll() end
	return true
end
local function finite(value, minimum, maximum)
	assert(type(value) == "number" and value == value and value >= minimum and value <= maximum, "Value outside supported range")
	return value
end
function HitboxSystem.SetSize(value) if not destroyed then Config.Size = finite(value, 0.01, 2048) end end
function HitboxSystem.SetTransparency(value) if not destroyed then Config.Transparency = finite(value, 0, 1) end end
function HitboxSystem.SetTargetPart(value)
	if destroyed then return end
	assert(type(value) == "string" and #value > 0, "Expected part name")
	restoreAll(); Config.TargetPart = value
end
function HitboxSystem.SetTeamCheck(value) if not destroyed then Config.TeamCheck = value == true; restoreAll() end end
function HitboxSystem.IsEnabled() return Config.Enabled end
function HitboxSystem.GetSize() return Config.Size end
function HitboxSystem.GetTransparency() return Config.Transparency end
function HitboxSystem.GetTargetPart() return Config.TargetPart end
function HitboxSystem.GetTeamCheck() return Config.TeamCheck end
function HitboxSystem.GetConfig() return table.clone(Config) end
function HitboxSystem.Init()
	assert(not destroyed, "Cannot initialize destroyed Hitbox")
	if initialized then return end
	initialized = true; bind()
end
function HitboxSystem.Destroy()
	if destroyed then return end
	HitboxSystem.SetEnabled(false); destroyed = true
end
if type(ModuleOptions) ~= "table" or not ModuleOptions.DeferInit then HitboxSystem.Init() end
return HitboxSystem
