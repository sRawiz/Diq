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

-- Server Hop (สุ่มไปเซิร์ฟเวอร์อื่นที่คนไม่เต็ม)
function MiscSystem.ServerHop()
    local placeId = game.PlaceId
    -- ใช้ roproxy เพื่อหลีกเลี่ยงการถูกบล็อกจาก Roblox API
    local url = "https://games.roproxy.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        -- ถ้า proxy ล่ม ลองใช้ API โดยตรง (บาง executor รองรับ)
        success, result = pcall(function()
            return game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
        end)
    end

    if success and result then
        local decoded = false
        local data = nil
        
        pcall(function()
            data = HttpService:JSONDecode(result)
            decoded = true
        end)
        
        if decoded and data and data.data then
            local availableServers = {}
            for _, server in ipairs(data.data) do
                -- หาเซิร์ฟเวอร์ที่มีที่ว่าง และไม่ใช่เซิร์ฟเวอร์ที่เรากำลังอยู่
                if type(server) == "table" and server.id ~= game.JobId then
                    if server.playing and server.maxPlayers and server.playing < server.maxPlayers then
                        table.insert(availableServers, server.id)
                    end
                end
            end
            
            if #availableServers > 0 then
                -- สุ่มเลือก 1 เซิร์ฟเวอร์จากที่หาได้
                local randomServer = availableServers[math.random(1, #availableServers)]
                TeleportService:TeleportToPlaceInstance(placeId, randomServer, LocalPlayer)
                return true, "Found server! Teleporting..."
            else
                return false, "No available servers found."
            end
        else
            return false, "Failed to decode server data."
        end
    end
    
    return false, "Failed to fetch server list."
end

return MiscSystem
