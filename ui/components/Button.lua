local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, callback, config)
	config = config or {}
	local Theme, p = ctx.Theme, ctx.Primitives
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj, debounce, hovered = {}, false, false
	local card = ctx.ActionGroup and ctx.ActionGroup.Cards
	local primary, danger = config.Variant == "Primary", config.Variant == "Danger"
	local ghost = config.Variant == "Ghost"
	local background = primary and Theme.Text or Theme.ElementBg
	local foreground = primary and Theme.Background or (danger and Theme.Error or Theme.Text)
	local frame = Instance.new("TextButton")
	frame.Name = "ActionButton"
	frame.Size = UDim2.fromOffset(160, card and 124 or 36)
	frame.BackgroundColor3 = background
	frame.BackgroundTransparency = ghost and 1 or 0
	frame.BorderSizePixel = 0
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.Parent = ctx.Parent
	p.ApplyCorner(frame, card and 14 or 10)
	local stroke = p.ApplyStroke(frame, danger and Theme.Error or Theme.Outline)
	stroke.Transparency = (primary or ghost) and 1 or 0.35
	local icon = config.Icon and p.AttachIcon(config.Icon, frame, 16, foreground,
		card and UDim2.fromOffset(16, 15) or UDim2.new(0, 12, 0.5, -8))
	local left = card and 16 or (icon and 36 or 14)
	local label = Instance.new("TextLabel")
	label.Name = "ActionTitle"
	label.Size = UDim2.new(1, -left - 14, 0, card and 22 or 36)
	label.Position = UDim2.fromOffset(left, card and 40 or 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = foreground
	label.Font = Tokens.Font.Label
	label.TextSize = Tokens.Text.Body
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = frame
	if card then
		local description = Instance.new("TextLabel")
		description.Name = "ActionDescription"
		description.Size = UDim2.new(1, -32, 1, -78)
		description.Position = UDim2.fromOffset(16, 66)
		description.BackgroundTransparency = 1
		description.Text = config.Description or ""
		description.TextColor3 = primary and Theme.Background or Theme.SubText
		description.Font = Tokens.Font.Body
		description.TextSize = Tokens.Text.Small
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.TextWrapped = true
		description.Parent = frame
		p.AttachIcon("arrow-up-right", frame, 14, foreground, UDim2.new(1, -30, 0, 16))
	end
	local function resize()
		if ctx.ActionGroup then return end -- The grid owns card/toolbar dimensions.
		local ok, bounds = pcall(function()
			return game:GetService("TextService"):GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(10000, 36))
		end)
		local width = (ok and bounds.X or #label.Text * 7) + left + 14
		local available = ctx.Parent.AbsoluteSize.X
		frame.Size = UDim2.fromOffset(math.min(width, math.max(80, available - 8)), 36)
	end
	resize()
	connections:Track(ctx.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	local function paint()
		p.Tween(frame, 0.15, { BackgroundColor3 = hovered and (primary and Theme.SubText or Theme.HoverBg) or background,
			BackgroundTransparency = ghost and not hovered and 1 or 0 })
	end
	connections:Track(frame.MouseEnter:Connect(function() hovered = true; paint() end))
	connections:Track(frame.MouseLeave:Connect(function() hovered = false; paint() end))
	connections:Track(frame.MouseButton1Click:Connect(function()
		if debounce then return end
		debounce = true
		connections:Invoke(function()
			-- Do not resize a control under a layout when pressed.
			task.wait(0.08)
			if not connections.Alive then return end
			if callback then connections:Invoke(callback) end
			task.wait(0.2)
			if connections.Alive then debounce = false end
		end)
	end))
	function obj:SetText(value) label.Text = value; resize() end
	function obj:SetCallback(fn) callback = fn end
	function obj:SetVisible(value) frame.Visible = value end
	function obj:Destroy() frame:Destroy() end
	obj.Root = frame
	ctx.Register(obj, connections, false)
	return obj
end
