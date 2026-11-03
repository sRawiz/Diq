return function(Runtime)
	local UserInputService = game:GetService("UserInputService")
	local function ConnectInput(name, callback)
		return Runtime and Runtime.Input:Connect(name, callback) or UserInputService[name]:Connect(callback)
	end

	local function MakeDraggable(dragPart, mainFrame, tracker)
		local dragging = false
		local dragStart, startPos

		tracker:Track(dragPart.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = mainFrame.Position
			end
		end))

		tracker:Track(dragPart.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))

		tracker:Track(ConnectInput("InputChanged", function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				mainFrame.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end))
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
