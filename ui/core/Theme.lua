return function()
	local DefaultTheme = {
		Background  = Color3.fromRGB(18, 18, 20),   -- #121214
		Sidebar     = Color3.fromRGB(26, 26, 30),   -- #1A1A1E
		ElementBg   = Color3.fromRGB(36, 36, 41),   -- #242429
		HoverBg     = Color3.fromRGB(44, 45, 50),   -- #2C2D32
		ActiveTab   = Color3.fromRGB(44, 45, 50),   -- #2C2D32
		Accent      = Color3.fromRGB(84, 98, 239),  -- #5462EF (Blurple)
		AccentHover = Color3.fromRGB(104, 118, 255),
		Text        = Color3.fromRGB(219, 222, 225),-- #DBDEE1 (Discord Chat Text)
		SubText     = Color3.fromRGB(150, 151, 158),-- #96979E
		DimText     = Color3.fromRGB(110, 111, 118),
		Outline     = Color3.fromRGB(44, 45, 50),   -- #2C2D32
		SliderBg    = Color3.fromRGB(26, 26, 30),   -- #1A1A1E
		InputBg     = Color3.fromRGB(26, 26, 30),   -- #1A1A1E
		NotifyBg    = Color3.fromRGB(36, 36, 41),   -- #242429
		Success     = Color3.fromRGB(34, 197, 94),
		Warning     = Color3.fromRGB(250, 204, 21),
		Error       = Color3.fromRGB(239, 68, 68),
	}

	local Theme = table.clone(DefaultTheme)

	-- เปลี่ยนธีมสีทั้งระบบ
	local function setTheme(newTheme)
		for key, value in newTheme do
			if DefaultTheme[key] ~= nil then
				Theme[key] = value
			end
		end
	end
	return Theme, setTheme
end
