local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, default, callback, config)
	local Theme = ctx.Theme
	local Tween = ctx.Primitives.Tween
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplySectionStyle = ctx.Primitives.ApplySectionStyle
	local AttachIcon = ctx.Primitives.AttachIcon
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj = {}
	local toggled = default or false
	config = config or {}

	local frameHeight = 36
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, frameHeight)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.Parent = ctx.Parent

	ApplySectionStyle(frame, ctx.Section)

	-- Top area
	local topArea = Instance.new("Frame")
	topArea.Size = UDim2.new(1, 0, 0, 36)
	topArea.BackgroundTransparency = 1
	topArea.Parent = frame

	-- Icon (ถ้ามี)
	local hasIcon = config.Icon and AttachIcon(config.Icon, topArea, 16, Theme.SubText, UDim2.new(0, 10, 0.5, -8))
	local textPadLeft = hasIcon and 32 or 12

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -120, 1, 0)
	lbl.Position = UDim2.new(0, textPadLeft, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Theme.Text
	lbl.Font = Tokens.Font.Label
	lbl.TextSize = Tokens.Text.Body
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = topArea

	-- พื้นหลังสวิตช์
	local switchBg = Instance.new("Frame")
	switchBg.Size = UDim2.new(0, 36, 0, 18)
	switchBg.Position = UDim2.new(1, -48, 0.5, -9)
	switchBg.BackgroundColor3 = toggled and Theme.Accent or Theme.SliderBg
	switchBg.BorderSizePixel = 0
	switchBg.Parent = topArea
	ApplyCorner(switchBg, 9)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 12, 0, 12)
	knob.Position = UDim2.new(0, toggled and 21 or 3, 0.5, -6)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = switchBg
	ApplyCorner(knob, 6)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = topArea

	local function UpdateVisual()
		Tween(switchBg, 0.25, { BackgroundColor3 = toggled and Theme.Accent or Theme.SliderBg })
		Tween(knob, 0.25, { Position = UDim2.new(0, toggled and 21 or 3, 0.5, -6) })
	end

	connections:Track(btn.MouseButton1Click:Connect(function()
		toggled = not toggled
		UpdateVisual()
		if callback then connections:Invoke(callback, toggled) end
	end))

	function obj:Set(v, silent) toggled = v; UpdateVisual(); if callback and not silent then connections:Invoke(callback, toggled) end end
	function obj:Get() return toggled end
	function obj:Reset() obj:Set(default or false) end
	function obj:SetText(t) lbl.Text = t end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end

	obj.Root = frame
	obj.Header = topArea
	obj.LabelOffset = textPadLeft
	obj.Scope = connections
	ctx.Register(obj, connections, true)
	return obj
end
