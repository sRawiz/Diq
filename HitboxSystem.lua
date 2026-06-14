local HitboxSystem = {}

-- ==========================================
-- Services
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- Constants
-- ==========================================
local MAX_ORIGINAL_SIZE_MAGNITUDE = 10 -- ถ้า Part ใหญ่กว่านี้ ถือว่าถูก expand ไปแล้ว ไม่ save
local CHARACTER_LOAD_DELAY = 0.5       -- วินาทีที่รอให้ตัวละครโหลดเสร็จ

-- ==========================================
-- Config
-- ==========================================
local Config = {
	Enabled = false,
	Size = 5,
	Transparency = 0.5,
	TargetPart = "Head",
	TeamCheck = true,
}

-- ==========================================
-- State
-- ==========================================
local OriginalProperties = {} -- [Player] = { PartName = { Size, Transparency, CanCollide } }
local Connections = {}

-- ==========================================
-- Helpers
-- ==========================================
local function IsTeammate(player)
	if not Config.TeamCheck then return false end
	if player.Neutral then return false end
	if player.Team and player.Team == LocalPlayer.Team then return true end
	return false
end

--- บันทึกค่าเดิมของ Part (ป้องกัน save ค่าที่ expand ไปแล้ว)
local function SaveOriginal(char)
	if not char then return nil end

	local props = {}
	local partsToSave = { "Head", "HumanoidRootPart" }

	for _, partName in partsToSave do
		local part = char:FindFirstChild(partName)
		if part and part.Size.Magnitude < MAX_ORIGINAL_SIZE_MAGNITUDE then
			props[partName] = {
				Size = part.Size,
				Transparency = part.Transparency,
				CanCollide = part.CanCollide,
			}
		end
	end

	return props
end

--- คืนค่า Hitbox ดั้งเดิมให้ผู้เล่นคนเดียว
local function RevertPlayer(player)
	if not OriginalProperties[player] then return end

	local char = player.Character
	if not char then return end

	for partName, props in OriginalProperties[player] do
		local part = char:FindFirstChild(partName)
		if part then
			part.Size = props.Size
			part.Transparency = props.Transparency
			part.CanCollide = props.CanCollide
		end
	end
end

--- คืนค่า Hitbox ดั้งเดิมให้ทุกคน
local function RevertAllHitboxes()
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			RevertPlayer(player)
		end
	end
end

-- ==========================================
-- Core Logic
-- ==========================================
local function OnStepped()
	if not Config.Enabled then return end -- ✅ Early return เมื่อปิด

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then continue end
		if IsTeammate(player) then continue end

		local char = player.Character
		if not char then continue end

		-- Save ค่าเดิมถ้ายังไม่มี
		if not OriginalProperties[player] then
			OriginalProperties[player] = SaveOriginal(char)
		end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		local targetPart = char:FindFirstChild(Config.TargetPart)
		if not targetPart then continue end

		targetPart.Size = Vector3.new(Config.Size, Config.Size, Config.Size)
		targetPart.Transparency = Config.Transparency
		targetPart.CanCollide = false
	end
end

local function HandleCharacterAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(CHARACTER_LOAD_DELAY)
		local char = player.Character
		if char then
			OriginalProperties[player] = SaveOriginal(char)
		end
	end)
end

-- ==========================================
-- Initialize / Destroy
-- ==========================================
local function Initialize()
	-- ลงทะเบียนผู้เล่นที่มีอยู่แล้ว
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			HandleCharacterAdded(player)
			if player.Character then
				OriginalProperties[player] = SaveOriginal(player.Character)
			end
		end
	end

	Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
		HandleCharacterAdded(player)
	end)

	Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		OriginalProperties[player] = nil
	end)

	Connections.Stepped = RunService.Stepped:Connect(OnStepped)
end

--- ทำลายทุกอย่าง ป้องกัน leak เมื่อ execute ซ้ำ
function HitboxSystem.Destroy()
	-- คืนค่าเดิมก่อนปิด
	RevertAllHitboxes()

	for _, connection in Connections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(Connections)
	table.clear(OriginalProperties)
end

-- ==========================================
-- Public API — Setters
-- ==========================================
function HitboxSystem.SetEnabled(state)
	Config.Enabled = state
	if not state then RevertAllHitboxes() end
end

function HitboxSystem.SetSize(val) Config.Size = val end

function HitboxSystem.SetTransparency(val) Config.Transparency = val end

function HitboxSystem.SetTargetPart(part)
	RevertAllHitboxes() -- คืนค่าเดิมก่อนย้ายไปขยายส่วนอื่น
	Config.TargetPart = part
end

function HitboxSystem.SetTeamCheck(state)
	Config.TeamCheck = state
	if state then RevertAllHitboxes() end
end

-- ==========================================
-- Public API — Getters
-- ==========================================
function HitboxSystem.IsEnabled() return Config.Enabled end
function HitboxSystem.GetSize() return Config.Size end
function HitboxSystem.GetTransparency() return Config.Transparency end
function HitboxSystem.GetTargetPart() return Config.TargetPart end
function HitboxSystem.GetTeamCheck() return Config.TeamCheck end

function HitboxSystem.GetConfig()
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

return HitboxSystem
