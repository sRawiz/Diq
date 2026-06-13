local ESPSystem = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Configuration state
local Config = {
    Enabled = false,
    Boxes = false,
    Names = false,
    Tracers = false,
    Health = false,
    Highlights = true,
    UseTeamColor = true,
    Color = Color3.fromRGB(255, 0, 50),
}

-- Store drawings and instances per player
local ESP_Cache = {}

-- Create a secure folder in CoreGui to store highlights
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "Diq_ESP_Holder"
local success = pcall(function()
    ESPFolder.Parent = CoreGui
end)
if not success then 
	ESPFolder.Parent = game:GetService("Lighting") 
end

local function GetColor(player)
    if Config.UseTeamColor and player.Team then
        return player.TeamColor.Color
    end
    return Config.Color
end

local function CreateESP(player)
    if ESP_Cache[player] then return end
    
    local cache = {}
    
    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Name = player.Name .. "_ESP"
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = ESPFolder
    cache.Highlight = hl

    -- Drawings (Box, Name, Tracer)
    pcall(function()
        local box = Drawing.new("Square")
        box.Thickness = 1
        box.Filled = false
        box.Transparency = 1
        cache.Box = box

        local text = Drawing.new("Text")
        text.Size = 16
        text.Center = true
        text.Outline = true
        cache.Name = text

        local tracer = Drawing.new("Line")
        tracer.Thickness = 1
        cache.Tracer = tracer
        
        local healthBg = Drawing.new("Square")
        healthBg.Thickness = 1
        healthBg.Filled = true
        healthBg.Transparency = 1
        healthBg.Color = Color3.fromRGB(0, 0, 0)
        cache.HealthBg = healthBg
        
        local healthBar = Drawing.new("Square")
        healthBar.Thickness = 1
        healthBar.Filled = true
        healthBar.Transparency = 1
        cache.HealthBar = healthBar
    end)
    
    ESP_Cache[player] = cache
end

local function RemoveESP(player)
    local cache = ESP_Cache[player]
    if cache then
        if cache.Highlight then cache.Highlight:Destroy() end
        if cache.Box then cache.Box:Remove() end
        if cache.Name then cache.Name:Remove() end
        if cache.Tracer then cache.Tracer:Remove() end
        if cache.HealthBg then cache.HealthBg:Remove() end
        if cache.HealthBar then cache.HealthBar:Remove() end
        ESP_Cache[player] = nil
    end
end

-- Update Loop
local function UpdateESP()
    for player, cache in pairs(ESP_Cache) do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if Config.Enabled and character and rootPart and humanoid and humanoid.Health > 0 and player ~= LocalPlayer then
            local color = GetColor(player)
            
            -- Highlight logic
            if cache.Highlight then
                cache.Highlight.Enabled = Config.Highlights
                cache.Highlight.Adornee = character
                cache.Highlight.FillColor = color
                cache.Highlight.OutlineColor = color
            end
            
            -- W2S Calculations for Drawings
            if cache.Box and cache.Name and cache.Tracer then
				local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
				local head = character:FindFirstChild("Head")
				
                if onScreen and head then
                    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                    
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 2
                    
                    -- Box
                    cache.Box.Visible = Config.Boxes
                    if Config.Boxes then
                        cache.Box.Size = Vector2.new(width, height)
                        cache.Box.Position = Vector2.new(rootPos.X - width/2, headPos.Y)
                        cache.Box.Color = color
                    end
                    
                    -- Name
                    cache.Name.Visible = Config.Names
                    if Config.Names then
                        local distance = math.floor((Camera.CFrame.Position - rootPart.Position).Magnitude)
                        cache.Name.Text = string.format("%s [%d]", player.Name, distance)
                        cache.Name.Position = Vector2.new(rootPos.X, headPos.Y - 20)
                        cache.Name.Color = color
                    end
                    
                    -- Tracer
                    cache.Tracer.Visible = Config.Tracers
                    if Config.Tracers then
                        cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        cache.Tracer.To = Vector2.new(rootPos.X, legPos.Y)
                        cache.Tracer.Color = color
                    end
                    
                    -- Health Bar
                    if cache.HealthBg and cache.HealthBar then
                        cache.HealthBg.Visible = Config.Health
                        cache.HealthBar.Visible = Config.Health
                        
                        if Config.Health then
                            local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            
                            -- สีเลือด (เขียว -> เหลือง -> แดง)
                            local healthColor = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), healthPct)
                            
                            local barWidth = 3
                            local offset = 5
                            
                            -- Background
                            cache.HealthBg.Size = Vector2.new(barWidth, height)
                            cache.HealthBg.Position = Vector2.new(rootPos.X - width/2 - offset - barWidth, headPos.Y)
                            
                            -- Fill
                            local fillHeight = height * healthPct
                            cache.HealthBar.Size = Vector2.new(barWidth, fillHeight)
                            cache.HealthBar.Position = Vector2.new(rootPos.X - width/2 - offset - barWidth, headPos.Y + (height - fillHeight))
                            cache.HealthBar.Color = healthColor
                        end
                    end
                else
                    cache.Box.Visible = false
                    cache.Name.Visible = false
                    cache.Tracer.Visible = false
                    if cache.HealthBg then cache.HealthBg.Visible = false end
                    if cache.HealthBar then cache.HealthBar.Visible = false end
                end
            end
        else
            -- If not enabled, dead, or no character, hide everything
            if cache.Highlight then cache.Highlight.Enabled = false end
            if cache.Box then cache.Box.Visible = false end
            if cache.Name then cache.Name.Visible = false end
            if cache.Tracer then cache.Tracer.Visible = false end
            if cache.HealthBg then cache.HealthBg.Visible = false end
            if cache.HealthBar then cache.HealthBar.Visible = false end
        end
    end
end

-- Initialize events
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

RunService.RenderStepped:Connect(UpdateESP)

-- Exposed API
function ESPSystem.SetEnabled(state) Config.Enabled = state end
function ESPSystem.SetHighlights(state) Config.Highlights = state end
function ESPSystem.SetBoxes(state) Config.Boxes = state end
function ESPSystem.SetNames(state) Config.Names = state end
function ESPSystem.SetTracers(state) Config.Tracers = state end
function ESPSystem.SetHealth(state) Config.Health = state end
function ESPSystem.SetUseTeamColor(state) Config.UseTeamColor = state end

return ESPSystem
