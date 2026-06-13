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

return MiscSystem
