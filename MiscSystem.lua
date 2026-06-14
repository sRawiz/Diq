local MiscSystem = {}

-- ==========================================
-- Services
-- ==========================================
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- Constants
-- ==========================================
local FULLBRIGHT_AMBIENT = Color3.new(1, 1, 1)
local FULLBRIGHT_BRIGHTNESS = 2
local FULLBRIGHT_FOG_END = 9e9

-- ==========================================
-- State
-- ==========================================
local Connections = {}
local OriginalLighting = {}
local State = {
	IsFullbright = false,
	IsAntiAFK = false,
}

-- ==========================================
-- Rejoin
-- ==========================================
function MiscSystem.Rejoin()
	local success, err = pcall(function()
		if #Players:GetPlayers() <= 1 then
			-- เซิร์ฟเวอร์มีคนเดียว อาจปิดตัวหลังออก ต้อง Teleport ใหม่
			LocalPlayer:Kick("\nRejoining...\n(Please wait...)")
			task.wait()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end
	end)

	if not success then
		warn("[Diq] Rejoin failed:", err)
	end
end

-- ==========================================
-- Fullbright & No Fog
-- ==========================================
function MiscSystem.SetFullbright(enable)
	State.IsFullbright = enable

	if enable then
		if not Connections.Fullbright then
			-- เก็บค่าแสงสว่างดั้งเดิม
			OriginalLighting = {
				Ambient = Lighting.Ambient,
				ColorShift_Bottom = Lighting.ColorShift_Bottom,
				ColorShift_Top = Lighting.ColorShift_Top,
				GlobalShadows = Lighting.GlobalShadows,
				FogEnd = Lighting.FogEnd,
				Brightness = Lighting.Brightness,
			}

			-- บังคับเปลี่ยนค่าแสงทุกเฟรม (ป้องกันเกมเปลี่ยนกลับ)
			Connections.Fullbright = RunService.RenderStepped:Connect(function()
				Lighting.Ambient = FULLBRIGHT_AMBIENT
				Lighting.ColorShift_Bottom = FULLBRIGHT_AMBIENT
				Lighting.ColorShift_Top = FULLBRIGHT_AMBIENT
				Lighting.GlobalShadows = false
				Lighting.FogEnd = FULLBRIGHT_FOG_END
				Lighting.Brightness = FULLBRIGHT_BRIGHTNESS
			end)
		end
	else
		if Connections.Fullbright then
			Connections.Fullbright:Disconnect()
			Connections.Fullbright = nil

			-- คืนค่าแสงสว่างดั้งเดิม
			if OriginalLighting.Ambient then
				Lighting.Ambient = OriginalLighting.Ambient
				Lighting.ColorShift_Bottom = OriginalLighting.ColorShift_Bottom
				Lighting.ColorShift_Top = OriginalLighting.ColorShift_Top
				Lighting.GlobalShadows = OriginalLighting.GlobalShadows
				Lighting.FogEnd = OriginalLighting.FogEnd
				Lighting.Brightness = OriginalLighting.Brightness
			end
			table.clear(OriginalLighting)
		end
	end
end

-- ==========================================
-- Anti-AFK (ป้องกันโดนเตะเมื่ออยู่นิ่งๆ 20 นาที)
-- ==========================================
function MiscSystem.SetAntiAFK(enable)
	State.IsAntiAFK = enable

	if enable then
		if not Connections.AntiAFK then
			-- ดึง VirtualUser แบบ pcall เผื่อ executor ไม่รองรับ
			local VirtualUser = nil
			pcall(function()
				VirtualUser = game:GetService("VirtualUser")
			end)

			if not VirtualUser then
				warn("[Diq] Anti-AFK: VirtualUser service not available on this executor")
				State.IsAntiAFK = false
				return
			end

			Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
				pcall(function()
					VirtualUser:CaptureController()
					VirtualUser:ClickButton2(Vector2.new())
				end)
			end)
		end
	else
		if Connections.AntiAFK then
			Connections.AntiAFK:Disconnect()
			Connections.AntiAFK = nil
		end
	end
end

-- ==========================================
-- Destroy / Cleanup
-- ==========================================
function MiscSystem.Destroy()
	-- คืนค่า Fullbright ก่อนปิด
	if State.IsFullbright then
		MiscSystem.SetFullbright(false)
	end

	-- ปิด Anti-AFK
	if State.IsAntiAFK then
		MiscSystem.SetAntiAFK(false)
	end

	-- Disconnect ที่เหลือ (ถ้ามี)
	for key, connection in Connections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(Connections)

	State.IsFullbright = false
	State.IsAntiAFK = false
end

-- ==========================================
-- Public API — Getters
-- ==========================================
function MiscSystem.IsFullbright() return State.IsFullbright end
function MiscSystem.IsAntiAFK() return State.IsAntiAFK end

function MiscSystem.GetState()
	return {
		IsFullbright = State.IsFullbright,
		IsAntiAFK = State.IsAntiAFK,
	}
end

return MiscSystem
