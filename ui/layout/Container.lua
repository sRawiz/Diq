local import = ...
local constructors = {
	CreateLabel = import("components/Label"),
	CreateProfileCard = import("blocks/ProfileCard"),
	CreateSection = import("layout/Section"),
	CreateButton = import("components/Button"),
	CreateToggle = import("blocks/SettingRow"),
	CreateSlider = import("components/Slider"),
	CreateDropdown = import("components/Dropdown"),
	CreateInput = import("components/Input"),
	CreateKeybind = import("components/Keybind"),
}

local function bind(container, base)
	for name, constructor in constructors do
		container[name] = function(self, ...)
			assert(self._tracker.Alive, "Cannot add controls to a destroyed container")
			local ctx = table.clone(base)
			ctx.Parent, ctx.Scope, ctx.Section = self._content, self._tracker, self
			ctx.BindContainer = function(section) bind(section, base) end
			return constructor(ctx, ...)
		end
	end
	return container
end
return bind
