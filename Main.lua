-- Diq bootstrap: load, validate, initialize, then build the UI.
local BASE_URL = "https://raw.githubusercontent.com/sRawiz/Diq/main/"

if type(_G.DiqCleanup) == "function" then
	local ok, err = pcall(_G.DiqCleanup)
	if not ok then warn("[Diq] Previous cleanup failed: " .. tostring(err)) end
end

local App = { Destroyed = false, Modules = {} }
local MyWindow
local cleanup
cleanup = function()
	if App.Destroyed then return end
	App.Destroyed = true
	for i = #App.Modules, 1, -1 do
		local entry = App.Modules[i]
		local ok, err = pcall(function() entry.Module:Destroy() end)
		if not ok then warn("[Diq] Cleanup failed (" .. entry.Name .. "): " .. tostring(err)) end
	end
	if _G.DiqCleanup == cleanup then _G.DiqCleanup = nil end
end
_G.DiqCleanup = cleanup

local function TraceError(err)
	return debug and debug.traceback and debug.traceback(tostring(err), 2) or tostring(err)
end

local function LoadModule(name, methods, optional)
	local function fail(stage, err)
		local message = "[Diq] " .. name .. " " .. stage .. " failed: " .. tostring(err)
		if optional then warn(message); return nil end
		error(message, 0)
	end
	local ok, source = pcall(function()
		return game:HttpGet(BASE_URL .. name .. ".lua?_=" .. tostring(os.clock()))
	end)
	if App.Destroyed then error("[Diq] Startup cancelled", 0) end
	if not ok then return fail("download", source) end
	if type(source) ~= "string" or source == "" then return fail("download", "empty or invalid response") end
	if type(loadstring) ~= "function" then return fail("compile", "loadstring is unavailable") end
	local compiled, chunk, compileError = pcall(loadstring, source, "@Diq/" .. name)
	if not compiled then return fail("compile", chunk) end
	if not chunk then return fail("compile", compileError) end
	local ran, result = xpcall(function() return chunk({ DeferInit = true }) end, TraceError)
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
	return result
end

local function Start()
	local DiqUI = LoadModule("DiqUILib", { "CreateWindow", "Destroy", "LoadIcons", "Notify" })
	local DiqIcons = LoadModule("DiqIcons", {  }, true)
	local Movement = LoadModule("MovementSystem", { "Destroy", "Init", "ResetCharacter", "SetCFrameSpeed", "SetFly", "SetFlySpeed", "SetInfinityJump", "SetNoClip", "SetNoFling", "SetSpeed", "Unanchor" })
	local ESP = LoadModule("ESPSystem", { "Destroy", "Init", "SetBoxes", "SetEnabled", "SetHealth", "SetHighlights", "SetNames", "SetTracers", "SetUseTeamColor", "SetColorMode", "SetRelationVisible", "SetRelationColor", "SetShowRelation", "SetTeamAttribute", "SetMaxDistance" })
	local Aimbot = LoadModule("AimbotSystem", { "Destroy", "Init", "ApplyAssistPreset", "SetEnabledListener", "SetEnabled", "SetAimPart", "SetFOVRadius", "SetShowFOV" })
	local Hitbox = LoadModule("HitboxSystem", { "Destroy", "Init", "SetEnabled", "SetSize", "SetTargetPart", "SetTeamCheck", "SetTransparency" })
	local Misc = LoadModule("MiscSystem", { "Destroy", "Rejoin", "SetAntiAFK", "SetFullbright" })

	for _, entry in App.Modules do
		if App.Destroyed then error("[Diq] Startup cancelled", 0) end
		if type(entry.Module.Init) == "function" then entry.Module.Init() end
	end
	-- ⭐ โหลด Icon เข้า Library (ทำครั้งเดียว)
	if DiqIcons then
		DiqUI:LoadIcons(DiqIcons)
	end

	MyWindow = DiqUI:CreateWindow({
		OnClose = cleanup,
		Title = "Diq",
		ToggleKey = Enum.KeyCode.K,
	})

	-- ==========================================
	-- 🏃 Tab: Movement (ใช้ Lucide icon "move")
	-- ==========================================
	local movementTab = MyWindow:CreateTab("Movement", "move")

	movementTab:CreateLabel("MOVEMENT SETTINGS")

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

	movementTab:CreateToggle("Infinite Jump", false, function(state)
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

	movementTab:CreateLabel("ACTIONS")

	movementTab:CreateButton("Reset Character", function()
		Movement.ResetCharacter()
	end, { Icon = "skull" })

	movementTab:CreateButton("Unanchor", function()
		Movement.Unanchor()
		DiqUI:Notify("Success", "Character unanchored", 2, "success")
	end, { Icon = "shield" })

	-- ==========================================
	-- 🎯 Tab: Combat (ใช้ Lucide icon "crosshair")
	-- ==========================================
	local aimTab = MyWindow:CreateTab("Aim Assist", "crosshair")

	aimTab:CreateLabel("AIM ASSIST")
	Aimbot.ApplyAssistPreset()
	local aimAssistToggle = aimTab:CreateToggle("Aim Assist [Q]", false, function(enabled)
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
	aimTab:CreateLabel("Q: on/off | Visible opponents only")

	local combatTab = MyWindow:CreateTab("Combat", "shield")
	combatTab:CreateLabel("HITBOX EXPANDER")

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

	combatTab:CreateLabel("CHECKS")

	combatTab:CreateToggle("Hitbox Team Check", true, function(state)
		Hitbox.SetTeamCheck(state)
	end, { Icon = "users" })



	-- ==========================================
	-- 👁️ Tab: Visuals (ใช้ Lucide icon "eye")
	-- ==========================================
	local visualTab = MyWindow:CreateTab("Visuals", "eye")

	visualTab:CreateLabel("ESP MASTER")

	visualTab:CreateToggle("Enable ESP", false, function(state)
		ESP.SetEnabled(state)
	end, { Icon = "eye" })

	visualTab:CreateLabel("ESP ELEMENTS")

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

	visualTab:CreateLabel("ESP TEAMS")
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

	visualTab:CreateLabel("WORLD VISUALS")

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
	local settingsTab = MyWindow:CreateTab("Settings", "settings")

	settingsTab:CreateLabel("PROFILE")

	-- Get Executor Name
	local executorName = "Unknown"
	if identifyexecutor then
		executorName = identifyexecutor()
	end

	-- สร้างการ์ดโปรไฟล์ที่มีรูป Avatar
	settingsTab:CreateProfileCard(
		game.Players.LocalPlayer.Name,
		executorName,
		game.Players.LocalPlayer.UserId
	)

	settingsTab:CreateLabel("WINDOW SHORTCUT")
	settingsTab:CreateKeybind("Show / Hide Window", MyWindow:GetToggleKey(), nil, {
		OnChanged = function(key)
			MyWindow:SetToggleKey(key)
		end,
	})

	settingsTab:CreateLabel("UTILITY")

	settingsTab:CreateToggle("Anti-AFK (Prevent Idle Kick)", false, function(state)
		Misc.SetAntiAFK(state)
		if state then
			DiqUI:Notify("Anti-AFK Enabled", "You will no longer be kicked for idling.", 3, "success")
		end
	end, { Icon = "coffee" })

	settingsTab:CreateLabel("SERVER MANAGEMENT")

	settingsTab:CreateButton("Rejoin Server", function()
		DiqUI:Notify("Server", "Rejoining the current server...", 3, "info")
		task.delay(0.5, function()
			if not App.Destroyed then Misc.Rejoin() end
		end)
	end, { Icon = "rotate-cw" })

	settingsTab:CreateLabel("DANGER ZONE")

	settingsTab:CreateButton("Reset All Settings", function()
		MyWindow:ResetAll()
		task.wait(0.15) -- รอให้ระบบปิดแจ้งเตือนจังหวะ Reset ทำงานเสร็จก่อน
		DiqUI:Notify("Reset Complete", "All settings restored to defaults", 3, "success")
	end, { Icon = "rotate-ccw" })

	settingsTab:CreateLabel("ABOUT")

	settingsTab:CreateButton("About Diq Panel", function()
		DiqUI:Notify("Diq UI Library", "Version 3.0 — by sRawiz\nRefactored Edition", 3, "info")
	end, { Icon = "info" })

	-- ==========================================
	-- ✅ แจ้งเตือนว่าโหลดสำเร็จ
	-- ==========================================
	DiqUI:Notify("Loaded Successfully!", "Diq Panel v3.0 is ready\nPress K to toggle UI", 4, "success")
	print("[Diq] Panel v3.0 Loaded Successfully!")

end

local ok, err = xpcall(Start, TraceError)
if not ok then
	cleanup()
	warn("[Diq] Startup failed: " .. tostring(err))
end
