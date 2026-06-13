-- ==========================================
-- ⚙️ Module: Movement System v2.0
-- ==========================================
-- อัพเดท:
-- ✅ เพิ่ม SetFlySpeed / SetCFrameSpeed (ปรับค่าจาก Slider)
-- ✅ เพิ่ม ToggleFly (สลับโหมดบิน)
-- ✅ ใช้ generalized iteration (ไม่ใช้ pairs/ipairs)
-- ✅ โค้ดสะอาดขึ้น

local Movement = {}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- ⚙️ Config — ปรับค่าได้จากภายนอก
-- ==========================================
local CONFIG = {
	FlySpeed    = 100,
	CFrameSpeed = 60,
	UpKey       = Enum.KeyCode.Space,
	DownKey     = Enum.KeyCode.LeftControl,
}

local State = {
	IsFlying       = false,
	IsCFrameSpeed  = false,
	IsInfinityJump = false,
}

local renderConnection = nil

-- ==========================================
-- 🔧 Internal Functions
-- ==========================================

local function getCharacterData()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Humanoid")
end

-- เปิด/ปิด แรงต้านแรงโน้มถ่วง
local function toggleAntiGravity(enable)
	local rootPart = getCharacterData()
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
-- 🎮 RenderStepped — อัพเดททุกเฟรม
-- ==========================================
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

-- จัดการ connection อย่างปลอดภัย
local function UpdateRenderConnection()
	if (State.IsFlying or State.IsCFrameSpeed) and not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(onRenderStepped)
	elseif not State.IsFlying and not State.IsCFrameSpeed and renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- ==========================================
-- 🔧 Public API
-- ==========================================

-- เปิด/ปิดโหมดบิน
function Movement.SetFly(enable)
	State.IsFlying = enable
	local rootPart, humanoid = getCharacterData()
	if humanoid then
		humanoid.PlatformStand = enable
		toggleAntiGravity(enable)
	end
	UpdateRenderConnection()
end

-- สลับโหมดบิน (toggle)
function Movement.ToggleFly()
	Movement.SetFly(not State.IsFlying)
	return State.IsFlying
end

-- เปิด/ปิดวิ่งเร็ว
function Movement.SetSpeed(enable)
	State.IsCFrameSpeed = enable
	UpdateRenderConnection()
end

-- สลับวิ่งเร็ว (toggle)
function Movement.ToggleSpeed()
	Movement.SetSpeed(not State.IsCFrameSpeed)
	return State.IsCFrameSpeed
end

-- ตั้งค่าความเร็วบิน (ใช้กับ Slider)
function Movement.SetFlySpeed(speed)
	CONFIG.FlySpeed = speed
end

-- ตั้งค่าความเร็ววิ่ง (ใช้กับ Slider)
function Movement.SetCFrameSpeed(speed)
	CONFIG.CFrameSpeed = speed
end

-- เปิด/ปิด กระโดดไร้ขีดจำกัด (Infinity Jump)
local jumpConnection = nil
function Movement.SetInfinityJump(enable)
	State.IsInfinityJump = enable
	if enable and not jumpConnection then
		jumpConnection = UserInputService.JumpRequest:Connect(function()
			if State.IsInfinityJump then
				local _, humanoid = getCharacterData()
				if humanoid then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	elseif not enable and jumpConnection then
		jumpConnection:Disconnect()
		jumpConnection = nil
	end
end

-- รีเซ็ตตัวละคร
function Movement.ResetCharacter()
	local _, humanoid = getCharacterData()
	if humanoid then
		humanoid.Health = 0
	end
end

-- ปลดล็อค Anchor
function Movement.Unanchor()
	local rootPart = getCharacterData()
	if rootPart then
		rootPart.Anchored = false
	end
end

-- ดึงสถานะปัจจุบัน
function Movement.GetState()
	return {
		IsFlying = State.IsFlying,
		IsCFrameSpeed = State.IsCFrameSpeed,
		FlySpeed = CONFIG.FlySpeed,
		CFrameSpeed = CONFIG.CFrameSpeed,
	}
end

-- ==========================================
-- 🔄 รีเซ็ตค่าตอนตัวละครตาย / respawn
-- ==========================================
LocalPlayer.CharacterAdded:Connect(function()
	State.IsFlying = false
	State.IsCFrameSpeed = false
	UpdateRenderConnection()
end)

return Movement
