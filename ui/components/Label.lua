local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, options)
	local Theme = ctx.Theme
	local connections = CreateConnectionTracker(ctx.Scope)
	local obj = {}
	local targetParent = ctx.Parent

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
	lbl.Font = Tokens.Font.Strong
	lbl.TextSize = Tokens.Text.Small -- ขยาย Font ให้เด่นขึ้นนิดหน่อย
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = frame
	if options and options.Wrap then
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		lbl.Size = UDim2.new(1, -10, 0, 24)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.TextWrapped = true
		lbl.TextTruncate = Enum.TextTruncate.None
	end

	function obj:SetText(t) lbl.Text = t end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy() frame:Destroy() end
	ctx.Register(obj, connections, false)
	return obj
end
