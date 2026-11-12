local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, options, default, callback)
	local Theme = ctx.Theme
	local Tween = ctx.Primitives.Tween
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplyStroke = ctx.Primitives.ApplyStroke
	local ApplyPadding = ctx.Primitives.ApplyPadding
	local AttachIcon = ctx.Primitives.AttachIcon
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj = {}
	local selected = default or (options and options[1]) or ""
	local isOpen = false
	local targetParent = ctx.Parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.ClipsDescendants = false
	frame.ZIndex = 5
	frame.Parent = targetParent
	ctx.Primitives.ApplySectionStyle(frame, ctx.Section)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, -10, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Theme.Text
	lbl.Font = Tokens.Font.Label
	lbl.TextSize = Tokens.Text.Body
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.ZIndex = 5
	lbl.Parent = frame

	-- ปุ่มแสดงค่าที่เลือก
	local selBtn = Instance.new("TextButton")
	selBtn.Size = UDim2.new(0.5, -10, 0, 26)
	selBtn.Position = UDim2.new(0.5, 0, 0.5, -13)
	selBtn.BackgroundColor3 = Theme.InputBg
	selBtn.Text = ""
	selBtn.AutoButtonColor = false
	selBtn.ZIndex = 5
	selBtn.Parent = frame
	ApplyCorner(selBtn, 6)

	local selText = Instance.new("TextLabel")
	selText.Size = UDim2.new(1, -30, 1, 0)
	selText.Position = UDim2.new(0, 10, 0, 0)
	selText.BackgroundTransparency = 1
	selText.Text = selected
	selText.TextColor3 = Theme.Text
	selText.Font = Tokens.Font.Label
	selText.TextSize = Tokens.Text.Small
	selText.TextXAlignment = Enum.TextXAlignment.Left
	selText.TextTruncate = Enum.TextTruncate.AtEnd
	selText.ZIndex = 5
	selText.Parent = selBtn

	local dropIcon = AttachIcon("chevron-down", selBtn, 14, Theme.SubText, UDim2.new(1, -22, 0.5, -7))
	if dropIcon then dropIcon.ZIndex = 5 end

	-- รายการตัวเลือก
	local dropList = Instance.new("ScrollingFrame")
	dropList.Size = UDim2.new(0.5, -10, 0, 0)
	dropList.Position = UDim2.new(0.5, 0, 1, 4)
	dropList.BackgroundColor3 = Theme.ElementBg
	dropList.ScrollBarThickness = 2
	dropList.ScrollBarImageColor3 = Theme.Outline
	dropList.BorderSizePixel = 0
	dropList.ClipsDescendants = true
	dropList.Visible = false
	dropList.ZIndex = 20
	dropList.Parent = frame
	ApplyCorner(dropList, 6)
	ApplyStroke(dropList, Theme.Accent)

	local dropLayout = Instance.new("UIListLayout")
	dropLayout.Padding = UDim.new(0, 2)
	dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dropLayout.Parent = dropList
	ApplyPadding(dropList, 4, 4, 4, 4)
	local narrow = false
	local motion
	local function stopMotion()
		local previous = motion; motion = nil
		if previous then previous:DisconnectAll() end
	end
	connections:Track(stopMotion)
	local function listSize(height) return UDim2.new(narrow and 1 or 0.5, narrow and -24 or -10, 0, height) end
	local function reflow()
		stopMotion()
		narrow = frame.AbsoluteSize.X / (ctx.GetScale and ctx.GetScale() or 1) < 360
		frame.Size = UDim2.new(1, 0, 0, narrow and 66 or 36)
		lbl.Size = narrow and UDim2.new(1, -24, 0, 24) or UDim2.new(0.5, -10, 1, 0)
		selBtn.Size = narrow and UDim2.new(1, -24, 0, 26) or UDim2.new(0.5, -10, 0, 26)
		selBtn.Position = narrow and UDim2.fromOffset(12, 30) or UDim2.new(0.5, 0, 0.5, -13)
		dropList.Position = narrow and UDim2.new(0, 12, 1, 4) or UDim2.new(0.5, 0, 1, 4)
		dropList.Size = listSize(isOpen and math.min(#options * 26 + 10, 140) or 0)
		dropList.Visible = isOpen
	end
	connections:Track(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow))
	reflow()
	local function setOpen(value)
		stopMotion(); isOpen = value
		if dropIcon then Tween(dropIcon, 0.2, { Rotation = isOpen and 180 or 0 }) end
		if value then dropList.Visible = true end
		local active = CreateConnectionTracker(connections)
		motion = active
		local tween = Tween(dropList, 0.2, { Size = listSize(value and math.min(#options * 26 + 10, 140) or 0) })
		active:Track(function() tween:Cancel() end)
		active:Once(tween.Completed, function()
			if motion ~= active then return end
			stopMotion(); dropList.Visible = isOpen
		end)
	end

	local optionBtns = {}
	local optionConnections

	local function BuildOptions()
		if optionConnections then optionConnections:DisconnectAll() end
		optionConnections = CreateConnectionTracker(connections)
		for _, b in optionBtns do b:Destroy() end
		table.clear(optionBtns)

		for _, opt in options do
			local optBtn = Instance.new("TextButton")
			optBtn.Size = UDim2.new(1, 0, 0, 24)
			optBtn.BackgroundColor3 = (opt == selected) and Theme.Accent or Theme.HoverBg
			optBtn.BackgroundTransparency = (opt == selected) and 0 or 0.5
			optBtn.Text = opt
			optBtn.TextColor3 = Theme.Text
			optBtn.Font = Tokens.Font.Body
			optBtn.TextSize = Tokens.Text.Small
			optBtn.AutoButtonColor = false
			optBtn.ZIndex = 21
			optBtn.Parent = dropList
			ApplyCorner(optBtn, 4)

			optionConnections:Track(optBtn.MouseEnter:Connect(function()
				if opt ~= selected then
					Tween(optBtn, 0.15, { BackgroundTransparency = 0, BackgroundColor3 = Theme.HoverBg })
				end
			end))
			optionConnections:Track(optBtn.MouseLeave:Connect(function()
				if opt ~= selected then
					Tween(optBtn, 0.15, { BackgroundTransparency = 0.5 })
				end
			end))

			optionConnections:Track(optBtn.MouseButton1Click:Connect(function()
				selected = opt
				selText.Text = selected

				-- อัพเดท highlight
				for _, b in optionBtns do
					if b.Text == opt then
						Tween(b, 0.15, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0 })
					else
						Tween(b, 0.15, { BackgroundColor3 = Theme.HoverBg, BackgroundTransparency = 0.5 })
					end
				end

				-- ปิด dropdown
				setOpen(false)

				if callback then connections:Invoke(callback, selected) end
			end))

			table.insert(optionBtns, optBtn)
		end
	end

	BuildOptions()

	-- เปิด/ปิด dropdown
	connections:Track(selBtn.MouseButton1Click:Connect(function()
		setOpen(not isOpen)
	end))

	function obj:Set(opt, silent)
		selected = opt; selText.Text = opt
		for _, b in optionBtns do
			local match = (b.Text == opt)
			Tween(b, 0.15, {
				BackgroundColor3 = match and Theme.Accent or Theme.HoverBg,
				BackgroundTransparency = match and 0 or 0.5,
			})
		end
		if callback and not silent then connections:Invoke(callback, selected) end
	end
	function obj:Get() return selected end
	function obj:Reset() obj:Set(default or (options and options[1]) or "") end
	function obj:SetOptions(newOpts) options = newOpts; BuildOptions(); reflow() end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end

	ctx.Register(obj, connections, true)
	return obj
end
