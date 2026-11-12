local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, playerName, executorName, userId)
	local Theme = ctx.Theme
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplyStroke = ctx.Primitives.ApplyStroke
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj = {}
	local targetParent = ctx.Parent
	local sessionStart = os.clock()

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 92)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.Parent = targetParent
	ApplyCorner(frame, Tokens.Radius.Control)
	ApplyStroke(frame, Theme.Outline)

	-- รูป Avatar (วงกลม)
	local avatar = Instance.new("ImageLabel")
	avatar.Size = UDim2.new(0, 56, 0, 56)
	avatar.Position = UDim2.new(0, 12, 0.5, -28)
	avatar.BackgroundColor3 = Theme.HoverBg
	avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
	avatar.Parent = frame
	ApplyCorner(avatar, 28)

	-- ชื่อผู้เล่น
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -85, 0, 18)
	nameLbl.Position = UDim2.new(0, 80, 0, 10)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = playerName
	nameLbl.TextColor3 = Theme.Text
	nameLbl.Font = Tokens.Font.Strong
	nameLbl.TextSize = 14
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = frame

	-- ชื่อ Executor
	local execLbl = Instance.new("TextLabel")
	execLbl.Size = UDim2.new(1, -85, 0, 16)
	execLbl.Position = UDim2.new(0, 80, 0, 30)
	execLbl.BackgroundTransparency = 1
	execLbl.Text = "Using: " .. (executorName or "Unknown")
	execLbl.TextColor3 = Theme.Accent
	execLbl.Font = Tokens.Font.Label
	execLbl.TextSize = Tokens.Text.Small
	execLbl.TextXAlignment = Enum.TextXAlignment.Left
	execLbl.Parent = frame

	-- Map Name
	local mapLbl = Instance.new("TextLabel")
	mapLbl.Size = UDim2.new(1, -85, 0, 16)
	mapLbl.Position = UDim2.new(0, 80, 0, 48)
	mapLbl.BackgroundTransparency = 1
	mapLbl.Text = "Map: Loading..."
	mapLbl.TextColor3 = Theme.SubText
	mapLbl.Font = Tokens.Font.Body
	mapLbl.TextSize = Tokens.Text.Caption
	mapLbl.TextXAlignment = Enum.TextXAlignment.Left
	mapLbl.Parent = frame

	-- Play Time
	local timeLbl = Instance.new("TextLabel")
	timeLbl.Size = UDim2.new(1, -85, 0, 16)
	timeLbl.Position = UDim2.new(0, 80, 0, 64)
	timeLbl.BackgroundTransparency = 1
	timeLbl.Text = "Session: 00:00:00"
	timeLbl.TextColor3 = Theme.SubText
	timeLbl.Font = Tokens.Font.Body
	timeLbl.TextSize = Tokens.Text.Caption
	timeLbl.TextXAlignment = Enum.TextXAlignment.Left
	timeLbl.Parent = frame
	for _, label in { nameLbl, execLbl, mapLbl, timeLbl } do label.TextTruncate = Enum.TextTruncate.AtEnd end

	-- ดึงชื่อ Map แบบ Asynchronous
	connections:Spawn(function()
		local success, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		if not connections.Alive then return end
		if success and info and info.Name then
			mapLbl.Text = "Map: " .. info.Name
		else
			mapLbl.Text = "Map: Unknown"
		end
	end)

	-- อัปเดตเวลา Session Time (เดินตลอดเวลา)
	connections:Spawn(function()
		while task.wait(1) do
			if not frame.Parent then break end -- กัน Memory Leak ถ้า UI โดนลบ
			local elapsed = os.clock() - sessionStart
			local hrs = math.floor(elapsed / 3600)
			local mins = math.floor((elapsed % 3600) / 60)
			local secs = math.floor(elapsed % 60)
			timeLbl.Text = string.format("Session: %02d:%02d:%02d", hrs, mins, secs)
		end
	end)

	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end
	ctx.Register(obj, connections, false)
	return obj
end
