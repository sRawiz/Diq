-- ==========================================
-- ⚙️ Module: Movement System
-- ==========================================

local Movement = {}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CONFIG = {
    FlySpeed = 100,
    CFrameSpeed = 60,
    UpKey = Enum.KeyCode.Space,
    DownKey = Enum.KeyCode.LeftControl,
}

local State = {
    IsFlying = false,
    IsCFrameSpeed = false
}

local renderConnection = nil

local function getCharacterData()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Humanoid")
end

local function toggleAntiGravity(enable)
    local rootPart = getCharacterData()
    if not rootPart then return end

    if enable then
        if not rootPart:FindFirstChild("FlyAttachment") then
            local attachment = Instance.new("Attachment", rootPart)
            attachment.Name = "FlyAttachment"
            
            local lv = Instance.new("LinearVelocity", rootPart)
            lv.Name = "FlyVelocity"
            lv.Attachment0 = attachment
            lv.MaxForce = math.huge
            lv.VectorVelocity = Vector3.zero
        end
    else
        local att = rootPart:FindFirstChild("FlyAttachment")
        local lv = rootPart:FindFirstChild("FlyVelocity")
        if att then att:Destroy() end
        if lv then lv:Destroy() end
    end
end

local function onRenderStepped(deltaTime)
    local rootPart, humanoid = getCharacterData()
    if not rootPart or not humanoid then return end

    if State.IsFlying then
        local moveVector = Vector3.zero
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(CONFIG.UpKey) then moveVector += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(CONFIG.DownKey) then moveVector -= Vector3.new(0, 1, 0) end
        
        if moveVector.Magnitude > 0 then moveVector = moveVector.Unit end
        
        local rootPos = rootPart.Position
        local cameraLook = Camera.CFrame.LookVector
        local lookAtPos = rootPos + Vector3.new(cameraLook.X, 0, cameraLook.Z)
        
        rootPart.CFrame = CFrame.new(rootPos, lookAtPos) + (moveVector * CONFIG.FlySpeed * deltaTime)
        
    elseif State.IsCFrameSpeed then
        local walkDir = humanoid.MoveDirection
        if walkDir.Magnitude > 0 then
            walkDir = Vector3.new(walkDir.X, 0, walkDir.Z).Unit
            rootPart.CFrame = rootPart.CFrame + (walkDir * CONFIG.CFrameSpeed * deltaTime)
        end
    end
end

local function UpdateRenderConnection()
    if (State.IsFlying or State.IsCFrameSpeed) and not renderConnection then
        renderConnection = RunService.RenderStepped:Connect(onRenderStepped)
    elseif not State.IsFlying and not State.IsCFrameSpeed and renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
end

-- [ ฟังก์ชันสาธารณะ ]

function Movement.SetFly(enable)
    State.IsFlying = enable
    local rootPart, humanoid = getCharacterData()
    if humanoid then
        humanoid.PlatformStand = enable
        toggleAntiGravity(enable)
    end
    UpdateRenderConnection()
end

function Movement.SetSpeed(enable)
    State.IsCFrameSpeed = enable
    UpdateRenderConnection()
end

function Movement.ResetCharacter()
    local rootPart, humanoid = getCharacterData()
    if humanoid then
        humanoid.Health = 0
    end
end

function Movement.Unanchor()
    local rootPart = getCharacterData()
    if rootPart then
        rootPart.Anchored = false
    end
end

-- รีเซ็ตค่าตอนตัวละครตาย
LocalPlayer.CharacterAdded:Connect(function()
    State.IsFlying = false
    State.IsCFrameSpeed = false
    UpdateRenderConnection()
end)

return Movement
