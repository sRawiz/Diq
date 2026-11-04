return function()
	local DefaultTheme = {
		Background  = Color3.fromRGB(33, 33, 33),
		Sidebar     = Color3.fromRGB(24, 24, 24),
		ElementBg   = Color3.fromRGB(39, 39, 39),
		HoverBg     = Color3.fromRGB(49, 49, 49),
		ActiveTab   = Color3.fromRGB(47, 47, 47),
		Accent      = Color3.fromRGB(67, 177, 138),
		AccentHover = Color3.fromRGB(88, 197, 158),
		Text        = Color3.fromRGB(239, 239, 239),
		SubText     = Color3.fromRGB(177, 177, 177),
		DimText     = Color3.fromRGB(146, 146, 146),
		Outline     = Color3.fromRGB(62, 62, 62),
		SliderBg    = Color3.fromRGB(67, 67, 67),
		InputBg     = Color3.fromRGB(30, 30, 30),
		NotifyBg    = Color3.fromRGB(43, 43, 43),
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
