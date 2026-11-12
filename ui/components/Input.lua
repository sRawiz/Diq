local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, placeholder, callback, options)
	local Theme = ctx.Theme
	local Tween = ctx.Primitives.Tween
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplyStroke = ctx.Primitives.ApplyStroke
	local ApplyPadding = ctx.Primitives.ApplyPadding
	local connections = CreateConnectionTracker(ctx.Scope)
	options = options or {}
	local obj = {}
	local targetParent = ctx.Parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.Parent = targetParent
	ctx.Primitives.ApplySectionStyle(frame, ctx.Section)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.4, -10, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Theme.Text
	lbl.Font = Tokens.Font.Label
	lbl.TextSize = Tokens.Text.Body
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = frame

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.6, -15, 0, 24)
	inputBox.Position = UDim2.new(0.4, 0, 0.5, -12)
	inputBox.BackgroundColor3 = Theme.InputBg
	inputBox.Text = ""
	inputBox.PlaceholderText = placeholder or "Type here..."
	inputBox.PlaceholderColor3 = Theme.DimText
	inputBox.TextColor3 = Theme.Text
	inputBox.Font = Tokens.Font.Body
	inputBox.TextSize = Tokens.Text.Small
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = frame
	if options.Multiline then
		frame.Size = UDim2.new(1, 0, 0, 160)
		lbl.Size = UDim2.new(1, -24, 0, 24)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.new(0, 12, 0, 28)
		scroll.Size = UDim2.new(1, -24, 1, -40)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.Parent = frame
		inputBox.Parent = scroll
		inputBox.Position = UDim2.new(0, 0, 0, 0)
		inputBox.Size = UDim2.new(1, -6, 0, 116)
		inputBox.AutomaticSize = Enum.AutomaticSize.Y
		inputBox.MultiLine = true
		inputBox.TextXAlignment = Enum.TextXAlignment.Left
		inputBox.TextYAlignment = Enum.TextYAlignment.Top
		inputBox.TextWrapped = true
	end
	ApplyCorner(inputBox, Tokens.Radius.Input)
	ApplyPadding(inputBox, 0, 0, 8, 8)
	if not options.Multiline then
		local function reflow()
			local narrow = frame.AbsoluteSize.X / (ctx.GetScale and ctx.GetScale() or 1) < 360
			frame.Size = UDim2.new(1, 0, 0, narrow and 66 or 36)
			lbl.Size = narrow and UDim2.new(1, -24, 0, 24) or UDim2.new(0.4, -10, 1, 0)
			inputBox.Size = narrow and UDim2.new(1, -24, 0, 26) or UDim2.new(0.6, -15, 0, 24)
			inputBox.Position = narrow and UDim2.fromOffset(12, 30) or UDim2.new(0.4, 0, 0.5, -12)
		end
		connections:Track(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow))
		reflow()
	end

	local inputStroke = ApplyStroke(inputBox, Theme.Outline)

	connections:Track(inputBox.Focused:Connect(function()
		Tween(inputStroke, 0.2, { Color = Theme.Accent })
	end))

	connections:Track(inputBox.FocusLost:Connect(function(enterPressed)
		Tween(inputStroke, 0.2, { Color = Theme.Outline })
		if callback then connections:Invoke(callback, inputBox.Text, enterPressed) end
	end))

	function obj:Set(t) inputBox.Text = t end
	function obj:Get() return inputBox.Text end
	function obj:Reset() obj:Set("") end
	function obj:SetPlaceholder(t) inputBox.PlaceholderText = t end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end

	ctx.Register(obj, connections, true)
	return obj
end
