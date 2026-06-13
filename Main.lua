-- ==========================================
-- 🎮 Loader / Main Controller v2.1
-- ==========================================
-- อัพเดท: ใช้ Lucide Icons แทน Emoji
-- ✅ โหลด DiqIcons module
-- ✅ Tab ใช้ icon ชื่อ เช่น "move", "settings"
-- ✅ Button / Toggle ใส่ { Icon = "name" }

-- ⚠️ เปลี่ยนให้ตรงกับ GitHub ของคุณ ⚠️
local GITHUB_USERNAME = "sRawiz"
local REPO_NAME = "Diq"

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USERNAME .. "/" .. REPO_NAME .. "/main/"

-- โหลด Module ผ่านอินเทอร์เน็ต
local DiqUI    = loadstring(game:HttpGet(BASE_URL .. "DiqUILib.lua?_=" .. tostring(tick())))()
local DiqIcons = loadstring(game:HttpGet(BASE_URL .. "DiqIcons.lua?_=" .. tostring(tick())))()
local Movement = loadstring(game:HttpGet(BASE_URL .. "MovementSystem.lua?_=" .. tostring(tick())))()
local ESP      = loadstring(game:HttpGet(BASE_URL .. "ESPSystem.lua?_=" .. tostring(tick())))()

-- ⭐ โหลด Icon เข้า Library (ทำครั้งเดียว)
DiqUI:LoadIcons(DiqIcons)

-- ==========================================
-- 🖥️ สร้าง Window
-- ==========================================
local MyWindow = DiqUI:CreateWindow({
	Title = "Diq Panel",
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

movementTab:CreateToggle("Infinity Jump", false, function(state)
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

-- ==========================================
-- ⚙️ Tab: Settings (ใช้ Lucide icon "settings")
-- ==========================================
local settingsTab = MyWindow:CreateTab("Settings", "settings")

settingsTab:CreateLabel("PLAYER")

settingsTab:CreateInput("Player Name", "Enter name...", function(text, enterPressed)
	if enterPressed and text ~= "" then
		DiqUI:Notify("Search", "Searching for: " .. text, 2, "info")
	end
end)

settingsTab:CreateDropdown("Teleport Mode", { "Instant", "Smooth", "CFrame" }, "Instant", function(selected)
	DiqUI:Notify("Mode Changed", "Current Mode: " .. selected, 2, "info")
end)

settingsTab:CreateLabel("ABOUT")

settingsTab:CreateButton("About Diq Panel", function()
	DiqUI:Notify("Diq UI Library", "Version 2.1 — by sRawiz\nLucide Icons Edition", 3, "info")
end, { Icon = "info" })

-- ==========================================
-- ✅ แจ้งเตือนว่าโหลดสำเร็จ
-- ==========================================
DiqUI:Notify("Loaded Successfully!", "Diq Panel v2.1 is ready\nPress RightShift to toggle UI", 4, "success")
print("[Diq] Panel v2.1 Loaded Successfully!")
