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
local serverListener, serverOperation
local serverWorker, serverTimeout
local function cancelTask(thread)
	if thread and thread ~= coroutine.running() then pcall(task.cancel, thread) end
end
local function serverStatus(phase, message)
	if not destroyed and phase == "Failed" then warn("[Diq] " .. message) end
	if not destroyed and serverListener then
		local ok = pcall(serverListener, phase, message)
		if not ok then warn("[Diq] Server status listener failed") end
	end
end
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
local function finishServer(operation, phase, message)
	if serverOperation ~= operation then return end
	serverOperation = nil
	disconnect("TeleportFailed")
	local worker, timeout = serverWorker, serverTimeout
	serverWorker, serverTimeout = nil, nil
	cancelTask(worker); cancelTask(timeout)
	serverStatus(phase, message)
end
local function startTeleport(operation, jobId)
	if destroyed or serverOperation ~= operation then return false end
	operation.Phase = "Teleporting"
	cancelTask(serverTimeout)
	serverTimeout = task.delay(45, function()
		finishServer(operation, "Failed", "Teleport timed out. Check the Roblox connection and try again.")
	end)
	local connected = pcall(function()
		connections.TeleportFailed = TeleportService.TeleportInitFailed:Connect(function(player, result, _, placeId, options)
			if player ~= LocalPlayer or placeId ~= operation.PlaceId or serverOperation ~= operation then return end
			-- Ignore failures from another teleport target when Roblox supplies it.
			if options and jobId then
				local read, target = pcall(function() return options.ServerInstanceId end)
				if read and type(target) == "string" and target ~= "" and target ~= jobId then return end
			end
			local reason = result == Enum.TeleportResult.GameFull and "Server is full. Find another server."
				or result == Enum.TeleportResult.Flooded and "Too many teleport requests. Wait a moment and try again."
				or "Teleport failed. The server may be unavailable or restricted; try again."
			finishServer(operation, "Failed", reason)
		end)
	end)
	if not connected then
		finishServer(operation, "Failed", "Teleport failure events are unavailable in this runtime.")
		return false
	end
	serverStatus("Teleporting", jobId == game.JobId and "Rejoining the current server..." or "Joining another server...")
	if destroyed or serverOperation ~= operation then return false end
	-- Client/executor runtime: TeleportAsync is server-only. Keep the client API.
	local ok = pcall(function()
		if jobId then TeleportService:TeleportToPlaceInstance(operation.PlaceId, jobId, LocalPlayer)
		else TeleportService:Teleport(operation.PlaceId, LocalPlayer) end
	end)
	if not ok then finishServer(operation, "Failed", "Teleport request failed. Check executor support and try again.") end
	return ok
end
local function beginServer(phase)
	if destroyed then return nil, "Module is closed" end
	if serverOperation then return nil, "A server search or teleport is already in progress" end
	if not LocalPlayer or type(game.PlaceId) ~= "number" or game.PlaceId <= 0 then
		return nil, "Join a running Roblox game before changing servers"
	end
	local operation = { Phase = phase, PlaceId = game.PlaceId }
	serverOperation = operation
	return operation
end

-- Uses the same executor HttpGet capability as Main's loader. No proxy or credentials.
local function findServer(operation)
	local available, httpGet = pcall(function() return game.HttpGet end)
	if not available or type(httpGet) ~= "function" then
		return nil, "Server search requires executor game:HttpGet support"
	end
	local http = game:GetService("HttpService")
	local cursor, seen = nil, {}
	for page = 1, 10 do
		if destroyed or serverOperation ~= operation then return nil end
		local url = "https://games.roblox.com/v1/games/" .. tostring(operation.PlaceId)
			.. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
		if cursor then url ..= "&cursor=" .. http:UrlEncode(cursor) end
		local downloaded, body = pcall(httpGet, game, url)
		if destroyed or serverOperation ~= operation then return nil end
		if not downloaded then return nil, "Server list download failed. Check executor HTTP access or wait before retrying." end
		if type(body) ~= "string" or body == "" then return nil, "Server list returned an empty or invalid response" end
		local decoded, data = pcall(function() return http:JSONDecode(body) end)
		if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
			return nil, "Server list response could not be read. Try again later."
		end
		for _, server in ipairs(data.data) do
			if type(server) == "table" and type(server.id) == "string" and server.id ~= "" and #server.id <= 128
				and server.id ~= game.JobId and type(server.playing) == "number" and type(server.maxPlayers) == "number"
				and server.playing >= 0 and server.playing < server.maxPlayers then
				return server.id
			end
		end
		cursor = data.nextPageCursor
		if cursor == nil or cursor == "" then return nil, "No other public server with room was found. Try again later." end
		if type(cursor) ~= "string" or #cursor > 4096 or seen[cursor] then
			return nil, "Server list pagination is invalid. Try again later."
		end
		seen[cursor] = true
		if page < 10 then task.wait(0.3) end
	end
	return nil, "No available server found in the first 10 pages. Try again later."
end

function MiscSystem.ServerHop()
	local operation, reason = beginServer("Searching")
	if not operation then return false, reason end
	serverTimeout = task.delay(30, function()
		finishServer(operation, "Failed", "Server search timed out. Check HTTP access and try again.")
	end)
	serverWorker = task.defer(function()
		local ok, jobId, failure = pcall(findServer, operation)
		if destroyed or serverOperation ~= operation then return end
		if not ok or not jobId then
			finishServer(operation, "Failed", ok and failure or "Server search failed. Check executor HTTP support and try again.")
			return
		end
		startTeleport(operation, jobId)
	end)
	serverStatus("Searching", "Searching for another public server with room...")
	return true
end
function MiscSystem.CancelServerSearch()
	if not serverOperation or serverOperation.Phase ~= "Searching" then return false end
	finishServer(serverOperation, "Cancelled", "Server search cancelled")
	return true
end
function MiscSystem.SetServerListener(callback) serverListener = callback end
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
	local operation, reason = beginServer("Teleporting")
	if not operation then return false, reason end
	local jobId = #Players:GetPlayers() > 1 and game.JobId ~= "" and game.JobId or nil
	return startTeleport(operation, jobId)
end
function MiscSystem.SetStateListener(callback) listener = callback end
function MiscSystem.IsFullbright() return State.IsFullbright end
function MiscSystem.IsAntiAFK() return State.IsAntiAFK end
function MiscSystem.GetState() return table.clone(State) end
function MiscSystem.Destroy()
	if destroyed then return end
	MiscSystem.SetFullbright(false); MiscSystem.SetAntiAFK(false)
	destroyed = true; listener = nil
	serverListener = nil
	if serverOperation then finishServer(serverOperation, "Cancelled", "Session closed") end
	for name in connections do disconnect(name) end
end
return MiscSystem
