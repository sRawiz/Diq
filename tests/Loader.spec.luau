-- INSERT_MOCKS
-- INSERT_MODULES
local baseline=liveConnections()
local captured={}
local function instrument()
	local result={}
	for name,factory in factories do
		if name~="Main" then
			result[name]=function(...)
				local module=factory(...); captured[name]=module; return module
			end
		end
	end
	return result
end
local app,err=factories.Main({Factories=instrument()})
check(app~=nil, "Full Main startup: "..tostring(err))
check(not app.Destroyed and type(_G.DiqCleanup)=="function","Main registers active session")
check(app:GetDiagnostics().Revision=="bundled/local","Diagnostics distinguish bundled/local sources")
check(RunService.PreSimulation:Count()==0 and RunService.RenderStepped:Count()==0 and next(RunService.bindings)==nil,"All features remain idle at startup")
captured.MovementSystem.SetNoClip(true); RunService.PreSimulation:Fire(1/60)
check(not own.Character.Head.CanCollide,"Main injects working runtime into features")
local second=factories.Main({Factories=instrument()})
check(second and app.Destroyed and own.Character.Head.CanCollide,"Repeated execution stops and restores previous session")
second:Destroy(); second:Destroy(); advance(20); advance(0)
check(_G.DiqCleanup==nil and liveConnections()==baseline,"Full Main teardown releases everything")
-- Failure halfway through initialization rolls all already-loaded modules back.
local broken=instrument()
broken.AimbotSystem=function() return {Init=function() error("test init") end,Destroy=function() end} end
local failed=factories.Main({Factories=broken})
advance(20); advance(0)
check(failed==nil and liveConnections()==baseline,"Invalid module contract rolls back partial startup")
broken=instrument()
local original=broken.ESPSystem
broken.ESPSystem=function(...)
	local module=original(...)
	module.Init=function() error("test init") end
	return module
end
failed=factories.Main({Factories=broken}); advance(20); advance(0)
check(failed==nil and liveConnections()==baseline,"Initialization failure destroys loaded resources")
-- Network and compiler substitutes exercise the real production loader stages.
local urls={}
services.HttpService={JSONDecode=function() return {sha=string.rep("a",40)} end}
function game:HttpGet(url)
	table.insert(urls,url)
	if string.find(url,"api.github.com",1,true) then return "commit metadata" end
	local name=string.match(url,"/([^/]+)%.lua$")
	return name
end
loadstring=function(source) return factories[source] end
local remote=factories.Main()
check(remote~=nil,"Remote loader starts with resolved revision")
check(#urls==9,"One revision resolution plus eight module downloads")
for i=2,#urls do check(string.find(urls[i],string.rep("a",40),1,true)~=nil,"All downloads use one immutable revision") end
remote:Destroy(); advance(20); advance(0)
check(liveConnections()==baseline,"Remote-loaded session cleans up")
local beforeWarnings=#warnings
function game:HttpGet() error("secret-response-body") end
check(factories.Main()==nil,"Download failure is handled")
check(string.find(warnings[#warnings],"download",1,true)~=nil,"Download stage is actionable")
check(not string.find(warnings[#warnings],"secret-response-body",1,true),"Loader does not log network response contents")
loadstring=function() return nil,"invalid syntax" end
check(factories.Main({Sources={Infrastructure="invalid"}})==nil,"Compile failure is handled")
check(string.find(warnings[#warnings],"compile",1,true)~=nil,"Compile stage distinguished")
loadstring=function() return function() error("runtime error") end end
check(factories.Main({Sources={Infrastructure="valid"}})==nil,"Runtime failure is handled")
check(string.find(warnings[#warnings],"execution",1,true)~=nil,"Execution stage distinguished")
check(#warnings>beforeWarnings and liveConnections()==baseline,"Failure paths leave no session resources")
loadstring=nil
local bundled=factories.Bundle()
check(bundled~=nil,"Built artifact starts without HTTP or loadstring")
bundled:Destroy(); advance(20); advance(0)
check(liveConnections()==baseline,"Built artifact cleans up like the source entry point")
print("Loader checks passed: "..checks)
