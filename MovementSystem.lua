local ModuleOptions = ...
local Runtime = type(ModuleOptions) == "table" and ModuleOptions.Runtime
local Movement = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local initialized, destroyed = false, false
local Config = { FlySpeed = 100, CFrameSpeed = 60 }
local State = { IsFlying = false, IsCFrameSpeed = false, IsInfinityJump = false, IsNoClip = false, IsNoFling = false }
local connections, originals = {}, {}
local flyOwner, clipOwner, flingOwner = {}, {}, {}
local attachment, velocity, flyRoot
local listener

local function disconnect(key)
	if connections[key] then connections[key]:Disconnect(); connections[key] = nil end
end
local function changed()
	if listener then
		local ok = pcall(listener, Movement.GetState())
		if not ok then warn("[Diq] Movement state listener failed") end
	end
end
local function claim(owner, object, property, value)
	if Runtime then
		assert(Runtime.Properties:Set(owner, object, property, value), "Movement property write failed")
		return
	end
	-- Direct execution stays self-contained; Main supplies shared ownership.
	originals[owner] = originals[owner] or {}
	local objects = originals[owner]
	objects[object] = objects[object] or {}
	local fields = objects[object]
	if not fields[property] then fields[property] = { value = object[property] } end
	fields[property].last = value
	if object[property] ~= value then object[property] = value end
end
local function release(owner, object)
	if Runtime then Runtime.Properties:Release(owner, object); return end
	for instance, fields in originals[owner] or {} do
		if not object or instance == object then
			for property, data in fields do
				pcall(function() if instance[property] == data.last then instance[property] = data.value end end)
			end
			originals[owner][instance] = nil
		end
	end
	if not object then originals[owner] = nil end
end
local function data()
	if Runtime then
		local record = Runtime.Registry:Get(LocalPlayer)
		return record and record.Root, record and record.Humanoid
	end
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
end
local function clearFlight()
	if velocity then velocity:Destroy(); velocity = nil end
	if attachment then attachment:Destroy(); attachment = nil end
	flyRoot = nil; release(flyOwner)
end
local function setupFlight(root, humanoid)
	if flyRoot ~= root then
		clearFlight()
		attachment = Instance.new("Attachment")
		attachment.Name = "DiqFlyAttachment"; attachment.Parent = root
		velocity = Instance.new("LinearVelocity")
		velocity.Name = "DiqFlyVelocity"; velocity.Attachment0 = attachment
		velocity.MaxForce = math.huge; velocity.VectorVelocity = Vector3.zero; velocity.Parent = root
		flyRoot = root
	end
	claim(flyOwner, humanoid, "PlatformStand", true)
end
local function connectStep(name, callback)
	if Runtime then
		return Runtime.Scheduler:Connect("Movement." .. name, "PreSimulation", 0, callback, function()
			Movement.SetFly(false); Movement.SetSpeed(false); Movement.SetNoClip(false); Movement.SetNoFling(false)
		end)
	end
	return RunService.PreSimulation:Connect(callback)
end
local function updateMovement(dt)
	local root, humanoid = data()
	local camera = workspace.CurrentCamera
	if not root or not humanoid or not camera then clearFlight(); return end
	if State.IsFlying then setupFlight(root, humanoid) end
	if Input:GetFocusedTextBox() then return end
	if State.IsFlying then
		local direction = Vector3.zero
		if Input:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
		if Input:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
		if Input:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
		if Input:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
		if Input:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
		if Input:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
		if direction.Magnitude > 0 then direction = direction.Unit end
		local look = camera.CFrame.LookVector
		local horizontal = Vector3.new(look.X, 0, look.Z)
		local frame = root.CFrame
		if horizontal.Magnitude > 0.001 then frame = CFrame.lookAt(root.Position, root.Position + horizontal) end
		root.CFrame = frame + direction * Config.FlySpeed * math.min(dt, 0.1)
	elseif State.IsCFrameSpeed then
		local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
		if direction.Magnitude > 0 then root.CFrame += direction.Unit * Config.CFrameSpeed * math.min(dt, 0.1) end
	end
end
local function updateBinding()
	local needed = State.IsFlying or State.IsCFrameSpeed
	if needed and not connections.Move then connections.Move = connectStep("Move", updateMovement)
	elseif not needed then disconnect("Move") end
end
local function collisionStep(owner, others)
	-- Reuse generation marks instead of allocating a new set every step.
	local mark = {}
	local list = Runtime and Runtime.Registry:GetPlayers() or Players:GetPlayers()
	for _, player in list do
		if (others and player ~= LocalPlayer) or (not others and player == LocalPlayer) then
			local record = Runtime and Runtime.Registry:Get(player)
			local character = player.Character
			local parts = record and record.Parts
			if not Runtime and character then
				parts = {}; for _, part in character:GetDescendants() do if part:IsA("BasePart") then parts[part] = true end end
			end
			for part in parts or {} do
				if part.Parent then owner[part] = mark; claim(owner, part, "CanCollide", false) end
			end
		end
	end
	for part, seen in owner do if seen ~= mark then release(owner, part); owner[part] = nil end end
end
local function resetCharacter()
	Movement.SetFly(false); Movement.SetSpeed(false); Movement.SetNoClip(false)
	Movement.SetNoFling(false); Movement.SetInfinityJump(false)
end
function Movement.SetFly(enabled)
	if destroyed then return false end
	State.IsFlying = enabled == true
	if not State.IsFlying then clearFlight() end
	updateBinding(); changed(); return true
end
function Movement.SetSpeed(enabled)
	if destroyed then return false end
	State.IsCFrameSpeed = enabled == true; updateBinding(); changed(); return true
end
function Movement.SetNoClip(enabled)
	if destroyed then return false end
	State.IsNoClip = enabled == true
	if State.IsNoClip and not connections.Clip then
		connections.Clip = connectStep("NoClip", function() collisionStep(clipOwner, false) end)
	elseif not State.IsNoClip then disconnect("Clip"); release(clipOwner); table.clear(clipOwner) end
	changed(); return true
end
function Movement.SetNoFling(enabled)
	if destroyed then return false end
	State.IsNoFling = enabled == true
	if State.IsNoFling and not connections.Fling then
		connections.Fling = connectStep("NoFling", function() collisionStep(flingOwner, true) end)
	elseif not State.IsNoFling then disconnect("Fling"); release(flingOwner); table.clear(flingOwner) end
	changed(); return true
end
function Movement.SetInfinityJump(enabled)
	if destroyed then return false end
	State.IsInfinityJump = enabled == true
	if State.IsInfinityJump and not connections.Jump then
		local function jump()
			if destroyed or not State.IsInfinityJump or Input:GetFocusedTextBox() then return end
			local _, humanoid = data()
			if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
		end
		connections.Jump = Runtime and Runtime.Input:Connect("JumpRequest", jump) or Input.JumpRequest:Connect(jump)
	elseif not State.IsInfinityJump then disconnect("Jump") end
	changed(); return true
end
function Movement.ToggleFly() Movement.SetFly(not State.IsFlying); return State.IsFlying end
function Movement.ToggleSpeed() Movement.SetSpeed(not State.IsCFrameSpeed); return State.IsCFrameSpeed end
function Movement.ToggleNoClip() Movement.SetNoClip(not State.IsNoClip); return State.IsNoClip end
function Movement.ToggleNoFling() Movement.SetNoFling(not State.IsNoFling); return State.IsNoFling end
local function finite(value)
	assert(type(value) == "number" and value == value and value >= 0 and value < math.huge, "Expected finite nonnegative speed")
	return value
end
function Movement.SetFlySpeed(value) if not destroyed then Config.FlySpeed = finite(value) end end
function Movement.SetCFrameSpeed(value) if not destroyed then Config.CFrameSpeed = finite(value) end end
function Movement.ResetCharacter() if destroyed then return end; local _, humanoid = data(); if humanoid then humanoid.Health = 0 end end
function Movement.Unanchor() if destroyed then return end; local root = data(); if root then root.Anchored = false end end
function Movement.GetState()
	local result = table.clone(State); result.FlySpeed = Config.FlySpeed; result.CFrameSpeed = Config.CFrameSpeed; return result
end
function Movement.SetStateListener(callback) listener = callback end
function Movement.Init()
	assert(not destroyed, "Cannot initialize destroyed Movement")
	if initialized then return end
	initialized = true
	connections.Character = LocalPlayer.CharacterAdded:Connect(resetCharacter)
	connections.Removing = LocalPlayer.CharacterRemoving:Connect(resetCharacter)
	connections.Focus = Runtime and Runtime.Input:Connect("WindowFocusReleased", resetCharacter) or Input.WindowFocusReleased:Connect(resetCharacter)
end
function Movement.Destroy()
	if destroyed then return end
	resetCharacter(); destroyed = true; listener = nil
	for key in connections do disconnect(key) end
end
if type(ModuleOptions) ~= "table" or not ModuleOptions.DeferInit then Movement.Init() end
return Movement
