local function CreateConnectionTracker(parent)
	local tracker = { _list = {}, Alive = true }
	function tracker:Track(item)
		if not self.Alive then
			if type(item) == "function" then item()
			elseif item.Disconnect then item:Disconnect()
			else item:DisconnectAll() end
			return item
		end
		self._list[item] = true
		return item
	end
	function tracker:Invoke(callback, ...)
		if not self.Alive then return end
		local args = table.pack(...)
		local thread
		thread = coroutine.create(function()
			local ok = pcall(callback, table.unpack(args, 1, args.n))
			self._list[thread] = nil
			if not ok then warn("[Diq] UI callback failed") end
		end)
		self._list[thread] = true
		-- Non-yielding setters finish synchronously. Yielding user callbacks do
		-- not block the input dispatcher and remain cancellable by their owner.
		local ok = coroutine.resume(thread)
		if not ok then self._list[thread] = nil; warn("[Diq] UI callback could not start") end
	end
	function tracker:Once(event, callback)
		local connection
		connection = event:Once(function(...)
			self._list[connection] = nil
			self:Invoke(callback, ...)
		end)
		return self:Track(connection)
	end
	function tracker:Delay(seconds, callback, ...)
		if not self.Alive then return end
		local args = table.pack(...)
		local thread
		thread = task.delay(seconds, function()
			-- Keep in the set while yielding so Destroy can still cancel it.
			if self.Alive then self:Invoke(callback, table.unpack(args, 1, args.n)) end
			self._list[thread] = nil
		end)
		self._list[thread] = true
		return thread
	end
	function tracker:Spawn(callback, ...) return self:Delay(0, callback, ...) end
	function tracker:DisconnectAll()
		if not self.Alive then return end
		self.Alive = false
		if parent then parent._list[self] = nil end
		for item in self._list do
			pcall(function()
				if type(item) == "function" then item()
				elseif type(item) == "thread" then
					if item ~= coroutine.running() and coroutine.status(item) ~= "dead" then task.cancel(item) end
				elseif item.Disconnect then item:Disconnect()
				else item:DisconnectAll() end
			end)
		end
		table.clear(self._list)
	end
	if parent then parent:Track(tracker) end
	return tracker
end

local function RegisterElement(elements, obj, tracker, resettable)
	if resettable then table.insert(elements, obj) end
	local destroy = obj.Destroy
	tracker:Track(function()
		local index = table.find(elements, obj)
		if index then table.remove(elements, index) end
		if destroy then destroy() end
	end)
	obj.Destroy = function() tracker:DisconnectAll() end
	for _, key in { "Set", "Reset", "SetText", "SetVisible", "SetOptions", "SetPlaceholder", "SetCallback", "SetSlider" } do
		local method = obj[key]
		if method then
			obj[key] = function(...)
				if tracker.Alive then return method(...) end
			end
		end
	end
end

return { new = CreateConnectionTracker, Register = RegisterElement }
