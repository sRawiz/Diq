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
	ActivationKey = "Q", ActivationMode = "Toggle",
	TargetMode = "Balanced", CrosshairWeight = 0.7, SwitchDelay = 0.2,
	AutoSwitch = false, NextTargetKey = "T",
}
local initialized, destroyed, bound = false, false, false
local focused, held, aiming = true, false, false
local currentPlayer, currentPart
local nextRequested = false
local cycleOrder = nil
local inputSuspended = false
local lastAimDirection, lastCamera
local challenger, challengerTime = nil, 0
local scanElapsed = 0
local SCAN_INTERVAL = 0.1
local status = "Disabled"
local rejected = {}
local connections = {}
local fovGui, fovFrame, fovStroke, statusLabel
local bindingName = "DiqAim_" .. tostring({})
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function updateStatusLabel()
	if statusLabel then
		statusLabel.Visible = Config.Enabled
		local activation = Config.ActivationMode .. " " .. Config.ActivationKey .. ": " .. (held and "ON" or "OFF")
		statusLabel.Text = "Diq Aim | " .. activation .. " | " .. Config.TargetMode .. " | Next: " .. Config.NextTargetKey .. " | " .. status
	end
end

local function releaseTarget()
	currentPlayer, currentPart, aiming = nil, nil, false
	lastAimDirection = nil
	nextRequested = false
	cycleOrder = nil
	challenger, challengerTime, scanElapsed = nil, 0, 0
	updateStatusLabel()
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
local function reject(reason)
	rejected[reason] = (rejected[reason] or 0) + 1
	return nil
end

local function matchesActivation(input)
	if Config.ActivationKey == "MouseButton2" then return input.UserInputType == Enum.UserInputType.MouseButton2 end
	if Config.ActivationKey == "MouseButton1" then return input.UserInputType == Enum.UserInputType.MouseButton1 end
	return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode[Config.ActivationKey]
end

local function evaluate(player, camera, origin)
	if player == LocalPlayer or player.Parent ~= Players then return nil end
	if Config.TeamCheck and not LocalPlayer.Neutral and not player.Neutral
		and player.Team ~= nil and player.Team == LocalPlayer.Team then return reject("Same team") end
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then return reject("Character unavailable") end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return reject("No living Humanoid") end
	local part = getPart(character)
	if not part then return reject("Aim part unavailable") end
	local direction = part.Position - camera.CFrame.Position
	if direction.Magnitude < 0.001 or direction.Magnitude > Config.MaxDistance then return reject("Outside max distance") end
	local projected, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen or projected.Z <= 0 then return reject("Off screen") end
	local point = Vector2.new(projected.X, projected.Y)
	local distance = (point - origin).Magnitude
	if distance > Config.FOVRadius then return reject("Outside FOV") end
	if Config.WallCheck then
		local hit = workspace:Raycast(camera.CFrame.Position, direction, rayParams)
		if hit and not hit.Instance:IsDescendantOf(character) then return reject("Blocked by wall") end
	end
	return part, point, distance
end

-- Smaller scores win. UserId breaks exact ties independently of player-list order.
local function scoreTarget(part, screenDistance, camera)
	if Config.TargetMode == "Smart" or Config.TargetMode == "Sticky" then return screenDistance end
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local worldDistance = (part.Position - (root and root.Position or camera.CFrame.Position)).Magnitude
	if Config.TargetMode == "Nearest" then return worldDistance end
	-- Normalize unlike units before combining: pixels/FOV and distance with a
	-- 100-stud half-scale. User preference changes ranking, not eligibility.
	return Config.CrosshairWeight * (screenDistance / Config.FOVRadius)
		+ (1 - Config.CrosshairWeight) * (worldDistance / (worldDistance + 100))
end

local function better(score, player, bestScore, bestPlayer)
	return score < bestScore or (score == bestScore and (not bestPlayer or player.UserId < bestPlayer.UserId))
end

local function selectTarget(camera, origin, dt)
	if nextRequested then
		nextRequested = false
		local candidates = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local part, point, distance = evaluate(player, camera, origin)
			if part then
				table.insert(candidates, { Player = player, Part = part, Point = point,
					Score = scoreTarget(part, distance, camera) })
			end
		end
		table.sort(candidates, function(a, b) return better(a.Score, a.Player, b.Score, b.Player) end)
		-- Preserve a cycle order across presses; reranking after every camera
		-- turn otherwise bounces between two players and can starve the third.
		local available = {}
		for _, candidate in ipairs(candidates) do available[candidate.Player] = candidate end
		local ordered, included = {}, {}
		for _, player in ipairs(cycleOrder or {}) do
			if available[player] then table.insert(ordered, player); included[player] = true end
		end
		for _, candidate in ipairs(candidates) do
			if not included[candidate.Player] then table.insert(ordered, candidate.Player) end
		end
		cycleOrder = ordered
		local index = 1
		for i, player in ipairs(ordered) do
			if player == currentPlayer then index = i % #ordered + 1; break end
		end
		local selected = ordered[index] and available[ordered[index]]
		if selected then
			currentPlayer = selected.Player
			challenger, challengerTime, scanElapsed = nil, 0, 0
			return selected.Part, selected.Point
		end
		releaseTarget()
		return nil
	end
	local part, point, distance
	if currentPlayer then part, point, distance = evaluate(currentPlayer, camera, origin) end
	if not part then releaseTarget() end
	local currentScore = part and scoreTarget(part, distance, camera) or math.huge
	scanElapsed = scanElapsed + math.clamp(dt, 0, 0.1)
	-- Validate the current target every frame, but search challengers at 10 Hz.
	if part and (not Config.AutoSwitch or Config.TargetMode == "Sticky" or scanElapsed < SCAN_INTERVAL) then
		return part, point
	end
	local elapsed = scanElapsed
	scanElapsed = 0
	local bestPlayer, bestPart, bestPoint, bestScore = currentPlayer, part, point, currentScore
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= currentPlayer then
			local candidate, screen, screenDistance = evaluate(player, camera, origin)
			if candidate then
				local score = scoreTarget(candidate, screenDistance, camera)
				if better(score, player, bestScore, bestPlayer) then
					bestPlayer, bestPart, bestPoint, bestScore = player, candidate, screen, score
				end
			end
		end
	end
	if not part then
		currentPlayer = bestPlayer
		return bestPart, bestPoint
	end
	-- A challenger must improve the score by 20% AND an absolute margin,
	-- and remain best across successive scans. Near-equal targets do not chatter.
	local margin = Config.TargetMode == "Balanced" and 0.025 or (Config.TargetMode == "Nearest" and 3 or 8)
	if bestPlayer ~= currentPlayer and bestScore < currentScore * 0.8 and currentScore - bestScore >= margin then
		if challenger ~= bestPlayer then
			challenger, challengerTime = bestPlayer, 0
		else
			challengerTime = challengerTime + elapsed
		end
		if challengerTime >= Config.SwitchDelay then
			currentPlayer = bestPlayer
			cycleOrder = nil
			challenger, challengerTime = nil, 0
			return bestPart, bestPoint
		end
	else
		challenger, challengerTime = nil, 0
	end
	return part, point
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
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "AimStatus"
	statusLabel.Position = UDim2.fromOffset(12, 60)
	statusLabel.Size = UDim2.fromOffset(650, 26)
	statusLabel.BackgroundTransparency = 0.4
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextSize = 14
	statusLabel.Visible = false
	statusLabel.Parent = fovGui
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
	if camera ~= lastCamera then releaseTarget(); lastCamera = camera end
	local blocked = inputSuspended or not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox() ~= nil
	if fovFrame then fovFrame.Visible = Config.Enabled and Config.ShowFOV and camera ~= nil and not blocked end
	if not camera then status = "No camera"; releaseTarget(); return end
	local inset = GuiService:GetGuiInset()
	local origin = getOrigin(camera, inset)
	if fovFrame then
		local screen = origin + inset
		fovFrame.Position = UDim2.fromOffset(screen.X, screen.Y)
		fovFrame.Size = UDim2.fromOffset(Config.FOVRadius * 2, Config.FOVRadius * 2)
		fovStroke.Color = Config.FOVColor
	end
	if not Config.Enabled or not held or blocked then
		status = not Config.Enabled and "Disabled" or (blocked and "Paused: focus, menu or text input" or "Waiting for " .. Config.ActivationKey)
		releaseTarget()
		return
	end
	local localCharacter = LocalPlayer.Character
	local localHumanoid = localCharacter and localCharacter:FindFirstChildOfClass("Humanoid")
	if not localHumanoid or localHumanoid.Health <= 0 then status = "Local character not alive"; releaseTarget(); return end
	rayParams.FilterDescendantsInstances = { localCharacter, camera }

	table.clear(rejected)
	local part, point = selectTarget(camera, origin, dt)
	currentPart = part
	if not part then status = "No eligible player in FOV"; updateStatusLabel(); return end
	status = "Tracking " .. currentPlayer.Name
	updateStatusLabel()
	aiming = true
	-- Higher response means faster convergence. Exponential response is stable
	-- across frame rates; the same factor is used by both output backends.
	local alpha = 1 - math.exp(-(2 + 38 * Config.Smoothing) * math.clamp(dt, 0, 0.1))
	if Config.AimMethod == "Camera" then
		local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
		-- Continue from our previous orientation even if the game's camera
		-- controller resets its orientation before this callback every frame.
		local start = lastAimDirection and CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + lastAimDirection) or camera.CFrame
		camera.CFrame = start:Lerp(desired, alpha)
		lastAimDirection = camera.CFrame.LookVector
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
		RunService:BindToRenderStep(bindingName, Enum.RenderPriority.Last.Value + 1, function(dt)
			local ok, err = pcall(step, dt)
			if not ok then
				Config.Enabled = false
				status = "Runtime error: " .. tostring(err)
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
			if inputSuspended or not Config.Enabled or processed or not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox() ~= nil then return end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode[Config.NextTargetKey] then
				AimbotSystem.NextTarget()
				return
			end
			if not matchesActivation(input) then return end
			held = Config.ActivationMode == "Toggle" and not held or Config.ActivationMode == "Hold"
			status = held and "Searching" or "Waiting for " .. Config.ActivationKey
			releaseTarget()
		end))
		table.insert(connections, Input.InputEnded:Connect(function(input)
			if Config.ActivationMode == "Hold" and matchesActivation(input) then held = false; releaseTarget() end
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
	fovGui, fovFrame, fovStroke, statusLabel = nil, nil, nil, nil
end

function AimbotSystem.SetEnabled(value)
	if destroyed then return false end
	Config.Enabled = value == true
	held = false
	status = Config.Enabled and "Waiting for " .. Config.ActivationKey or "Disabled"
	releaseTarget()
	if not Config.Enabled and fovFrame then fovFrame.Visible = false end
	updateBinding()
	return true
end
function AimbotSystem.SetActivationKey(key)
	assert(type(key) == "string" and (key == "MouseButton1" or key == "MouseButton2"
		or (key ~= "Unknown" and Enum.KeyCode[key] ~= nil)), "Expected a keyboard key name or mouse button")
	if key == Config.NextTargetKey then return false, "Aim and Next Target must use different buttons" end
	Config.ActivationKey = key
	status = "Waiting for " .. key
	held = false
	releaseTarget()
	return true
end
function AimbotSystem.SetInputSuspended(value)
	inputSuspended = value == true
	if inputSuspended then
		held = false
		status = "Paused: editing keybind"
		releaseTarget()
	end
end
function AimbotSystem.NextTarget()
	if inputSuspended or destroyed or not Config.Enabled or not held or not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox() ~= nil then return false end
	nextRequested = true
	return true
end
function AimbotSystem.SetNextTargetKey(key)
	if type(key) ~= "string" or key == "Unknown" or not Enum.KeyCode[key] then return false, "Choose a keyboard key" end
	if key == Config.ActivationKey then return false, "Aim and Next Target must use different buttons" end
	Config.NextTargetKey = key
	nextRequested = false
	updateStatusLabel()
	return true
end
function AimbotSystem.GetNextTargetKey() return Config.NextTargetKey end
function AimbotSystem.SetAutoSwitch(value)
	Config.AutoSwitch = value == true
	challenger, challengerTime, scanElapsed = nil, 0, 0
end
function AimbotSystem.GetAutoSwitch() return Config.AutoSwitch end
function AimbotSystem.SetActivationMode(mode)
	assert(mode == "Hold" or mode == "Toggle", "Expected Hold or Toggle")
	Config.ActivationMode = mode
	status = "Waiting for " .. Config.ActivationKey
	held = false
	releaseTarget()
end
function AimbotSystem.GetActivationKey() return Config.ActivationKey end
function AimbotSystem.GetActivationMode() return Config.ActivationMode end
function AimbotSystem.GetStatus()
	return { Reason = destroyed and "Destroyed" or (not Config.Enabled and "Disabled" or status),
		Active = held, Tracking = aiming, Method = Config.AimMethod,
		ActivationKey = Config.ActivationKey, ActivationMode = Config.ActivationMode,
		AutoSwitch = Config.AutoSwitch, NextTargetKey = Config.NextTargetKey,
		TargetMode = Config.TargetMode, TargetName = currentPlayer and currentPlayer.Name or nil,
		Rejected = table.clone(rejected) }
end
function AimbotSystem.SetTargetMode(mode)
	assert(mode == "Balanced" or mode == "Smart" or mode == "Sticky" or mode == "Nearest", "Unknown target mode")
	Config.TargetMode = mode
	releaseTarget()
end
function AimbotSystem.SetCrosshairWeight(value)
	Config.CrosshairWeight = finite(value, "Crosshair weight", 0, 1)
	challenger, challengerTime = nil, 0
end
function AimbotSystem.GetCrosshairWeight() return Config.CrosshairWeight end
function AimbotSystem.GetTargetMode() return Config.TargetMode end
function AimbotSystem.SetSwitchDelay(value)
	Config.SwitchDelay = finite(value, "Switch delay", 0.1, 1)
	challenger, challengerTime = nil, 0
end
function AimbotSystem.GetSwitchDelay() return Config.SwitchDelay end
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
