local import = ...
local Tokens = import("core/Tokens")
local CreateConnectionTracker = import("core/Lifecycle").new

return function(ctx, text, default, callback, options)
	local Theme = ctx.Theme
	local ConnectInput = ctx.Input.Connect
	local UserInputService = ctx.Input.Service
	local Tween = ctx.Primitives.Tween
	local ApplyCorner = ctx.Primitives.ApplyCorner
	local ApplyStroke = ctx.Primitives.ApplyStroke
	local ApplySectionStyle = ctx.Primitives.ApplySectionStyle
	local connections = CreateConnectionTracker(ctx.Scope)
	options = options or {}
	local obj = {}
	local currentKey = default or Enum.KeyCode.Unknown
	local listening = false
	local targetParent = ctx.Parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = Theme.ElementBg
	frame.Parent = targetParent

	ApplySectionStyle(frame, ctx.Section)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -95, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Theme.Text
	lbl.Font = Tokens.Font.Label
	lbl.TextSize = Tokens.Text.Body
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = frame

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(0, 75, 0, 24)
	keyBtn.Position = UDim2.new(1, -85, 0.5, -12)
	keyBtn.BackgroundColor3 = Theme.InputBg
	keyBtn.Text = currentKey.Name
	keyBtn.TextColor3 = Theme.Accent
	keyBtn.Font = Tokens.Font.Strong
	keyBtn.TextSize = Tokens.Text.Small
	keyBtn.AutoButtonColor = false
	keyBtn.Parent = frame
	ApplyCorner(keyBtn, 6)
	local kbStroke = ApplyStroke(keyBtn, Theme.Outline)

	connections:Track(keyBtn.MouseButton1Click:Connect(function()
		if listening or ctx.Capture.Owner then return end
		ctx.Capture.Owner = frame
		listening = true
		if options.OnListeningChanged then options.OnListeningChanged(true) end
		keyBtn.Text = "..."
		Tween(kbStroke, 0.2, { Color = Theme.Accent })
	end))

	connections:Track(ConnectInput("InputBegan", function(input, gameProcessed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
				if input.KeyCode == Enum.KeyCode.Escape then
					-- ยกเลิก
					keyBtn.Text = currentKey.Name
				else
					currentKey = input.KeyCode
					keyBtn.Text = currentKey.Name
					if options.OnChanged then options.OnChanged(currentKey) end
				end
				listening = false
				connections:Spawn(function()
					if ctx.Capture.Owner == frame then ctx.Capture.Owner = nil end
					if options.OnListeningChanged then options.OnListeningChanged(false) end
				end)
				Tween(kbStroke, 0.2, { Color = Theme.Outline })
			end
		else
			-- กดปุ่มลัดที่ตั้งไว้ → เรียก callback
			if not gameProcessed and not ctx.Capture.Owner and not UserInputService:GetFocusedTextBox()
				and input.UserInputType == Enum.UserInputType.Keyboard
				and input.KeyCode == currentKey then
				if callback then connections:Invoke(callback, currentKey) end
			end
		end
	end))

	function obj:Set(key, silent)
		currentKey = key
		keyBtn.Text = key.Name
		if options.OnChanged and not silent then options.OnChanged(key) end
	end
	function obj:Reset() obj:Set(default or Enum.KeyCode.Unknown) end
	function obj:Get() return currentKey end
	function obj:SetText(t) lbl.Text = t end
	function obj:SetVisible(v) frame.Visible = v end
	function obj:Destroy()
		if listening and options.OnListeningChanged then options.OnListeningChanged(false) end
		listening = false
		if ctx.Capture.Owner == frame then ctx.Capture.Owner = nil end
		frame:Destroy()
	end
	ctx.Register(obj, connections, true)
	return obj
end
