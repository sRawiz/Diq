-- INSERT_MOCKS
-- INSERT_UI_MODULES
local Lifecycle = importUI("core/Lifecycle")
local baseline = liveConnections()
local theme, setTheme = importUI("core/Theme")()
local secondTheme = importUI("core/Theme")()
setTheme({ Accent = Color3.fromRGB(10, 20, 30), UnknownToken = true })
check(secondTheme.Accent.R ~= theme.Accent.R and theme.UnknownToken == nil, "Themes are instance-local and preserve the accepted-token contract")
local scope, elements = Lifecycle.new(), {}
local parent = Instance.new("Frame")
local primitives = importUI("core/Primitives")(theme, function() return nil end)
local input = importUI("core/Input")()
local ctx = {
	Parent = parent, Scope = scope, Theme = theme, Primitives = primitives, Input = input, Capture = {},
	BindSliderDrag = input.CreateDrag(scope),
	Register = function(obj, owner, resettable) Lifecycle.Register(elements, obj, owner, resettable) end,
}
local controlsBaseline = liveConnections()
local label = importUI("components/Label")(ctx, "Independent component")
label:SetText("Updated")
label:Destroy(); label:Destroy()
check(liveConnections() == controlsBaseline, "A component mounts and unmounts without a Window or Tab")
local clicked = 0
local button = importUI("components/Button")(ctx, "Cancel pending click", function() clicked += 1 end)
local buttonFrame = parent:GetChildren()[1]
buttonFrame.MouseButton1Click:Fire()
button:Destroy(); advance(1)
check(clicked == 0 and liveConnections() == controlsBaseline, "Destroy cancels the pending button animation callback")

local standaloneCalls, embeddedCalls, toggleCalls = 0, 0, 0
local slider = importUI("components/Slider")(ctx, "Standalone", 0, 100, 20, function() standaloneCalls += 1 end)
local row = importUI("blocks/SettingRow")(ctx, "Combined", false, function() toggleCalls += 1 end, {
	Slider = { Min = 0, Max = 100, Default = 20, Callback = function() embeddedCalls += 1 end },
	Keybind = { Default = Enum.KeyCode.F },
})
slider:Set(35.9); row:SetSlider(35.9)
slider:Set(35.9); row:SetSlider(35.9)
check(slider:Get() == 35 and row:GetSlider() == 35 and standaloneCalls == 1 and embeddedCalls == 1, "Both slider presentations share quantization and no-op behavior")
slider:Set(500, true); row:SetSlider(500, true)
check(slider:Get() == 100 and row:GetSlider() == 100 and embeddedCalls == 1, "Both slider presentations share silent clamping")
check(#elements == 2, "Embedded slider does not add an independent ResetAll entry")
Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard, KeyCode=Enum.KeyCode.F}, false)
check(row:Get() and toggleCalls == 1, "Composed hotkey updates the same toggle state")
row:Reset()
check(not row:Get() and row:GetSlider() == 100, "Legacy toggle Reset leaves the embedded slider unchanged")
local embeddedRoot
for _, object in row.Root:GetChildren() do
	if object.ClassName == "Frame" and type(object.Position.Y) == "table" and object.Position.Y.Offset == 36 then embeddedRoot = object end
end
check(embeddedRoot ~= nil and embeddedRoot.Size.Y.Offset == 46, "Compact slider is parented below the switch")
local hitArea
for _, object in embeddedRoot:GetChildren() do
	if object.ClassName == "TextButton" then hitArea = object end
end
hitArea.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1, Position=vec(660,300)})
local callbacksBeforeDestroy = embeddedCalls
row:Destroy(); slider:Destroy()
Input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement, Position=vec(800,300)})
row:SetSlider(1); row:Set(true)
Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard, KeyCode=Enum.KeyCode.F}, false)
check(embeddedCalls == callbacksBeforeDestroy and toggleCalls == 2, "Destroy cancels composed dragging, hotkeys and setters")
check(liveConnections() == controlsBaseline and #elements == 0 and embeddedRoot.Destroyed, "Composed controls release their nested resources")

-- Section binding must use the actual container, not a captured tab parent.
local container = { _content = parent, _tracker = scope }
importUI("layout/Container")(container, ctx)
local section = container:CreateSection("Outer")
local nestedSection = section:CreateSection("Inner")
local nestedRow = nestedSection:CreateToggle("Nested", false, nil, {Slider={Default=10}})
check(nestedRow.Root.Parent == nestedSection._content, "Nested toggles belong to their section")
section:Destroy(); section:Destroy()
check(nestedRow.Root.Destroyed and liveConnections() == controlsBaseline and #elements == 0, "Section destruction owns every descendant component")
check(not pcall(function() nestedSection:CreateButton("Too late", function() end) end), "Destroyed containers cannot create new controls")

local actions = container:CreateActionGroup({ Cards = true, Columns = 2, MinWidth = 210 })
local actionGrid = actions._content:FindFirstChildOfClass("UIGridLayout")
local cardCalls = 0
local card = actions:CreateButton("Open a page", function() cardCalls += 1 end, { Description = "A useful destination" })
actions._content.AbsoluteSize = vec(600, 124)
check(actionGrid.FillDirectionMaxCells == 2 and actionGrid.CellSize.X.Scale == 0.5, "Wide action groups lay out two columns")
actions._content.AbsoluteSize = vec(300, 258)
check(actionGrid.FillDirectionMaxCells == 1 and actionGrid.CellSize.X.Scale == 1, "Narrow action groups collapse to one column")
actionGrid.AbsoluteContentSize = vec(300, 258)
check(actions._content.Size.Y.Offset == 258, "Action groups expand the scrolling page to fit their content")
local cardSize = card.Root.Size
card.Root.MouseButton1Click:Fire(); advance(0.1); advance(0.3)
check(cardCalls == 1 and card.Root.Size == cardSize, "Card clicks preserve the dimensions owned by the grid")
card.Root.MouseButton1Click:Fire(); actions:Destroy(); advance(1)
check(cardCalls == 1 and card.Root.Destroyed and liveConnections() == controlsBaseline,
	"Removing an action group cancels pending clicks and all descendant handlers")
local compactButton = container:CreateButton("Short action", function() end)
check(compactButton.Root.Size.X.Scale == 0 and compactButton.Root.Size.X.Offset < parent.AbsoluteSize.X,
	"Standalone actions use content width instead of stretching across the page")
parent.AbsoluteSize = vec(120, 300)
check(compactButton.Root.Size.X.Offset <= 120, "Compact actions stay within narrow containers")
compactButton:Destroy()

scope:DisconnectAll(); parent:Destroy(); advance(20); advance(0)
check(liveConnections() == baseline, "Standalone component host releases shared input")

-- Compatibility facade owns one window; stale handles cannot destroy its replacement.
local ui = importUI("init")()
local first = ui:CreateWindow("First")
first:CreateTab("Old"):CreateToggle("Old toggle", false, nil, {Keybind={Default=Enum.KeyCode.F}})
local second = ui:CreateWindow("Second")
local tab = second:CreateTab("New")
local current = tab:CreateToggle("New toggle", false, nil)
local shell = CoreGui:FindFirstChild("Diq_UI"):FindFirstChild("DiqMainFrame")
local body = shell:FindFirstChild("Body")
shell.AbsoluteSize = vec(920, 660)
check(body:FindFirstChild("Sidebar").Size.X.Offset == 184 and tab._label.Visible, "Wide windows show full sidebar navigation")
shell.AbsoluteSize = vec(480, 600)
check(body:FindFirstChild("Sidebar").Size.X.Offset == 56 and not tab._label.Visible, "Narrow windows retain an icon rail and give content more room")
shell.AbsoluteSize = vec(920, 660)
shell:FindFirstChild("TopBar"):FindFirstChild("ToggleSidebar").MouseButton1Click:Fire()
check(body:FindFirstChild("Sidebar").Size.X.Offset == 56, "Sidebar can be collapsed manually")
tab._button.MouseButton1Click:Fire()
check(tab._content.Visible, "Compact navigation still opens its page")
first:Destroy()
check(not current.Root.Destroyed, "Old window teardown cannot destroy a replacement window")
ui:Notify("Message", "Pending notification", 10)
ui:Destroy(); ui:Destroy(); advance(20); advance(0)
check(liveConnections() == baseline and current.Root.Destroyed, "Facade cleans windows and pending notifications without Runtime")

-- Construction failure midway through a window must roll back its allocated GUI and input.
local originalNew = Instance.new
Instance.new = function(class)
	if class == "ScrollingFrame" then error("simulated UI construction failure") end
	return originalNew(class)
end
check(not pcall(function() ui:CreateWindow("Broken") end), "Window construction errors remain actionable")
Instance.new = originalNew
advance(20); advance(0)
check(liveConnections() == baseline, "Failed window creation releases partial input resources")
check(CoreGui:FindFirstChild("Diq_UI") == nil, "Failed window creation releases its partial ScreenGui")
check(#warnings == 0, "Component scenarios have no swallowed callback errors")
print("Component checks passed: " .. checks)
