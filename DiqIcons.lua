-- ==========================================
-- 🎨 DiqIcons v2.0 (Lucide Integration)
-- ==========================================
-- ใช้ Library: latte-soft/lucide-roblox
-- รองรับ Icon ระดับ Professional มากกว่า 1500+ แบบ

local GITHUB_USERNAME = "sRawiz"
local REPO_NAME = "Diq"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USERNAME .. "/" .. REPO_NAME .. "/main/"

-- โหลด Lucide Library ที่ดึงมาจาก Repository
local Lucide = loadstring(game:HttpGet(BASE_URL .. "Lucide.lua"))()

local Icons = {}

-- ตรวจสอบว่า Icon นี้มีอยู่หรือไม่
-- @param name string ชื่อ icon เช่น "move", "settings"
-- @return boolean
function Icons.Exists(name)
	local success = pcall(function()
		Lucide.GetAsset(name)
	end)
	return success
end

-- สร้าง ImageLabel พร้อม icon จาก Lucide
-- @param name string ชื่อ icon
-- @param parent Instance parent ที่จะแปะ
-- @param size number? ขนาด (default: 16)
-- @param color Color3? สี (default: ขาว)
-- @return ImageLabel?
function Icons.Create(name, parent, size, color)
	size = size or 16
	color = color or Color3.fromRGB(255, 255, 255)

	local success, icon = pcall(function()
		return Lucide.ImageLabel(name, size, {
			Name = "Icon_" .. name,
			BackgroundTransparency = 1,
			ImageColor3 = color,
			ScaleType = Enum.ScaleType.Fit,
			Parent = parent
		})
	end)

	if not success then
		warn("[DiqIcons] ไม่พบ icon: " .. tostring(name))
		return nil
	end

	return icon
end

return Icons
