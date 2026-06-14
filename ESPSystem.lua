local ESPSystem = {}

-- ==========================================
-- Services
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- Constants
-- ==========================================
local TEXT_SIZE_NAME = 16
local TEXT_SIZE_HP = 14
local HEALTH_BAR_WIDTH = 3
local HEALTH_BAR_OFFSET = 5
local HEALTH_COLOR_LOW = Color3.fromRGB(255, 0, 0)
local HEALTH_COLOR_FULL = Color3.fromRGB(0, 255, 0)

-- ==========================================
-- Config
-- ==========================================
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

-- ==========================================
-- State
-- ==========================================
local ESP_Cache = {} -- [Player] = { Highlight, Box, Name, Tracer, HealthBg, HealthBar, HpText }
local ESPFolder = nil
local Connections = {}

-- ==========================================
-- Helpers
-- ==========================================
local function GetCamera()
	return workspace.CurrentCamera
end

local function GetColor(player)
	if Config.UseTeamColor and player.Team then
		return player.TeamColor.Color
	end
	return Config.Color
end

--- สร้าง Drawing object อย่างปลอดภัย (แต่ละตัวแยก pcall — ถ้าตัวใดพัง ตัวอื่นยังใช้ได้)
local function CreateDrawingSafe(drawingType, props)
	local obj = nil
	pcall(function()
		obj = Drawing.new(drawingType)
		for key, value in props do
			obj[key] = value
		end
	end)
	return obj
end

-- ==========================================
-- Drawing Update Functions — แยกแต่ละ element
-- ==========================================
local function UpdateBox(cache, screenData, color)
	if not cache.Box then return end
	cache.Box.Visible = Config.Boxes
	if not Config.Boxes then return end

	cache.Box.Size = Vector2.new(screenData.Width, screenData.Height)
	cache.Box.Position = Vector2.new(screenData.RootX - screenData.Width / 2, screenData.HeadY)
	cache.Box.Color = color
end

local function UpdateName(cache, screenData, color, playerName, distance)
	if not cache.Name then return end
	cache.Name.Visible = Config.Names
	if not Config.Names then return end

	cache.Name.Text = string.format("%s [%dm]", playerName, distance)
	cache.Name.Position = Vector2.new(screenData.RootX, screenData.HeadY - 20)
	cache.Name.Color = color
end

local function UpdateTracer(cache, screenData, color, viewportSize)
	if not cache.Tracer then return end
	cache.Tracer.Visible = Config.Tracers
	if not Config.Tracers then return end

	cache.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
	cache.Tracer.To = Vector2.new(screenData.RootX, screenData.LegY)
	cache.Tracer.Color = color
end

local function UpdateHealthBar(cache, screenData, humanoid)
	local hasHealthElements = cache.HealthBg and cache.HealthBar
	if not hasHealthElements then return end

	cache.HealthBg.Visible = Config.Health
	cache.HealthBar.Visible = Config.Health
	if cache.HpText then cache.HpText.Visible = Config.Health end

	if not Config.Health then return end

	local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	local healthColor = HEALTH_COLOR_LOW:Lerp(HEALTH_COLOR_FULL, healthPct)
	local barX = screenData.RootX - screenData.Width / 2 - HEALTH_BAR_OFFSET - HEALTH_BAR_WIDTH

	-- Background
	cache.HealthBg.Size = Vector2.new(HEALTH_BAR_WIDTH, screenData.Height)
	cache.HealthBg.Position = Vector2.new(barX, screenData.HeadY)

	-- Fill
	local fillHeight = screenData.Height * healthPct
	cache.HealthBar.Size = Vector2.new(HEALTH_BAR_WIDTH, fillHeight)
	cache.HealthBar.Position = Vector2.new(barX, screenData.HeadY + (screenData.Height - fillHeight))
	cache.HealthBar.Color = healthColor

	-- HP Text
	if cache.HpText then
		cache.HpText.Text = string.format("[%d HP]", math.floor(humanoid.Health))
		cache.HpText.Position = Vector2.new(screenData.RootX, screenData.LegY + 2)
		cache.HpText.Color = healthColor
	end
end

local function HideAllDrawings(cache)
	if cache.Box then cache.Box.Visible = false end
	if cache.Name then cache.Name.Visible = false end
	if cache.Tracer then cache.Tracer.Visible = false end
	if cache.HealthBg then cache.HealthBg.Visible = false end
	if cache.HealthBar then cache.HealthBar.Visible = false end
	if cache.HpText then cache.HpText.Visible = false end
end

-- ==========================================
-- ESP Cache Management
-- ==========================================
local function CreateESPFolder()
	local folder = Instance.new("Folder")
	folder.Name = "Diq_ESP_Holder"
	local success = pcall(function()
		folder.Parent = CoreGui
	end)
	if not success then
		folder.Parent = game:GetService("Lighting") -- Fallback สำหรับ executor ที่ไม่รองรับ CoreGui
	end
	return folder
end

local function CreateESP(player)
	if ESP_Cache[player] then return end
	if player == LocalPlayer then return end

	local cache = {}

	-- Highlight (Instance-based)
	local hl = Instance.new("Highlight")
	hl.Name = player.Name .. "_ESP"
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = ESPFolder
	cache.Highlight = hl

	-- Drawings (แต่ละตัว pcall แยก)
	cache.Box = CreateDrawingSafe("Square", {
		Thickness = 1, Filled = false, Transparency = 1,
	})
	cache.Name = CreateDrawingSafe("Text", {
		Size = TEXT_SIZE_NAME, Center = true, Outline = true,
	})
	cache.Tracer = CreateDrawingSafe("Line", {
		Thickness = 1,
	})
	cache.HealthBg = CreateDrawingSafe("Square", {
		Thickness = 1, Filled = true, Transparency = 1,
		Color = Color3.fromRGB(0, 0, 0),
	})
	cache.HealthBar = CreateDrawingSafe("Square", {
		Thickness = 1, Filled = true, Transparency = 1,
	})
	cache.HpText = CreateDrawingSafe("Text", {
		Size = TEXT_SIZE_HP, Center = true, Outline = true,
	})

	ESP_Cache[player] = cache
end

local function RemoveESP(player)
	local cache = ESP_Cache[player]
	if not cache then return end

	if cache.Highlight then cache.Highlight:Destroy() end
	if cache.Box then cache.Box:Remove() end
	if cache.Name then cache.Name:Remove() end
	if cache.Tracer then cache.Tracer:Remove() end
	if cache.HealthBg then cache.HealthBg:Remove() end
	if cache.HealthBar then cache.HealthBar:Remove() end
	if cache.HpText then cache.HpText:Remove() end

	ESP_Cache[player] = nil
end

local function RemoveAllESP()
	for player in ESP_Cache do
		RemoveESP(player)
	end
end

-- ==========================================
-- Main Update Loop
-- ==========================================
local function UpdateESP()
	local camera = GetCamera()
	if not camera then return end

	for player, cache in ESP_Cache do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local isValid = Config.Enabled and character and rootPart and humanoid
			and humanoid.Health > 0 and player ~= LocalPlayer

		if not isValid then
			if cache.Highlight then cache.Highlight.Enabled = false end
			HideAllDrawings(cache)
			continue
		end

		local color = GetColor(player)

		-- Highlight
		if cache.Highlight then
			cache.Highlight.Enabled = Config.Highlights
			cache.Highlight.Adornee = character
			cache.Highlight.FillColor = color
			cache.Highlight.OutlineColor = color
		end

		-- คำนวณตำแหน่งบนหน้าจอ
		local rootPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
		local head = character:FindFirstChild("Head")

		if not onScreen or not head then
			HideAllDrawings(cache)
			continue
		end

		local headPos = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
		local legPos = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

		local height = math.abs(headPos.Y - legPos.Y)
		local width = height / 2
		local distance = math.floor((camera.CFrame.Position - rootPart.Position).Magnitude)

		-- รวม screen data เป็น struct เพื่อส่งให้ sub-functions
		local screenData = {
			RootX = rootPos.X,
			HeadY = headPos.Y,
			LegY = legPos.Y,
			Height = height,
			Width = width,
		}

		UpdateBox(cache, screenData, color)
		UpdateName(cache, screenData, color, player.Name, distance)
		UpdateTracer(cache, screenData, color, camera.ViewportSize)
		UpdateHealthBar(cache, screenData, humanoid)
	end
end

-- ==========================================
-- Initialize / Destroy
-- ==========================================
local function Initialize()
	ESPFolder = CreateESPFolder()

	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			CreateESP(player)
		end
	end

	Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
		CreateESP(player)
	end)

	Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		RemoveESP(player)
	end)

	Connections.RenderStepped = RunService.RenderStepped:Connect(UpdateESP)
end

--- ทำลายทุกอย่าง ป้องกัน leak เมื่อ execute ซ้ำ
function ESPSystem.Destroy()
	for _, connection in Connections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(Connections)

	RemoveAllESP()

	if ESPFolder then
		ESPFolder:Destroy()
		ESPFolder = nil
	end
end

-- ==========================================
-- Public API — Setters
-- ==========================================
function ESPSystem.SetEnabled(state)
	Config.Enabled = state
	if not state then
		for _, cache in ESP_Cache do
			if cache.Highlight then cache.Highlight.Enabled = false end
			HideAllDrawings(cache)
		end
	end
end

function ESPSystem.SetHighlights(state) Config.Highlights = state end
function ESPSystem.SetBoxes(state) Config.Boxes = state end
function ESPSystem.SetNames(state) Config.Names = state end
function ESPSystem.SetTracers(state) Config.Tracers = state end
function ESPSystem.SetHealth(state) Config.Health = state end
function ESPSystem.SetUseTeamColor(state) Config.UseTeamColor = state end
function ESPSystem.SetColor(color) Config.Color = color end

-- ==========================================
-- Public API — Getters
-- ==========================================
function ESPSystem.IsEnabled() return Config.Enabled end
function ESPSystem.GetHighlights() return Config.Highlights end
function ESPSystem.GetBoxes() return Config.Boxes end
function ESPSystem.GetNames() return Config.Names end
function ESPSystem.GetTracers() return Config.Tracers end
function ESPSystem.GetHealth() return Config.Health end
function ESPSystem.GetUseTeamColor() return Config.UseTeamColor end
function ESPSystem.GetColor() return Config.Color end

function ESPSystem.GetConfig()
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

return ESPSystem
