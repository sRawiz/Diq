local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, title)
	local Theme = ctx.Theme
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplyStroke = ctx.Primitives.ApplyStroke
	local connections = CreateConnectionTracker(ctx.Scope)
	local Section = {}
	local targetParent = ctx.Parent

	local sectionFrame = Instance.new("Frame")
	sectionFrame.Size = UDim2.new(1, 0, 0, 0)
	sectionFrame.BackgroundColor3 = Theme.ElementBg
	sectionFrame.Name = "SettingsSection"
	sectionFrame.BorderSizePixel = 0
	sectionFrame.ClipsDescendants = false
	sectionFrame.Parent = targetParent
	ApplyCorner(sectionFrame, 14)
	ApplyStroke(sectionFrame, Theme.Outline)

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, 0)
	sectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.Parent = sectionFrame
	ctx.Primitives.ApplyPadding(sectionFrame, 8, 10, 8, 8)

	local titleContainer = Instance.new("Frame")
	titleContainer.Size = UDim2.new(1, 0, 0, 38)
	titleContainer.BackgroundTransparency = 1
	titleContainer.BorderSizePixel = 0
	titleContainer.Parent = sectionFrame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -24, 1, 0)
	titleLbl.Position = UDim2.new(0, 12, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = Theme.Text
	titleLbl.Font = Tokens.Font.Strong
	titleLbl.TextSize = Tokens.Text.Small
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = titleContainer

	connections:Track(sectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		sectionFrame.Size = UDim2.new(1, 0, 0, sectionLayout.AbsoluteContentSize.Y + 18)
	end))

	Section._tracker = connections
	connections:Track(function() sectionFrame:Destroy() end)
	Section.Destroy = function() connections:DisconnectAll(); sectionFrame:Destroy() end
	Section._content = sectionFrame
	Section._isSection = true
	Section._itemCount = 0
	ctx.BindContainer(Section)
	return Section
end
