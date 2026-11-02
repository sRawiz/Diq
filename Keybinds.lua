-- One dispatcher for application shortcuts, independent of widget lifetimes.
local Keybinds = {}
function Keybinds.new(options)
	local self = { Entries = {}, Order = {}, Pressed = {}, Held = {}, Destroyed = false }
	local scope, input = options.Scope, options.Input
	local focused = true
	function self:Register(id, entry)
		assert(not self.Entries[id], "Duplicate shortcut")
		entry.DefaultKey, entry.DefaultMode = entry.Key, entry.Mode or "Toggle"
		entry.Mode = entry.DefaultMode
		self.Entries[id] = entry; table.insert(self.Order, id)
	end
	function self:Snapshot(defaults)
		local result = {}
		for _, id in self.Order do
			local e = self.Entries[id]
			result[id] = { Key = defaults and e.DefaultKey or e.Key, Mode = defaults and e.DefaultMode or e.Mode }
		end
		return result
	end
	function self:Validate(values)
		if type(values) ~= "table" then return false, "Keybinds must be an object" end
		local used = {}
		for id in values do if not self.Entries[id] then return false, "Unknown shortcut" end end
		for _, id in self.Order do
			local v, e = values[id], self.Entries[id]
			if type(v) ~= "table" or not options.ValidKey(v.Key) then return false, "Invalid key for " .. id end
			if v.Mode ~= "Toggle" and (v.Mode ~= "Hold" or not e.Set) then return false, "Invalid shortcut mode" end
			if v.Key ~= "None" then
				if used[v.Key] then return false, v.Key .. " is already used by " .. self.Entries[used[v.Key]].Label end
				used[v.Key] = id
			end
		end
		return true
	end
	local function run(callback, ...)
		local ok = pcall(callback, ...)
		if not ok and options.OnError then options.OnError("Shortcut failed") end
	end
	function self:Release()
		local held = self.Held; self.Held = {}; self.Pressed = {}
		for id in held do run(self.Entries[id].Set, false) end
	end
	function self:Apply(values)
		if self.Destroyed then return false, "Shortcuts are unavailable" end
		local ok, err = self:Validate(values); if not ok then return false, err end
		self:Release()
		for _, id in self.Order do local e, v = self.Entries[id], values[id]; e.Key, e.Mode = v.Key, v.Mode end
		if options.OnChanged then options.OnChanged() end
		return true
	end
	function self:Change(id, key, mode)
		local values = self:Snapshot()
		if not values[id] then return false, "Unknown shortcut" end
		values[id] = { Key = key, Mode = mode }; return self:Apply(values)
	end
	scope:Add(input:Connect("InputBegan", function(event, processed)
		if self.Destroyed or processed or not focused or options.Blocked() or event.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local key = event.KeyCode.Name
		if self.Pressed[key] then return end
		self.Pressed[key] = true
		for _, id in self.Order do
			local e = self.Entries[id]
			if e.Key ~= key then continue end
			if e.Mode == "Hold" then self.Held[id] = true; run(e.Set, true)
			else run(e.Toggle) end
			break
		end
	end))
	scope:Add(input:Connect("InputEnded", function(event)
		if event.UserInputType ~= Enum.UserInputType.Keyboard then return end
		self.Pressed[event.KeyCode.Name] = nil
		for id in self.Held do
			if self.Entries[id].Key == event.KeyCode.Name then self.Held[id] = nil; run(self.Entries[id].Set, false) end
		end
	end))
	scope:Add(input:Connect("WindowFocusReleased", function() focused = false; self:Release() end))
	scope:Add(input:Connect("WindowFocused", function() focused = true end))
	function self:Destroy() if self.Destroyed then return end; self:Release(); self.Destroyed = true; scope:Destroy() end
	return self
end
return Keybinds
