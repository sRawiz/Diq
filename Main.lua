-- ==========================================
-- 🎮 Loader / Main Controller
-- ==========================================
-- สคริปต์นี้เอาไว้ไปรันใน Executor (แค่บรรทัดเดียว)
-- จะดึง Library และ System จาก GitHub ของคุณ

-- ⚠️ ก่อนใช้งานจริง: ให้เปลี่ยน 2 จุดด้านล่างนี้ให้ตรงกับ GitHub ของคุณ ⚠️
local GITHUB_USERNAME = "sRawiz" -- เปลี่ยนตรงนี้
local REPO_NAME = "Diq"             -- เปลี่ยนตรงนี้

-- สร้าง URL สำหรับดึงไฟล์แบบสดๆ
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USERNAME .. "/" .. REPO_NAME .. "/main/"

-- โหลด Module ย่อยต่างๆ ผ่านอินเทอร์เน็ต
local DiqUI = loadstring(game:HttpGet(BASE_URL .. "DiqUILib.lua"))()
local Movement = loadstring(game:HttpGet(BASE_URL .. "MovementSystem.lua"))()

-- ==========================================
-- 🖥️ สร้าง UI และผูกฟังก์ชัน
-- ==========================================

local MyWindow = DiqUI:CreateWindow("Diq Panel")

MyWindow:CreateLabel("MOVEMENT SETTINGS")

MyWindow:CreateToggle("✈️ โหมดบิน (CFrame Fly)", false, function(state)
    Movement.SetFly(state)
end)

MyWindow:CreateToggle("⚡ วิ่งเร็ว (CFrame Speed)", false, function(state)
    Movement.SetSpeed(state)
end)

MyWindow:CreateLabel("ACTIONS")

MyWindow:CreateButton("💀 รีเซ็ตตัวละคร (Reset)", function()
    Movement.ResetCharacter()
end)

MyWindow:CreateButton("🛡️ ลบสถานะแช่แข็ง (Unanchor)", function()
    Movement.Unanchor()
end)

print("✅ Diq Panel Loaded Successfully from GitHub!")
