-- INSERT_MOCKS
-- INSERT_MODULES
local baseline = liveConnections()
local misc, statuses, urls, teleports, pages
local function reset()
	if misc then misc.Destroy() end
	statuses, urls, teleports, pages = {}, {}, {}, {}
	misc = factories.MiscSystem()
	misc.SetServerListener(function(phase, message) table.insert(statuses, {phase, message}) end)
	function game:HttpGet(url)
		table.insert(urls, url)
		return tostring(#urls)
	end
	function services.HttpService:JSONDecode(body) return pages[tonumber(body)] end
	function services.HttpService:UrlEncode(value)
		return (value:gsub("[^%w]", function(c) return string.format("%%%02X", string.byte(c)) end))
	end
	function TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
		table.insert(teleports, {placeId, jobId, player})
	end
	function TeleportService:Teleport(placeId, player) table.insert(teleports, {placeId, nil, player}) end
end
local function server(id, count, max) return {id=id, playing=count or 1, maxPlayers=max or 10} end
local function lastPhase() return statuses[#statuses][1] end
reset()
pages = {
	{data={server(game.JobId), server("full",10), {id="bad",playing="1",maxPlayers=10}}, nextPageCursor="a+/="},
	{data={server("new")}},
}
check(misc.ServerHop(), "Search starts")
check(not misc.ServerHop() and not misc.Rejoin(), "Search locks both server actions")
advance(0)
check(#urls == 1 and #teleports == 0, "Skip current, full and malformed servers")
advance(0.3)
check(#urls == 2 and string.find(urls[2], "cursor=a%2B%2F%3D", 1, true), "Follow and encode cursor")
check(#teleports == 1 and teleports[1][1] == game.PlaceId and teleports[1][2] == "new" and teleports[1][3] == own,
	"Teleport local player to another instance in the same place")
check(lastPhase() == "Teleporting" and not misc.ServerHop() and not misc.Rejoin(), "Request acceptance is not teleport completion")
TeleportService.TeleportInitFailed:Fire(enemy, Enum.TeleportResult.GameFull, "secret", game.PlaceId)
TeleportService.TeleportInitFailed:Fire(own, Enum.TeleportResult.GameFull, "secret", 99)
TeleportService.TeleportInitFailed:Fire(own, Enum.TeleportResult.GameFull, "secret", game.PlaceId, {ServerInstanceId="other"})
check(lastPhase() == "Teleporting", "Ignore unrelated failures")
TeleportService.TeleportInitFailed:Fire(own, Enum.TeleportResult.GameFull, "secret", game.PlaceId, {ServerInstanceId="new"})
check(lastPhase() == "Failed" and string.find(statuses[#statuses][2], "full", 1, true), "Report async full-server failure")
check(TeleportService.TeleportInitFailed:Count() == 0 and misc.ServerHop(), "Failure releases connection and lock")
misc.CancelServerSearch()

reset(); pages = {{data={}}}
misc.ServerHop(); advance(0)
check(lastPhase() == "Failed" and #teleports == 0, "No candidate never falls back to current server")
check(misc.ServerHop(), "Empty list allows retry"); misc.CancelServerSearch()
reset(); game.HttpGet = nil
misc.ServerHop(); advance(0)
check(lastPhase() == "Failed" and string.find(statuses[#statuses][2], "HttpGet", 1, true), "Missing executor HTTP support is actionable")
reset(); function game:HttpGet() error("secret-response-body") end
misc.ServerHop(); advance(0)
check(lastPhase() == "Failed" and string.find(statuses[#statuses][2], "download", 1, true), "Download error is distinguished")
check(not string.find(statuses[#statuses][2], "secret", 1, true), "Network errors do not expose bodies")
reset(); function services.HttpService:JSONDecode() error("secret-json") end
misc.ServerHop(); advance(0)
check(lastPhase() == "Failed" and string.find(statuses[#statuses][2], "response", 1, true), "JSON error is distinguished")
reset(); pages = {{data={}}, {data={}}}; pages[1].nextPageCursor="repeat"; pages[2].nextPageCursor="repeat"
misc.ServerHop(); advance(0); advance(0.3)
check(lastPhase() == "Failed" and #urls == 2, "Repeated cursor cannot loop forever")
reset(); pages = {{data={}, nextPageCursor=123}}
misc.ServerHop(); advance(0)
check(lastPhase() == "Failed", "Invalid cursor is rejected")
reset()
for i=1,11 do pages[i]={data={},nextPageCursor=tostring(i)} end
misc.ServerHop(); advance(0)
for _=1,10 do advance(0.31) end
check(lastPhase() == "Failed" and #urls == 10, "Search has a fixed page budget")

reset(); pages = {{data={server("new")}}}
function TeleportService:TeleportToPlaceInstance() error("secret-teleport") end
misc.ServerHop(); advance(0)
check(lastPhase() == "Failed" and TeleportService.TeleportInitFailed:Count() == 0, "Synchronous teleport failure releases resources")
check(misc.Rejoin() == false and lastPhase() == "Failed", "Rejoin keeps boolean failure result")
reset(); pages = {{data={server("new")}}}
misc.ServerHop(); advance(0); advance(45)
check(lastPhase() == "Failed" and misc.ServerHop(), "Missing teleport event times out and permits retry")
misc.CancelServerSearch()

reset(); pages = {{data={server("new")}}}
local lateResponse
function game:HttpGet()
	lateResponse = coroutine.running()
	task.wait(60)
	return "1"
end
misc.ServerHop(); advance(0)
check(misc.CancelServerSearch() and lastPhase() == "Cancelled", "Cancel works during yielding HTTP")
check(coroutine.status(lateResponse) == "dead", "Cancelled HTTP coroutine is closed")
advance(60)
check(#teleports == 0 and #statuses == 2, "Late HTTP response cannot teleport or notify")
misc.ServerHop(); advance(0); advance(30)
check(lastPhase() == "Failed" and #teleports == 0, "Hanging HTTP times out")

reset(); pages = {{data={server("new")}}}
misc.ServerHop(); misc.Destroy(); advance(60)
check(#urls == 0 and #teleports == 0 and #statuses == 1, "Destroy before queued search prevents work")
reset(); pages = {{data={server("new")}}}
misc.ServerHop(); advance(0)
local before = #statuses
misc.Destroy(); misc.Destroy()
TeleportService.TeleportInitFailed:Fire(own, Enum.TeleportResult.Flooded, "secret", game.PlaceId)
advance(60)
check(#statuses == before and liveConnections() == baseline and next(queue) == nil, "Destroy releases server handlers and tasks")
check(not misc.ServerHop() and not misc.Rejoin(), "Destroyed module cannot start more work")
reset()
check(misc.Rejoin() and teleports[1][2] == game.JobId, "Existing Rejoin targets current server")
check(not misc.ServerHop(), "Rejoin and server hop share a lock")
misc.Destroy(); advance(60)
check(liveConnections() == baseline and next(queue) == nil, "Repeated module sessions leave no server resources")
print("Misc: " .. checks .. " checks passed")
