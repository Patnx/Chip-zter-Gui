-- Integrated Chip'zter GUI with Car Controls
-- Combines Main GUI and Car Controls into a single, themed interface

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- CONFIG
local REQUIRED_KEY = "Chipz"
local IMAGE_ID = "rbxassetid://136330164453116"
local DISCORD_LINK = "https://discord.gg/UwcKe2MXca"
local HARD_MAX_SPEED = 900
local QE_ADJUST_RATE = 0.4

-- THEMES
local Themes = {
    {Name="Pink", Accent=Color3.fromRGB(255,105,180)},
    {Name="Purple", Accent=Color3.fromRGB(170,85,255)},
    {Name="Blue", Accent=Color3.fromRGB(80,170,255)},
    {Name="Cyan", Accent=Color3.fromRGB(80,255,255)},
    {Name="Green", Accent=Color3.fromRGB(80,255,120)},
    {Name="Yellow", Accent=Color3.fromRGB(255,220,80)},
    {Name="Orange", Accent=Color3.fromRGB(255,150,80)},
    {Name="Red", Accent=Color3.fromRGB(255,80,80)},
    {Name="White", Accent=Color3.fromRGB(235,235,235)},
    {Name="Dark", Accent=Color3.fromRGB(120,120,120)}
}

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
end)

local isCarEnabled = false
local shuttingDown = false

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ChipzterGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Main Frame
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(320, 200)
main.Position = UDim2.fromScale(0.05, 0.1)
main.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
main.BackgroundTransparency = 0.5
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Themes[1].Accent
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = main

-- Background Image
local bg = Instance.new("ImageLabel")
bg.Size = UDim2.fromScale(1, 1)
bg.Image = IMAGE_ID
bg.ImageTransparency = 0.5
bg.BackgroundTransparency = 1
bg.ScaleType = Enum.ScaleType.Crop
bg.Parent = main

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
topBar.Parent = main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 16)

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0)
title.Position = UDim2.fromOffset(15, 0)
title.BackgroundTransparency = 1
title.Text = "Chip'zter"
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = topBar

-- Close Button
local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -35, 0.5, -15)
close.Text = "X"
close.TextScaled = true
close.BackgroundTransparency = 1
close.TextColor3 = stroke.Color
close.Parent = topBar
close.MouseButton1Click:Connect(function()
    if shuttingDown then
        return
    end

    shuttingDown = true
    isCarEnabled = false

    pcall(function()
        gui:Destroy()
    end)

    pcall(function()
        script:Destroy()
    end)
end)

-- Draggable
local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        dragging = false 
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and startPos and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Key input
local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(1, -60, 0, 40)
keyBox.Position = UDim2.fromOffset(30, 70)
keyBox.PlaceholderText = "Input key here"
keyBox.TextScaled = true
keyBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
keyBox.TextColor3 = Color3.new(1, 1, 1)
keyBox.Parent = main
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 12)

local status = Instance.new("TextButton")
status.Size = UDim2.new(1, -60, 0, 30)
status.Position = UDim2.fromOffset(30, 120)
status.BackgroundTransparency = 1
status.TextScaled = true
status.TextColor3 = Color3.new(1, 1, 1)
status.Text = "Discord (Key here)"
status.Parent = main

-- Content Frame (initially hidden)
local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(0, 50)
content.Size = UDim2.new(1, 0, 1, -50)
content.BackgroundTransparency = 1
content.Visible = false
content.Parent = main

-- Layout for buttons
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 15)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = content

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 30)
pad.Parent = content

-- Function to create styled buttons
local function makeButton(text)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.85, 0, 0, 50)
    button.Text = text
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Parent = content
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
    return button
end

-- Car Controls Frame (initially hidden)
local carControls = Instance.new("Frame")
carControls.Size = UDim2.new(1, -40, 0, 280)
carControls.Position = UDim2.fromOffset(20, 60)
carControls.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
carControls.BackgroundTransparency = 0.7
carControls.Visible = false
carControls.Parent = content
Instance.new("UICorner", carControls).CornerRadius = UDim.new(0, 12)

-- Car Controls Title
local carTitle = Instance.new("TextLabel")
carTitle.Size = UDim2.new(1, 0, 0, 30)
carTitle.Position = UDim2.fromOffset(0, 10)
carTitle.BackgroundTransparency = 1
carTitle.Text = "Speed Modifier"
carTitle.TextColor3 = Color3.new(1, 1, 1)
carTitle.Font = Enum.Font.GothamBold
carTitle.TextSize = 18
carTitle.Parent = carControls

-- Toggle Button for Car Controls
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.8, 0, 0, 40)
toggleButton.Position = UDim2.new(0.1, 0, 0.12, 0)
toggleButton.Text = "Power: OFF"
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.GothamBold
toggleButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Parent = carControls
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 12)

-- Speed Slider
local speedSlider = Instance.new("Frame")
speedSlider.Size = UDim2.new(0.8, 0, 0, 40)
speedSlider.Position = UDim2.new(0.1, 0, 0.35, 0)
speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
speedSlider.Parent = carControls
Instance.new("UICorner", speedSlider).CornerRadius = UDim.new(0, 8)

local sliderBar = Instance.new("Frame")
sliderBar.Size = UDim2.new(1, -20, 0, 8)
sliderBar.Position = UDim2.new(0, 10, 0.5, -4)
sliderBar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
sliderBar.Parent = speedSlider
Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
sliderFill.BackgroundColor3 = Themes[1].Accent
sliderFill.Parent = sliderBar
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.new(0, 16, 2, 16)
sliderButton.Position = UDim2.new(0.5, -8, 0.5, -8)
sliderButton.Text = ""
sliderButton.BackgroundColor3 = Color3.new(1, 1, 1)
sliderButton.Parent = sliderBar
Instance.new("UICorner", sliderButton).CornerRadius = UDim.new(0.5, 0)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 20)
speedLabel.Position = UDim2.new(0, 0, -0.5, -5)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Top Speed: 100%"
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 12
speedLabel.Parent = speedSlider

-- Car Control Instructions
local instructions = Instance.new("TextLabel")
instructions.Size = UDim2.new(0.9, 0, 0, 80)
instructions.Position = UDim2.new(0.05, 0, 0.6, 0)
instructions.BackgroundTransparency = 1
instructions.Text = "WASD - Drive\nQ/E - Adjust Top Speed\nX - Emergency Stop"
instructions.TextColor3 = Color3.new(1, 1, 1)
instructions.Font = Enum.Font.Gotham
instructions.TextSize = 14
instructions.TextYAlignment = Enum.TextYAlignment.Top
instructions.TextXAlignment = Enum.TextXAlignment.Left
instructions.Parent = carControls

local speedLimitPercent = 1
local qeInput = {Q=false, E=false}
local driveInput = {W=false, A=false, S=false, D=false, X=false}
local carSpeed = 0
local accel = 250
local reverseMax = 400

local function syncSpeedUi()
    sliderFill.Size = UDim2.new(speedLimitPercent, 0, 1, 0)
    sliderButton.Position = UDim2.new(speedLimitPercent, -8, 0.5, -8)
    speedLabel.Text = "Top Speed: "..math.floor(speedLimitPercent*100).."%"
end
syncSpeedUi()

-- Slider dragging
local draggingSlider = false
sliderButton.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = true
    end
end)

sliderButton.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = false
    end
end)

UIS.InputChanged:Connect(function(i)
    if draggingSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
        speedLimitPercent = math.clamp(
            (i.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X,
            0, 1
        )
        syncSpeedUi()
    end
end)

-- Create menu buttons
local btn1 = makeButton("Car Controls")
local btn2 = makeButton("Coming Soon...")
local btn3 = makeButton("Vehicle")

local vehicleControls = Instance.new("Frame")
vehicleControls.Size = UDim2.new(1, -40, 0, 220)
vehicleControls.Position = UDim2.fromOffset(20, 60)
vehicleControls.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
vehicleControls.BackgroundTransparency = 0.7
vehicleControls.Visible = false
vehicleControls.Parent = content
Instance.new("UICorner", vehicleControls).CornerRadius = UDim.new(0, 12)

local vehicleTitle = Instance.new("TextLabel")
vehicleTitle.Size = UDim2.new(1, 0, 0, 30)
vehicleTitle.Position = UDim2.fromOffset(0, 10)
vehicleTitle.BackgroundTransparency = 1
vehicleTitle.Text = "Vehicle"
vehicleTitle.TextColor3 = Color3.new(1, 1, 1)
vehicleTitle.Font = Enum.Font.GothamBold
vehicleTitle.TextSize = 18
vehicleTitle.Parent = vehicleControls

local indestructBtn = Instance.new("TextButton")
indestructBtn.Size = UDim2.new(0.8, 0, 0, 40)
indestructBtn.Position = UDim2.new(0.1, 0, 0.35, 0)
indestructBtn.Text = "Indestructible Vehicle: OFF"
indestructBtn.TextScaled = true
indestructBtn.Font = Enum.Font.GothamBold
indestructBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
indestructBtn.TextColor3 = Color3.new(1, 1, 1)
indestructBtn.Parent = vehicleControls
Instance.new("UICorner", indestructBtn).CornerRadius = UDim.new(0, 12)

local indestructEnabled = false
local touchConn = nil
local cleanupToken = 0

local function getTargetCarModel()
    local carCollection = workspace:FindFirstChild("CarCollection")
    if not carCollection then
        return nil
    end

    local ownerFolder = carCollection:FindFirstChild(player.Name) or carCollection:FindFirstChild("patrtk123")
    if not ownerFolder then
        return nil
    end

    local carModel = ownerFolder:FindFirstChild("Car")
    return carModel
end

local function isTouchInterest(inst)
    if inst.Name == "TouchInterest" then
        return true
    end

    if inst.ClassName == "TouchTransmitter" then
        return true
    end

    return false
end

local function isCollisionPart(inst)
    return inst:IsA("BasePart") and inst.Name == "Collision"
end

local function destroyAllTouchInterests(root)
    if not root then
        return
    end

    for _, d in ipairs(root:GetDescendants()) do
        if isTouchInterest(d) or isCollisionPart(d) then
            pcall(function()
                d:Destroy()
            end)
        end
    end
end

local function countTouchInterests(root)
    if not root then
        return 0
    end

    local n = 0
    for _, d in ipairs(root:GetDescendants()) do
        if isTouchInterest(d) or isCollisionPart(d) then
            n += 1
        end
    end
    return n
end

local function startCleanupUntilClear()
    cleanupToken += 1
    local myToken = cleanupToken

    task.spawn(function()
        while indestructEnabled and not shuttingDown and myToken == cleanupToken do
            local carModel = getTargetCarModel()
            if not carModel then
                task.wait(0.2)
            else
                local remaining = countTouchInterests(carModel)
                if remaining == 0 then
                    task.wait(0.5)
                else
                    destroyAllTouchInterests(carModel)
                    task.wait()
                end
            end
        end
    end)
end

local function enableIndestructible()
    startCleanupUntilClear()

    if touchConn then
        touchConn:Disconnect()
        touchConn = nil
    end

    touchConn = workspace.DescendantAdded:Connect(function(inst)
        if shuttingDown or not indestructEnabled then
            return
        end

        if not isTouchInterest(inst) and not isCollisionPart(inst) then
            return
        end

        local carModel = getTargetCarModel()
        if carModel and inst:IsDescendantOf(carModel) then
            pcall(function()
                inst:Destroy()
            end)
        end
    end)
end

local function disableIndestructible()
    cleanupToken += 1
    if touchConn then
        touchConn:Disconnect()
        touchConn = nil
    end
end

indestructBtn.MouseButton1Click:Connect(function()
    if shuttingDown then
        return
    end

    indestructEnabled = not indestructEnabled
    indestructBtn.Text = indestructEnabled and "Indestructible Vehicle: ON" or "Indestructible Vehicle: OFF"
    indestructBtn.BackgroundColor3 = indestructEnabled and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(200, 60, 60)

    if indestructEnabled then
        enableIndestructible()
    else
        disableIndestructible()
    end
end)

UIS.InputBegan:Connect(function(i, gp)
    if gp or shuttingDown then
        return
    end

    if i.KeyCode == Enum.KeyCode.R and indestructEnabled then
        startCleanupUntilClear()
    end
end)

-- Resize Handle
local resize = Instance.new("TextButton")
resize.Size = UDim2.fromOffset(30, 30)
resize.Position = UDim2.new(1, -30, 1, -30)
resize.Text = "↘"
resize.TextScaled = true
resize.BackgroundTransparency = 1
resize.TextColor3 = stroke.Color
resize.Parent = main

-- Resize functionality
local resizing, resizeStart, startSize = false, nil, nil
local canResize = false
local MAX_WIDTH, MAX_HEIGHT = 840, 720

resize.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and canResize then
        resizing = true
        resizeStart = i.Position
        startSize = main.Size
    end
end)

resize.InputEnded:Connect(function(i) 
    if i.UserInputType == Enum.UserInputType.MouseButton1 then 
        resizing = false 
    end 
end)

UIS.InputChanged:Connect(function(i)
    if resizing and startSize and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - resizeStart
        main.Size = UDim2.fromOffset(
            math.clamp(startSize.X.Offset + d.X, 350, MAX_WIDTH), 
            math.clamp(startSize.Y.Offset + d.Y, 280, MAX_HEIGHT)
        )
    end
end)

-- Key validation
keyBox.FocusLost:Connect(function(enter)
    if not enter then return end
    if keyBox.Text == REQUIRED_KEY then
        status.Text = "Access Granted"
        status.TextColor3 = Color3.fromRGB(80, 255, 80)
        TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), 
            {Size = UDim2.fromOffset(420, 500)}):Play()
        task.wait(0.35)
        keyBox.Visible = false
        status.Visible = false
        content.Visible = true
        canResize = true
    else
        status.Text = "Invalid Key"
        status.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

-- Discord copy
status.MouseButton1Click:Connect(function()
    pcall(function() 
        local cb = (typeof(_G) == "table") and _G.setclipboard or nil
        if typeof(cb) == "function" then
            cb(DISCORD_LINK)
        end
    end)
    local originalText = status.Text
    status.Text = "Link Copied!"
    task.delay(1, function() 
        status.Text = originalText 
    end)
end)

-- Car button shows car controls
btn1.MouseButton1Click:Connect(function()
    carControls.Visible = true
    vehicleControls.Visible = false

    btn1.Visible = false
    btn3.Visible = false
    btn2.Visible = true
    btn2.Text = "Back to Menu"
    
    -- Adjust main window size based on car controls visibility
    TweenService:Create(main, TweenInfo.new(0.3), {Size = UDim2.fromOffset(420, 600)}):Play()
end)

btn3.MouseButton1Click:Connect(function()
    vehicleControls.Visible = true
    carControls.Visible = false

    btn1.Visible = false
    btn3.Visible = false
    btn2.Visible = true
    btn2.Text = "Back to Menu"

    TweenService:Create(main, TweenInfo.new(0.3), {Size = UDim2.fromOffset(420, 560)}):Play()
end)

-- Back button behavior (only when car controls are open)
btn2.MouseButton1Click:Connect(function()
    if not carControls.Visible and not vehicleControls.Visible then
        return
    end

    carControls.Visible = false
    vehicleControls.Visible = false
    btn1.Visible = true
    btn2.Visible = true
    btn3.Visible = true
    btn2.Text = "Coming Soon..."
    TweenService:Create(main, TweenInfo.new(0.3), {Size = UDim2.fromOffset(420, 500)}):Play()
end)

toggleButton.MouseButton1Click:Connect(function()
    isCarEnabled = not isCarEnabled
    toggleButton.Text = isCarEnabled and "Power: ON" or "Power: OFF"
    toggleButton.BackgroundColor3 = isCarEnabled and Color3.fromRGB(60,200,60) or Color3.fromRGB(200,60,60)

    if not isCarEnabled then
        for k in pairs(driveInput) do
            driveInput[k] = false
        end
        for k in pairs(qeInput) do
            qeInput[k] = false
        end
    end
end)

local function onInputBegan(i, gp)
    if shuttingDown or gp or not isCarEnabled then return end
    if i.KeyCode == Enum.KeyCode.W then driveInput.W = true end
    if i.KeyCode == Enum.KeyCode.S then driveInput.S = true end
    if i.KeyCode == Enum.KeyCode.A then driveInput.A = true end
    if i.KeyCode == Enum.KeyCode.D then driveInput.D = true end
    if i.KeyCode == Enum.KeyCode.X then driveInput.X = true end
    if i.KeyCode == Enum.KeyCode.Q then qeInput.Q = true end
    if i.KeyCode == Enum.KeyCode.E then qeInput.E = true end
end

local function onInputEnded(i)
    if shuttingDown then return end
    if i.KeyCode == Enum.KeyCode.W then driveInput.W = false end
    if i.KeyCode == Enum.KeyCode.S then driveInput.S = false end
    if i.KeyCode == Enum.KeyCode.A then driveInput.A = false end
    if i.KeyCode == Enum.KeyCode.D then driveInput.D = false end
    if i.KeyCode == Enum.KeyCode.X then driveInput.X = false end
    if i.KeyCode == Enum.KeyCode.Q then qeInput.Q = false end
    if i.KeyCode == Enum.KeyCode.E then qeInput.E = false end
end

UIS.InputBegan:Connect(onInputBegan)
UIS.InputEnded:Connect(onInputEnded)

RunService.RenderStepped:Connect(function(dt)
    if shuttingDown or not isCarEnabled then return end
    if not humanoid or not humanoid.Parent then return end
    if not humanoid.Sit or not humanoid.SeatPart then return end

    if qeInput.E then speedLimitPercent = math.clamp(speedLimitPercent + QE_ADJUST_RATE * dt, 0, 1) end
    if qeInput.Q then speedLimitPercent = math.clamp(speedLimitPercent - QE_ADJUST_RATE * dt, 0, 1) end
    syncSpeedUi()

    local seatPart = humanoid.SeatPart
    local maxSpeed = HARD_MAX_SPEED * speedLimitPercent
    carSpeed = math.clamp(carSpeed, -reverseMax, maxSpeed)

    local driverGyro = seatPart:FindFirstChild("DriverGyro")
    if not driverGyro then
        driverGyro = Instance.new("BodyGyro")
        driverGyro.Name = "DriverGyro"
        driverGyro.MaxTorque = Vector3.new(0, math.huge, 0)
        driverGyro.P = 50000
        driverGyro.D = 2000
        driverGyro.CFrame = CFrame.new(seatPart.Position)
        driverGyro.Parent = seatPart
    end

    seatPart.AssemblyAngularVelocity = Vector3.new(0, seatPart.AssemblyAngularVelocity.Y, 0)

    if driveInput.X then
        carSpeed = 0
        seatPart.Velocity = Vector3.zero
        return
    end

    if driveInput.W then
        carSpeed = math.min(carSpeed + accel * dt, maxSpeed)
    elseif driveInput.S then
        carSpeed = math.max(carSpeed - accel * dt * 1.3, -reverseMax)
    else
        carSpeed = carSpeed * (1 - math.clamp(math.abs(carSpeed)/(maxSpeed+1), 0.02, 0.08))
    end

    local baseTurnRate = math.rad(180)
    local speedRatio = math.clamp(math.abs(carSpeed)/(maxSpeed+1), 0, 1)
    local turnAmount = baseTurnRate * (1 - 0.5*speedRatio) * dt

    local _, yaw, _ = driverGyro.CFrame:ToEulerAnglesYXZ()
    if driveInput.A then yaw += turnAmount end
    if driveInput.D then yaw -= turnAmount end
    driverGyro.CFrame = CFrame.new(seatPart.Position) * CFrame.Angles(0, yaw, 0)

    local look = seatPart.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude > 0 then
        forward = forward.Unit
    else
        forward = Vector3.new(0, 0, -1)
    end
    seatPart.Velocity = forward * carSpeed + Vector3.new(0, seatPart.Velocity.Y, 0)
end)

print("Chip'zter GUI loaded successfully!")
