-- ================================================
-- Auto Fish + QTE + 自动买/用 Bait + UI
-- 你爸制作
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
-- Bait：购买 + 装备 + 使用（一步到位）
-- ================================================

local function prepareBait()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    -- 找 bait
    local bait = nil
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find("bait") then bait = v break end
        end
    end
    if not bait and backpack then
        for _, v in ipairs(backpack:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find("bait") then bait = v break end
        end
    end

    -- 没有就买
    if not bait then
        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("DialogueRemote")
        local daniel = nil
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "Daniel" and v:IsA("Model") then daniel = v break end
        end
        if remote and daniel then
            remote:FireServer("Action", "Buy_Bait", daniel)
            print("[AutoFish] 购买 Bait")
            task.wait(1)
        end

        -- 重新找
        if backpack then
            for _, v in ipairs(backpack:GetChildren()) do
                if v:IsA("Tool") and v.Name:lower():find("bait") then bait = v break end
            end
        end
    end

    if not bait then return end

    -- 装备到手上
    if bait.Parent ~= char then
        bait.Parent = char
        task.wait(0.5)
    end

    -- 点击使用
    print("[AutoFish] 使用 Bait")
    clickAt(0.5)
    task.wait(1)
end

-- ================================================
-- 鱼竿装备
-- ================================================

local function equipRod()
    local char = LocalPlayer.Character
    if not char then return false end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and v.Name:lower():find("rod") then return true end
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end

    for _, v in ipairs(backpack:GetChildren()) do
        if v:IsA("Tool") and v.Name:lower():find("rod") then
            print("[AutoFish] 装备鱼竿")
            v.Parent = char
            task.wait(0.5)
            return true
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
-- 等待 FishBite
-- ================================================

local function waitForBite(bobber)
    local bitten = false

    local conn = bobber.ChildAdded:Connect(function(child)
        if child.Name == "FishBite" then bitten = true end
    end)

    while Config.Enabled do
        if not bobber.Parent then conn:Disconnect() return false end
        if bitten then
            print("[AutoFish] 上钩!")
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

task.spawn(function()
    while true do
        pcall(function()
            local gui = LocalPlayer.PlayerGui
            local container = gui:FindFirstChild("MashingSystem")
                and gui.MashingSystem:FindFirstChild("Container")
            if not container or not container.Visible then return end

            local keyLabel = container:FindFirstChild("Circle")
                and container.Circle:FindFirstChild("KeyLabel")
            local barFill = container:FindFirstChild("BarBG")
                and container.BarBG:FindFirstChild("BarFill")
            if not keyLabel or not barFill then return end

            print("[QTE] 检测到!")
            while container.Visible and barFill.Size.X.Scale < 1 do
                local kc = keyMap[keyLabel.Text:upper()]
                if kc then
                    VirtualInputManager:SendKeyEvent(true, kc, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, kc, false, game)
                end
                task.wait(0.05)
            end
            print("[QTE] 完成!")
        end)
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

local function lbl(text, y, color, size)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 20)
    l.Position = UDim2.new(0, 5, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.TextSize = size or 12
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = frame
    return l
end

lbl("Auto Fisher", 4, Color3.fromRGB(255, 200, 50), 16)
local countLabel = lbl("已钓: 0 条", 28, Color3.fromRGB(255, 220, 100), 14)
local statusLabel = lbl("已停止", 50, Color3.fromRGB(255, 100, 100))

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.85, 0, 0, 28)
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

-- ================================================
-- 主循环
-- ================================================

local function mainLoop()
    while Config.Enabled do
        if not getRoot() then task.wait(1) continue end
        teleportBack()

        -- 每轮：用 bait → 装备鱼竿 → 抛竿 → 等上钩 → 收竿
        statusLabel.Text = "准备 Bait..."
        prepareBait()

        statusLabel.Text = "装备鱼竿..."
        if not equipRod() then
            statusLabel.Text = "无鱼竿!"
            task.wait(2)
            continue
        end

        local bobber = scanBobber()
        if not bobber then
            statusLabel.Text = "抛竿..."
            cast()
            task.wait(Config.CastDelay)
            bobber = scanBobber()
            if not bobber then task.wait(0.5) continue end
        end

        statusLabel.Text = "等待上钩..."
        if not waitForBite(bobber) then task.wait(1) continue end

        statusLabel.Text = "收竿!"
        reel()
        task.wait(0.5)
        teleportBack()

        fishCount = fishCount + 1
        countLabel.Text = "已钓: " .. fishCount .. " 条"
        statusLabel.Text = "第 " .. fishCount .. " 条!"

        task.wait(Config.RecastDelay)
    end
end

local function toggle()
    Config.Enabled = not Config.Enabled
    if Config.Enabled then
        local root = getRoot()
        if root then savedPos = root.Position end
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

toggleBtn.MouseButton1Click:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)

print("[AutoFish] 已加载，按 F6 或点击按钮开始")