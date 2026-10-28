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
	local ESP = LoadModule("ESPSystem", { "Destroy", "Init", "SetBoxes", "SetEnabled", "SetHealth", "SetHighlights", "SetNames", "SetTracers", "SetUseTeamColor" })
	local Aimbot = LoadModule("AimbotSystem", { "Destroy", "GetStatus", "Init", "SetActivationKey", "SetActivationMode", "SetAimMethod", "SetAimPart", "SetEnabled", "SetFOVRadius", "SetMaxDistance", "SetShowFOV", "SetSmoothing", "SetTeamCheck", "SetTargetMode", "SetCrosshairWeight", "SetSwitchDelay", "SetAutoSwitch", "SetInputSuspended", "SetNextTargetKey", "GetNextTargetKey", "GetActivationKey", "SetWallCheck" })
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
	local combatTab = MyWindow:CreateTab("Combat", "crosshair")

	combatTab:CreateLabel("AIMBOT MASTER")

	combatTab:CreateToggle("Enable Aimbot", false, function(state)
		Aimbot.SetEnabled(state)
		if state then
			DiqUI:Notify("Aimbot Enabled", "Q: start / stop aiming. T: next target. Buttons configurable below.", 3, "info")
		end
	end, { Icon = "crosshair" })

	combatTab:CreateDropdown("Aim Activation Mode", { "Toggle", "Hold" }, "Toggle", function(mode)
		Aimbot.SetActivationMode(mode)
	end)
	local keyboardAimKey = Enum.KeyCode.Q
	local aimButtonDropdown
	local selectedAimButton = "Keyboard"
	aimButtonDropdown = combatTab:CreateDropdown("Aim Button", { "Keyboard", "Right Mouse", "Left Mouse" }, "Keyboard", function(button)
		local key = button == "Right Mouse" and "MouseButton2" or (button == "Left Mouse" and "MouseButton1" or keyboardAimKey.Name)
		local ok, reason = Aimbot.SetActivationKey(key)
		if not ok then
			aimButtonDropdown:Set(selectedAimButton)
			DiqUI:Notify("Key Conflict", reason, 4, "warning")
		else
			selectedAimButton = button
		end
	end)
	local aimKeybind, nextKeybind
	local restoringKey = false
	aimKeybind = combatTab:CreateKeybind("Keyboard Aim Button", Enum.KeyCode.Q, nil, {
		OnListeningChanged = Aimbot.SetInputSuspended,
		OnChanged = function(key)
			if restoringKey then return end
			local ok, reason = Aimbot.SetActivationKey(key.Name)
			if not ok then
				restoringKey = true; aimKeybind:Set(keyboardAimKey); restoringKey = false
				DiqUI:Notify("Key Conflict", reason, 4, "warning")
				return
			end
			keyboardAimKey = key
			aimButtonDropdown:Set("Keyboard")
		end,
	})
	nextKeybind = combatTab:CreateKeybind("Next Target Button", Enum.KeyCode.T, nil, {
		OnListeningChanged = Aimbot.SetInputSuspended,
		OnChanged = function(key)
			if restoringKey then return end
			local ok, reason = Aimbot.SetNextTargetKey(key.Name)
			if not ok then
				restoringKey = true; nextKeybind:Set(Enum.KeyCode[Aimbot.GetNextTargetKey()]); restoringKey = false
				DiqUI:Notify("Key Conflict", reason, 4, "warning")
			end
		end,
	})
	combatTab:CreateButton("Diagnose Aimbot", function()
		local snapshot = Aimbot.GetStatus()
		local reasons = {}
		for reason, count in pairs(snapshot.Rejected) do table.insert(reasons, reason .. ": " .. count) end
		table.sort(reasons)
		local message = snapshot.Reason .. " | " .. snapshot.Method .. " | " .. snapshot.TargetMode .. " | " .. snapshot.ActivationMode .. " " .. snapshot.ActivationKey
		if #reasons > 0 then message = message .. "\n" .. table.concat(reasons, ", ") end
		print("[Diq] Aim status: " .. message)
		DiqUI:Notify("Aimbot Diagnostics", message, 6, "info")
	end)

	combatTab:CreateToggle("Show FOV Circle", false, function(state)
		Aimbot.SetShowFOV(state)
	end, { Icon = "circle" })

	combatTab:CreateLabel("TARGET SELECTION")
	combatTab:CreateToggle("Auto Switch to Better Target", false, function(value)
		Aimbot.SetAutoSwitch(value)
	end)
	local targetModes = {
		["Balanced: Crosshair + Distance"] = "Balanced",
		["Closest to Crosshair"] = "Smart",
		["Closest Player"] = "Nearest",
		["Keep Current Target"] = "Sticky",
	}
	combatTab:CreateDropdown("Target Priority", { "Balanced: Crosshair + Distance", "Closest to Crosshair", "Closest Player", "Keep Current Target" }, "Balanced: Crosshair + Distance", function(choice)
		Aimbot.SetTargetMode(targetModes[choice])
	end)
	combatTab:CreateSlider("Balanced: Crosshair Weight (%)", 0, 100, 70, function(value)
		Aimbot.SetCrosshairWeight(value / 100)
	end)
	combatTab:CreateSlider("Target Switch Delay (ms)", 100, 1000, 200, function(value)
		Aimbot.SetSwitchDelay(value / 1000)
	end)

	combatTab:CreateLabel("AIMBOT SETTINGS")

	combatTab:CreateSlider("FOV Size", 10, 800, 150, function(value)
		Aimbot.SetFOVRadius(value)
	end)

	combatTab:CreateSlider("Aim Response (Higher = Faster)", 1, 100, 50, function(value)
	    -- Map 1-100 to 0.01-1
		Aimbot.SetSmoothing(value / 100)
	end)

	combatTab:CreateDropdown("Aim Part", { "Head", "Torso", "HumanoidRootPart" }, "Head", function(selected)
		Aimbot.SetAimPart(selected)
	end)

	local aimMethodDropdown
	aimMethodDropdown = combatTab:CreateDropdown("Aim Method", { "Camera", "Mouse" }, "Camera", function(selected)
		local ok, reason = Aimbot.SetAimMethod(selected)
		if not ok then
			aimMethodDropdown:Set(Aimbot.GetAimMethod())
			DiqUI:Notify("Aim Method Unavailable", reason, 4, "warning")
		end
	end)
	combatTab:CreateSlider("Max Aim Distance (studs)", 100, 10000, 3000, function(value)
		Aimbot.SetMaxDistance(value)
	end)

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

	combatTab:CreateToggle("Team Check", true, function(state)
		Aimbot.SetTeamCheck(state)
		Hitbox.SetTeamCheck(state)
	end, { Icon = "users" })

	combatTab:CreateToggle("Wall Check (Visible Only)", false, function(state)
		Aimbot.SetWallCheck(state)
	end, { Icon = "eye-off" })

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

	visualTab:CreateLabel("ESP SETTINGS")

	visualTab:CreateToggle("Use Team Color", true, function(state)
		ESP.SetUseTeamColor(state)
	end, { Icon = "users" })

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
