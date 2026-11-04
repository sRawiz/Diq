local import = ...
local Tokens = import("core/Tokens")
local Lifecycle = import("core/Lifecycle")
local BindContainer = import("layout/Container")
return function(ctx, tabName, tabIcon, options)
	options = options or {}
	local Theme, DiqIcons = ctx.Theme, ctx.GetIcons()
	local ApplyCorner, ApplyPadding, AttachIcon, Tween = ctx.Primitives.ApplyCorner, ctx.Primitives.ApplyPadding, ctx.Primitives.AttachIcon, ctx.Primitives.Tween
	local TabContainer, ContentArea = ctx.TabContainer, ctx.ContentArea
	local connections = Lifecycle.new(ctx.Scope)
	local Tab = { Name = tabName }
	tabIcon = tabIcon or "folder"

	-- ปุ่มแท็บใน Sidebar
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = "Nav_" .. tabName
	tabBtn.Size = UDim2.new(1, 0, 0, 38)
	tabBtn.LayoutOrder = options.Order or 0
	tabBtn.BackgroundColor3 = Theme.ActiveTab
	tabBtn.BackgroundTransparency = 1
	tabBtn.Text = ""
	tabBtn.AutoButtonColor = false
	tabBtn.Parent = TabContainer
	ApplyCorner(tabBtn, 10)

	-- แถบ accent ด้านซ้าย (แสดงว่า active)
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0, 16)
	indicator.Position = UDim2.new(0, 2, 0.5, -8)
	indicator.BackgroundColor3 = Theme.Accent
	indicator.BackgroundTransparency = 1
	indicator.BorderSizePixel = 0
	indicator.Parent = tabBtn
	indicator.Visible = false -- The selected surface is the navigation indicator.
	ApplyCorner(indicator, 2)

	-- Tab Icon (Lucide) — ถ้ามี DiqIcons ใช้ ImageLabel, ถ้าไม่มีใช้ emoji
	local hasLucideIcon = DiqIcons and DiqIcons.Exists(tabIcon)
	local textOffset = 12 -- ตำแหน่งข้อความ

	local navIcon = hasLucideIcon and AttachIcon(tabIcon, tabBtn, 16, Theme.SubText, UDim2.new(0, 12, 0.5, -8))
	if not navIcon then
		navIcon = Instance.new("TextLabel")
		navIcon.Size = UDim2.fromOffset(16, 20)
		navIcon.Position = UDim2.new(0, 12, 0.5, -10)
		navIcon.BackgroundTransparency = 1
		navIcon.Text = tabName:sub(1, 1)
		navIcon.Font = Tokens.Font.Label
		navIcon.TextSize = 13
		navIcon.TextColor3 = Theme.SubText
		navIcon.Parent = tabBtn
	end
	textOffset = 38

	-- ชื่อแท็บ
	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(1, -(textOffset + 5), 1, 0)
	btnLabel.Position = UDim2.new(0, textOffset, 0, 0)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Text = tabName
	btnLabel.TextColor3 = Theme.SubText
	btnLabel.Font = Tokens.Font.Label
	btnLabel.TextSize = Tokens.Text.Small
	btnLabel.TextXAlignment = Enum.TextXAlignment.Left
	btnLabel.TextTruncate = Enum.TextTruncate.AtEnd
	btnLabel.Parent = tabBtn
	local compactNavigation = false
	local hint = Instance.new("TextLabel")
	hint.Name = "NavigationHint"
	hint.Size = UDim2.fromOffset(170, 32)
	hint.BackgroundColor3 = Theme.HoverBg
	hint.BorderSizePixel = 0
	hint.Text = tabName
	hint.TextColor3 = Theme.Text
	hint.TextSize = Tokens.Text.Small
	hint.Font = Tokens.Font.Label
	hint.ZIndex = 50
	hint.Visible = false
	hint.Parent = ContentArea
	ApplyCorner(hint, 8)
	connections:Track(function() hint:Destroy() end)

	-- Hover effect
	connections:Track(tabBtn.MouseEnter:Connect(function()
		if compactNavigation then
			hint.Position = UDim2.fromOffset(6, tabBtn.AbsolutePosition.Y - ContentArea.AbsolutePosition.Y + 3)
			hint.Visible = true
		end
		if ctx.IsActive(Tab) then return end
		Tween(tabBtn, 0.15, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.HoverBg })
	end))
	connections:Track(tabBtn.MouseLeave:Connect(function()
		hint.Visible = false
		if ctx.IsActive(Tab) then return end
		Tween(tabBtn, 0.15, { BackgroundTransparency = 1 })
	end))

	-- Content ScrollingFrame สำหรับแท็บนี้
	local content = Instance.new("ScrollingFrame")
	content.Name = "Tab_" .. tabName
	content.Size = UDim2.new(1, -32, 1, -16)
	content.Position = UDim2.new(0, 16, 0, 8)
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.BackgroundTransparency = 1
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = Theme.Outline
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.Visible = false
	content.Parent = ContentArea

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, Tokens.Spacing.ControlGap) -- เพิ่มระยะห่างระหว่างแต่ละ Element เป็น 10
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	ApplyPadding(content, Tokens.Spacing.ContentInset, Tokens.Spacing.ContentInset, 4, 4) -- Top, Bottom, Left, Right (เพิ่มพื้นที่ขอบบนล่างซ้ายขวา)

	connections:Track(contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + Tokens.Spacing.ContentInset * 2)
	end))
	local heading = Instance.new("Frame")
	heading.Name = "PageHeader"
	heading.Size = UDim2.new(1, 0, 0, options.Description and 82 or 50)
	heading.BackgroundTransparency = 1
	heading.LayoutOrder = -100
	heading.Parent = content
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.BackgroundTransparency = 1
	title.Text = tabName
	title.TextColor3 = Theme.Text
	title.TextSize = 25
	title.Font = Tokens.Font.Strong
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = heading
	if options.Description then
		local description = Instance.new("TextLabel")
		description.Size = UDim2.new(1, -8, 0, 40)
		description.Position = UDim2.fromOffset(0, 38)
		description.BackgroundTransparency = 1
		description.Text = options.Description
		description.TextColor3 = Theme.SubText
		description.TextSize = 12
		description.Font = Tokens.Font.Body
		description.TextWrapped = true
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.Parent = heading
	end
	function Tab:_SetCompact(compact)
		compactNavigation = compact
		btnLabel.Visible = not compact
		hint.Visible = false
	end

	-- เก็บ reference สำหรับ tab switching
	Tab._button = tabBtn
	Tab._label = btnLabel
	Tab._indicator = indicator
	Tab._content = content

	-- กดเลือกแท็บ
	connections:Track(tabBtn.MouseButton1Click:Connect(function()
		hint.Visible = false
		ctx.Select(Tab)
	end))
	Tab._tracker = connections
	return BindContainer(Tab, ctx.Controls)
end
