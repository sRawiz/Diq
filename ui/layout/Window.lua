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
	local windowSize  = config.Size or UDim2.new(0.92, 0, 0.88, 0)
	local toggleKey   = config.ToggleKey or Enum.KeyCode.K

	local Window = {}

	local connections = ctx.Scope

	local tabs = {}
	local activeTab = nil
	local isVisible = true
	local isMinimized = false
	local transitioning = false
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
	-- One outer silhouette. Child surfaces must stay inside its rounded corners.
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
	local shellRadius = 18
	ApplyCorner(MainFrame, shellRadius)
	ApplyStroke(MainFrame, Theme.Outline, 1)
	local WindowScale = Instance.new("UIScale")
	WindowScale.Name = "WindowScale"
	WindowScale.Scale = 1
	WindowScale.Parent = MainFrame
	controls.GetScale = function() return WindowScale.Scale end
	if not config.Size then
		local bounds = Instance.new("UISizeConstraint")
		bounds.MaxSize = Vector2.new(920, 660)
		bounds.Parent = MainFrame
	end

	MainFrame.Size = windowSize

	-- ==========================================
	-- 🔝 Top Bar
	-- ==========================================
	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Size = UDim2.new(1, 0, 0, 52)
	TopBar.BackgroundTransparency = 1
	TopBar.BorderSizePixel = 0
	TopBar.Parent = MainFrame
	local cancelWindowDrag = MakeDraggable(TopBar, MainFrame, connections, function()
		return isVisible and not isMinimized and not transitioning
	end)

	local SidebarBtn = Instance.new("TextButton")
	SidebarBtn.Name = "ToggleSidebar"
	SidebarBtn.Size = UDim2.fromOffset(30, 30)
	SidebarBtn.Position = UDim2.new(0, 12, 0.5, -15)
	SidebarBtn.BackgroundTransparency = 1
	SidebarBtn.Text = ""
	SidebarBtn.Parent = TopBar
	if not AttachIcon("panel-left", SidebarBtn, 18, Theme.SubText, UDim2.new(0.5, -9, 0.5, -9)) then
		SidebarBtn.Text = "☰"; SidebarBtn.TextSize = 18; SidebarBtn.TextColor3 = Theme.Text
	end

	-- ชื่อหน้าต่าง
	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Size = UDim2.new(1, -136, 1, 0)
	TitleLabel.Position = UDim2.new(0, 54, 0, 0)
	TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
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
	MinBtn.Name = "Minimize"
	MinBtn.Size = UDim2.new(0, 26, 0, 26)
	MinBtn.Position = UDim2.new(1, -62, 0.5, -13)
	MinBtn.BackgroundColor3 = Theme.ElementBg
	MinBtn.Text = ""
	MinBtn.AutoButtonColor = false
	MinBtn.Parent = TopBar
	ApplyCorner(MinBtn, 6)

	local minIcon = AttachIcon("minus", MinBtn, 14, Theme.SubText, UDim2.new(0.5, -7, 0.5, -7))
	if not minIcon then MinBtn.Text = "−"; MinBtn.TextColor3 = Theme.SubText; MinBtn.TextSize = 18 end

	connections:Track(MinBtn.MouseEnter:Connect(function()
		Tween(MinBtn, 0.2, { BackgroundColor3 = Theme.HoverBg })
		if minIcon then Tween(minIcon, 0.2, { ImageColor3 = Theme.Text }) end
	end))
	connections:Track(MinBtn.MouseLeave:Connect(function()
		Tween(MinBtn, 0.2, { BackgroundColor3 = Theme.ElementBg })
		if minIcon then Tween(minIcon, 0.2, { ImageColor3 = Theme.SubText }) end
	end))

	-- ==========================================
	-- ปุ่ม Close
	-- ==========================================
	local CloseBtn = Instance.new("TextButton")
	CloseBtn.Name = "Close"
	CloseBtn.Size = UDim2.new(0, 26, 0, 26)
	CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
	CloseBtn.BackgroundColor3 = Theme.ElementBg
	CloseBtn.Text = ""
	CloseBtn.AutoButtonColor = false
	CloseBtn.Parent = TopBar
	ApplyCorner(CloseBtn, 6)

	local closeIcon = AttachIcon("x", CloseBtn, 14, Theme.SubText, UDim2.new(0.5, -7, 0.5, -7))
	if not closeIcon then CloseBtn.Text = "×"; CloseBtn.TextColor3 = Theme.SubText; CloseBtn.TextSize = 18 end

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
	Body.Size = UDim2.new(1, 0, 1, -52)
	Body.Position = UDim2.new(0, 0, 0, 52)
	Body.BackgroundTransparency = 1
	Body.Parent = MainFrame

	-- ==========================================
	-- 📑 Sidebar (แถบแท็บด้านซ้าย)
	-- ==========================================
	local Sidebar = Instance.new("Frame")
	Sidebar.Name = "Sidebar"
	Sidebar.Size = UDim2.new(0, 184, 1, 0)
	Sidebar.BackgroundTransparency = 1
	Sidebar.BorderSizePixel = 0
	Sidebar.Parent = Body
	-- UICorner does not mask descendants. Round the painted surface itself,
	-- then square only its top/right edges, which are inside the outer silhouette.
	local sidebarSurface = Instance.new("Frame")
	sidebarSurface.Name = "SidebarSurface"
	sidebarSurface.Size = UDim2.fromScale(1, 1)
	sidebarSurface.BackgroundColor3 = Theme.Sidebar
	sidebarSurface.BorderSizePixel = 0
	sidebarSurface.Parent = Sidebar
	ApplyCorner(sidebarSurface, shellRadius)
	local sidebarTop = Instance.new("Frame")
	sidebarTop.Name = "SquareTop"
	sidebarTop.Size = UDim2.new(1, 0, 0, shellRadius)
	sidebarTop.BackgroundColor3 = Theme.Sidebar
	sidebarTop.BorderSizePixel = 0
	sidebarTop.Parent = sidebarSurface
	local sidebarRight = Instance.new("Frame")
	sidebarRight.Name = "SquareRight"
	sidebarRight.Size = UDim2.new(0, shellRadius, 1, 0)
	sidebarRight.Position = UDim2.new(1, -shellRadius, 0, 0)
	sidebarRight.BackgroundColor3 = Theme.Sidebar
	sidebarRight.BorderSizePixel = 0
	sidebarRight.Parent = sidebarSurface

	-- Tab Container (เลื่อนได้ถ้าแท็บเยอะ)
	local TabContainer = Instance.new("ScrollingFrame")
	TabContainer.Name = "TabContainer"
	TabContainer.Size = UDim2.new(1, -16, 1, -108)
	TabContainer.Position = UDim2.new(0, 8, 0, 34)
	TabContainer.BackgroundTransparency = 1
	TabContainer.ScrollBarThickness = 2
	TabContainer.ScrollBarImageColor3 = Theme.Outline
	TabContainer.BorderSizePixel = 0
	TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	TabContainer.Parent = Sidebar
	local navigationLabel = Instance.new("TextLabel")
	navigationLabel.Size = UDim2.new(1, -28, 0, 24)
	navigationLabel.Position = UDim2.fromOffset(14, 4)
	navigationLabel.BackgroundTransparency = 1
	navigationLabel.Text = "WORKSPACE"
	navigationLabel.Font = Tokens.Font.Label
	navigationLabel.TextSize = 10
	navigationLabel.TextColor3 = Theme.DimText
	navigationLabel.TextXAlignment = Enum.TextXAlignment.Left
	navigationLabel.Parent = Sidebar
	local account = Instance.new("TextLabel")
	account.Name = "SidebarAccount"
	account.Size = UDim2.new(1, -24, 0, 48)
	account.Position = UDim2.new(0, 12, 1, -60)
	account.BackgroundColor3 = Theme.ElementBg
	account.BorderSizePixel = 0
	account.Text = Players.LocalPlayer.Name
	account.TextColor3 = Theme.SubText
	account.TextSize = Tokens.Text.Small
	account.Font = Tokens.Font.Label
	account.TextTruncate = Enum.TextTruncate.AtEnd
	account.Parent = Sidebar
	ApplyCorner(account, 12)

	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Padding = UDim.new(0, 4)
	tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabListLayout.Parent = TabContainer

	connections:Track(tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		TabContainer.CanvasSize = UDim2.new(0, 0, 0, tabListLayout.AbsoluteContentSize.Y / WindowScale.Scale + 10)
	end))

	-- เส้นแบ่ง Sidebar กับ Content
	local SidebarDivider = Instance.new("Frame")
	SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
	SidebarDivider.Position = UDim2.new(0, 184, 0, 0)
	SidebarDivider.BackgroundTransparency = 0.6
	SidebarDivider.BackgroundColor3 = Theme.Outline
	SidebarDivider.BorderSizePixel = 0
	SidebarDivider.Parent = Body

	-- ==========================================
	-- 📄 Content Area (พื้นที่แสดงเนื้อหาแต่ละแท็บ)
	-- ==========================================
	local ContentArea = Instance.new("Frame")
	ContentArea.Name = "ContentArea"
	ContentArea.Size = UDim2.new(1, -185, 1, 0)
	ContentArea.Position = UDim2.new(0, 185, 0, 0)
	ContentArea.BackgroundTransparency = 1
	ContentArea.Parent = Body
	local collapseRequested = false
	local function updateSidebar()
		local compact = collapseRequested or MainFrame.AbsoluteSize.X / WindowScale.Scale < 680
		local width = compact and 56 or 184
		Sidebar.Size = UDim2.new(0, width, 1, 0)
		SidebarDivider.Position = UDim2.fromOffset(width, 0)
		ContentArea.Position = UDim2.fromOffset(width + 1, 0)
		ContentArea.Size = UDim2.new(1, -width - 1, 1, 0)
		navigationLabel.Visible = not compact
		account.Text = compact and Players.LocalPlayer.Name:sub(1, 1):upper() or Players.LocalPlayer.Name
		for _, tab in tabs do tab:_SetCompact(compact) end
	end
	connections:Track(MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSidebar))
	connections:Track(SidebarBtn.MouseButton1Click:Connect(function()
		collapseRequested = not collapseRequested; updateSidebar()
	end))
	updateSidebar()

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
		TitleLabel.Text = windowTitle .. " / " .. targetTab.Name
		activeTab._content.Visible = true
		Tween(activeTab._button, 0.2, { BackgroundColor3 = Theme.ActiveTab, BackgroundTransparency = 0 })
		Tween(activeTab._label, 0.2, { TextColor3 = Theme.Text })
		Tween(activeTab._indicator, 0.2, { BackgroundTransparency = 0 })
	end

	-- ==========================================
	-- 📑 CreateTab — สร้างแท็บใหม่
	-- ==========================================
	function Window:CreateTab(tabName, tabIcon, options)
		assert(connections.Alive, "Cannot add tabs to a destroyed window")
		local tab = CreateTab({
			Theme = Theme, Primitives = ctx.Primitives, Scope = connections, GetIcons = ctx.GetIcons,
			TabContainer = TabContainer, ContentArea = ContentArea, Controls = controls,
			IsActive = function(candidate) return activeTab == candidate end,
			Select = SwitchTab,
		}, tabName, tabIcon, options)
		table.insert(tabs, tab)
		updateSidebar()
		if #tabs == 1 then SwitchTab(tab) end
		return tab
	end

	-- ==========================================
	-- Minimize into a taskbar-style restore button without changing the layout size.
	-- ==========================================
	local dockPosition = UDim2.new(0.5, 0, 1, -38)
	local restorePosition = MainFrame.Position
	local positionNeedsRestore = false
	local RestoreButton = Instance.new("TextButton")
	RestoreButton.Name = "RestoreWindow"
	RestoreButton.AnchorPoint = Vector2.new(0.5, 1)
	RestoreButton.Position = UDim2.new(0.5, 0, 1, -16)
	RestoreButton.Size = UDim2.fromOffset(196, 44)
	RestoreButton.BackgroundColor3 = Theme.Sidebar
	RestoreButton.BorderSizePixel = 0
	RestoreButton.AutoButtonColor = false
	RestoreButton.Text = ""
	RestoreButton.Visible = false
	RestoreButton.ZIndex = 10
	RestoreButton.Parent = ScreenGui
	ApplyCorner(RestoreButton, 12)
	ApplyStroke(RestoreButton, Theme.Outline, 1)
	local dockLabel = Instance.new("TextLabel")
	dockLabel.Size = UDim2.new(1, -48, 1, 0)
	dockLabel.Position = UDim2.fromOffset(14, 0)
	dockLabel.BackgroundTransparency = 1
	dockLabel.Text = windowTitle
	dockLabel.TextColor3 = Theme.Text
	dockLabel.Font = Tokens.Font.Label
	dockLabel.TextSize = Tokens.Text.Body
	dockLabel.TextXAlignment = Enum.TextXAlignment.Left
	dockLabel.TextTruncate = Enum.TextTruncate.AtEnd
	dockLabel.Parent = RestoreButton
	local restoreIcon = AttachIcon("maximize-2", RestoreButton, 16, Theme.SubText, UDim2.new(1, -30, 0.5, -8))
	if not restoreIcon then dockLabel.Text = windowTitle .. "  ↗" end
	local motionScope
	local function stopMotion()
		local previous = motionScope
		motionScope = nil
		transitioning = false
		if previous then previous:DisconnectAll() end
	end
	connections:Track(stopMotion)
	local function animateWindow()
		stopMotion()
		transitioning = true
		positionNeedsRestore = true
		cancelWindowDrag()
		local scope = Lifecycle.new(connections)
		motionScope = scope
		MainFrame.Visible = true
		RestoreButton.Visible = isMinimized
		local service = game:GetService("TweenService")
		local info = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local positionTween = service:Create(MainFrame, info, { Position = isMinimized and dockPosition or restorePosition })
		local scaleTween = service:Create(WindowScale, info, { Scale = isMinimized and 0.12 or 1 })
		scope:Track(function() positionTween:Cancel(); scaleTween:Cancel() end)
		scope:Track(scaleTween.Completed:Connect(function(state)
			if destroyed or motionScope ~= scope or state ~= Enum.PlaybackState.Completed then return end
			stopMotion()
			MainFrame.Visible = isVisible and not isMinimized
			RestoreButton.Visible = isVisible and isMinimized
			if not isMinimized then
				MainFrame.Position = restorePosition
				WindowScale.Scale = 1
				positionNeedsRestore = false
				updateSidebar()
			end
		end))
		positionTween:Play(); scaleTween:Play()
	end
	function Window:SetMinimized(value)
		if destroyed then return end
		value = value == true
		if value == isMinimized then return end
		if value and not transitioning and not positionNeedsRestore then restorePosition = MainFrame.Position end
		isMinimized = value
		if isVisible then animateWindow() end
	end
	function Window:IsMinimized() return isMinimized end
	connections:Track(MinBtn.MouseButton1Click:Connect(function() Window:SetMinimized(true) end))
	connections:Track(RestoreButton.MouseButton1Click:Connect(function() Window:SetVisible(true) end))
	connections:Track(RestoreButton.MouseEnter:Connect(function() Tween(RestoreButton, 0.15, { BackgroundColor3 = Theme.HoverBg }) end))
	connections:Track(RestoreButton.MouseLeave:Connect(function() Tween(RestoreButton, 0.15, { BackgroundColor3 = Theme.Sidebar }) end))

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
			Window:Toggle()
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
		if destroyed then return end
		self:SetVisible(isMinimized or not isVisible)
	end

	function Window:SetVisible(visible)
		if destroyed then return end
		isVisible = visible == true
		if not isVisible then
			stopMotion(); cancelWindowDrag()
			MainFrame.Visible = false; RestoreButton.Visible = false
		elseif isMinimized then
			self:SetMinimized(false)
		else
			stopMotion()
			WindowScale.Scale = 1
			MainFrame.Visible = true; RestoreButton.Visible = false
			-- Only an interrupted animation needs to restore its saved position.
			if positionNeedsRestore then MainFrame.Position = restorePosition; positionNeedsRestore = false end
			updateSidebar()
		end
	end

	function Window:SetTitle(newTitle)
		windowTitle = newTitle
		TitleLabel.Text = newTitle .. (activeTab and " / " .. activeTab.Name or "")
		dockLabel.Text = newTitle .. (not restoreIcon and "  ↗" or "")
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
