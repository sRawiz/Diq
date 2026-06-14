-- ==========================================
-- ⚙️ Module: Movement System v3.0 (Refactored)
-- ==========================================

local Movement = {}

-- ==========================================
-- Services
-- ==========================================
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- Constants
-- ==========================================
local DEFAULT_FLY_SPEED = 100
local DEFAULT_CFRAME_SPEED = 60
local FLY_UP_KEY = Enum.KeyCode.Space
local FLY_DOWN_KEY = Enum.KeyCode.LeftControl

-- ==========================================
-- Config
-- ==========================================
local Config = {
	FlySpeed = DEFAULT_FLY_SPEED,
	CFrameSpeed = DEFAULT_CFRAME_SPEED,
}

-- ==========================================
-- State
-- ==========================================
local State = {
	IsFlying = false,
	IsCFrameSpeed = false,
	IsInfinityJump = false,
	IsNoClip = false,
	IsNoFling = false, -- ✅ เพิ่มเข้า State table ตั้งแต่แรก
}

local Connections = {} -- เก็บ connections ทั้งหมดในที่เดียว

-- ==========================================
-- Helpers
-- ==========================================

--- ดึง CurrentCamera สดทุกครั้ง ป้องกัน camera เปลี่ยน
local function GetCamera()
	return workspace.CurrentCamera
end

local function GetCharacterData()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

--- ตัดการเชื่อมต่อ connection อย่างปลอดภัย
local function SafeDisconnect(key)
	local conn = Connections[key]
	if conn and conn.Connected then
		conn:Disconnect()
	end
	Connections[key] = nil
end

--- เปิด/ปิด แรงต้านแรงโน้มถ่วง สำหรับ Fly
local function ToggleAntiGravity(enable)
	local rootPart = GetCharacterData()
	if not rootPart then return end

	if enable then
		if not rootPart:FindFirstChild("FlyAttachment") then
			local attachment = Instance.new("Attachment")
			attachment.Name = "FlyAttachment"
			attachment.Parent = rootPart

			local lv = Instance.new("LinearVelocity")
			lv.Name = "FlyVelocity"
			lv.Attachment0 = attachment
			lv.MaxForce = math.huge
			lv.VectorVelocity = Vector3.zero
			lv.Parent = rootPart
		end
	else
		local att = rootPart:FindFirstChild("FlyAttachment")
		local lv = rootPart:FindFirstChild("FlyVelocity")
		if att then att:Destroy() end
		if lv then lv:Destroy() end
	end
end

-- ==========================================
-- Core Logic — RenderStepped
-- ==========================================
local function OnRenderStepped(deltaTime)
	local rootPart, humanoid = GetCharacterData()
	if not rootPart or not humanoid then return end

	local camera = GetCamera()
	if not camera then return end

	if State.IsFlying then
		local moveVector = Vector3.zero

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector -= camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(FLY_UP_KEY) then moveVector += Vector3.yAxis end
		if UserInputService:IsKeyDown(FLY_DOWN_KEY) then moveVector -= Vector3.yAxis end

		if moveVector.Magnitude > 0 then moveVector = moveVector.Unit end

		local rootPos = rootPart.Position
		local cameraLook = camera.CFrame.LookVector
		local lookAtPos = rootPos + Vector3.new(cameraLook.X, 0, cameraLook.Z)

		rootPart.CFrame = CFrame.new(rootPos, lookAtPos) + (moveVector * Config.FlySpeed * deltaTime)

	elseif State.IsCFrameSpeed then
		local walkDir = humanoid.MoveDirection
		if walkDir.Magnitude > 0 then
			walkDir = Vector3.new(walkDir.X, 0, walkDir.Z).Unit
			rootPart.CFrame = rootPart.CFrame + (walkDir * Config.CFrameSpeed * deltaTime)
		end
	end
end

--- จัดการ RenderStepped connection — เปิดเมื่อจำเป็น ปิดเมื่อไม่ใช้
local function UpdateRenderConnection()
	local needsRender = State.IsFlying or State.IsCFrameSpeed

	if needsRender and not Connections.Render then
		Connections.Render = RunService.RenderStepped:Connect(OnRenderStepped)
	elseif not needsRender then
		SafeDisconnect("Render")
	end
end

-- ==========================================
-- Character Respawn Handler
-- ==========================================
local function OnCharacterAdded()
	-- รีเซ็ตทุก state เมื่อตัวละครเกิดใหม่
	State.IsFlying = false
	State.IsCFrameSpeed = false
	State.IsNoClip = false
	State.IsNoFling = false
	State.IsInfinityJump = false -- ✅ เพิ่ม reset InfinityJump

	UpdateRenderConnection()
	SafeDisconnect("NoClip")
	SafeDisconnect("NoFling")
	SafeDisconnect("InfinityJump") -- ✅ เพิ่ม disconnect InfinityJump
end

-- ==========================================
-- Initialize / Destroy
-- ==========================================
local function Initialize()
	Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
end

--- ทำลายทุกอย่าง ป้องกัน leak เมื่อ execute ซ้ำ
function Movement.Destroy()
	-- คืนค่า Fly state
	if State.IsFlying then
		local _, humanoid = GetCharacterData()
		if humanoid then humanoid.PlatformStand = false end
		ToggleAntiGravity(false)
	end

	-- Disconnect ทุก connection
	for key in Connections do
		SafeDisconnect(key)
	end
	table.clear(Connections)

	-- Reset state
	for key in State do
		State[key] = false
	end
end

-- ==========================================
-- Public API — Feature Controls
-- ==========================================

--- เปิด/ปิดโหมดบิน
function Movement.SetFly(enable)
	State.IsFlying = enable
	local _, humanoid = GetCharacterData()
	if humanoid then
		humanoid.PlatformStand = enable
		ToggleAntiGravity(enable)
	end
	UpdateRenderConnection()
end

--- สลับโหมดบิน
function Movement.ToggleFly()
	Movement.SetFly(not State.IsFlying)
	return State.IsFlying
end

--- เปิด/ปิดวิ่งเร็ว
function Movement.SetSpeed(enable)
	State.IsCFrameSpeed = enable
	UpdateRenderConnection()
end

--- สลับวิ่งเร็ว
function Movement.ToggleSpeed()
	Movement.SetSpeed(not State.IsCFrameSpeed)
	return State.IsCFrameSpeed
end

--- เปิด/ปิดทะลุกำแพง
function Movement.SetNoClip(enable)
	State.IsNoClip = enable
	if enable and not Connections.NoClip then
		Connections.NoClip = RunService.Stepped:Connect(function()
			if not State.IsNoClip then return end
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end)
	elseif not enable then
		SafeDisconnect("NoClip")
	end
end

--- สลับทะลุกำแพง
function Movement.ToggleNoClip()
	Movement.SetNoClip(not State.IsNoClip)
	return State.IsNoClip
end

--- เปิด/ปิด กระโดดไร้ขีดจำกัด
function Movement.SetInfinityJump(enable)
	State.IsInfinityJump = enable
	if enable and not Connections.InfinityJump then
		Connections.InfinityJump = UserInputService.JumpRequest:Connect(function()
			if not State.IsInfinityJump then return end
			local _, humanoid = GetCharacterData()
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	elseif not enable then
		SafeDisconnect("InfinityJump")
	end
end

--- เปิด/ปิด ป้องกันโดนชนปลิว
function Movement.SetNoFling(enable)
	State.IsNoFling = enable
	if enable and not Connections.NoFling then
		Connections.NoFling = RunService.Stepped:Connect(function()
			if not State.IsNoFling then return end
			for _, player in Players:GetPlayers() do
				if player ~= LocalPlayer and player.Character then
					for _, part in player.Character:GetDescendants() do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end
		end)
	elseif not enable then
		SafeDisconnect("NoFling")
	end
end

--- สลับ NoFling
function Movement.ToggleNoFling()
	Movement.SetNoFling(not State.IsNoFling)
	return State.IsNoFling
end

-- ==========================================
-- Public API — Speed Settings
-- ==========================================
function Movement.SetFlySpeed(speed) Config.FlySpeed = speed end
function Movement.SetCFrameSpeed(speed) Config.CFrameSpeed = speed end

-- ==========================================
-- Public API — Actions
-- ==========================================
function Movement.ResetCharacter()
	local _, humanoid = GetCharacterData()
	if humanoid then humanoid.Health = 0 end
end

function Movement.Unanchor()
	local rootPart = GetCharacterData()
	if rootPart then rootPart.Anchored = false end
end

-- ==========================================
-- Public API — Getters
-- ==========================================
function Movement.GetState()
	return {
		IsFlying = State.IsFlying,
		IsCFrameSpeed = State.IsCFrameSpeed,
		IsInfinityJump = State.IsInfinityJump,
		IsNoClip = State.IsNoClip,
		IsNoFling = State.IsNoFling, -- ✅ เพิ่มครบทุก state
		FlySpeed = Config.FlySpeed,
		CFrameSpeed = Config.CFrameSpeed,
	}
end

-- ==========================================
-- Boot
-- ==========================================
Initialize()

return Movement
