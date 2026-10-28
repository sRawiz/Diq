-- Client aim controller. Main may load this with { DeferInit = true }.
local ModuleOptions = ...
local AimbotSystem = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local Config = {
	Enabled = false, AimMethod = "Camera", ShowFOV = false,
	FOVRadius = 150, FOVColor = Color3.new(1, 1, 1),
	Smoothing = 0.5, AimPart = "Head", WallCheck = false,
	TeamCheck = true, MaxDistance = 3000,
}
local initialized, destroyed, bound = false, false, false
local focused, held, aiming = true, false, false
local currentPlayer, currentPart
local connections = {}
local fovGui, fovFrame, fovStroke
local bindingName = "DiqAim_" .. tostring({})
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function releaseTarget()
	currentPlayer, currentPart, aiming = nil, nil, false
end

local function finite(value, name, minimum, maximum)
	assert(type(value) == "number" and value == value and math.abs(value) < math.huge, name .. " must be finite")
	return math.clamp(value, minimum, maximum)
end

-- All selection and movement calculations use viewport coordinates.
-- Only the GUI overlay converts back to screen coordinates with the inset.
local function getOrigin(camera, inset)
	if Config.AimMethod == "Camera" or Input.MouseBehavior ~= Enum.MouseBehavior.Default then
		return camera.ViewportSize / 2
	end
	return Input:GetMouseLocation() - inset
end

local function getPart(character)
	local part = character:FindFirstChild(Config.AimPart)
	if not part and Config.AimPart == "Torso" then
		part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso")
	end
	part = part or character:FindFirstChild("HumanoidRootPart")
	return part and part:IsA("BasePart") and part or nil
end

-- Revalidate the owner as well as the part: respawn, team swaps, death and
-- streaming must invalidate a lock through the same rules as initial selection.
local function evaluate(player, camera, origin)
	if player == LocalPlayer or player.Parent ~= Players then return nil end
	if Config.TeamCheck and not LocalPlayer.Neutral and not player.Neutral
		and player.Team ~= nil and player.Team == LocalPlayer.Team then return nil end
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	local part = getPart(character)
	if not part then return nil end
	local direction = part.Position - camera.CFrame.Position
	if direction.Magnitude < 0.001 or direction.Magnitude > Config.MaxDistance then return nil end
	local projected, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen or projected.Z <= 0 then return nil end
	local point = Vector2.new(projected.X, projected.Y)
	local distance = (point - origin).Magnitude
	if distance > Config.FOVRadius then return nil end
	if Config.WallCheck then
		local hit = workspace:Raycast(camera.CFrame.Position, direction, rayParams)
		if hit and not hit.Instance:IsDescendantOf(character) then return nil end
	end
	return part, point, distance
end

local function createOverlay()
	-- Standard Roblox GUI: the FOV indicator does not require executor Drawing.
	fovGui = Instance.new("ScreenGui")
	fovGui.Name = "Diq_AimFOV"
	fovGui.IgnoreGuiInset = true
	fovGui.ResetOnSpawn = false
	fovGui.DisplayOrder = 10
	fovGui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not fovGui.Parent then error("[Diq] PlayerGui is not available for the FOV overlay") end
	fovFrame = Instance.new("Frame")
	fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	fovFrame.BackgroundTransparency = 1
	fovFrame.Visible = false
	fovFrame.Parent = fovGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = fovFrame
	fovStroke = Instance.new("UIStroke")
	fovStroke.Thickness = 1
	fovStroke.Parent = fovFrame
end

local function step(dt)
	local camera = workspace.CurrentCamera
	local blocked = not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox() ~= nil
	if fovFrame then fovFrame.Visible = Config.Enabled and Config.ShowFOV and camera ~= nil and not blocked end
	if not camera then releaseTarget(); return end
	local inset = GuiService:GetGuiInset()
	local origin = getOrigin(camera, inset)
	if fovFrame then
		local screen = origin + inset
		fovFrame.Position = UDim2.fromOffset(screen.X, screen.Y)
		fovFrame.Size = UDim2.fromOffset(Config.FOVRadius * 2, Config.FOVRadius * 2)
		fovStroke.Color = Config.FOVColor
	end
	if not Config.Enabled or not held or blocked then releaseTarget(); return end
	local localCharacter = LocalPlayer.Character
	local localHumanoid = localCharacter and localCharacter:FindFirstChildOfClass("Humanoid")
	if not localHumanoid or localHumanoid.Health <= 0 then releaseTarget(); return end
	rayParams.FilterDescendantsInstances = { localCharacter, camera }

	local part, point
	if currentPlayer then part, point = evaluate(currentPlayer, camera, origin) end
	if not part then
		releaseTarget()
		local closest = math.huge
		for _, player in ipairs(Players:GetPlayers()) do
			local candidate, screen, distance = evaluate(player, camera, origin)
			if candidate and distance < closest then
				closest, currentPlayer, part, point = distance, player, candidate, screen
			end
		end
	end
	currentPart = part
	if not part then return end
	aiming = true
	-- Higher response means faster convergence. Exponential response is stable
	-- across frame rates; the same factor is used by both output backends.
	local alpha = 1 - math.exp(-(2 + 38 * Config.Smoothing) * math.clamp(dt, 0, 0.1))
	if Config.AimMethod == "Camera" then
		local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
		camera.CFrame = camera.CFrame:Lerp(desired, alpha)
	else
		local delta = (point - origin) * alpha
		local ok, err = pcall(mousemoverel, delta.X, delta.Y)
		if not ok then
			Config.AimMethod = "Camera"
			releaseTarget()
			warn("[Diq] Mouse aiming failed; switched to Camera: " .. tostring(err))
		end
	end
end

local function updateBinding()
	local needed = initialized and not destroyed and Config.Enabled
	if needed and not bound then
		RunService:BindToRenderStep(bindingName, Enum.RenderPriority.Camera.Value + 5, function(dt)
			local ok, err = pcall(step, dt)
			if not ok then
				Config.Enabled = false
				releaseTarget()
				if fovFrame then fovFrame.Visible = false end
				RunService:UnbindFromRenderStep(bindingName)
				bound = false
				warn("[Diq] Aimbot stopped after a runtime error: " .. tostring(err))
			end
		end)
		bound = true
	elseif not needed and bound then
		RunService:UnbindFromRenderStep(bindingName)
		bound = false
	end
end

function AimbotSystem.Init()
	assert(not destroyed, "[Diq] Cannot initialize a destroyed module")
	if initialized then return end
	initialized = true
	local ok, err = pcall(function()
		createOverlay()
		table.insert(connections, Input.InputBegan:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				held = not processed and focused and not GuiService.MenuIsOpen and Input:GetFocusedTextBox() == nil
			end
		end))
		table.insert(connections, Input.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then held = false; releaseTarget() end
		end))
		table.insert(connections, Input.WindowFocusReleased:Connect(function() focused = false; held = false; releaseTarget() end))
		table.insert(connections, Input.WindowFocused:Connect(function() focused = true end))
		table.insert(connections, LocalPlayer.CharacterAdded:Connect(function() held = false; releaseTarget() end))
		updateBinding()
	end)
	if not ok then AimbotSystem.Destroy(); error(err, 0) end
end

function AimbotSystem.Destroy()
	if destroyed then return end
	destroyed = true
	Config.Enabled, held = false, false
	releaseTarget()
	updateBinding()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	if fovGui then fovGui:Destroy() end
	fovGui, fovFrame, fovStroke = nil, nil, nil
end

function AimbotSystem.SetEnabled(value)
	if destroyed then return false end
	Config.Enabled = value == true
	releaseTarget()
	if not Config.Enabled and fovFrame then fovFrame.Visible = false end
	updateBinding()
	return true
end
function AimbotSystem.SetAimMethod(method)
	if method ~= "Camera" and method ~= "Mouse" then return false, "Unknown aim method" end
	if method == "Mouse" and type(mousemoverel) ~= "function" then
		return false, "This executor does not provide mousemoverel; use Camera mode"
	end
	Config.AimMethod = method
	releaseTarget()
	return true
end
function AimbotSystem.SetShowFOV(value)
	Config.ShowFOV = value == true
	if not Config.ShowFOV and fovFrame then fovFrame.Visible = false end
end
function AimbotSystem.SetFOVRadius(value) Config.FOVRadius = finite(value, "FOV radius", 10, 800); releaseTarget() end
function AimbotSystem.SetFOVColor(value) assert(typeof(value) == "Color3", "Expected Color3"); Config.FOVColor = value end
function AimbotSystem.SetSmoothing(value) Config.Smoothing = finite(value, "Aim response", 0.01, 1) end
function AimbotSystem.SetMaxDistance(value) Config.MaxDistance = finite(value, "Max distance", 1, 10000); releaseTarget() end
function AimbotSystem.SetAimPart(value)
	assert(value == "Head" or value == "Torso" or value == "HumanoidRootPart", "Unsupported aim part")
	Config.AimPart = value
	releaseTarget()
end
function AimbotSystem.SetWallCheck(value) Config.WallCheck = value == true; releaseTarget() end
function AimbotSystem.SetTeamCheck(value) Config.TeamCheck = value == true; releaseTarget() end
function AimbotSystem.IsEnabled() return Config.Enabled end
function AimbotSystem.GetAimMethod() return Config.AimMethod end
function AimbotSystem.GetShowFOV() return Config.ShowFOV end
function AimbotSystem.GetFOVRadius() return Config.FOVRadius end
function AimbotSystem.GetFOVColor() return Config.FOVColor end
function AimbotSystem.GetSmoothing() return Config.Smoothing end
function AimbotSystem.GetMaxDistance() return Config.MaxDistance end
function AimbotSystem.GetAimPart() return Config.AimPart end
function AimbotSystem.GetWallCheck() return Config.WallCheck end
function AimbotSystem.GetTeamCheck() return Config.TeamCheck end
function AimbotSystem.IsAiming() return aiming end
function AimbotSystem.GetCurrentTarget() return currentPart end
function AimbotSystem.GetConfig() return table.clone(Config) end

if type(ModuleOptions) ~= "table" or not ModuleOptions.DeferInit then AimbotSystem.Init() end
return AimbotSystem
