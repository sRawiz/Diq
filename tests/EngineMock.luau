-- Deterministic engine substitute. It measures control flow/resource ownership,
-- not physics, rendering, network permissions, or executor compatibility.
local signals = {}
local function signal()
	local s = { listeners = {} }
	function s:Connect(callback)
		local handle = { Connected = true, callback = callback }
		function handle:Disconnect() self.Connected = false; self.callback = nil end
		table.insert(self.listeners, handle); return handle
	end
	function s:Once(callback)
		local handle
		handle = self:Connect(function(...) handle:Disconnect(); callback(...) end)
		return handle
	end
	function s:Fire(...)
		for _, handle in table.clone(self.listeners) do if handle.Connected then handle.callback(...) end end
	end
	function s:Count()
		local count = 0; for _, handle in self.listeners do if handle.Connected then count += 1 end end; return count
	end
	table.insert(signals, s); return s
end
local now, queue = 0, {}
local task = {}
function task.delay(seconds, callback, ...)
	local args = table.pack(...)
	local thread = coroutine.create(function() callback(table.unpack(args, 1, args.n)) end)
	queue[thread] = now + seconds; return thread
end
function task.cancel(thread) queue[thread] = nil; coroutine.close(thread) end
function task.spawn(callback, ...) return task.delay(0, callback, ...) end
function task.defer(callback, ...) return task.delay(0, callback, ...) end
function task.wait(seconds)
	local delay=seconds or 0
	queue[coroutine.running()]=now+delay
	coroutine.yield(delay)
	return delay
end
local function advance(seconds)
	now += seconds
	local due = {}
	for thread, deadline in queue do if deadline <= now then table.insert(due, thread) end end
	for _, thread in due do
		if queue[thread] then
			queue[thread] = nil
			local ok, delay = coroutine.resume(thread)
			assert(ok, delay)
			if coroutine.status(thread) ~= "dead" then queue[thread] = now + (delay or 0) end
		end
	end
end
local function runYielding(callback, ...)
	local args, result = table.pack(...), nil
	task.spawn(function() result = table.pack(callback(table.unpack(args, 1, args.n))) end)
	for _ = 1, 200 do
		advance(0)
		if result then return table.unpack(result, 1, result.n) end
	end
	error("Mock operation did not complete")
end
local function liveConnections()
	local count = 0; for _, s in signals do count += s:Count() end; return count
end
local vectorMT = {}
local function vec(x, y, z) return setmetatable({X=x,Y=y,Z=z or 0}, vectorMT) end
vectorMT.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if key == "Unit" then return vec(v.X/v.Magnitude,v.Y/v.Magnitude,v.Z/v.Magnitude) end
end
vectorMT.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMT.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMT.__mul = function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
vectorMT.__div = function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
vectorMT.__eq = function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local Vector2, Vector3 = {new=vec}, {new=vec,zero=vec(0,0,0),xAxis=vec(1,0,0),yAxis=vec(0,1,0)}
local Color3 = {}
function Color3.new(r,g,b)
	local c={R=r,G=g,B=b,__type="Color3"}
	function c:Lerp(other,t) return Color3.new(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t) end
	return c
end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local UDim = {new=function(scale,offset) return {Scale=scale,Offset=offset} end}
local UDim2 = {new=function(x,ox,y,oy) return {X=UDim.new(x,ox),Y=UDim.new(y,oy)} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local CFrame = {}
function CFrame.lookAt(position, target)
	local frame = {Position=position,LookVector=(target-position).Unit,RightVector=vec(1,0,0)}
	function frame:Lerp(other,alpha) return CFrame.lookAt(self.Position,self.Position+self.LookVector*(1-alpha)+other.LookVector*alpha) end
	return setmetatable(frame,{__add=function(a,b) return CFrame.lookAt(a.Position+b,a.Position+b+a.LookVector) end})
end
CFrame.new = CFrame.lookAt
local Enum = setmetatable({}, {__index=function(enums,groupName)
	local group = setmetatable({}, {__index=function(items,name)
		local item={Name=name,Value=name=="Last" and 2000 or 200,EnumType=items,__type="EnumItem"}
		rawset(items,name,item); return item
	end})
	rawset(enums,groupName,group); return group
end})
local typeof = function(value)
	if type(value)=="table" and value.__type then return value.__type end
	if type(value)=="table" and value.Connected~=nil then return "RBXScriptConnection" end
	return type(value)
end
local warnings = {}
local warn = function(message) table.insert(warnings, message) end
local methods, instanceMT = {}, {}
local instances = {}
local signalNames = {Changed=true,Destroying=true,ChildAdded=true,ChildRemoved=true,DescendantAdded=true,DescendantRemoving=true,
 CharacterAdded=true,CharacterRemoving=true,Idled=true,InputBegan=true,InputEnded=true,InputChanged=true,MouseEnter=true,MouseLeave=true,
 MouseButton1Click=true,Activated=true,Focused=true,FocusLost=true}
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
	self.calls.descendants = (self.calls.descendants or 0)+1
	local result={}
	local function visit(object) for _,child in object.children do table.insert(result,child); visit(child) end end
	visit(self); return result
end
function methods:FindFirstChild(name) for _,child in self.children do if child.Name==name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:FindFirstChildOfClass(class) for _,child in self.children do if child.ClassName==class then return child end end end
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:IsDescendantOf(parent)
	local current=self.Parent; while current do if current==parent then return true end; current=current.Parent end; return false
end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:GetPropertyChangedSignal(name)
	self.propertySignals[name] = self.propertySignals[name] or signal(); return self.propertySignals[name]
end
function methods:ChangeState(state) self.State=state end
function methods:Destroy()
	if self.Destroyed then return end
	self.Destroying:Fire(); self.Destroyed=true
	for _,child in self:GetChildren() do child:Destroy() end
	self.Parent=nil
	for _,s in self.events do for _,c in s.listeners do c:Disconnect() end end
	for _,s in self.propertySignals do for _,c in s.listeners do c:Disconnect() end end
end
instanceMT.__index = function(object,key)
	if methods[key] then return methods[key] end
	if signalNames[key] then object.events[key]=object.events[key] or signal(); return object.events[key] end
	if object.props[key]~=nil then return object.props[key] end
	return methods.FindFirstChild(object,key)
end
instanceMT.__newindex = function(object,key,value)
	local old=object.props[key]
	if old==value then return end
	if key=="Parent" and old then
		local cursor=old; while cursor do cursor.DescendantRemoving:Fire(object); cursor=cursor.Parent end
		local index=table.find(old.children,object); if index then table.remove(old.children,index) end
		old.ChildRemoved:Fire(object)
	end
	object.props[key]=value
	object.writes[key]=(object.writes[key] or 0)+1
	if key=="Parent" and value then
		table.insert(value.children,object); value.ChildAdded:Fire(object)
		local cursor=value; while cursor do cursor.DescendantAdded:Fire(object); cursor=cursor.Parent end
	end
	if object.events.Changed then object.events.Changed:Fire(key) end
	if object.propertySignals[key] then object.propertySignals[key]:Fire() end
end
local Instance = {}
function Instance.new(class)
	local object=setmetatable({props={ClassName=class,Name=class,AbsolutePosition=vec(0,0),AbsoluteSize=vec(520,380),
	 AbsoluteContentSize=vec(0,0),Visible=true,Text="",Position=vec(400,300,10),CanCollide=true,Size=vec(2,2,2),Transparency=0},
	 children={},events={},propertySignals={},attrs={},calls={},writes={}},instanceMT)
	table.insert(instances,object); return object
end
local workspace=Instance.new("Workspace")
local camera={CFrame=CFrame.lookAt(vec(0,0,0),vec(0,0,1)),ViewportSize=vec(800,600)}
function camera:WorldToViewportPoint(position) return position,position.Z>0 end
workspace.CurrentCamera=camera
function methods:Raycast() return nil end
local Players={list={},PlayerAdded=signal(),PlayerRemoving=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),enumerations=0}
function Players:GetPlayers() self.enumerations+=1; return table.clone(self.list) end
local function newCharacter()
	local character=Instance.new("Model"); character.Parent=workspace
	for _,name in {"Head","HumanoidRootPart"} do local part=Instance.new("Part"); part.Name=name; part.Parent=character end
	local humanoid=Instance.new("Humanoid"); humanoid.Health=100; humanoid.MaxHealth=100; humanoid.PlatformStand=false
	humanoid.MoveDirection=vec(0,0,0); humanoid.Parent=character
	character.HumanoidRootPart.CFrame=CFrame.lookAt(vec(0,0,0),vec(0,0,1))
	return character
end
local function newPlayer(name,team)
	local player=Instance.new("Player"); player.Name=name; player.Team=team; player.Neutral=false; player.UserId=#Players.list+1
	player.TeamColor={Color=Color3.new(0,0,1)}; player.Character=newCharacter()
	player.props.Parent=Players
	table.insert(Players.list,player); return player
end
local own, enemy = newPlayer("Own","blue"),newPlayer("Enemy","red")
Players.LocalPlayer=own
local playerGui=Instance.new("PlayerGui"); playerGui.Parent=own
local RunService={PreSimulation=signal(),RenderStepped=signal(),Heartbeat=signal(),bindings={}}
function RunService:BindToRenderStep(name,priority,callback) self.bindings[name]=callback end
function RunService:UnbindFromRenderStep(name) self.bindings[name]=nil end
local Input={InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),WindowFocused=signal(),WindowFocusReleased=signal(),TextBoxFocused=signal(),JumpRequest=signal(),MouseBehavior=Enum.MouseBehavior.Default}
function Input:GetFocusedTextBox() return self.textbox end
function Input:IsKeyDown() return false end
function Input:GetMouseLocation() return vec(400,300) end
local Lighting=Instance.new("Lighting")
Lighting.Ambient=Color3.new(0,0,0); Lighting.ColorShift_Bottom=Color3.new(0,0,0); Lighting.ColorShift_Top=Color3.new(0,0,0)
Lighting.GlobalShadows=true; Lighting.FogEnd=1000; Lighting.Brightness=1
local CoreGui=Instance.new("CoreGui")
local TweenService={created={}}
function TweenService:Create(object,info,props)
	local tween={Completed=signal(),PlaybackState=Enum.PlaybackState.Begin}
	local pending
	function tween:Play()
		self.PlaybackState=Enum.PlaybackState.Playing
		for key,value in props do object[key]=value end
		pending=task.delay(0,function()
			pending=nil; self.PlaybackState=Enum.PlaybackState.Completed; self.Completed:Fire(self.PlaybackState)
		end)
	end
	function tween:Cancel()
		if self.PlaybackState~=Enum.PlaybackState.Playing then return end
		if pending then task.cancel(pending); pending=nil end
		self.PlaybackState=Enum.PlaybackState.Cancelled; self.Completed:Fire(self.PlaybackState)
	end
	table.insert(self.created,tween)
	return tween
end
local TweenInfo={new=function(...) return {...} end}
local RaycastParams={new=function() return {} end}
local GuiService={MenuIsOpen=false,MenuOpened=signal(),GetGuiInset=function() return vec(0,0) end}
local TeleportService={TeleportInitFailed=signal(),Teleport=function() end,TeleportToPlaceInstance=function() end}
local VirtualUser={CaptureController=function() end,ClickButton2=function() end}
local services={Players=Players,RunService=RunService,UserInputService=Input,Lighting=Lighting,CoreGui=CoreGui,
 TweenService=TweenService,GuiService=GuiService,TeleportService=TeleportService,VirtualUser=VirtualUser,
 MarketplaceService={GetProductInfo=function() return {Name="Test"} end}, HttpService={}}
local game={PlaceId=1,JobId="test"}
function game:GetService(name) return assert(services[name],name) end
local drawings={}
local Drawing={new=function(class)
	local object={ClassName=class}; function object:Remove() self.Removed=true end
	table.insert(drawings,object); return object
end}
local _G={}
local loadstring
local checks=0
local function check(condition,message) checks+=1; assert(condition,message) end
