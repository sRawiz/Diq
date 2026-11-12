-- Native vector-style D/Q monogram: no image upload or executor asset loader.
return function(parent, primitives)
	local mark = Instance.new("Frame")
	mark.Name = "DiqMark"
	mark.Size = UDim2.fromOffset(32, 32)
	mark.BackgroundTransparency = 1
	mark.Parent = parent
	local ink = Color3.fromRGB(240, 235, 224)
	local accent = Color3.fromRGB(193, 173, 139)
	local arc = Instance.new("Frame")
	arc.Name = "Arc"
	arc.Position, arc.Size = UDim2.fromOffset(16, 2), UDim2.fromOffset(12, 28)
	arc.BackgroundTransparency, arc.ClipsDescendants = 1, true
	arc.Parent = mark
	local loop = Instance.new("Frame")
	loop.Name = "Loop"
	loop.Position, loop.Size = UDim2.fromOffset(-10, 2), UDim2.fromOffset(20, 24)
	loop.BackgroundTransparency = 1
	loop.Parent = arc
	primitives.ApplyCorner(loop, 10)
	primitives.ApplyStroke(loop, ink, 2.5)
	local spine = Instance.new("Frame")
	spine.Name = "Spine"
	spine.Position, spine.Size = UDim2.fromOffset(4.75, 2.75), UDim2.fromOffset(2.5, 26.5)
	spine.BackgroundColor3, spine.BorderSizePixel = ink, 0
	spine.Parent = mark
	primitives.ApplyCorner(spine, 1.25)
	for _, y in { 2.75, 26.75 } do
		local bar = Instance.new("Frame")
		bar.Position, bar.Size = UDim2.fromOffset(6, y), UDim2.fromOffset(10, 2.5)
		bar.BackgroundColor3, bar.BorderSizePixel = ink, 0
		bar.Parent = mark
	end
	local tail = Instance.new("Frame")
	tail.Name = "Signature"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position, tail.Size = UDim2.fromOffset(24, 26), UDim2.fromOffset(10, 2.5)
	tail.Rotation = 45
	tail.BackgroundColor3, tail.BorderSizePixel = accent, 0
	tail.Parent = mark
	primitives.ApplyCorner(tail, 1.25)
	return mark
end
