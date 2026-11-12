-- Native vector-style D/Q monogram: no image upload or executor asset loader.
return function(parent, primitives, surface, scope)
	local mark = Instance.new("Frame")
	mark.Name = "DiqMark"
	mark.Size = UDim2.fromOffset(32, 32)
	mark.BackgroundTransparency = 1
	mark.Parent = parent
	local ink = Color3.fromRGB(240, 235, 224)
	local accent = Color3.fromRGB(193, 173, 139)
	-- Overlapping filled silhouettes avoid clipped UIStroke edges and seams
	-- between fractional-width bars. Both cutouts follow the actual surface.
	local function silhouette(name, x, y, width, height, color, leftRadius, layer)
		local body = Instance.new("Frame")
		body.Name = name
		body.Position, body.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
		body.BackgroundColor3, body.BorderSizePixel, body.ZIndex = color, 0, layer
		body.Parent = mark
		primitives.ApplyCorner(body, width / 2)
		local left = Instance.new("Frame")
		left.Name = "StraightEdge"
		left.Size = UDim2.fromScale(0.5, 1)
		left.BackgroundColor3, left.BorderSizePixel, left.ZIndex = color, 0, layer
		left.Parent = body
		if leftRadius then primitives.ApplyCorner(left, leftRadius) end
		return body, left
	end
	surface = surface or parent
	silhouette("Outline", 4.75, 2.75, 22.5, 26.5, ink, 1.25, 1)
	local cutout, cutoutLeft = silhouette("Cutout", 7.25, 5.25, 17.5, 21.5, surface.BackgroundColor3, nil, 2)
	if scope then
		scope:Track(surface:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			cutout.BackgroundColor3, cutoutLeft.BackgroundColor3 = surface.BackgroundColor3, surface.BackgroundColor3
		end))
	end
	local tail = Instance.new("Frame")
	tail.Name = "Signature"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position, tail.Size = UDim2.fromOffset(24, 26), UDim2.fromOffset(10, 2.5)
	tail.Rotation = 45
	tail.BackgroundColor3, tail.BorderSizePixel = accent, 0
	tail.ZIndex = 3
	tail.Parent = mark
	primitives.ApplyCorner(tail, 1.25)
	return mark
end
