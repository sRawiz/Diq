local AimbotSystem = {}

-- ==========================================
-- Services
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- Constants
-- ==========================================
local FOV_CIRCLE_SIDES = 60
local FOV_CIRCLE_ZINDEX = 999
local SMOOTHING_MULTIPLIER = 10 -- ตัวคูณสำหรับ exponential smoothing
local DEFAULT_FOV_RADIUS = 150
local DEFAULT_SMOOTHING = 0.5

-- ==========================================
-- Config
-- ==========================================
local Config = {
	Enabled = false,
	AimMethod = "Camera", -- "Camera" หรือ "Mouse"
	ShowFOV = false,
	FOVRadius = DEFAULT_FOV_RADIUS,
	FOVColor = Color3.fromRGB(255, 255, 255),
	Smoothing = DEFAULT_SMOOTHING, -- 0.01 (Slow) to 1.0 (Instant)
	AimPart = "Head",
	WallCheck = false,
	TeamCheck = true,
}

-- ==========================================
-- State
-- ==========================================
local IsAiming = false
local CurrentTarget = nil -- locked target (Part reference)
local FOVCircle = nil
local Connections = {} -- เก็บ connections ทั้งหมดเพื่อ cleanup

-- ==========================================
-- Helpers
-- ==========================================

--- ดึง CurrentCamera สดทุกครั้ง ป้องกันกรณี camera เปลี่ยน (cutscene, respawn)
local function GetCamera()
	return workspace.CurrentCamera
end

--- ตรวจสอบว่า Part ยังมองเห็นได้ (ไม่โดนกำแพงบัง)
local function IsVisible(targetPart)
	if not Config.WallCheck then return true end

	local character = LocalPlayer.Character
	if not character then return false end

	local camera = GetCamera()
	if not camera then return false end

	local rayOrigin = camera.CFrame.Position
	local rayDirection = targetPart.Position - rayOrigin -- ✅ ไม่ต้อง .Unit * .Magnitude

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if result and result.Instance then
		-- ถ้าชนอะไรที่ไม่ใช่ตัวของเป้าหมาย = โดนกำแพงบัง
		return result.Instance:IsDescendantOf(targetPart.Parent)
	end

	return true
end

--- ตรวจสอบว่า target ปัจจุบันยังใช้ได้อยู่ไหม (ยังมีชีวิต, ยังอยู่ใน FOV, ยังมองเห็น)
local function IsTargetValid(targetPart)
	if not targetPart then return false end
	if not targetPart.Parent then return false end

	-- ตรวจว่า character ยังอยู่
	local character = targetPart.Parent
	if not character:IsDescendantOf(workspace) then return false end

	-- ตรวจว่ายังมีชีวิต
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- ตรวจว่ายังอยู่บนหน้าจอและอยู่ใน FOV
	local camera = GetCamera()
	if not camera then return false end

	local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
	if not onScreen then return false end

	-- ใช้จุดกึ่งกลางจอถ้าเป็นโหมดเมาส์, ใช้พิกัดเมาส์ถ้าเป็นโหมดกล้อง
	local centerPos
	if Config.AimMethod == "Mouse" then
		local viewportSize = camera.ViewportSize
		centerPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	else
		centerPos = UserInputService:GetMouseLocation()
	end

	local distance = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude
	if distance > Config.FOVRadius then return false end

	-- ตรวจ WallCheck
	if not IsVisible(targetPart) then return false end

	return true
end

--- หาเป้าหมายที่ใกล้เคอร์เซอร์ที่สุดภายใน FOV
local function GetClosestTarget()
	local camera = GetCamera()
	if not camera then return nil end

	-- ใช้จุดกึ่งกลางจอถ้าเป็นโหมดเมาส์, ใช้พิกัดเมาส์ถ้าเป็นโหมดกล้อง
	local centerPos
	if Config.AimMethod == "Mouse" then
		local viewportSize = camera.ViewportSize
		centerPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	else
		centerPos = UserInputService:GetMouseLocation()
	end

	local closestTarget = nil
	local shortestDistance = Config.FOVRadius

	for _, player in Players:GetPlayers() do -- ✅ Luau generalized iteration
		if player == LocalPlayer then continue end

		-- Team Check
		if Config.TeamCheck then
			if player.Team and player.Team == LocalPlayer.Team and not player.Neutral then
				continue
			end
		end

		local char = player.Character
		if not char then continue end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local targetPart = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("HumanoidRootPart")

		if not humanoid or humanoid.Health <= 0 or not targetPart then continue end

		local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then continue end

		local distance = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude

		if distance < shortestDistance and IsVisible(targetPart) then
			shortestDistance = distance
			closestTarget = targetPart
		end
	end

	return closestTarget
end

-- ==========================================
-- FOV Circle (Drawing API)
-- ==========================================
local function CreateFOVCircle()
	local circle = nil
	pcall(function()
		circle = Drawing.new("Circle")
		circle.Thickness = 1
		circle.NumSides = FOV_CIRCLE_SIDES
		circle.Radius = Config.FOVRadius
		circle.Filled = false
		circle.Visible = false
		circle.ZIndex = FOV_CIRCLE_ZINDEX
		circle.Transparency = 1
		circle.Color = Config.FOVColor
	end)
	return circle
end

local function DestroyFOVCircle()
	if FOVCircle then
		pcall(function()
			FOVCircle:Remove()
		end)
		FOVCircle = nil
	end
end

-- ==========================================
-- Input Handling
-- ==========================================
local function OnInputBegan(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsAiming = true
	end
end

local function OnInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsAiming = false
		CurrentTarget = nil -- ปล่อย lock เมื่อปล่อยคลิก
	end
end

-- ==========================================
-- Main Render Loop
-- ==========================================
local function OnRenderStepped(deltaTime)
	-- อัพเดท FOV Circle
	if FOVCircle then
		FOVCircle.Radius = Config.FOVRadius
		FOVCircle.Color = Config.FOVColor
		FOVCircle.Visible = Config.ShowFOV and Config.Enabled
		if Config.ShowFOV then
			FOVCircle.Position = UserInputService:GetMouseLocation()
		end
	end

	-- Aiming Logic
	if not Config.Enabled or not IsAiming then return end

	-- ✅ Target Locking: หา target ใหม่เฉพาะเมื่อ target เก่าหลุด
	if not IsTargetValid(CurrentTarget) then
		CurrentTarget = GetClosestTarget()
	end

	if not CurrentTarget then return end

	local camera = GetCamera()
	if not camera then return end

	-- ✅ Frame-rate independent smoothing (exponential decay)
	-- ไม่ว่า 60fps หรือ 240fps ความเร็วการเล็งจะเท่ากัน
	local factor = 1 - math.exp(-Config.Smoothing * SMOOTHING_MULTIPLIER * deltaTime)
	factor = math.clamp(factor, 0.001, 1)

	if Config.AimMethod == "Camera" then
		-- เล็งด้วยการหมุน CFrame ของกล้องโดยตรง (ใช้ได้ดีในเกมทั่วไป)
		local targetPos = CurrentTarget.Position
		local camPos = camera.CFrame.Position
		local newCFrame = CFrame.new(camPos, targetPos)
		
		camera.CFrame = camera.CFrame:Lerp(newCFrame, factor)
	elseif Config.AimMethod == "Mouse" then
		-- เล็งด้วยการจำลองการเลื่อนเมาส์ (ใช้แก้ปัญหาเกม FPS หนักๆ เช่น ENTRENCHED, Arsenal)
		local screenPos, onScreen = camera:WorldToViewportPoint(CurrentTarget.Position)
		if onScreen then
			-- เอาพิกัดของจุดกึ่งกลางจอภาพ (เป้าปืน) แทนที่จะใช้ MouseLocation
			-- เกม FPS ขยับกล้องจากเป้ากลางจอเสมอ
			local viewportSize = camera.ViewportSize
			local centerX = viewportSize.X / 2
			local centerY = viewportSize.Y / 2
			
			local deltaX = screenPos.X - centerX
			local deltaY = screenPos.Y - centerY
			
			-- FPS เกมต้องการ input แบบ relative
			-- ใช้ Smoothness ควบคุมความเร็วโดยตรง (0.01 - 1.0)
			-- ปรับจูนให้ 1.0 คือเมาส์สะบัดเข้าเป้าเร็วมาก (แต่ไม่เกินระยะห่าง)
			local speedMultiplier = Config.Smoothing * 0.8
			
			local moveX = deltaX * speedMultiplier
			local moveY = deltaY * speedMultiplier
			
			-- บังคับขยับขั้นต่ำ 1 พิกเซล ถ้าเป้ายังไม่ตรงเป๊ะ ป้องกันเมาส์ติด
			if math.abs(deltaX) > 1 and math.abs(moveX) < 1 then moveX = deltaX > 0 and 1 or -1 end
			if math.abs(deltaY) > 1 and math.abs(moveY) < 1 then moveY = deltaY > 0 and 1 or -1 end
			
			if type(mousemoverel) == "function" then
				mousemoverel(moveX, moveY)
			end
		end
	end
end

-- ==========================================
-- Initialize / Destroy
-- ==========================================
local function Initialize()
	-- สร้าง FOV Circle
	FOVCircle = CreateFOVCircle()

	-- เชื่อมต่อ events และเก็บ connection ไว้
	Connections.InputBegan = UserInputService.InputBegan:Connect(OnInputBegan)
	Connections.InputEnded = UserInputService.InputEnded:Connect(OnInputEnded)
	Connections.RenderStepped = RunService.RenderStepped:Connect(OnRenderStepped)
end

--- ทำลายทุกอย่าง ป้องกัน leak เมื่อ execute ซ้ำ
function AimbotSystem.Destroy()
	-- Disconnect ทุก connection
	for name, connection in Connections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(Connections)

	-- ลบ FOV Circle
	DestroyFOVCircle()

	-- Reset state
	IsAiming = false
	CurrentTarget = nil
end

-- ==========================================
-- Public API — Setters
-- ==========================================
function AimbotSystem.SetEnabled(state)
	Config.Enabled = state
	if not state then
		CurrentTarget = nil -- ปล่อย lock เมื่อปิด
	end
end

function AimbotSystem.SetAimMethod(method)
	if method == "Camera" or method == "Mouse" then
		Config.AimMethod = method
	end
end

function AimbotSystem.SetShowFOV(state) Config.ShowFOV = state end
function AimbotSystem.SetFOVRadius(val) Config.FOVRadius = val end
function AimbotSystem.SetFOVColor(color) Config.FOVColor = color end
function AimbotSystem.SetSmoothing(val) Config.Smoothing = math.clamp(val, 0.01, 1) end
function AimbotSystem.SetAimPart(part) Config.AimPart = part end
function AimbotSystem.SetWallCheck(state) Config.WallCheck = state end
function AimbotSystem.SetTeamCheck(state) Config.TeamCheck = state end

-- ==========================================
-- Public API — Getters
-- ==========================================
function AimbotSystem.IsEnabled() return Config.Enabled end
function AimbotSystem.GetAimMethod() return Config.AimMethod end
function AimbotSystem.GetShowFOV() return Config.ShowFOV end
function AimbotSystem.GetFOVRadius() return Config.FOVRadius end
function AimbotSystem.GetFOVColor() return Config.FOVColor end
function AimbotSystem.GetSmoothing() return Config.Smoothing end
function AimbotSystem.GetAimPart() return Config.AimPart end
function AimbotSystem.GetWallCheck() return Config.WallCheck end
function AimbotSystem.GetTeamCheck() return Config.TeamCheck end
function AimbotSystem.IsAiming() return IsAiming end
function AimbotSystem.GetCurrentTarget() return CurrentTarget end

--- คืน Config ทั้งก้อน (read-only copy)
function AimbotSystem.GetConfig()
	local copy = {}
	for k, v in Config do
		copy[k] = v
	end
	return copy
end

-- ==========================================
-- Boot
-- ==========================================
Initialize()

return AimbotSystem
