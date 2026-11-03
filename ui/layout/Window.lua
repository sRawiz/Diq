local import = ...
local Tokens = import("core/Tokens")
local Lifecycle = import("core/Lifecycle")
local CreateTab = import("layout/Tab")
return function(ctx, config)
	local Diq, Theme = ctx.UI, ctx.Theme
	local Players, CoreGui = game:GetService("Players"), game:GetService("CoreGui")
	local UserInputService, ConnectInput, MakeDraggable = ctx.Input.Service, ctx.Input.Connect, ctx.Input.MakeDraggable
	local Tween, ApplyCorner, ApplyStroke, AttachIcon = ctx.Primitives.Tween, ctx.Primitives.ApplyCorner, ctx.Primitives.ApplyStroke, ctx.Primitives.AttachIcon
	-- รองรับทั้ง string และ table
	if type(config) == "string" then
		config = { Title = config }
	end
	config = config or {}
	local destroyed = false
	local capture = {}

	local windowTitle = config.Title or "Diq Panel"
	local windowSize  = config.Size or UDim2.new(0, 520, 0, 380)
	local toggleKey   = config.ToggleKey or Enum.KeyCode.K

	local Window = {}

	local connections = ctx.Scope

	local tabs = {}
	local activeTab = nil
	local isVisible = true
	local isMinimized = false
	Window._elements = {}
	local controls = {
		Theme = Theme, Primitives = ctx.Primitives, Input = ctx.Input, Capture = capture,
		BindSliderDrag = ctx.Input.CreateDrag(connections),
		Register = function(obj, scope, resettable) Lifecycle.Register(Window._elements, obj, scope, resettable) end,
	}

	function Window:ResetAll()
		Diq.SuppressNotifications = true
		for _, element in ipairs(table.clone(self._elements)) do
			if element.Reset then element:Reset() end
		end
		Diq.SuppressNotifications = false
	end

	-- ==========================================
	-- ลบ UI เก่าที่ค้างอยู่
	-- ==========================================
	for _, v in Players.LocalPlayer.PlayerGui:GetChildren() do
		if v.Name == "Diq_UI" then v:Destroy() end
	end
	pcall(function()
		for _, v in CoreGui:GetChildren() do
			if v.Name == "Diq_UI" then v:Destroy() end
		end
	end)

	-- ==========================================
	-- ScreenGui
	-- ==========================================
	local ScreenGui = Instance.new("ScreenGui")
	connections:Track(function() ScreenGui:Destroy() end)
	ScreenGui.Name = "Diq_UI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if not pcall(function() ScreenGui.Parent = CoreGui end) then
		ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	ctx.Notifications:Mount(ScreenGui)
	connections:Track(function() ctx.Notifications:Destroy() end)

	-- ==========================================
	-- Main Frame (เริ่มเล็ก → ขยายด้วย animation)
	-- ==========================================
	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "DiqMainFrame"
	MainFrame.Size = UDim2.new(0, 0, 0, 0)
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.BackgroundColor3 = Theme.Background
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.Parent = ScreenGui
	ApplyCorner(MainFrame, 10)
	ApplyStroke(MainFrame, Theme.Outline, 1)

	-- 🎬 Open animation
	Tween(MainFrame, 0.45, { Size = windowSize }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- ==========================================
	-- 🔝 Top Bar
	-- ==========================================
	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Size = UDim2.new(1, 0, 0, 40)
	TopBar.BackgroundColor3 = Theme.Sidebar
	TopBar.BorderSizePixel = 0
	TopBar.Parent = MainFrame
	ApplyCorner(TopBar, 10)

	-- ปิดมุมล่างของ TopBar (ให้เป็นเหลี่ยม)
	local topBarCover = Instance.new("Frame")
	topBarCover.Size = UDim2.new(1, 0, 0, 12)
	topBarCover.Position = UDim2.new(0, 0, 1, -12)
	topBarCover.BackgroundColor3 = Theme.Sidebar
	topBarCover.BorderSizePixel = 0
	topBarCover.Parent = TopBar

	MakeDraggable(TopBar, MainFrame, connections)

	-- Icon ธีม Gemini (ประกายดาว)
	AttachIcon("sparkles", TopBar, 18, Theme.Accent, UDim2.new(0, 15, 0.5, -9))

	-- ชื่อหน้าต่าง
	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Size = UDim2.new(1, -110, 1, 0)
	TitleLabel.Position = UDim2.new(0, 42, 0, 0) -- เลื่อนหลบ Icon
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Text = windowTitle
	TitleLabel.TextColor3 = Theme.Text
	TitleLabel.Font = Tokens.Font.Strong
	TitleLabel.TextSize = Tokens.Text.Title
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	TitleLabel.Parent = TopBar

	-- ==========================================
	-- ปุ่ม Minimize
	-- ==========================================
	local MinBtn = Instance.new("TextButton")
	MinBtn.Size = UDim2.new(0, 26, 0, 26)
	MinBtn.Position = UDim2.new(1, -62, 0.5, -13)
	MinBtn.BackgroundColor3 = Theme.ElementBg
	MinBtn.Text = ""
	MinBtn.AutoButtonColor = false
	MinBtn.Parent = TopBar
	ApplyCorner(MinBtn, 6)

	local minIcon = AttachIcon("minus", MinBtn, 14, Theme.SubText, UDim2.new(0.5, -7, 0.5, -7))

	connections:Track(MinBtn.MouseEnter:Connect(function()
		Tween(MinBtn, 0.2, { BackgroundColor3 = Theme.Warning })
		if minIcon then Tween(minIcon, 0.2, { ImageColor3 = Theme.Background }) end
	end))
	connections:Track(MinBtn.MouseLeave:Connect(function()
		Tween(MinBtn, 0.2, { BackgroundColor3 = Theme.ElementBg })
		if minIcon then Tween(minIcon, 0.2, { ImageColor3 = Theme.SubText }) end
	end))

	-- ==========================================
	-- ปุ่ม Close
	-- ==========================================
	local CloseBtn = Instance.new("TextButton")
	CloseBtn.Size = UDim2.new(0, 26, 0, 26)
	CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
	CloseBtn.BackgroundColor3 = Theme.ElementBg
	CloseBtn.Text = ""
	CloseBtn.AutoButtonColor = false
	CloseBtn.Parent = TopBar
	ApplyCorner(CloseBtn, 6)

	local closeIcon = AttachIcon("x", CloseBtn, 14, Theme.SubText, UDim2.new(0.5, -7, 0.5, -7))

	connections:Track(CloseBtn.MouseEnter:Connect(function()
		Tween(CloseBtn, 0.2, { BackgroundColor3 = Theme.Error })
		if closeIcon then Tween(closeIcon, 0.2, { ImageColor3 = Theme.Text }) end
	end))
	connections:Track(CloseBtn.MouseLeave:Connect(function()
		Tween(CloseBtn, 0.2, { BackgroundColor3 = Theme.ElementBg })
		if closeIcon then Tween(closeIcon, 0.2, { ImageColor3 = Theme.SubText }) end
	end))

	-- ==========================================
	-- 📦 Body (Sidebar + Content)
	-- ==========================================
	local Body = Instance.new("Frame")
	Body.Name = "Body"
	Body.Size = UDim2.new(1, 0, 1, -40)
	Body.Position = UDim2.new(0, 0, 0, 40)
	Body.BackgroundTransparency = 1
	Body.Parent = MainFrame

	-- ==========================================
	-- 📑 Sidebar (แถบแท็บด้านซ้าย)
	-- ==========================================
	local Sidebar = Instance.new("Frame")
	Sidebar.Name = "Sidebar"
	Sidebar.Size = UDim2.new(0, 135, 1, 0)
	Sidebar.BackgroundColor3 = Theme.Sidebar
	Sidebar.BorderSizePixel = 0
	Sidebar.Parent = Body

	-- Tab Container (เลื่อนได้ถ้าแท็บเยอะ)
	local TabContainer = Instance.new("ScrollingFrame")
	TabContainer.Name = "TabContainer"
	TabContainer.Size = UDim2.new(1, -10, 1, -15)
	TabContainer.Position = UDim2.new(0, 5, 0, 10)
	TabContainer.BackgroundTransparency = 1
	TabContainer.ScrollBarThickness = 2
	TabContainer.ScrollBarImageColor3 = Theme.Outline
	TabContainer.BorderSizePixel = 0
	TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	TabContainer.Parent = Sidebar

	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Padding = UDim.new(0, 4)
	tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabListLayout.Parent = TabContainer

	connections:Track(tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		TabContainer.CanvasSize = UDim2.new(0, 0, 0, tabListLayout.AbsoluteContentSize.Y + 10)
	end))

	-- เส้นแบ่ง Sidebar กับ Content
	local SidebarDivider = Instance.new("Frame")
	SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
	SidebarDivider.Position = UDim2.new(0, 135, 0, 0)
	SidebarDivider.BackgroundColor3 = Theme.Outline
	SidebarDivider.BorderSizePixel = 0
	SidebarDivider.Parent = Body

	-- ==========================================
	-- 📄 Content Area (พื้นที่แสดงเนื้อหาแต่ละแท็บ)
	-- ==========================================
	local ContentArea = Instance.new("Frame")
	ContentArea.Name = "ContentArea"
	ContentArea.Size = UDim2.new(1, -136, 1, 0)
	ContentArea.Position = UDim2.new(0, 136, 0, 0)
	ContentArea.BackgroundTransparency = 1
	ContentArea.Parent = Body

	-- ==========================================
	-- 🔀 Tab Switching Logic
	-- ==========================================
	local function SwitchTab(targetTab)
		if activeTab == targetTab then return end

		-- ปิดแท็บเก่า
		if activeTab then
			activeTab._content.Visible = false
			Tween(activeTab._button, 0.2, { BackgroundTransparency = 1 })
			Tween(activeTab._label, 0.2, { TextColor3 = Theme.SubText })
			Tween(activeTab._indicator, 0.2, { BackgroundTransparency = 1 })
		end

		-- เปิดแท็บใหม่
		activeTab = targetTab
		activeTab._content.Visible = true
		Tween(activeTab._button, 0.2, { BackgroundColor3 = Theme.ActiveTab, BackgroundTransparency = 0 })
		Tween(activeTab._label, 0.2, { TextColor3 = Theme.Text })
		Tween(activeTab._indicator, 0.2, { BackgroundTransparency = 0 })
	end

	-- ==========================================
	-- 📑 CreateTab — สร้างแท็บใหม่
	-- ==========================================
	function Window:CreateTab(tabName, tabIcon)
		assert(connections.Alive, "Cannot add tabs to a destroyed window")
		local tab = CreateTab({
			Theme = Theme, Primitives = ctx.Primitives, Scope = connections, GetIcons = ctx.GetIcons,
			TabContainer = TabContainer, ContentArea = ContentArea, Controls = controls,
			IsActive = function(candidate) return activeTab == candidate end,
			Select = SwitchTab,
		}, tabName, tabIcon)
		table.insert(tabs, tab)
		if #tabs == 1 then SwitchTab(tab) end
		return tab
	end

	-- ==========================================
	-- ปุ่ม Minimize — ย่อ/ขยายหน้าต่าง
	-- ==========================================
	local fullSize = windowSize

	connections:Track(MinBtn.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		if isMinimized then
			Tween(MainFrame, 0.3, { Size = UDim2.new(0, fullSize.X.Offset, 0, 40) })
			Body.Visible = false
			MinBtn.Text = "□"
		else
			Body.Visible = true
			Tween(MainFrame, 0.3, { Size = fullSize }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			MinBtn.Text = "─"
		end
	end))

	-- ==========================================
	-- ปุ่ม Close — ปิดหน้าต่าง + cleanup ทุก connection
	-- ==========================================
	connections:Track(CloseBtn.MouseButton1Click:Connect(function()
		if destroyed then return end
		if type(config.OnClose) == "function" then
			config.OnClose()
		else
			Window:Destroy()
		end
	end))

	-- ==========================================
	-- ปุ่มลัด Toggle UI (ค่าเริ่มต้น: K)
	-- ==========================================
	connections:Track(ConnectInput("InputBegan", function(input, gameProcessed)
		if config.ManagedInput or gameProcessed or capture.Owner or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == toggleKey then
			isVisible = not isVisible
			MainFrame.Visible = isVisible
		end
	end))

	-- ==========================================
	-- 🔧 Public Window Methods
	-- ==========================================

	function Window:SetToggleKey(key)
		assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode and key ~= Enum.KeyCode.Unknown, "Expected a keyboard KeyCode")
		toggleKey = key
	end

	function Window:GetToggleKey() return toggleKey end
	function Window:IsCapturingKeybind() return capture.Owner ~= nil end
	function Window:SelectTab(tab)
		if destroyed or not table.find(tabs, tab) then return false end
		SwitchTab(tab); self:SetVisible(true); return true
	end

	function Window:Toggle()
		isVisible = not isVisible
		MainFrame.Visible = isVisible
	end

	function Window:SetVisible(visible)
		isVisible = visible
		MainFrame.Visible = isVisible
	end

	function Window:SetTitle(newTitle)
		TitleLabel.Text = newTitle
	end

	function Window:Destroy()
		if destroyed then return end
		destroyed = true
		connections:DisconnectAll()
		table.clear(Window._elements)
		if ScreenGui then ScreenGui:Destroy() end
	end

	return Window
end
