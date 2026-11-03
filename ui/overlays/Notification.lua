local import = ...
local Tokens = import("core/Tokens")
local Lifecycle = import("core/Lifecycle")
return function(Theme, primitives)
	local notifications = {}
	local notificationTasks = Lifecycle.new()
	local Tween, ApplyCorner, ApplyStroke = primitives.Tween, primitives.ApplyCorner, primitives.ApplyStroke
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
	function notifications:Notify(title, message, duration, notifType)

		if not NotificationHolder or not NotificationHolder.Parent then return end

		duration = duration or 3
		notifType = notifType or "info"

		local accentColor = Theme.Accent
		if notifType == "success" then accentColor = Theme.Success
		elseif notifType == "warning" then accentColor = Theme.Warning
		elseif notifType == "error" then accentColor = Theme.Error end

		-- จำกัดจำนวนแจ้งเตือน (ให้แสดงแค่อันเดียว ลบของเก่าทิ้งทั้งหมด)
		for _, child in NotificationHolder:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

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
		titleLbl.Font = Tokens.Font.Strong
		titleLbl.TextSize = Tokens.Text.Body
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = notif

		-- เนื้อหา
		local msgLbl = Instance.new("TextLabel")
		msgLbl.Size = UDim2.new(1, -25, 0, 30)
		msgLbl.Position = UDim2.new(0, 18, 0, 30)
		msgLbl.BackgroundTransparency = 1
		msgLbl.Text = message or ""
		msgLbl.TextColor3 = Theme.SubText
		msgLbl.Font = Tokens.Font.Body
		msgLbl.TextSize = Tokens.Text.Small
		msgLbl.TextXAlignment = Enum.TextXAlignment.Left
		msgLbl.TextYAlignment = Enum.TextYAlignment.Top
		msgLbl.TextWrapped = true
		msgLbl.Parent = notif

		-- Slide in
		Tween(notif, 0.35, { BackgroundTransparency = 0 })

		-- หายไปอัตโนมัติ
		notificationTasks:Delay(duration, function()
			if notif and notif.Parent then
				local tw = Tween(notif, 0.3, {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
				})
				notificationTasks:Once(tw.Completed, function()
					if notif then notif:Destroy() end
				end)
			end
		end)
	end
	function notifications:Mount(gui)
		self:Destroy()
		notificationTasks = Lifecycle.new()
		EnsureNotificationHolder(gui)
	end
	function notifications:Destroy()
		notificationTasks:DisconnectAll()
		if NotificationHolder then NotificationHolder:Destroy(); NotificationHolder = nil end
	end
	return notifications
end
