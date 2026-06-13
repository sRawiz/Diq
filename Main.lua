-- ==========================================
-- 🎮 Loader / Main Controller v2.0
-- ==========================================
-- อัพเดท: ใช้ API ใหม่ของ Diq UI Library v2.0
-- ✅ Tab System (Movement / Settings)
-- ✅ Slider ปรับค่าความเร็ว
-- ✅ Keybind ตั้งค่าปุ่มลัด
-- ✅ Dropdown, Input
-- ✅ Notification

-- ⚠️ เปลี่ยนให้ตรงกับ GitHub ของคุณ ⚠️
local GITHUB_USERNAME = "sRawiz"
local REPO_NAME = "Diq"

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USERNAME .. "/" .. REPO_NAME .. "/main/"

-- โหลด Module ผ่านอินเทอร์เน็ต
local DiqUI = loadstring(game:HttpGet(BASE_URL .. "DiqUILib.lua"))()
local Movement = loadstring(game:HttpGet(BASE_URL .. "MovementSystem.lua"))()

-- ==========================================
-- 🖥️ สร้าง Window
-- ==========================================
local MyWindow = DiqUI:CreateWindow({
	Title = "Diq Panel",
	ToggleKey = Enum.KeyCode.RightShift,  -- กด RightShift เพื่อซ่อน/แสดง
})

-- ==========================================
-- 🏃 Tab: Movement
-- ==========================================
local movementTab = MyWindow:CreateTab("Movement", "🏃")

movementTab:CreateLabel("FLY & SPEED")

local flyToggle = movementTab:CreateToggle("✈️ โหมดบิน (CFrame Fly)", false, function(state)
	Movement.SetFly(state)
end)

local speedToggle = movementTab:CreateToggle("⚡ วิ่งเร็ว (CFrame Speed)", false, function(state)
	Movement.SetSpeed(state)
end)

movementTab:CreateSlider("🚀 ความเร็วบิน", 10, 500, 100, function(value)
	Movement.SetFlySpeed(value)
end)

movementTab:CreateSlider("💨 ความเร็ววิ่ง", 10, 300, 60, function(value)
	Movement.SetCFrameSpeed(value)
end)

movementTab:CreateLabel("ACTIONS")

movementTab:CreateButton("💀 รีเซ็ตตัวละคร", function()
	Movement.ResetCharacter()
end)

movementTab:CreateButton("🛡️ ลบสถานะแช่แข็ง", function()
	Movement.Unanchor()
	DiqUI:Notify("✅ สำเร็จ", "ปลดล็อค Anchor เรียบร้อย", 2, "success")
end)

-- ==========================================
-- ⚙️ Tab: Settings
-- ==========================================
local settingsTab = MyWindow:CreateTab("Settings", "⚙️")

settingsTab:CreateLabel("KEYBINDS")

settingsTab:CreateKeybind("🎮 สลับโหมดบิน", Enum.KeyCode.F, function()
	local isFlying = Movement.ToggleFly()
	flyToggle:Set(isFlying)
	DiqUI:Notify(
		isFlying and "✈️ เปิดโหมดบิน" or "🚶 ปิดโหมดบิน",
		isFlying and "กดปุ่มเดิมเพื่อปิด" or "กลับสู่โหมดปกติ",
		2,
		isFlying and "info" or "warning"
	)
end)

settingsTab:CreateLabel("PLAYER")

settingsTab:CreateInput("📝 ชื่อผู้เล่น", "พิมพ์ชื่อ...", function(text, enterPressed)
	if enterPressed and text ~= "" then
		DiqUI:Notify("🔍 ค้นหา", "กำลังค้นหา: " .. text, 2, "info")
	end
end)

settingsTab:CreateDropdown("🎯 โหมดเทเลพอร์ต", { "Instant", "Smooth", "CFrame" }, "Instant", function(selected)
	DiqUI:Notify("🎯 เปลี่ยนโหมด", "โหมด: " .. selected, 2, "info")
end)

settingsTab:CreateLabel("ABOUT")

settingsTab:CreateButton("ℹ️ เกี่ยวกับ Diq Panel", function()
	DiqUI:Notify("🎨 Diq UI Library", "Version 2.0 — by sRawiz", 3, "info")
end)

-- ==========================================
-- ✅ แจ้งเตือนว่าโหลดสำเร็จ
-- ==========================================
DiqUI:Notify("✅ โหลดสำเร็จ!", "Diq Panel v2.0 พร้อมใช้งาน\nกด RightShift เพื่อซ่อน/แสดง", 4, "success")
print("✅ Diq Panel v2.0 Loaded Successfully!")
