local import = ...
local Lifecycle = import("core/Lifecycle")

-- A responsive action grid. Columns collapse before card text becomes cramped.
return function(ctx, options)
	options = options or {}
	local scope = Lifecycle.new(ctx.Scope)
	local frame = Instance.new("Frame")
	frame.Name = "ActionGroup"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.Parent = ctx.Parent
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.Parent = frame
	local height = options.Cards and 124 or 38
	local function resize()
		local width = frame.AbsoluteSize.X / (ctx.GetScale and ctx.GetScale() or 1)
		local columns = math.clamp(math.floor((width + 10) / ((options.MinWidth or 210) + 10)), 1, options.Columns or 2)
		grid.FillDirectionMaxCells = columns
		grid.CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, height)
	end
	scope:Track(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	scope:Track(grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		frame.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y / (ctx.GetScale and ctx.GetScale() or 1))
	end))
	resize()
	local group = { _content = frame, _tracker = scope, _actionGroup = { Cards = options.Cards == true } }
	function group:Destroy() scope:DisconnectAll() end
	scope:Track(function() frame:Destroy() end)
	ctx.BindContainer(group)
	return group
end
