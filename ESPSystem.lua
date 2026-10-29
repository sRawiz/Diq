local ModuleOptions = ...
local initialized = false
local destroyed = false

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
	UseTeamColor = false,
	ColorMode = "Relation",
	ShowTeammates = true,
	ShowEnemies = true,
	ShowUnknown = true,
	ShowRelation = true,
	TeamAttribute = "", -- Optional Player attribute; never guess game-specific team fields.
	MaxDistance = 0, -- Studs; 0 means unlimited.
	TeammateColor = Color3.fromRGB(80, 200, 255),
	EnemyColor = Color3.fromRGB(255, 70, 90),
	UnknownColor = Color3.fromRGB(255, 200, 80),
	Color = Color3.fromRGB(255, 0, 50),
}

-- ==========================================
-- State
-- ==========================================
local ESP_Cache = {} -- [Player] = { Highlight, Box, Name, Tracer, HealthBg, HealthBar, HpText }
local ESPFolder = nil
local Connections = {}
local drawingWarningShown = false

-- ==========================================
-- Helpers
-- ==========================================
local function GetCamera()
	return workspace.CurrentCamera
end

local function GetRelation(player)
	if player == LocalPlayer then return "Self" end
	if Config.TeamAttribute ~= "" then
		local ownTeam = LocalPlayer:GetAttribute(Config.TeamAttribute)
		local otherTeam = player:GetAttribute(Config.TeamAttribute)
		-- Missing/custom neutral values must not accidentally become enemies.
		if ownTeam == nil or otherTeam == nil or ownTeam == "" or otherTeam == ""
			or ownTeam ~= ownTeam or otherTeam ~= otherTeam
			or (type(ownTeam) ~= "string" and type(ownTeam) ~= "number")
			or (type(otherTeam) ~= "string" and type(otherTeam) ~= "number") then
			return "Unknown"
		end
		return ownTeam == otherTeam and "Teammate" or "Enemy"
	end
	if LocalPlayer.Neutral or player.Neutral or not LocalPlayer.Team or not player.Team then
		return "Unknown"
	end
	return player.Team == LocalPlayer.Team and "Teammate" or "Enemy"
end

local function GetColor(player, relation)
	if Config.ColorMode == "Team" and not player.Neutral and player.Team then
		return player.TeamColor.Color
	end
	if Config.ColorMode ~= "Uniform" then
		if relation == "Teammate" then return Config.TeammateColor end
		if relation == "Enemy" then return Config.EnemyColor end
		return Config.UnknownColor
	end
	return Config.Color
end

--- สร้าง Drawing object อย่างปลอดภัย (แต่ละตัวแยก pcall — ถ้าตัวใดพัง ตัวอื่นยังใช้ได้)
local function CreateDrawingSafe(drawingType, props)
	local obj = nil
	local success = pcall(function()
		obj = Drawing.new(drawingType)
		obj.Visible = false
		for key, value in props do
			obj[key] = value
		end
	end)
	if not success then
		if obj then pcall(function() obj:Remove() end) end
		obj = nil
		if not drawingWarningShown then
			drawingWarningShown = true
			warn("[Diq ESP] Drawing creation failed. Boxes, names, tracers or health may be unavailable; use Highlights or an executor with a compatible Drawing API.")
		end
	end
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

	cache.Name.Text = string.format("%s [%d studs]", playerName, distance)
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

	local healthPct = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
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

local function HideESP(cache)
	if cache.Highlight then
		cache.Highlight.Enabled = false
		cache.Highlight.Adornee = nil
	end
	HideAllDrawings(cache)
end

local function HideAllESP()
	for _, cache in ESP_Cache do HideESP(cache) end
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
		-- A workspace folder also supports Highlights without privileged CoreGui access.
		folder.Parent = workspace
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
	hl.Enabled = false
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

	-- One executor object failing cleanup must not leave the remaining objects behind.
	for key, object in cache do
		pcall(function()
			if key == "Highlight" then object:Destroy() else object:Remove() end
		end)
	end

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
	if destroyed or not Config.Enabled then return end
	local camera = GetCamera()
	if not camera then HideAllESP(); return end

	for player, cache in ESP_Cache do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local isValid = Config.Enabled and character and rootPart and humanoid
			and rootPart:IsA("BasePart") and character:IsDescendantOf(workspace)
			and humanoid.Health > 0 and player ~= LocalPlayer

		if not isValid then
			HideESP(cache)
			continue
		end

		local relation = GetRelation(player)
		local allowed = (relation == "Teammate" and Config.ShowTeammates)
			or (relation == "Enemy" and Config.ShowEnemies)
			or (relation == "Unknown" and Config.ShowUnknown)
		local distance = (camera.CFrame.Position - rootPart.Position).Magnitude
		if not allowed or (Config.MaxDistance > 0 and distance > Config.MaxDistance) then
			HideESP(cache)
			continue
		end
		local color = GetColor(player, relation)

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

		-- ✅ Fallback if Head is missing (ENTRENCHED and some FPS games don't have Head initially)
		local headWorldPos = head and head:IsA("BasePart") and head.Position or (rootPart.Position + Vector3.new(0, 1.5, 0))
		local headPos = camera:WorldToViewportPoint(headWorldPos + Vector3.new(0, 0.5, 0))
		local legPos = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

		if not onScreen or rootPos.Z <= 0 or headPos.Z <= 0 or legPos.Z <= 0 then
			HideAllDrawings(cache)
			continue
		end

		local height = math.abs(headPos.Y - legPos.Y)
		local width = height / 2

		-- รวม screen data เป็น struct เพื่อส่งให้ sub-functions
		local screenData = {
			RootX = rootPos.X,
			HeadY = headPos.Y,
			LegY = legPos.Y,
			Height = height,
			Width = width,
		}

		UpdateBox(cache, screenData, color)
		local label = Config.ShowRelation and ("[" .. relation .. "] " .. player.Name) or player.Name
		UpdateName(cache, screenData, color, label, math.floor(distance))
		UpdateTracer(cache, screenData, color, camera.ViewportSize)
		UpdateHealthBar(cache, screenData, humanoid)
	end
end

-- ==========================================
-- Initialize / Destroy
-- ==========================================
local function Initialize()
	ESPFolder = CreateESPFolder()
	-- Connect before enumeration so joins during startup cannot be missed.
	Connections.PlayerAdded = Players.PlayerAdded:Connect(CreateESP)
	Connections.PlayerRemoving = Players.PlayerRemoving:Connect(RemoveESP)

	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			CreateESP(player)
		end
	end

	if Config.Enabled then Connections.RenderStepped = RunService.RenderStepped:Connect(UpdateESP) end
end

--- ทำลายทุกอย่าง ป้องกัน leak เมื่อ execute ซ้ำ
function ESPSystem.Destroy()
	if destroyed then return end
	destroyed = true
	Config.Enabled = false
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
	if destroyed then return end
	Config.Enabled = state == true
	if Config.Enabled and initialized and not Connections.RenderStepped then
		Connections.RenderStepped = RunService.RenderStepped:Connect(UpdateESP)
	elseif not Config.Enabled then
		if Connections.RenderStepped then Connections.RenderStepped:Disconnect() end
		Connections.RenderStepped = nil
		HideAllESP()
	end
end

function ESPSystem.SetHighlights(state) Config.Highlights = state end
function ESPSystem.SetBoxes(state) Config.Boxes = state end
function ESPSystem.SetNames(state) Config.Names = state end
function ESPSystem.SetTracers(state) Config.Tracers = state end
function ESPSystem.SetHealth(state) Config.Health = state end
-- Legacy false retains the old single-color behavior; the new UI selects Relation explicitly.
function ESPSystem.SetUseTeamColor(state)
	ESPSystem.SetColorMode(state and "Team" or "Uniform")
end
function ESPSystem.SetColor(color) Config.Color = color end

function ESPSystem.SetColorMode(mode: string)
	assert(mode == "Relation" or mode == "Team" or mode == "Uniform", "Invalid ESP color mode")
	Config.ColorMode = mode
	Config.UseTeamColor = mode == "Team"
end

function ESPSystem.SetRelationVisible(relation: string, visible: boolean)
	local key = ({ Teammate = "ShowTeammates", Enemy = "ShowEnemies", Unknown = "ShowUnknown" })[relation]
	assert(key, "Invalid ESP relation")
	Config[key] = visible == true
	HideAllESP()
end

function ESPSystem.SetRelationColor(relation: string, color: Color3)
	local key = ({ Teammate = "TeammateColor", Enemy = "EnemyColor", Unknown = "UnknownColor" })[relation]
	assert(key and typeof(color) == "Color3", "Expected ESP relation and Color3")
	Config[key] = color
end

function ESPSystem.SetShowRelation(state: boolean) Config.ShowRelation = state == true end

function ESPSystem.SetTeamAttribute(attribute: string)
	assert(type(attribute) == "string", "Expected Player team attribute name (empty uses Roblox teams)")
	Config.TeamAttribute = attribute
	HideAllESP()
end

function ESPSystem.SetMaxDistance(distance: number)
	assert(type(distance) == "number" and distance == distance and distance >= 0 and distance < math.huge,
		"Expected finite nonnegative distance in studs")
	Config.MaxDistance = distance
	HideAllESP()
end

function ESPSystem.GetRelation(player: Player): string return GetRelation(player) end

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
function ESPSystem.Init()
	if destroyed then error("[Diq] Cannot initialize a destroyed module") end
	if initialized then return end
	initialized = true
	Initialize()
end

-- Keep direct module execution compatible; Main explicitly defers initialization.
if type(ModuleOptions) ~= "table" or not ModuleOptions.DeferInit then
	ESPSystem.Init()
end

return ESPSystem
