-- Engine mocks test control flow, not Roblox rendering or executor compatibility.
local function signal()
 local s = { listeners = {} }
 function s:Connect(fn)
  local c = { Connected = true }
  function c:Disconnect() self.Connected = false end
  table.insert(self.listeners, {fn, c}); return c
 end
 function s:Fire(...)
  for _, pair in self.listeners do if pair[2].Connected then pair[1](...) end end
 end
 function s:Count()
  local n = 0
  for _, pair in self.listeners do if pair[2].Connected then n += 1 end end
  return n
 end
 return s
end
local mt = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z or 0}, mt) end
mt.__index = function(v,k) if k == 'Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
mt.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local Vector2, Vector3 = {new=vec}, {new=vec}
local Color3 = {fromRGB=function(r,g,b)
 local c={r=r,g=g,b=b}
 function c:Lerp(other, alpha) return {r=self.r+(other.r-self.r)*alpha} end
 return c
end}
local typeof = function(v) return type(v)=='table' and v.r and 'Color3' or type(v) end
local Enum = {HighlightDepthMode={AlwaysOnTop=1}}
local instances, drawings, warnings = {}, {}, {}
local warn = function(message) table.insert(warnings,message) end
local Instance = {new=function(class)
 local o={ClassName=class}
 function o:Destroy() self.Destroyed=true; self.Parent=nil end
 table.insert(instances,o); return o
end}
local Drawing = {new=function(class)
 local o={ClassName=class}
 function o:Remove() self.Removed=true end
 table.insert(drawings,o); return o
end}
local camera={CFrame={Position=vec(0,0,0)},ViewportSize=vec(800,600)}
function camera:WorldToViewportPoint(p) return p, p.X>=0 and p.Z>0 end
local workspace={CurrentCamera=camera}
local function character()
 local c={HumanoidRootPart={Position=vec(400,300,10)}, Head={Position=vec(400,302,10)}, humanoid={Health=100,MaxHealth=100}}
 function c.HumanoidRootPart:IsA(name) return name=='BasePart' end
 function c.Head:IsA(name) return name=='BasePart' end
 function c:FindFirstChild(name) return self[name] end
 function c:FindFirstChildOfClass() return self.humanoid end
 function c:IsDescendantOf(parent) return parent==workspace and not self.Removed end
 return c
end
local blue, red = {}, {}
local function player(name,team)
 local p={Name=name,Team=team,Neutral=false,TeamColor={Color=Color3.fromRGB(1,2,3)},Character=character(),attrs={}}
 function p:GetAttribute(key) return self.attrs[key] end
 return p
end
local own=player('Own',blue)
local ally,enemy,unknown=player('Ally',blue),player('Enemy',red),player('Unknown',nil)
local Players={LocalPlayer=own,list={own,ally,enemy,unknown},PlayerAdded=signal(),PlayerRemoving=signal()}
function Players:GetPlayers() return self.list end
local RunService={RenderStepped=signal()}
local game={GetService=function(_,name) return ({Players=Players,RunService=RunService,CoreGui={}})[name] end}
local function loadModule(...)
-- INSERT_MODULE
end
local esp=loadModule({DeferInit=true})
local checks=0
local function check(condition,message) checks+=1; assert(condition,message) end
local function highlight(name)
 for _,o in instances do if o.Name==name..'_ESP' and not o.Destroyed then return o end end
end
local function tick() RunService.RenderStepped:Fire() end
esp.Init(); esp.Init()
check(Players.PlayerAdded:Count()==1,'Init must be idempotent')
check(RunService.RenderStepped:Count()==0,'Disabled ESP must not render')
check(not highlight('Enemy').Enabled,'No startup flash')
check(esp.GetRelation(own)=='Self','Self classification')
check(esp.GetRelation(ally)=='Teammate','Same team')
check(esp.GetRelation(enemy)=='Enemy','Different team')
check(esp.GetRelation(unknown)=='Unknown','Missing team')
own.Neutral=true
check(esp.GetRelation(ally)=='Unknown','Local neutral with retained Team')
own.Neutral=false; ally.Neutral=true
check(esp.GetRelation(ally)=='Unknown','Target neutral with retained Team')
ally.Neutral=false; own.Team=nil
check(esp.GetRelation(unknown)=='Unknown','nil teams must not become allies')
own.Team=blue
esp.SetEnabled(true); esp.SetEnabled(true); tick()
check(RunService.RenderStepped:Count()==1,'No duplicate render loop')
check(highlight('Ally').FillColor==esp.GetConfig().TeammateColor,'Ally relation color')
check(highlight('Enemy').FillColor==esp.GetConfig().EnemyColor,'Enemy relation color')
check(highlight('Unknown').FillColor==esp.GetConfig().UnknownColor,'Unknown relation color')
esp.SetNames(true); esp.SetBoxes(true); esp.SetHealth(true); esp.SetTracers(true); tick()
local enemyName=drawings[8] -- six drawings per player; second entry is Name
check(enemyName.Visible and string.find(enemyName.Text,'[Enemy]',1,true)~=nil,'Relation name label')
check(string.find(enemyName.Text,'studs',1,true)~=nil,'Distance uses studs')
esp.SetRelationVisible('Teammate',false); tick()
check(not highlight('Ally').Enabled and highlight('Enemy').Enabled,'Independent ally filter')
enemy.Team=blue; tick()
check(not highlight('Enemy').Enabled and not enemyName.Visible,'Team change hides all elements')
enemy.Team=red; own.Team=red; tick()
check(not highlight('Enemy').Enabled and highlight('Ally').Enabled,'Local team change reclassifies everyone')
own.Team=blue; tick()
esp.SetRelationVisible('Unknown',false); tick()
check(not highlight('Unknown').Enabled,'Independent unknown filter')
esp.SetMaxDistance(1); tick()
check(not highlight('Enemy').Enabled and not enemyName.Visible,'Range hides highlight and drawings')
esp.SetMaxDistance(0); tick()
check(highlight('Enemy').Enabled,'Unlimited range')
esp.SetColorMode('Team'); tick()
check(highlight('Enemy').FillColor==enemy.TeamColor.Color,'Game team colors')
esp.SetUseTeamColor(false); tick()
check(highlight('Enemy').FillColor==esp.GetColor(),'Legacy uniform mode')
esp.SetColorMode('Relation')
local custom=Color3.fromRGB(30,40,50)
esp.SetRelationColor('Enemy',custom); tick()
check(highlight('Enemy').FillColor==custom,'Custom relation color')
esp.SetTeamAttribute('Faction')
check(esp.GetRelation(enemy)=='Unknown','Missing custom attribute never guesses native teams')
own.attrs.Faction='A'; enemy.attrs.Faction='B'
check(esp.GetRelation(enemy)=='Enemy','Custom faction difference')
enemy.attrs.Faction='A'
check(esp.GetRelation(enemy)=='Teammate','Custom faction equality')
enemy.attrs.Faction=false
check(esp.GetRelation(enemy)=='Unknown','Boolean custom team rejected')
enemy.attrs.Faction=''
check(esp.GetRelation(enemy)=='Unknown','Empty custom team rejected')
own.attrs.Faction=0; enemy.attrs.Faction=0
check(esp.GetRelation(enemy)=='Teammate','Numeric zero is a valid explicit faction')
esp.SetTeamAttribute(''); tick()
workspace.CurrentCamera=nil; tick()
check(not highlight('Enemy').Enabled and not enemyName.Visible,'Camera loss clears stale overlays')
workspace.CurrentCamera=camera; tick()
enemy.Character.humanoid.Health=0; tick()
check(not highlight('Enemy').Enabled,'Dead targets hidden')
enemy.Character=character(); tick()
check(highlight('Enemy').Adornee==enemy.Character,'Respawn rebinds Highlight')
enemy.Character.Removed=true; tick()
check(not highlight('Enemy').Enabled,'Detached characters hidden')
enemy.Character=character(); enemy.Character.Head=nil; tick()
check(highlight('Enemy').Enabled and enemyName.Visible,'Missing head fallback')
enemy.Character.HumanoidRootPart.Position=vec(-10,10,10); tick()
check(highlight('Enemy').Enabled and not enemyName.Visible,'Offscreen hides drawings while retaining Highlight')
enemy.Character=character(); enemy.Character.humanoid.MaxHealth=0; tick()
check(highlight('Enemy').Enabled,'Zero max health does not break updates')
esp.SetEnabled(false)
check(not enemyName.Visible and not highlight('Enemy').Enabled,'Disable immediately hides all')
check(RunService.RenderStepped:Count()==0,'Disable disconnects render')
esp.SetEnabled(true); tick()
Players.PlayerRemoving:Fire(enemy)
check(enemyName.Removed and not highlight('Enemy'),'Departure destroys objects')
Players.PlayerAdded:Fire(enemy); tick()
check(highlight('Enemy')~=nil,'Rejoin creates fresh objects')
local snapshot=esp.GetConfig(); snapshot.ShowEnemies=false
check(esp.GetConfig().ShowEnemies,'Config copy is isolated')
check(not pcall(esp.SetMaxDistance,0/0),'Reject NaN range')
check(not pcall(esp.SetColorMode,'Bad'),'Reject invalid color mode')
esp.Destroy(); esp.Destroy(); esp.SetEnabled(true)
check(not esp.IsEnabled() and RunService.RenderStepped:Count()==0,'Destroy is final and idempotent')
check(Players.PlayerAdded:Count()==0 and Players.PlayerRemoving:Count()==0,'Player connections cleaned')
for _,o in instances do check(o.Destroyed,'All instances cleaned') end
for _,o in drawings do check(o.Removed,'All drawings cleaned') end
-- A fresh execution still works with no executor Drawing implementation.
Drawing=nil
local second=loadModule()
second.SetEnabled(true); tick()
check(highlight('Enemy').Enabled,'Highlight survives missing Drawing API')
check(#warnings==1,'Report Drawing failure once, not every object/frame')
second.Destroy()
check(RunService.RenderStepped:Count()==0,'Repeated execution cleans up')
print('ESP checks passed: '..checks)
