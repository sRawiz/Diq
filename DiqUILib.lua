-- ==========================================
-- 🎨 Module: Diq UI Library
-- ==========================================

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Diq = {}

local Theme = {
    Background = Color3.fromRGB(24, 24, 27),
    ElementBg = Color3.fromRGB(39, 39, 42),
    HoverBg = Color3.fromRGB(63, 63, 70),
    Accent = Color3.fromRGB(99, 102, 241),
    Text = Color3.fromRGB(250, 250, 250),
    SubText = Color3.fromRGB(161, 161, 170),
    Outline = Color3.fromRGB(63, 63, 70),
}

local function MakeDraggable(dragPart, mainFrame)
    local dragging, dragInput, dragStart, startPos
    dragPart.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragPart.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function Diq:CreateWindow(titleText)
    local Window = {}
    
    for _, v in pairs(Players.LocalPlayer.PlayerGui:GetChildren()) do
        if v.Name == "Diq_UI" then v:Destroy() end
    end
    pcall(function()
        for _, v in pairs(CoreGui:GetChildren()) do
            if v.Name == "Diq_UI" then v:Destroy() end
        end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Diq_UI"
    ScreenGui.ResetOnSpawn = false
    if not pcall(function() ScreenGui.Parent = CoreGui end) then
        ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 380, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -190, 0.5, -210)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
    local UIStroke = Instance.new("UIStroke", MainFrame)
    UIStroke.Color = Theme.Outline
    UIStroke.Thickness = 1

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 45)
    TopBar.BackgroundTransparency = 1
    TopBar.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -30, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = titleText or "Diq Panel"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    MakeDraggable(TopBar, MainFrame)

    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(1, 0, 0, 1)
    Divider.Position = UDim2.new(0, 0, 1, 0)
    Divider.BackgroundColor3 = Theme.Outline
    Divider.BorderSizePixel = 0
    Divider.Parent = TopBar

    local Container = Instance.new("ScrollingFrame")
    Container.Size = UDim2.new(1, -20, 1, -60)
    Container.Position = UDim2.new(0, 10, 0, 55)
    Container.BackgroundTransparency = 1
    Container.ScrollBarThickness = 3
    Container.ScrollBarImageColor3 = Theme.Outline
    Container.BorderSizePixel = 0
    Container.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 10)
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = Container

    local UIPadding = Instance.new("UIPadding")
    UIPadding.PaddingTop = UDim.new(0, 5)
    UIPadding.PaddingBottom = UDim.new(0, 5)
    UIPadding.Parent = Container

    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Container.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 15)
    end)

    function Window:CreateLabel(text)
        local LabelFrame = Instance.new("Frame")
        LabelFrame.Size = UDim2.new(1, -10, 0, 20)
        LabelFrame.BackgroundTransparency = 1
        LabelFrame.Parent = Container

        local LabelText = Instance.new("TextLabel")
        LabelText.Size = UDim2.new(1, 0, 1, 0)
        LabelText.BackgroundTransparency = 1
        LabelText.Text = text
        LabelText.TextColor3 = Theme.SubText
        LabelText.Font = Enum.Font.Gotham
        LabelText.TextSize = 13
        LabelText.TextXAlignment = Enum.TextXAlignment.Left
        LabelText.Parent = LabelFrame
    end

    function Window:CreateButton(text, callback)
        local ButtonFrame = Instance.new("Frame")
        ButtonFrame.Size = UDim2.new(1, -10, 0, 42)
        ButtonFrame.BackgroundColor3 = Theme.ElementBg
        ButtonFrame.Parent = Container
        Instance.new("UICorner", ButtonFrame).CornerRadius = UDim.new(0, 6)
        
        local ButtonStroke = Instance.new("UIStroke", ButtonFrame)
        ButtonStroke.Color = Theme.Outline
        ButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.Text = text
        Btn.TextColor3 = Theme.Text
        Btn.Font = Enum.Font.GothamMedium
        Btn.TextSize = 14
        Btn.Parent = ButtonFrame

        Btn.MouseEnter:Connect(function()
            TweenService:Create(ButtonFrame, TweenInfo.new(0.2), {BackgroundColor3 = Theme.HoverBg}):Play()
            TweenService:Create(ButtonStroke, TweenInfo.new(0.2), {Color = Theme.Accent}):Play()
        end)
        
        Btn.MouseLeave:Connect(function()
            TweenService:Create(ButtonFrame, TweenInfo.new(0.2), {BackgroundColor3 = Theme.ElementBg}):Play()
            TweenService:Create(ButtonStroke, TweenInfo.new(0.2), {Color = Theme.Outline}):Play()
        end)

        Btn.MouseButton1Click:Connect(function()
            local tw = TweenService:Create(ButtonFrame, TweenInfo.new(0.1), {Size = UDim2.new(0.95, -10, 0, 38)})
            tw:Play()
            tw.Completed:Wait()
            TweenService:Create(ButtonFrame, TweenInfo.new(0.1), {Size = UDim2.new(1, -10, 0, 42)}):Play()
            if callback then callback() end
        end)
    end

    function Window:CreateToggle(text, default, callback)
        local toggled = default or false

        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Size = UDim2.new(1, -10, 0, 42)
        ToggleFrame.BackgroundColor3 = Theme.ElementBg
        ToggleFrame.Parent = Container
        Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", ToggleFrame).Color = Theme.Outline

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -70, 1, 0)
        Label.Position = UDim2.new(0, 15, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = text
        Label.TextColor3 = Theme.Text
        Label.Font = Enum.Font.GothamMedium
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = ToggleFrame

        local SwitchBg = Instance.new("Frame")
        SwitchBg.Size = UDim2.new(0, 42, 0, 22)
        SwitchBg.Position = UDim2.new(1, -55, 0.5, -11)
        SwitchBg.BackgroundColor3 = toggled and Theme.Accent or Theme.Background
        SwitchBg.Parent = ToggleFrame
        Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

        local SwitchKnob = Instance.new("Frame")
        SwitchKnob.Size = UDim2.new(0, 16, 0, 16)
        SwitchKnob.Position = UDim2.new(0, toggled and 23 or 3, 0.5, -8)
        SwitchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SwitchKnob.Parent = SwitchBg
        Instance.new("UICorner", SwitchKnob).CornerRadius = UDim.new(1, 0)

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.Text = ""
        Btn.Parent = ToggleFrame

        Btn.MouseButton1Click:Connect(function()
            toggled = not toggled
            TweenService:Create(SwitchBg, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = toggled and Theme.Accent or Theme.Background}):Play()
            TweenService:Create(SwitchKnob, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.new(0, toggled and 23 or 3, 0.5, -8)}):Play()
            if callback then callback(toggled) end
        end)
    end

    return Window
end

return Diq
