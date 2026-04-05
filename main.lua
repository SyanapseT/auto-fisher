-- ================================================
-- Auto Fish + QTE + 自动买/用 Bait + UI 完整版
-- ================================================

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = false,
    CastDelay = 2,
    RecastDelay = 3,
    MaxDist = 50,
    CastY = 0.3,
}

local savedPos = nil
local fishCount = 0

-- ================================================
-- 基础工具
-- ================================================

local function clickAt(yRatio)
    local cam = workspace.CurrentCamera
    local cx = cam.ViewportSize.X / 2
    local cy = cam.ViewportSize.Y * yRatio
    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
end

local function cast() clickAt(Config.CastY) end
local function reel() clickAt(0.5) end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleportBack()
    if not savedPos then return end
    local root = getRoot()
    if not root then return end
    if (root.Position - savedPos).Magnitude > 3 then
        root.CFrame = CFrame.new(savedPos)
    end
end

-- ================================================
-- Bait 检测、购买、使用
-- ================================================

local function findBait(parent)
    if not parent then return nil end
    for _, v in ipairs(parent:GetChildren()) do
        if v:IsA("Tool") and v.Name:lower():find("bait") then
            return v
        end
    end
    return nil
end

local function hasBait()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    return findBait(char) or findBait(backpack)
end

local function buyBait()
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("DialogueRemote")
    if not remote then return false end

    local daniel = nil
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Daniel" and v:IsA("Model") then
            daniel = v
            break
        end
    end
    if not daniel then return false end

    remote:FireServer("Action", "Buy_Bait", daniel)
    print("[AutoFish] 已购买 Bait")
    task.wait(1)
    return true
end

local function useBait()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local bait = findBait(char) or findBait(backpack)
    if not bait then return false end

    if bait.Parent ~= char then
        bait.Parent = char
        task.wait(0.5)
    end

    print("[AutoFish] 使用 Bait")
    clickAt(0.5)
    task.wait(1)
    return true
end

-- ================================================
-- 鱼竿检测与装备
-- ================================================

local function isRod(item)
    if not item:IsA("Tool") then return false end
    local name = item.Name:lower()
    return name:find("rod") or name:find("fish")
end

local function hasRodEquipped()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, v in ipairs(char:GetChildren()) do
        if isRod(v) then return true end
    end
    return false
end

local function equipRod()
    if hasRodEquipped() then return true end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    for _, v in ipairs(backpack:GetChildren()) do
        if isRod(v) then
            print("[AutoFish] 装备鱼竿: " .. v.Name)
            v.Parent = LocalPlayer.Character
            task.wait(0.5)
            return hasRodEquipped()
        end
    end
    return false
end

-- ================================================
-- 浮标扫描
-- ================================================

local function scanBobber()
    local root = getRoot()
    if not root then return nil end

    local best = nil
    local bestDist = math.huge

    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "Part" then
            local vol = v.Size.X * v.Size.Y * v.Size.Z
            if vol < 5 then
                local dist = (v.Position - root.Position).Magnitude
                if dist < Config.MaxDist and dist < bestDist then
                    best = v
                    bestDist = dist
                end
            end
        end
    end

    return best
end

-- ================================================
-- 等待 FishBite 上钩
-- ================================================

local function waitForBite(bobber)
    local bitten = false

    local conn = bobber.ChildAdded:Connect(function(child)
        if child.Name == "FishBite" then
            bitten = true
        end
    end)

    while Config.Enabled do
        if not bobber.Parent then conn:Disconnect() return false end
        if bitten then
            print("[AutoFish] FishBite! 上钩!")
            conn:Disconnect()
            return true
        end
        teleportBack()
        task.wait(0.05)
    end

    conn:Disconnect()
    return false
end

-- ================================================
-- QTE 自动处理
-- ================================================

local keyMap = {
    A = Enum.KeyCode.A, B = Enum.KeyCode.B, C = Enum.KeyCode.C,
    D = Enum.KeyCode.D, E = Enum.KeyCode.E, F = Enum.KeyCode.F,
    G = Enum.KeyCode.G, H = Enum.KeyCode.H, I = Enum.KeyCode.I,
    J = Enum.KeyCode.J, K = Enum.KeyCode.K, L = Enum.KeyCode.L,
    M = Enum.KeyCode.M, N = Enum.KeyCode.N, O = Enum.KeyCode.O,
    P = Enum.KeyCode.P, Q = Enum.KeyCode.Q, R = Enum.KeyCode.R,
    S = Enum.KeyCode.S, T = Enum.KeyCode.T, U = Enum.KeyCode.U,
    V = Enum.KeyCode.V, W = Enum.KeyCode.W, X = Enum.KeyCode.X,
    Y = Enum.KeyCode.Y, Z = Enum.KeyCode.Z,
}

local function pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function handleQTE()
    local gui = LocalPlayer.PlayerGui
    local mashing = gui:FindFirstChild("MashingSystem")
    if not mashing then return end

    local container = mashing:FindFirstChild("Container")
    if not container or not container.Visible then return end

    local circle = container:FindFirstChild("Circle")
    local barBG = container:FindFirstChild("BarBG")
    if not circle or not barBG then return end

    local keyLabel = circle:FindFirstChild("KeyLabel")
    local barFill = barBG:FindFirstChild("BarFill")
    if not keyLabel or not barFill then return end

    print("[QTE] 检测到QTE!")

    while container.Visible and barFill.Size.X.Scale < 1 do
        local key = keyLabel.Text:upper()
        local keyCode = keyMap[key]
        if keyCode then
            pressKey(keyCode)
        end
        teleportBack()
        task.wait(0.05)
    end

    print("[QTE] 完成!")
end

task.spawn(function()
    while true do
        handleQTE()
        task.wait(0.1)
    end
end)

-- ================================================
-- GUI
-- ================================================

pcall(function()
    local old = game:GetService("CoreGui"):FindFirstChild("AutoFishGui")
    if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFishGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 130)
frame.Position = UDim2.new(0, 10, 0.5, -65)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Auto Fisher"
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = frame

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, 0, 0, 22)
countLabel.Position = UDim2.new(0, 0, 0, 28)
countLabel.BackgroundTransparency = 1
countLabel.Text = "已钓: 0 条"
countLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
countLabel.TextSize = 14
countLabel.Font = Enum.Font.Gotham
countLabel.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 22)
statusLabel.Position = UDim2.new(0, 0, 0, 50)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "已停止"
statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = frame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.85, 0, 0, 30)
toggleBtn.Position = UDim2.new(0.075, 0, 0, 78)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 40)
toggleBtn.Text = "▶ 开始钓鱼"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = frame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local credit = Instance.new("TextLabel")
credit.Size = UDim2.new(1, -10, 0, 14)
credit.Position = UDim2.new(0, 5, 1, -16)
credit.BackgroundTransparency = 1
credit.Text = "你爸制作"
credit.TextColor3 = Color3.fromRGB(100, 100, 100)
credit.TextSize = 10
credit.Font = Enum.Font.Gotham
credit.TextXAlignment = Enum.TextXAlignment.Right
credit.Parent = frame

local function updateStatus(text)
    statusLabel.Text = text
end

local function toggleFishing()
    Config.Enabled = not Config.Enabled
    if Config.Enabled then
        local root = getRoot()
        if root then
            savedPos = root.Position
        end
        toggleBtn.Text = "■ 停止钓鱼"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        statusLabel.Text = "运行中"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        task.spawn(mainLoop)
    else
        toggleBtn.Text = "▶ 开始钓鱼"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 40)
        statusLabel.Text = "已停止"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end

toggleBtn.MouseButton1Click:Connect(toggleFishing)

-- ================================================
-- 钓鱼主循环
-- ================================================

function mainLoop()
    print("[AutoFish] 启动")

    while Config.Enabled do
        if not getRoot() then
            task.wait(1)
            continue
        end

        teleportBack()

        -- 步骤1：Bait
        if not hasBait() then
            updateStatus("购买 Bait...")
            buyBait()
        end
        if hasBait() then
            updateStatus("使用 Bait...")
            useBait()
        end

        -- 步骤2：鱼竿
        if not hasRodEquipped() then
            updateStatus("装备鱼竿...")
            if not equipRod() then
                updateStatus("无鱼竿!")
                task.wait(2)
                continue
            end
        end

        -- 步骤3：抛竿
        local bobber = scanBobber()
        if not bobber then
            updateStatus("抛竿...")
            cast()
            task.wait(Config.CastDelay)

            bobber = scanBobber()
            if not bobber then
                task.wait(0.5)
                continue
            end
        end

        -- 步骤4：等上钩
        updateStatus("等待上钩...")
        local bitten = waitForBite(bobber)
        if not bitten then
            task.wait(1)
            continue
        end

        -- 步骤5：收竿
        updateStatus("收竿!")
        reel()
        task.wait(0.5)
        teleportBack()

        fishCount = fishCount + 1
        countLabel.Text = "已钓: " .. fishCount .. " 条"
        updateStatus("第 " .. fishCount .. " 条!")

        task.wait(Config.RecastDelay)
    end

    print("[AutoFish] 已停止")
end

-- F6 快捷键
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        toggleFishing()
    end
end)

print("[AutoFish] 已加载")