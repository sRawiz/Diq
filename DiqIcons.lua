-- ==========================================
-- 🖼️ Module: Diq Icon Library (Lucide Style)
-- ==========================================
-- ใช้ Lucide Icons ผ่าน Roblox Image Asset
-- รองรับเปลี่ยนสีด้วย ImageColor3
-- วิธีใช้: local Icons = require(...)
--          Icons.Get("plane")  → rbxassetid://...
--          Icons.Create("plane", parent, size, color)

local Icons = {}

-- ==========================================
-- 📦 Icon Asset Map
-- ==========================================
-- Lucide icons อัพโหลดเป็น Roblox Decal (white on transparent)
-- สามารถเปลี่ยนสีได้ด้วย ImageColor3
-- ที่มา: https://lucide.dev

local IconMap = {
	-- ✈️ Movement / Direction
	["plane"]            = "rbxassetid://18812267061",
	["zap"]              = "rbxassetid://18812278498",
	["rocket"]           = "rbxassetid://18812271688",
	["move"]             = "rbxassetid://18812265612",
	["arrow-up"]         = "rbxassetid://18812257498",
	["arrow-down"]       = "rbxassetid://18812256432",
	["arrow-left"]       = "rbxassetid://18812256791",
	["arrow-right"]      = "rbxassetid://18812257109",
	["navigation"]       = "rbxassetid://18812266078",
	["compass"]          = "rbxassetid://18812259502",

	-- ⚙️ Settings / System
	["settings"]         = "rbxassetid://18812272814",
	["sliders"]          = "rbxassetid://18812273719",
	["wrench"]           = "rbxassetid://18812278046",
	["cog"]              = "rbxassetid://18812259502",
	["toggle-left"]      = "rbxassetid://18812275838",
	["toggle-right"]     = "rbxassetid://18812275993",
	["power"]            = "rbxassetid://18812270224",

	-- 👤 User / Player
	["user"]             = "rbxassetid://18812276894",
	["users"]            = "rbxassetid://18812277144",
	["skull"]            = "rbxassetid://18812273262",
	["heart"]            = "rbxassetid://18812262710",
	["shield"]           = "rbxassetid://18812273018",
	["crown"]            = "rbxassetid://18812259936",
	["swords"]           = "rbxassetid://18812274730",
	["crosshair"]        = "rbxassetid://18812260119",

	-- 🎮 Game / Action
	["gamepad"]          = "rbxassetid://18812261898",
	["target"]           = "rbxassetid://18812275153",
	["play"]             = "rbxassetid://18812269788",
	["pause"]            = "rbxassetid://18812268676",
	["square"]           = "rbxassetid://18812274103",
	["refresh-cw"]       = "rbxassetid://18812271280",
	["rotate-cw"]        = "rbxassetid://18812272150",
	["maximize"]         = "rbxassetid://18812265073",
	["minimize"]         = "rbxassetid://18812265330",

	-- 📁 UI / Layout
	["layout"]           = "rbxassetid://18812264145",
	["grid"]             = "rbxassetid://18812262248",
	["list"]             = "rbxassetid://18812264649",
	["menu"]             = "rbxassetid://18812265073",
	["x"]                = "rbxassetid://18812278271",
	["check"]            = "rbxassetid://18812258555",
	["plus"]             = "rbxassetid://18812270009",
	["minus"]            = "rbxassetid://18812265330",
	["search"]           = "rbxassetid://18812272561",
	["filter"]           = "rbxassetid://18812261408",
	["chevron-down"]     = "rbxassetid://18812258825",
	["chevron-up"]       = "rbxassetid://18812259118",
	["chevron-left"]     = "rbxassetid://18812258969",
	["chevron-right"]    = "rbxassetid://18812259006",
	["more-horizontal"]  = "rbxassetid://18812265429",
	["more-vertical"]    = "rbxassetid://18812265518",

	-- 💬 Communication
	["message-circle"]   = "rbxassetid://18812265182",
	["bell"]             = "rbxassetid://18812257820",
	["bell-ring"]        = "rbxassetid://18812257942",
	["info"]             = "rbxassetid://18812263434",
	["alert-triangle"]   = "rbxassetid://18812256103",
	["alert-circle"]     = "rbxassetid://18812255861",
	["help-circle"]      = "rbxassetid://18812262551",

	-- 🔒 Security
	["lock"]             = "rbxassetid://18812264834",
	["unlock"]           = "rbxassetid://18812276634",
	["key"]              = "rbxassetid://18812263826",
	["eye"]              = "rbxassetid://18812261107",
	["eye-off"]          = "rbxassetid://18812261237",

	-- 📊 Data / Misc
	["clock"]            = "rbxassetid://18812259233",
	["timer"]            = "rbxassetid://18812275651",
	["activity"]         = "rbxassetid://18812255595",
	["trending-up"]      = "rbxassetid://18812276340",
	["bar-chart"]        = "rbxassetid://18812257635",
	["download"]         = "rbxassetid://18812260690",
	["upload"]           = "rbxassetid://18812276744",
	["save"]             = "rbxassetid://18812272381",
	["trash"]            = "rbxassetid://18812276156",
	["copy"]             = "rbxassetid://18812259649",
	["clipboard"]        = "rbxassetid://18812259335",
	["folder"]           = "rbxassetid://18812261642",
	["file"]             = "rbxassetid://18812261271",
	["image"]            = "rbxassetid://18812263130",
	["star"]             = "rbxassetid://18812274308",
	["sun"]              = "rbxassetid://18812274524",
	["moon"]             = "rbxassetid://18812265512",
	["cloud"]            = "rbxassetid://18812259417",
	["wifi"]             = "rbxassetid://18812277780",
	["bluetooth"]        = "rbxassetid://18812258198",
	["map-pin"]          = "rbxassetid://18812264921",
	["home"]             = "rbxassetid://18812262936",
	["hash"]             = "rbxassetid://18812262438",
	["command"]          = "rbxassetid://18812259502",
	["terminal"]         = "rbxassetid://18812275432",
	["code"]             = "rbxassetid://18812259468",
	["palette"]          = "rbxassetid://18812268326",
	["sparkles"]         = "rbxassetid://18812273948",
	["flame"]            = "rbxassetid://18812261502",
	["snowflake"]        = "rbxassetid://18812273498",
	["music"]            = "rbxassetid://18812265895",
	["volume-2"]         = "rbxassetid://18812277487",
	["volume-x"]         = "rbxassetid://18812277614",
	["camera"]           = "rbxassetid://18812258377",
	["video"]            = "rbxassetid://18812277300",
}

-- ==========================================
-- 🔧 API
-- ==========================================

-- ดึง Asset ID จากชื่อ icon
-- @param name string ชื่อ icon (เช่น "plane", "settings")
-- @return string? rbxassetid URL หรือ nil ถ้าไม่เจอ
function Icons.Get(name)
	return IconMap[name]
end

-- สร้าง ImageLabel พร้อม icon
-- @param name string ชื่อ icon
-- @param parent Instance parent ที่จะแปะ
-- @param size number? ขนาด (default: 16)
-- @param color Color3? สี (default: ขาว)
-- @return ImageLabel?
function Icons.Create(name, parent, size, color)
	local assetId = IconMap[name]
	if not assetId then
		warn("[DiqIcons] ไม่พบ icon: " .. tostring(name))
		return nil
	end

	size = size or 16
	color = color or Color3.fromRGB(255, 255, 255)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon_" .. name
	icon.Size = UDim2.new(0, size, 0, size)
	icon.BackgroundTransparency = 1
	icon.Image = assetId
	icon.ImageColor3 = color
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent

	return icon
end

-- ดึงรายชื่อ icon ทั้งหมด
-- @return {string} array ของชื่อ icon
function Icons.GetAll()
	local names = {}
	for name in IconMap do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- เช็คว่า icon มีอยู่ไหม
-- @param name string ชื่อ icon
-- @return boolean
function Icons.Exists(name)
	return IconMap[name] ~= nil
end

return Icons
