local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- Usage Counter (once per session)
local hasCountedSession = false
local function incrementUsageCounter()
   if hasCountedSession then return end
   
   pcall(function()
      local url = "https://chippyzter.helioho.st/counter.php"
      local resp = request({Url = url, Method = "GET"})
      if resp and resp.StatusCode == 200 then
         hasCountedSession = true
         print("Usage counter incremented successfully")
      end
   end)
end

incrementUsageCounter()

local function startIdleKickPrevention()
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        wait(2)
    end)
end

local Rayfield = assert(loadstring, "loadstring is not available in this environment")(game:HttpGet('https://sirius.menu/rayfield'))
Rayfield = assert(Rayfield, "Failed to load Rayfield UI library")()

local Window = Rayfield:CreateWindow({
    Name = "Chipzter Gui V1.8.0",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Loading Chipzter Gui",
    Theme = "Default",
    ConfigurationSaving = false,
    KeySystem = false
})

local DiscordTab = Window:CreateTab("Discord Link", "lock")
DiscordTab:CreateSection("Join our Discord Community")

DiscordTab:CreateButton({
    Name = "Copy Discord Link",
    Callback = function()
        local discordLink = "https://discord.gg/UwcKe2MXca"
        local clipboardSuccess = false
        
        pcall(function()
            if _G.setclipboard then
                _G.setclipboard(discordLink)
                clipboardSuccess = true
            end
        end)
        
        if not clipboardSuccess then
            pcall(function()
                setclipboard(discordLink)
                clipboardSuccess = true
            end)
        end
        
        if not clipboardSuccess then
            pcall(function()
                local env = getgenv and getgenv() or _G
                if env.setclipboard then
                    env.setclipboard(discordLink)
                    clipboardSuccess = true
                end
            end)
        end
        
        if not clipboardSuccess then
            pcall(function()
                if syn and syn.write_clipboard then
                    syn.write_clipboard(discordLink)
                    clipboardSuccess = true
                end
            end)
        end
        
        if clipboardSuccess then
            Rayfield:Notify({Title = "Copied!", Content = "Discord link copied to clipboard!", Duration = 3, Image = 11567543471})
        else
            Rayfield:Notify({Title = "Discord Link", Content = discordLink, Duration = 8, Image = 11567543471})
        end
    end
})

DiscordTab:CreateParagraph({
    Title = "Discord Server",
    Content = "Join our Discord for updates, support, and more features!"
})

startIdleKickPrevention()

-- ===== OBVIOUS SPEED MULTIPLIER VARIABLES =====
local carSpeed = 0
local currentSteering = 0
local currentAccDir = 0
local speedEnabled = false
local hardSpeedCap = 200
local accelerating = false
local braking = false
local steer = 0
local currentSeat = nil
local lv = nil
local av = nil
local gyroActive = false

local speedSliderValue = 5
local turningSliderValue = 75
local speedCapValue = 500

local alternateSpeedEnabled = false

local suspensionEnabled = false
local stiffnessProtectionEnabled = false

-- ===== CAR FUNCTIONS =====
local function findPlayerSeat()
    local player = LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("Humanoid") then return nil end
    
    local seat = character.Humanoid.SeatPart
    if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
        return seat
    end
    
    local carCollection = workspace:FindFirstChild("CarCollection")
    if carCollection then
        local playerFolder = carCollection:FindFirstChild(player.Name)
        if playerFolder then
            local carModel = playerFolder:FindFirstChild("Car")
            if carModel then
                for _, part in ipairs(carModel:GetDescendants()) do
                    if part:IsA("Seat") or part:IsA("VehicleSeat") then
                        if part.Occupant == character.Humanoid then
                            return part
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function setupSeat(seat)
    currentSeat = seat
    
    local carModel = seat.Parent
    local primaryPart = carModel.PrimaryPart or carModel:FindFirstChildWhichIsA("BasePart")
    
    if primaryPart then
        if lv then lv:Destroy() end
        if av then av:Destroy() end
        
        -- BodyVelocity for speed - now only affects horizontal movement
        lv = Instance.new("BodyVelocity")
        lv.MaxForce = Vector3.new(math.huge, 0, math.huge) -- No vertical force
        lv.P = 5000
        lv.Parent = primaryPart
        
        -- BodyGyro for turning
        av = Instance.new("BodyGyro")
        av.MaxTorque = Vector3.new(0, math.huge, 0)
        av.P = 100000
        av.D = 5000
        av.Parent = primaryPart
        
        gyroActive = true
    end
end

local masterPhysicsConnection = nil
local lastInputUpdate = 0
local lastReferenceUpdate = 0

local cachedCarCollection = nil
local cachedPlayerFolder = nil
local cachedCarModel = nil
local cachedWheels = nil

local stickyWheelsEnabled = false
local stickyWheelsForces = {}
local downForceStrength = 15000
local originalWheelSizes = {}

local ao = nil

local function cleanupStickyWheelsControl()
    for _, force in pairs(stickyWheelsForces) do
        if force and force.Parent then
            force:Destroy()
        end
    end
    stickyWheelsForces = {}
    
    if cachedWheels then
        for _, wheelName in ipairs({"FL", "FR", "RL", "RR"}) do
            local wheel = cachedWheels:FindFirstChild(wheelName)
            if wheel and wheel:IsA("BasePart") then
                local currentSize = wheel.Size
                if typeof(currentSize) == "Vector3" then
                    wheel.Size = Vector3.new(currentSize.X, originalWheelSizes[wheelName] or 2, currentSize.Z)
                end
            end
        end
    end
    originalWheelSizes = {}
end

local function updateCachedReferences()
    cachedCarCollection = workspace:FindFirstChild("CarCollection")
    if cachedCarCollection then
        cachedPlayerFolder = cachedCarCollection:FindFirstChild(LocalPlayer.Name)
        if cachedPlayerFolder then
            cachedCarModel = cachedPlayerFolder:FindFirstChild("Car")
            if cachedCarModel then
                cachedWheels = cachedCarModel:FindFirstChild("Wheels")
            end
        end
    end
end

local function updateMasterPhysics(dt)
    if not speedEnabled then return end
    
    local currentTime = tick()
    
    if currentTime - lastReferenceUpdate > 2 then
        updateCachedReferences()
        lastReferenceUpdate = currentTime
    end
    
    local seat = findPlayerSeat()
    if not seat then return end
    
    if seat ~= currentSeat then
        setupSeat(seat)
    end
    
    -- Get slider values
    if Rayfield.Flags then
        if Rayfield.Flags.SpeedAdjustment then
            speedSliderValue = tonumber(Rayfield.Flags.SpeedAdjustment) or 5
        end
        if Rayfield.Flags.TurningForce then
            turningSliderValue = tonumber(Rayfield.Flags.TurningForce) or 75
        end
        if Rayfield.Flags.SpeedCap then
            speedCapValue = tonumber(Rayfield.Flags.SpeedCap) or 500
        end
    end
    
    -- Get acceleration direction
    if cachedPlayerFolder then
        local accDir = cachedPlayerFolder:FindFirstChild("AccDir")
        if accDir and accDir:IsA("IntValue") then
            currentAccDir = tonumber(accDir.Value) or 0
        else
            currentAccDir = 0
        end
    else
        currentAccDir = 0
    end
    
    if currentAccDir == 1 then
        accelerating = true
        braking = false
    elseif currentAccDir == -1 then
        accelerating = true
        braking = false
    else
        accelerating = false
        braking = false
    end
    
    -- Get steering
    if cachedCarModel and cachedWheels then
        local flWheel = cachedWheels:FindFirstChild("FL")
        if flWheel then
            local arm = flWheel:FindFirstChild("Arm")
            if arm then
                for _, child in ipairs(arm:GetChildren()) do
                    if child:IsA("HingeConstraint") then
                        local targetAngle = child.TargetAngle
                        if targetAngle < 0 then
                            currentSteering = -1
                        elseif targetAngle > 0 then
                            currentSteering = 1
                        else
                            currentSteering = 0
                        end
                        break
                    end
                end
            end
        end
    end
    steer = currentSteering
    
    local turningRate = (turningSliderValue / 100) * 180
    
    -- Speed calculation - proper gravity-respecting physics
    if not alternateSpeedEnabled then
        if accelerating and currentAccDir == 1 then
            -- Acceleration: increase speed based on slider value
            local accelerationRate = speedSliderValue * 200
            carSpeed = math.min(carSpeed + accelerationRate * dt, speedCapValue)
        elseif currentAccDir == 0 then
            -- Coasting: slow down gradually (friction/drag)
            carSpeed = math.max(0, carSpeed - 100 * dt)
        elseif currentAccDir == -1 then
            -- Braking/Reversing
            local decelerationRate = speedSliderValue * 150
            carSpeed = math.max(0, carSpeed - decelerationRate * dt)
        end
        
        -- Apply velocity to car - HORIZONTAL ONLY, gravity handles vertical
        if cachedCarModel and cachedCarModel.PrimaryPart and lv then
            local forwardVector = seat.CFrame.LookVector
            if typeof(forwardVector) ~= "Vector3" then
                forwardVector = Vector3.new(0, 0, 1)
            end
            local forwardMovement = forwardVector.Unit
            
            -- Only apply horizontal velocity, leave Y alone for gravity
            if carSpeed > 0 and currentAccDir == 1 then
                lv.Velocity = Vector3.new(forwardMovement.X * carSpeed, 0, forwardMovement.Z * carSpeed)
            elseif currentAccDir == -1 then
                lv.Velocity = Vector3.new(-forwardMovement.X * math.min(carSpeed, speedCapValue * 0.3), 0, -forwardMovement.Z * math.min(carSpeed, speedCapValue * 0.3))
            else
                lv.Velocity = Vector3.new(0, 0, 0)
            end
        end
    else
        -- Alternate speed mode
        if lv then
            lv.Velocity = Vector3.new(0, 0, 0)
        end
        
        if cachedWheels then
            local wheelPatterns = {"FL", "FR", "RL", "RR"}
            for _, pattern in ipairs(wheelPatterns) do
                for _, wheel in ipairs(cachedWheels:GetChildren()) do
                    if wheel.Name == pattern then
                        local cylindricalConstraint = wheel:FindFirstChildWhichIsA("CylindricalConstraint")
                        
                        if cylindricalConstraint then
                            local angularVelocity = 0
                            if accelerating and currentAccDir == 1 then
                                angularVelocity = speedCapValue * (speedSliderValue / 5)
                            elseif currentAccDir == -1 then
                                angularVelocity = -speedCapValue * (speedSliderValue / 5) * 0.3
                            else
                                angularVelocity = 0
                            end
                            
                            if type(angularVelocity) == "number" then
                                cylindricalConstraint.AngularVelocity = angularVelocity
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Steering - ONLY horizontal rotation, allows gravity to work
    if steer ~= 0 then
        local turnRadiansPerFrame = math.rad(turningRate) * dt
        local carModel = seat.Parent
        local primaryPart = carModel.PrimaryPart or carModel:FindFirstChildWhichIsA("BasePart")
        if primaryPart and av then
            local currentCFrame = primaryPart.CFrame
            -- Only rotate around Y axis (up/down), preserving position for gravity
            local rotation = CFrame.Angles(0, -steer * turnRadiansPerFrame, 0)
            av.CFrame = currentCFrame * rotation
            gyroActive = true
        end
    else
        if av and gyroActive then
            local carModel = seat.Parent
            local primaryPart = carModel.PrimaryPart or carModel:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                -- Just maintain current rotation without forcing position
                av.CFrame = primaryPart.CFrame
            end
        end
    end
    
    -- AntiFlip - check if cachedWheels exists
    if stickyWheelsEnabled and cachedWheels then
        local allWheels = {"FL", "FR", "RL", "RR"}
        for _, wheelName in ipairs(allWheels) do
            local wheel = cachedWheels:FindFirstChild(wheelName)
            if wheel and wheel:IsA("BasePart") then
                if not originalWheelSizes[wheelName] then
                    local wheelSize = wheel.Size
                    if typeof(wheelSize) == "Vector3" then
                        originalWheelSizes[wheelName] = wheelSize.Y
                    else
                        originalWheelSizes[wheelName] = 2
                    end
                end
                
                local sizeMultiplier = 1 + (downForceStrength / 10)
                local newYSize = (originalWheelSizes[wheelName] or 2) * sizeMultiplier
                
                local currentSize = wheel.Size
                if typeof(currentSize) == "Vector3" then
                    wheel.Size = Vector3.new(currentSize.X, newYSize, currentSize.Z)
                end
            end
        end
    end
end

local function startMasterPhysics()
    if masterPhysicsConnection then return end
    updateCachedReferences()
    masterPhysicsConnection = game:GetService("RunService").Heartbeat:Connect(updateMasterPhysics)
end

local function stopMasterPhysics()
    if masterPhysicsConnection then
        masterPhysicsConnection:Disconnect()
        masterPhysicsConnection = nil
    end
    
    if lv then
        lv.Velocity = Vector3.new(0, 0, 0)
        lv:Destroy()
        lv = nil
    end
    if av then
        av:Destroy()
        av = nil
    end
    if ao then
        ao:Destroy()
        ao = nil
    end
    
    gyroActive = false
    carSpeed = 0
    currentSteering = 0
    steer = 0
    
    cachedCarCollection = nil
    cachedPlayerFolder = nil
    cachedCarModel = nil
    cachedWheels = nil
end

-- ===== FRICTION FUNCTIONS =====
local frictionEnabled = false
local frictionValue = 50
local originalFrictionValues = {}
local frictionProtectionConnection = nil

local function updateFrictionValues()
    pcall(function()
        local carCollection = workspace:FindFirstChild("CarCollection")
        if carCollection then
            local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
            if playerModel then
                local carModel = playerModel:FindFirstChild("Car")
                if carModel then
                    local wheels = carModel:FindFirstChild("Wheels")
                    if wheels then
                        local frictionProperty = (frictionValue / 100) * 2
                        local frictionWeightProperty = frictionValue == 100 and 100 or frictionValue
                        
                        local wheelPatterns = {"FL", "FR", "RL", "RR"}
                        for _, pattern in ipairs(wheelPatterns) do
                            for _, wheel in ipairs(wheels:GetChildren()) do
                                if wheel.Name == pattern then
                                    local props = wheel.CustomPhysicalProperties
                                    if props then
                                        local customProps = PhysicalProperties.new(
                                            props.Density,
                                            frictionProperty,
                                            props.Elasticity,
                                            frictionWeightProperty,
                                            props.ElasticityWeight
                                        )
                                        wheel.CustomPhysicalProperties = customProps
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function startFrictionProtection()
    if frictionProtectionConnection then
        frictionProtectionConnection:Disconnect()
        frictionProtectionConnection = nil
    end
    
    frictionProtectionConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if frictionEnabled then
            updateFrictionValues()
        end
    end)
end

local function stopFrictionProtection()
    if frictionProtectionConnection then
        frictionProtectionConnection:Disconnect()
        frictionProtectionConnection = nil
    end
end

-- ===== SUSPENSION FUNCTIONS =====
local targetFrontSuspensionHeight = 0
local targetRearSuspensionHeight = 0
local suspensionStiffness = 50
local suspensionDamping = 1150
local originalSuspensionStiffnessSaved = 50
local originalSuspensionDamping = 1150

local stiffnessGuardConnection = nil

local frontCamber = 0
local rearCamber = 0
local frontTrackWidth = 0
local rearTrackWidth = 0

local function updateSuspensionValues()
    if not suspensionEnabled then return end
    
    pcall(function()
        local carCollection = workspace:FindFirstChild("CarCollection")
        if not carCollection then return end
        
        local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
        if not playerModel then return end
        
        local carModel = playerModel:FindFirstChild("Car")
        if not carModel then return end
        
        local wheels = carModel:FindFirstChild("Wheels")
        if not wheels then return end
        
        local frontWheels = {"FL", "FR"}
        for _, wheelName in ipairs(frontWheels) do
            local wheel = wheels:FindFirstChild(wheelName)
            if wheel then
                local spring = wheel:FindFirstChild("Spring")
                if spring and spring:IsA("SpringConstraint") then
                    spring.Stiffness = suspensionStiffness
                    spring.Damping = suspensionDamping
                    spring.MaxLength = targetFrontSuspensionHeight
                    spring.FreeLength = targetFrontSuspensionHeight
                    if targetFrontSuspensionHeight > 1 then
                        spring.MinLength = targetFrontSuspensionHeight - 1
                    else
                        spring.MinLength = 0
                    end
                    spring.LimitsEnabled = true
                end
            end
        end
        
        local rearWheels = {"RL", "RR"}
        for _, wheelName in ipairs(rearWheels) do
            local wheel = wheels:FindFirstChild(wheelName)
            if wheel then
                local spring = wheel:FindFirstChild("Spring")
                if spring and spring:IsA("SpringConstraint") then
                    spring.Stiffness = suspensionStiffness
                    spring.Damping = suspensionDamping
                    spring.MaxLength = targetRearSuspensionHeight
                    spring.FreeLength = targetRearSuspensionHeight
                    if targetRearSuspensionHeight > 1 then
                        spring.MinLength = targetRearSuspensionHeight - 1
                    else
                        spring.MinLength = 0
                    end
                    spring.LimitsEnabled = true
                end
            end
        end
    end)
end

local function startStiffnessGuard()
    if stiffnessGuardConnection then
        stiffnessGuardConnection:Disconnect()
    end
    
    stiffnessProtectionEnabled = true
    
    stiffnessGuardConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not suspensionEnabled or not stiffnessProtectionEnabled then return end
        
        local carCollection = workspace:FindFirstChild("CarCollection")
        if not carCollection then return end
        
        local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
        if not playerModel then return end
        
        local carModel = playerModel:FindFirstChild("Car")
        if not carModel then return end
        
        local wheels = carModel:FindFirstChild("Wheels")
        if not wheels then return end
        
        for _, wheel in ipairs(wheels:GetChildren()) do
            local spring = wheel:FindFirstChild("Spring")
            if spring and spring:IsA("SpringConstraint") then
                if spring.Stiffness ~= suspensionStiffness then
                    spring.Stiffness = suspensionStiffness
                end
            end
        end
    end)
end

local function stopStiffnessGuard()
    stiffnessProtectionEnabled = false
    if stiffnessGuardConnection then
        stiffnessGuardConnection:Disconnect()
        stiffnessGuardConnection = nil
    end
end

local function startHighPrioritySuspension()
    local updateConnection
    updateConnection = game:GetService("RunService").RenderStepped:Connect(function()
        if not suspensionEnabled then 
            if updateConnection then
                updateConnection:Disconnect()
            end
            return 
        end
        updateSuspensionValues()
    end)
    return updateConnection
end

local function updateCamberValues()
    if not suspensionEnabled then return end
    
    pcall(function()
        local carCollection = workspace:FindFirstChild("CarCollection")
        if not carCollection then return end
        
        local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
        if not playerModel then return end
        
        local carModel = playerModel:FindFirstChild("Car")
        if not carModel then return end
        
        local wheels = carModel:FindFirstChild("Wheels")
        if not wheels then return end
        
        local frontWheels = {"FL", "FR"}
        for _, wheelPattern in ipairs(frontWheels) do
            for _, wheel in ipairs(wheels:GetChildren()) do
                if wheel.Name == wheelPattern then
                    local cylindricalConstraint = wheel:FindFirstChildWhichIsA("CylindricalConstraint")
                    if cylindricalConstraint then
                        local mappedAngle = frontCamber - 180
                        if frontCamber == 360 then
                            mappedAngle = 180
                        else
                            mappedAngle = frontCamber - 180
                        end
                        cylindricalConstraint.InclinationAngle = mappedAngle
                    end
                end
            end
        end
        
        local rearWheels = {"RL", "RR"}
        for _, wheelPattern in ipairs(rearWheels) do
            for _, wheel in ipairs(wheels:GetChildren()) do
                if wheel.Name == wheelPattern then
                    local cylindricalConstraint = wheel:FindFirstChildWhichIsA("CylindricalConstraint")
                    if cylindricalConstraint then
                        local mappedAngle = rearCamber - 180
                        if rearCamber == 360 then
                            mappedAngle = 180
                        else
                            mappedAngle = rearCamber - 180
                        end
                        cylindricalConstraint.InclinationAngle = mappedAngle
                    end
                end
            end
        end
    end)
end

local function updateTrackWidthValues()
    if not suspensionEnabled then return end
    
    pcall(function()
        local carCollection = workspace:FindFirstChild("CarCollection")
        if not carCollection then return end
        
        local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
        if not playerModel then return end
        
        local carModel = playerModel:FindFirstChild("Car")
        if not carModel then return end
        
        local wheels = carModel:FindFirstChild("Wheels")
        if not wheels then return end
        
        local frontWheels = {"FL", "FR"}
        for _, wheelName in ipairs(frontWheels) do
            local wheel = wheels:FindFirstChild(wheelName)
            if wheel then
                local arm = wheel:FindFirstChild("Arm")
                if arm and arm:IsA("Part") then
                    local hingeAtt = arm:FindFirstChild("HingeAtt")
                    if hingeAtt and hingeAtt:IsA("Attachment") then
                        local currentPos = hingeAtt.Position
                        hingeAtt.Position = Vector3.new(currentPos.X, frontTrackWidth, currentPos.Z)
                    end
                end
            end
        end
        
        local rearWheels = {"RL", "RR"}
        for _, wheelName in ipairs(rearWheels) do
            local wheel = wheels:FindFirstChild(wheelName)
            if wheel then
                local base = wheel:FindFirstChild("Base")
                if base and base:IsA("Part") then
                    local sAtt = base:FindFirstChild("SAtt")
                    if sAtt and sAtt:IsA("Attachment") then
                        local currentPos = sAtt.Position
                        sAtt.Position = Vector3.new(currentPos.X, rearTrackWidth, currentPos.Z)
                    end
                end
            end
        end
    end)
end

-- ===== MAIN TAB =====
local MainTab = Window:CreateTab("Car Enhancements", "car")
MainTab:CreateSection("Vehicle")

MainTab:CreateToggle({
    Name = "Obvious Speed Multiplier",
    CurrentValue = false,
    Callback = function(Value)
        speedEnabled = Value
        if Value then
            startMasterPhysics()
            Rayfield:Notify({Title = "Obvious Speed Multiplier", Content = "Enabled! Speed and turning controls active. Gravity works normally!", Duration = 3, Image = 11567543471})
        else
            stopMasterPhysics()
            carSpeed = 0
            currentSteering = 0
            accelerating = false
            braking = false
            currentAccDir = 0
            Rayfield:Notify({Title = "Obvious Speed Multiplier", Content = "Disabled!", Duration = 3, Image = 11567543659})
        end
    end
})

MainTab:CreateToggle({
    Name = "Alternate Speed Modification",
    CurrentValue = false,
    Callback = function(Value)
        alternateSpeedEnabled = Value
        
        if Value then
            Rayfield:Notify({Title = "Speed Mode", Content = "Angular Velocity mode enabled! Uses wheel rotation for speed.", Duration = 3, Image = 11567543471})
            if not speedEnabled then
                speedEnabled = true
                startMasterPhysics()
            end
        else
            Rayfield:Notify({Title = "Speed Mode", Content = "Normal velocity mode enabled!", Duration = 3, Image = 11567543659})
            if lv then
                lv.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end
})

MainTab:CreateSlider({
    Name = "Acceleration Power",
    Range = {0, 10},
    Increment = 0.1,
    CurrentValue = 5,
    Flag = "SpeedAdjustment",
    Callback = function(Value)
        speedSliderValue = tonumber(Value) or 5
    end
})

MainTab:CreateSlider({
    Name = "Turning Force (Degrees)",
    Range = {0, 150},
    Increment = 5,
    CurrentValue = 75,
    Flag = "TurningForce",
    Callback = function(Value)
        turningSliderValue = tonumber(Value) or 75
    end
})

MainTab:CreateSlider({
    Name = "Speed Cap (MPH)",
    Range = {1, 1000},
    Increment = 10,
    CurrentValue = 500,
    Flag = "SpeedCap",
    Callback = function(Value)
        speedCapValue = tonumber(Value) or 500
        -- Convert MPH to studs/second (1 MPH ≈ 0.44704 studs/sec)
        hardSpeedCap = speedCapValue * 0.44704
        Rayfield:Notify({Title = "Speed Cap", Content = "Set to " .. speedCapValue .. " MPH (" .. math.floor(hardSpeedCap) .. " studs/sec)", Duration = 2, Image = 11567543471})
    end
})

MainTab:CreateButton({
    Name = "Make Car Invincible",
    Callback = function()
        local player = LocalPlayer
        local playerGui = player:FindFirstChild("PlayerGui")
        
        if playerGui then
            local collisionDamage = playerGui:FindFirstChild("CollisionDamage")
            if collisionDamage then
                collisionDamage:Destroy()
                Rayfield:Notify({Title = "Invincible Car", Content = "CollisionDamage script removed!", Duration = 3, Image = 11567543659})
            else
                Rayfield:Notify({Title = "Invincible Car", Content = "CollisionDamage script not found!", Duration = 3, Image = 11567543659})
            end
        else
            Rayfield:Notify({Title = "Invincible Car", Content = "PlayerGui not found!", Duration = 3, Image = 11567543659})
        end
    end
})

MainTab:CreateToggle({
    Name = "Friction Control",
    CurrentValue = false,
    Callback = function(Value)
        frictionEnabled = Value
        
        if Value then
            pcall(function()
                local carCollection = workspace:FindFirstChild("CarCollection")
                if carCollection then
                    local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
                    if playerModel then
                        local carModel = playerModel:FindFirstChild("Car")
                        if carModel then
                            local wheels = carModel:FindFirstChild("Wheels")
                            if wheels then
                                local wheelPatterns = {"FL", "FR", "RL", "RR"}
                                for _, pattern in ipairs(wheelPatterns) do
                                    for _, wheel in ipairs(wheels:GetChildren()) do
                                        if wheel.Name == pattern then
                                            local customPhysicalProperties = wheel.CustomPhysicalProperties
                                            if customPhysicalProperties then
                                                originalFrictionValues[wheel] = {
                                                    Friction = customPhysicalProperties.Friction,
                                                    FrictionWeight = customPhysicalProperties.FrictionWeight
                                                }
                                            end
                                        end
                                    end
                                end
                                
                                updateFrictionValues()
                                startFrictionProtection()
                                Rayfield:Notify({Title = "Friction Control", Content = "Friction control enabled!", Duration = 3, Image = 11567543471})
                            end
                        end
                    end
                end
            end)
        else
            stopFrictionProtection()
            
            pcall(function()
                local restored = 0
                for wheel, values in pairs(originalFrictionValues) do
                    if wheel and wheel.CustomPhysicalProperties then
                        wheel.CustomPhysicalProperties = PhysicalProperties.new({
                            Density = wheel.CustomPhysicalProperties.Density,
                            Friction = values.Friction,
                            Elasticity = wheel.CustomPhysicalProperties.Elasticity,
                            FrictionWeight = values.FrictionWeight,
                            ElasticityWeight = wheel.CustomPhysicalProperties.ElasticityWeight
                        })
                        restored = restored + 1
                    end
                end
                originalFrictionValues = {}
                Rayfield:Notify({Title = "Friction Control", Content = "Disabled! Restored " .. restored .. " wheels.", Duration = 3, Image = 11567543659})
            end)
        end
    end
})

MainTab:CreateSlider({
    Name = "Friction",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 50,
    Flag = "Friction",
    Callback = function(Value)
        frictionValue = Value
        
        if frictionEnabled then
            updateFrictionValues()
        end
    end
})

MainTab:CreateToggle({
    Name = "AntiFlip",
    CurrentValue = false,
    Callback = function(Value)
        stickyWheelsEnabled = Value
        if Value then
            updateCachedReferences()
            if not cachedWheels then
                Rayfield:Notify({Title = "AntiFlip", Content = "No wheels found! Get in a car first.", Duration = 3, Image = 11567543659})
                stickyWheelsEnabled = false
                return
            end
            Rayfield:Notify({Title = "AntiFlip", Content = "AntiFlip activated!", Duration = 3, Image = 11567543471})
        else
            cleanupStickyWheelsControl()
            Rayfield:Notify({Title = "AntiFlip", Content = "AntiFlip disabled!", Duration = 3, Image = 11567543659})
        end
    end
})

MainTab:CreateSlider({
    Name = "AntiFlip Strength",
    Range = {0, 20},
    Increment = 1,
    CurrentValue = 10,
    Flag = "DownForceStrength",
    Callback = function(Value)
        downForceStrength = tonumber(Value) or 10
    end
})

-- ===== SUSPENSION TAB =====
local SuspensionTab = Window:CreateTab("Suspension", "car")
SuspensionTab:CreateSection("Suspension Settings")

SuspensionTab:CreateToggle({
    Name = "Enable Suspension",
    CurrentValue = false,
    Callback = function(Value)
        suspensionEnabled = Value
        if Value then
            originalSuspensionStiffnessSaved = suspensionStiffness
            originalSuspensionDamping = suspensionDamping
            
            startStiffnessGuard()
            startHighPrioritySuspension()
            
            updateSuspensionValues()
            updateCamberValues()
            updateTrackWidthValues()
            
            Rayfield:Notify({Title = "Suspension", Content = "Suspension system activated!", Duration = 3, Image = 11567543471})
        else
            stopStiffnessGuard()
            
            updateSuspensionValues()
            updateCamberValues()
            updateTrackWidthValues()
            
            Rayfield:Notify({Title = "Suspension", Content = "Suspension system deactivated!", Duration = 3, Image = 11567543659})
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Front Suspension Height",
    Range = {0, 10},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "FrontSuspensionHeight",
    Callback = function(Value)
        targetFrontSuspensionHeight = tonumber(Value) or 0
        if suspensionEnabled then
            updateSuspensionValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Rear Suspension Height",
    Range = {0, 10},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "RearSuspensionHeight",
    Callback = function(Value)
        targetRearSuspensionHeight = tonumber(Value) or 0
        if suspensionEnabled then
            updateSuspensionValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Suspension Stiffness",
    Range = {10, 1000000},
    Increment = 10,
    CurrentValue = 50,
    Flag = "SuspensionStiffness",
    Callback = function(Value)
        suspensionStiffness = tonumber(Value) or 50
        if suspensionEnabled then
            updateSuspensionValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Suspension Damping",
    Range = {10000, 100000},
    Increment = 1000,
    CurrentValue = 50000,
    Flag = "SuspensionDamping",
    Callback = function(Value)
        suspensionDamping = tonumber(Value) or 50000
        if suspensionEnabled then
            updateSuspensionValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Front Camber",
    Range = {0, 360},
    Increment = 1,
    CurrentValue = 0,
    Flag = "FrontCamber",
    Callback = function(Value)
        frontCamber = tonumber(Value) or 0
        if suspensionEnabled then
            updateCamberValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Rear Camber",
    Range = {0, 360},
    Increment = 1,
    CurrentValue = 0,
    Flag = "RearCamber",
    Callback = function(Value)
        rearCamber = tonumber(Value) or 0
        if suspensionEnabled then
            updateCamberValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Front Track Width",
    Range = {0, 15},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "FrontTrackWidth",
    Callback = function(Value)
        frontTrackWidth = tonumber(Value) or 0
        if suspensionEnabled then
            updateTrackWidthValues()
        end
    end
})

SuspensionTab:CreateSlider({
    Name = "Rear Track Width",
    Range = {0, 15},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "RearTrackWidth",
    Callback = function(Value)
        rearTrackWidth = tonumber(Value) or 0
        if suspensionEnabled then
            updateTrackWidthValues()
        end
    end
})

-- ===== HYDRAULICS TAB =====
local HydraulicsTab = Window:CreateTab("Hydraulics", "car")
HydraulicsTab:CreateSection("Hydraulics Settings")

local hydraulicsEnabled = false
local hydraulicsGui = nil
local hydraulicButtons = {}
local maybachPovEnabled = false
local maybachPovConnection = nil
local maybachPovTime = 0

local function startMaybachPov()
    if maybachPovConnection then return end
    
    maybachPovEnabled = true
    maybachPovTime = 0
    
    maybachPovConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not maybachPovEnabled then return end
        
        maybachPovTime = maybachPovTime + dt
        local movement = math.abs(math.sin(maybachPovTime * 3)) * 1.5
        
        pcall(function()
            local carCollection = workspace:FindFirstChild("CarCollection")
            if not carCollection then return end
            
            local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
            if not playerModel then return end
            
            local carModel = playerModel:FindFirstChild("Car")
            if not carModel then return end
            
            local wheels = carModel:FindFirstChild("Wheels")
            if not wheels then return end
            
            local allWheels = {"FL", "FR", "RL", "RR"}
            for _, wheelName in ipairs(allWheels) do
                local wheel = wheels:FindFirstChild(wheelName)
                if wheel then
                    local spring = wheel:FindFirstChild("Spring")
                    if spring and spring:IsA("SpringConstraint") then
                        local baseLength = 2
                        local newMaxLength = baseLength + movement
                        local newMinLength = newMaxLength - 1
                        
                        spring.MaxLength = newMaxLength
                        spring.MinLength = newMinLength
                        spring.FreeLength = newMaxLength
                        spring.LimitsEnabled = true
                    end
                end
            end
        end)
    end)
end

local function stopMaybachPov()
    maybachPovEnabled = false
    if maybachPovConnection then
        maybachPovConnection:Disconnect()
        maybachPovConnection = nil
    end
    
    pcall(function()
        local carCollection = workspace:FindFirstChild("CarCollection")
        if not carCollection then return end
        
        local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
        if not playerModel then return end
        
        local carModel = playerModel:FindFirstChild("Car")
        if not carModel then return end
        
        local wheels = carModel:FindFirstChild("Wheels")
        if not wheels then return end
        
        local allWheels = {"FL", "FR", "RL", "RR"}
        for _, wheelName in ipairs(allWheels) do
            local wheel = wheels:FindFirstChild(wheelName)
            if wheel then
                local spring = wheel:FindFirstChild("Spring")
                if spring and spring:IsA("SpringConstraint") then
                    spring.MaxLength = 2
                    spring.MinLength = 1
                    spring.FreeLength = 2
                    spring.LimitsEnabled = true
                end
            end
        end
    end)
end

local function createHydraulicsGui()
    if hydraulicsGui then return end
    
    hydraulicsGui = Instance.new("ScreenGui")
    hydraulicsGui.Name = "HydraulicsGui"
    hydraulicsGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    hydraulicsGui.ResetOnSpawn = false
    
    local camera = workspace.CurrentCamera
    local screenSize = camera.ViewportSize
    local isMobile = (game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled)
    
    local baseButtonWidth = isMobile and 100 or 80
    local baseButtonHeight = isMobile and 120 or 60
    
    local buttonSpacing = 20
    local padding = 40
    local draggableAreaHeight = 70
    
    local calculatedWidth = (baseButtonWidth * 2) + buttonSpacing + (padding * 2)
    local calculatedHeight = (baseButtonHeight * 3) + (buttonSpacing * 2) + (padding * 2) + draggableAreaHeight
    
    local baseWidth = math.max(calculatedWidth, isMobile and 400 or 300)
    local baseHeight = math.max(calculatedHeight, isMobile and 1000 or 750)
    
    local scaleX = screenSize.X / 1080
    local scaleY = screenSize.Y / 1980
    local scale = math.min(scaleX, scaleY)
    
    local finalWidth = baseWidth * scale
    local finalHeight = baseHeight * scale
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = hydraulicsGui
    mainFrame.Size = UDim2.new(0, finalWidth, 0, finalHeight)
    mainFrame.Position = UDim2.new(0.5, -finalWidth/2, 0.5, -finalHeight/2)
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    mainFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15 * scale)
    corner.Parent = mainFrame
    
    local grayRectangle = Instance.new("Frame")
    grayRectangle.Name = "GrayRectangle"
    grayRectangle.Parent = mainFrame
    grayRectangle.Size = UDim2.new(1, -20, 0, 60)
    grayRectangle.Position = UDim2.new(0, 10, 1, -70)
    grayRectangle.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    grayRectangle.BorderSizePixel = 0
    
    local grayCorner = Instance.new("UICorner")
    grayCorner.CornerRadius = UDim.new(0, 12)
    grayCorner.Parent = grayRectangle
    
    local draggableText = Instance.new("TextLabel")
    draggableText.Name = "DraggableText"
    draggableText.Parent = grayRectangle
    draggableText.Size = UDim2.new(1, 0, 1, 0)
    draggableText.Position = UDim2.new(0, 0, 0, 0)
    draggableText.BackgroundTransparency = 1
    draggableText.Text = "Draggable"
    draggableText.TextColor3 = Color3.new(0, 0, 0)
    draggableText.TextScaled = true
    draggableText.Font = Enum.Font.SourceSansBold
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local dragConnection = nil
    local moveConnection = nil
    
    grayRectangle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            if dragConnection then dragConnection:Disconnect() end
            if moveConnection then moveConnection:Disconnect() end
            
            dragConnection = game:GetService("UserInputService").InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = input.Position - dragStart
                    mainFrame.Position = UDim2.new(
                        startPos.X.Scale,
                        startPos.X.Offset + delta.X,
                        startPos.Y.Scale,
                        startPos.Y.Offset + delta.Y
                    )
                end
            end)
            
            moveConnection = game:GetService("UserInputService").InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                    if dragConnection then dragConnection:Disconnect() dragConnection = nil end
                    if moveConnection then moveConnection:Disconnect() moveConnection = nil end
                end
            end)
        end
    end)
    
    local buttonPositions
    if isMobile then
        local buttonPadding = 15 * scale
        local buttonSpacing = 15 * scale
        
        local buttonWidth = baseButtonWidth * scale
        local buttonHeight = baseButtonHeight * scale
        
        local leftX = buttonPadding
        local centerX = (finalWidth - buttonWidth) / 2
        local rightX = finalWidth - buttonWidth - buttonPadding
        
        local topY = buttonPadding
        local middleY = (finalHeight / 2) - (buttonHeight / 2) - 35 * scale
        local bottomY = finalHeight - buttonHeight - buttonPadding - 80 * scale
        
        buttonPositions = {
            FL = {x = leftX, y = topY, name = "FL"},
            Front = {x = centerX, y = topY, name = "Front"},
            FR = {x = rightX, y = topY, name = "FR"},
            Left = {x = leftX, y = middleY, name = "Left"},
            Jump = {x = centerX, y = middleY, name = "Jump"},
            Right = {x = rightX, y = middleY, name = "Right"},
            RL = {x = leftX, y = bottomY, name = "RL"},
            Rear = {x = centerX, y = bottomY, name = "Rear"},
            RR = {x = rightX, y = bottomY, name = "RR"}
        }
    else
        buttonPositions = {
            FL = {x = 10, y = 20, name = "FL"},
            FR = {x = 210, y = 20, name = "FR"},
            RL = {x = 10, y = 420, name = "RL"},
            RR = {x = 210, y = 420, name = "RR"},
            Rear = {x = 110, y = 530, name = "Rear"},
            Front = {x = 110, y = 110, name = "Front"},
            Jump = {x = 110, y = 220, name = "Jump"},
            Left = {x = 10, y = 310, name = "Left"},
            Right = {x = 210, y = 310, name = "Right"}
        }
    end
    
    for buttonId, data in pairs(buttonPositions) do
        local button = Instance.new("TextButton")
        button.Name = buttonId .. "Button"
        button.Parent = mainFrame
        button.Size = UDim2.new(0, baseButtonWidth * scale, 0, baseButtonHeight * scale)
        
        local posX = isMobile and data.x or (data.x * scale)
        local posY = isMobile and data.y or (data.y * scale)
        
        button.Position = UDim2.new(0, posX, 0, posY)
        button.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
        button.BorderSizePixel = 0
        button.Text = data.name
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextScaled = true
        button.Font = Enum.Font.SourceSansBold
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 10 * scale)
        buttonCorner.Parent = button
        
        hydraulicButtons[buttonId] = button
        
        button.MouseButton1Click:Connect(function()
            local wheelsToJump = {}
            local jumpDirection = "up"
            if buttonId == "FL" then
                wheelsToJump = {"FL"}
            elseif buttonId == "FR" then
                wheelsToJump = {"FR"}
            elseif buttonId == "RL" then
                wheelsToJump = {"RL"}
            elseif buttonId == "RR" then
                wheelsToJump = {"RR"}
            elseif buttonId == "Rear" then
                wheelsToJump = {"RL", "RR"}
            elseif buttonId == "Front" then
                wheelsToJump = {"FL", "FR"}
            elseif buttonId == "Jump" then
                wheelsToJump = {"FL", "FR", "RL", "RR"}
            elseif buttonId == "Left" then
                wheelsToJump = {"FL", "RL"}
                jumpDirection = "left"
            elseif buttonId == "Right" then
                wheelsToJump = {"FR", "RR"}
                jumpDirection = "right"
            end
            
            pcall(function()
                local carCollection = workspace:FindFirstChild("CarCollection")
                if not carCollection then return end
                
                local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
                if not playerModel then return end
                
                local carModel = playerModel:FindFirstChild("Car")
                if not carModel then return end
                
                local wheels = carModel:FindFirstChild("Wheels")
                if not wheels then return end
                
                local wheelData = {}
                
                for _, wheelName in ipairs(wheelsToJump) do
                    local wheel = wheels:FindFirstChild(wheelName)
                    if wheel then
                        local spring = wheel:FindFirstChild("Spring")
                        if spring and spring:IsA("SpringConstraint") then
                            local originalMaxLength = spring.MaxLength
                            local originalFreeLength = spring.FreeLength
                            local originalMinLength = spring.MinLength
                            local targetHeight = originalMaxLength + 2
                            
                            table.insert(wheelData, {
                                wheel = wheel,
                                spring = spring,
                                originalMaxLength = originalMaxLength,
                                originalFreeLength = originalFreeLength,
                                originalMinLength = originalMinLength,
                                targetHeight = targetHeight
                            })
                        end
                    end
                end
                
                for _, data in ipairs(wheelData) do
                    local wheelVelocity = Instance.new("BodyVelocity")
                    wheelVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    wheelVelocity.P = 5000
                    
                    if jumpDirection == "left" then
                        wheelVelocity.Velocity = Vector3.new(-20, 10, 0)
                    elseif jumpDirection == "right" then
                        wheelVelocity.Velocity = Vector3.new(20, 10, 0)
                    else
                        wheelVelocity.Velocity = Vector3.new(0, 20, 0)
                    end
                    
                    wheelVelocity.Parent = data.wheel
                end
                
                for _, data in ipairs(wheelData) do
                    data.spring.Stiffness = 1000000
                    data.spring.MaxLength = data.targetHeight
                    data.spring.FreeLength = data.targetHeight
                    data.spring.MinLength = data.targetHeight
                    data.spring.LimitsEnabled = true
                end
                
                task.wait(0.1)
                for _, data in ipairs(wheelData) do
                    local velocity = data.wheel:FindFirstChild("BodyVelocity")
                    if velocity then
                        velocity:Destroy()
                    end
                end
                
                local startTime = tick()
                local duration = 0.5
                
                local jumpConnection
                jumpConnection = game:GetService("RunService").Heartbeat:Connect(function()
                    local elapsed = tick() - startTime
                    local progress = math.min(elapsed / duration, 1)
                    
                    if progress >= 1 then
                        local returnStartTime = tick()
                        local returnDuration = 0.5
                        
                        local returnConnection
                        returnConnection = game:GetService("RunService").Heartbeat:Connect(function()
                            local returnElapsed = tick() - returnStartTime
                            local returnProgress = math.min(returnElapsed / returnDuration, 1)
                            
                            local easedReturnProgress = 1 - math.cos(returnProgress * math.pi / 2)
                            
                            for _, data in ipairs(wheelData) do
                                local currentReturnHeight = data.targetHeight - (data.targetHeight - data.originalMaxLength) * easedReturnProgress
                                
                                data.spring.MaxLength = currentReturnHeight
                                data.spring.FreeLength = currentReturnHeight
                                data.spring.MinLength = currentReturnHeight
                            end
                            
                            if returnProgress >= 1 then
                                for _, data in ipairs(wheelData) do
                                    data.spring.MaxLength = data.originalMaxLength
                                    data.spring.FreeLength = data.originalFreeLength
                                    data.spring.MinLength = data.originalMinLength
                                    data.spring.Stiffness = suspensionStiffness
                                end
                                
                                if returnConnection then
                                    returnConnection:Disconnect()
                                    returnConnection = nil
                                end
                            end
                        end)
                        
                        if jumpConnection then
                            jumpConnection:Disconnect()
                            jumpConnection = nil
                        end
                    end
                end)
            end)
        end)
    end
end

local function destroyHydraulicsGui()
    if hydraulicsGui then
        hydraulicsGui:Destroy()
        hydraulicsGui = nil
        hydraulicButtons = {}
    end
end

HydraulicsTab:CreateToggle({
    Name = "Hydraulic Jump Control",
    CurrentValue = false,
    Callback = function(Value)
        hydraulicsEnabled = Value
        
        if Value then
            createHydraulicsGui()
        else
            destroyHydraulicsGui()
        end
    end
})

HydraulicsTab:CreateToggle({
    Name = "MaybachPov",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startMaybachPov()
            Rayfield:Notify({Title = "MaybachPov", Content = "Activated!", Duration = 3, Image = 11567543471})
        else
            stopMaybachPov()
            Rayfield:Notify({Title = "MaybachPov", Content = "Deactivated!", Duration = 3, Image = 11567543659})
        end
    end
})

-- ===== PVP TAB =====
local PVPTab = Window:CreateTab("PVP", "sword")
PVPTab:CreateSection("PVP Settings")

PVPTab:CreateParagraph({
    Title = "Coming Soon!",
    Content = "PVP features are currently under development."
})

-- ===== CORE TAB =====
local CoreTab = Window:CreateTab("Core", "settings")
CoreTab:CreateSection("Teleportation")

CoreTab:CreateToggle({
    Name = "Auto Helicopter Escape",
    CurrentValue = false,
    Flag = "AutoHelicopterEscape",
    Callback = function(Value)
        if Value then
            local energyCoreSession = workspace:FindFirstChild("EnergyCore_Session")
            if energyCoreSession then
                local helicopterModel = energyCoreSession:FindFirstChild("Helicopter")
                if helicopterModel then
                    LocalPlayer.Character:SetPrimaryPartCFrame(helicopterModel.PrimaryPart.CFrame)
                    Rayfield:Notify({Title = "Auto Helicopter", Content = "Teleported to helicopter!", Duration = 3, Image = 11567543471})
                    
                    task.wait(2)
                    pcall(function()
                        local vim = game:GetService("VirtualInputManager")
                        if vim and vim.SendKeyEvent then
                            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.1)
                            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                            Rayfield:Notify({Title = "Auto Helicopter", Content = "E key pressed!", Duration = 2, Image = 11567543471})
                        end
                    end)
                else
                    Rayfield:Notify({Title = "Error", Content = "Helicopter not found!", Duration = 3, Image = 11567543659})
                end
            else
                Rayfield:Notify({Title = "Error", Content = "EnergyCore_Session not found!", Duration = 3, Image = 11567543659})
            end
        else
            Rayfield:Notify({Title = "Auto Helicopter", Content = "Disabled!", Duration = 3, Image = 11567543659})
        end
    end
})

CoreTab:CreateToggle({
    Name = "Auto Boat Escape",
    CurrentValue = false,
    Flag = "AutoBoatEscape",
    Callback = function(Value)
        if Value then
            local energyCoreSession = workspace:FindFirstChild("EnergyCore_Session")
            if energyCoreSession then
                local boatModel = energyCoreSession:FindFirstChild("Boat")
                if boatModel then
                    LocalPlayer.Character:SetPrimaryPartCFrame(boatModel.PrimaryPart.CFrame)
                    Rayfield:Notify({Title = "Auto Boat", Content = "Teleported to boat!", Duration = 3, Image = 11567543471})
                    
                    task.wait(2)
                    pcall(function()
                        local vim = game:GetService("VirtualInputManager")
                        if vim and vim.SendKeyEvent then
                            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.1)
                            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                            Rayfield:Notify({Title = "Auto Boat", Content = "E key pressed!", Duration = 2, Image = 11567543471})
                        end
                    end)
                else
                    Rayfield:Notify({Title = "Error", Content = "Boat not found!", Duration = 3, Image = 11567543659})
                end
            else
                Rayfield:Notify({Title = "Error", Content = "EnergyCore_Session not found!", Duration = 3, Image = 11567543659})
            end
        else
            Rayfield:Notify({Title = "Auto Boat", Content = "Disabled!", Duration = 3, Image = 11567543659})
        end
    end
})

-- ===== AUTOFARM TAB =====
local AutofarmTab = Window:CreateTab("Autofarm", "car")
AutofarmTab:CreateSection("AutoFarm Settings")

local autofarmEnabled = false
local spawnTimerConnection = nil

AutofarmTab:CreateToggle({
    Name = "AutoFarm",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            autofarmEnabled = true
            
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                if vim and vim.SendKeyEvent then
                    vim:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                    task.wait(0.1)
                    vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                    Rayfield:Notify({Title = "AutoFarm", Content = "R key triggered!", Duration = 3, Image = 11567543471})
                end
            end)
            
            local spawnTimer = LocalPlayer:FindFirstChild("SpawnTimer")
            if spawnTimer and spawnTimer:IsA("NumberValue") then
                spawnTimerConnection = spawnTimer:GetPropertyChangedSignal("Value"):Connect(function()
                    if autofarmEnabled then
                        pcall(function()
                            local vim = game:GetService("VirtualInputManager")
                            if vim and vim.SendKeyEvent then
                                local fKeySpamCount = 0
                                local maxFSpam = 100
                                
                                local function spamFKey()
                                    if not autofarmEnabled or fKeySpamCount >= maxFSpam then return end
                                    
                                    vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                                    task.wait(0.125)
                                    vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                                    fKeySpamCount = fKeySpamCount + 1
                                    
                                    task.spawn(spamFKey)
                                end
                                
                                spamFKey()
                            end
                            
                            local carCollection = workspace:FindFirstChild("CarCollection")
                            if not carCollection then return end
                            
                            local playerModel = carCollection:FindFirstChild(LocalPlayer.Name)
                            if not playerModel then return end
                            
                            local carModel = playerModel:FindFirstChild("Car")
                            if not carModel then return end
                            
                            local bodyModel = carModel:FindFirstChild("Body")
                            if not bodyModel then return end
                            
                            local hitBoxes = bodyModel:FindFirstChild("HitBoxes")
                            if not hitBoxes then return end
                            
                            local mainPart = hitBoxes:FindFirstChild("Main")
                            if not mainPart then return end
                            
                            local assemblyVelocity = mainPart.AssemblyLinearVelocity
                            local targetY = -1111
                            local currentY = assemblyVelocity.Y
                            local steps = 20
                            local stepSize = (targetY - currentY) / steps
                            
                            for i = 1, steps do
                                local newY = currentY + (stepSize * i)
                                mainPart.AssemblyLinearVelocity = Vector3.new(assemblyVelocity.X, newY, assemblyVelocity.Z)
                                task.wait(0.01)
                            end
                            
                            mainPart.AssemblyLinearVelocity = Vector3.new(assemblyVelocity.X, targetY, assemblyVelocity.Z)
                            
                            local trailerModel = carModel:FindFirstChild("Trailer")
                            if trailerModel then
                                local trailerMain = trailerModel:FindFirstChild("Main")
                                if trailerMain then
                                    trailerMain.AssemblyLinearVelocity = Vector3.new(assemblyVelocity.X, targetY, assemblyVelocity.Z)
                                end
                            end
                        end)
                    end
                    
                    if spawnTimer.Value == 0 then
                        pcall(function()
                            local vim = game:GetService("VirtualInputManager")
                            if vim and vim.SendKeyEvent then
                                vim:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                                task.wait(0.1)
                                vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                                Rayfield:Notify({Title = "AutoFarm", Content = "SpawnTimer = 0, R key pressed!", Duration = 3, Image = 11567543471})
                            end
                        end)
                    end
                    
                    if spawnTimer.Value == 20 and suspensionEnabled then
                        pcall(function()
                            updateSuspensionValues()
                            updateCamberValues()
                            updateTrackWidthValues()
                        end)
                    end
                end)
            end
        else
            autofarmEnabled = false
            if spawnTimerConnection then
                spawnTimerConnection:Disconnect()
                spawnTimerConnection = nil
            end
            
            Rayfield:Notify({Title = "AutoFarm", Content = "Disabled!", Duration = 3, Image = 11567543659})
        end
    end
})

AutofarmTab:CreateButton({
    Name = "Simulate All Button Presses",
    Callback = function()
        pcall(function()
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local playerGui = character:WaitForChild("PlayerGui")
            local dealershipGui = playerGui:FindFirstChild("Dealership screen")
            
            if dealershipGui then
                local bottomBar = dealershipGui:FindFirstChild("BottomBar")
                if bottomBar then
                    local holder = bottomBar:FindFirstChild("Holder")
                    if holder then
                        local nextButton = holder:FindFirstChild("Next")
                        local previousButton = holder:FindFirstChild("Previous")
                        local spawnButton = holder:FindFirstChild("Spawn")
                        local vim = game:GetService("VirtualInputManager")
                        
                        if nextButton and previousButton and spawnButton then
                            local nextButtonPos = nextButton.AbsolutePosition
                            local previousButtonPos = previousButton.AbsolutePosition
                            local spawnButtonPos = spawnButton.AbsolutePosition
                            local buttonSize = (nextButton.AbsoluteSize + previousButton.AbsoluteSize + spawnButton.AbsoluteSize) / 3
                            
                            local buttons = {
                                {name = "Next", pos = nextButtonPos, button = nextButton},
                                {name = "Previous", pos = previousButtonPos, button = previousButton},
                                {name = "Spawn", pos = spawnButtonPos, button = spawnButton}
                            }
                            
                            for i, buttonData in ipairs(buttons) do
                                local centerX = buttonData.pos.X + buttonSize.X / 2
                                local centerY = buttonData.pos.Y + buttonSize.Y / 2
                                
                                vim:SendMouseMoveEvent(centerX, centerY)
                                task.wait(0.1)
                                
                                vim:SendMouseButtonEvent(1, true, game)
                                task.wait(0.1)
                                vim:SendMouseButtonEvent(1, false, game)
                                
                                Rayfield:Notify({Title = "Button Pressed", Content = buttonData.name .. " pressed!", Duration = 2, Image = 11567543471})
                                
                                if i < #buttons then
                                    task.wait(1)
                                end
                            end
                        else
                            Rayfield:Notify({Title = "Not Found", Content = "Some buttons not found!", Duration = 3, Image = 11567543659})
                        end
                    else
                        Rayfield:Notify({Title = "Not Found", Content = "GUI Holder not found!", Duration = 3, Image = 11567543659})
                    end
                else
                    Rayfield:Notify({Title = "Not Found", Content = "GUI BottomBar not found!", Duration = 3, Image = 11567543659})
                end
            else
                Rayfield:Notify({Title = "Not Found", Content = "Dealership GUI not found!", Duration = 3, Image = 11567543659})
            end
        end)
    end
})

-- ===== TELEPORT TAB =====
local TeleportTab = Window:CreateTab("Teleport", "map")

TeleportTab:CreateSection("Map Locations")

TeleportTab:CreateButton({
    Name = "Teleport to Ridge Rock Races",
    Callback = function()
        local char = LocalPlayer.Character
        if char and char.PrimaryPart then
            char:SetPrimaryPartCFrame(CFrame.new(-4884, 78, -5192))
            Rayfield:Notify({Title = "Teleport", Content = "Teleported to Ridge Rock Races!", Duration = 3, Image = 11567543471})
        end
    end
})

TeleportTab:CreateButton({
    Name = "Teleport to Volcano",
    Callback = function()
        local char = LocalPlayer.Character
        if char and char.PrimaryPart then
            char:SetPrimaryPartCFrame(CFrame.new(2569, 1845, 4997))
            Rayfield:Notify({Title = "Teleport", Content = "Teleported to Volcano!", Duration = 3, Image = 11567543471})
        end
    end
})

TeleportTab:CreateSection("Vehicles")

TeleportTab:CreateButton({
    Name = "Teleport to Helicopter",
    Callback = function()
        local energyCoreSession = workspace:FindFirstChild("EnergyCore_Session")
        if energyCoreSession then
            local helicopterModel = energyCoreSession:FindFirstChild("Helicopter")
            if helicopterModel and helicopterModel.PrimaryPart then
                LocalPlayer.Character:SetPrimaryPartCFrame(helicopterModel.PrimaryPart.CFrame)
                Rayfield:Notify({Title = "Teleport", Content = "Teleported to Helicopter!", Duration = 3, Image = 11567543471})
            else
                Rayfield:Notify({Title = "Error", Content = "Helicopter not found!", Duration = 3, Image = 11567543659})
            end
        else
            Rayfield:Notify({Title = "Error", Content = "EnergyCore_Session not found!", Duration = 3, Image = 11567543659})
        end
    end
})

TeleportTab:CreateButton({
    Name = "Teleport to Boat",
    Callback = function()
        local energyCoreSession = workspace:FindFirstChild("EnergyCore_Session")
        if energyCoreSession then
            local boatModel = energyCoreSession:FindFirstChild("Boat")
            if boatModel and boatModel.PrimaryPart then
                LocalPlayer.Character:SetPrimaryPartCFrame(boatModel.PrimaryPart.CFrame)
                Rayfield:Notify({Title = "Teleport", Content = "Teleported to Boat!", Duration = 3, Image = 11567543471})
            else
                Rayfield:Notify({Title = "Error", Content = "Boat not found!", Duration = 3, Image = 11567543659})
            end
        else
            Rayfield:Notify({Title = "Error", Content = "EnergyCore_Session not found!", Duration = 3, Image = 11567543659})
        end
    end
})

-- ===== WEBHOOK TAB =====
local WebhookTab = Window:CreateTab("Webhook", "bell")
WebhookTab:CreateSection("Discord Notifications")

local webhookUrl = ""
local webhookEnabled = false
local webhookInterval = 5
local webhookTask = nil

local function sendWebhook()
    if not webhookEnabled or webhookUrl == "" then return end
    
    local money = "0"
    local parts = "0"
    local platinum = "0"
    
    pcall(function()
        if LocalPlayer:FindFirstChild("leaderstats") then
            if LocalPlayer.leaderstats:FindFirstChild("Money") then 
                money = tostring(LocalPlayer.leaderstats.Money.Value) 
            end
            if LocalPlayer.leaderstats:FindFirstChild("Parts") then 
                parts = tostring(LocalPlayer.leaderstats.Parts.Value) 
            end
        end
        
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local platinaLabel = playerGui:FindFirstChild("Currencies")
                and playerGui.Currencies:FindFirstChild("Currencies")
                and playerGui.Currencies.Currencies:FindFirstChild("Background")
                and playerGui.Currencies.Currencies.Background:FindFirstChild("Platina")
                and playerGui.Currencies.Currencies.Background.Platina:FindFirstChild("Amount")
            
            if platinaLabel then
                platinum = platinaLabel.Text
            end
        end
    end)

    local data = {
        ["embeds"] = {{
            ["title"] = "🏆 Farm Status Update",
            ["description"] = "Current stats for **" .. LocalPlayer.Name .. "**",
            ["color"] = tonumber(0x00FF00),
            ["fields"] = {
                {["name"] = "💵 Money", ["value"] = money, ["inline"] = true},
                {["name"] = "⚙️ Parts", ["value"] = parts, ["inline"] = true},
                {["name"] = "💎 Platina", ["value"] = platinum, ["inline"] = true}
            },
            ["footer"] = {["text"] = "Chipzter Gui Autofarm • " .. os.date("%H:%M:%S")}
        }}
    }

    local headers = {["Content-Type"] = "application/json"}
    
    local requestFunc = syn and syn.request or request or http and http.request

    if requestFunc then
        pcall(function()
            requestFunc({
                Url = webhookUrl,
                Method = "POST",
                Headers = headers,
                Body = HttpService:JSONEncode(data)
            })
        end)
    end
end

local function toggleWebhookLoop()
    if webhookTask then 
        task.cancel(webhookTask) 
        webhookTask = nil
    end
    
    if webhookEnabled and webhookUrl ~= "" then
        webhookTask = task.spawn(function()
            while webhookEnabled do
                sendWebhook()
                task.wait(webhookInterval * 60)
            end
        end)
    end
end

WebhookTab:CreateInput({
    Name = "Discord Webhook URL",
    PlaceholderText = "Paste your webhook URL here...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        webhookUrl = Text
        if webhookEnabled then
            toggleWebhookLoop()
        end
    end,
})

WebhookTab:CreateSlider({
    Name = "Update Interval (Minutes)",
    Range = {1, 60},
    Increment = 1,
    CurrentValue = 5,
    Flag = "WebhookInterval",
    Callback = function(Value)
        webhookInterval = Value
        if webhookEnabled then
            toggleWebhookLoop()
        end
    end,
})

WebhookTab:CreateToggle({
    Name = "Enable Notifications",
    CurrentValue = false,
    Flag = "WebhookToggle",
    Callback = function(Value)
        if Value and webhookUrl == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a webhook URL first!", Duration = 3, Image = 11567543659})
            webhookEnabled = false
            return
        end
        
        webhookEnabled = Value
        
        if Value then
            Rayfield:Notify({Title = "Webhook Started", Content = "Sending updates every " .. webhookInterval .. " minutes.", Duration = 3, Image = 11567543471})
            task.spawn(sendWebhook)
        else
            Rayfield:Notify({Title = "Webhook Stopped", Content = "Notifications disabled.", Duration = 3, Image = 11567543659})
        end
        
        toggleWebhookLoop()
    end,
})

WebhookTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        if webhookUrl ~= "" then
            sendWebhook()
            Rayfield:Notify({Title = "Sent", Content = "Test webhook sent to Discord!", Duration = 3, Image = 11567543471})
        else
            Rayfield:Notify({Title = "Error", Content = "Enter a URL first!", Duration = 3, Image = 11567543659})
        end
    end,
})

-- ===== KEYBOARD SHORTCUTS =====
local UserInputService = game:GetService("UserInputService")
local refreshConnection

local function refreshAllSettings()
    if suspensionEnabled then
        updateSuspensionValues()
        updateCamberValues()
        updateTrackWidthValues()
        
        startStiffnessGuard()
        startHighPrioritySuspension()
    end
    
    if hydraulicsEnabled then
        destroyHydraulicsGui()
        task.wait(0.1)
        createHydraulicsGui()
    end
end

refreshConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.R then
        refreshAllSettings()
    end
end)

game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
    if child.Name == "Rayfield" then
        if refreshConnection then
            refreshConnection:Disconnect()
            refreshConnection = nil
        end
    end
end)
