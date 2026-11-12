local import = ...
local Tokens = import("core/Tokens")
local Lifecycle = import("core/Lifecycle")

return function(ctx, callback)
	local scope = Lifecycle.new(ctx.Scope)
	local Theme = ctx.Theme
	local obj, rows, entries = {}, {}, {}
	local selected
	local frame = Instance.new("Frame")
	frame.Name = "PlayerDirectory"
	frame.Size = UDim2.new(1, 0, 0, 254)
	frame.BackgroundTransparency = 1
	frame.Parent = ctx.Parent
	local function label(parent, name, size, position, font, color)
		local item = Instance.new("TextLabel")
		item.Name, item.Size, item.Position = name, size, position
		item.BackgroundTransparency = 1
		item.Font, item.TextColor3 = font, color
		item.TextSize = Tokens.Text.Small
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextTruncate = Enum.TextTruncate.AtEnd
		item.Parent = parent
		return item
	end
	local search = Instance.new("TextBox")
	search.Name = "PlayerSearch"
	search.Size = UDim2.new(1, 0, 0, 38)
	search.BackgroundColor3 = Theme.InputBg
	search.BorderSizePixel = 0
	search.Text, search.PlaceholderText = "", "Search display name or @username..."
	search.TextColor3, search.PlaceholderColor3 = Theme.Text, Theme.DimText
	search.Font, search.TextSize = Tokens.Font.Body, Tokens.Text.Small
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.ClearTextOnFocus = false
	search.Parent = frame
	ctx.Primitives.ApplyCorner(search, 10)
	ctx.Primitives.ApplyPadding(search, 0, 0, 12, 12)
	local count = label(frame, "PlayerCount", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 42), Tokens.Font.Label, Theme.SubText)
	local list = Instance.new("ScrollingFrame")
	list.Name = "PlayerRows"
	list.Size, list.Position = UDim2.new(1, 0, 0, 180), UDim2.fromOffset(0, 74)
	list.BackgroundTransparency, list.BorderSizePixel = 1, 0
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = Theme.Outline
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.CanvasPosition = Vector2.new(0, 0)
	list.Parent = frame
	local empty = label(list, "EmptyPlayers", UDim2.new(1, -12, 0, 60), UDim2.fromOffset(6, 0), Tokens.Font.Body, Theme.SubText)
	empty.TextWrapped = true
	empty.TextTruncate = Enum.TextTruncate.None
	local function paint(row)
		row.Button.BackgroundTransparency = row.Id == selected and 0 or (row.Hovered and 0.5 or 1)
		row.Button.BackgroundColor3 = row.Id == selected and Theme.ActiveTab or Theme.HoverBg
	end
	local function render()
		local query = search.Text:lower():match("^%s*(.-)%s*$"):gsub("^@", "")
		local visible = 0
		for _, entry in entries do
			local row = rows[entry.UserId]
			local matches = query == "" or entry.Name:lower():find(query, 1, true) or entry.DisplayName:lower():find(query, 1, true)
			row.Button.Visible = matches ~= nil and matches ~= false
			if row.Button.Visible then
				row.Button.Position = UDim2.fromOffset(0, visible * 60)
				visible += 1
			end
			paint(row)
		end
		count.Text = tostring(visible) .. " / " .. tostring(#entries) .. " players · select a row"
		empty.Visible = visible == 0
		empty.Text = #entries == 0 and "No other players in this server." or "No players match your search."
		list.CanvasSize = UDim2.fromOffset(0, visible * 60)
		local scale = ctx.GetScale and ctx.GetScale() or 1
		local maxY = math.max(0, visible * 60 - list.AbsoluteSize.Y / scale)
		if list.CanvasPosition.Y > maxY then list.CanvasPosition = Vector2.new(0, maxY) end
	end
	function obj:SetPlayers(values, selectedId)
		if not scope.Alive then return end
		entries, selected = values, selectedId
		local seen = {}
		for _, entry in entries do
			local id = entry.UserId
			seen[id] = true
			local row = rows[id]
			if not row then
				local rowScope = Lifecycle.new(scope)
				local button = Instance.new("TextButton")
				button.Name = "Player_" .. tostring(id)
				button.Size = UDim2.new(1, -8, 0, 56)
				button.BorderSizePixel, button.Text, button.AutoButtonColor = 0, "", false
				button.Parent = list
				ctx.Primitives.ApplyCorner(button, 10)
				row = { Id = id, Button = button, Scope = rowScope }
				row.Name = label(button, "DisplayName", UDim2.new(0.7, -16, 0, 24), UDim2.fromOffset(12, 4), Tokens.Font.Strong, Theme.Text)
				row.Meta = label(button, "PlayerMeta", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 29), Tokens.Font.Body, Theme.SubText)
				row.Distance = label(button, "Distance", UDim2.new(0.3, -12, 0, 24), UDim2.new(0.7, 0, 0, 4), Tokens.Font.Label, Theme.SubText)
				row.Distance.TextXAlignment = Enum.TextXAlignment.Right
				rowScope:Track(button.Activated:Connect(function()
					selected = id; render()
					if callback then scope:Invoke(callback, id) end
				end))
				rowScope:Track(button.MouseEnter:Connect(function() row.Hovered = true; paint(row) end))
				rowScope:Track(button.MouseLeave:Connect(function() row.Hovered = false; paint(row) end))
				rowScope:Track(function() button:Destroy() end)
				rows[id] = row
			end
			row.Name.Text = entry.DisplayName .. (entry.Watching and " · Watching" or "")
			row.Meta.Text = "@" .. entry.Name .. " · " .. entry.Team .. (not entry.Available and " · Unavailable" or "")
			row.Distance.Text = entry.Distance and string.format("%.0f studs", entry.Distance) or "—"
		end
		for id, row in rows do
			if not seen[id] then row.Scope:DisconnectAll(); rows[id] = nil end
		end
		render()
	end
	scope:Track(search:GetPropertyChangedSignal("Text"):Connect(function()
		list.CanvasPosition = Vector2.new(0, 0)
		render()
	end))
	function obj:Destroy() frame:Destroy() end
	ctx.Register(obj, scope, false)
	obj:SetPlayers({}, nil)
	return obj
end
