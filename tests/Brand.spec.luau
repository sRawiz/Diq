-- INSERT_MOCKS
-- INSERT_UI_MODULES
local baseline = liveConnections()
local attempts = 0
function Players:GetUserThumbnailAsync(id, kind, size)
	check(id == own.UserId and kind == Enum.ThumbnailType.HeadShot and size == Enum.ThumbnailSize.Size150x150,
		"Avatar request uses the local player's headshot")
	attempts += 1
	return "rbxasset://avatar-test", attempts > 1
end
own.DisplayName = "Display Name"
local ui = importUI("init")()
local window = ui:CreateWindow({ Title = "Diq", Size = UDim2.fromOffset(800, 580) })
local tab = window:CreateTab("Settings")
local anotherTab = window:CreateTab("Other")
local gui = CoreGui.Diq_UI
gui.AbsoluteSize = vec(1280, 900)
local shell, dock = gui.DiqMainFrame, gui.RestoreWindow
local account = shell.Body.Sidebar.SidebarAccount
shell.AbsoluteSize = vec(800, 580)
advance(0)
check(account.DisplayName.Text == "Display Name" and account.Username.Text == "@Own", "Sidebar shows display name and username")
check(account.Portrait.Avatar.Image == "" and account.Portrait.AvatarFallback.Visible, "Initials remain while thumbnail is not ready")
advance(1)
check(attempts == 2 and account.Portrait.Avatar.Image == "rbxasset://avatar-test", "Ready thumbnail replaces placeholder after bounded retry")
account.Portrait.Avatar.IsLoaded = true
check(not account.Portrait.AvatarFallback.Visible, "Loaded image hides initials")
shell.AbsoluteSize = vec(480, 580)
check(not account.DisplayName.Visible and not account.Username.Visible and account.Portrait.Size.X.Offset == 32,
	"Compact sidebar keeps avatar and hides both text lines")
shell.AbsoluteSize = vec(800, 580)
check(account.DisplayName.Visible and account.Username.Visible and account.Portrait.Size.X.Offset == 36, "Expanded sidebar restores full account card")
own.DisplayName = "Updated Name"
check(account.DisplayName.Text == "Updated Name", "Display-name changes update without rebuilding the card")
check(dock.Size.X.Offset == 56 and dock.Size.Y.Offset == 56 and dock.Text == "" and dock.DiqMark ~= nil, "Minimized surface is a square logo button")
check(shell.TopBar.DiqMark.Outline ~= nil and shell.TopBar.DiqMark.Cutout ~= nil, "Header uses filled silhouettes without clipped strokes")
for _, node in shell.TopBar.DiqMark:GetDescendants() do
	check(not node:IsA("UIStroke") and not node.ClipsDescendants, "Logo avoids clipped stroke seams")
end
dock.MouseEnter:Fire(); advance(0)
check(dock.DiqMark.Cutout.BackgroundColor3 == dock.BackgroundColor3
	and dock.DiqMark.Cutout.StraightEdge.BackgroundColor3 == dock.BackgroundColor3,
	"Logo cutout follows hover surface without a background patch")
check(shell.TopBar.DiqMark.Cutout.BackgroundColor3 == shell.BackgroundColor3, "Header cutout uses actual window surface")
local originalPosition, originalSize = shell.Position, shell.Size
window:SetMinimized(true); advance(0)
local stable = liveConnections()
local function begin(kind)
	local pointer = {UserInputType = kind or Enum.UserInputType.MouseButton1, Position = vec(100, 100)}
	dock.InputBegan:Fire(pointer)
	return pointer
end
local function move(dx, dy)
	Input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement, Position=vec(100+dx, 100+dy)})
end
local function endMouse() Input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1}) end
local start = dock.Position
local mouse = begin(); move(-200, -120)
check(dock.Position.X.Scale < start.X.Scale and dock.Position.Y.Scale < start.Y.Scale, "Mouse drag moves floating logo")
dock.Activated:Fire(mouse); endMouse()
check(window:IsMinimized(), "Activation before release cannot restore after a drag")
mouse = begin(); move(-20, 0); endMouse(); dock.Activated:Fire(mouse)
check(window:IsMinimized(), "Activation after release cannot restore after a drag")
local movedPosition = dock.Position
move(100, 100)
check(dock.Position == movedPosition, "Release outside button ends movement")
mouse = begin(); move(2, 1); endMouse(); dock.Activated:Fire(mouse); advance(0)
check(not window:IsMinimized() and shell.Visible and shell.Position == originalPosition and shell.Size == originalSize,
	"Small click jitter restores original window geometry")
window:SetMinimized(true); advance(0)
check(dock.Position == movedPosition and shell.Position == dock.Position, "Logo position persists and minimize animates toward it")
local touch = begin(Enum.UserInputType.Touch)
Input.InputChanged:Fire({UserInputType=Enum.UserInputType.Touch, Position=vec(0, 0)})
check(dock.Position == movedPosition, "Second finger cannot steal floating-logo drag")
touch.Position = vec(50, 50); Input.InputChanged:Fire(touch)
check(dock.Position ~= movedPosition, "Initiating touch moves the logo")
Input.InputEnded:Fire(touch); dock.Activated:Fire(touch)
check(window:IsMinimized(), "Touch drag does not trigger restore")
mouse = begin(); move(-10000, -10000); endMouse()
check(math.abs(dock.Position.X.Scale * 1280 - 36) < 0.001 and math.abs(dock.Position.Y.Scale * 900 - 36) < 0.001,
	"Logo stays fully inside the safe-area margin")
begin(); Input.WindowFocusReleased:Fire()
local frozen = dock.Position; move(500, 500)
check(dock.Position == frozen and window:IsMinimized(), "Focus loss cancels dragging")
dock.Activated:Fire({UserInputType=Enum.UserInputType.Gamepad1}); advance(0)
check(not window:IsMinimized(), "Gamepad activation can restore after a cancelled pointer gesture")
window:SetMinimized(true); advance(0)
begin(); move(40, 40); window:SetVisible(false)
frozen = dock.Position; move(200, 200)
check(not dock.Visible and dock.Position == frozen, "Hide cancels overlay drag and hides logo")
window:SetVisible(true); advance(0)
window:SetMinimized(true); advance(0)
begin(); gui.AbsoluteSize = vec(320, 240)
frozen = dock.Position; move(500, 500)
check(dock.Position == frozen and dock.Position.X.Scale * 320 >= 36 and dock.Position.Y.Scale * 240 >= 36,
	"Viewport resize cancels drag and keeps logo reachable")
window:SetTitle("Renamed")
check(window.Title == "Renamed" and not shell.TopBar:FindFirstChild("WindowTitle") and dock.DiqMark ~= nil,
	"SetTitle keeps metadata without reintroducing header text")
window:SelectTab(anotherTab); advance(0)
check(not shell.TopBar:FindFirstChild("WindowTitle") and shell.TopBar.WindowDragArea.Active,
	"Tab switching retains logo-only header and active drag area")
window:SetMinimized(true); advance(0)
for _ = 1, 15 do
	local click = begin(); endMouse(); dock.Activated:Fire(click); advance(0)
	window:SetMinimized(true); advance(0)
end
check(liveConnections() == stable, "Repeated logo restore cycles do not accumulate handlers")
begin(); ui:Destroy(); move(100, 100); advance(3)
check(liveConnections() == baseline and next(queue) == nil and dock.Destroyed, "Close during logo drag releases all resources")

-- Avatar failures and teardown during a yielding thumbnail request.
function Players:GetUserThumbnailAsync() error("unavailable") end
ui = importUI("init")(); window = ui:CreateWindow()
advance(0)
account = CoreGui.Diq_UI.DiqMainFrame.Body.Sidebar.SidebarAccount
check(account.Portrait.AvatarFallback.Visible and account.Portrait.Avatar.Image == "", "Thumbnail failure leaves a usable initials fallback")
ui:Destroy(); advance(0)
local worker
function Players:GetUserThumbnailAsync() worker = coroutine.running(); task.wait(10); return "late-image", true end
ui = importUI("init")(); window = ui:CreateWindow(); advance(0)
ui:Destroy(); advance(20)
check(coroutine.status(worker) == "dead" and liveConnections() == baseline and next(queue) == nil,
	"Thumbnail request cannot update a replaced or closed UI")
check(#warnings == 0, "Brand scenarios have no swallowed callback errors")
print("Brand checks passed: " .. checks)
