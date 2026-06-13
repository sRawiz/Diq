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

local flySection = movementTab:CreateSection("FLY (CFRAME)")

local flyToggle = flySection:CreateToggle("CFrame Fly", false, function(state)
	Movement.SetFly(state)
end, { Icon = "plane" })

flySection:CreateSlider("Fly Speed", 10, 500, 100, function(value)
	Movement.SetFlySpeed(value)
end)

flySection:CreateKeybind("Toggle Fly", Enum.KeyCode.F, function()
	local isFlying = Movement.ToggleFly()
	flyToggle:Set(isFlying)
	DiqUI:Notify(
		isFlying and "Fly Enabled" or "Fly Disabled",
		isFlying and "Press key again to disable" or "Returned to normal mode",
		2,
		isFlying and "info" or "warning"
	)
end)

local speedSection = movementTab:CreateSection("SPEED (CFRAME)")

local speedToggle = speedSection:CreateToggle("CFrame Speed", false, function(state)
	Movement.SetSpeed(state)
end, { Icon = "zap" })

speedSection:CreateSlider("Walk Speed", 10, 300, 60, function(value)
	Movement.SetCFrameSpeed(value)
end)

speedSection:CreateKeybind("Toggle Speed", Enum.KeyCode.G, function()
	local isSpeed = Movement.ToggleSpeed()
	speedToggle:Set(isSpeed)
	DiqUI:Notify(
		isSpeed and "Speed Enabled" or "Speed Disabled",
		isSpeed and "Press key again to disable" or "Returned to normal speed",
		2,
		isSpeed and "info" or "warning"
	)
end)

local noClipSection = movementTab:CreateSection("NOCLIP")

local noClipToggle = noClipSection:CreateToggle("NoClip", false, function(state)
	Movement.SetNoClip(state)
end, { Icon = "ghost" })

noClipSection:CreateKeybind("Toggle NoClip", Enum.KeyCode.V, function()
	local isNoClip = Movement.ToggleNoClip()
	noClipToggle:Set(isNoClip)
	DiqUI:Notify(
		isNoClip and "NoClip Enabled" or "NoClip Disabled",
		isNoClip and "You can walk through walls" or "Collision restored",
		2,
		isNoClip and "info" or "warning"
	)
end)

local jumpSection = movementTab:CreateSection("JUMP")

local infJumpToggle = jumpSection:CreateToggle("Infinity Jump", false, function(state)
	Movement.SetInfinityJump(state)
end, { Icon = "chevron-up" })

local actionSection = movementTab:CreateSection("ACTIONS")

actionSection:CreateButton("Reset Character", function()
	Movement.ResetCharacter()
end, { Icon = "skull" })

actionSection:CreateButton("Unanchor", function()
	Movement.Unanchor()
	DiqUI:Notify("Success", "Character unanchored", 2, "success")
end, { Icon = "shield" })

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
