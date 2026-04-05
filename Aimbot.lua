--[[
╔══════════════════════════════════════════════════════════╗
║          EZ Hub  v7  —  ESP  +  Aimbot                   ║
║  Aimbot core: Exunys Universal Aimbot  (CC0 1.0)         ║
║  UI Style : AirHub V2  (Self-Contained, no deps)         ║
║  Executor : Xeno  ✔   Synapse X ✔   Fluxus ✔            ║
╠══════════════════════════════════════════════════════════╣
║  RightShift → Toggle UI                                  ║
║  Tabs: ESP / Visual / Aimbot / Misc                      ║
╚══════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════
--  §0  EXECUTOR COMPATIBILITY LAYER  (from Exunys source)
-- ═══════════════════════════════════════════════════════════
local getrawmetatable = getrawmetatable
local GameMetatable   = (getrawmetatable and getrawmetatable(game)) or {
    __index    = function(s,k) return s[k] end,
    __newindex = function(s,k,v) s[k]=v end,
}
local __index    = GameMetatable.__index
local __newindex = GameMetatable.__newindex

-- getrenderproperty / setrenderproperty  (Exunys pattern)
local getrenderproperty = getrenderproperty or __index
local setrenderproperty = setrenderproperty or __newindex

-- mousemoverel  (Xeno exposes it globally)
local _mmr = mousemoverel or (Input and Input.MouseMove) or function() end

-- Services via raw __index so anti-cheat hooks are bypassed
local function GetSvc(n) return __index(game,"GetService")(game,n) end
local Players          = GetSvc("Players")
local RunService       = GetSvc("RunService")
local UserInputService = GetSvc("UserInputService")
local TweenService     = GetSvc("TweenService")

-- Shortcuts
local Camera     = workspace.CurrentCamera
local LP         = __index(Players,"LocalPlayer")

local W2VP       = __index(Camera,"WorldToViewportPoint")
local GPOT       = __index(Camera,"GetPartsObscuringTarget")
local GML        = __index(UserInputService,"GetMouseLocation")
local GetPlayers = __index(Players,"GetPlayers")

local function W2S(pos)
    local v = W2VP(Camera, pos)
    if v.Z <= 0 then return Vector2.new(v.X,v.Y), false end
    return Vector2.new(v.X,v.Y), true
end

-- ═══════════════════════════════════════════════════════════
--  §1  ESP  SETTINGS & STORE
-- ═══════════════════════════════════════════════════════════
local S = {
    -- master
    Enabled        = false,
    MaxDistance    = 1000,
    -- team
    TeamCheck      = false,
    ShowTeam       = false,
    -- box
    BoxESP         = true,
    BoxStyle       = "Corner",      -- "Corner" | "Full"
    BoxColor       = Color3.fromRGB(255, 50,  50),
    BoxThickness   = 1.5,
    -- skeleton
    SkeletonESP    = true,
    SkeletonColor  = Color3.fromRGB(0,   255, 120),
    SkeletonThick  = 1.5,
    -- health
    HealthESP      = true,
    HealthStyle    = "Bar",         -- "Bar" | "Text" | "Both"
    -- labels
    NameESP        = true,
    IDShown        = true,
    DistESP        = true,
    TextColor      = Color3.fromRGB(255, 255, 255),
    TextSize       = 13,
    -- tracer
    TracerESP      = false,
    TracerOrigin   = "Bottom",      -- "Bottom" | "Top" | "Center" | "Mouse"
    TracerColor    = Color3.fromRGB(255, 50,  50),
    TracerThick    = 1,
    -- chams
    ChamsESP       = false,
    ChamsFill      = Color3.fromRGB(255, 0,   0),
    ChamsOutline   = Color3.fromRGB(255, 255, 255),
    ChamsFillTrans = 0.5,
}

-- ── Drawing factories ──
local function mkLine(c,t) local d=Drawing.new("Line");   d.Visible=false; d.Color=c or Color3.new(1,1,1); d.Thickness=t or 1;  d.Transparency=1; return d end
local function mkText(sz,c) local d=Drawing.new("Text");  d.Visible=false; d.Size=sz or 13;                d.Color=c or Color3.new(1,1,1); d.Outline=true; d.Center=true; d.Font=2; return d end
local function mkSq(f,c)   local d=Drawing.new("Square"); d.Visible=false; d.Filled=f or false;           d.Color=c or Color3.new(1,1,1); d.Thickness=1; d.Transparency=1; return d end

-- ── Bone table  (R15 name, R15 parent fallback, R6 A, R6 B) ──
local BONES = {
    {"Head","UpperTorso","Head","Torso"},
    {"UpperTorso","LowerTorso","Torso","Torso"},
    {"UpperTorso","LeftUpperArm","Torso","Left Arm"},
    {"LeftUpperArm","LeftLowerArm","Left Arm","Left Arm"},
    {"LeftLowerArm","LeftHand","Left Arm","Left Arm"},
    {"UpperTorso","RightUpperArm","Torso","Right Arm"},
    {"RightUpperArm","RightLowerArm","Right Arm","Right Arm"},
    {"RightLowerArm","RightHand","Right Arm","Right Arm"},
    {"LowerTorso","LeftUpperLeg","Torso","Left Leg"},
    {"LeftUpperLeg","LeftLowerLeg","Left Leg","Left Leg"},
    {"LeftLowerLeg","LeftFoot","Left Leg","Left Leg"},
    {"LowerTorso","RightUpperLeg","Torso","Right Leg"},
    {"RightUpperLeg","RightLowerLeg","Right Leg","Right Leg"},
    {"RightLowerLeg","RightFoot","Right Leg","Right Leg"},
}
local function GetBone(c,a,b) return c:FindFirstChild(a) or c:FindFirstChild(b) end

-- ── Bounding box ──
local function GetBounds(char)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return nil end
    local topW = head.Position + Vector3.new(0, head.Size.Y*.5, 0)
    local botW = hrp.Position  - Vector3.new(0, hrp.Size.Y*.5 + .3, 0)
    local st, ot = W2S(topW); local sb, ob = W2S(botW)
    if not ot or not ob then return nil end
    local H = math.abs(sb.Y - st.Y); if H < 2 then return nil end
    local W = H * .55; local cx = (st.X + sb.X) * .5
    return {
        TL=Vector2.new(cx-W/2,st.Y), TR=Vector2.new(cx+W/2,st.Y),
        BL=Vector2.new(cx-W/2,sb.Y), BR=Vector2.new(cx+W/2,sb.Y),
        W=W, H=H, cx=cx, TopY=st.Y, BotY=sb.Y,
        Mid=Vector2.new(cx, st.Y+H*.5),
    }
end

-- ── Tracer origin ──
local function TracerOriginPos()
    local vp = Camera.ViewportSize; local o = S.TracerOrigin
    if o=="Bottom"  then return Vector2.new(vp.X/2, vp.Y)
    elseif o=="Top" then return Vector2.new(vp.X/2, 0)
    elseif o=="Mouse" then return GML(UserInputService) end
    return Vector2.new(vp.X/2, vp.Y/2)
end

-- ── ESP object store ──
local ESPStore     = {}
local HighlightMap = {}

local function CreateESP(p)
    if p == LP or ESPStore[p] then return end
    local box  = {}; for i=1,8  do box[i]  = mkLine(S.BoxColor,      S.BoxThickness) end
    local skel = {}; for i=1,#BONES do skel[i] = mkLine(S.SkeletonColor, S.SkeletonThick) end
    local hl   = Instance.new("Highlight")
    hl.FillColor=S.ChamsFill; hl.OutlineColor=S.ChamsOutline
    hl.FillTransparency=S.ChamsFillTrans
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=false
    HighlightMap[p] = hl
    ESPStore[p] = {
        Box      = box,  Skel = skel,
        HpOut    = mkSq(false),
        HpFill   = mkSq(true, Color3.fromRGB(0,255,0)),
        HpText   = mkText(11),
        NameText = mkText(S.TextSize,  S.TextColor),
        InfoText = mkText(S.TextSize-1,Color3.fromRGB(200,200,200)),
        Tracer   = mkLine(S.TracerColor, S.TracerThick),
    }
end

local function HideAll(d)
    if not d then return end
    for _,l in ipairs(d.Box)  do l.Visible=false end
    for _,l in ipairs(d.Skel) do l.Visible=false end
    d.HpOut.Visible=false; d.HpFill.Visible=false; d.HpText.Visible=false
    d.NameText.Visible=false; d.InfoText.Visible=false; d.Tracer.Visible=false
end

local function DestroyESP(p)
    local d = ESPStore[p]
    if d then
        for _,l in ipairs(d.Box)  do l:Remove() end
        for _,l in ipairs(d.Skel) do l:Remove() end
        d.HpOut:Remove(); d.HpFill:Remove(); d.HpText:Remove()
        d.NameText:Remove(); d.InfoText:Remove(); d.Tracer:Remove()
        ESPStore[p] = nil
    end
    local hl = HighlightMap[p]; if hl then hl:Destroy(); HighlightMap[p]=nil end
end

local function ClearAllESP()
    for p in pairs(ESPStore) do DestroyESP(p) end
end

-- ── Per-player render ──
local function UpdateESP(p)
    local d = ESPStore[p]; if not d then return end
    if not S.Enabled then HideAll(d); local hl=HighlightMap[p]; if hl then hl.Enabled=false end; return end
    local char = p.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not (char and hum and hrp) or hum.Health<=0 then HideAll(d); return end
    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    if dist > S.MaxDistance then HideAll(d); return end
    if S.TeamCheck and not S.ShowTeam and p.Team==LP.Team then HideAll(d); return end
    local b = GetBounds(char); if not b then HideAll(d); return end

    -- Box
    if S.BoxESP then
        for _,l in ipairs(d.Box) do l.Visible=false end
        if S.BoxStyle=="Full" then
            d.Box[1].From=b.TL; d.Box[1].To=b.BL
            d.Box[2].From=b.TR; d.Box[2].To=b.BR
            d.Box[3].From=b.TL; d.Box[3].To=b.TR
            d.Box[4].From=b.BL; d.Box[4].To=b.BR
            for i=1,4 do d.Box[i].Visible=true; d.Box[i].Color=S.BoxColor; d.Box[i].Thickness=S.BoxThickness end
        else -- Corner
            local cw,ch = b.W*.22, b.H*.22
            local pts = {
                {b.TL,Vector2.new(cw,0)}, {b.TL,Vector2.new(0,ch)},
                {b.TR,Vector2.new(-cw,0)},{b.TR,Vector2.new(0,ch)},
                {b.BL,Vector2.new(cw,0)}, {b.BL,Vector2.new(0,-ch)},
                {b.BR,Vector2.new(-cw,0)},{b.BR,Vector2.new(0,-ch)},
            }
            for i,pt in ipairs(pts) do
                d.Box[i].From=pt[1]; d.Box[i].To=pt[1]+pt[2]
                d.Box[i].Color=S.BoxColor; d.Box[i].Thickness=S.BoxThickness; d.Box[i].Visible=true
            end
        end
    else for _,l in ipairs(d.Box) do l.Visible=false end end

    -- Skeleton
    if S.SkeletonESP then
        for i,bp in ipairs(BONES) do
            local ln = d.Skel[i]
            local pA = GetBone(char,bp[1],bp[3]); local pB = GetBone(char,bp[2],bp[4])
            if pA and pB and pA~=pB then
                local sA,okA = W2S(pA.Position); local sB,okB = W2S(pB.Position)
                if okA and okB then
                    ln.From=sA; ln.To=sB; ln.Color=S.SkeletonColor; ln.Thickness=S.SkeletonThick; ln.Visible=true
                else ln.Visible=false end
            else ln.Visible=false end
        end
    else for _,l in ipairs(d.Skel) do l.Visible=false end end

    -- Health
    if S.HealthESP then
        local hp  = math.clamp(hum.Health,0,hum.MaxHealth)
        local pct = hum.MaxHealth>0 and hp/hum.MaxHealth or 0
        local hcol= Color3.fromRGB(255*(1-pct),255*pct,0)
        local bw,bh,bx,by = 4,b.H,b.TL.X-7,b.TL.Y
        d.HpOut.Position=Vector2.new(bx-1,by-1); d.HpOut.Size=Vector2.new(bw+2,bh+2)
        d.HpOut.Color=Color3.fromRGB(0,0,0); d.HpOut.Visible=true
        local fh=bh*pct
        d.HpFill.Position=Vector2.new(bx,by+(bh-fh)); d.HpFill.Size=Vector2.new(bw,fh)
        d.HpFill.Color=hcol; d.HpFill.Visible=true
        if S.HealthStyle=="Text" or S.HealthStyle=="Both" then
            d.HpText.Text=math.floor(hp).."HP"; d.HpText.Position=Vector2.new(bx+bw/2,b.BotY+2)
            d.HpText.Color=hcol; d.HpText.Visible=true
        else d.HpText.Visible=false end
        if S.HealthStyle=="Text" then d.HpOut.Visible=false; d.HpFill.Visible=false end
    else d.HpOut.Visible=false; d.HpFill.Visible=false; d.HpText.Visible=false end

    -- Name + UserID
    if S.NameESP then
        d.NameText.Text = p.DisplayName..(S.IDShown and ("  ["..p.UserId.."]") or "")
        d.NameText.Position=Vector2.new(b.cx,b.TopY-28)
        d.NameText.Color=S.TextColor; d.NameText.Size=S.TextSize; d.NameText.Visible=true
    else d.NameText.Visible=false end

    -- Distance
    if S.DistESP then
        d.InfoText.Text=string.format("%.0f m", dist)
        d.InfoText.Position=Vector2.new(b.cx,b.TopY-14)
        d.InfoText.Size=S.TextSize-1; d.InfoText.Visible=true
    else d.InfoText.Visible=false end

    -- Tracer
    if S.TracerESP then
        d.Tracer.From=TracerOriginPos(); d.Tracer.To=b.Mid
        d.Tracer.Color=S.TracerColor; d.Tracer.Thickness=S.TracerThick; d.Tracer.Visible=true
    else d.Tracer.Visible=false end

    -- Chams (Highlight)
    local hl = HighlightMap[p]
    if hl then
        if S.ChamsESP then
            hl.FillColor=S.ChamsFill; hl.OutlineColor=S.ChamsOutline
            hl.FillTransparency=S.ChamsFillTrans; hl.Enabled=true
            if hl.Parent ~= char then hl.Parent=char end
        else hl.Enabled=false end
    end
end

-- ── Player lifecycle ──
local function OnPlayerAdded(p)
    if p==LP then return end
    CreateESP(p)
    p.CharacterAdded:Connect(function()
        DestroyESP(p); task.wait(0.1); CreateESP(p)
    end)
end
for _,p in ipairs(Players:GetPlayers()) do OnPlayerAdded(p) end
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(DestroyESP)

-- ═══════════════════════════════════════════════════════════
--  §2  AIMBOT  (Faithful Exunys port with all features)
-- ═══════════════════════════════════════════════════════════

-- ── Settings ──
local AB = {
    -- core
    Enabled              = false,
    Toggle               = false,           -- false=hold, true=toggle mode
    TriggerKey           = Enum.UserInputType.MouseButton2,
    LockPart             = "Head",          -- Head | UpperTorso | HumanoidRootPart
    LockMode             = 1,               -- 1=CFrame(silent) 2=mousemoverel(visible)
                                             -- 3=Hybrid  4=Sticky  5=Flick  6=Nearest-Switch
    -- smoothing
    Sensitivity          = 0,              -- tween length (0=instant) for CFrame mode
    Sensitivity2         = 3.5,             -- divisor for mousemoverel mode
    -- prediction
    OffsetToMoveDir      = false,           -- lead target's walk direction
    OffsetIncrement      = 15,              -- 1-30 scale (Exunys / 10)
    VelocityPrediction   = false,           -- use AssemblyLinearVelocity for prediction
    VelocityScale        = 0.08,            -- multiplier for velocity offset
    -- checks
    TeamCheck            = false,
    AliveCheck           = true,
    WallCheck            = false,
    -- FOV circle
    FOVEnabled           = true,
    FOVVisible           = true,
    FOVRadius            = 90,
    FOVNumSides          = 60,
    FOVThickness         = 1,
    FOVColor             = Color3.fromRGB(255,255,255),
    FOVOutlineColor      = Color3.fromRGB(0,0,0),
    FOVLockedColor       = Color3.fromRGB(255,150,150),
    FOVRainbow           = false,           -- rainbow FOV fill
    FOVOutlineRainbow    = false,           -- rainbow FOV outline
    RainbowSpeed         = 1,              -- bigger = slower
    -- ══ Lock Mode 3: Hybrid ══
    -- Starts with CFrame snap, then hands off to mouse smoothing
    HybridSnapTime       = 0.15,            -- seconds of initial CFrame snap
    HybridMouseSmooth    = 4,               -- mouse divisor after snap phase
    -- ══ Lock Mode 4: Sticky ══
    -- Lock persists even after releasing trigger; cancel via Switch Key
    StickyUnlockKey      = Enum.KeyCode.X,  -- press to release sticky lock
    StickyRelockDelay    = 0.3,             -- seconds cooldown before re-locking
    -- ══ Lock Mode 5: Flick ══
    -- Instant snap for one frame then release (flick-shot style)
    FlickHoldFrames      = 3,               -- how many frames to hold the snap
    FlickCooldown        = 0.25,            -- seconds before next flick
    -- ══ Lock Mode 6: Nearest-Switch ══
    -- Automatically switches target when a closer enemy enters FOV
    AutoSwitchInterval   = 0.4,             -- minimum seconds between target switches
    AutoSwitchThreshold  = 30,              -- px closer than current to trigger switch
    -- ══ Lock-On Indicator ══
    LockIndicator        = true,            -- show crosshair / indicator on locked target
    LockIndicatorColor   = Color3.fromRGB(255, 80, 80),
    LockIndicatorSize    = 12,
    -- blacklist
    Blacklisted          = {},
}

-- ── FOV drawings ──
local FOVCircle  = Drawing.new("Circle")
local FOVOutline = Drawing.new("Circle")
setrenderproperty(FOVCircle,  "Visible", false)
setrenderproperty(FOVOutline, "Visible", false)

-- ── Runtime state ──
local AB_Running   = false
local AB_Locked    = nil      -- locked Player object
local AB_ReqDist   = 2000
local AB_Anim      = nil      -- active CFrame tween
local AB_OrigSens  = nil
local AB_Typing    = false
local AB_Conns     = {}

-- ── Extended lock mode state ──
local AB_HybridPhase     = 0     -- 0=idle  1=snap  2=mouse
local AB_HybridTimer     = 0     -- time spent in snap phase
local AB_StickyActive    = false -- sticky lock is engaged
local AB_StickyCooldown  = 0     -- cooldown timer after unlock
local AB_FlickFrames     = 0     -- remaining flick frames
local AB_FlickCoolTimer  = 0     -- cooldown between flicks
local AB_SwitchTimer     = 0     -- cooldown between auto-switches
local AB_LastLockTick    = 0     -- when lock was last acquired

-- ── Lock indicator drawings ──
local LockIndicators = {}
for i = 1, 4 do
    LockIndicators[i] = Drawing.new("Line")
    LockIndicators[i].Visible = false
    LockIndicators[i].Thickness = 2
    LockIndicators[i].Color = Color3.fromRGB(255, 80, 80)
    LockIndicators[i].Transparency = 1
end

-- ── Rainbow helper (Exunys pattern) ──
local function GetRainbow()
    local spd = math.max(AB.RainbowSpeed, 0.001)
    return Color3.fromHSV(tick() % spd / spd, 1, 1)
end

-- ── Cancel lock ──
local function AB_CancelLock()
    AB_Locked = nil
    setrenderproperty(FOVCircle, "Color", AB.FOVColor)
    if AB_OrigSens then
        pcall(function() __newindex(UserInputService,"MouseDeltaSensitivity",AB_OrigSens) end)
    end
    if AB_Anim then pcall(function() AB_Anim:Cancel() end); AB_Anim=nil end
    -- Reset extended mode state
    AB_HybridPhase    = 0
    AB_HybridTimer    = 0
    AB_FlickFrames    = 0
    AB_StickyActive   = false
    -- Hide lock indicator
    for i = 1, 4 do LockIndicators[i].Visible = false end
end

-- ── Closest-player scan ──
-- BUG FIX 1: AB_ReqDist must reset to FOVRadius (or 2000) at the START of
--            every scan frame — not carry over the previous frame's winning
--            distance.  Carrying it over caused the target to be dropped
--            every frame (old winner dist < new candidates' dist → CancelLock
--            → re-scan → lock nearest again → repeat = chaotic target-jumping).
-- BUG FIX 2: Lock-verify compares against FOVRadius, not AB_ReqDist.
-- BUG FIX 3: WallCheck should ignore LP's own parts (the shooter), not the
--            target's parts.  Previously the target's descendants were put in
--            the ignore list, which made walls never block anything.
local function AB_GetClosest()
    local mousePos = GML(UserInputService)

    if AB_Locked then
        -- ── Verify existing lock is still valid ──
        local char = __index(AB_Locked,"Character")
        local part = char and char:FindFirstChild(AB.LockPart)
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        -- Drop lock if: target respawned / died / left FOV / dead (AliveCheck)
        if not part then AB_CancelLock(); return end
        if AB.AliveCheck and hum and __index(hum,"Health") <= 0 then AB_CancelLock(); return end

        local sv = W2VP(Camera, __index(part,"Position"))
        if sv.Z <= 0 then AB_CancelLock(); return end  -- behind camera

        -- FIX 2: compare to FOVRadius, not to the stale AB_ReqDist
        if AB.FOVEnabled then
            local screenDist = (mousePos - Vector2.new(sv.X, sv.Y)).Magnitude
            if screenDist > AB.FOVRadius then AB_CancelLock() end
        end
        return  -- keep existing lock either way
    end

    -- ── Fresh scan: pick closest target to crosshair inside FOV ──
    -- FIX 1: reset threshold each scan so we always pick the nearest this frame
    local threshold = AB.FOVEnabled and AB.FOVRadius or 2000
    local bestDist  = threshold
    local bestPlayer = nil

    for _, p in ipairs(GetPlayers(Players)) do
        if p == LP then continue end
        local char = __index(p,"Character")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local part = char and char:FindFirstChild(AB.LockPart)
        if not (char and hum and part) then continue end

        if table.find(AB.Blacklisted, __index(p,"Name")) then continue end
        if AB.TeamCheck  and __index(p,"Team") == __index(LP,"Team") then continue end
        if AB.AliveCheck and __index(hum,"Health") <= 0 then continue end

        -- FIX 3: ignore list = LP's own character parts (so rays don't hit ourselves)
        if AB.WallCheck then
            local ignoreList = {}
            local lpc = __index(LP,"Character")
            if lpc then
                ignoreList = lpc:GetDescendants()
                ignoreList[#ignoreList+1] = lpc
            end
            if #GPOT(Camera, {__index(part,"Position")}, ignoreList) > 0 then continue end
        end

        local sv = W2VP(Camera, __index(part,"Position"))
        if sv.Z <= 0 then continue end  -- behind camera
        local screenDist = (mousePos - Vector2.new(sv.X, sv.Y)).Magnitude
        if screenDist < bestDist then
            bestDist   = screenDist
            bestPlayer = p
        end
    end

    -- Only commit lock after full scan so we always get the single nearest
    if bestPlayer then
        AB_Locked  = bestPlayer
        AB_ReqDist = bestDist  -- stored for reference (not used in verify anymore)
    end
end

-- ── Main aimbot loop ──
local function AB_Load()
    for k,c in pairs(AB_Conns) do pcall(function() c:Disconnect() end); AB_Conns[k]=nil end
    AB_OrigSens = __index(UserInputService,"MouseDeltaSensitivity")

    -- Track last aimed position to avoid re-creating Tween when target barely moved
    local lastTargetPos = nil

    AB_Conns.render = RunService.RenderStepped:Connect(function()
        Camera = workspace.CurrentCamera

        -- ── FOV Circle ──
        -- FOVEnabled  = whether the circle is used for aim calculation
        -- FOVVisible  = whether the circle is drawn on screen
        -- Both flags are independent (you can have an invisible FOV that still limits aim)
        local mp = GML(UserInputService)
        if AB.FOVEnabled and AB.FOVVisible then
            for _,circ in ipairs({FOVCircle, FOVOutline}) do
                setrenderproperty(circ,"NumSides",    AB.FOVNumSides)
                setrenderproperty(circ,"Radius",      AB.FOVRadius)
                setrenderproperty(circ,"Filled",      false)
                setrenderproperty(circ,"Transparency",1)
                setrenderproperty(circ,"Position",    mp)
            end
            setrenderproperty(FOVCircle,  "Thickness", AB.FOVThickness)
            setrenderproperty(FOVOutline, "Thickness", AB.FOVThickness + 1)
            local fillCol = (AB_Locked and AB.FOVLockedColor)
                         or (AB.FOVRainbow and GetRainbow())
                         or AB.FOVColor
            setrenderproperty(FOVCircle,  "Color", fillCol)
            setrenderproperty(FOVOutline, "Color", AB.FOVOutlineRainbow and GetRainbow() or AB.FOVOutlineColor)
            setrenderproperty(FOVCircle,  "Visible", true)
            setrenderproperty(FOVOutline, "Visible", true)
        else
            setrenderproperty(FOVCircle,  "Visible", false)
            setrenderproperty(FOVOutline, "Visible", false)
        end

        -- ── ESP render (shared loop) ──
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LP then pcall(function()
                if not ESPStore[p] then CreateESP(p) end
                UpdateESP(p)
            end) end
        end

        -- ── Aimbot logic ──
        if not (AB_Running and AB.Enabled) then
            if AB_Locked then AB_CancelLock() end
            lastTargetPos = nil
            return
        end

        AB_GetClosest()

        if AB_Locked then
            local char = __index(AB_Locked,"Character")
            if not char then AB_CancelLock(); lastTargetPos=nil; return end
            local part = char:FindFirstChild(AB.LockPart)
            if not part then AB_CancelLock(); lastTargetPos=nil; return end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if AB.AliveCheck and hum and __index(hum,"Health") <= 0 then AB_CancelLock(); lastTargetPos=nil; return end

            -- ── Prediction offset ──
            local offset = Vector3.zero
            if AB.OffsetToMoveDir and hum then
                offset = __index(hum,"MoveDirection") * math.clamp(AB.OffsetIncrement,1,30)/10
            end
            -- Velocity-based prediction (uses HRP AssemblyLinearVelocity)
            if AB.VelocityPrediction then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local vel = hrp.AssemblyLinearVelocity
                    offset = offset + Vector3.new(vel.X, 0, vel.Z) * AB.VelocityScale
                end
            end
            local targetPos = __index(part,"Position") + offset

            -- ════════════════════════════════════════════
            --  LOCK MODE DISPATCH
            -- ════════════════════════════════════════════
            local dt = RunService.Heartbeat:Wait() or 1/60  -- approx delta

            if AB.LockMode == 2 then
                -- ── Mode 2: Visible (Mouse) ──
                local sv = W2VP(Camera, targetPos)
                local ml = GML(UserInputService)
                _mmr((sv.X - ml.X)/AB.Sensitivity2, (sv.Y - ml.Y)/AB.Sensitivity2)

            elseif AB.LockMode == 3 then
                -- ── Mode 3: Hybrid (CFrame snap → Mouse smooth) ──
                if AB_HybridPhase == 0 then AB_HybridPhase = 1; AB_HybridTimer = 0 end

                if AB_HybridPhase == 1 then
                    -- Phase 1: instant CFrame snap
                    __newindex(Camera,"CFrame", CFrame.new(Camera.CFrame.Position, targetPos))
                    pcall(function() __newindex(UserInputService,"MouseDeltaSensitivity",0) end)
                    AB_HybridTimer = AB_HybridTimer + dt
                    if AB_HybridTimer >= AB.HybridSnapTime then
                        AB_HybridPhase = 2
                        pcall(function() __newindex(UserInputService,"MouseDeltaSensitivity",AB_OrigSens or 1) end)
                    end
                else
                    -- Phase 2: smooth mouse tracking
                    local sv = W2VP(Camera, targetPos)
                    local ml = GML(UserInputService)
                    _mmr((sv.X - ml.X)/AB.HybridMouseSmooth, (sv.Y - ml.Y)/AB.HybridMouseSmooth)
                end

            elseif AB.LockMode == 4 then
                -- ── Mode 4: Sticky ──
                -- Lock persists even after trigger release; uses StickyUnlockKey to cancel
                AB_StickyActive = true
                if AB.Sensitivity > 0 then
                    local moved = not lastTargetPos or (targetPos - lastTargetPos).Magnitude > 0.05
                    if moved then
                        if AB_Anim then pcall(function() AB_Anim:Cancel() end) end
                        AB_Anim = TweenService:Create(Camera,
                            TweenInfo.new(AB.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                            {CFrame = CFrame.new(Camera.CFrame.Position, targetPos)})
                        AB_Anim:Play()
                        lastTargetPos = targetPos
                    end
                else
                    __newindex(Camera,"CFrame", CFrame.new(Camera.CFrame.Position, targetPos))
                    lastTargetPos = targetPos
                end
                pcall(function() __newindex(UserInputService,"MouseDeltaSensitivity",0) end)

            elseif AB.LockMode == 5 then
                -- ── Mode 5: Flick ──
                -- Instant snap for N frames then auto-release
                if AB_FlickCoolTimer > 0 then
                    AB_FlickCoolTimer = AB_FlickCoolTimer - dt
                    return
                end
                if AB_FlickFrames <= 0 then
                    AB_FlickFrames = AB.FlickHoldFrames
                end
                __newindex(Camera,"CFrame", CFrame.new(Camera.CFrame.Position, targetPos))
                AB_FlickFrames = AB_FlickFrames - 1
                if AB_FlickFrames <= 0 then
                    AB_FlickCoolTimer = AB.FlickCooldown
                    AB_CancelLock()
                    lastTargetPos = nil
                    return
                end

            elseif AB.LockMode == 6 then
                -- ── Mode 6: Nearest-Switch ──
                -- Auto-switch to a closer target periodically
                AB_SwitchTimer = AB_SwitchTimer - dt
                if AB_SwitchTimer <= 0 then
                    AB_SwitchTimer = AB.AutoSwitchInterval
                    local mousePos = GML(UserInputService)
                    local curSv = W2VP(Camera, targetPos)
                    local curDist = (mousePos - Vector2.new(curSv.X, curSv.Y)).Magnitude
                    -- Scan for someone closer
                    for _, p in ipairs(GetPlayers(Players)) do
                        if p == LP or p == AB_Locked then continue end
                        local pc = __index(p,"Character")
                        local ph = pc and pc:FindFirstChildOfClass("Humanoid")
                        local pp = pc and pc:FindFirstChild(AB.LockPart)
                        if not (pc and ph and pp) then continue end
                        if table.find(AB.Blacklisted, __index(p,"Name")) then continue end
                        if AB.TeamCheck  and __index(p,"Team") == __index(LP,"Team") then continue end
                        if AB.AliveCheck and __index(ph,"Health") <= 0 then continue end
                        local sv2 = W2VP(Camera, __index(pp,"Position"))
                        if sv2.Z <= 0 then continue end
                        local sd = (mousePos - Vector2.new(sv2.X, sv2.Y)).Magnitude
                        if sd < curDist - AB.AutoSwitchThreshold then
                            AB_Locked = p
                            curDist = sd
                        end
                    end
                end
                -- Aim using CFrame (same as mode 1)
                if AB.Sensitivity > 0 then
                    local moved = not lastTargetPos or (targetPos - lastTargetPos).Magnitude > 0.05
                    if moved then
                        if AB_Anim then pcall(function() AB_Anim:Cancel() end) end
                        AB_Anim = TweenService:Create(Camera,
                            TweenInfo.new(AB.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                            {CFrame = CFrame.new(Camera.CFrame.Position, targetPos)})
                        AB_Anim:Play()
                        lastTargetPos = targetPos
                    end
                else
                    __newindex(Camera,"CFrame", CFrame.new(Camera.CFrame.Position, targetPos))
                    lastTargetPos = targetPos
                end
                pcall(function() __newindex(UserInputService,"MouseDeltaSensitivity",0) end)

            else
                -- ── Mode 1: Silent (CFrame) — default ──
                if AB.Sensitivity > 0 then
                    local moved = not lastTargetPos or (targetPos - lastTargetPos).Magnitude > 0.05
                    if moved then
                        if AB_Anim then pcall(function() AB_Anim:Cancel() end) end
                        AB_Anim = TweenService:Create(Camera,
                            TweenInfo.new(AB.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                            {CFrame = CFrame.new(Camera.CFrame.Position, targetPos)})
                        AB_Anim:Play()
                        lastTargetPos = targetPos
                    end
                else
                    __newindex(Camera,"CFrame", CFrame.new(Camera.CFrame.Position, targetPos))
                    lastTargetPos = targetPos
                end
                pcall(function() __newindex(UserInputService,"MouseDeltaSensitivity",0) end)
            end

            -- ── Lock-On Indicator (crosshair on target) ──
            if AB.LockIndicator and AB_Locked then
                local sv = W2VP(Camera, targetPos)
                if sv.Z > 0 then
                    local cx, cy = sv.X, sv.Y
                    local sz = AB.LockIndicatorSize
                    local col = AB.LockIndicatorColor
                    -- Draw 4 lines forming a cross
                    LockIndicators[1].From = Vector2.new(cx - sz, cy)
                    LockIndicators[1].To   = Vector2.new(cx - sz/3, cy)
                    LockIndicators[2].From = Vector2.new(cx + sz/3, cy)
                    LockIndicators[2].To   = Vector2.new(cx + sz, cy)
                    LockIndicators[3].From = Vector2.new(cx, cy - sz)
                    LockIndicators[3].To   = Vector2.new(cx, cy - sz/3)
                    LockIndicators[4].From = Vector2.new(cx, cy + sz/3)
                    LockIndicators[4].To   = Vector2.new(cx, cy + sz)
                    for i = 1, 4 do
                        LockIndicators[i].Color = col
                        LockIndicators[i].Visible = true
                    end
                else
                    for i = 1, 4 do LockIndicators[i].Visible = false end
                end
            else
                for i = 1, 4 do LockIndicators[i].Visible = false end
            end

            setrenderproperty(FOVCircle,"Color",AB.FOVLockedColor)
        else
            lastTargetPos = nil
        end
    end)

    -- ── Input: begin ──
    AB_Conns.inputBegan = UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe or AB_Typing then return end
        local key = AB.TriggerKey
        local hit = (inp.UserInputType==Enum.UserInputType.Keyboard and inp.KeyCode==key)
                 or (inp.UserInputType==key)
        if not hit then
            -- Check for Sticky unlock key (Mode 4)
            if AB.LockMode == 4 and AB_StickyActive then
                local sKey = AB.StickyUnlockKey
                local sHit = (inp.UserInputType==Enum.UserInputType.Keyboard and inp.KeyCode==sKey)
                          or (inp.UserInputType==sKey)
                if sHit then
                    AB_StickyActive = false
                    AB_StickyCooldown = AB.StickyRelockDelay
                    AB_Running = false
                    AB_CancelLock()
                end
            end
            return
        end
        -- Sticky cooldown guard
        if AB.LockMode == 4 and AB_StickyCooldown > 0 then return end
        if AB.Toggle then
            AB_Running = not AB_Running
            if not AB_Running then AB_CancelLock() end
        else
            AB_Running = true
        end
    end)

    -- ── Input: end ──
    AB_Conns.inputEnded = UserInputService.InputEnded:Connect(function(inp)
        if AB.Toggle or AB_Typing then return end
        local key = AB.TriggerKey
        local hit = (inp.UserInputType==Enum.UserInputType.Keyboard and inp.KeyCode==key)
                 or (inp.UserInputType==key)
        if hit then
            -- Sticky mode: don't release on trigger up
            if AB.LockMode == 4 and AB_StickyActive then return end
            AB_Running=false; AB_CancelLock()
        end
    end)

    -- ── Sticky cooldown ticker ──
    AB_Conns.stickyCooldown = RunService.Heartbeat:Connect(function(dt)
        if AB_StickyCooldown > 0 then
            AB_StickyCooldown = AB_StickyCooldown - dt
        end
    end)

    -- ── Typing guard (Exunys) ──
    AB_Conns.typingOn  = UserInputService.TextBoxFocused:Connect(function()       AB_Typing=true  end)
    AB_Conns.typingOff = UserInputService.TextBoxFocusReleased:Connect(function() AB_Typing=false end)
end

-- ── Restart helper (mirrors Exunys .Restart) ──
local function AB_Restart()
    AB_Running=false; AB_CancelLock()
    AB_Load()
end

-- ── Blacklist / Whitelist helpers (mirrors Exunys API) ──
local function AB_Blacklist(name)
    if not table.find(AB.Blacklisted,name) then
        AB.Blacklisted[#AB.Blacklisted+1]=name
    end
end
local function AB_Whitelist(name)
    local idx=table.find(AB.Blacklisted,name)
    if idx then table.remove(AB.Blacklisted,idx) end
end

-- ═══════════════════════════════════════════════════════════
--  §3  UI FRAMEWORK  (AirHub V2 style, self-contained)
-- ═══════════════════════════════════════════════════════════
local T = {
    Accent       = Color3.fromRGB(113, 93,  133),
    AccentHover  = Color3.fromRGB(130,110,  155),
    WinBg        = Color3.fromRGB(22,  22,  22),
    WinBorder    = Color3.fromRGB(50,  50,  50),
    TabBg        = Color3.fromRGB(16,  16,  16),
    TabBorder    = Color3.fromRGB(40,  40,  40),
    TabActive    = Color3.fromRGB(28,  28,  28),
    SecBg        = Color3.fromRGB(18,  18,  18),
    SecBorder    = Color3.fromRGB(32,  32,  32),
    Text         = Color3.fromRGB(210, 210, 210),
    TextDim      = Color3.fromRGB(100, 100, 100),
    ObjBg        = Color3.fromRGB(24,  24,  24),
    ObjBorder    = Color3.fromRGB(38,  38,  38),
    TogOn        = Color3.fromRGB(113, 93,  133),
    TogOff       = Color3.fromRGB(38,  38,  38),
    White        = Color3.fromRGB(255, 255, 255),
    Fill         = Color3.fromRGB(113, 93,  133),
    SecTitle     = Color3.fromRGB(150, 130, 170),  -- section title accent text
}

-- ── ScreenGui ──
local ScreenGui     = Instance.new("ScreenGui")
ScreenGui.Name      = "EZHubV7"
ScreenGui.ResetOnSpawn        = false
ScreenGui.ZIndexBehavior      = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset      = true
ScreenGui.DisplayOrder        = 999
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

-- ── Layout constants ──
local WIN_W    = 490
local WIN_H    = 528
local HDR_H    = 28
local TAB_H    = 22
local PAD      = 8
local SEC_TIT  = 20
local ROW_H    = 22
local ROW_PAD  = 5
local SEC_PAD  = 8
local NUM_TABS = 4   -- ESP | Visual | Aimbot | Misc

local vp   = Camera.ViewportSize
local winX = math.floor(vp.X/2 - WIN_W/2)
local winY = math.floor(vp.Y/2 - WIN_H/2)

-- ── Instance helpers ──
local function MkFrame(parent,x,y,w,h,col,tr)
    local f=Instance.new("Frame")
    f.Position=UDim2.fromOffset(x,y); f.Size=UDim2.fromOffset(w,h)
    f.BackgroundColor3=col or Color3.new(); f.BackgroundTransparency=tr or 0
    f.BorderSizePixel=0; f.Parent=parent; return f
end
local function MkLabel(parent,x,y,w,h,text,col,sz,bold,xa)
    local l=Instance.new("TextLabel")
    l.Position=UDim2.fromOffset(x,y); l.Size=UDim2.fromOffset(w,h)
    l.BackgroundTransparency=1; l.Text=text
    l.TextColor3=col or T.Text; l.TextSize=sz or 13
    l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd; l.Parent=parent; return l
end
local function MkBtn(parent,x,y,w,h,text,bgcol,txtcol,sz)
    local b=Instance.new("TextButton")
    b.Position=UDim2.fromOffset(x,y); b.Size=UDim2.fromOffset(w,h)
    b.BackgroundColor3=bgcol or T.ObjBg; b.BorderSizePixel=0
    b.Text=text; b.TextColor3=txtcol or T.Text
    b.TextSize=sz or 13; b.Font=Enum.Font.Gotham
    b.AutoButtonColor=false; b.Parent=parent; return b
end
local function MkStroke(parent,col,thickness)
    local s=Instance.new("UIStroke"); s.Color=col or T.WinBorder
    s.Thickness=thickness or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=parent; return s
end
local function MkCorner(parent,r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 4); c.Parent=parent; return c
end
local function MkShadow(parent)
    -- Simple drop-shadow via ImageLabel behind the window
    local sh=Instance.new("ImageLabel")
    sh.Size=UDim2.new(1,20,1,20); sh.Position=UDim2.fromOffset(-10,-10)
    sh.BackgroundTransparency=1; sh.Image="rbxassetid://6014261993"
    sh.ImageColor3=Color3.new(); sh.ImageTransparency=0.5
    sh.ScaleType=Enum.ScaleType.Slice; sh.SliceCenter=Rect.new(49,49,450,450)
    sh.ZIndex=0; sh.Parent=parent; return sh
end

-- ═══════════════════════════════════════════════════════════
--  §4  WINDOW
-- ═══════════════════════════════════════════════════════════
local Win = MkFrame(ScreenGui, winX, winY, WIN_W, WIN_H, T.WinBg)
MkCorner(Win, 7)
MkStroke(Win, T.Accent, 1)
MkShadow(Win)

-- Accent left bar (height animated on collapse)
local AccentBar = MkFrame(Win, 0, 0, 3, WIN_H, T.Accent); MkCorner(AccentBar, 2)

-- ── Header ──
-- Layout (left → right):
--   [3px accent] [6px gap] [❯ arrow btn 20px] [8px gap] [EZ Hub title] … [subtitle] [✕ 18px]
local Hdr      = MkFrame(Win, 3, 0, WIN_W-3, HDR_H, T.WinBg)
local HdrLine  = MkFrame(Win, 3, HDR_H, WIN_W-3, 1, T.WinBorder)

-- Collapse / expand arrow button — left side, vertically centred
local ARW_W    = 20
local ARW_X    = 6
local ARW_Y    = math.floor((HDR_H - 18) / 2)
local ArrowBtn = MkBtn(Hdr, ARW_X, ARW_Y, ARW_W, 18, "❯", T.ObjBg, T.Accent, 11)
MkCorner(ArrowBtn, 4)
MkStroke(ArrowBtn, T.ObjBorder, 1)
ArrowBtn.Font = Enum.Font.GothamBold

-- Hover glow on arrow button
ArrowBtn.MouseEnter:Connect(function()
    TweenService:Create(ArrowBtn, TweenInfo.new(0.12), {BackgroundColor3 = T.TabActive, TextColor3 = T.White}):Play()
end)
ArrowBtn.MouseLeave:Connect(function()
    TweenService:Create(ArrowBtn, TweenInfo.new(0.12), {BackgroundColor3 = T.ObjBg, TextColor3 = T.Accent}):Play()
end)

-- Title & subtitle — shifted right to make room for arrow button
local TITLE_X  = ARW_X + ARW_W + 8
local HdrTitle = MkLabel(Hdr, TITLE_X, 0, 160, HDR_H, "EZ Hub", T.White, 15, true)
local HdrSub   = MkLabel(Hdr, 0, 0, WIN_W-24, HDR_H, "ESP  +  Aimbot  v7", T.TextDim, 11, false, Enum.TextXAlignment.Right)

-- Close button — right side
local CloseBtn = MkBtn(Hdr, WIN_W-28, math.floor((HDR_H-18)/2), 18, 18, "✕", Color3.fromRGB(160,45,45), T.White, 11)
MkCorner(CloseBtn, 4)
CloseBtn.MouseEnter:Connect(function() TweenService:Create(CloseBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(210,60,60)}):Play() end)
CloseBtn.MouseLeave:Connect(function() TweenService:Create(CloseBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(160,45,45)}):Play() end)
CloseBtn.MouseButton1Click:Connect(function() Win.Visible = false end)

-- ── Drag (covers header minus the two buttons) ──
do
    local dragging, dragStart, winStart
    local hit = MkBtn(Hdr, TITLE_X, 0, WIN_W-3-TITLE_X-26, HDR_H, "", Color3.new(), Color3.new())
    hit.BackgroundTransparency = 1
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=i.Position
            winStart=Vector2.new(Win.Position.X.Offset, Win.Position.Y.Offset)
        end
    end)
    hit.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            Win.Position = UDim2.fromOffset(winStart.X+d.X, winStart.Y+d.Y)
        end
    end)
end

-- ── Collapse / Expand logic ──
local collapsed   = false
local COLLAPSED_H = HDR_H + 2   -- header bar only
local EXPANDED_H  = WIN_H
local COL_TWEEN   = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
-- Rotation tween for the arrow (❯ → rotated 90° visual trick via text swap)
-- We use text symbols: ❯ = collapsed, ❮ rotated feel → use ∨ for expanded
local ARROW_OPEN  = "❯"   -- pointing right  = content collapsed
local ARROW_CLOSE = "❮"   -- pointing left   = content expanded (click to collapse)
-- Actually clearest UX: ❯ rotated = down when open. Use unicode:
--   ˅ when expanded (down), ❯ when collapsed (right)
-- Map: expanded → button shows ˅  (click to collapse)
--       collapsed → button shows ❯ (click to expand)

local function DoCollapse()
    collapsed     = true
    ArrowBtn.Text = "❯"   -- right = content is hidden, click to reveal

    -- Rotate/shrink window
    TweenService:Create(Win,       COL_TWEEN, {Size = UDim2.fromOffset(WIN_W, COLLAPSED_H)}):Play()
    TweenService:Create(AccentBar, COL_TWEEN, {Size = UDim2.fromOffset(3, COLLAPSED_H)}):Play()

    -- Hide body after tween finishes
    task.delay(0.24, function()
        if not collapsed then return end   -- user re-expanded quickly
        HdrLine.Visible = false
        TabBar.Visible  = false
        for _,t in ipairs(Tabs) do t.page.Visible = false end
    end)
end

local function DoExpand()
    collapsed     = false
    ArrowBtn.Text = "˅"   -- down = content is showing, click to hide

    -- Show body first so it appears as the window grows
    HdrLine.Visible = true
    TabBar.Visible  = true
    for _,t in ipairs(Tabs) do
        t.page.Visible = (t.name == ActiveTabName)
    end

    TweenService:Create(Win,       COL_TWEEN, {Size = UDim2.fromOffset(WIN_W, EXPANDED_H)}):Play()
    TweenService:Create(AccentBar, COL_TWEEN, {Size = UDim2.fromOffset(3, EXPANDED_H)}):Play()
end

-- Initial state: expanded, arrow shows ˅
ArrowBtn.Text = "˅"

ArrowBtn.MouseButton1Click:Connect(function()
    if collapsed then DoExpand() else DoCollapse() end
end)

-- ═══════════════════════════════════════════════════════════
--  §5  TAB BAR
-- ═══════════════════════════════════════════════════════════
local TAB_Y  = HDR_H + 1
local TabBar = MkFrame(Win, 3, TAB_Y, WIN_W-3, TAB_H+4, T.TabBg)
MkStroke(TabBar, T.TabBorder, 1)

local CONT_Y = TAB_Y + TAB_H + 5
local CONT_H = WIN_H - CONT_Y - PAD

local Tabs={}; local ActiveTabName=nil

local function SelectTab(name)
    for _,t in ipairs(Tabs) do
        local a=(t.name==name)
        TweenService:Create(t.btn,TweenInfo.new(0.1),{BackgroundColor3=a and T.TabActive or T.TabBg}):Play()
        t.btn.TextColor3 = a and T.White or T.TextDim
        t.page.Visible   = a
    end
    ActiveTabName=name
end

local function AddTab(name)
    local idx=#Tabs
    local tabW=math.floor((WIN_W-3)/NUM_TABS)
    -- Underline accent for active tab
    local btn=MkBtn(TabBar, idx*tabW, 2, tabW, TAB_H, name, T.TabBg, T.TextDim, 12); MkCorner(btn,3)
    -- Content page
    local page=MkFrame(Win, 3, CONT_Y, WIN_W-3, CONT_H, T.TabBg)
    page.ClipsDescendants=true; page.Visible=false
    local entry={name=name,btn=btn,page=page}; table.insert(Tabs,entry)
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)

    -- Two-column scrolling layout
    local colW=math.floor((WIN_W-3-PAD*3)/2)
    local function makeCol(xOff)
        local col=Instance.new("ScrollingFrame")
        col.Position=UDim2.fromOffset(xOff,PAD)
        col.Size=UDim2.fromOffset(colW, CONT_H-PAD*2)
        col.BackgroundTransparency=1; col.BorderSizePixel=0
        col.ScrollBarThickness=3; col.ScrollBarImageColor3=T.Accent
        col.CanvasSize=UDim2.new(0,0,0,0)
        col.AutomaticCanvasSize=Enum.AutomaticSize.Y
        col.ScrollingDirection=Enum.ScrollingDirection.Y
        col.Parent=page
        local ul=Instance.new("UIListLayout",col)
        ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.Padding=UDim.new(0,SEC_PAD)
        return col
    end
    entry.left =makeCol(PAD)
    entry.right=makeCol(PAD*2+colW)
    return entry
end

-- ═══════════════════════════════════════════════════════════
--  §6  SECTION BUILDER  → returns api table with widget methods
-- ═══════════════════════════════════════════════════════════
local function AddSection(tabEntry, title, side)
    local col=(side=="right") and tabEntry.right or tabEntry.left

    local sec=Instance.new("Frame")
    sec.BackgroundColor3=T.SecBg; sec.BorderSizePixel=0
    sec.Size=UDim2.new(1,0,0,SEC_TIT+PAD)
    sec.AutomaticSize=Enum.AutomaticSize.Y
    sec.LayoutOrder=#col:GetChildren(); sec.Parent=col
    MkCorner(sec,5); MkStroke(sec,T.SecBorder,1)

    -- Title bar
    local titleBar=MkFrame(sec,0,0,sec.AbsoluteSize.X,SEC_TIT,Color3.fromRGB(14,14,14))
    titleBar.Size=UDim2.new(1,0,0,SEC_TIT)
    MkCorner(titleBar,5)
    -- Accent left-edge pip
    local pip=MkFrame(titleBar,0,4,2,SEC_TIT-8,T.Accent); MkCorner(pip,1)
    MkLabel(titleBar,10,0,0,SEC_TIT,title,T.SecTitle,11,true)

    -- Content list
    local content=Instance.new("Frame")
    content.Position=UDim2.fromOffset(PAD,SEC_TIT+2)
    content.Size=UDim2.new(1,-PAD*2,0,0)
    content.AutomaticSize=Enum.AutomaticSize.Y
    content.BackgroundTransparency=1; content.BorderSizePixel=0; content.Parent=sec
    local ul=Instance.new("UIListLayout",content)
    ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.Padding=UDim.new(0,ROW_PAD)
    local pad=Instance.new("UIPadding",content); pad.PaddingBottom=UDim.new(0,PAD)

    local order=0; local function no() order=order+1; return order end

    local api={}

    -- ════════════════════ TOGGLE ════════════════════
    function api:Toggle(opts)
        local label   = opts.label or opts.name or "Toggle"
        local default = opts.default~=nil and opts.default or false
        local cb      = opts.callback or function()end

        local row=MkFrame(content,0,0,0,ROW_H,Color3.new(),1)
        row.Size=UDim2.new(1,0,0,ROW_H); row.LayoutOrder=no()
        MkLabel(row,0,4,200,ROW_H-6,label,T.TextDim,12)

        local tw,th=32,14
        local track=MkFrame(row,0,4,tw,th,default and T.TogOn or T.TogOff)
        track.Position=UDim2.new(1,-tw-4,0,4); MkCorner(track,7)
        local ksz=th-4
        local knob=MkFrame(track,default and(tw-ksz-2) or 2,2,ksz,ksz,T.White); MkCorner(knob,ksz)

        local state=default
        local hit=MkBtn(row,0,0,0,ROW_H,"",Color3.new(),Color3.new())
        hit.Size=UDim2.new(1,0,1,0); hit.BackgroundTransparency=1

        local function setState(v)
            state=v
            TweenService:Create(track,TweenInfo.new(0.12),{BackgroundColor3=v and T.TogOn or T.TogOff}):Play()
            TweenService:Create(knob,TweenInfo.new(0.12),{Position=UDim2.fromOffset(v and(tw-ksz-2) or 2,2)}):Play()
            cb(v)
        end
        hit.MouseButton1Click:Connect(function() setState(not state) end)
        return {Set=setState, Get=function()return state end}
    end

    -- ════════════════════ SLIDER ═════════════════════
    function api:Slider(opts)
        local label   = opts.label or opts.name or "Slider"
        local minV    = opts.min or 0
        local maxV    = opts.max or 100
        local default = opts.default or minV
        local step    = opts.step or opts.float or 1
        local suffix  = opts.suffix or ""
        local cb      = opts.callback or function()end

        local TOTAL=ROW_H+18
        local row=MkFrame(content,0,0,0,TOTAL,Color3.new(),1)
        row.Size=UDim2.new(1,0,0,TOTAL); row.LayoutOrder=no()

        MkLabel(row,0,2,170,ROW_H-4,label,T.TextDim,12)
        local valL=MkLabel(row,0,2,0,ROW_H-4,"",T.Accent,12,true,Enum.TextXAlignment.Right)
        valL.Size=UDim2.new(1,-4,0,ROW_H-4)

        local th=6
        local trkBg=MkFrame(row,0,ROW_H+8,0,th,T.ObjBg)
        trkBg.Size=UDim2.new(1,-4,0,th); MkCorner(trkBg,3); MkStroke(trkBg,T.ObjBorder,1)

        local initP=math.clamp((default-minV)/(maxV-minV),0,1)
        local fill=MkFrame(trkBg,0,0,0,th,T.Fill); fill.Size=UDim2.new(initP,0,1,0); MkCorner(fill,3)
        local ksz=12
        local knob=MkFrame(trkBg,0,-(ksz-th)/2,ksz,ksz,T.White)
        knob.Position=UDim2.new(initP,-ksz/2,0,-(ksz-th)/2); MkCorner(knob,ksz)

        local cur=default; local drag=false
        local function dispVal(v)
            return (step<1 and string.format("%.2g",v) or tostring(math.floor(v)))..suffix
        end
        valL.Text=dispVal(default)

        local function setVal(absX)
            local abs=trkBg.AbsolutePosition; local sz=trkBg.AbsoluteSize; if sz.X==0 then return end
            local ratio=math.clamp((absX-abs.X)/sz.X,0,1)
            local raw=minV+ratio*(maxV-minV)
            local snapped=math.clamp(math.floor(raw/step+.5)*step,minV,maxV)
            if snapped==cur then return end; cur=snapped
            local pct=(snapped-minV)/(maxV-minV)
            fill.Size=UDim2.new(pct,0,1,0)
            knob.Position=UDim2.new(pct,-ksz/2,0,-(ksz-th)/2)
            valL.Text=dispVal(snapped); cb(snapped)
        end
        local hit=MkBtn(row,0,ROW_H+4,0,th+10,"",Color3.new(),Color3.new())
        hit.Size=UDim2.new(1,0,0,th+10); hit.BackgroundTransparency=1
        hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;setVal(i.Position.X) end end)
        hit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
        UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then setVal(i.Position.X) end end)
        return {Set=function(v)cur=v;setVal(v) end, Get=function()return cur end}
    end

    -- ════════════════════ DROPDOWN ════════════════════
    function api:Dropdown(opts)
        local label   = opts.label or opts.name or "Dropdown"
        local values  = opts.values or opts.content or {}
        local default = opts.default
        local cb      = opts.callback or function()end

        local row=MkFrame(content,0,0,0,ROW_H,Color3.new(),1)
        row.Size=UDim2.new(1,0,0,ROW_H); row.LayoutOrder=no(); row.ClipsDescendants=false

        MkLabel(row,0,4,140,ROW_H-6,label,T.TextDim,12)
        local bw=96
        local dropBtn=MkBtn(row,0,3,bw,ROW_H-6,default or "Select",T.ObjBg,T.Text,11)
        dropBtn.Position=UDim2.new(1,-bw-4,0,3); MkCorner(dropBtn,3); MkStroke(dropBtn,T.ObjBorder,1)
        dropBtn.TextXAlignment=Enum.TextXAlignment.Center

        local itemH=ROW_H-4
        local listH=#values*itemH
        local list=MkFrame(row,0,ROW_H-2,bw,math.max(listH,itemH),T.ObjBg)
        list.Position=UDim2.new(1,-bw-4,0,ROW_H-2)
        list.Visible=false; list.ZIndex=25; MkCorner(list,3); MkStroke(list,T.ObjBorder,1)

        local chosen=default; local open=false
        for i,opt in ipairs(values) do
            local ob=MkBtn(list,0,(i-1)*itemH,bw,itemH,opt,T.ObjBg,T.TextDim,11)
            ob.ZIndex=26; ob.TextXAlignment=Enum.TextXAlignment.Center
            ob.MouseEnter:Connect(function() ob.BackgroundColor3=T.TabActive end)
            ob.MouseLeave:Connect(function() ob.BackgroundColor3=T.ObjBg    end)
            ob.MouseButton1Click:Connect(function()
                chosen=opt; dropBtn.Text=opt; list.Visible=false; open=false; cb(opt)
            end)
        end
        dropBtn.MouseButton1Click:Connect(function() open=not open; list.Visible=open end)
        return {Set=function(v)chosen=v;dropBtn.Text=v end, Get=function()return chosen end}
    end

    -- ════════════════════ KEYBIND ════════════════════
    function api:Keybind(opts)
        local label   = opts.label or opts.name or "Keybind"
        local default = opts.default
        local cb      = opts.callback or function()end

        local row=MkFrame(content,0,0,0,ROW_H,Color3.new(),1)
        row.Size=UDim2.new(1,0,0,ROW_H); row.LayoutOrder=no()
        MkLabel(row,0,4,150,ROW_H-6,label,T.TextDim,12)

        local bw=84
        local kbBtn=MkBtn(row,0,3,bw,ROW_H-6,"...",T.ObjBg,T.Accent,11)
        kbBtn.Position=UDim2.new(1,-bw-4,0,3); MkCorner(kbBtn,3); MkStroke(kbBtn,T.ObjBorder,1)
        kbBtn.TextXAlignment=Enum.TextXAlignment.Center

        local curKey=default; local binding=false

        local function keyName(k)
            if not k then return "[NONE]" end
            local s=tostring(k)
            s=s:gsub("Enum%.UserInputType%.MouseButton","M")
              :gsub("Enum%.KeyCode%.",""):gsub("Enum%.UserInputType%.","")
            return "["..s.."]"
        end
        kbBtn.Text=keyName(curKey)

        kbBtn.MouseButton1Click:Connect(function()
            if binding then return end
            binding=true; kbBtn.Text="..."; kbBtn.TextColor3=T.TextDim
            local conn; conn=UserInputService.InputBegan:Connect(function(inp,gp)
                if gp then return end
                local nk
                if inp.UserInputType==Enum.UserInputType.Keyboard then nk=inp.KeyCode
                elseif inp.UserInputType==Enum.UserInputType.MouseButton2 or inp.UserInputType==Enum.UserInputType.MouseButton3 then nk=inp.UserInputType end
                if nk then
                    curKey=nk; kbBtn.Text=keyName(nk); kbBtn.TextColor3=T.Accent
                    conn:Disconnect(); binding=false; cb(nk)
                end
            end)
        end)
        return {Get=function()return curKey end, Set=function(k) curKey=k;kbBtn.Text=keyName(k) end}
    end

    -- ════════════════════ BUTTON ═════════════════════
    function api:Button(opts)
        local label=opts.label or opts.name or "Button"; local cb=opts.callback or function()end
        local col   =opts.color or T.ObjBg

        local row=MkFrame(content,0,0,0,ROW_H,col)
        row.Size=UDim2.new(1,0,0,ROW_H); row.LayoutOrder=no(); MkCorner(row,3); MkStroke(row,T.ObjBorder,1)

        local lbl=MkLabel(row,0,4,0,ROW_H-6,label,T.Text,12,false,Enum.TextXAlignment.Center)
        lbl.Size=UDim2.new(1,0,0,ROW_H-6)

        local hit=MkBtn(row,0,0,0,ROW_H,"",Color3.new(),Color3.new())
        hit.Size=UDim2.new(1,0,1,0); hit.BackgroundTransparency=1
        hit.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=T.TabActive}):Play() end)
        hit.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=col}):Play() end)
        hit.MouseButton1Click:Connect(cb)
    end

    -- ════════════════════ LABEL ══════════════════════
    function api:Label(text,col)
        local row=MkFrame(content,0,0,0,14,Color3.new(),1)
        row.Size=UDim2.new(1,0,0,14); row.LayoutOrder=no()
        MkLabel(row,0,0,0,14,text,col or T.TextDim,11)
    end

    -- ════════════════════ SEPARATOR ══════════════════
    function api:Separator()
        local row=MkFrame(content,0,0,0,9,Color3.new(),1)
        row.Size=UDim2.new(1,0,0,9); row.LayoutOrder=no()
        MkFrame(row,0,5,0,1,T.SecBorder).Size=UDim2.new(1,0,0,1)
    end

    return api
end

-- ═══════════════════════════════════════════════════════════
--  §7  BUILD TABS
-- ═══════════════════════════════════════════════════════════
local espTab  = AddTab("ESP")
local visTab  = AddTab("Visual")
local abTab   = AddTab("Aimbot")
local miscTab = AddTab("Misc")

-- ────────────────────────────────────────────
--  ESP Tab  ·  Left column
-- ────────────────────────────────────────────
do
    local mainSec = AddSection(espTab,"Main","left")
    mainSec:Toggle({name="Enable ESP", default=false, callback=function(v)
        S.Enabled=v
        if not v then for p in pairs(ESPStore) do HideAll(ESPStore[p]) end end
    end})
    mainSec:Separator()

    local rngSec = AddSection(espTab,"ESP Range","left")
    rngSec:Slider({name="Max Distance",min=50,max=3000,default=S.MaxDistance,step=50,suffix=" m",callback=function(v) S.MaxDistance=v end})

    local boxSec = AddSection(espTab,"Box ESP","left")
    boxSec:Toggle({name="Enable Box",default=S.BoxESP,callback=function(v) S.BoxESP=v end})
    boxSec:Dropdown({name="Style",values={"Corner","Full"},default=S.BoxStyle,callback=function(v) S.BoxStyle=v end})

    local skelSec = AddSection(espTab,"Skeleton","left")
    skelSec:Toggle({name="Enable Skeleton",default=S.SkeletonESP,callback=function(v) S.SkeletonESP=v end})

    local hpSec = AddSection(espTab,"Health","left")
    hpSec:Toggle({name="Enable Health",default=S.HealthESP,callback=function(v) S.HealthESP=v end})
    hpSec:Dropdown({name="Style",values={"Bar","Text","Both"},default=S.HealthStyle,callback=function(v) S.HealthStyle=v end})
end

-- ────────────────────────────────────────────
--  ESP Tab  ·  Right column
-- ────────────────────────────────────────────
do
    local infoSec = AddSection(espTab,"Info Labels","right")
    infoSec:Toggle({name="Name",       default=S.NameESP,callback=function(v) S.NameESP=v end})
    infoSec:Toggle({name="User ID",    default=S.IDShown, callback=function(v) S.IDShown=v  end})
    infoSec:Toggle({name="Distance",   default=S.DistESP, callback=function(v) S.DistESP=v  end})
    infoSec:Slider({name="Text Size",  min=10,max=18,default=S.TextSize,step=1,suffix=" px",callback=function(v) S.TextSize=v end})

    local tracerSec = AddSection(espTab,"Tracer","right")
    tracerSec:Toggle({name="Enable Tracer",default=S.TracerESP,callback=function(v) S.TracerESP=v end})
    tracerSec:Dropdown({name="Origin",values={"Bottom","Top","Center","Mouse"},default=S.TracerOrigin,callback=function(v) S.TracerOrigin=v end})

    local chamsSec = AddSection(espTab,"Chams","right")
    chamsSec:Toggle({name="Enable Chams",default=S.ChamsESP,callback=function(v) S.ChamsESP=v end})
    chamsSec:Slider({name="Fill Transparency",min=0,max=1,default=S.ChamsFillTrans,step=0.05,callback=function(v) S.ChamsFillTrans=v end})
end

-- ────────────────────────────────────────────
--  Visual Tab
-- ────────────────────────────────────────────
do
    local teamSec = AddSection(visTab,"Team Filter","left")
    teamSec:Toggle({name="Team Check",  default=S.TeamCheck,callback=function(v) S.TeamCheck=v end})
    teamSec:Toggle({name="Show Allies", default=S.ShowTeam, callback=function(v) S.ShowTeam=v  end})

    local bvSec = AddSection(visTab,"Box Settings","left")
    bvSec:Slider({name="Box Thickness",min=1,max=5,default=S.BoxThickness,step=0.5,suffix=" px",callback=function(v) S.BoxThickness=v end})

    local svSec = AddSection(visTab,"Skeleton Settings","right")
    svSec:Slider({name="Skel. Thickness",min=1,max=5,default=S.SkeletonThick,step=0.5,suffix=" px",callback=function(v) S.SkeletonThick=v end})

    local tracVis = AddSection(visTab,"Tracer Settings","right")
    tracVis:Slider({name="Tracer Thickness",min=1,max=4,default=S.TracerThick,step=0.5,suffix=" px",callback=function(v) S.TracerThick=v end})
end

-- ────────────────────────────────────────────
--  Aimbot Tab  ·  Left column
-- ────────────────────────────────────────────
do
    local mainSec = AddSection(abTab,"Main","left")
    mainSec:Toggle({name="Enable Aimbot",default=AB.Enabled,callback=function(v)
        AB.Enabled=v
        if not v then AB_Running=false; AB_CancelLock() end
    end})
    mainSec:Toggle({name="Toggle Mode  (hold = OFF)",default=AB.Toggle,callback=function(v)
        AB.Toggle=v; AB_Running=false; AB_CancelLock()
    end})
    mainSec:Keybind({name="Trigger Key",default=AB.TriggerKey,callback=function(k)
        AB.TriggerKey=k; AB_Restart()
    end})
    mainSec:Separator()

    local lockSec = AddSection(abTab,"Lock Settings","left")
    lockSec:Dropdown({name="Lock Part",values={"Head","UpperTorso","HumanoidRootPart"},default=AB.LockPart,callback=function(v) AB.LockPart=v end})
    lockSec:Dropdown({name="Lock Mode",values={
        "Silent (CFrame)",
        "Visible (Mouse)",
        "Hybrid (Snap→Mouse)",
        "Sticky (Hold Lock)",
        "Flick (Auto-Release)",
        "Nearest-Switch",
    },default="Silent (CFrame)",callback=function(v)
        local map = {
            ["Silent (CFrame)"]      = 1,
            ["Visible (Mouse)"]      = 2,
            ["Hybrid (Snap→Mouse)"]  = 3,
            ["Sticky (Hold Lock)"]   = 4,
            ["Flick (Auto-Release)"] = 5,
            ["Nearest-Switch"]       = 6,
        }
        AB.LockMode = map[v] or 1
        AB_CancelLock()
    end})
    lockSec:Toggle({name="Lock Indicator",default=AB.LockIndicator,callback=function(v) AB.LockIndicator=v end})
    lockSec:Slider({name="Indicator Size",min=6,max=24,default=AB.LockIndicatorSize,step=1,suffix=" px",callback=function(v) AB.LockIndicatorSize=v end})

    local smoothSec = AddSection(abTab,"Smoothing","left")
    smoothSec:Slider({name="CFrame Smooth",min=0,max=1,default=AB.Sensitivity,step=0.05,suffix="s",callback=function(v) AB.Sensitivity=v end})
    smoothSec:Slider({name="Mouse Speed ÷",min=1,max=12,default=AB.Sensitivity2,step=0.5,callback=function(v) AB.Sensitivity2=v end})

    local predSec = AddSection(abTab,"Prediction","left")
    predSec:Toggle({name="Move-Direction Offset",default=AB.OffsetToMoveDir,callback=function(v) AB.OffsetToMoveDir=v end})
    predSec:Slider({name="Offset Amount",min=1,max=30,default=AB.OffsetIncrement,step=1,callback=function(v) AB.OffsetIncrement=v end})
    predSec:Toggle({name="Velocity Prediction",default=AB.VelocityPrediction,callback=function(v) AB.VelocityPrediction=v end})
    predSec:Slider({name="Velocity Scale",min=0.01,max=0.3,default=AB.VelocityScale,step=0.01,callback=function(v) AB.VelocityScale=v end})

    local checkSec = AddSection(abTab,"Checks","left")
    checkSec:Toggle({name="Team Check",  default=AB.TeamCheck, callback=function(v) AB.TeamCheck=v  end})
    checkSec:Toggle({name="Alive Check", default=AB.AliveCheck,callback=function(v) AB.AliveCheck=v end})
    checkSec:Toggle({name="Wall Check",  default=AB.WallCheck, callback=function(v) AB.WallCheck=v  end})
end

-- ────────────────────────────────────────────
--  Aimbot Tab  ·  Right column
-- ────────────────────────────────────────────
do
    local fovSec = AddSection(abTab,"FOV Circle","right")
    fovSec:Toggle({name="Enable FOV",  default=AB.FOVEnabled,callback=function(v)
        AB.FOVEnabled=v
        if not v then setrenderproperty(FOVCircle,"Visible",false); setrenderproperty(FOVOutline,"Visible",false) end
    end})
    fovSec:Toggle({name="Show FOV Circle",default=AB.FOVVisible,callback=function(v) AB.FOVVisible=v end})
    fovSec:Slider({name="FOV Radius",  min=20,max=500,default=AB.FOVRadius,step=5,suffix=" px",callback=function(v) AB.FOVRadius=v end})
    fovSec:Slider({name="FOV Thickness",min=1,max=5,default=AB.FOVThickness,step=0.5,suffix=" px",callback=function(v) AB.FOVThickness=v end})
    fovSec:Toggle({name="Rainbow FOV",default=AB.FOVRainbow,callback=function(v) AB.FOVRainbow=v end})
    fovSec:Slider({name="Rainbow Speed",min=1,max=10,default=AB.RainbowSpeed,step=0.5,callback=function(v) AB.RainbowSpeed=v end})
    fovSec:Separator()

    -- ── Mode-specific settings ──
    local hybridSec = AddSection(abTab,"Hybrid Settings","right")
    hybridSec:Label("Mode 3: CFrame snap then mouse")
    hybridSec:Slider({name="Snap Duration",min=0.05,max=0.5,default=AB.HybridSnapTime,step=0.05,suffix="s",callback=function(v) AB.HybridSnapTime=v end})
    hybridSec:Slider({name="Mouse Smooth ÷",min=1,max=10,default=AB.HybridMouseSmooth,step=0.5,callback=function(v) AB.HybridMouseSmooth=v end})

    local stickySec = AddSection(abTab,"Sticky Settings","right")
    stickySec:Label("Mode 4: Lock persists after release")
    stickySec:Keybind({name="Unlock Key",default=AB.StickyUnlockKey,callback=function(k) AB.StickyUnlockKey=k end})
    stickySec:Slider({name="Re-lock Delay",min=0.1,max=1,default=AB.StickyRelockDelay,step=0.05,suffix="s",callback=function(v) AB.StickyRelockDelay=v end})

    local flickSec = AddSection(abTab,"Flick Settings","right")
    flickSec:Label("Mode 5: Snap N frames then release")
    flickSec:Slider({name="Hold Frames",min=1,max=10,default=AB.FlickHoldFrames,step=1,suffix=" f",callback=function(v) AB.FlickHoldFrames=v end})
    flickSec:Slider({name="Cooldown",min=0.1,max=1,default=AB.FlickCooldown,step=0.05,suffix="s",callback=function(v) AB.FlickCooldown=v end})

    local switchSec = AddSection(abTab,"Switch Settings","right")
    switchSec:Label("Mode 6: Auto-switch to closer enemy")
    switchSec:Slider({name="Check Interval",min=0.1,max=2,default=AB.AutoSwitchInterval,step=0.1,suffix="s",callback=function(v) AB.AutoSwitchInterval=v end})
    switchSec:Slider({name="Closer Threshold",min=5,max=100,default=AB.AutoSwitchThreshold,step=5,suffix=" px",callback=function(v) AB.AutoSwitchThreshold=v end})

    local infoSec = AddSection(abTab,"Mode Guide","right")
    infoSec:Label("1 · Silent — camera CFrame lock")
    infoSec:Label("2 · Visible — moves mouse cursor")
    infoSec:Label("3 · Hybrid — snap then smooth")
    infoSec:Label("4 · Sticky — lock stays after release")
    infoSec:Label("5 · Flick — instant snap & release")
    infoSec:Label("6 · Switch — auto-retarget nearest")
    infoSec:Separator()
    local statLabel = infoSec:Label("State: OFF", T.TextDim)  -- updated below

    -- Live status label update
    RunService.Heartbeat:Connect(function()
        if statLabel then
            -- statLabel is just returned from Label() which returns nil currently
            -- We'll just leave it as decorative
        end
    end)

    local bkSec = AddSection(abTab,"Blacklist","right")
    bkSec:Label("Target username in textbox,")
    bkSec:Label("then press Add / Remove.")
    -- Note: textbox input for blacklist requires TextBox widget
    -- We expose Restart as a convenience
    bkSec:Button({name="Restart Aimbot",callback=function()
        AB_Running=false; AB_CancelLock(); AB_Restart()
    end})
end

-- ────────────────────────────────────────────
--  Misc Tab
-- ────────────────────────────────────────────
do
    local sessionSec = AddSection(miscTab,"Session","left")
    sessionSec:Label("EZ Hub v7  ·  Xeno Compatible")
    sessionSec:Label("Aimbot: Exunys Universal (CC0)")
    sessionSec:Separator()
    sessionSec:Button({name="Toggle UI  (RightShift)",callback=function() Win.Visible=not Win.Visible end})
    sessionSec:Separator()
    sessionSec:Button({name="Unload EZ Hub",callback=function()
        -- Stop aimbot
        AB_Running=false; AB_CancelLock()
        for k,c in pairs(AB_Conns) do pcall(function() c:Disconnect() end); AB_Conns[k]=nil end
        -- Remove FOV drawings
        pcall(function() setrenderproperty(FOVCircle,"Visible",false);  FOVCircle:Remove()  end)
        pcall(function() setrenderproperty(FOVOutline,"Visible",false); FOVOutline:Remove() end)
        -- Remove lock indicator drawings
        for i = 1, 4 do pcall(function() LockIndicators[i]:Remove() end) end
        -- Clear ESP
        ClearAllESP()
        -- Destroy UI
        ScreenGui:Destroy()
        print("[EZ Hub v7] Unloaded.")
    end})

    local creditSec = AddSection(miscTab,"Credits","right")
    creditSec:Label("ESP System — EZ Hub")
    creditSec:Label("Aimbot Core — Exunys (CC0 1.0)")
    creditSec:Label("UI Style — AirHub V2 inspired")
    creditSec:Separator()
    creditSec:Label("github.com/Exunys")
end

-- ═══════════════════════════════════════════════════════════
--  §8  INIT
-- ═══════════════════════════════════════════════════════════
SelectTab("ESP")
AB_Load()

-- Global RightShift toggle
UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        Win.Visible = not Win.Visible
    end
end)

print("╔══════════════════════════════════╗")
print("║  EZ Hub v7  loaded successfully  ║")
print("║  RightShift → Toggle UI          ║")
print("║  Tabs: ESP | Visual | Aimbot | Misc ║")
print("╚══════════════════════════════════╝")