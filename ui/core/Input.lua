return function(Runtime)
	local UserInputService = game:GetService("UserInputService")
	local function ConnectInput(name, callback)
		return Runtime and Runtime.Input:Connect(name, callback) or UserInputService[name]:Connect(callback)
	end

	local function MakeDraggable(dragPart, mainFrame, tracker, canDrag, applyPosition)
		local dragging = false
		local dragStart, startPos, pointer

		tracker:Track(dragPart.InputBegan:Connect(function(input)
			if canDrag and not canDrag() then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if dragging then return end
				dragging = true; pointer = input
				dragStart = input.Position
				startPos = mainFrame.Position
			end
		end))

		tracker:Track(ConnectInput("InputEnded", function(input)
			if input == pointer or (pointer and pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
				dragging = false
			end
		end))

		tracker:Track(ConnectInput("InputChanged", function(input)
			if canDrag and not canDrag() then dragging = false; return end
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				if pointer.UserInputType == Enum.UserInputType.Touch and input ~= pointer then return end
				if pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
				local delta = input.Position - dragStart
				local position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
				if applyPosition then applyPosition(position) else mainFrame.Position = position end
			end
		end))
		return function() dragging = false end
	end
	local function CreateDrag(connections)
		local activeDrag
		connections:Track(ConnectInput("InputChanged", function(input)
			if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				activeDrag.update(input)
			end
		end))
		connections:Track(ConnectInput("InputEnded", function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then activeDrag = nil end
		end))
		local function BindSliderDrag(hitArea, tracker, update)
			local drag = { update = update }
			tracker:Track(hitArea.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					activeDrag = drag; update(input)
				end
			end))
			tracker:Track(function() if activeDrag == drag then activeDrag = nil end end)
		end

		return BindSliderDrag
	end
	return { Connect = ConnectInput, MakeDraggable = MakeDraggable, CreateDrag = CreateDrag, Service = UserInputService }
end
