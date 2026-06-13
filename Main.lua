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
local DiqUI    = loadstring(game:HttpGet(BASE_URL .. "DiqUILib.lua"))()
local DiqIcons = loadstring(game:HttpGet(BASE_URL .. "DiqIcons.lua"))()
local Movement = loadstring(game:HttpGet(BASE_URL .. "MovementSystem.lua"))()

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

movementTab:CreateLabel("FLY & SPEED")

local flyToggle = movementTab:CreateToggle("โหมดบิน (CFrame Fly)", false, function(state)
	Movement.SetFly(state)
end, { Icon = "plane" })

local speedToggle = movementTab:CreateToggle("วิ่งเร็ว (CFrame Speed)", false, function(state)
	Movement.SetSpeed(state)
end, { Icon = "zap" })

movementTab:CreateSlider("ความเร็วบิน", 10, 500, 100, function(value)
	Movement.SetFlySpeed(value)
end)

movementTab:CreateSlider("ความเร็ววิ่ง", 10, 300, 60, function(value)
	Movement.SetCFrameSpeed(value)
end)

movementTab:CreateLabel("ACTIONS")

movementTab:CreateButton("รีเซ็ตตัวละคร", function()
	Movement.ResetCharacter()
end, { Icon = "skull" })

movementTab:CreateButton("ลบสถานะแช่แข็ง", function()
	Movement.Unanchor()
	DiqUI:Notify("สำเร็จ", "ปลดล็อค Anchor เรียบร้อย", 2, "success")
end, { Icon = "shield" })

-- ==========================================
-- ⚙️ Tab: Settings (ใช้ Lucide icon "settings")
-- ==========================================
local settingsTab = MyWindow:CreateTab("Settings", "settings")

settingsTab:CreateLabel("KEYBINDS")

settingsTab:CreateKeybind("สลับโหมดบิน", Enum.KeyCode.F, function()
	local isFlying = Movement.ToggleFly()
	flyToggle:Set(isFlying)
	DiqUI:Notify(
		isFlying and "เปิดโหมดบิน" or "ปิดโหมดบิน",
		isFlying and "กดปุ่มเดิมเพื่อปิด" or "กลับสู่โหมดปกติ",
		2,
		isFlying and "info" or "warning"
	)
end)

settingsTab:CreateKeybind("สลับวิ่งเร็ว", Enum.KeyCode.G, function()
	local isSpeed = Movement.ToggleSpeed()
	speedToggle:Set(isSpeed)
	DiqUI:Notify(
		isSpeed and "เปิดวิ่งเร็ว" or "ปิดวิ่งเร็ว",
		isSpeed and "กดปุ่มเดิมเพื่อปิด" or "กลับความเร็วปกติ",
		2,
		isSpeed and "info" or "warning"
	)
end)

settingsTab:CreateLabel("PLAYER")

settingsTab:CreateInput("ชื่อผู้เล่น", "พิมพ์ชื่อ...", function(text, enterPressed)
	if enterPressed and text ~= "" then
		DiqUI:Notify("ค้นหา", "กำลังค้นหา: " .. text, 2, "info")
	end
end)

settingsTab:CreateDropdown("โหมดเทเลพอร์ต", { "Instant", "Smooth", "CFrame" }, "Instant", function(selected)
	DiqUI:Notify("เปลี่ยนโหมด", "โหมด: " .. selected, 2, "info")
end)

settingsTab:CreateLabel("ABOUT")

settingsTab:CreateButton("เกี่ยวกับ Diq Panel", function()
	DiqUI:Notify("Diq UI Library", "Version 2.1 — by sRawiz\nLucide Icons Edition", 3, "info")
end, { Icon = "info" })

-- ==========================================
-- ✅ แจ้งเตือนว่าโหลดสำเร็จ
-- ==========================================
DiqUI:Notify("โหลดสำเร็จ!", "Diq Panel v2.1 พร้อมใช้งาน\nกด RightShift เพื่อซ่อน/แสดง", 4, "success")
print("[Diq] Panel v2.1 Loaded Successfully!")
