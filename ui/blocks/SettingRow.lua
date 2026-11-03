local import = ...
local Toggle = import("components/Toggle")
local Slider = import("components/Slider")
local Hotkey = import("components/Hotkey")

return function(ctx, text, default, callback, config)
	config = config or {}
	local toggle = Toggle(ctx, text, default, callback, config)
	if config.Keybind then Hotkey(ctx, toggle, config.Keybind) end
	if config.Slider then
		local spec = config.Slider
		local child = table.clone(ctx)
		child.Parent, child.Scope, child.Section = toggle.Root, toggle.Scope, nil
		local slider = Slider(child, spec.Text or "Speed", spec.Min or 0, spec.Max or 100, spec.Default,
			spec.Callback, { Compact = true, LabelOffset = toggle.LabelOffset })
		slider.Root.Position = UDim2.fromOffset(0, 36)
		toggle.Root.Size = UDim2.new(1, 0, 0, 82)
		function toggle:GetSlider() return slider:Get() end
		function toggle:SetSlider(value, silent) slider:Set(value, silent) end
	end
	return toggle
end
