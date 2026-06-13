local HitboxSystem = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = false,
    Size = 5,
    Transparency = 0.5,
    TargetPart = "Head",
    TeamCheck = true,
}

local OriginalProperties = {} -- [Player] = { Head = {Size, Trans}, HumanoidRootPart = {Size, Trans} }

local function IsTeammate(player)
    if not Config.TeamCheck then return false end
    if player.Neutral then return false end
    if player.Team and player.Team == LocalPlayer.Team then return true end
    return false
end

-- เซฟค่าเริ่มต้นของชิ้นส่วนตัวละคร (ป้องกันการเซฟค่าที่ขยายไปแล้ว)
local function SaveOriginal(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    local props = {}
    if head and head.Size.Magnitude < 10 then 
        props.Head = { Size = head.Size, Transparency = head.Transparency, CanCollide = head.CanCollide }
    end
    if root and root.Size.Magnitude < 10 then
        props.HumanoidRootPart = { Size = root.Size, Transparency = root.Transparency, CanCollide = root.CanCollide }
    end
    return props
end

-- คืนค่า Hitbox ดั้งเดิมให้ทุกคน
local function RevertHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and OriginalProperties[player] then
            local char = player.Character
            for partName, props in pairs(OriginalProperties[player]) do
                local part = char:FindFirstChild(partName)
                if part then
                    part.Size = props.Size
                    part.Transparency = props.Transparency
                    part.CanCollide = props.CanCollide
                end
            end
        end
    end
end

-- วงจรควบคุมขนาด Hitbox ตลอดเวลา
RunService.Stepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                -- ถ้าเพิ่งเกิด ให้เซฟค่าดั้งเดิมเก็บไว้
                if not OriginalProperties[player] then
                    OriginalProperties[player] = SaveOriginal(char)
                end
                
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local targetPart = char:FindFirstChild(Config.TargetPart)
                    
                    if Config.Enabled and not IsTeammate(player) then
                        if targetPart then
                            targetPart.Size = Vector3.new(Config.Size, Config.Size, Config.Size)
                            targetPart.Transparency = Config.Transparency
                            targetPart.CanCollide = false
                        end
                    end
                end
            end
        end
    end
end)

-- รีเซ็ตค่าดั้งเดิมเวลามีคนเกิดใหม่
local function HandlePlayer(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5) -- รอให้ตัวโหลดเสร็จ
        OriginalProperties[player] = SaveOriginal(char)
    end)
end

Players.PlayerAdded:Connect(HandlePlayer)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then HandlePlayer(player) end
end

Players.PlayerRemoving:Connect(function(player)
    OriginalProperties[player] = nil
end)

-- APIs
function HitboxSystem.SetEnabled(state) 
    Config.Enabled = state
    if not state then RevertHitboxes() end
end

function HitboxSystem.SetSize(val) 
    Config.Size = val 
end

function HitboxSystem.SetTransparency(val) 
    Config.Transparency = val 
end

function HitboxSystem.SetTargetPart(part) 
    RevertHitboxes() -- คืนค่าเดิมก่อนย้ายไปขยายส่วนอื่น
    Config.TargetPart = part 
end

function HitboxSystem.SetTeamCheck(state) 
    Config.TeamCheck = state 
    if state then RevertHitboxes() end -- คืนค่าเดิมให้เพื่อนร่วมทีมถ้าเพิ่งเปิดเช็ค
end

return HitboxSystem
