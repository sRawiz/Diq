local AimbotSystem = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = false,
    ShowFOV = false,
    FOVRadius = 150,
    Smoothing = 0.5, -- 0.01 (Slow) to 1.0 (Instant)
    AimPart = "Head",
    WallCheck = false,
    TeamCheck = true,
}

local FOVCircle
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 60
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Filled = false
    FOVCircle.Visible = false
    FOVCircle.ZIndex = 999
    FOVCircle.Transparency = 1
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
end)

local IsAiming = false
local CurrentTarget = nil

-- Listen for Aim button (Right Click)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsAiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsAiming = false
        CurrentTarget = nil
    end
end)

-- Check if part is visible (WallCheck)
local function IsVisible(targetPart)
    if not Config.WallCheck then return true end
    local character = LocalPlayer.Character
    if not character then return false end
    
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = (targetPart.Position - rayOrigin).Unit * (targetPart.Position - rayOrigin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    
    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    -- If it hit something, and that something is NOT part of the target's character, it's behind a wall
    if result and result.Instance and not result.Instance:IsDescendantOf(targetPart.Parent) then
        return false
    end
    return true
end

-- Find closest target to mouse inside FOV
local function GetClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closestTarget = nil
    local shortestDistance = Config.FOVRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Team Check (Skip if teammate, UNLESS they are Neutral/FFA)
            if Config.TeamCheck then
                if player.Team and player.Team == LocalPlayer.Team and not player.Neutral then
                    continue
                end
            end
            
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local targetPart = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("HumanoidRootPart")
                
                if humanoid and humanoid.Health > 0 and targetPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        
                        if distance < shortestDistance and IsVisible(targetPart) then
                            shortestDistance = distance
                            closestTarget = targetPart
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

-- Main Loop
RunService.RenderStepped:Connect(function()
    -- Update FOV Circle
    if FOVCircle then
        FOVCircle.Radius = Config.FOVRadius
        FOVCircle.Visible = Config.ShowFOV and Config.Enabled
        if Config.ShowFOV then
            FOVCircle.Position = UserInputService:GetMouseLocation()
        end
    end

    -- Aiming Logic
    if Config.Enabled and IsAiming then
        CurrentTarget = GetClosestTarget()
        
        if CurrentTarget then
            local targetPos = CurrentTarget.Position
            local camPos = Camera.CFrame.Position
            local newCFrame = CFrame.new(camPos, targetPos)
            
            -- Smoothing formula: Camera.CFrame = Camera.CFrame:Lerp(goal, speed)
            local lerpSpeed = math.clamp(Config.Smoothing, 0.01, 1)
            Camera.CFrame = Camera.CFrame:Lerp(newCFrame, lerpSpeed)
        end
    end
end)

-- API
function AimbotSystem.SetEnabled(state) Config.Enabled = state end
function AimbotSystem.SetShowFOV(state) Config.ShowFOV = state end
function AimbotSystem.SetFOVRadius(val) Config.FOVRadius = val end
function AimbotSystem.SetSmoothing(val) Config.Smoothing = val end
function AimbotSystem.SetAimPart(part) Config.AimPart = part end
function AimbotSystem.SetWallCheck(state) Config.WallCheck = state end
function AimbotSystem.SetTeamCheck(state) Config.TeamCheck = state end

return AimbotSystem
