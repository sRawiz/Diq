-- INSERT_MOCKS
-- INSERT_UI_MODULES
local baseline = liveConnections()
local ui = importUI("init")()
local customSize = UDim2.fromOffset(800, 580)
local window = ui:CreateWindow({ Title = "Window test", Size = customSize })
local tab = window:CreateTab("Settings")
local gui = CoreGui:FindFirstChild("Diq_UI")
local shell = gui:FindFirstChild("DiqMainFrame")
local top = shell:FindFirstChild("TopBar")
local sidebar = shell:FindFirstChild("Body"):FindFirstChild("Sidebar")
local scale = shell:FindFirstChild("WindowScale")
local dock = gui:FindFirstChild("RestoreWindow")
local min = top:FindFirstChild("Minimize")
local actions = tab:CreateActionGroup({ Cards = true })
local grid = actions._content:FindFirstChildOfClass("UIGridLayout")
actions:CreateButton("Open", function() end)
local section = tab:CreateSection("Preferences")
local sectionLayout = section._content:FindFirstChildOfClass("UIListLayout")
local button = tab:CreateButton("Compact action", function() end)
scale.Scale = 0.5
actions._content.AbsoluteSize = vec(300, 62)
grid.AbsoluteContentSize = vec(300, 62)
sectionLayout.AbsoluteContentSize = vec(300, 50)
tab._content.AbsoluteSize = vec(300, 200)
local pageLayout = tab._content:FindFirstChildOfClass("UIListLayout")
pageLayout.AbsoluteContentSize = vec(300, 200)
shell.AbsoluteSize = vec(460,330)
check(grid.FillDirectionMaxCells == 2 and actions._content.Size.Y.Offset == 124,
	"Animation scale preserves card columns and their logical layout height")
check(section._content.Size.Y.Offset == 118 and tab._content.CanvasSize.Y.Offset == 432,
	"Section height and scroll canvas convert scaled measurements back to layout units")
check(sidebar.Size.X.Offset == 184 and button.Root.Size.X.Offset > 100,
	"Zooming does not trigger the narrow sidebar or squeeze compact buttons")
scale.Scale = 1; shell.AbsoluteSize = vec(920,660)
advance(0)
local steadyConnections = liveConnections()
check(top.BackgroundTransparency == 1 and not top:FindFirstChildOfClass("UICorner"),
	"Header cannot paint a different-radius corner over the shell")
local surface = sidebar:FindFirstChild("SidebarSurface")
check(sidebar.BackgroundTransparency == 1 and surface:FindFirstChildOfClass("UICorner").CornerRadius.Offset == shell:FindFirstChildOfClass("UICorner").CornerRadius.Offset,
	"Sidebar paints its own matching curved bottom-left boundary")
check(surface:FindFirstChild("SquareTop").Size.Y.Offset == 18
	and surface:FindFirstChild("SquareRight").Size.X.Offset == 18,
	"Only the sidebar's interior top and right edges are squared")

top.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=vec(100,100)})
Input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=vec(160,140)})
local originalPosition = shell.Position
check(originalPosition.X.Offset == 60 and originalPosition.Y.Offset == 40, "Window can still be dragged before minimizing")
min.MouseButton1Click:Fire()
check(window:IsMinimized() and dock.Visible and shell.Size == customSize and scale.Scale == 0.12,
	"Minimize scales toward a bottom restore button without replacing the saved window dimensions")
local dockTarget = shell.Position
Input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=vec(500,300)})
check(shell.Position == dockTarget, "An active title-bar drag is cancelled before minimizing")
advance(0)
check(not shell.Visible and dock.Visible and liveConnections() == steadyConnections,
	"Completed minimize hides the full window and releases transition handlers")
dock.MouseButton1Click:Fire(); advance(0)
check(not window:IsMinimized() and shell.Visible and not dock.Visible and scale.Scale == 1,
	"The dock restores the full window")
check(shell.Position == originalPosition and shell.Size == customSize and tab._content.Visible,
	"Restore preserves the dragged position, explicit size and selected tab")

min.MouseButton1Click:Fire(); advance(0)
Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.K}, false); advance(0)
check(shell.Visible and not window:IsMinimized() and not dock.Visible, "The window shortcut restores a minimized window")
window:Toggle()
check(not shell.Visible and not dock.Visible, "The shortcut still hides an expanded window")
window:Toggle()
check(shell.Visible and shell.Position == originalPosition, "Showing an ordinary hidden window keeps its position")

min.MouseButton1Click:Fire()
local obsoleteScaleTween = TweenService.created[#TweenService.created]
dock.MouseButton1Click:Fire()
check(obsoleteScaleTween.PlaybackState == Enum.PlaybackState.Cancelled, "A rapid restore cancels the previous minimize tween")
obsoleteScaleTween.Completed:Fire(Enum.PlaybackState.Completed)
advance(0)
check(shell.Visible and not dock.Visible and shell.Position == originalPosition,
	"Late completion from a superseded animation cannot hide the restored window")

window:SetMinimized(true); window:SetVisible(false); advance(0)
check(not shell.Visible and not dock.Visible, "Explicit hide during minimize hides both surfaces")
window:SetVisible(true); advance(0)
check(shell.Visible and not dock.Visible and shell.Position == originalPosition, "Explicit show restores a hidden minimized window")

window:SetMinimized(true); advance(0); window:SetMinimized(false)
shell.Position = UDim2.new(0.7, 12, 0.8, 9); scale.Scale = 0.6 -- Simulate an intermediate tween frame.
window:SetVisible(false); window:SetVisible(true); advance(0)
check(shell.Position == originalPosition and scale.Scale == 1 and shell.Visible,
	"Hide/show during restoration cannot keep an intermediate animation position")

window:SetMinimized(true); advance(0)
check(window:SelectTab(tab), "Selecting a valid page still succeeds while minimized")
advance(0)
check(shell.Visible and not window:IsMinimized() and tab._content.Visible, "Quick navigation also restores the window")
for _ = 1, 20 do window:SetMinimized(true); window:SetMinimized(false); advance(0) end
check(liveConnections() == steadyConnections and shell.Position == originalPosition,
	"Repeated interrupted transitions neither leak handlers nor drift the restore position")
window:SetMinimized(true)
local lastTween = TweenService.created[#TweenService.created]
ui:Destroy(); lastTween.Completed:Fire(Enum.PlaybackState.Completed); advance(1)
check(lastTween.PlaybackState == Enum.PlaybackState.Cancelled and dock.Destroyed and shell.Destroyed,
	"Destroy during minimize cancels motion and removes the dock")
check(liveConnections() == baseline and next(queue) == nil, "Window teardown releases pending motion and input resources")
check(#warnings == 0, "Window scenarios contain no swallowed callback failures")
print("Window checks passed: " .. checks)
