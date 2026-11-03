local import = ...
local Tokens = import("core/Tokens")
local Lifecycle = import("core/Lifecycle")
local BindContainer = import("layout/Container")
return function(ctx, tabName, tabIcon)
	local Theme, DiqIcons = ctx.Theme, ctx.GetIcons()
	local ApplyCorner, ApplyPadding, AttachIcon, Tween = ctx.Primitives.ApplyCorner, ctx.Primitives.ApplyPadding, ctx.Primitives.AttachIcon, ctx.Primitives.Tween
	local TabContainer, ContentArea = ctx.TabContainer, ctx.ContentArea
	local connections = Lifecycle.new(ctx.Scope)
	local Tab = {}
	tabIcon = tabIcon or "folder"

	-- ปุ่มแท็บใน Sidebar
	local tabBtn = Instance.new("TextButton")
	tabBtn.Size = UDim2.new(1, 0, 0, 33)
	tabBtn.BackgroundColor3 = Theme.ActiveTab
	tabBtn.BackgroundTransparency = 1
	tabBtn.Text = ""
	tabBtn.AutoButtonColor = false
	tabBtn.Parent = TabContainer
	ApplyCorner(tabBtn, 6)

	-- แถบ accent ด้านซ้าย (แสดงว่า active)
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0, 16)
	indicator.Position = UDim2.new(0, 2, 0.5, -8)
	indicator.BackgroundColor3 = Theme.Accent
	indicator.BackgroundTransparency = 1
	indicator.BorderSizePixel = 0
	indicator.Parent = tabBtn
	ApplyCorner(indicator, 2)

	-- Tab Icon (Lucide) — ถ้ามี DiqIcons ใช้ ImageLabel, ถ้าไม่มีใช้ emoji
	local hasLucideIcon = DiqIcons and DiqIcons.Exists(tabIcon)
	local textOffset = 12 -- ตำแหน่งข้อความ

	if hasLucideIcon then
		AttachIcon(tabIcon, tabBtn, 14, Theme.SubText, UDim2.new(0, 10, 0.5, -7))
		textOffset = 30 -- เลื่อนข้อความไปทางขวาเพื่อให้พ้น icon
	end

	-- ชื่อแท็บ
	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(1, -(textOffset + 5), 1, 0)
	btnLabel.Position = UDim2.new(0, textOffset, 0, 0)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Text = hasLucideIcon and tabName or (tabIcon .. " " .. tabName)
	btnLabel.TextColor3 = Theme.SubText
	btnLabel.Font = Tokens.Font.Label
	btnLabel.TextSize = Tokens.Text.Small
	btnLabel.TextXAlignment = Enum.TextXAlignment.Left
	btnLabel.TextTruncate = Enum.TextTruncate.AtEnd
	btnLabel.Parent = tabBtn

	-- Hover effect
	connections:Track(tabBtn.MouseEnter:Connect(function()
		if ctx.IsActive(Tab) then return end
		Tween(tabBtn, 0.15, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.HoverBg })
	end))
	connections:Track(tabBtn.MouseLeave:Connect(function()
		if ctx.IsActive(Tab) then return end
		Tween(tabBtn, 0.15, { BackgroundTransparency = 1 })
	end))

	-- Content ScrollingFrame สำหรับแท็บนี้
	local content = Instance.new("ScrollingFrame")
	content.Name = "Tab_" .. tabName
	content.Size = UDim2.new(1, -16, 1, -16)
	content.Position = UDim2.new(0, 8, 0, 8)
	content.BackgroundTransparency = 1
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = Theme.Outline
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.Visible = false
	content.Parent = ContentArea

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, Tokens.Spacing.ControlGap) -- เพิ่มระยะห่างระหว่างแต่ละ Element เป็น 10
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	ApplyPadding(content, Tokens.Spacing.ContentInset, Tokens.Spacing.ContentInset, 4, 4) -- Top, Bottom, Left, Right (เพิ่มพื้นที่ขอบบนล่างซ้ายขวา)

	connections:Track(contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 15)
	end))

	-- เก็บ reference สำหรับ tab switching
	Tab._button = tabBtn
	Tab._label = btnLabel
	Tab._indicator = indicator
	Tab._content = content

	-- กดเลือกแท็บ
	connections:Track(tabBtn.MouseButton1Click:Connect(function()
		ctx.Select(Tab)
	end))
	Tab._tracker = connections
	return BindContainer(Tab, ctx.Controls)
end
