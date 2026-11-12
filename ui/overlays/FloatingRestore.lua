local import = ...
local BrandMark = import("blocks/BrandMark")
return function(ctx)
	local scope, viewport = ctx.Scope, ctx.Viewport
	local button = Instance.new("TextButton")
	button.Name = "RestoreWindow"
	button.Size = UDim2.fromOffset(56, 56)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(1, -48, 1, -48)
	button.BackgroundColor3, button.BorderSizePixel = ctx.Theme.Sidebar, 0
	button.AutoButtonColor, button.Text, button.Visible = false, "", false
	button.ZIndex = 10
	button.Parent = viewport
	ctx.Primitives.ApplyCorner(button, 18)
	ctx.Primitives.ApplyStroke(button, ctx.Theme.Outline, 1)
	local mark = BrandMark(button, ctx.Primitives, button, scope)
	mark.Position = UDim2.fromOffset(12, 12)
	local pointer, start, origin, moved
	local suppressed = false
	local dock = { Button = button }
	function dock:Cancel()
		if pointer then suppressed = true end
		pointer = nil
	end
	local function clamp(position)
		local size = viewport.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return position end
		local insetX, insetY = math.min(36, size.X / 2), math.min(36, size.Y / 2)
		local x = math.clamp(position.X.Scale * size.X + position.X.Offset, insetX, size.X - insetX)
		local y = math.clamp(position.Y.Scale * size.Y + position.Y.Offset, insetY, size.Y - insetY)
		return UDim2.fromScale(x / size.X, y / size.Y)
	end
	scope:Track(button.InputBegan:Connect(function(input)
		if pointer or not ctx.CanActivate() then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		suppressed = false
		if not ctx.CanDrag() then return end
		pointer, start, origin = input, input.Position, button.Position
		moved, suppressed = false, false
	end))
	scope:Track(ctx.Input.Connect("InputChanged", function(input)
		if not pointer then return end
		if not ctx.CanDrag() then dock:Cancel(); return end
		if pointer.UserInputType == Enum.UserInputType.Touch then
			if input ~= pointer then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - start
		if delta.X * delta.X + delta.Y * delta.Y > 36 then moved, suppressed = true, true end
		if moved then
			button.Position = clamp(UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y))
		end
	end))
	scope:Track(ctx.Input.Connect("InputEnded", function(input)
		if pointer and (input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then pointer = nil end
	end))
	scope:Track(button.Activated:Connect(function(input)
		if not ctx.CanActivate() then return end
		local nonPointer = input and input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch
		if suppressed and not nonPointer then return end
		ctx.Restore()
	end))
	scope:Track(ctx.Input.Connect("WindowFocusReleased", function() dock:Cancel() end))
	scope:Track(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		dock:Cancel(); button.Position = clamp(button.Position)
	end))
	scope:Track(button.MouseEnter:Connect(function() ctx.Primitives.Tween(button, 0.15, { BackgroundColor3 = ctx.Theme.HoverBg }) end))
	scope:Track(button.MouseLeave:Connect(function() ctx.Primitives.Tween(button, 0.15, { BackgroundColor3 = ctx.Theme.Sidebar }) end))
	scope:Delay(0, function() button.Position = clamp(button.Position) end)
	scope:Track(function() dock:Cancel(); button:Destroy() end)
	return dock
end
