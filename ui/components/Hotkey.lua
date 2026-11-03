local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new
return function(ctx, toggle, config)
	local connections = CreateConnectionTracker(toggle.Scope)
	local frame, topArea = toggle.Root, toggle.Header
	local Theme, UserInputService = ctx.Theme, ctx.Input.Service
	local ConnectInput = ctx.Input.Connect
	local Tween, ApplyCorner, ApplyStroke = ctx.Primitives.Tween, ctx.Primitives.ApplyCorner, ctx.Primitives.ApplyStroke
	-- KEYBIND (ถ้ามี)
	connections:Track(function() if ctx.Capture.Owner == frame then ctx.Capture.Owner = nil end end)
	local currentKey = config.Default
	if config then
		local keyBtn = Instance.new("TextButton")
		keyBtn.Size = UDim2.new(0, 32, 0, 20)
		keyBtn.Position = UDim2.new(1, -90, 0.5, -10)
		keyBtn.BackgroundColor3 = Theme.Background
		keyBtn.Text = currentKey and "[" .. currentKey.Name .. "]" or "[None]"
		keyBtn.TextColor3 = Theme.SubText
		keyBtn.Font = Tokens.Font.Strong
		keyBtn.TextSize = Tokens.Text.Caption
		keyBtn.ZIndex = 2
		keyBtn.Parent = topArea
		ApplyCorner(keyBtn, 4)
		ApplyStroke(keyBtn, Theme.Outline)

		local listening = false
		connections:Track(keyBtn.MouseButton1Click:Connect(function()
			if ctx.Capture.Owner then return end
			ctx.Capture.Owner = frame
			listening = true
			keyBtn.Text = "..."
			Tween(keyBtn, 0.2, { BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Background })
		end))

		connections:Track(ConnectInput("InputBegan", function(input, gp)
			if listening and input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				connections:Spawn(function() if ctx.Capture.Owner == frame then ctx.Capture.Owner = nil end end)
				currentKey = input.KeyCode
				keyBtn.Text = "[" .. currentKey.Name .. "]"
				Tween(keyBtn, 0.2, { BackgroundColor3 = Theme.Background, TextColor3 = Theme.SubText })
				if config.Callback then connections:Invoke(config.Callback, currentKey) end
			elseif not listening and not ctx.Capture.Owner and not UserInputService:GetFocusedTextBox() and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey and not gp then
				-- Auto toggle on hotkey!
				toggle:Set(not toggle:Get())
			end
		end))
	end
end
