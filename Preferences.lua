-- Data-only profiles. No downloaded code, loadstring, or automatic execution.
local Preferences = {}
local LIMIT = 65536
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
function Preferences.new(options)
	local self = { Entries = {}, Order = {}, Destroyed = false, Busy = false }
	local codec, files = options.Codec, options.Files or {}
	local place = tostring(options.PlaceId)
	local function nameOK(name)
		return type(name) == "string" and #name > 0 and #name <= 40 and name:match("^[%w_-]+$") ~= nil
	end
	local function valid(entry, value)
		if entry.Kind == "boolean" then return type(value) == "boolean" end
		if entry.Kind == "number" then return finite(value) and value >= entry.Min and value <= entry.Max and value % 1 == 0 end
		if entry.Kind == "choice" then return type(value) == "string" and table.find(entry.Options, value) ~= nil end
		return type(value) == "string" and #value <= (entry.MaxLength or 128)
	end
	function self:Register(id, entry)
		assert(not self.Entries[id], "Duplicate setting: " .. id)
		assert(valid(entry, entry.Default), "Invalid default: " .. id)
		self.Entries[id] = entry; table.insert(self.Order, id)
	end
	function self:Snapshot()
		local values = {}
		for _, id in self.Order do values[id] = self.Entries[id].Get() end
		return values
	end
	function self:Validate(values)
		if type(values) ~= "table" then return false, "Settings must be an object" end
		for id, value in values do
			local entry = self.Entries[id]
			if not entry or not valid(entry, value) then return false, "Invalid setting: " .. tostring(id):sub(1, 80) end
		end
		return true
	end
	function self:Apply(values)
		if self.Destroyed or self.Busy then return false, "Settings are unavailable" end
		local ok, err = self:Validate(values); if not ok then return false, err end
		local before, applied = self:Snapshot(), {}
		self.Busy = true
		-- Options first; enable switches last. Callbacks must be synchronous.
		for _, active in { false, true } do
			for _, id in self.Order do
				local entry, value = self.Entries[id], values[id]
				if value == nil or (entry.Active == true) ~= active or before[id] == value then continue end
				table.insert(applied, id)
				local ran, accepted = pcall(entry.Set, value)
				if not ran or accepted == false or entry.Get() ~= value then
					local restored = true
					for i = #applied, 1, -1 do
						local key = applied[i]
						local rollback, result = pcall(self.Entries[key].Set, before[key])
						if not rollback or result == false or self.Entries[key].Get() ~= before[key] then restored = false end
					end
					self.Busy = false
					return false, "Could not apply " .. id .. (restored and "; previous settings restored" or "; restore incomplete, use Stop All")
				end
			end
		end
		self.Busy = false; return true
	end
	function self:Defaults()
		local values = {}; for _, id in self.Order do values[id] = self.Entries[id].Default end; return values
	end
	function self:Encode(bindings)
		local values = self:Snapshot()
		local validValues, reason = self:Validate(values); if not validValues then return nil, reason end
		local ok, text = pcall(function() return codec:JSONEncode({ Format = "DiqProfile", Version = 1, PlaceId = place, Settings = values, Keybinds = bindings }) end)
		if not ok or type(text) ~= "string" or #text > LIMIT then return nil, "Could not encode profile" end
		return text
	end
	function self:Decode(text)
		if type(text) ~= "string" or #text > LIMIT then return nil, "Profile exceeds 64 KiB" end
		local ok, data = pcall(function() return codec:JSONDecode(text) end)
		if not ok or type(data) ~= "table" then return nil, "Invalid JSON profile" end
		if data.Format ~= "DiqProfile" or data.Version ~= 1 then return nil, "Unsupported profile format/version" end
		if data.PlaceId ~= place then return nil, "Profile belongs to a different place" end
		local validSettings, reason = self:Validate(data.Settings)
		if not validSettings then return nil, reason end
		-- Full snapshots prevent accidental dependence on the previous profile.
		for _, id in self.Order do if data.Settings[id] == nil then return nil, "Profile is missing " .. id end end
		return data
	end
	function self:Save(name, text)
		if self.Destroyed then return false, "Settings are unavailable" end
		if not nameOK(name) then return false, "Name: 1-40 letters, digits, _ or -" end
		if type(text) ~= "string" or #text > LIMIT then return false, "Invalid profile data" end
		if type(files.writefile) ~= "function" or type(files.makefolder) ~= "function" then return false, "File saving unavailable; use Export JSON" end
		local path = "DiqProfiles/" .. place .. "/" .. name .. ".json"
		local ok = pcall(function()
			for _, folder in { "DiqProfiles", "DiqProfiles/" .. place } do
				if type(files.isfolder) ~= "function" or not files.isfolder(folder) then
					local made, result = pcall(files.makefolder, folder)
					if (not made or result == false) and (type(files.isfolder) ~= "function" or not files.isfolder(folder)) then error("Folder unavailable") end
				end
			end
			assert(files.writefile(path, text) ~= false, "Write refused")
		end)
		return ok, ok and path or "Write failed; use Export JSON"
	end
	function self:Read(name)
		if self.Destroyed then return nil, "Settings are unavailable" end
		if not nameOK(name) then return nil, "Invalid profile name" end
		if type(files.readfile) ~= "function" then return nil, "File reading unavailable; use Import JSON" end
		local ok, text = pcall(files.readfile, "DiqProfiles/" .. place .. "/" .. name .. ".json")
		if not ok or type(text) ~= "string" then return nil, "Read failed; check profile name or use Import JSON" end
		if #text > LIMIT then return nil, "Profile exceeds 64 KiB" end
		return text
	end
	function self:Destroy() self.Destroyed = true end
	return self
end
return Preferences
