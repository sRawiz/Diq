-- Options can supply Sources/Factories for local tests or a self-contained build.
-- Remote sessions resolve main once, then fetch every module from that commit.
local StartupOptions = ...
if type(StartupOptions) ~= "table" then StartupOptions = type(_G.DiqOptions) == "table" and _G.DiqOptions or {} end
local App = { Destroyed = false, Modules = {} }
local revision = StartupOptions.Revision
local function ReadSource(name)
	if StartupOptions.Sources then
		assert(type(StartupOptions.Sources[name]) == "string", "Local module missing: " .. name)
		return StartupOptions.Sources[name]
	end
	if not revision then
		local response = game:HttpGet("https://api.github.com/repos/sRawiz/Diq/commits/main")
		if App.Destroyed then error("[Diq] Startup cancelled", 0) end
		local metadata = game:GetService("HttpService"):JSONDecode(response)
		revision = metadata.sha
	end
	assert(type(revision) == "string" and #revision == 40 and revision:match("^%x+$"),
		"Provide DiqOptions.Revision as a full commit SHA or use the bundled release")
	return game:HttpGet("https://raw.githubusercontent.com/sRawiz/Diq/" .. revision .. "/" .. name .. ".lua")
end

if type(_G.DiqCleanup) == "function" then
	local ok, err = pcall(_G.DiqCleanup)
	if not ok then warn("[Diq] Previous cleanup failed: " .. tostring(err)) end
end

local MyWindow
local loadingGui, loadingStatus, loadingFill, loadingPercent, loadingTitle, loadingButton, loadingConnection
local startupFailure = "Please close this screen and try again."
local function DestroyLoading()
	if loadingConnection then loadingConnection:Disconnect(); loadingConnection = nil end
	if loadingGui then loadingGui:Destroy(); loadingGui = nil end
end
local cleanup
cleanup = function(keepLoading)
	if not keepLoading then DestroyLoading() end
	if not (keepLoading and loadingGui) and _G.DiqCleanup == cleanup then _G.DiqCleanup = nil end
	if App.Destroyed then return end
	App.Destroyed = true
	-- Stop queued UI/actions before restoring feature state.
	if App.Runtime then App.Runtime.Scope:Remove("Actions") end
	if App.Runtime then App.Runtime.Input:Destroy() end
	for i = #App.Modules, 1, -1 do
		local entry = App.Modules[i]
		local ok, err = pcall(function() entry.Module:Destroy() end)
		if not ok then warn("[Diq] Cleanup failed (" .. entry.Name .. "): " .. tostring(err)) end
	end
end
_G.DiqCleanup = cleanup
function App:Destroy() cleanup() end

-- Bootstrap UI is local: it must appear before the first remote download.
-- It owns no render loops, external assets or executor Drawing objects.
local function CreateLoading()
	local function create(class, parent, props)
		local object = Instance.new(class)
		object.Parent = parent
		for key, value in props do object[key] = value end
		return object
	end
	local accent = Color3.fromRGB(84, 98, 239)
	loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "Diq_Loading"
	loadingGui.ResetOnSpawn = false
	loadingGui.IgnoreGuiInset = true
	loadingGui.DisplayOrder = 100
	loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local shade = create("Frame", loadingGui, {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BackgroundTransparency = 0.3, BorderSizePixel = 0, Active = true,
	})
	local card = create("Frame", shade, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.88, 0, 0, 250), BackgroundColor3 = Color3.fromRGB(18, 18, 20), BorderSizePixel = 0,
	})
	create("UISizeConstraint", card, { MaxSize = Vector2.new(420, 250) })
	create("UICorner", card, { CornerRadius = UDim.new(0, 16) })
	create("UIStroke", card, { Color = Color3.fromRGB(44, 45, 50), Thickness = 1 })
	local function label(name, text, y, height, size, color)
		return create("TextLabel", card, {
			Name = name, Text = text, Position = UDim2.new(0, 26, 0, y), Size = UDim2.new(1, -52, 0, height),
			BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = size,
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		})
	end
	label("Brand", "DIQ", 22, 26, 22, accent)
	loadingTitle = label("Title", "Getting things ready", 62, 30, 21, Color3.fromRGB(235, 236, 240))
	loadingStatus = label("Status", "Starting Diq...", 99, 42, 13, Color3.fromRGB(150, 151, 158))
	local track = create("Frame", card, {
		Position = UDim2.new(0, 26, 0, 157), Size = UDim2.new(1, -52, 0, 5),
		BackgroundColor3 = Color3.fromRGB(36, 36, 41), BorderSizePixel = 0, ClipsDescendants = true,
	})
	create("UICorner", track, { CornerRadius = UDim.new(1, 0) })
	loadingFill = create("Frame", track, {
		Name = "Progress", Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0,
	})
	create("UICorner", loadingFill, { CornerRadius = UDim.new(1, 0) })
	loadingPercent = label("Percent", "0%", 184, 32, 13, Color3.fromRGB(150, 151, 158))
	loadingPercent.Size = UDim2.new(0.5, -26, 0, 32)
	loadingButton = create("TextButton", card, {
		Name = "Dismiss", Text = "Cancel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 184),
		Size = UDim2.fromOffset(90, 32), BackgroundColor3 = Color3.fromRGB(36, 36, 41), BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(219, 222, 225),
	})
	create("UICorner", loadingButton, { CornerRadius = UDim.new(0, 8) })
	loadingConnection = loadingButton.Activated:Connect(function() cleanup() end)
	if not pcall(function() loadingGui.Parent = game:GetService("CoreGui") end) then
		local player = game:GetService("Players").LocalPlayer
		local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
		assert(playerGui, "PlayerGui is not ready")
		loadingGui.Parent = playerGui
	end
end

local function SetLoading(text, fraction)
	if App.Destroyed then error("[Diq] Startup cancelled", 0) end
	if loadingGui then
		loadingStatus.Text = text
		loadingFill.Size = UDim2.fromScale(fraction, 1)
		loadingPercent.Text = tostring(math.floor(fraction * 100)) .. "%"
		-- Give the client a frame to paint and process Cancel, including bundled runs.
		task.wait()
	end
	if App.Destroyed then error("[Diq] Startup cancelled", 0) end
end

function App:GetDiagnostics()
	local result = { Destroyed = self.Destroyed, Revision = revision or "bundled/local", Tasks = {}, Features = {} }
	if self.Runtime then
		for name, stats in self.Runtime.Scheduler.stats do result.Tasks[name] = table.clone(stats) end
	end
	for _, entry in self.Modules do
		if entry.Module.GetMetrics then result.Features[entry.Name] = entry.Module.GetMetrics() end
	end
	return result
end

local function TraceError(err)
	return debug and debug.traceback and debug.traceback(tostring(err), 2) or tostring(err)
end

local loadedModules = 0
local moduleLabels = {
	Infrastructure = "Preparing the session", DiqUILib = "Loading the interface", DiqIcons = "Loading icons",
	MovementSystem = "Loading movement controls", ESPSystem = "Loading visual controls", AimbotSystem = "Loading aim controls",
	HitboxSystem = "Loading hitbox controls", MiscSystem = "Loading extra tools", Preferences = "Loading preferences",
	Keybinds = "Loading shortcuts", ControlCenter = "Loading the control center",
}
local function LoadModule(name, methods, optional)
	SetLoading(moduleLabels[name] or "Loading components", loadedModules / 11 * 0.7)
	startupFailure = "A required component could not be loaded. Please try again."
	local function fail(stage, err)
		local message = "[Diq] " .. name .. " " .. stage .. " failed: " .. tostring(err)
		if optional then loadedModules += 1; warn(message); return nil end
		if stage == "download" then startupFailure = "Download failed. Check your connection and try again."
		elseif stage == "compile" then startupFailure = "A component could not be prepared. Check the script version and runtime."
		else startupFailure = "A component could not start. See the console for details." end
		error(message, 0)
	end
	local chunk = StartupOptions.Factories and StartupOptions.Factories[name]
	if StartupOptions.Factories and type(chunk) ~= "function" then return fail("validation", "bundled module missing") end
	if not chunk then
		local ok, source = pcall(ReadSource, name)
		if App.Destroyed then error("[Diq] Startup cancelled", 0) end
		if not ok then return fail("download", "source unavailable; check network, commit SHA, or bundled release") end
		if type(source) ~= "string" or source == "" then return fail("download", "empty or invalid response") end
		if type(loadstring) ~= "function" then return fail("compile", "loadstring unavailable; use the bundled release") end
		local compiled, compileError
		compiled, chunk, compileError = pcall(loadstring, source, "@Diq/" .. name)
		if not compiled then return fail("compile", chunk) end
		if not chunk then return fail("compile", compileError) end
	end
	local ran, result = xpcall(function() return chunk({ DeferInit = true, Runtime = App.Runtime }) end, TraceError)
	if App.Destroyed then
		if ran and type(result) == "table" and type(result.Destroy) == "function" then
			pcall(function() result:Destroy() end)
		end
		error("[Diq] Startup cancelled", 0)
	end
	if not ran then return fail("execution", result) end
	if type(result) ~= "table" then return fail("validation", "expected module table") end
	-- Register before validation/Init so partial startup can be rolled back.
	if type(result.Destroy) == "function" then
		table.insert(App.Modules, { Name = name, Module = result })
	end
	for _, method in methods do
		if type(result[method]) ~= "function" then return fail("validation", "missing method " .. method) end
	end
	loadedModules += 1
	return result
end

local function Start()
	local shown = pcall(CreateLoading)
	if not shown then DestroyLoading(); warn("[Diq] Loading screen unavailable; continuing startup") end
	local Infrastructure = LoadModule("Infrastructure", { "new" })
	App.Runtime = Infrastructure.new()
	table.insert(App.Modules, { Name = "Infrastructure", Module = App.Runtime })
	App.Actions = App.Runtime.Scope:Add(App.Runtime:CreateScope(), "Actions")
	local DiqUI = LoadModule("DiqUILib", { "CreateWindow", "Destroy", "LoadIcons", "Notify" })
	local DiqIcons = LoadModule("DiqIcons", {  }, true)
	local Movement = LoadModule("MovementSystem", { "Destroy", "Init", "ResetCharacter", "SetCFrameSpeed", "SetFly", "SetFlySpeed", "SetInfinityJump", "SetNoClip", "SetNoFling", "SetSpeed", "Unanchor", "GetState", "SetStateListener" })
	local ESP = LoadModule("ESPSystem", { "Destroy", "Init", "SetBoxes", "SetEnabled", "SetHealth", "SetHighlights", "SetNames", "SetTracers", "SetUseTeamColor", "SetColorMode", "SetRelationVisible", "SetRelationColor", "SetShowRelation", "SetTeamAttribute", "SetMaxDistance", "SetPerformance", "IsEnabled" })
	local Aimbot = LoadModule("AimbotSystem", { "Destroy", "Init", "ApplyAssistPreset", "SetEnabledListener", "SetEnabled", "SetAimPart", "SetFOVRadius", "SetShowFOV", "SetManagedInput", "SetScanInterval", "SetInputSuspended", "IsEnabled" })
	local Hitbox = LoadModule("HitboxSystem", { "Destroy", "Init", "SetEnabled", "SetSize", "SetTargetPart", "SetTeamCheck", "SetTransparency", "IsEnabled" })
	local Misc = LoadModule("MiscSystem", { "Destroy", "Rejoin", "ServerHop", "FindBestServer", "CancelServerSearch", "SetServerListener", "SetAntiAFK", "SetFullbright", "IsAntiAFK", "IsFullbright", "SetStateListener" })
	local Preferences = LoadModule("Preferences", { "new" })
	local Keybinds = LoadModule("Keybinds", { "new" })
	local ControlCenter = LoadModule("ControlCenter", { "new" })

	startupFailure = "Setup could not finish. See the console for details."
	for index, entry in App.Modules do
		if App.Destroyed then error("[Diq] Startup cancelled", 0) end
		SetLoading("Setting up your session", 0.7 + (index - 1) / #App.Modules * 0.2)
		if type(entry.Module.Init) == "function" then entry.Module.Init() end
	end
	-- ⭐ โหลด Icon เข้า Library (ทำครั้งเดียว)
	if DiqIcons then
		DiqUI:LoadIcons(DiqIcons)
	end

	SetLoading("Building your panel", 0.92)
	MyWindow = DiqUI:CreateWindow({
		OnClose = function() cleanup() end,
		Title = "Diq",
		ToggleKey = Enum.KeyCode.K,
		ManagedInput = true,
	})
	local Controls = ControlCenter.new({ App = App, Window = MyWindow, UI = DiqUI, Runtime = App.Runtime,
		Preferences = Preferences, Keybinds = Keybinds,
		Modules = { Movement = Movement, ESP = ESP, Aim = Aimbot, Hitbox = Hitbox, Misc = Misc },
	})
	App.Tools = Controls
	table.insert(App.Modules, { Name = "ControlCenter", Module = Controls })

	-- ==========================================
	-- 🏃 Tab: Movement (ใช้ Lucide icon "move")
	-- ==========================================
	local movementPage = Controls:TrackTab(MyWindow:CreateTab("Movement", "move", { Description = "Move your way. Tune speed, flight and character controls." }), "movement")
	local movementTab = movementPage:CreateSection("Movement controls")

	local flyToggle
	flyToggle = movementTab:CreateToggle("CFrame Fly", false, function(state)
		Movement.SetFly(state)
		DiqUI:Notify(
			state and "Fly Enabled" or "Fly Disabled",
			state and "Press key to disable" or "Returned to normal",
			2,
			state and "info" or "warning"
		)
	end, {
		Icon = "plane",
		Keybind = {
			Default = Enum.KeyCode.F,
		},
		Slider = {
			Text = "Fly Speed",
			Min = 10,
			Max = 500,
			Default = 100,
			Callback = function(val) Movement.SetFlySpeed(val) end
		}
	})

	local speedToggle
	speedToggle = movementTab:CreateToggle("CFrame Speed", false, function(state)
		Movement.SetSpeed(state)
		DiqUI:Notify(
			state and "Speed Enabled" or "Speed Disabled",
			state and "Press key to disable" or "Returned to normal",
			2,
			state and "info" or "warning"
		)
	end, {
		Icon = "zap",
		Keybind = {
			Default = Enum.KeyCode.G,
		},
		Slider = {
			Text = "Walk Speed",
			Min = 10,
			Max = 300,
			Default = 60,
			Callback = function(val) Movement.SetCFrameSpeed(val) end
		}
	})

	local jumpToggle = movementTab:CreateToggle("Infinite Jump", false, function(state)
		Movement.SetInfinityJump(state)
	end, { Icon = "chevron-up" })

	local noClipToggle
	noClipToggle = movementTab:CreateToggle("NoClip", false, function(state)
		Movement.SetNoClip(state)
		DiqUI:Notify(
			state and "NoClip Enabled" or "NoClip Disabled",
			state and "You can walk through walls" or "Collision restored",
			2,
			state and "info" or "warning"
		)
	end, {
		Icon = "ghost",
		Keybind = {
			Default = Enum.KeyCode.V,
		}
	})

	local noFlingToggle
	noFlingToggle = movementTab:CreateToggle("Anti-Fling", false, function(state)
		Movement.SetNoFling(state)
		DiqUI:Notify(
			state and "Anti-Fling Enabled" or "Anti-Fling Disabled",
			state and "Other players cannot fling you" or "Normal physics restored",
			2,
			state and "info" or "warning"
		)
	end, {
		Icon = "shield-alert",
		Keybind = {
			Default = Enum.KeyCode.B,
		}
	})
	Movement.SetStateListener(function(state)
		flyToggle:Set(state.IsFlying, true)
		speedToggle:Set(state.IsCFrameSpeed, true)
		noClipToggle:Set(state.IsNoClip, true)
		noFlingToggle:Set(state.IsNoFling, true)
		jumpToggle:Set(state.IsInfinityJump, true)
	end)

	movementPage:CreateLabel("CHARACTER ACTIONS")
	local characterActions = movementPage:CreateActionGroup({ Columns = 2, MinWidth = 150 })

	characterActions:CreateButton("Reset Character", function()
		Movement.ResetCharacter()
	end, { Icon = "skull" })

	characterActions:CreateButton("Unanchor", function()
		Movement.Unanchor()
		DiqUI:Notify("Success", "Character unanchored", 2, "success")
	end, { Icon = "shield" })

	-- ==========================================
	-- 🎯 Tab: Combat (ใช้ Lucide icon "crosshair")
	-- ==========================================
	local aimPage = Controls:TrackTab(MyWindow:CreateTab("Aim Assist", "crosshair", { Description = "Adjust targeting and the field of view. Shortcuts live in Keybinds." }), "aim")
	local aimTab = aimPage:CreateSection("Targeting")
	Aimbot.ApplyAssistPreset()
	local aimAssistToggle = aimTab:CreateToggle("Aim Assist", false, function(enabled)
		Aimbot.SetEnabled(enabled)
	end, { Icon = "crosshair" })
	Aimbot.SetEnabledListener(function(enabled)
		aimAssistToggle:Set(enabled, true)
	end)
	aimTab:CreateDropdown("Aim At", { "Head", "Body" }, "Head", function(part)
		Aimbot.SetAimPart(part)
	end)
	aimTab:CreateSlider("FOV Radius", 20, 400, 150, function(radius)
		Aimbot.SetFOVRadius(radius)
	end)
	aimTab:CreateToggle("Show FOV", true, function(visible)
		Aimbot.SetShowFOV(visible)
	end, { Icon = "circle" })
	aimPage:CreateLabel("Shortcuts and Hold / Toggle modes are in Keybinds", { Wrap = true })

	local combatPage = Controls:TrackTab(MyWindow:CreateTab("Combat", "shield", { Description = "Configure hitboxes and choose which targets are included." }), "combat")
	local combatTab = combatPage:CreateSection("Hitbox configuration")

	combatTab:CreateToggle("Enable Hitbox Expander", false, function(state)
		Hitbox.SetEnabled(state)
		if state then
			DiqUI:Notify("Hitbox Enabled", "Enemy hitboxes are now expanded", 2, "info")
		end
	end, { Icon = "maximize" })

	combatTab:CreateSlider("Hitbox Size", 2, 20, 5, function(value)
		Hitbox.SetSize(value)
	end)

	combatTab:CreateSlider("Transparency", 0, 100, 50, function(value)
	    -- Map 0-100 to 0-1
		Hitbox.SetTransparency(value / 100)
	end)

	combatTab:CreateDropdown("Target Part", { "Head", "HumanoidRootPart" }, "Head", function(selected)
		Hitbox.SetTargetPart(selected)
	end)

	combatTab = combatPage:CreateSection("Target checks")

	combatTab:CreateToggle("Hitbox Team Check", true, function(state)
		Hitbox.SetTeamCheck(state)
	end, { Icon = "users" })



	-- ==========================================
	-- 👁️ Tab: Visuals (ใช้ Lucide icon "eye")
	-- ==========================================
	local visualPage = Controls:TrackTab(MyWindow:CreateTab("Visuals", "eye", { Description = "Choose what to see, who to highlight and how the world looks." }), "visual")
	local visualTab = visualPage:CreateSection("Overlay")

	visualTab:CreateToggle("Enable ESP", false, function(state)
		ESP.SetEnabled(state)
	end, { Icon = "eye" })

	visualTab = visualPage:CreateSection("Visible elements")

	visualTab:CreateToggle("Show Highlights", true, function(state)
		ESP.SetHighlights(state)
	end, { Icon = "sun" })

	visualTab:CreateToggle("Show Boxes", false, function(state)
		ESP.SetBoxes(state)
	end, { Icon = "square" })

	visualTab:CreateToggle("Show Health Bar", false, function(state)
		ESP.SetHealth(state)
	end, { Icon = "activity" })

	visualTab:CreateToggle("Show Names & Distance", false, function(state)
		ESP.SetNames(state)
	end, { Icon = "type" })

	visualTab:CreateToggle("Show Tracers", false, function(state)
		ESP.SetTracers(state)
	end, { Icon = "git-commit" })

	visualTab = visualPage:CreateSection("Teams & colors")
	visualTab:CreateToggle("Show Teammates", true, function(state)
		ESP.SetRelationVisible("Teammate", state)
	end, { Icon = "users" })
	visualTab:CreateToggle("Show Enemies", true, function(state)
		ESP.SetRelationVisible("Enemy", state)
	end, { Icon = "eye" })
	visualTab:CreateToggle("Show Unknown / Neutral", true, function(state)
		ESP.SetRelationVisible("Unknown", state)
	end, { Icon = "users" })
	visualTab:CreateToggle("Show Relation in Names", true, function(state)
		ESP.SetShowRelation(state)
	end, { Icon = "type" })
	visualTab:CreateDropdown("ESP Colors", { "Relation", "Team", "Uniform" }, "Relation", function(mode)
		ESP.SetColorMode(mode)
	end)
	local espPalette = {
		Blue = Color3.fromRGB(80, 200, 255), Red = Color3.fromRGB(255, 70, 90),
		Gold = Color3.fromRGB(255, 200, 80), Green = Color3.fromRGB(90, 230, 130),
		Purple = Color3.fromRGB(190, 120, 255), White = Color3.fromRGB(255, 255, 255),
	}
	for _, entry in { { "Teammate", "Blue" }, { "Enemy", "Red" }, { "Unknown", "Gold" } } do
		local relation = entry[1]
		visualTab:CreateDropdown(relation .. " Color", { "Blue", "Red", "Gold", "Green", "Purple", "White" }, entry[2], function(name)
			ESP.SetRelationColor(relation, espPalette[name])
		end)
	end
	visualTab:CreateSlider("ESP Range (studs, 0 = unlimited)", 0, 5000, 0, function(value)
		ESP.SetMaxDistance(value)
	end)
	visualTab:CreateInput("Team Attribute (optional)", "Empty = Roblox teams", function(value)
		ESP.SetTeamAttribute(value:match("^%s*(.-)%s*$"))
	end)

	visualTab = visualPage:CreateSection("World lighting")

	visualTab:CreateToggle("Fullbright & No Fog", false, function(state)
		Misc.SetFullbright(state)
		DiqUI:Notify(
			state and "Fullbright Enabled" or "Fullbright Disabled",
			state and "Map lighting set to maximum" or "Lighting restored",
			2,
			state and "info" or "warning"
		)
	end, { Icon = "sun" })

	-- ==========================================
	-- ⚙️ Tab: Settings (ใช้ Lucide icon "settings")
	-- ==========================================
	local settingsTab = Controls:TrackTab(MyWindow:CreateTab("Settings", "settings", { Description = "Your session, server connections and workspace preferences." }), "settings")

	-- Get Executor Name
	local executorName = "Unknown"
	if type(identifyexecutor) == "function" then
		local success, name = pcall(identifyexecutor)
		if success and type(name) == "string" then executorName = name end
	end

	-- สร้างการ์ดโปรไฟล์ที่มีรูป Avatar
	settingsTab:CreateProfileCard(
		game:GetService("Players").LocalPlayer.Name,
		executorName,
		game:GetService("Players").LocalPlayer.UserId
	)

	settingsTab:CreateLabel("Manage shortcuts in Keybinds. End stops all features.", { Wrap = true })

	local utility = settingsTab:CreateSection("Session preferences")

	local antiAfkToggle
	antiAfkToggle = utility:CreateToggle("Anti-AFK (Prevent Idle Kick)", false, function(state)
		local ok, reason = Misc.SetAntiAFK(state)
		if not ok then
			antiAfkToggle:Set(false, true)
			DiqUI:Notify("Anti-AFK unavailable", reason, 3, "warning")
		end
	end, { Icon = "coffee" })
	Misc.SetStateListener(function(state) antiAfkToggle:Set(state.IsAntiAFK, true) end)

	settingsTab:CreateLabel("SERVER CONNECTIONS")
	local serverCards = settingsTab:CreateActionGroup({ Cards = true })
	Misc.SetServerListener(function(phase, message)
		if not App.Destroyed then
			DiqUI:Notify("Server", message, phase == "Failed" and 6 or 3, phase == "Failed" and "warning" or "info")
		end
	end)
	serverCards:CreateButton("Find Best Server (Roblox)", function()
		local ok, reason = Misc.FindBestServer()
		if not ok and reason then DiqUI:Notify("Server", reason, 3, "warning") end
	end, { Icon = "globe", Description = "Let Roblox match your connection. May return to this server." })
	serverCards:CreateButton("Find New Server", function()
		local ok, reason = Misc.ServerHop()
		if not ok then DiqUI:Notify("Server", reason, 3, "warning") end
	end, { Icon = "search", Description = "Find another public server with room to join." })
	settingsTab:CreateLabel("Best Server considers location and latency; lowest ping is not guaranteed.", { Wrap = true })
	local serverActions = settingsTab:CreateActionGroup({ Columns = 2, MinWidth = 150 })
	serverActions:CreateButton("Cancel Server Search", function()
		if not Misc.CancelServerSearch() then
			DiqUI:Notify("Server", "No active search. A teleport already sent to Roblox cannot be cancelled here.", 3, "info")
		end
	end, { Icon = "x", Variant = "Ghost" })

	serverActions:CreateButton("Rejoin Server", function()
		local ok, reason = Misc.Rejoin()
		if not ok and reason then DiqUI:Notify("Server", reason, 3, "warning") end
	end, { Icon = "rotate-cw" })

	settingsTab:CreateLabel("WORKSPACE")
	local workspaceActions = settingsTab:CreateActionGroup({ Columns = 2, MinWidth = 150 })

	workspaceActions:CreateButton("Reset All Settings", function()
		local reset, reason = Controls:Reset()
		DiqUI:Notify(reset and "Reset Complete" or "Reset failed", reset and "All settings restored to defaults" or reason, 3, reset and "success" or "warning")
	end, { Icon = "rotate-ccw", Variant = "Danger" })


	workspaceActions:CreateButton("About Diq Panel", function()
		DiqUI:Notify("Diq UI Library", "Version 3.0 — by sRawiz\nRefactored Edition", 3, "info")
	end, { Icon = "info", Variant = "Ghost" })

	-- ==========================================
	-- ✅ แจ้งเตือนว่าโหลดสำเร็จ
	-- ==========================================
	Controls:Mount()
	SetLoading("Ready", 1)
	DestroyLoading()
	DiqUI:Notify("Loaded Successfully!", "Diq is ready\nK: panel | F1: quick actions | End: stop all", 4, "success")
	print("[Diq] Panel v3.0 Loaded Successfully!")

end


local ok, err = xpcall(Start, TraceError)
if not ok then
	if App.Destroyed then return nil, err end
	if loadingGui then
		loadingTitle.Text = "Couldn't start Diq"
		loadingStatus.Text = startupFailure
		loadingFill.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
		loadingPercent.Text = "Stopped"
		loadingButton.Text = "Close"
	end
	-- Roll back features now; keep only the dismissible error card until closed or rerun.
	cleanup(true)
	warn("[Diq] Startup failed: " .. tostring(err))
	return nil, err
end
return App
