-- ==========================================
-- 🎨 Diq UI Library v2.1
-- ==========================================
-- เขียนใหม่ทั้งหมดพร้อม:
-- ✅ แก้ Memory Leak ทุกจุด (Connection Tracker)
-- ✅ Tab System (Sidebar)
-- ✅ ทุก element return object ควบคุมได้
-- ✅ Components ใหม่: Slider, Dropdown, Input, Keybind
-- ✅ Notification System
-- ✅ Minimize / Close / Toggle Keybind
-- ✅ Open/Close Animation
-- ✅ Theme Customization API
-- ✅ Debounce ทุกปุ่ม
-- ✅ Window:Destroy() cleanup
-- ✅ Lucide Icons (DiqIcons) — ไม่ต้องใช้ Emoji อีกต่อไป

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Diq = {}
local DiqIcons = nil -- จะโหลดทีหลังผ่าน Diq:LoadIcons()

-- ==========================================
-- 🎨 Default Theme (Zinc / Indigo)
-- ==========================================
local DefaultTheme = {
	Background  = Color3.fromRGB(18, 18, 20),   -- #121214
	Sidebar     = Color3.fromRGB(26, 26, 30),   -- #1A1A1E
	ElementBg   = Color3.fromRGB(36, 36, 41),   -- #242429
	HoverBg     = Color3.fromRGB(44, 45, 50),   -- #2C2D32
	ActiveTab   = Color3.fromRGB(44, 45, 50),   -- #2C2D32
	Accent      = Color3.fromRGB(84, 98, 239),  -- #5462EF (Blurple)
	AccentHover = Color3.fromRGB(104, 118, 255),
	Text        = Color3.fromRGB(219, 222, 225),-- #DBDEE1 (Discord Chat Text)
	SubText     = Color3.fromRGB(150, 151, 158),-- #96979E
	DimText     = Color3.fromRGB(110, 111, 118),
	Outline     = Color3.fromRGB(44, 45, 50),   -- #2C2D32
	SliderBg    = Color3.fromRGB(26, 26, 30),   -- #1A1A1E
	InputBg     = Color3.fromRGB(26, 26, 30),   -- #1A1A1E
	NotifyBg    = Color3.fromRGB(36, 36, 41),   -- #242429
	Success     = Color3.fromRGB(34, 197, 94),
	Warning     = Color3.fromRGB(250, 204, 21),
	Error       = Color3.fromRGB(239, 68, 68),
}

local Theme = table.clone(DefaultTheme)

-- เปลี่ยนธีมสีทั้งระบบ
function Diq:SetTheme(newTheme)
	for key, value in newTheme do
		if DefaultTheme[key] ~= nil then
			Theme[key] = value
		end
	end
end

-- ==========================================
-- 🔧 Utility Functions
-- ==========================================

-- ระบบจัดการ Connection ป้องกัน Memory Leak
local function CreateConnectionTracker()
	local tracker = { _list = {} }

	function tracker:Track(connection)
		table.insert(self._list, connection)
		return connection
	end

	function tracker:DisconnectAll()
		for _, conn in self._list do
			if typeof(conn) == "RBXScriptConnection" and conn.Connected then
				conn:Disconnect()
			end
		end
		table.clear(self._list)
	end

	return tracker
end

-- Tween Helper
local function Tween(obj, duration, props, style, dir)
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- สร้าง UICorner
local function ApplyCorner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = obj
	return c
end

-- สร้าง UIStroke
local function ApplyStroke(obj, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Outline
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

-- สร้าง UIPadding
local function ApplyPadding(obj, top, bottom, left, right)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top or 0)
	p.PaddingBottom = UDim.new(0, bottom or 0)
	p.PaddingLeft = UDim.new(0, left or 0)
	p.PaddingRight = UDim.new(0, right or 0)
	p.Parent = obj
	return p
end

-- แปะ Lucide Icon เข้าไปใน Frame (คืน ImageLabel)
-- ถ้าไม่มี DiqIcons หรือหา icon ไม่เจอ จะ return nil
local function AttachIcon(iconName, parent, size, color, position)
	if not DiqIcons or not iconName then return nil end
	if not DiqIcons.Exists(iconName) then return nil end

	size = size or 16
	color = color or Theme.SubText
	position = position or UDim2.new(0, 10, 0.5, -(size / 2))

	local icon = DiqIcons.Create(iconName, parent, size, color)
	if icon then
		icon.Position = position
	end
	return icon
end

-- ลากหน้าต่างได้ (แก้ leak: ทุก connection ถูก track)
local function MakeDraggable(dragPart, mainFrame, tracker)
	local dragging = false
	local dragStart, startPos

	tracker:Track(dragPart.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
		end
	end))

	tracker:Track(dragPart.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	tracker:Track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))
end

-- ==========================================
-- 🔔 Notification System
-- ==========================================
local NotificationHolder = nil

local function EnsureNotificationHolder(screenGui)
	if NotificationHolder and NotificationHolder.Parent then return end

	NotificationHolder = Instance.new("Frame")
	NotificationHolder.Name = "DiqNotifications"
	NotificationHolder.Size = UDim2.new(0, 280, 1, -20)
	NotificationHolder.Position = UDim2.new(1, -290, 0, 10)
	NotificationHolder.BackgroundTransparency = 1
	NotificationHolder.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = NotificationHolder
end

-- แสดงการแจ้งเตือน
-- notifType: "info" | "success" | "warning" | "error"
function Diq:Notify(title, message, duration, notifType)
	if not NotificationHolder or not NotificationHolder.Parent then return end

	duration = duration or 3
	notifType = notifType or "info"

	local accentColor = Theme.Accent
	if notifType == "success" then accentColor = Theme.Success
	elseif notifType == "warning" then accentColor = Theme.Warning
	elseif notifType == "error" then accentColor = Theme.Error end

	-- Notification frame
	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(1, 0, 0, 68)
	notif.BackgroundColor3 = Theme.NotifyBg
	notif.BackgroundTransparency = 1
	notif.ClipsDescendants = true
	notif.Parent = NotificationHolder
	ApplyCorner(notif, 8)
	ApplyStroke(notif, Theme.Outline)

	-- แถบสีด้านซ้าย
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 1, -10)
	bar.Position = UDim2.new(0, 6, 0, 5)
	bar.BackgroundColor3 = accentColor
	bar.BorderSizePixel = 0
	bar.Parent = notif
	ApplyCorner(bar, 2)

	-- หัวข้อ
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -25, 0, 20)
	titleLbl.Position = UDim2.new(0, 18, 0, 8)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title or "Notification"
	titleLbl.TextColor3 = Theme.Text
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = notif

	-- เนื้อหา
	local msgLbl = Instance.new("TextLabel")
	msgLbl.Size = UDim2.new(1, -25, 0, 30)
	msgLbl.Position = UDim2.new(0, 18, 0, 30)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Text = message or ""
	msgLbl.TextColor3 = Theme.SubText
	msgLbl.Font = Enum.Font.Gotham
	msgLbl.TextSize = 12
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextYAlignment = Enum.TextYAlignment.Top
	msgLbl.TextWrapped = true
	msgLbl.Parent = notif

	-- Slide in
	Tween(notif, 0.35, { BackgroundTransparency = 0 })

	-- หายไปอัตโนมัติ
	task.delay(duration, function()
		if notif and notif.Parent then
			local tw = Tween(notif, 0.3, {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
			})
			tw.Completed:Once(function()
				if notif then notif:Destroy() end
			end)
		end
	end)
end

-- ==========================================
-- 🖥️ Window System
-- ==========================================

-- เก็บ tracker ระดับ module เพื่อ cleanup ตอนสร้าง window ใหม่
local _activeTracker = nil

function Diq:CreateWindow(config)
	-- รองรับทั้ง string และ table
	if type(config) == "string" then
		config = { Title = config }
	end
	config = config or {}

	local windowTitle = config.Title or "Diq Panel"
	local windowSize  = config.Size or UDim2.new(0, 520, 0, 380)
	local toggleKey   = config.ToggleKey or Enum.KeyCode.RightShift

	local Window = {}
	
	-- Cleanup tracker เก่า (ป้องกัน leak จาก window เก่า)
	if _activeTracker then
		_activeTracker:DisconnectAll()
		_activeTracker = nil
	end
	
	local connections = CreateConnectionTracker()
	_activeTracker = connections
	
	local tabs = {}
	local activeTab = nil
	local isVisible = true
	local isMinimized = false

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
	ScreenGui.Name = "Diq_UI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if not pcall(function() ScreenGui.Parent = CoreGui end) then
		ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	EnsureNotificationHolder(ScreenGui)

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
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.TextSize = 15
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
		btnLabel.Font = Enum.Font.GothamMedium
		btnLabel.TextSize = 12
		btnLabel.TextXAlignment = Enum.TextXAlignment.Left
		btnLabel.TextTruncate = Enum.TextTruncate.AtEnd
		btnLabel.Parent = tabBtn

		-- Hover effect
		connections:Track(tabBtn.MouseEnter:Connect(function()
			if activeTab and activeTab._button == tabBtn then return end
			Tween(tabBtn, 0.15, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.HoverBg })
		end))
		connections:Track(tabBtn.MouseLeave:Connect(function()
			if activeTab and activeTab._button == tabBtn then return end
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
		contentLayout.Padding = UDim.new(0, 10) -- เพิ่มระยะห่างระหว่างแต่ละ Element เป็น 10
		contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
		contentLayout.Parent = content

		ApplyPadding(content, 8, 8, 4, 4) -- Top, Bottom, Left, Right (เพิ่มพื้นที่ขอบบนล่างซ้ายขวา)

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
			SwitchTab(Tab)
		end))

		table.insert(tabs, Tab)

		-- เลือกแท็บแรกอัตโนมัติ
		if #tabs == 1 then
			SwitchTab(Tab)
		end

		-- ======================================
		-- 📝 CreateLabel — หัวข้อหมวดหมู่
		-- ======================================
		function Tab:CreateLabel(text)
			local obj = {}
			local targetParent = (self and self._content) or content

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 28) -- เพิ่มความสูงให้ Label มีที่หายใจมากขึ้น
			frame.BackgroundTransparency = 1
			frame.Parent = targetParent

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -5, 1, 0)
			lbl.Position = UDim2.new(0, 5, 0, 4) -- เลื่อนลงมานิดนึงให้ดูไม่ชิดขอบบน
			lbl.BackgroundTransparency = 1
			lbl.Text = text
			lbl.TextColor3 = Theme.DimText
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 12 -- ขยาย Font ให้เด่นขึ้นนิดหน่อย
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = frame

			-- เส้นแบ่งใต้หัวข้อ
			local sep = Instance.new("Frame")
			sep.Size = UDim2.new(1, -10, 0, 1)
			sep.Position = UDim2.new(0, 5, 1, -1)
			sep.BackgroundColor3 = Theme.Outline
			sep.BackgroundTransparency = 0.5
			sep.BorderSizePixel = 0
			sep.Parent = frame

			function obj:SetText(t) lbl.Text = t end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- 💳 CreateProfileCard — การ์ดโปรไฟล์มีรูป Avatar
		-- ======================================
		function Tab:CreateProfileCard(playerName, executorName, userId)
			local obj = {}
			local targetParent = (self and self._content) or content

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 64)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.Parent = targetParent
			ApplyCorner(frame, 8)
			ApplyStroke(frame, Theme.Outline)

			-- รูป Avatar (วงกลม)
			local avatar = Instance.new("ImageLabel")
			avatar.Size = UDim2.new(0, 44, 0, 44)
			avatar.Position = UDim2.new(0, 10, 0.5, -22)
			avatar.BackgroundColor3 = Theme.HoverBg
			avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
			avatar.Parent = frame
			ApplyCorner(avatar, 22)

			-- ชื่อผู้เล่น
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -70, 0, 20)
			nameLbl.Position = UDim2.new(0, 64, 0, 12)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = playerName
			nameLbl.TextColor3 = Theme.Text
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextSize = 14
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Parent = frame

			-- ชื่อ Executor
			local execLbl = Instance.new("TextLabel")
			execLbl.Size = UDim2.new(1, -70, 0, 16)
			execLbl.Position = UDim2.new(0, 64, 0, 34)
			execLbl.BackgroundTransparency = 1
			execLbl.Text = "Using: " .. (executorName or "Unknown")
			execLbl.TextColor3 = Theme.Accent
			execLbl.Font = Enum.Font.GothamMedium
			execLbl.TextSize = 12
			execLbl.TextXAlignment = Enum.TextXAlignment.Left
			execLbl.Parent = frame

			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- 📦 CreateSection — กล่องจัดกลุ่ม (Unified Container)
		-- ======================================
		function Tab:CreateSection(title)
			local Section = {}
			setmetatable(Section, { __index = Tab })

			local targetParent = (self and self._content) or content

			local sectionFrame = Instance.new("Frame")
			sectionFrame.Size = UDim2.new(1, 0, 0, 0)
			sectionFrame.BackgroundColor3 = Theme.ElementBg
			sectionFrame.ClipsDescendants = true
			sectionFrame.Parent = targetParent
			ApplyCorner(sectionFrame, 8)
			ApplyStroke(sectionFrame, Theme.Outline)

			local sectionLayout = Instance.new("UIListLayout")
			sectionLayout.Padding = UDim.new(0, 0)
			sectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sectionLayout.Parent = sectionFrame

			local titleContainer = Instance.new("Frame")
			titleContainer.Size = UDim2.new(1, 0, 0, 30)
			titleContainer.BackgroundColor3 = Theme.HoverBg
			titleContainer.BackgroundTransparency = 0.5
			titleContainer.BorderSizePixel = 0
			titleContainer.Parent = sectionFrame

			local titleLbl = Instance.new("TextLabel")
			titleLbl.Size = UDim2.new(1, -24, 1, 0)
			titleLbl.Position = UDim2.new(0, 12, 0, 0)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Text = title
			titleLbl.TextColor3 = Theme.Accent
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.TextSize = 12
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.Parent = titleContainer

			connections:Track(sectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				sectionFrame.Size = UDim2.new(1, 0, 0, sectionLayout.AbsoluteContentSize.Y)
			end))

			Section._content = sectionFrame
			Section._isSection = true
			Section._itemCount = 0
			return Section
		end

		-- ======================================
		-- 🔘 CreateButton — ปุ่มกด (มี debounce)
		-- ======================================
		function Tab:CreateButton(text, callback, config)
			local obj = {}
			local targetParent = (self and self._content) or content
			local debounce = false
			config = config or {}

			local frame = Instance.new("TextButton")
			frame.Size = UDim2.new(1, 0, 0, 36)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.AutoButtonColor = false
			frame.Text = ""
			frame.Parent = targetParent
			
			local isSection = self and self._isSection
			local stroke
			
			if isSection then
				frame.BackgroundTransparency = 1
				if self._itemCount and self._itemCount > 0 then
					local sep = Instance.new("Frame")
					sep.Size = UDim2.new(1, -24, 0, 1)
					sep.Position = UDim2.new(0, 12, 0, 0)
					sep.BackgroundColor3 = Theme.Outline
					sep.BorderSizePixel = 0
					sep.BackgroundTransparency = 0.5
					sep.Parent = frame
				end
				if self._itemCount then self._itemCount = self._itemCount + 1 end
			else
				ApplyCorner(frame, 8)
				stroke = ApplyStroke(frame, Theme.Outline)
			end

			-- Icon (ถ้ามี)
			local hasIcon = config.Icon and AttachIcon(config.Icon, frame, 16, Theme.SubText, UDim2.new(0, 12, 0.5, -8))
			local textPadLeft = hasIcon and 34 or 0

			local btn = Instance.new("TextLabel")
			btn.Size = UDim2.new(1, -textPadLeft, 1, 0)
			btn.Position = UDim2.new(0, textPadLeft, 0, 0)
			btn.BackgroundTransparency = 1
			btn.Text = text
			btn.TextColor3 = Theme.Text
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 13
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

				-- Click animation (ย่อ-ขยาย)
				Tween(frame, 0.08, { Size = UDim2.new(0.97, 0, 0, 33) })
				task.wait(0.08)
				Tween(frame, 0.12, { Size = UDim2.new(1, 0, 0, 36) })

				if callback then task.spawn(callback) end
				task.wait(0.2)
				debounce = false
			end))

			function obj:SetText(t) btn.Text = t end
			function obj:SetCallback(fn) callback = fn end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- 🔄 CreateToggle — สวิตช์เปิด/ปิด (รองรับ Keybind & Slider ในตัว)
		-- ======================================
		function Tab:CreateToggle(text, default, callback, config)
			local obj = {}
			local toggled = default or false
			config = config or {}

			local frameHeight = 36
			if config.Slider then frameHeight = frameHeight + 46 end

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, frameHeight)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.Parent = content

			local isSection = self and self._isSection
			
			if isSection then
				frame.BackgroundTransparency = 1
				if self._itemCount and self._itemCount > 0 then
					local sep = Instance.new("Frame")
					sep.Size = UDim2.new(1, -24, 0, 1)
					sep.Position = UDim2.new(0, 12, 0, 0)
					sep.BackgroundColor3 = Theme.Outline
					sep.BorderSizePixel = 0
					sep.BackgroundTransparency = 0.5
					sep.Parent = frame
				end
				if self._itemCount then self._itemCount = self._itemCount + 1 end
			else
				ApplyCorner(frame, 8)
				ApplyStroke(frame, Theme.Outline)
			end

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
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
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

			-- KEYBIND (ถ้ามี)
			local currentKey = config.Keybind and config.Keybind.Default
			if config.Keybind then
				local keyBtn = Instance.new("TextButton")
				keyBtn.Size = UDim2.new(0, 32, 0, 20)
				keyBtn.Position = UDim2.new(1, -90, 0.5, -10)
				keyBtn.BackgroundColor3 = Theme.Background
				keyBtn.Text = currentKey and "[" .. currentKey.Name .. "]" or "[None]"
				keyBtn.TextColor3 = Theme.SubText
				keyBtn.Font = Enum.Font.GothamBold
				keyBtn.TextSize = 11
				keyBtn.ZIndex = 2
				keyBtn.Parent = topArea
				ApplyCorner(keyBtn, 4)
				ApplyStroke(keyBtn, Theme.Outline)

				local listening = false
				connections:Track(keyBtn.MouseButton1Click:Connect(function()
					listening = true
					keyBtn.Text = "..."
					Tween(keyBtn, 0.2, { BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Background })
				end))

				connections:Track(UserInputService.InputBegan:Connect(function(input, gp)
					if listening and input.UserInputType == Enum.UserInputType.Keyboard then
						listening = false
						currentKey = input.KeyCode
						keyBtn.Text = "[" .. currentKey.Name .. "]"
						Tween(keyBtn, 0.2, { BackgroundColor3 = Theme.Background, TextColor3 = Theme.SubText })
						if config.Keybind.Callback then task.spawn(config.Keybind.Callback, currentKey) end
					elseif not listening and input.KeyCode == currentKey and not gp then
						-- Auto toggle on hotkey!
						toggled = not toggled
						UpdateVisual()
						if callback then task.spawn(callback, toggled) end
					end
				end))
			end

			-- SLIDER (ถ้ามี)
			if config.Slider then
				local sMin = config.Slider.Min or 0
				local sMax = config.Slider.Max or 100
				local sValue = math.clamp(config.Slider.Default or sMin, sMin, sMax)
				local sCb = config.Slider.Callback
				local sliding = false

				local sliderArea = Instance.new("Frame")
				sliderArea.Size = UDim2.new(1, 0, 0, 46)
				sliderArea.Position = UDim2.new(0, 0, 0, 36)
				sliderArea.BackgroundTransparency = 1
				sliderArea.Parent = frame

				local sep = Instance.new("Frame")
				sep.Size = UDim2.new(1, -24, 0, 1)
				sep.Position = UDim2.new(0, 12, 0, 0)
				sep.BackgroundColor3 = Theme.Outline
				sep.BackgroundTransparency = 0.5
				sep.BorderSizePixel = 0
				sep.Parent = sliderArea

				local sLbl = Instance.new("TextLabel")
				sLbl.Size = UDim2.new(1, -60, 0, 16)
				sLbl.Position = UDim2.new(0, textPadLeft, 0, 6)
				sLbl.BackgroundTransparency = 1
				sLbl.Text = config.Slider.Text or "Speed"
				sLbl.TextColor3 = Theme.SubText
				sLbl.Font = Enum.Font.GothamMedium
				sLbl.TextSize = 11
				sLbl.TextXAlignment = Enum.TextXAlignment.Left
				sLbl.Parent = sliderArea

				local valInput = Instance.new("TextBox")
				valInput.Size = UDim2.new(0, 35, 0, 16)
				valInput.Position = UDim2.new(1, -48, 0, 6)
				valInput.BackgroundColor3 = Theme.Background
				valInput.Text = tostring(math.floor(sValue))
				valInput.TextColor3 = Theme.Accent
				valInput.Font = Enum.Font.GothamBold
				valInput.TextSize = 10
				valInput.TextXAlignment = Enum.TextXAlignment.Center
				valInput.ClearTextOnFocus = false
				valInput.Parent = sliderArea
				ApplyCorner(valInput, 4)
				ApplyStroke(valInput, Theme.Outline)

				local track = Instance.new("Frame")
				track.Size = UDim2.new(1, -24, 0, 5)
				track.Position = UDim2.new(0, 12, 0, 28)
				track.BackgroundColor3 = Theme.SliderBg
				track.BorderSizePixel = 0
				track.Parent = sliderArea
				ApplyCorner(track, 3)

				local fill = Instance.new("Frame")
				fill.Size = UDim2.new((sValue - sMin) / math.max(sMax - sMin, 1), 0, 1, 0)
				fill.BackgroundColor3 = Theme.Accent
				fill.BorderSizePixel = 0
				fill.Parent = track
				ApplyCorner(fill, 3)

				local sKnob = Instance.new("Frame")
				sKnob.Size = UDim2.new(0, 10, 0, 10)
				sKnob.Position = UDim2.new((sValue - sMin) / math.max(sMax - sMin, 1), -5, 0.5, -5)
				sKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				sKnob.BorderSizePixel = 0
				sKnob.Parent = track
				ApplyCorner(sKnob, 5)

				local hitArea = Instance.new("TextButton")
				hitArea.Size = UDim2.new(1, -24, 0, 18)
				hitArea.Position = UDim2.new(0, 12, 0, 20)
				hitArea.BackgroundTransparency = 1
				hitArea.Text = ""
				hitArea.ZIndex = 3
				hitArea.Parent = sliderArea

				local function UpdateSlider(newValue)
					sValue = math.clamp(math.floor(newValue), sMin, sMax)
					local ratio = (sValue - sMin) / math.max(sMax - sMin, 1)
					fill.Size = UDim2.new(ratio, 0, 1, 0)
					sKnob.Position = UDim2.new(ratio, -5, 0.5, -5)
					valInput.Text = tostring(sValue)
					if sCb then task.spawn(sCb, sValue) end
				end

				connections:Track(valInput.FocusLost:Connect(function()
					local parsed = tonumber(valInput.Text)
					if parsed then UpdateSlider(parsed) else valInput.Text = tostring(sValue) end
				end))

				connections:Track(hitArea.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = true
						local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
						UpdateSlider(sMin + (sMax - sMin) * ratio)
					end
				end))

				connections:Track(UserInputService.InputEnded:Connect(function(input)
					if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
						sliding = false
					end
				end))
			end

			connections:Track(btn.MouseButton1Click:Connect(function()
				toggled = not toggled
				UpdateVisual()
				if callback then task.spawn(callback, toggled) end
			end))

			function obj:Set(v) toggled = v; UpdateVisual(); if callback then task.spawn(callback, toggled) end end
			function obj:Get() return toggled end
			function obj:SetText(t) lbl.Text = t end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- 📏 CreateSlider — ปรับค่าตัวเลข
		-- ======================================
		function Tab:CreateSlider(text, min, max, default, callback)
			local obj = {}
			local value = math.clamp(default or min, min, max)
			local sliding = false
			local targetParent = (self and self._content) or content

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 52)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.Parent = targetParent

			local isSection = self and self._isSection
			
			if isSection then
				frame.BackgroundTransparency = 1
				if self._itemCount and self._itemCount > 0 then
					local sep = Instance.new("Frame")
					sep.Size = UDim2.new(1, -24, 0, 1)
					sep.Position = UDim2.new(0, 12, 0, 0)
					sep.BackgroundColor3 = Theme.Outline
					sep.BorderSizePixel = 0
					sep.BackgroundTransparency = 0.5
					sep.Parent = frame
				end
				if self._itemCount then self._itemCount = self._itemCount + 1 end
			else
				ApplyCorner(frame, 8)
				ApplyStroke(frame, Theme.Outline)
			end

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -55, 0, 20)
			lbl.Position = UDim2.new(0, 12, 0, 4)
			lbl.BackgroundTransparency = 1
			lbl.Text = text
			lbl.TextColor3 = Theme.Text
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = frame

			local valInput = Instance.new("TextBox")
			valInput.Size = UDim2.new(0, 45, 0, 20)
			valInput.Position = UDim2.new(1, -55, 0, 6)
			valInput.BackgroundColor3 = Theme.Background
			valInput.Text = tostring(math.floor(value))
			valInput.TextColor3 = Theme.Accent
			valInput.Font = Enum.Font.GothamBold
			valInput.TextSize = 12
			valInput.TextXAlignment = Enum.TextXAlignment.Center
			valInput.ClearTextOnFocus = false
			valInput.Parent = frame
			ApplyCorner(valInput, 4)
			ApplyStroke(valInput, Theme.Outline)

			-- แท่งพื้นหลัง
			local track = Instance.new("Frame")
			track.Size = UDim2.new(1, -24, 0, 5)
			track.Position = UDim2.new(0, 12, 0, 34)
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
			sliderKnob.Size = UDim2.new(0, 12, 0, 12)
			sliderKnob.Position = UDim2.new((value - min) / math.max(max - min, 1), -6, 0.5, -6)
			sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sliderKnob.BorderSizePixel = 0
			sliderKnob.ZIndex = 2
			sliderKnob.Parent = track
			ApplyCorner(sliderKnob, 6)

			-- ปุ่มกดใส (ครอบพื้นที่ slider)
			local hitArea = Instance.new("TextButton")
			hitArea.Size = UDim2.new(1, -24, 0, 22)
			hitArea.Position = UDim2.new(0, 12, 0, 24)
			hitArea.BackgroundTransparency = 1
			hitArea.Text = ""
			hitArea.ZIndex = 3
			hitArea.Parent = frame

			local function UpdateSlider(newValue)
				value = math.clamp(math.floor(newValue), min, max)
				local ratio = (value - min) / math.max(max - min, 1)
				fill.Size = UDim2.new(ratio, 0, 1, 0)
				sliderKnob.Position = UDim2.new(ratio, -6, 0.5, -6)
				valInput.Text = tostring(value)
				if callback then task.spawn(callback, value) end
			end

			connections:Track(valInput.FocusLost:Connect(function()
				local parsed = tonumber(valInput.Text)
				if parsed then
					UpdateSlider(parsed)
				else
					valInput.Text = tostring(value)
				end
			end))

			connections:Track(hitArea.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					local ratio = math.clamp(
						(input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1
					)
					UpdateSlider(min + (max - min) * ratio)
				end
			end))

			-- ปล่อย mouse ที่ไหนก็ได้ → หยุด slide
			connections:Track(UserInputService.InputEnded:Connect(function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch) then
					sliding = false
				end
			end))

			-- ลาก mouse → อัพเดทค่า
			connections:Track(UserInputService.InputChanged:Connect(function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
					local ratio = math.clamp(
						(input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1
					)
					UpdateSlider(min + (max - min) * ratio)
				end
			end))

			function obj:Set(v) UpdateSlider(v) end
			function obj:Get() return value end
			function obj:SetText(t) lbl.Text = t end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- 📋 CreateDropdown — เลือกจากรายการ
		-- ======================================
		function Tab:CreateDropdown(text, options, default, callback)
			local obj = {}
			local selected = default or (options and options[1]) or ""
			local isOpen = false
			local targetParent = (self and self._content) or content

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 36)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.ClipsDescendants = false
			frame.ZIndex = 5
			frame.Parent = targetParent
			ApplyCorner(frame, 8)
			ApplyStroke(frame, Theme.Outline)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0.5, -10, 1, 0)
			lbl.Position = UDim2.new(0, 12, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = text
			lbl.TextColor3 = Theme.Text
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
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
			selText.Font = Enum.Font.GothamMedium
			selText.TextSize = 12
			selText.TextXAlignment = Enum.TextXAlignment.Left
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

			local optionBtns = {}

			local function BuildOptions()
				for _, b in optionBtns do b:Destroy() end
				table.clear(optionBtns)

				for _, opt in options do
					local optBtn = Instance.new("TextButton")
					optBtn.Size = UDim2.new(1, 0, 0, 24)
					optBtn.BackgroundColor3 = (opt == selected) and Theme.Accent or Theme.HoverBg
					optBtn.BackgroundTransparency = (opt == selected) and 0 or 0.5
					optBtn.Text = opt
					optBtn.TextColor3 = Theme.Text
					optBtn.Font = Enum.Font.Gotham
					optBtn.TextSize = 12
					optBtn.AutoButtonColor = false
					optBtn.ZIndex = 21
					optBtn.Parent = dropList
					ApplyCorner(optBtn, 4)

					connections:Track(optBtn.MouseEnter:Connect(function()
						if opt ~= selected then
							Tween(optBtn, 0.15, { BackgroundTransparency = 0, BackgroundColor3 = Theme.HoverBg })
						end
					end))
					connections:Track(optBtn.MouseLeave:Connect(function()
						if opt ~= selected then
							Tween(optBtn, 0.15, { BackgroundTransparency = 0.5 })
						end
					end))

					connections:Track(optBtn.MouseButton1Click:Connect(function()
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
						isOpen = false
						if dropIcon then Tween(dropIcon, 0.2, { Rotation = 0 }) end
						local tw = Tween(dropList, 0.2, { Size = UDim2.new(0.5, -10, 0, 0) })
						tw.Completed:Once(function()
							dropList.Visible = false
						end)

						if callback then task.spawn(callback, selected) end
					end))

					table.insert(optionBtns, optBtn)
				end
			end

			BuildOptions()

			-- เปิด/ปิด dropdown
			connections:Track(selBtn.MouseButton1Click:Connect(function()
				isOpen = not isOpen
				if dropIcon then Tween(dropIcon, 0.2, { Rotation = isOpen and 180 or 0 }) end
				
				if isOpen then
					dropList.Visible = true
					local targetH = math.min(#options * 26 + 10, 140)
					Tween(dropList, 0.2, { Size = UDim2.new(0.5, -10, 0, targetH) })
				else
					local tw = Tween(dropList, 0.2, { Size = UDim2.new(0.5, -10, 0, 0) })
					tw.Completed:Once(function() dropList.Visible = false end)
				end
			end))

			function obj:Set(opt)
				selected = opt; selText.Text = opt
				for _, b in optionBtns do
					local match = (b.Text == opt)
					Tween(b, 0.15, {
						BackgroundColor3 = match and Theme.Accent or Theme.HoverBg,
						BackgroundTransparency = match and 0 or 0.5,
					})
				end
				if callback then task.spawn(callback, selected) end
			end
			function obj:Get() return selected end
			function obj:SetOptions(newOpts) options = newOpts; BuildOptions() end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- ✏️ CreateInput — ช่องพิมพ์ข้อความ
		-- ======================================
		function Tab:CreateInput(text, placeholder, callback)
			local obj = {}
			local targetParent = (self and self._content) or content

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 36)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.Parent = targetParent
			ApplyCorner(frame, 8)
			ApplyStroke(frame, Theme.Outline)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0.4, -10, 1, 0)
			lbl.Position = UDim2.new(0, 12, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = text
			lbl.TextColor3 = Theme.Text
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = frame

			local inputBox = Instance.new("TextBox")
			inputBox.Size = UDim2.new(0.6, -15, 0, 24)
			inputBox.Position = UDim2.new(0.4, 0, 0.5, -12)
			inputBox.BackgroundColor3 = Theme.InputBg
			inputBox.Text = ""
			inputBox.PlaceholderText = placeholder or "Type here..."
			inputBox.PlaceholderColor3 = Theme.DimText
			inputBox.TextColor3 = Theme.Text
			inputBox.Font = Enum.Font.Gotham
			inputBox.TextSize = 12
			inputBox.ClearTextOnFocus = false
			inputBox.Parent = frame
			ApplyCorner(inputBox, 6)
			ApplyPadding(inputBox, 0, 0, 8, 8)

			local inputStroke = ApplyStroke(inputBox, Theme.Outline)

			connections:Track(inputBox.Focused:Connect(function()
				Tween(inputStroke, 0.2, { Color = Theme.Accent })
			end))

			connections:Track(inputBox.FocusLost:Connect(function(enterPressed)
				Tween(inputStroke, 0.2, { Color = Theme.Outline })
				if callback then task.spawn(callback, inputBox.Text, enterPressed) end
			end))

			function obj:Set(t) inputBox.Text = t end
			function obj:Get() return inputBox.Text end
			function obj:SetPlaceholder(t) inputBox.PlaceholderText = t end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		-- ======================================
		-- ⌨️ CreateKeybind — ตั้งค่าปุ่มลัด
		-- ======================================
		function Tab:CreateKeybind(text, default, callback)
			local obj = {}
			local currentKey = default or Enum.KeyCode.Unknown
			local listening = false
			local targetParent = (self and self._content) or content

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 36)
			frame.BackgroundColor3 = Theme.ElementBg
			frame.Parent = targetParent

			local isSection = self and self._isSection
			
			if isSection then
				frame.BackgroundTransparency = 1
				if self._itemCount and self._itemCount > 0 then
					local sep = Instance.new("Frame")
					sep.Size = UDim2.new(1, -24, 0, 1)
					sep.Position = UDim2.new(0, 12, 0, 0)
					sep.BackgroundColor3 = Theme.Outline
					sep.BorderSizePixel = 0
					sep.BackgroundTransparency = 0.5
					sep.Parent = frame
				end
				if self._itemCount then self._itemCount = self._itemCount + 1 end
			else
				ApplyCorner(frame, 8)
				ApplyStroke(frame, Theme.Outline)
			end

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -95, 1, 0)
			lbl.Position = UDim2.new(0, 12, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = text
			lbl.TextColor3 = Theme.Text
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = frame

			local keyBtn = Instance.new("TextButton")
			keyBtn.Size = UDim2.new(0, 75, 0, 24)
			keyBtn.Position = UDim2.new(1, -85, 0.5, -12)
			keyBtn.BackgroundColor3 = Theme.InputBg
			keyBtn.Text = currentKey.Name
			keyBtn.TextColor3 = Theme.Accent
			keyBtn.Font = Enum.Font.GothamBold
			keyBtn.TextSize = 12
			keyBtn.AutoButtonColor = false
			keyBtn.Parent = frame
			ApplyCorner(keyBtn, 6)
			local kbStroke = ApplyStroke(keyBtn, Theme.Outline)

			connections:Track(keyBtn.MouseButton1Click:Connect(function()
				if listening then return end
				listening = true
				keyBtn.Text = "..."
				Tween(kbStroke, 0.2, { Color = Theme.Accent })
			end))

			connections:Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if listening then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode == Enum.KeyCode.Escape then
							-- ยกเลิก
							keyBtn.Text = currentKey.Name
						else
							currentKey = input.KeyCode
							keyBtn.Text = currentKey.Name
						end
						listening = false
						Tween(kbStroke, 0.2, { Color = Theme.Outline })
					end
				else
					-- กดปุ่มลัดที่ตั้งไว้ → เรียก callback
					if not gameProcessed
						and input.UserInputType == Enum.UserInputType.Keyboard
						and input.KeyCode == currentKey then
						if callback then task.spawn(callback, currentKey) end
					end
				end
			end))

			function obj:Set(key) currentKey = key; keyBtn.Text = key.Name end
			function obj:Get() return currentKey end
			function obj:SetText(t) lbl.Text = t end
			function obj:SetVisible(v) frame.Visible = v end
			function obj:Destroy() frame:Destroy() end
			return obj
		end

		return Tab
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
		local tw = Tween(MainFrame, 0.3, {
			Size = UDim2.new(0, 0, 0, 0),
		}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tw.Completed:Once(function()
			connections:DisconnectAll()
			_activeTracker = nil
			ScreenGui:Destroy()
		end)
	end))

	-- ==========================================
	-- ปุ่มลัด Toggle UI (ค่าเริ่มต้น: RightShift)
	-- ==========================================
	connections:Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == toggleKey then
			isVisible = not isVisible
			MainFrame.Visible = isVisible
		end
	end))

	-- ==========================================
	-- 🔧 Public Window Methods
	-- ==========================================

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
		connections:DisconnectAll()
		_activeTracker = nil
		if ScreenGui then ScreenGui:Destroy() end
	end

	return Window
end

-- โหลด DiqIcons module
-- @param iconsModule table โมดูล DiqIcons ที่โหลดมาแล้ว
function Diq:LoadIcons(iconsModule)
	DiqIcons = iconsModule
end

return Diq
