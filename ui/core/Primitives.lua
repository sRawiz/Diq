local import = ...
local Tokens = import("core/Tokens")
return function(Theme, getIcons)
	local TweenService = game:GetService("TweenService")
	local function Tween(obj, duration, props, style, dir)
		local tween = TweenService:Create(
			obj,
			TweenInfo.new(duration, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
			props
		)
		tween:Play()
		return tween
	end

	local function ApplyCorner(obj, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius or 6)
		c.Parent = obj
		return c
	end

	local function ApplyStroke(obj, color, thickness)
		local s = Instance.new("UIStroke")
		s.Color = color or Theme.Outline
		s.Thickness = thickness or 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = obj
		return s
	end

	local function ApplyPadding(obj, top, bottom, left, right)
		local p = Instance.new("UIPadding")
		p.PaddingTop = UDim.new(0, top or 0)
		p.PaddingBottom = UDim.new(0, bottom or 0)
		p.PaddingLeft = UDim.new(0, left or 0)
		p.PaddingRight = UDim.new(0, right or 0)
		p.Parent = obj
		return p
	end

	local function ApplySectionStyle(frame, sectionRef)
		local isSection = sectionRef and sectionRef._isSection
		if isSection then
			frame.BackgroundTransparency = 1
			if sectionRef._itemCount and sectionRef._itemCount > 0 then
				local sep = Instance.new("Frame")
				sep.Size = UDim2.new(1, -24, 0, 1)
				sep.Position = UDim2.new(0, 12, 0, 0)
				sep.BackgroundColor3 = Theme.Outline
				sep.BorderSizePixel = 0
				sep.BackgroundTransparency = 0.5
				sep.Parent = frame
			end
			if sectionRef._itemCount then sectionRef._itemCount = sectionRef._itemCount + 1 end
			return nil, true -- stroke=nil, isSection=true
		else
			ApplyCorner(frame, Tokens.Radius.Control)
			return ApplyStroke(frame, Theme.Outline), false
		end
	end

	local function AttachIcon(iconName, parent, size, color, position)
		local DiqIcons = getIcons()
		if not DiqIcons or not iconName then return nil end
		if not DiqIcons.Exists(iconName) then return nil end

		size = size or 16
		color = color or Theme.SubText
		position = position or UDim2.new(0, 10, 0.5, -(size / 2))

		local icon = DiqIcons.Create(iconName, parent, size, color)
		if icon then
			icon.Position = position
		end
		return icon
	end
	return { Tween = Tween, ApplyCorner = ApplyCorner, ApplyStroke = ApplyStroke, ApplyPadding = ApplyPadding, ApplySectionStyle = ApplySectionStyle, AttachIcon = AttachIcon }
end
