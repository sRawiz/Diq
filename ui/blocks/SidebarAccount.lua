local import = ...
local Tokens = import("core/Tokens")
local Lifecycle = import("core/Lifecycle")
return function(ctx, parent, player)
	local scope = Lifecycle.new(ctx.Scope)
	local frame = Instance.new("Frame")
	frame.Name = "SidebarAccount"
	frame.BackgroundColor3, frame.BorderSizePixel = ctx.Theme.ElementBg, 0
	frame.Parent = parent
	ctx.Primitives.ApplyCorner(frame, 14)
	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.BackgroundColor3, portrait.BorderSizePixel = ctx.Theme.InputBg, 0
	portrait.Parent = frame
	ctx.Primitives.ApplyCorner(portrait, 18)
	local fallback = Instance.new("TextLabel")
	fallback.Name = "AvatarFallback"
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundTransparency = 1
	fallback.Font, fallback.TextSize, fallback.TextColor3 = Tokens.Font.Strong, 14, ctx.Theme.Text
	fallback.Parent = portrait
	local image = Instance.new("ImageLabel")
	image.Name = "Avatar"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency, image.Image = 1, ""
	image.Parent = portrait
	ctx.Primitives.ApplyCorner(image, 18)
	local function label(name, y, color, font, size)
		local item = Instance.new("TextLabel")
		item.Name, item.Position, item.Size = name, UDim2.fromOffset(54, y), UDim2.new(1, -62, 0, 18)
		item.BackgroundTransparency = 1
		item.TextColor3, item.Font, item.TextSize = color, font, size
		item.TextXAlignment, item.TextTruncate = Enum.TextXAlignment.Left, Enum.TextTruncate.AtEnd
		item.Parent = frame
		return item
	end
	local display = label("DisplayName", 9, ctx.Theme.Text, Tokens.Font.Label, 12)
	local username = label("Username", 29, ctx.Theme.SubText, Tokens.Font.Body, 10)
	local function refresh()
		display.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
		username.Text = "@" .. player.Name
		-- Username is ASCII and gives a valid initial even for Unicode display names.
		fallback.Text = player.Name:sub(1, 1):upper()
	end
	refresh()
	scope:Track(player:GetPropertyChangedSignal("DisplayName"):Connect(refresh))
	scope:Track(image:GetPropertyChangedSignal("IsLoaded"):Connect(function() fallback.Visible = not image.IsLoaded end))
	scope:Spawn(function()
		for attempt = 1, 3 do
			local ok, url, ready = pcall(function()
				return game:GetService("Players"):GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if not scope.Alive then return end
			if ok and ready and type(url) == "string" and url ~= "" then image.Image = url; return end
			if not ok then return end -- Keep initials if the runtime cannot retrieve the thumbnail.
			if attempt < 3 then task.wait(attempt) end
		end
	end)
	local account = {}
	function account:SetCompact(compact)
		frame.Size = compact and UDim2.fromOffset(40, 40) or UDim2.new(1, -16, 0, 56)
		frame.Position = UDim2.new(0, 8, 1, compact and -56 or -68)
		portrait.Size = UDim2.fromOffset(compact and 32 or 36, compact and 32 or 36)
		portrait.Position = UDim2.fromOffset(compact and 4 or 10, compact and 4 or 10)
		display.Visible, username.Visible = not compact, not compact
	end
	account:SetCompact(false)
	scope:Track(function() frame:Destroy() end)
	return account
end
