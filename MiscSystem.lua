local MiscSystem = {}

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Rejoin Server (เข้าเซิร์ฟเวอร์เดิม)
function MiscSystem.Rejoin()
    -- ถ้านี่เป็นเซิร์ฟเวอร์ส่วนตัวหรือเซิร์ฟที่ไม่มีคนอื่น การออกอาจจะทำให้เซิร์ฟปิดตัวได้
    if #Players:GetPlayers() <= 1 then
        LocalPlayer:Kick("\nRejoining...\n(Please wait...)")
        task.wait()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local fullbrightConnection = nil

local originalLighting = {}

-- ปรับสว่าง 100% และลบหมอก (Fullbright & No Fog)
function MiscSystem.SetFullbright(enable)
    if enable then
        if not fullbrightConnection then
            -- เก็บค่าแสงสว่างดั้งเดิมเอาไว้ก่อน
            originalLighting.Ambient = Lighting.Ambient
            originalLighting.ColorShift_Bottom = Lighting.ColorShift_Bottom
            originalLighting.ColorShift_Top = Lighting.ColorShift_Top
            originalLighting.GlobalShadows = Lighting.GlobalShadows
            originalLighting.FogEnd = Lighting.FogEnd
            originalLighting.Brightness = Lighting.Brightness

            -- บังคับเปลี่ยนค่าแสงทุกเฟรม (ป้องกันเกมเปลี่ยนกลับ)
            fullbrightConnection = RunService.RenderStepped:Connect(function()
                Lighting.Ambient = Color3.new(1, 1, 1)
                Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
                Lighting.ColorShift_Top = Color3.new(1, 1, 1)
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9 -- ลบหมอกให้มองเห็นได้ไกลสุดๆ
                Lighting.Brightness = 2
            end)
        end
    else
        if fullbrightConnection then
            fullbrightConnection:Disconnect()
            fullbrightConnection = nil
            
            -- คืนค่าแสงสว่างดั้งเดิมให้กับเกม
            if originalLighting.Ambient then
                Lighting.Ambient = originalLighting.Ambient
                Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
                Lighting.ColorShift_Top = originalLighting.ColorShift_Top
                Lighting.GlobalShadows = originalLighting.GlobalShadows
                Lighting.FogEnd = originalLighting.FogEnd
                Lighting.Brightness = originalLighting.Brightness
            end
        end
    end
end

return MiscSystem
