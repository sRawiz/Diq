local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, callback, config)
	local Theme = ctx.Theme
	local Tween = ctx.Primitives.Tween
	local ApplySectionStyle = ctx.Primitives.ApplySectionStyle
	local AttachIcon = ctx.Primitives.AttachIcon
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj = {}
	local targetParent = ctx.Parent
	local debounce = false
	config = config or {}

	local frame = Instance.new("TextButton")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.Parent = targetParent

	local stroke, isSection = ApplySectionStyle(frame, ctx.Section)

	-- Icon (ถ้ามี)
	local hasIcon = config.Icon and AttachIcon(config.Icon, frame, 16, Theme.SubText, UDim2.new(0, 12, 0.5, -8))
	local textPadLeft = hasIcon and 34 or 0

	local btn = Instance.new("TextLabel")
	btn.Size = UDim2.new(1, -textPadLeft, 1, 0)
	btn.Position = UDim2.new(0, textPadLeft, 0, 0)
	btn.BackgroundTransparency = 1
	btn.Text = text
	btn.TextColor3 = Theme.Text
	btn.Font = Tokens.Font.Label
	btn.TextSize = Tokens.Text.Body
	btn.Parent = frame

	connections:Track(frame.MouseEnter:Connect(function()
		if isSection then
			Tween(frame, 0.2, { BackgroundTransparency = 0, BackgroundColor3 = Theme.HoverBg })
		else
			Tween(frame, 0.2, { BackgroundColor3 = Theme.HoverBg })
			if stroke then Tween(stroke, 0.2, { Color = Theme.Accent }) end
		end
	end))

	connections:Track(frame.MouseLeave:Connect(function()
		if isSection then
			Tween(frame, 0.2, { BackgroundTransparency = 1 })
		else
			Tween(frame, 0.2, { BackgroundColor3 = Theme.ElementBg })
			if stroke then Tween(stroke, 0.2, { Color = Theme.Outline }) end
		end
	end))

	connections:Track(frame.MouseButton1Click:Connect(function()
		if debounce then return end
		debounce = true
		connections:Invoke(function()
			-- Click animation (ย่อ-ขยาย)
			Tween(frame, 0.08, { Size = UDim2.new(0.97, 0, 0, 33) })
			task.wait(0.08)
			if not connections.Alive then return end
			Tween(frame, 0.12, { Size = UDim2.new(1, 0, 0, 36) })

			if callback then connections:Invoke(callback) end
			task.wait(0.2)
			if not connections.Alive then return end
			debounce = false
		end)
	end))

	function obj:SetText(t) btn.Text = t end
	function obj:SetCallback(fn) callback = fn end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end
	ctx.Register(obj, connections, false)
	return obj
end
