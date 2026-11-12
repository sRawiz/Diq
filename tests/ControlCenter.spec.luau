-- INSERT_MOCKS
-- Executor filesystem/clipboard and engine JSON boundary are simulated.
-- JSON parsing itself belongs to Roblox HttpService, not the implementation.
local disk, folders, clipboard = {}, {}, nil
local writefile = function(path, data) disk[path] = data end
local readfile = function(path) return assert(disk[path], "missing") end
local makefolder = function(path) folders[path] = true end
local isfolder = function(path) return folders[path] == true end
local setclipboard = function(text) clipboard = text end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for key, v in value do result[key] = copy(v) end; return result
end
local encoded, sequence = {}, 0
function services.HttpService:JSONEncode(value)
	sequence += 1; local key = "{mock-json:" .. sequence .. "}"; encoded[key] = copy(value); return key
end
function services.HttpService:JSONDecode(text) return copy(assert(encoded[text], "bad JSON")) end
-- INSERT_MODULES
local rawMain = factories.Main
factories.Main = function(...) return runYielding(rawMain, ...) end
local baseline = liveConnections()
local captured, injected = {}, {}
for name, factory in factories do
	if name ~= "Main" then injected[name] = function(...) local module = factory(...); captured[name] = module; return module end end
end
local app, err = factories.Main({Factories=injected})
check(app ~= nil, "Control center starts with production UI: " .. tostring(err))
local tools = app.Tools
local settings, keys = tools.Settings, tools.Keys
check(tools.QuickTab._content.Visible, "Workspace opens on Quick Actions")
check(tools.Controls["movement.cframe_fly"].Tab.Name == "Movement"
	and tools.Controls["movement.cframe_fly"].Widget.Root.Parent.Name == "SettingsSection",
	"Grouped controls preserve profile identifiers and navigate to their owning page")
local function labelObject(text)
	for _, object in instances do
		if object.ClassName=="TextLabel" and object.Text==text and object.Parent then return object end
	end
	error("Missing UI label: "..text)
end
local function click(text)
	local button=labelObject(text).Parent
	task.spawn(function() button.MouseButton1Click:Fire() end)
	advance(0); advance(0.1); advance(0.3)
end
local function inputBox(text)
	for _, child in labelObject(text).Parent.children do
		if child.ClassName=="TextBox" then return child end
		if child.ClassName=="ScrollingFrame" then for _, nested in child.children do if nested.ClassName=="TextBox" then return nested end end end
	end
	error("Missing text box")
end

-- Players page is wired to the real directory, camera controller and End shortcut.
local directoryRow
for _, object in instances do
	if object.Name == "Player_" .. tostring(enemy.UserId) and object.Parent then directoryRow = object; break end
end
check(directoryRow ~= nil, "Players page contains another player's row")
directoryRow.Activated:Fire()
camera.CameraSubject, camera.CameraType = own.Character.Humanoid, Enum.CameraType.Custom
click("Spectate")
check(captured.PlayerSystem.GetSnapshot().SpectatingUserId == enemy.UserId and camera.CameraSubject == enemy.Character.Humanoid,
	"Players row and Spectate action drive the real camera controller")
click("Stop Spectating")
check(not captured.PlayerSystem.GetSnapshot().SpectatingUserId and camera.CameraSubject == own.Character.Humanoid,
	"Stop Spectating action restores own camera")
click("Spectate")
Input.InputBegan:Fire({KeyCode=Enum.KeyCode.End, UserInputType=Enum.UserInputType.Keyboard}, false)
Input.InputEnded:Fire({KeyCode=Enum.KeyCode.End, UserInputType=Enum.UserInputType.Keyboard}, false)
check(not captured.PlayerSystem.GetSnapshot().SpectatingUserId and camera.CameraSubject == own.Character.Humanoid,
	"End emergency shortcut restores the camera too")
check(#settings.Order >= 30 and #keys.Order == 13, "Feature settings and shortcuts registered centrally")
check(Input.InputBegan:Count() == 1, "Shared dispatcher keeps one engine InputBegan connection")
local function press(key, processed) Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[key]},processed or false) end
local function release(key) Input.InputEnded:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[key]}) end
local serverDownloads = 0
function game:HttpGet()
	serverDownloads += 1
	task.wait(60)
	return "unused late response"
end
click("Find New Server")
check(serverDownloads == 1 and not captured.MiscSystem.ServerHop(), "Find New Server button starts one guarded search")
click("Cancel Server Search")
check(not captured.MiscSystem.CancelServerSearch(), "Cancel button stops the active search")
click("Find New Server")
press("End"); release("End")
check(not captured.MiscSystem.CancelServerSearch(), "Emergency stop cancels server discovery")
game.HttpGet = nil
local matchmakingCalls = 0
local originalTeleport = TeleportService.Teleport
function TeleportService:Teleport(placeId, player)
	check(placeId == game.PlaceId and player == own, "Best Server button requests matchmaking for the local player")
	matchmakingCalls += 1
end
click("Find Best Server (Roblox)")
check(matchmakingCalls == 1 and not captured.MiscSystem.ServerHop(), "Best Server button uses the shared teleport lock")
TeleportService.TeleportInitFailed:Fire(own, Enum.TeleportResult.Flooded, "test", game.PlaceId)
check(warnings[#warnings] == "[Diq] Too many teleport requests. Wait a moment and try again.",
	"Best Server reports the simulated Roblox failure")
table.remove(warnings) -- This warning is expected; keep the final unexpected-warning check.
TeleportService.Teleport = originalTeleport
press("Q"); check(captured.AimbotSystem.IsEnabled(), "Q enables aim once, no legacy double dispatch")
press("Q"); check(captured.AimbotSystem.IsEnabled(), "Repeated InputBegan cannot toggle twice before release")
release("Q"); press("Q"); release("Q"); check(not captured.AimbotSystem.IsEnabled(), "Second complete key press disables")
Input.textbox={}; press("Q"); release("Q"); Input.textbox=nil
check(not captured.AimbotSystem.IsEnabled(), "Typing suppresses shortcuts")
press("Q",true); release("Q"); check(not captured.AimbotSystem.IsEnabled(), "Processed input is ignored")
GuiService.MenuIsOpen=true; press("Q"); release("Q"); GuiService.MenuIsOpen=false
check(not captured.AimbotSystem.IsEnabled(), "Open menu suppresses shortcuts")
local old=keys:Snapshot()
local ok, reason=keys:Change("aim.aim_assist","F","Toggle")
check(not ok and reason:find("already used",1,true) and keys.Entries["aim.aim_assist"].Key=="Q", "Conflicting bind rejected without mutation")
check(not keys:Change("aim.aim_assist","Escape","Toggle"), "Escape remains a capture cancel key")
check(not keys:Change("window","K","Hold"), "Action shortcuts cannot use Hold")
check(keys:Change("movement.noclip","V","Hold"), "Hold mode accepted")
press("V"); RunService.PreSimulation:Fire(1/60)
check(not own.Character.Head.CanCollide, "Hold activates collision feature")
release("V"); check(own.Character.Head.CanCollide, "Release restores collision")
press("V"); RunService.PreSimulation:Fire(1/60); Input.TextBoxFocused:Fire({})
check(own.Character.Head.CanCollide and not captured.MovementSystem.GetState().IsNoClip, "Text entry releases held features")
release("V"); press("V"); GuiService.MenuOpened:Fire()
check(not captured.MovementSystem.GetState().IsNoClip, "Opening menu releases held feature")
release("V"); press("V"); Input.WindowFocusReleased:Fire()
check(not captured.MovementSystem.GetState().IsNoClip, "Losing focus releases holds")
press("V"); check(not captured.MovementSystem.GetState().IsNoClip, "Unfocused dispatcher ignores keys")
Input.WindowFocused:Fire(); release("V"); press("V")
check(keys:Change("movement.noclip","J","Hold") and not captured.MovementSystem.GetState().IsNoClip, "Rebinding releases old held state")
release("V"); press("J"); own.CharacterRemoving:Fire(own.Character)
check(not captured.MovementSystem.GetState().IsNoClip, "Respawn clears held state")
release("J")
-- Restore the registry after the simulated removal, keeping the actual instance.
own.CharacterAdded:Fire(own.Character)
check(keys:Apply(old), "Restoring all keybinds works")
local swapped=keys:Snapshot(); swapped.window.Key="Q"; swapped["aim.aim_assist"].Key="K"
check(keys:Apply(swapped), "Whole-profile key swaps validate atomically")
keys:Apply(old)
check(settings:Apply({["movement.cframe_fly.value"]=175,["aim.fov_radius"]=220,["visual.team_attribute_optional"]="Faction"}), "Numeric, nested slider and string settings apply")
check(captured.MovementSystem.GetState().FlySpeed==175 or tools.Controls["movement.cframe_fly.value"].Widget:GetSlider()==175, "Nested slider readback updated")
check(captured.AimbotSystem.GetFOVRadius()==220 and captured.ESPSystem.GetConfig().TeamAttribute=="Faction", "Profile writes reach production module setters")
local profile=assert(tools:ExportProfile())
local data=services.HttpService:JSONDecode(profile)
check(data.Version==1 and data.PlaceId=="1" and data.Keybinds.window.Key=="K", "Versioned per-place snapshot contains bindings")
click("Export JSON")
check(services.HttpService:JSONDecode(inputBox("Profile JSON").Text).Settings["aim.fov_radius"]==220, "Export button populates scrollable profile field")
settings:Apply({["aim.fov_radius"]=110})
inputBox("Profile JSON").Text=profile; click("Import JSON")
check(captured.AimbotSystem.GetFOVRadius()==220, "Import button applies the pasted profile")
inputBox("Profile Name").Text="via-ui"; click("Save Named Profile")
check(disk["DiqProfiles/1/via-ui.json"]~=nil, "Save button uses typed profile name")
settings:Apply({["aim.fov_radius"]=100}); click("Load Named Profile")
check(captured.AimbotSystem.GetFOVRadius()==220, "Load button restores saved profile")
local search=inputBox("Find Setting"); search.Text="aim assist"; search.FocusLost:Fire(false)
click("Toggle Selected Setting")
check(captured.AimbotSystem.IsEnabled(), "Quick-action search routes to the matching feature")
click("Toggle Selected Setting"); click("Open Selected Setting")
check(tools.Controls["aim.aim_assist"].Tab._content.Visible, "Quick-action navigation opens the setting tab")
search.Text="no possible match"; search.FocusLost:Fire(false); click("Toggle Selected Setting")
check(not captured.AimbotSystem.IsEnabled(), "Empty quick search cannot toggle stale result")
-- Picker events must suppress the same key in the global dispatcher.
local pickerFrame
for _, object in instances do
	if object.ClassName=="TextLabel" and object.Text=="Show / Hide Window" then pickerFrame=object.Parent end
end
local pickerButton
for _, child in pickerFrame.children do if child.ClassName=="TextButton" then pickerButton=child end end
pickerButton.MouseButton1Click:Fire(); press("Q"); release("Q"); advance(0)
check(keys.Entries.window.Key=="K" and not captured.AimbotSystem.IsEnabled(), "Capture blocks global dispatch and restores picker after conflict")
pickerButton.MouseButton1Click:Fire(); press("L"); release("L"); advance(0)
check(keys.Entries.window.Key=="L" and pickerButton.Text=="L", "Picker applies a valid rebind")
keys:Apply(old)
settings:Apply({["aim.aim_assist"]=true,["visual.team_attribute_optional"]=""})
local function renderAim() for _, fn in RunService.bindings do fn(0.1) end end
renderAim(); check(captured.AimbotSystem.IsAiming(), "Aim is active before opening capture")
pickerButton.MouseButton1Click:Fire(); renderAim()
check(not captured.AimbotSystem.IsAiming(), "Key capture suspends active aim")
press("Escape"); release("Escape"); advance(0); renderAim()
check(captured.AimbotSystem.IsAiming(), "Canceling capture resumes enabled aim")
settings:Apply({["aim.aim_assist"]=false})
settings:Apply({["aim.fov_radius"]=100})
check(tools:ApplyProfile(profile) and captured.AimbotSystem.GetFOVRadius()==220, "Export/import restores values")
local function bad(change)
	local invalid=copy(data); change(invalid); return tools:ApplyProfile(services.HttpService:JSONEncode(invalid))
end
check(not bad(function(d) d.Version=2 end), "Rejects unsupported future schema")
check(not bad(function(d) d.PlaceId="other" end), "Rejects profile from another place")
check(not bad(function(d) d.Settings["aim.fov_radius"]=1/0 end), "Rejects infinity")
check(not bad(function(d) d.Settings["aim.fov_radius"]=0/0 end), "Rejects NaN")
check(not bad(function(d) d.Settings["aim.fov_radius"]=220.5 end), "Rejects fractional integer slider")
check(not bad(function(d) d.Settings["aim.fov_radius"]="220" end), "Rejects number strings")
check(not bad(function(d) d.Settings["aim.fov_radius"]=nil end), "Rejects incomplete snapshot")
check(not bad(function(d) d.Settings.unknown=true end), "Rejects unknown settings")
check(not bad(function(d) d.Settings["aim.aim_at"]="Invalid" end), "Rejects invalid enum choices")
check(not bad(function(d) d.Settings["visual.team_attribute_optional"]=string.rep("x",129) end), "Bounds free text")
check(not bad(function(d) d.Keybinds.window.Key="Q"; d.Settings["aim.fov_radius"]=120 end) and captured.AimbotSystem.GetFOVRadius()==220, "Validates shortcuts before any setting mutation")
check(not tools:ApplyProfile("invalid json") and not tools:ApplyProfile(string.rep("x",65537)), "Malformed and oversized profiles rejected")
local entry=settings.Entries["aim.aim_at"]; local original=entry.Set
entry.Set=function(value) if value=="Body" then error("injected setter failure") end; return original(value) end
local changed=copy(data); changed.Settings["movement.cframe_fly.value"]=200; changed.Settings["aim.aim_at"]="Body"
check(not tools:ApplyProfile(services.HttpService:JSONEncode(changed)), "Setter failures surface")
check(settings:Snapshot()["movement.cframe_fly.value"]==175 and captured.AimbotSystem.GetAimPart()=="Head", "Failed apply rolls back prior setting changes")
entry.Set=original
check(settings:Save("test",profile) and folders["DiqProfiles/1"], "Save creates scoped directories")
check(settings:Read("test")==profile, "Read uses same scoped path")
check(not settings:Save("../outside",profile) and not settings:Read("../outside"), "Rejects path traversal names")
check(not settings:Save("",profile) and not settings:Save(string.rep("a",41),profile), "Bounds profile names")
check(settings:Read("missing")==nil, "Missing files return actionable failure")
check(tools:Copy(profile) and clipboard==profile, "Clipboard result reflects actual call")
setclipboard=function() error("denied") end
check(not tools:Copy(profile) and tools:CapabilitiesSnapshot().Clipboard=="Copy unavailable/failed", "Clipboard runtime failure is distinguished")
setclipboard=function() return false end
check(not tools:Copy(profile), "Explicit clipboard refusal is not reported as success")
check(tools:ProbeDrawing() and drawings[#drawings].Removed, "Drawing probe always removes its object")
check(tools:CapabilitiesSnapshot().MouseOutput=="Unavailable", "Absent executor API reported as unavailable")
local prefs=captured.Preferences.new({Codec=services.HttpService,PlaceId=1})
check(not prefs:Save("test",profile) and prefs:Read("test")==nil, "No-filesystem fallback returns explicit export/import guidance")
local refused=captured.Preferences.new({Codec=services.HttpService,PlaceId=1,Files={writefile=function() return false end,makefolder=function() end}})
check(not refused:Save("test",profile), "Explicit filesystem refusal is not reported as success")
local textWidget=tools.Controls["visual.team_attribute_optional"].Widget
textWidget:Set(string.rep("x",129))
check(tools:ExportProfile()==nil, "Invalid current text cannot produce an unloadable exported profile")
textWidget:Set("")
-- Performance limits have real effect on production render work.
enemy.Character.HumanoidRootPart.Position=vec(300,200,10)
tools:SetPerformance("Low")
check(captured.ESPSystem.GetConfig().MaxVisuals==20 and captured.AimbotSystem.GetScanInterval()==0.25, "Low preset changes actual budgets")
check(not captured.ESPSystem.IsEnabled(), "Performance presets never enable features")
settings:Apply({["visual.team_attribute_optional"]="",["visual.show_names_distance"]=true,["visual.enable_esp"]=true})
local previous=captured.ESPSystem.GetMetrics().Projections
for _=1,60 do RunService.RenderStepped:Fire(1/60) end
local projections=captured.ESPSystem.GetMetrics().Projections-previous
check(projections>0 and projections<=63, "Low ESP updates bounded near 20Hz at 60FPS")
for i=1,25 do local p=newPlayer("Extra"..i,"red"); p.Character.HumanoidRootPart.Position=vec(300+i,200,10); Players.PlayerAdded:Fire(p) end
RunService.RenderStepped:Fire(0.1)
local highlights=0
for _,o in instances do if o.ClassName=="Highlight" and o.Enabled then highlights+=1 end end
check(highlights==20, "Only nearest 20 highlights active under Low cap")
tools:SetPerformance("Balanced")
check(captured.ESPSystem.GetConfig().MaxVisuals==50 and captured.AimbotSystem.GetScanInterval()==0.1, "Balanced preset applies")
tools:SetPerformance("High")
check(captured.ESPSystem.GetConfig().MaxVisuals==0 and captured.ESPSystem.GetConfig().UpdateInterval==0, "High removes extra caps")
-- All stop paths restore overlapping owned state and retain user configuration.
settings:Apply({["movement.noclip"]=true,["movement.anti_fling"]=true,["visual.fullbright_no_fog"]=true,["combat.enable_hitbox_expander"]=true})
RunService.PreSimulation:Fire(1/60)
local actionRan=false
app.Actions:Delay(0.5,function() actionRan=true end)
tools:SampleFrames()
press("End"); release("End")
advance(1)
check(not actionRan and not tools.Sampling, "Stop All cancels queued actions and frame sampling")
check(own.Character.Head.CanCollide and enemy.Character.Head.CanCollide and Lighting.Brightness==1, "Stop All restores collision and lighting")
check(not captured.ESPSystem.IsEnabled() and not captured.HitboxSystem.IsEnabled() and not captured.AimbotSystem.IsEnabled(), "Stop All disables features")
check(captured.AimbotSystem.GetFOVRadius()==220, "Stop All keeps configured settings")
check(tools:SampleFrames() and not tools:SampleFrames(), "Only one frame sample can run")
for _=1,101 do RunService.RenderStepped:Fire(0.1) end
check(tools.FrameSample.Status=="Complete" and math.abs(tools.FrameSample.P95Ms-100)<0.001, "Frame sample reports actual mock frame percentiles")
check(not tools.Sampling and RunService.RenderStepped:Count()==0, "Sampling stops its connection")
tools:SampleFrames(); advance(16)
check(tools.FrameSample.Status=="Timed out; partial sample" and not tools.Sampling, "No-frame sample times out cleanly")
local report=services.HttpService:JSONDecode(tools:Report())
check(report.Capabilities and report.Tasks and report.ActiveFeatures and report.Performance and report.FrameSample, "Diagnostics aggregate capabilities, failures, timings and states")
check(report.UserId==nil and report.JobId==nil and report.Scripts==nil, "Report excludes account, job and script contents")
click("Refresh Report")
check(services.HttpService:JSONDecode(inputBox("Report").Text).FrameSample~=nil, "Diagnostics UI refresh writes readable report data")
check(tools:Reset() and captured.AimbotSystem.GetFOVRadius()==150 and tools.Performance=="High", "Reset restores all feature defaults and budgets")
check(keys.Entries.window.Key=="K" and keys.Entries["movement.noclip"].Mode=="Toggle", "Reset restores binding defaults")

-- Drive the production tab with a simulated Roblox Animator.
local character = own.Character
local humanoid = character.Humanoid
humanoid.RigType = Enum.HumanoidRigType.R6
humanoid.Died = signal()
local animator = Instance.new("Animator")
animator.Parent = humanoid
local length, failPlayback = 2, false
local lastTrack
function animator:LoadAnimation(animation)
	local track = Instance.new("AnimationTrack")
	track.Animation = animation
	track.Ended = signal()
	track.Length = length
	function track:Play()
		if failPlayback then error("mock playback error") end
		self.IsPlaying = true
	end
	function track:Stop() self.IsPlaying = false end
	lastTrack = track
	return track
end
local function released(track)
	return track.Destroyed and track.Animation.Destroyed and not track.IsPlaying and track.Ended:Count() == 0
end
click("Trolling")
check(labelObject("Wave").Parent.Parent.Parent.Name == "Tab_Trolling" and not tools.QuickTab._content.Visible,
	"Trolling is reachable from the sidebar")
local idleConnections = liveConnections()
click("Wave")
local wave = lastTrack
check(wave.IsPlaying and not wave.Looped and wave.Animation.AnimationId == "rbxassetid://128777973", "R6 wave plays once with the R6 asset")
click("Dance 1")
check(released(wave) and lastTrack.Looped and lastTrack.Animation.AnimationId == "rbxassetid://182435998",
	"Starting a dance replaces the owned track and loops the R6 dance")
click("Stop Animation")
check(released(lastTrack) and liveConnections() == idleConnections, "Stop Animation releases the track and its connections")
humanoid.RigType = Enum.HumanoidRigType.R15
click("Wave")
check(lastTrack.IsPlaying and lastTrack.Animation.AnimationId == "rbxassetid://507770239", "The same button selects the R15 asset")
lastTrack.Ended:Fire()
check(released(lastTrack), "Natural completion releases the animation")
click("Dance 1")
check(lastTrack.IsPlaying and lastTrack.Animation.AnimationId == "rbxassetid://507771019", "R15 dance uses its own asset")
press("End"); release("End")
check(released(lastTrack), "The emergency stop releases an active emote")
click("Dance 1")
humanoid.Died:Fire()
check(released(lastTrack), "Death releases an active emote")
click("Dance 1")
own.CharacterRemoving:Fire(character)
check(released(lastTrack), "Character removal releases an active emote")
own.CharacterAdded:Fire(character)

failPlayback = true
local played, failure = captured.TrollingSystem.Play("Dance 1")
check(not played and failure:find("Could not play", 1, true) and released(lastTrack), "Playback failure releases partially created resources")
failPlayback, length = false, 0
click("Wave")
advance(8)
check(released(lastTrack) and labelObject("Animation unavailable"), "An asset that fails to load is released and reported in the UI")
local reported = false
check(captured.TrollingSystem.Play("Dance 1", function() reported = true end), "A slow asset can still start loading")
local pending = lastTrack
length = 2
click("Wave")
advance(8)
check(released(pending) and lastTrack.IsPlaying and not reported, "A replaced load cannot report an error or stop the current track")
tools:SampleFrames(); app:Destroy(); advance(30); advance(0)
check(released(lastTrack), "Closing the panel releases the active emote")
check(liveConnections()==baseline, "Shutdown cancels samples, picker handlers and shared input")
check(not tools:ApplyProfile(profile) and not tools:SetPerformance("Low"), "Closed control center rejects mutations")

-- Rotation values stand in for CFrames to verify playback ownership and cleanup.
local function rotation(value)
	local frame = { Value = value }
	frame.Rotation = frame
	function frame:Inverse() return rotation(-self.Value) end
	function frame:Lerp(other, alpha) return rotation(self.Value + (other.Value - self.Value) * alpha) end
	return setmetatable(frame, { __mul = function(left, right) return rotation(left.Value + right.Value) end })
end
CFrame.Angles = function(x, y, z) return rotation(x + y + z) end
local second = assert(factories.Main({Factories=injected}))
local r6Shoulder = Instance.new("Motor6D")
r6Shoulder.Name = "Right Shoulder"
r6Shoulder.Part0, r6Shoulder.Part1 = character.HumanoidRootPart, character.Head
r6Shoulder.C0, r6Shoulder.Transform = rotation(0), rotation(0.4)
r6Shoulder.Parent = r6Shoulder.Part0
humanoid.RigType = Enum.HumanoidRigType.R6
click("Trolling")
click("Jerk Off")
RunService.PreSimulation:Fire(0.12)
local firstPose = r6Shoulder.Transform
RunService.PreSimulation:Fire(0.15)
check(firstPose.Value ~= r6Shoulder.Transform.Value and RunService.PreSimulation:Count() == 1,
	"The R6 gesture updates the shoulder over time")
local animatorPose = rotation(0.7)
r6Shoulder.Transform = animatorPose
RunService.PreSimulation:Fire(0.15)
click("Stop Animation")
check(r6Shoulder.Transform == animatorPose and RunService.PreSimulation:Count() == 0,
	"Stopping restores the latest underlying shoulder pose")

local function constraint(name)
	local joint = Instance.new("AnimationConstraint")
	joint.Name = name
	joint.IsKinematic = true
	joint.Attachment0 = Instance.new("Attachment")
	joint.Attachment0.CFrame = rotation(0)
	joint.Attachment1 = Instance.new("Attachment")
	joint.Transform = rotation(0)
	joint.Parent = character.Head
	return joint
end
local r15Shoulder, r15Elbow = constraint("RightShoulder"), constraint("RightElbow")
local baseShoulder, baseElbow = r15Shoulder.Transform, r15Elbow.Transform
humanoid.RigType = Enum.HumanoidRigType.R15
click("Jerk Off")
RunService.PreSimulation:Fire(0.12)
check(r15Shoulder.Transform ~= baseShoulder and r15Elbow.Transform ~= baseElbow,
	"The R15 gesture moves both upgraded joints")
press("End"); release("End")
check(r15Shoulder.Transform == baseShoulder and r15Elbow.Transform == baseElbow and RunService.PreSimulation:Count() == 0,
	"End restores both R15 joints and disconnects the update")

click("Jerk Off")
RunService.PreSimulation:Fire(0.12)
click("Wave")
check(r15Shoulder.Transform == baseShoulder and r15Elbow.Transform == baseElbow and lastTrack.IsPlaying,
	"Switching to a stock emote stops the gesture")
click("Jerk Off")
check(released(lastTrack), "Starting the gesture releases a stock emote")
RunService.PreSimulation:Fire(0.12)
own.CharacterRemoving:Fire(character)
check(r15Shoulder.Transform == baseShoulder and r15Elbow.Transform == baseElbow and RunService.PreSimulation:Count() == 0,
	"Character removal stops the gesture")
own.CharacterAdded:Fire(character)
r15Elbow.IsKinematic = false
local gestureStarted, gestureFailure = captured.TrollingSystem.Play("Jerk Off")
check(not gestureStarted and gestureFailure and RunService.PreSimulation:Count() == 0,
	"Unsupported joints fail without leaving a scheduled update")
r15Elbow.IsKinematic = true
click("Jerk Off")
RunService.PreSimulation:Fire(0.12)
second:Destroy(); advance(20); advance(0)
check(r15Shoulder.Transform == baseShoulder and r15Elbow.Transform == baseElbow, "Closing the panel restores the gesture's joints")
check(liveConnections()==baseline, "Repeated Main lifecycle leaves no added handlers")
check(#warnings==0, "No hidden callback failures in control-center scenarios")
print("ControlCenter checks passed: "..checks)
