-- ==========================================
-- 🎮 Loader / Main Controller v3.0 (Refactored)
-- ==========================================
-- Changes:
-- ✅ Cleanup ระบบเก่าก่อนโหลดใหม่ (ป้องกัน execute ซ้ำ leak)
-- ✅ LoadModule helper พร้อม pcall (ป้องกัน crash ทั้งหมด)
-- ✅ ใช้ os.clock() แทน tick() (deprecated)
-- ✅ ลงทะเบียน _G.DiqCleanup สำหรับ execute ครั้งถัดไป

-- ⚠️ เปลี่ยนให้ตรงกับ GitHub ของคุณ ⚠️
local GITHUB_USERNAME = "sRawiz"
local REPO_NAME = "Diq"

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USERNAME .. "/" .. REPO_NAME .. "/main/"

-- ==========================================
-- 🔄 Cleanup ระบบเก่า (ป้องกัน execute ซ้ำ leak)
-- ==========================================
if _G.DiqCleanup then
	pcall(_G.DiqCleanup)
end

-- ==========================================
-- 📦 Module Loader (with error handling)
-- ==========================================
local function LoadModule(name)
	local cacheBust = tostring(os.clock()) -- ✅ แทน tick() ที่ deprecated
	local url = BASE_URL .. name .. ".lua?_=" .. cacheBust

	local success, result = pcall(function()
		return loadstring(game:HttpGet(url))()
	end)

	if success then
		return result
	else
		warn("[Diq] Failed to load " .. name .. ": " .. tostring(result))
		return nil
	end
end

local DiqUI    = LoadModule("DiqUILib")
local DiqIcons = LoadModule("DiqIcons")
local Movement = LoadModule("MovementSystem")
local ESP      = LoadModule("ESPSystem")
local Aimbot   = LoadModule("AimbotSystem")
local Hitbox   = LoadModule("HitboxSystem")
local Misc     = LoadModule("MiscSystem")

-- ตรวจสอบว่า Module หลักโหลดสำเร็จ
if not DiqUI then
	error("[Diq] Critical: DiqUILib failed to load. Aborting.")
	return
end

-- ==========================================
-- 🔧 ลงทะเบียน Cleanup สำหรับ execute ครั้งถัดไป
-- ==========================================
_G.DiqCleanup = function()
	pcall(function() if Aimbot and Aimbot.Destroy then Aimbot.Destroy() end end)
	pcall(function() if ESP and ESP.Destroy then ESP.Destroy() end end)
	pcall(function() if Hitbox and Hitbox.Destroy then Hitbox.Destroy() end end)
	pcall(function() if Movement and Movement.Destroy then Movement.Destroy() end end)
	pcall(function() if Misc and Misc.Destroy then Misc.Destroy() end end)
	pcall(function() if DiqUI and DiqUI.Destroy then DiqUI.Destroy() end end)
end

-- ⭐ โหลด Icon เข้า Library (ทำครั้งเดียว)
if DiqIcons then
	DiqUI:LoadIcons(DiqIcons)
end

local MyWindow = DiqUI:CreateWindow({
	Title = "Diq",
	ToggleKey = Enum.KeyCode.RightShift,
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

combatTab:CreateToggle("Enable Aimbot (Hold Right Click)", false, function(state)
	Aimbot.SetEnabled(state)
	if state then
		DiqUI:Notify("Aimbot Enabled", "Hold Right Click to aim at targets", 3, "info")
	end
end, { Icon = "crosshair" })

combatTab:CreateToggle("Show FOV Circle", false, function(state)
	Aimbot.SetShowFOV(state)
end, { Icon = "circle" })

combatTab:CreateLabel("AIMBOT SETTINGS")

combatTab:CreateSlider("FOV Size", 10, 800, 150, function(value)
	Aimbot.SetFOVRadius(value)
end)

combatTab:CreateSlider("Smoothness", 1, 100, 50, function(value)
    -- Map 1-100 to 0.01-1
	Aimbot.SetSmoothing(value / 100)
end)

combatTab:CreateDropdown("Aim Part", { "Head", "Torso", "HumanoidRootPart" }, "Head", function(selected)
	Aimbot.SetAimPart(selected)
end)

combatTab:CreateDropdown("Aim Method (FPS Game)", { "Camera", "Mouse" }, "Camera", function(selected)
	Aimbot.SetAimMethod(selected)
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
		Misc.Rejoin()
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
DiqUI:Notify("Loaded Successfully!", "Diq Panel v3.0 is ready\nPress RightShift to toggle UI", 4, "success")
print("[Diq] Panel v3.0 Loaded Successfully!")
