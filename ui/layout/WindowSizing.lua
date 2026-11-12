-- Pixel geometry in ScreenGui's safe area, independent of minimize's UIScale.
return function(ctx)
	local frame, viewport, scope = ctx.Frame, ctx.Viewport, ctx.Scope
	local sizing = { Maximized = false }
	local normal, gesture
	local handles = {}
	local function limits()
		local size = viewport.AbsoluteSize
		local margin = math.min(8, size.X / 10, size.Y / 10)
		return size.X, size.Y, margin, math.max(1, size.X - margin * 2), math.max(1, size.Y - margin * 2)
	end
	local function dimensions(size)
		local width, height = limits()
		return size.X.Scale * width + size.X.Offset, size.Y.Scale * height + size.Y.Offset
	end
	function sizing:Cancel() gesture = nil end
	function sizing:IsResizing() return gesture ~= nil end
	function sizing:Constrain(position)
		local vw, vh, margin = limits()
		local w, h = dimensions(frame.Size)
		local x, y = position.X.Scale * vw + position.X.Offset, position.Y.Scale * vh + position.Y.Offset
		local cx = math.clamp(x, margin + w / 2, math.max(margin + w / 2, vw - margin - w / 2))
		local cy = math.clamp(y, margin + h / 2, math.max(margin + h / 2, vh - margin - h / 2))
		if cx == x and cy == y then return position end
		return UDim2.new(position.X.Scale, position.X.Offset + cx - x, position.Y.Scale, position.Y.Offset + cy - y)
	end
	function sizing:Fit(initial)
		local vw, vh, _, maxW, maxH = limits()
		if vw <= 0 or vh <= 0 then return end
		self:Cancel(); ctx.CancelDrag()
		if self.Maximized then
			frame.Size = UDim2.fromOffset(maxW, maxH)
			ctx.SetPosition(UDim2.fromScale(0.5, 0.5))
		else
			local w, h = dimensions(frame.Size)
			if initial and ctx.DefaultSize then w, h = math.min(w, 920), math.min(h, 660) end
			local width = math.clamp(w, math.min(420, maxW), maxW)
			local height = math.clamp(h, math.min(300, maxH), maxH)
			local currentW, currentH = dimensions(frame.Size)
			if width ~= currentW or height ~= currentH then frame.Size = UDim2.fromOffset(width, height) end
			ctx.SetPosition(self:Constrain(ctx.GetPosition()))
		end
	end
	function sizing:SetMaximized(value)
		if not scope.Alive then return end
		value = value == true
		if value == self.Maximized then return end
		self:Cancel(); ctx.CancelDrag()
		if value then
			normal = { Size = frame.Size, Position = ctx.GetPosition() }
		elseif normal then
			frame.Size = normal.Size
			ctx.SetPosition(normal.Position)
		end
		self.Maximized = value
		for _, handle in handles do handle.Visible = not value end
		self:Fit()
		ctx.OnMaximized(value)
	end
	local edges = {
		{ "Left", -1, 0, UDim2.new(0, 0, 0, 12), UDim2.new(0, 7, 1, -30) },
		{ "Right", 1, 0, UDim2.new(1, -7, 0, 12), UDim2.new(0, 7, 1, -30) },
		{ "Top", 0, -1, UDim2.new(0, 12, 0, 0), UDim2.new(1, -24, 0, 7) },
		{ "Bottom", 0, 1, UDim2.new(0, 18, 1, -7), UDim2.new(1, -36, 0, 7) },
		{ "TopLeft", -1, -1, UDim2.fromOffset(0, 0), UDim2.fromOffset(12, 12) },
		{ "TopRight", 1, -1, UDim2.new(1, -12, 0, 0), UDim2.fromOffset(12, 12) },
		{ "BottomLeft", -1, 1, UDim2.new(0, 0, 1, -18), UDim2.fromOffset(18, 18) },
		{ "BottomRight", 1, 1, UDim2.new(1, -18, 1, -18), UDim2.fromOffset(18, 18) },
	}
	for _, spec in edges do
		local handle = Instance.new("TextButton")
		handle.Name = "Resize" .. spec[1]
		handle.Position, handle.Size = spec[4], spec[5]
		handle.BackgroundTransparency, handle.Text, handle.AutoButtonColor = 1, "", false
		handle.ZIndex = 30
		handle.Parent = frame
		table.insert(handles, handle)
		if spec[1] == "BottomRight" then
			handle.Text, handle.TextSize, handle.TextColor3 = "◢", 12, ctx.Theme.SubText
		end
		scope:Track(handle.InputBegan:Connect(function(input)
			if not ctx.CanManipulate() or sizing.Maximized or gesture then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			ctx.CancelDrag(); sizing:Fit()
			local vw, vh = limits()
			local w, h = dimensions(frame.Size)
			local pos = ctx.GetPosition()
			local x, y = pos.X.Scale * vw + pos.X.Offset, pos.Y.Scale * vh + pos.Y.Offset
			gesture = { Input = input, Start = input.Position, X = spec[2], Y = spec[3],
				Left = x - w / 2, Top = y - h / 2, Right = x + w / 2, Bottom = y + h / 2 }
		end))
	end
	scope:Track(ctx.Input.Connect("InputChanged", function(input)
		if not gesture then return end
		if not ctx.CanManipulate() then sizing:Cancel(); return end
		if gesture.Input.UserInputType == Enum.UserInputType.Touch then
			if input ~= gesture.Input then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - gesture.Start
		local vw, vh, margin, maxW, maxH = limits()
		local minW, minH = math.min(420, maxW), math.min(300, maxH)
		local l, t, r, b = gesture.Left, gesture.Top, gesture.Right, gesture.Bottom
		if gesture.X < 0 then l = math.clamp(l + delta.X, margin, math.max(margin, r - minW))
		elseif gesture.X > 0 then r = math.clamp(r + delta.X, l + minW, math.max(l + minW, vw - margin)) end
		if gesture.Y < 0 then t = math.clamp(t + delta.Y, margin, math.max(margin, b - minH))
		elseif gesture.Y > 0 then b = math.clamp(b + delta.Y, t + minH, math.max(t + minH, vh - margin)) end
		frame.Size = UDim2.fromOffset(r - l, b - t)
		ctx.SetPosition(UDim2.fromOffset((l + r) / 2, (t + b) / 2))
	end))
	scope:Track(ctx.Input.Connect("InputEnded", function(input)
		if gesture and (input == gesture.Input or (gesture.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then sizing:Cancel() end
	end))
	scope:Track(ctx.Input.Connect("WindowFocusReleased", function() sizing:Cancel(); ctx.CancelDrag() end))
	scope:Track(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() sizing:Fit() end))
	scope:Track(function() sizing:Cancel() end)
	scope:Delay(0, function() sizing:Fit(true) end)
	return sizing
end
