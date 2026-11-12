-- Application settings, shortcuts and tools. Feature modules remain independent.
local ControlCenter = {}
local activeIds = {
	["movement.cframe_fly"] = true, ["movement.cframe_speed"] = true,
	["movement.infinite_jump"] = true, ["movement.noclip"] = true, ["movement.anti_fling"] = true,
	["aim.aim_assist"] = true, ["combat.enable_hitbox_expander"] = true,
	["visual.enable_esp"] = true, ["visual.fullbright_no_fog"] = true,
	["settings.anti_afk_prevent_idle_kick"] = true,
}
local budgets = {
	Low = { Interval = 1/20, Visuals = 20, Distance = 500, Scan = 0.25 },
	Balanced = { Interval = 1/30, Visuals = 50, Distance = 1500, Scan = 0.1 },
	High = { Interval = 0, Visuals = 0, Distance = 0, Scan = 0.1 },
}
local function slug(text) return text:lower():gsub("[^%w]+", "_"):gsub("^_", ""):gsub("_$", "") end
function ControlCenter.new(options)
	local self = { Destroyed = false, Controls = {}, Order = {}, Errors = {}, Capabilities = {}, Performance = "High" }
	local app, window, ui, runtime = options.App, options.Window, options.UI, options.Runtime
	local modules = options.Modules
	local scope = runtime:CreateScope()
	runtime.Scope:Add(scope)
	local input, gui = game:GetService("UserInputService"), game:GetService("GuiService")
	local codec = game:GetService("HttpService")
	local files = { readfile = readfile, writefile = writefile, makefolder = makefolder, isfolder = isfolder }
	self.Settings = options.Preferences.new({ Codec = codec, PlaceId = game.PlaceId, Files = files })
	local function notice(ok, text)
		if self.Destroyed then return end
		ui:Notify(ok and "Diq" or "Action unavailable", text, 3, ok and "success" or "warning")
	end
	local function fail(message)
		if #self.Errors >= 10 then table.remove(self.Errors, 1) end
		table.insert(self.Errors, message); notice(false, message)
	end
	local function validKey(name)
		if name == "None" then return true end
		if type(name) ~= "string" or #name > 32 or name == "Unknown" or name == "Escape" then return false end
		local ok, key = pcall(function() return Enum.KeyCode[name] end)
		return ok and key ~= nil
	end
	self.Keys = options.Keybinds.new({
		Scope = runtime.Scope:Add(runtime:CreateScope()), Input = runtime.Input, ValidKey = validKey,
		Blocked = function() return input:GetFocusedTextBox() ~= nil or gui.MenuIsOpen or window:IsCapturingKeybind() end,
		OnError = fail, OnChanged = function() if self.RefreshKeys then self.RefreshKeys() end end,
	})
	local function release() self.Keys:Release() end
	scope:Add(runtime.Input:Connect("TextBoxFocused", release))
	scope:Add(gui.MenuOpened:Connect(release))
	scope:Add(game:GetService("Players").LocalPlayer.CharacterRemoving:Connect(release))
	modules.Aim.SetManagedInput(true)
	self.Keys:Register("window", { Label = "Show / Hide Window", Key = "K", Toggle = function() window:Toggle() end })
	self.Keys:Register("stop", { Label = "Stop All Features", Key = "End", Toggle = function() self:StopAll() end })
	self.Keys:Register("quick", { Label = "Quick Actions", Key = "F1", Toggle = function() if self.QuickTab then window:SelectTab(self.QuickTab) end end })
	local activeReads = {
		["movement.cframe_fly"] = function() return modules.Movement.GetState().IsFlying end,
		["movement.cframe_speed"] = function() return modules.Movement.GetState().IsCFrameSpeed end,
		["movement.infinite_jump"] = function() return modules.Movement.GetState().IsInfinityJump end,
		["movement.noclip"] = function() return modules.Movement.GetState().IsNoClip end,
		["movement.anti_fling"] = function() return modules.Movement.GetState().IsNoFling end,
		["aim.aim_assist"] = modules.Aim.IsEnabled, ["combat.enable_hitbox_expander"] = modules.Hitbox.IsEnabled,
		["visual.enable_esp"] = modules.ESP.IsEnabled, ["visual.fullbright_no_fog"] = modules.Misc.IsFullbright,
		["settings.anti_afk_prevent_idle_kick"] = modules.Misc.IsAntiAFK,
	}
	local function register(id, label, tab, widget, spec, callback, slider)
		local read = activeReads[id] or function() return slider and widget:GetSlider() or widget:Get() end
		local write = function(value)
			if self.Destroyed then return false end
			if slider then widget:SetSlider(value, true) else widget:Set(value, true) end
			if callback then return callback(value) end
		end
		spec.Get, spec.Set, spec.Active = read, write, activeIds[id] == true
		self.Settings:Register(id, spec)
		self.Controls[id] = { Label = label, Tab = tab, Widget = widget, Spec = spec }
		table.insert(self.Order, id)
	end
	function self:TrackTab(tab, prefix, rootTab)
		rootTab = rootTab or tab
		-- IDs are schema-v1 identifiers derived from the shipped English labels.
		-- Renaming labels requires an explicit profile migration, not silent remapping.
		local toggle, slider, dropdown, textInput = tab.CreateToggle, tab.CreateSlider, tab.CreateDropdown, tab.CreateInput
		local createSection = tab.CreateSection
		local owner = self
		function tab:CreateSection(...)
			return owner:TrackTab(createSection(self, ...), prefix, rootTab)
		end
		function tab:CreateToggle(label, default, callback, config)
			config = table.clone(config or {})
			local key = config.Keybind and config.Keybind.Default.Name or "None"
			config.Keybind = nil -- owned by the central dispatcher
			local widget = toggle(self, label, default, callback, config)
			local id = prefix .. "." .. slug(label)
			register(id, label, rootTab, widget, { Kind = "boolean", Default = default == true }, callback)
			if activeIds[id] then
				if id == "aim.aim_assist" then key = "Q" end
				local owner = self._controlCenter
				local function set(value) local ok, reason = owner.Settings:Apply({ [id] = value }); if not ok then fail(reason) end end
				owner.Keys:Register(id, { Label = label, Key = key, Set = set, Toggle = function() set(not owner.Settings.Entries[id].Get()) end })
			end
			if config.Slider then
				local s = config.Slider
				register(id .. ".value", s.Text, rootTab, widget, { Kind = "number", Default = s.Default, Min = s.Min, Max = s.Max }, s.Callback, true)
			end
			return widget
		end
		function tab:CreateSlider(label, min, max, default, callback)
			local widget = slider(self, label, min, max, default, callback)
			register(prefix .. "." .. slug(label), label, rootTab, widget, { Kind = "number", Default = default, Min = min, Max = max }, callback)
			return widget
		end
		function tab:CreateDropdown(label, choices, default, callback)
			local widget = dropdown(self, label, choices, default, callback)
			register(prefix .. "." .. slug(label), label, rootTab, widget, { Kind = "choice", Default = default, Options = table.clone(choices) }, callback)
			return widget
		end
		function tab:CreateInput(label, placeholder, callback)
			local widget = textInput(self, label, placeholder, callback)
			register(prefix .. "." .. slug(label), label, rootTab, widget, { Kind = "string", Default = "", MaxLength = 128 }, callback)
			return widget
		end
		tab._controlCenter = self
		return tab
	end
	function self:SetPerformance(name)
		local budget = budgets[name]
		if self.Destroyed or not budget then return false end
		modules.ESP.SetPerformance(budget.Interval, budget.Visuals, budget.Distance)
		modules.Aim.SetScanInterval(budget.Scan)
		self.Performance = name; return true
	end
	self.Settings:Register("performance", { Kind = "choice", Default = "High", Options = { "Low", "Balanced", "High" },
		Get = function() return self.Performance end,
		Set = function(value)
			local ok = self:SetPerformance(value)
			if self.PerformanceWidget then self.PerformanceWidget:Set(value, true) end
			return ok
		end,
	})
	function self:StopAll()
		if self.Destroyed then return false end
		self.Keys:Release()
		runtime.Scope:Remove("Actions")
		app.Actions = runtime.Scope:Add(runtime:CreateScope(), "Actions")
		if self.CancelSample then self.CancelSample() end
		if modules.Misc.CancelServerSearch then modules.Misc.CancelServerSearch() end
		local success = true
		for _, id in self.Settings.Order do
			local entry = self.Settings.Entries[id]
			if entry.Active then
				local ok, result = pcall(entry.Set, false)
				if not ok or result == false then success = false end
			end
		end
		-- Also stop features activated through the public module API.
		for _, stop in {
			function() modules.Movement.SetFly(false); modules.Movement.SetSpeed(false); modules.Movement.SetInfinityJump(false); modules.Movement.SetNoClip(false); modules.Movement.SetNoFling(false) end,
			function() modules.Aim.SetEnabled(false) end, function() modules.ESP.SetEnabled(false) end,
			function() modules.Hitbox.SetEnabled(false) end, function() modules.Misc.SetFullbright(false); modules.Misc.SetAntiAFK(false) end,
		} do if not pcall(stop) then success = false end end
		if modules.Trolling and not pcall(modules.Trolling.Stop) then success = false end
		if modules.Players and not pcall(modules.Players.Stop) then success = false end
		notice(success, success and "All features stopped; settings kept" or "Some cleanup failed; close the panel")
		return success
	end
	function self:ApplyProfile(text)
		if self.Destroyed then return false, "Control center is closed" end
		local data, err = self.Settings:Decode(text); if not data then return false, err end
		local ok, reason = self.Keys:Validate(data.Keybinds); if not ok then return false, reason end
		self.Keys:Release()
		ok, reason = self.Settings:Apply(data.Settings)
		if not ok then return false, reason end
		return self.Keys:Apply(data.Keybinds)
	end
	function self:ExportProfile() return self.Settings:Encode(self.Keys:Snapshot()) end
	function self:Reset()
		self.Keys:Release()
		local ok, reason = self.Settings:Apply(self.Settings:Defaults())
		if not ok then return false, reason end
		return self.Keys:Apply(self.Keys:Snapshot(true))
	end
	function self:CapabilitiesSnapshot()
		local capabilities = {}
		for name, available in {
			Drawing = type(Drawing) == "table" and type(Drawing.new) == "function",
			Clipboard = type(setclipboard) == "function", ReadFile = type(readfile) == "function",
			WriteFile = type(writefile) == "function", MakeFolder = type(makefolder) == "function",
			MouseOutput = type(mousemoverel) == "function",
		} do capabilities[name] = self.Capabilities[name] or (available and "Present; untested" or "Unavailable") end
		return capabilities
	end
	function self:ProbeDrawing()
		if self.Destroyed then return false end
		local object
		local ok = pcall(function() object = runtime.Adapters.CreateDrawing("Square"); object.Visible = false; object:Remove(); object = nil end)
		if object then pcall(function() object:Remove() end) end
		self.Capabilities.Drawing = ok and "Square create/remove succeeded" or "Square probe failed"
		return ok
	end
	function self:Copy(text)
		local ok, result = false, nil
		if type(setclipboard) == "function" then ok, result = pcall(setclipboard, text) end
		ok = ok and result ~= false
		self.Capabilities.Clipboard = ok and "Last copy succeeded" or "Copy unavailable/failed"
		return ok
	end
	function self:Report()
		local data = app:GetDiagnostics()
		data.Capabilities = self:CapabilitiesSnapshot()
		data.Performance = { Name = self.Performance, Budget = table.clone(budgets[self.Performance]) }
		data.RecentErrors = table.clone(self.Errors)
		data.ActiveFeatures = {}
		for id, read in activeReads do data.ActiveFeatures[id] = read() end
		data.FrameSample = self.FrameSample or { Status = "Not sampled" }
		data.Notes = "Task times are seconds; feature counters are cumulative. No account, script source or network bodies included."
		return codec:JSONEncode(data)
	end
	function self:SampleFrames()
		if self.Destroyed or self.Sampling then return false end
		self.Sampling = true
		local frames, elapsed, total = {}, 0, 0
		scope:Add(runtime.Input:Connect("WindowFocusReleased", function() self.SampleLostFocus = true end), "sampleFocus")
		self.SampleLostFocus = false
		local function finish(status)
			if not self.Sampling then return end
			self.Sampling = false; self.CancelSample = nil
			scope:Remove("sample"); scope:Remove("sampleFocus"); scope:Remove("sampleTimeout")
			table.sort(frames)
			self.FrameSample = { Status = status, Frames = #frames, Seconds = total, LostFocus = self.SampleLostFocus,
				MeanMs = #frames > 0 and total * 1000 / #frames or 0,
				P95Ms = #frames > 0 and frames[math.ceil(#frames * 0.95)] * 1000 or 0,
				P99Ms = #frames > 0 and frames[math.ceil(#frames * 0.99)] * 1000 or 0 }
			if self.RefreshDiagnostics then self.RefreshDiagnostics() end
		end
		self.CancelSample = function() finish("Cancelled") end
		scope:Add(game:GetService("RunService").RenderStepped:Connect(function(dt)
			if dt <= 0 or dt ~= dt or dt == math.huge then return end
			table.insert(frames, dt); elapsed += dt; total += dt
			if elapsed >= 10 or #frames >= 10000 then finish(elapsed >= 10 and "Complete" or "Sample cap reached") end
		end), "sample")
		scope:Add(task.delay(15, function() finish("Timed out; partial sample") end), "sampleTimeout")
		return true
	end
	function self:Mount()
		local profile = window:CreateTab("Profiles", "save", { Description = "Save a setup for this place, or bring one in from another session." })
		local saved = profile:CreateSection("Saved profiles")
		local name = saved:CreateInput("Profile Name", "letters, digits, _ or -")
		name:Set("default")
		local storageActions = saved:CreateActionGroup({ Columns = 2, MinWidth = 150 })
		local exchange = profile:CreateSection("Import & export")
		exchange:CreateLabel("Import applies the saved feature states.", { Wrap = true })
		local box = exchange:CreateInput("Profile JSON", "Export here or paste a profile", nil, { Multiline = true })
		local jsonActions = exchange:CreateActionGroup({ Columns = 3, MinWidth = 110 })
		jsonActions:CreateButton("Export JSON", function() local text, err = self:ExportProfile(); if text then box:Set(text) else fail(err) end end)
		jsonActions:CreateButton("Copy JSON", function() local text, err = self:ExportProfile(); if text then box:Set(text); notice(self:Copy(text), "JSON is also available in the text box") else fail(err) end end)
		jsonActions:CreateButton("Import JSON", function() local ok, err = self:ApplyProfile(box:Get()); notice(ok, ok and "Profile applied" or err) end)
		storageActions:CreateButton("Save Named Profile", function()
			local text, err = self:ExportProfile(); if not text then fail(err); return end
			box:Set(text)
			local ok, reason = self.Settings:Save(name:Get(), text)
			self.Capabilities.WriteFile = ok and "Last save succeeded" or "Last save failed"
			notice(ok, reason)
		end)
		storageActions:CreateButton("Load Named Profile", function()
			local text, err = self.Settings:Read(name:Get())
			self.Capabilities.ReadFile = text and "Last read succeeded" or "Last read failed"
			if not text then fail(err); return end
			box:Set(text); local ok, reason = self:ApplyProfile(text); notice(ok, ok and "Profile loaded" or reason)
		end)
		profile:CreateButton("Restore Defaults", function() local ok, err = self:Reset(); notice(ok, ok and "Defaults restored" or err) end, { Variant = "Danger", Icon = "rotate-ccw" })
		local keys = window:CreateTab("Keybinds", "keyboard", { Description = "Make it yours. Select a key to rebind; Escape cancels capture." })
		local widgets = {}
		for _, id in self.Keys.Order do
			local entry = self.Keys.Entries[id]
			local picker, mode
			local keySection = keys:CreateSection(entry.Label)
			local function changed(key, selectedMode)
				local ok, err = self.Keys:Change(id, key, selectedMode)
				if not ok then self.RefreshKeys(); fail(err) end
			end
			picker = keySection:CreateKeybind(entry.Label, entry.Key == "None" and Enum.KeyCode.Unknown or Enum.KeyCode[entry.Key], nil, {
				OnListeningChanged = function(listening)
					if listening then self.Keys:Release() end
					modules.Aim.SetInputSuspended(listening)
				end,
				OnChanged = function(key) changed(key.Name, entry.Mode) end,
			})
			if entry.Set then mode = keySection:CreateDropdown(entry.Label .. " Mode", { "Toggle", "Hold" }, entry.Mode, function(value) changed(entry.Key, value) end) end
			keySection:CreateButton("Unbind " .. entry.Label, function() changed("None", entry.Mode) end, { Variant = "Ghost" })
			widgets[id] = { Key = picker, Mode = mode }
		end
		self.RefreshKeys = function()
			for id, pair in widgets do
				local entry = self.Keys.Entries[id]
				pair.Key:Set(entry.Key == "None" and Enum.KeyCode.Unknown or Enum.KeyCode[entry.Key], true)
				if pair.Mode then pair.Mode:Set(entry.Mode, true) end
			end
			local key = self.Keys.Entries.window.Key
			if key ~= "None" then window:SetToggleKey(Enum.KeyCode[key]) end
		end
		local performance = window:CreateTab("Performance", "activity", { Description = "Balance visual detail and update frequency for your device." })
		local budgetSection = performance:CreateSection("Update budget")
		self.PerformanceWidget = budgetSection:CreateDropdown("Performance Preset", { "Low", "Balanced", "High" }, self.Performance, function(value) self:SetPerformance(value) end)
		self.Controls.performance = { Label = "Performance Preset", Tab = performance, Widget = self.PerformanceWidget, Spec = self.Settings.Entries.performance }
		table.insert(self.Order, "performance")
		budgetSection:CreateLabel("Low: 20 updates/s, nearest 20 players, 500 studs; scan 4/s", { Wrap = true })
		budgetSection:CreateLabel("Balanced: 30 updates/s, nearest 50 players, 1500 studs; scan 10/s", { Wrap = true })
		budgetSection:CreateLabel("High: every frame, no extra visual cap; scan 10/s", { Wrap = true })
		budgetSection:CreateLabel("User ESP range still applies. Presets do not enable features.", { Wrap = true })
		local diagnostics = window:CreateTab("Diagnostics", "activity", { Description = "Inspect this session, check capabilities and measure frame times." })
		local session = diagnostics:CreateSection("Session overview")
		local overview = session:CreateLabel("Refresh to inspect this session")
		local capabilityLabels = {}
		for _, name in { "Drawing", "Clipboard", "ReadFile", "WriteFile", "MakeFolder", "MouseOutput" } do
			capabilityLabels[name] = session:CreateLabel(name .. ": not checked", { Wrap = true })
		end
		local report = diagnostics:CreateSection("Session report")
		local reportBox = report:CreateInput("Report", "Refresh to inspect this session", nil, { Multiline = true })
		self.RefreshDiagnostics = function()
			if self.Destroyed then return end
			local failures, active = 0, 0
			for _, stats in runtime.Scheduler.stats do failures += stats.Failures end
			if modules.Aim.GetMetrics then failures += modules.Aim.GetMetrics().Failures or 0 end
			for _, group in runtime.Scheduler.phases do active += #group.jobs end
			overview:SetText("Active tasks: " .. active .. " | Task failures: " .. failures .. " | Preset: " .. self.Performance)
			for name, value in self:CapabilitiesSnapshot() do capabilityLabels[name]:SetText(name .. ": " .. value) end
			local ok, text = pcall(function() return self:Report() end)
			if ok then reportBox:Set(text) else fail("Could not encode diagnostics") end
		end
		report:CreateLabel("Present does not mean tested. Reports contain no account IDs or script source.", { Wrap = true })
		local reportActions = report:CreateActionGroup({ Columns = 2, MinWidth = 130 })
		reportActions:CreateButton("Refresh Report", self.RefreshDiagnostics, { Icon = "refresh-cw" })
		reportActions:CreateButton("Copy Report", function() self.RefreshDiagnostics(); notice(self:Copy(reportBox:Get()), "Report is also available in the text box") end)
		local probes = diagnostics:CreateActionGroup({ Cards = true, MinWidth = 240 })
		probes:CreateButton("Test Invisible Drawing", function() local ok = self:ProbeDrawing(); self.RefreshDiagnostics(); notice(ok, self.Capabilities.Drawing) end, { Icon = "pen-tool", Description = "Check whether drawing is available in this session." })
		probes:CreateButton("Sample Frame Times (10 seconds)", function() notice(self:SampleFrames(), "Keep this window focused and the scene unchanged during the sample") end, { Icon = "activity", Description = "Measure ten seconds with the scene unchanged." })
		local quick = window:CreateTab("Quick Actions", "search", { Order = -10, Description = "What would you like to do? Jump to a setting or manage your session." })
		self.QuickTab = quick
		local destinations = quick:CreateActionGroup({ Cards = true })
		destinations:CreateButton("Open Profiles", function() window:SelectTab(profile) end, { Icon = "save", Description = "Keep your favorite setup ready for next time." })
		destinations:CreateButton("Open Diagnostics", function() window:SelectTab(diagnostics); self.RefreshDiagnostics() end, { Icon = "activity", Description = "Check your session and measure performance." })
		local finder = quick:CreateSection("Find a setting")
		local choices, lookup, selected = {}, {}, nil
		for _, id in self.Order do local label = self.Controls[id].Label .. " [" .. id .. "]"; table.insert(choices, label); lookup[label] = id end
		local results
		finder:CreateInput("Find Setting", "Search by name, then leave this field", function(query)
			local filtered = {}; query = query:lower()
			for _, label in choices do if label:lower():find(query, 1, true) then table.insert(filtered, label) end end
			results:SetOptions(filtered); selected = filtered[1]; results:Set(selected or "No matches", true)
		end)
		selected = choices[1]
		results = finder:CreateDropdown("Results", choices, selected, function(value) selected = value end)
		local selectionActions = finder:CreateActionGroup({ Columns = 2, MinWidth = 180 })
		selectionActions:CreateButton("Open Selected Setting", function() local item = self.Controls[lookup[selected]]; if item then window:SelectTab(item.Tab) end end, { Variant = "Primary", Icon = "arrow-up-right" })
		selectionActions:CreateButton("Toggle Selected Setting", function()
			local id = lookup[selected]; local item = id and self.Controls[id]
			if not item or item.Spec.Kind ~= "boolean" then notice(false, "Choose a toggle or open its settings page"); return end
			local ok, reason = self.Settings:Apply({ [id] = not item.Spec.Get() }); if not ok then fail(reason) end
		end)
		quick:CreateButton("Stop All Features", function() self:StopAll() end, { Variant = "Danger", Icon = "square" })
		window:SelectTab(quick)
	end
	function self:Destroy()
		if self.Destroyed then return end
		self.Keys:Destroy(); self.Destroyed = true; scope:Destroy(); self.Settings:Destroy()
		self.RefreshKeys, self.RefreshDiagnostics, self.CancelSample = nil, nil, nil
		self.Sampling = false
	end
	return self
end
return ControlCenter
