local ModuleOptions = ...
local Runtime = type(ModuleOptions) == "table" and ModuleOptions.Runtime
local MiscSystem = {}
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local destroyed = false
local State = { IsFullbright = false, IsAntiAFK = false }
local connections, original = {}, {}
local owner = {}
local pending
local listener
local desired = {
	Ambient = Color3.new(1, 1, 1), ColorShift_Bottom = Color3.new(1, 1, 1),
	ColorShift_Top = Color3.new(1, 1, 1), GlobalShadows = false, FogEnd = 9e9, Brightness = 2,
}
local function changed()
	if listener then
		local ok = pcall(listener, MiscSystem.GetState())
		if not ok then warn("[Diq] Misc state listener failed") end
	end
end
local function disconnect(name)
	if connections[name] then connections[name]:Disconnect(); connections[name] = nil end
end
local function applyLighting()
	if destroyed or not State.IsFullbright then return end
	for property, value in desired do
		if Runtime then Runtime.Properties:Set(owner, Lighting, property, value)
		elseif Lighting[property] ~= value then Lighting[property] = value end
	end
end
function MiscSystem.SetFullbright(enabled)
	if destroyed then return false end
	enabled = enabled == true
	if enabled == State.IsFullbright then return true end
	State.IsFullbright = enabled
	if enabled then
		for property in desired do original[property] = Lighting[property] end
		applyLighting()
		connections.Lighting = Lighting.Changed:Connect(function(property)
			if not State.IsFullbright or destroyed or desired[property] == nil or Lighting[property] == desired[property] or pending then return end
			-- Coalesce external writes and keep lighting work off the render path.
			pending = task.delay(0.1, function() pending = nil; applyLighting() end)
		end)
	else
		disconnect("Lighting")
		if pending then pcall(task.cancel, pending); pending = nil end
		if Runtime then Runtime.Properties:Release(owner)
		else
			for property, value in original do
				if Lighting[property] == desired[property] then Lighting[property] = value end
			end
		end
		table.clear(original)
	end
	changed(); return true
end
function MiscSystem.SetAntiAFK(enabled)
	if destroyed then return false, "Module is closed" end
	if not enabled then
		State.IsAntiAFK = false; disconnect("Idle"); changed(); return true
	end
	if State.IsAntiAFK then return true end
	local ok, virtualUser = pcall(function() return game:GetService("VirtualUser") end)
	if not ok or not virtualUser then return false, "VirtualUser is unavailable in this runtime" end
	-- Service existence does not prove permission to invoke its methods.
	State.IsAntiAFK = true
	connections.Idle = LocalPlayer.Idled:Connect(function()
		if destroyed or not State.IsAntiAFK then return end
		local succeeded = pcall(function()
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.new())
		end)
		if not succeeded then
			MiscSystem.SetAntiAFK(false)
			warn("[Diq] Anti-AFK disabled: this runtime cannot invoke VirtualUser input")
		end
	end)
	changed(); return true
end
function MiscSystem.Rejoin()
	if destroyed then return false, "Module is closed" end
	local ok = pcall(function()
		if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, LocalPlayer)
		else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
	end)
	if not ok then warn("[Diq] Rejoin failed") end
	return ok
end
function MiscSystem.SetStateListener(callback) listener = callback end
function MiscSystem.IsFullbright() return State.IsFullbright end
function MiscSystem.IsAntiAFK() return State.IsAntiAFK end
function MiscSystem.GetState() return table.clone(State) end
function MiscSystem.Destroy()
	if destroyed then return end
	MiscSystem.SetFullbright(false); MiscSystem.SetAntiAFK(false)
	destroyed = true; listener = nil
	for name in connections do disconnect(name) end
end
return MiscSystem
