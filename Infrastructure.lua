-- Shared client infrastructure. No executor code runs when this file is loaded.
-- Factories accept dependencies so the same code can run in the CLI test harness.
local Infrastructure = {}

function Infrastructure.CreateScope(tasks, report)
	local scope = { Destroyed = false, entries = {}, order = {} }
	report = report or warn
	local function dispose(item)
		local ok = pcall(function()
			if type(item) == "function" then item()
			elseif type(item) == "thread" then
				if item ~= coroutine.running() and coroutine.status(item) ~= "dead" then tasks.cancel(item) end
			elseif item.Disconnect then item:Disconnect()
			else item:Destroy() end
		end)
		if not ok then report("[Diq] Resource cleanup failed") end
	end
	function scope:Remove(key)
		local item = self.entries[key]
		self.entries[key] = nil
		local index = table.find(self.order, key)
		if index then table.remove(self.order, index) end
		if item then dispose(item) end
	end
	function scope:Add(item, key)
		key = key or item
		self:Remove(key)
		if self.Destroyed then dispose(item); return item end
		self.entries[key] = item
		table.insert(self.order, key)
		return item
	end
	function scope:Delay(seconds, callback, ...)
		if self.Destroyed then return nil end
		local args = table.pack(...)
		local token = {}
		local thread = tasks.delay(seconds, function()
			-- Retain yielding work until completion so Destroy can still cancel it.
			if not self.Destroyed then
				local ok = pcall(callback, table.unpack(args, 1, args.n))
				if not ok then report("[Diq] Scheduled action failed") end
			end
			self.entries[token] = nil
			local index = table.find(self.order, token)
			if index then table.remove(self.order, index) end
		end)
		self:Add(thread, token)
		return thread
	end
	function scope:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		while #self.order > 0 do self:Remove(self.order[#self.order]) end
	end
	return scope
end

-- One baseline per instance/property, with independent feature ownership.
-- Last acquired owner wins. Updating an existing claim does not steal priority.
function Infrastructure.CreateProperties()
	local store = { objects = {}, owners = {}, sequence = 0 }
	local function winner(entry)
		local selected
		for _, claim in entry.claims do
			if not selected or claim.order > selected.order then selected = claim end
		end
		return selected
	end
	local function apply(entry, value)
		local ok = pcall(function()
			if entry.object[entry.property] ~= value then entry.object[entry.property] = value end
			entry.last = value
		end)
		return ok
	end
	function store:Set(owner, object, property, value)
		local fields = self.objects[object]
		if not fields then fields = {}; self.objects[object] = fields end
		local entry = fields[property]
		if not entry then
			entry = { object = object, property = property, baseline = object[property], claims = {} }
			fields[property] = entry
		end
		local claim = entry.claims[owner]
		if not claim then
			self.sequence += 1
			claim = { order = self.sequence }
			entry.claims[owner] = claim
			self.owners[owner] = self.owners[owner] or {}
			self.owners[owner][entry] = true
		end
		claim.value = value
		return apply(entry, winner(entry).value)
	end
	function store:Release(owner, object)
		local entries = self.owners[owner]
		if not entries then return end
		for entry in entries do
			if object == nil or entry.object == object then
				entries[entry] = nil
				entry.claims[owner] = nil
				local remaining = winner(entry)
				if remaining then apply(entry, remaining.value)
				else
					-- Preserve external changes made since our last write.
					pcall(function()
						if entry.object[entry.property] == entry.last then apply(entry, entry.baseline) end
					end)
					local fields = self.objects[entry.object]
					fields[entry.property] = nil
					if next(fields) == nil then self.objects[entry.object] = nil end
				end
			end
		end
		if next(entries) == nil then self.owners[owner] = nil end
	end
	function store:Destroy()
		while next(self.owners) do self:Release(next(self.owners)) end
	end
	return store
end

-- Fan-out channels keep one engine connection per input event. Subscribers own
-- their handles, and failures cannot prevent other subscribers from receiving input.
function Infrastructure.CreateInput(service, report)
	local router = { channels = {}, Destroyed = false }
	report = report or warn
	function router:Connect(event, callback)
		assert(not self.Destroyed, "Input router destroyed")
		local channel = self.channels[event]
		if not channel then
			channel = { listeners = {} }
			self.channels[event] = channel
			channel.connection = service[event]:Connect(function(...)
				local snapshot = channel.listeners
				for _, handle in snapshot do
					if handle.Connected then
						local ok = pcall(handle.callback, ...)
						if not ok then report("[Diq] Input callback failed: " .. event) end
					end
				end
			end)
		end
		local handle = { Connected = true, callback = callback }
		local routerRef = self
		function handle:Disconnect()
			if not self.Connected then return end
			self.Connected = false
			self.callback = nil
			local listeners = table.clone(channel.listeners)
			local index = table.find(listeners, self)
			if index then table.remove(listeners, index) end
			channel.listeners = listeners
			if #listeners == 0 then
				channel.connection:Disconnect()
				routerRef.channels[event] = nil
			end
		end
		local listeners = table.clone(channel.listeners)
		table.insert(listeners, handle)
		channel.listeners = listeners
		return handle
	end
	function router:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		for _, channel in self.channels do
			for _, handle in channel.listeners do handle:Disconnect() end
		end
	end
	return router
end

function Infrastructure.CreateScheduler(runService, clock, report)
	local scheduler = { phases = {}, stats = {}, Destroyed = false }
	report = report or warn
	function scheduler:Connect(name, phase, interval, callback, onError)
		assert(not self.Destroyed, "Scheduler destroyed")
		assert(interval >= 0, "Invalid interval")
		local group = self.phases[phase]
		if not group then
			group = { jobs = {} }
			self.phases[phase] = group
			group.connection = runService[phase]:Connect(function(dt)
				local snapshot = group.jobs
				for _, job in snapshot do
					if not job.Connected then continue end
					job.elapsed += dt
					if job.elapsed < job.interval then continue end
					local elapsed = job.elapsed
					job.elapsed = job.interval > 0 and job.elapsed % job.interval or 0
					local started = clock()
					local ok = pcall(job.callback, elapsed)
					local duration = clock() - started
					local stats = self.stats[job.name]
					stats.Calls += 1; stats.Total += duration; stats.Max = math.max(stats.Max, duration)
					if not ok then
						stats.Failures += 1
						job:Disconnect()
						if job.onError then pcall(job.onError) end
						report("[Diq] Scheduled task stopped: " .. job.name)
					end
				end
			end)
		end
		self.stats[name] = self.stats[name] or { Calls = 0, Total = 0, Max = 0, Failures = 0 }
		local job = { Connected = true, name = name, callback = callback, onError = onError, interval = interval, elapsed = 0 }
		local schedulerRef = self
		function job:Disconnect()
			if not self.Connected then return end
			self.Connected = false; self.callback = nil
			local jobs = table.clone(group.jobs)
			local index = table.find(jobs, self)
			if index then table.remove(jobs, index) end
			group.jobs = jobs
			if #jobs == 0 then group.connection:Disconnect(); schedulerRef.phases[phase] = nil end
		end
		local jobs = table.clone(group.jobs)
		table.insert(jobs, job); group.jobs = jobs
		return job
	end
	function scheduler:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		for _, group in self.phases do for _, job in group.jobs do job:Disconnect() end end
	end
	return scheduler
end

function Infrastructure.CreateRegistry(players, tasks, report)
	local registry = { records = {}, players = {}, Destroyed = false }
	local scope = Infrastructure.CreateScope(tasks, report)
	local function attach(record, character)
		if record.scope then record.scope:Destroy() end
		record.Character, record.Root, record.Humanoid, record.Head = character, nil, nil, nil
		record.Parts = {}
		record.scope = Infrastructure.CreateScope(tasks, report)
		if not character then return end
		local function refresh()
			record.Root = character:FindFirstChild("HumanoidRootPart")
			record.Head = character:FindFirstChild("Head")
			record.Humanoid = character:FindFirstChildOfClass("Humanoid")
		end
		record.scope:Add(character.DescendantAdded:Connect(function(part)
			if record.Character ~= character then return end
			if part:IsA("BasePart") then record.Parts[part] = true end
			refresh()
		end))
		record.scope:Add(character.DescendantRemoving:Connect(function(part)
			if record.Character ~= character then return end
			record.Parts[part] = nil
			-- Removing may fire before Parent changes; never re-cache the removed object.
			if record.Root == part then record.Root = nil end
			if record.Head == part then record.Head = nil end
			if record.Humanoid == part then record.Humanoid = nil end
		end))
		for _, part in character:GetDescendants() do if part:IsA("BasePart") then record.Parts[part] = true end end
		refresh()
	end
	local function remove(player)
		local record = registry.records[player]
		if not record then return end
		record.playerScope:Destroy()
		if record.scope then record.scope:Destroy() end
		registry.records[player] = nil
		local list = table.clone(registry.players)
		local index = table.find(list, player)
		if index then table.remove(list, index) end
		registry.players = list
	end
	local function add(player)
		if registry.Destroyed or registry.records[player] then return end
		local record = { playerScope = Infrastructure.CreateScope(tasks, report) }
		registry.records[player] = record
		local list = table.clone(registry.players); table.insert(list, player); registry.players = list
		record.playerScope:Add(player.CharacterAdded:Connect(function(character) attach(record, character) end))
		record.playerScope:Add(player.CharacterRemoving:Connect(function(character)
			if record.Character == character then attach(record, nil) end
		end))
		attach(record, player.Character)
	end
	function registry:Get(player) return self.records[player] end
	-- Borrowed snapshot: callers must not mutate it.
	function registry:GetPlayers() return self.players end
	function registry:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true; scope:Destroy()
		for player in self.records do remove(player) end
	end
	local ok, err = pcall(function()
		scope:Add(players.PlayerAdded:Connect(add)); scope:Add(players.PlayerRemoving:Connect(remove))
		for _, player in players:GetPlayers() do add(player) end
	end)
	if not ok then registry:Destroy(); error(err, 0) end
	return registry
end

function Infrastructure.new(dependencies)
	local deps = dependencies or {}
	local tasks, report = deps.Task or task, deps.Warn or warn
	local runtime = { Destroyed = false }
	runtime.Scope = Infrastructure.CreateScope(tasks, report)
	function runtime:CreateScope() return Infrastructure.CreateScope(tasks, report) end
	function runtime:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true; self.Scope:Destroy()
	end
	local ok, err = pcall(function()
		local players = deps.Players or game:GetService("Players")
		local runService = deps.RunService or game:GetService("RunService")
		local input = deps.Input or game:GetService("UserInputService")
		runtime.Properties = runtime.Scope:Add(Infrastructure.CreateProperties())
		runtime.Registry = runtime.Scope:Add(Infrastructure.CreateRegistry(players, tasks, report))
		runtime.Input = runtime.Scope:Add(Infrastructure.CreateInput(input, report))
		runtime.Scheduler = runtime.Scope:Add(Infrastructure.CreateScheduler(runService, deps.Clock or os.clock, report))
		runtime.Adapters = deps.Adapters or {
			CreateDrawing = function(kind)
				assert(Drawing and type(Drawing.new) == "function", "Drawing unavailable")
				return Drawing.new(kind)
			end,
			MoveMouse = function(x, y)
				assert(type(mousemoverel) == "function", "mousemoverel unavailable")
				mousemoverel(x, y)
			end,
		}
	end)
	if not ok then runtime:Destroy(); error(err, 0) end
	return runtime
end

return Infrastructure
