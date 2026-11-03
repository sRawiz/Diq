local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, min, max, default, callback, options)
	local Theme = ctx.Theme
	local BindSliderDrag = ctx.BindSliderDrag
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplyStroke = ctx.Primitives.ApplyStroke
	local ApplySectionStyle = ctx.Primitives.ApplySectionStyle
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj = {}
	options = options or {}
	local compact = options.Compact
	local value = math.clamp(default or min, min, max)
	local targetParent = ctx.Parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, compact and 46 or 52)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.Parent = targetParent

	if compact then
		frame.BackgroundTransparency = 1
		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1, -24, 0, 1)
		sep.Position = UDim2.new(0, 12, 0, 0)
		sep.BackgroundColor3 = Theme.Outline
		sep.BackgroundTransparency = 0.5
		sep.BorderSizePixel = 0
		sep.Parent = frame
	else
		ApplySectionStyle(frame, ctx.Section)
	end

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, compact and -60 or -55, 0, compact and 16 or 20)
	lbl.Position = UDim2.new(0, options.LabelOffset or 12, 0, compact and 6 or 4)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = compact and Theme.SubText or Theme.Text
	lbl.Font = Tokens.Font.Label
	lbl.TextSize = compact and 11 or 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = frame

	local valInput = Instance.new("TextBox")
	valInput.Size = UDim2.new(0, compact and 35 or 45, 0, compact and 16 or 20)
	valInput.Position = UDim2.new(1, compact and -48 or -55, 0, 6)
	valInput.BackgroundColor3 = Theme.Background
	valInput.Text = tostring(math.floor(value))
	valInput.TextColor3 = Theme.Accent
	valInput.Font = Tokens.Font.Strong
	valInput.TextSize = compact and 10 or 12
	valInput.TextXAlignment = Enum.TextXAlignment.Center
	valInput.ClearTextOnFocus = false
	valInput.Parent = frame
	ApplyCorner(valInput, 4)
	ApplyStroke(valInput, Theme.Outline)

	-- แท่งพื้นหลัง
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 5)
	track.Position = UDim2.new(0, 12, 0, compact and 28 or 34)
	track.BackgroundColor3 = Theme.SliderBg
	track.BorderSizePixel = 0
	track.Parent = frame
	ApplyCorner(track, 3)

	-- แท่งสี (fill)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0)
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	ApplyCorner(fill, 3)

	-- ปุ่มกลม (knob)
	local sliderKnob = Instance.new("Frame")
	local knobRadius = compact and 5 or 6
	sliderKnob.Size = UDim2.fromOffset(knobRadius * 2, knobRadius * 2)
	sliderKnob.Position = UDim2.new((value - min) / math.max(max - min, 1), -knobRadius, 0.5, -knobRadius)
	sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderKnob.BorderSizePixel = 0
	sliderKnob.ZIndex = 2
	sliderKnob.Parent = track
	ApplyCorner(sliderKnob, knobRadius)

	-- ปุ่มกดใส (ครอบพื้นที่ slider)
	local hitArea = Instance.new("TextButton")
	hitArea.Size = UDim2.new(1, -24, 0, compact and 18 or 22)
	hitArea.Position = UDim2.new(0, 12, 0, compact and 20 or 24)
	hitArea.BackgroundTransparency = 1
	hitArea.Text = ""
	hitArea.ZIndex = 3
	hitArea.Parent = frame

	local function UpdateSlider(newValue, silent)
		local previous = value
		value = math.clamp(math.floor(newValue), min, max)
		local ratio = (value - min) / math.max(max - min, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		sliderKnob.Position = UDim2.new(ratio, -knobRadius, 0.5, -knobRadius)
		valInput.Text = tostring(value)
		if callback and previous ~= value and not silent then connections:Invoke(callback, value) end
	end

	connections:Track(valInput.FocusLost:Connect(function()
		local parsed = tonumber(valInput.Text)
		if parsed then
			UpdateSlider(parsed)
		else
			valInput.Text = tostring(value)
		end
	end))

	BindSliderDrag(hitArea, connections, function(input)
		if track.AbsoluteSize.X <= 0 then return end
		local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		UpdateSlider(min + (max - min) * ratio)
	end)

	function obj:Set(v, silent) UpdateSlider(v, silent) end
	function obj:Get() return value end
	function obj:Reset() obj:Set(default or min) end
	function obj:SetText(t) lbl.Text = t end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end

	obj.Root = frame
	ctx.Register(obj, connections, not compact)
	return obj
end
