-- Mock engine regression tests. The runner inserts the production module here.
local function signal()
 local s = { listeners = {} }
 function s:Connect(fn)
  local c = { Connected = true }
  function c:Disconnect() self.Connected = false end
  table.insert(self.listeners, { fn, c }); return c
 end
 function s:Fire(...)
  for _, pair in ipairs(self.listeners) do if pair[2].Connected then pair[1](...) end end
 end
 return s
end
local vectorMT = {}
local function vec(x,y,z) return setmetatable({ X=x,Y=y,Z=z or 0 },vectorMT) end
vectorMT.__index = function(v,k) if k == 'Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k == 'Unit' then local m=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z); return vec(v.X/m,v.Y/m,v.Z/m) end end
vectorMT.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMT.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMT.__mul = function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
vectorMT.__div = function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
local Vector2 = {new=vec}
local Color3 = {new=function() return {} end}
local UDim = {new=function(...) return {...} end}
local UDim2 = {fromOffset=vec}
local Enum = {
 RaycastFilterType={Exclude=1}, MouseBehavior={Default=1,LockCenter=2},
 UserInputType={MouseButton2=2,MouseButton1=1,Keyboard=3}, KeyCode={Q=10,E=11,T=12,Unknown=0}, RenderPriority={Camera={Value=200},Last={Value=2000}},
}
local instances = {}
local Instance = { new = function(class)
 local obj = {ClassName=class}
 function obj:Destroy() self.Parent=nil; self.Destroyed=true end
 table.insert(instances,obj); return obj
end }
local RaycastParams = {new=function() return {} end}
local function frame(pos,target)
 local f={Position=pos,Target=target,LookVector=target and (target-pos).Unit or vec(0,0,1)}
 function f:Lerp(other,alpha)
  local result=frame(self.Position,other.Target)
  result.Alpha=alpha
  result.LookVector=(self.LookVector*(1-alpha)+other.LookVector*alpha).Unit
  return result
 end
 return f
end
local CFrame = {lookAt=frame}
local LocalPlayer = {Neutral=false,Team='blue',CharacterAdded=signal()}
local Players = { LocalPlayer=LocalPlayer, list={} }
function Players:GetPlayers() return self.list end
local Input = {MouseBehavior=1,mouse=vec(400,336),InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal(),WindowFocused=signal()}
function Input:GetMouseLocation() return self.mouse end
function Input:GetFocusedTextBox() return self.textbox end
local GuiService = {MenuIsOpen=false}
function GuiService:GetGuiInset() return vec(0,36) end
local RunService = {bindings={}}
function RunService:BindToRenderStep(name,priority,fn) self.bindings[name]=fn end
function RunService:UnbindFromRenderStep(name) self.bindings[name]=nil end
local camera = {ViewportSize=vec(800,600),CFrame=frame(vec(0,0,0))}
function camera:WorldToViewportPoint(pos) return pos,pos.Z>0 end
local workspace = {CurrentCamera=camera}
function workspace:Raycast() return self.hit end
local function character(x,y)
 local h={Health=100}
 local c={humanoid=h}
 function c:IsDescendantOf(parent) return parent==workspace and not self.gone end
 function c:FindFirstChildOfClass() return h end
 function c:FindFirstChild(name) return self[name] end
 local p={Position=vec(x,y,10),Parent=c}
 function p:IsA(name) return name=='BasePart' end
 function p:IsDescendantOf(other) return other==c end
 c.Head=p; c.HumanoidRootPart=p
 return c
end
LocalPlayer.Character=character(0,0)
function LocalPlayer:FindFirstChildOfClass() return {} end
local enemy={Name='Enemy',UserId=10,Parent=Players,Team='red',Neutral=false,Character=character(430,300)}
local other={Name='Other',UserId=20,Parent=Players,Team='red',Neutral=false,Character=character(450,300)}
Players.list={LocalPlayer,enemy,other}
local game = {GetService=function(_,name) return ({Players=Players,RunService=RunService,UserInputService=Input,GuiService=GuiService})[name] end}
local warnings={}
local function warn(message) table.insert(warnings,message) end
local mousemoverel
local function loadModule(...)
-- INSERT_MODULE
end
local A = loadModule({DeferInit=true})
assert(next(RunService.bindings)==nil,'deferred init must not bind')
A.Init(); A.Init()
assert(#Input.InputBegan.listeners==1,'Init must be idempotent')
local function tick(dt) for _,fn in pairs(RunService.bindings) do fn(dt or 1/60) end end
local function press() Input.InputBegan:Fire({UserInputType=2},false) end
local function target(expected,label) tick(); assert(A.GetCurrentTarget()==expected,label) end
A.SetTargetMode('Sticky')
A.SetActivationKey('MouseButton2'); A.SetActivationMode('Hold')
A.SetEnabled(true); A.SetShowFOV(true); press()
target(enemy.Character.Head,'closest target')
-- Compare the actual controller's per-frame response over one second.
local function remainingError(fps)
 local remaining=1
 for _=1,fps do tick(1/fps); remaining=remaining*(1-camera.CFrame.Alpha) end
 return remaining
end
assert(math.abs(remainingError(30)-remainingError(144))<1e-9,'camera response must be frame-rate independent')
-- Invalid/offscreen locks must be dropped, including replacement characters.
local oldCharacter=enemy.Character
enemy.Character=character(435,300)
target(enemy.Character.Head,'respawn replaces the old target part')
assert(A.GetCurrentTarget()~=oldCharacter.Head,'old part must not survive respawn')
enemy.Character.Head.Position=vec(435,300,-10)
target(other.Character.Head,'behind-camera target is excluded')
enemy.Character.Head.Position=vec(430,300,10)
Input.InputEnded:Fire({UserInputType=2}); press()
target(enemy.Character.Head,'reacquire after release')
local overlay
for _,obj in ipairs(instances) do if obj.ClassName=='Frame' then overlay=obj end end
assert(overlay.Position.X==400 and overlay.Position.Y==336,'FOV must align with viewport center plus inset')
-- Retain a valid lock even when another player becomes closer.
other.Character.Head.Position=vec(405,300,10)
target(enemy.Character.Head,'stable lock')
enemy.Team='blue'; target(other.Character.Head,'team change invalidates lock')
other.Character.humanoid.Health=0; target(nil,'dead target invalidation')
other.Character.humanoid.Health=100; enemy.Team='red'
other.Character.Head.Position=vec(450,300,10)
A.SetAimPart('Torso'); enemy.Character.UpperTorso=enemy.Character.Head
target(enemy.Character.UpperTorso,'R15 torso fallback')
A.SetWallCheck(true)
workspace.hit={Instance={IsDescendantOf=function() return false end}}
target(nil,'wall blocks selection')
workspace.hit={Instance=enemy.Character.Head}
target(enemy.Character.Head,'target own geometry is visible')
workspace.hit=nil
A.SetMaxDistance(1); target(nil,'max distance')
A.SetMaxDistance(3000); A.SetWallCheck(false)
other.Character.Head.Position=vec(405,300,10)
Input.textbox={}; target(nil,'typing blocks aiming')
Input.textbox=nil; target(other.Character.Head,'resume after typing')
GuiService.MenuIsOpen=true; target(nil,'menu blocks aiming')
GuiService.MenuIsOpen=false
Input.WindowFocusReleased:Fire(); target(nil,'focus loss clears hold')
Input.WindowFocused:Fire(); target(nil,'focus gain does not restore hold')
press(); target(other.Character.Head,'new press resumes')
Input.InputEnded:Fire({UserInputType=2}); target(nil,'release clears lock')
assert(not A.SetAimMethod('Mouse'),'missing executor API rejected')
local moves={}
mousemoverel=function(x,y) table.insert(moves,vec(x,y)) end
assert(A.SetAimMethod('Mouse'))
Input.mouse=vec(420,336); press(); tick()
assert(moves[#moves].X>0 and math.abs(moves[#moves].Y)<0.001,'free cursor mouse origin must account for inset')
Input.MouseBehavior=Enum.MouseBehavior.LockCenter
A.SetTeamCheck(true); tick()
assert(moves[#moves].X>0,'locked mouse uses viewport center')
mousemoverel=function() error('executor failure') end
tick(); assert(A.GetAimMethod()=='Camera' and #warnings==1,'mouse failure recovers explicitly')
-- Reproduce the game's camera restoring its own orientation every frame.
A.SetAimMethod('Camera'); A.SetAimPart('Head')
Input.InputEnded:Fire({UserInputType=2}); press()
camera.CFrame=frame(vec(0,0,0)); tick()
local firstDirection=camera.CFrame.LookVector
local desiredDirection=A.GetCurrentTarget().Position.Unit
camera.CFrame=frame(vec(0,0,0)); tick()
assert((camera.CFrame.LookVector-desiredDirection).Magnitude < (firstDirection-desiredDirection).Magnitude,'camera smoothing must accumulate despite game resets')
-- The default Q toggle must not require holding right click.
A.SetActivationKey('Q'); A.SetActivationMode('Toggle')
Input.InputBegan:Fire({UserInputType=3,KeyCode=10},false); tick()
assert(A.IsAiming() and A.GetStatus().Active,'Q enables aiming')
Input.InputEnded:Fire({UserInputType=3,KeyCode=10}); tick()
assert(A.IsAiming(),'Q release preserves toggle')
Input.InputBegan:Fire({UserInputType=3,KeyCode=10},false); target(nil,'second Q stops aiming')
Input.InputBegan:Fire({UserInputType=3,KeyCode=10},true); tick()
assert(not A.GetStatus().Active,'processed keys must not toggle')
A.SetActivationMode('Hold')
Input.InputBegan:Fire({UserInputType=3,KeyCode=10},false); tick(); assert(A.IsAiming(),'keyboard hold starts')
Input.InputEnded:Fire({UserInputType=3,KeyCode=10}); target(nil,'keyboard release stops hold')
A.SetActivationKey('E'); A.SetActivationMode('Toggle')
Input.InputBegan:Fire({UserInputType=3,KeyCode=10},false); tick(); assert(not A.GetStatus().Active,'old key no longer toggles')
Input.InputBegan:Fire({UserInputType=3,KeyCode=11},false); tick(); assert(A.GetStatus().Active,'new key toggles')
A.SetEnabled(false); A.SetEnabled(true); tick(); assert(not A.GetStatus().Active,'master re-enable starts inactive')
-- Deterministic ranking, challenger debounce and invalidation.
A.SetAutoSwitch(true)
A.SetActivationKey('MouseButton2'); A.SetActivationMode('Hold'); press()
A.SetTargetMode('Smart')
enemy.Character.Head.Position=vec(430,300,10); other.Character.Head.Position=vec(450,300,10)
Players.list={LocalPlayer,other,enemy}
target(enemy.Character.Head,'screen ranking ignores enumeration order')
other.Character.Head.Position=vec(405,300,10)
target(enemy.Character.Head,'challenger cannot instantly steal lock')
for _=1,30 do tick() end
target(other.Character.Head,'sustained better challenger wins')
enemy.Character.Head.Position=vec(404,300,10)
for _=1,60 do tick() end
target(other.Character.Head,'near ties retain current target')
other.Character.humanoid.Health=0
target(enemy.Character.Head,'invalid target immediately replaced')
other.Character.humanoid.Health=100
A.SetTargetMode('Smart'); enemy.Character.Head.Position=vec(430,300,10); other.Character.Head.Position=vec(430,300,10)
target(enemy.Character.Head,'UserId breaks exact ties')
Players.list={LocalPlayer,enemy,other}; A.SetTargetMode('Smart')
target(enemy.Character.Head,'tie result independent of list ordering')
-- Depth changes physical distance independently of the mocked projection.
enemy.Character.Head.Position=vec(430,300,2500); other.Character.Head.Position=vec(435,300,10)
A.SetTargetMode('Nearest'); target(other.Character.Head,'nearest ranks physical distance')
A.SetTargetMode('Balanced'); A.SetCrosshairWeight(1)
target(enemy.Character.Head,'100 percent weight selects screen-nearest')
A.SetCrosshairWeight(0); A.SetTargetMode('Balanced')
target(other.Character.Head,'zero percent weight selects physical-nearest')
A.SetCrosshairWeight(0.7); A.SetTargetMode('Balanced')
target(other.Character.Head,'balanced weighs both screen and physical distance')
A.SetTargetMode('Smart'); enemy.Character.Head.Position=vec(430,300,10); other.Character.Head.Position=vec(450,300,10)
target(enemy.Character.Head,'start interrupted challenger scenario')
other.Character.Head.Position=vec(405,300,10)
for _=1,8 do tick() end
other.Character.Head.Position=vec(450,300,10)
for _=1,8 do tick() end
other.Character.Head.Position=vec(405,300,10)
for _=1,8 do tick() end
target(enemy.Character.Head,'interrupted challenger loses accumulated timer')
A.SetTargetMode('Sticky')
-- Default manual control keeps the ranked target until explicitly cycled.
A.SetAutoSwitch(false); A.SetTargetMode('Balanced')
A.SetActivationKey('MouseButton2'); A.SetActivationMode('Hold'); press()
enemy.Character.Head.Position=vec(430,300,10); other.Character.Head.Position=vec(405,300,10)
local third={Name='Third',UserId=30,Parent=Players,Team='red',Neutral=false,Character=character(440,300)}
Players.list={LocalPlayer,third,other,enemy}
target(other.Character.Head,'balanced still chooses initial target')
enemy.Character.Head.Position=vec(401,300,10)
for _=1,60 do tick() end
target(other.Character.Head,'auto switch OFF keeps original valid target')
enemy.Character.Head.Position=vec(430,300,10)
Input.InputBegan:Fire({UserInputType=3,KeyCode=12},false)
target(enemy.Character.Head,'T cycles to next ranked candidate')
-- A camera turn changes rankings; the remembered cycle must still reach third.
enemy.Character.Head.Position=vec(400,300,10)
other.Character.Head.Position=vec(435,300,10)
assert(A.NextTarget()); target(third.Character.Head,'manual cycle reaches third player')
assert(A.NextTarget()); target(other.Character.Head,'manual cycle wraps')
enemy.Character.Head.Position=vec(430,300,10); other.Character.Head.Position=vec(405,300,10)
assert(not A.SetNextTargetKey('MouseButton2'),'next target requires keyboard')
assert(A.SetNextTargetKey('E'))
Input.InputBegan:Fire({UserInputType=3,KeyCode=12},false)
target(other.Character.Head,'old next key has no effect')
Input.InputBegan:Fire({UserInputType=3,KeyCode=11},false)
target(enemy.Character.Head,'new next key works')
Input.textbox={}; assert(not A.NextTarget(),'typing blocks manual cycling')
Input.textbox=nil
assert(A.SetNextTargetKey('T'))
assert(not A.SetActivationKey('T'),'activation cannot collide with next key')
assert(A.GetActivationKey()=='MouseButton2','failed rebind preserves activation')
assert(A.SetActivationKey('Q'))
assert(not A.SetNextTargetKey('Q'),'next key cannot collide with activation')
assert(A.GetNextTargetKey()=='T','failed rebind preserves next key')
assert(not A.NextTarget(),'rebind resets active state')
A.SetActivationKey('MouseButton2'); A.SetActivationMode('Hold'); press()
assert(A.NextTarget()); Input.WindowFocusReleased:Fire(); Input.WindowFocused:Fire()
assert(not A.NextTarget(),'focus loss cancels queued cycling and active state')
press(); target(other.Character.Head,'focus regain begins with fresh selection')
Players.list={LocalPlayer,enemy,other}
A.SetTargetMode('Sticky')
-- Rebinding is input capture: neither activation nor cycling may run.
A.SetInputSuspended(true)
Input.InputBegan:Fire({UserInputType=2},false)
assert(not A.NextTarget(),'input capture blocks cycling')
target(nil,'input capture clears target and activation')
A.SetInputSuspended(false)
target(nil,'finishing rebind does not reactivate aim')
press()
-- Diagnostics expose the actual filters instead of guessing at the game.
A.SetActivationKey('MouseButton2'); A.SetActivationMode('Hold'); press()
enemy.Team='blue'; other.Team='blue'; tick()
assert(A.GetStatus().Rejected['Same team']==2 and not A.IsAiming(),'same-team diagnostic')
enemy.Team='red'; other.Team='red'
A.SetEnabled(false); assert(next(RunService.bindings)==nil and not overlay.Visible,'disable unbinds and hides FOV')
assert(not pcall(A.SetSmoothing,0/0),'reject NaN')
A.SetEnabled(true); press()
A.Destroy(); A.Destroy()
assert(next(RunService.bindings)==nil and A.GetCurrentTarget()==nil,'destroy removes binding and lock')
for _,sig in ipairs({Input.InputBegan,Input.InputEnded,Input.WindowFocusReleased,Input.WindowFocused,LocalPlayer.CharacterAdded}) do
 for _,pair in ipairs(sig.listeners) do assert(not pair[2].Connected,'all events disconnected') end
end
assert(not A.SetEnabled(true),'destroyed instance cannot restart')
assert(not pcall(A.Init),'destroyed instance cannot initialize')
print('PASS: Aimbot lifecycle, selection, FOV, input, visibility and executor failure regression tests')
