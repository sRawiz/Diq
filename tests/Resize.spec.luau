-- INSERT_MOCKS
-- INSERT_UI_MODULES
local baseline = liveConnections()
local ui = importUI("init")()
local window = ui:CreateWindow({ Size = UDim2.fromOffset(800, 580) })
local tab = window:CreateTab("Resize")
local gui = CoreGui.Diq_UI
gui.AbsoluteSize = vec(1280, 900)
local shell, top = gui.DiqMainFrame, gui.DiqMainFrame.TopBar
advance(0)
local stable = liveConnections()
local function rect()
	local w = shell.Size.X.Scale * gui.AbsoluteSize.X + shell.Size.X.Offset
	local h = shell.Size.Y.Scale * gui.AbsoluteSize.Y + shell.Size.Y.Offset
	local x = shell.Position.X.Scale * gui.AbsoluteSize.X + shell.Position.X.Offset
	local y = shell.Position.Y.Scale * gui.AbsoluteSize.Y + shell.Position.Y.Offset
	return x - w / 2, y - h / 2, w, h
end
local function reset()
	window:SetVisible(true); window:SetMaximized(false)
	shell.Size, shell.Position = UDim2.fromOffset(800, 580), UDim2.fromScale(0.5, 0.5)
end
local function begin(name, kind)
	local pointer = { UserInputType = kind or Enum.UserInputType.MouseButton1, Position = vec(100, 100) }
	shell[name].InputBegan:Fire(pointer)
	return pointer
end
local function move(dx, dy)
	Input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseMovement, Position = vec(100 + dx, 100 + dy)})
end
local function finish() Input.InputEnded:Fire({UserInputType = Enum.UserInputType.MouseButton1}) end
for _, name in {"Left", "Right", "Top", "Bottom", "TopLeft", "TopRight", "BottomLeft", "BottomRight"} do
	check(shell["Resize" .. name] ~= nil, "Resize handle exists: " .. name)
end
begin("ResizeBottomRight"); move(100, 50); finish()
local l, t, w, h = rect()
check(l == 240 and t == 160 and w == 900 and h == 630, "Bottom-right drag leaves opposite corner fixed")
reset(); begin("ResizeTopLeft"); move(100, 60); finish()
l, t, w, h = rect()
check(l == 340 and t == 220 and w == 700 and h == 520, "Top-left drag leaves opposite corner fixed")
reset(); begin("ResizeLeft"); move(10000, 0); finish()
l, t, w, h = rect()
check(w == 420 and h == 580 and l + w == 1040, "Width clamps at usable minimum without moving right edge")
reset(); begin("ResizeTop"); move(0, 10000); finish()
l, t, w, h = rect()
check(h == 300 and t + h == 740, "Height clamps at usable minimum")
reset(); begin("ResizeBottomRight"); move(10000, 10000); finish()
l, t, w, h = rect()
check(l + w == 1272 and t + h == 892, "Resize stays inside GUI safe-area margins")
reset(); begin("ResizeRight"); move(20, 0); finish()
local ended = shell.Size; move(200, 0)
check(shell.Size == ended, "Release outside handle ends resize")
begin("ResizeRight"); Input.WindowFocusReleased:Fire(); move(200, 0)
check(shell.Size == ended, "Losing focus cancels resize")
reset()
local touch = begin("ResizeBottomRight", Enum.UserInputType.Touch)
Input.InputChanged:Fire({UserInputType = Enum.UserInputType.Touch, Position = vec(999, 999)})
check(shell.Size.X.Offset == 800, "Unrelated touch cannot steal a resize")
touch.Position = vec(150, 130); Input.InputChanged:Fire(touch)
check(shell.Size.X.Offset == 850 and shell.Size.Y.Offset == 610, "Initiating finger resizes")
Input.InputEnded:Fire({UserInputType = Enum.UserInputType.Touch})
touch.Position = vec(160, 140); Input.InputChanged:Fire(touch)
check(shell.Size.X.Offset == 860, "Releasing another finger does not end resize")
Input.InputEnded:Fire(touch)
touch.Position = vec(200, 200); Input.InputChanged:Fire(touch)
check(shell.Size.X.Offset == 860, "Releasing initiating finger ends resize")
reset()
top.WindowDragArea.InputBegan:Fire({UserInputType = Enum.UserInputType.MouseButton1, Position = vec(100, 100)})
move(-10000, -10000); finish()
l, t = rect()
check(l == 8 and t == 8, "Title dragging cannot lose the window offscreen")
reset(); begin("ResizeRight"); window:SetMinimized(true); move(200, 0); advance(0)
check(shell.Size.X.Offset == 800 and window:IsMinimized(), "Minimize cancels active resize")
window:SetVisible(true); advance(0)
local beforeSize, beforePos = shell.Size, shell.Position
top.Maximize.MouseButton1Click:Fire()
check(window:IsMaximized() and shell.Size.X.Offset == 1264 and shell.Size.Y.Offset == 884, "Maximize fills safe area beyond old 920px cap")
check(not shell.ResizeBottomRight.Visible, "Resize handles are hidden while maximized")
begin("ResizeRight"); move(-300, 0); finish()
check(shell.Size.X.Offset == 1264, "Maximized window ignores resize gestures")
window:SetMinimized(true); advance(0); window:SetVisible(true); advance(0)
check(window:IsMaximized() and shell.Size.X.Offset == 1264 and shell.Visible, "Minimize retains maximized state")
top.Maximize.MouseButton1Click:Fire()
check(not window:IsMaximized() and shell.Size == beforeSize and shell.Position == beforePos, "Restore returns exact prior size and position")
window:SetMaximized(true); gui.AbsoluteSize = vec(1000, 700)
check(shell.Size.X.Offset == 984 and shell.Size.Y.Offset == 684, "Maximized window follows viewport changes")
window:SetMaximized(false)
check(shell.Size.X.Offset == 800 and shell.Size.Y.Offset == 580, "Restore fits normal size in changed viewport")
gui.AbsoluteSize = vec(360, 260)
l, t, w, h = rect()
check(w == 344 and h == 244 and l == 8 and t == 8, "Small viewport takes priority over desktop minimum dimensions")
window:SetMinimized(true); advance(0)
gui.AbsoluteSize = vec(300, 220)
check(not shell.Visible and window:IsMinimized(), "Viewport resize does not reveal minimized window")
window:SetVisible(true); advance(0)
l, t, w, h = rect()
check(w == 284 and h == 204 and l == 8 and t == 8, "Restore uses updated viewport instead of stale dock geometry")
gui.AbsoluteSize = vec(1280, 900); reset()
for _ = 1, 20 do window:SetMaximized(true); window:SetMaximized(false); begin("ResizeRight"); move(1, 0); finish() end
check(liveConnections() == stable, "Repeated resize/maximize cycles do not grow handler count")
begin("ResizeRight"); window:SetVisible(false); move(100, 0)
local hidden = shell.Size
window:SetVisible(true); move(500, 0)
check(shell.Size == hidden, "Hidden gestures cannot resume on showing window")
local textValue, selectedValue
tab:CreateInput("Responsive input", "Type", function(value) textValue = value end)
tab:CreateDropdown("Responsive choice", { "One", "Two" }, "One", function(value) selectedValue = value end)
local inputFrame, dropdownFrame
for _, child in tab._content:GetChildren() do
	local label = child:FindFirstChildOfClass("TextLabel")
	if label and label.Text == "Responsive input" then inputFrame = child end
	if label and label.Text == "Responsive choice" then dropdownFrame = child end
end
local textBox = inputFrame:FindFirstChildOfClass("TextBox")
local dropdownButton = dropdownFrame:FindFirstChildOfClass("TextButton")
local dropdownList = dropdownFrame:FindFirstChildOfClass("ScrollingFrame")
inputFrame.AbsoluteSize = vec(300, 36); dropdownFrame.AbsoluteSize = vec(300, 36)
check(inputFrame.Size.Y.Offset == 66 and textBox.Position.Y.Offset == 30 and textBox.Size.X.Scale == 1,
	"Narrow inputs place the field beneath the heading")
check(dropdownFrame.Size.Y.Offset == 66 and dropdownButton.Position.Y.Offset == 30,
	"Narrow dropdowns stack their label and selector")
dropdownButton.MouseButton1Click:Fire()
check(dropdownList.Visible and dropdownList.Size.X.Scale == 1, "Open narrow menu uses available width")
local staleTween = TweenService.created[#TweenService.created]
dropdownFrame.AbsoluteSize = vec(600, 66)
staleTween.Completed:Fire(Enum.PlaybackState.Completed); advance(0)
check(dropdownList.Visible and dropdownList.Size.X.Scale == 0.5 and dropdownFrame.Size.Y.Offset == 36,
	"Resize cancels stale menu motion and retains open state in the wide layout")
dropdownButton.MouseButton1Click:Fire(); dropdownButton.MouseButton1Click:Fire(); advance(0)
check(dropdownList.Visible, "Rapid dropdown reopen cannot be hidden by an earlier close completion")
inputFrame.AbsoluteSize = vec(600, 66)
textBox.Text = "preserved"; textBox.FocusLost:Fire(true)
local option
for _, item in dropdownList:GetChildren() do if item:IsA("TextButton") and item.Text == "Two" then option = item end end
option.MouseButton1Click:Fire(); advance(0)
check(textValue == "preserved" and selectedValue == "Two" and not dropdownList.Visible,
	"Reflow preserves functional input and option callbacks")
begin("ResizeBottomRight"); ui:Destroy(); move(500, 500); advance(1)
check(liveConnections() == baseline and next(queue) == nil, "Destroy during resize cleans up input and deferred fitting")
check(#warnings == 0, "No swallowed window sizing callbacks")
print("Resize checks passed: " .. checks)
