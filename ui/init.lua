-- Public compatibility facade. All imports resolve inside the generated file.
local import = ...
local CreateTheme = import("core/Theme")
local Lifecycle = import("core/Lifecycle")
local CreatePrimitives = import("core/Primitives")
local CreateInput = import("core/Input")
local CreateNotifications = import("overlays/Notification")
local CreateWindow = import("layout/Window")

return function(options)
	local runtime = type(options) == "table" and options.Runtime
	local ui = {}
	local theme, setTheme = CreateTheme()
	local icons, window, scope
	local function getIcons() return icons end
	local primitives = CreatePrimitives(theme, getIcons)
	local input = CreateInput(runtime)
	local notifications = CreateNotifications(theme, primitives)
	function ui:SetTheme(values) setTheme(values) end
	function ui:LoadIcons(value) icons = value end
	function ui:Notify(...)
		if not self.SuppressNotifications then notifications:Notify(...) end
	end
	function ui:Destroy()
		if window then window:Destroy(); window = nil end
		if scope then scope:DisconnectAll(); scope = nil end
		notifications:Destroy()
	end
	function ui:CreateWindow(config)
		self:Destroy()
		scope = Lifecycle.new()
		local ok, result = pcall(CreateWindow, {
			UI = self, Theme = theme, Scope = scope, Primitives = primitives,
			Input = input, Notifications = notifications, GetIcons = getIcons,
		}, config)
		if not ok then self:Destroy(); error(result, 0) end
		window = result
		return window
	end
	return ui
end
