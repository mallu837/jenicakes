local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- REMOTE REFS
-- ==========================================

local RS  = game:GetService("ReplicatedStorage")
local Svc = RS.Packages.Knit.Services

local requestRF  = nil
local vaultRF    = nil
local collectRF  = nil
local purchaseRF = nil

pcall(function() requestRF  = Svc.EggSpawnerService.RF.RequestHitEgg       end)
pcall(function() vaultRF    = Svc.EggVaultService.RF.RequestHitVaultEgg     end)
pcall(function() collectRF  = Svc.BaseService.RF.RequestPlatformCollect      end)
pcall(function() purchaseRF = Svc.PetEggStockService.RF.PurchasePetEgg       end)

local eggFolder = workspace:WaitForChild("EggRenderModels", 10)

-- ==========================================
-- ASSET IDS
-- ==========================================

local RawAssetId     = "111413665419179"
local OpenBtnAssetId = "134040538441909"

local function GetAssetImage(id)
    local cleanId = tostring(id):gsub("%D", "")
    local ok, res = pcall(function()
        local obj = game:GetObjects("rbxassetid://" .. cleanId)
        if obj and #obj > 0 and obj[1]:IsA("Decal") then return obj[1].Texture end
    end)
    return (ok and res and res ~= "" and res)
        or ("rbxthumb://type=Asset&id=" .. cleanId .. "&w=420&h=420")
end

local LogoId    = GetAssetImage(RawAssetId)
local OpenBtnId = GetAssetImage(OpenBtnAssetId)

-- ==========================================
-- CONFIG
-- ==========================================

local RANGE = 35

local BuyEggList = {
    { id = "i1", active = false, name = "Basic Rare (50c)"    },
    { id = "i2", active = false, name = "Quality Epic (100c)" },
    { id = "i3", active = false, name = "Elite Legend (150c)" },
    { id = "i4", active = false, name = "Super Mythic (250c)" },
}

-- ==========================================
-- STATE
-- ==========================================

local FARM = {
    farmActive    = false,
    walkActive    = false,
    vaultActive   = false,
    bypassActive  = false,
    collectActive = false,
    buyActive     = false,
    hitCount      = 0,
}

local farmConn    = nil
local walkConn    = nil
local vaultConn   = nil
local bypassConn  = nil
local collectTask = nil
local buyTask     = nil

-- ==========================================
-- HELPERS
-- ==========================================

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getNearestEgg()
    local hrp = getHRP()
    if not hrp or not eggFolder then return nil end
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(eggFolder:GetChildren()) do
        local hb = obj:FindFirstChild("Hitbox")
        if obj:IsA("Model") and hb then
            local d = (hrp.Position - hb.Position).Magnitude
            if d < bestDist then bestDist = d; best = hb.Position end
        end
    end
    return best
end

-- ==========================================
-- FARM LOGIC
-- ==========================================

local function startFarm()
    if farmConn then farmConn:Disconnect() end
    farmConn = RunService.Heartbeat:Connect(function()
        if not FARM.farmActive or not requestRF or not eggFolder then return end
        local hrp = getHRP(); if not hrp then return end
        local batch = {}
        for _, obj in ipairs(eggFolder:GetChildren()) do
            local hb = obj:FindFirstChild("Hitbox")
            if obj:IsA("Model") and hb then
                if (hrp.Position - hb.Position).Magnitude <= RANGE then
                    batch[#batch + 1] = obj.Name
                end
            end
        end
        if #batch > 0 then
            FARM.hitCount = FARM.hitCount + #batch
            pcall(function() requestRF:InvokeServer(batch) end)
        end
    end)
end

local function stopFarm()
    if farmConn then farmConn:Disconnect(); farmConn = nil end
end

local function startWalk()
    if walkConn then walkConn:Disconnect() end
    walkConn = RunService.Heartbeat:Connect(function()
        if not FARM.walkActive then return end
        local hrp = getHRP(); local hum = getHum()
        if not hrp or not hum or not eggFolder then return end
        local target = getNearestEgg()
        if not target then return end
        if (hrp.Position - target).Magnitude > RANGE * 0.6 then
            hum:MoveTo(target)
        else
            local farthest, farthestDist = nil, 0
            for _, obj in ipairs(eggFolder:GetChildren()) do
                local hb = obj:FindFirstChild("Hitbox")
                if obj:IsA("Model") and hb then
                    local d = (hrp.Position - hb.Position).Magnitude
                    if d > farthestDist and d <= RANGE * 2 then
                        farthestDist = d; farthest = hb.Position
                    end
                end
            end
            if farthest then hum:MoveTo(farthest) end
        end
    end)
end

local function stopWalk()
    if walkConn then walkConn:Disconnect(); walkConn = nil end
    local hrp = getHRP(); local hum = getHum()
    if hum and hrp then hum:MoveTo(hrp.Position) end
end

local function startVault()
    if vaultConn then vaultConn:Disconnect() end
    vaultConn = RunService.Heartbeat:Connect(function()
        if not FARM.vaultActive or not vaultRF then return end
        local hrp = getHRP(); if not hrp then return end
        for _, contName in ipairs({ "Eggs", "EggRenderModels" }) do
            local cont = workspace:FindFirstChild(contName)
            if cont then
                for _, obj in ipairs(cont:GetDescendants()) do
                    if (obj:IsA("Model") or obj:IsA("BasePart"))
                        and obj.Name:find("-") and #obj.Name == 36 then
                        local part = (obj:IsA("BasePart") and obj)
                            or obj.PrimaryPart
                            or obj:FindFirstChildWhichIsA("BasePart")
                        if part and (part.Position - hrp.Position).Magnitude <= 150 then
                            task.spawn(function()
                                pcall(function() vaultRF:InvokeServer(obj.Name) end)
                            end)
                        end
                    end
                end
            end
        end
    end)
end

local function stopVault()
    if vaultConn then vaultConn:Disconnect(); vaultConn = nil end
end

local function startBypass()
    pcall(function()
        local world = workspace:FindFirstChild("World")
        if world then
            for _, n in ipairs({ "PurchaseWall_Zone3", "PurchaseWall_Zone2" }) do
                local w = world:FindFirstChild(n); if w then w:Destroy() end
            end
        end
    end)
    if bypassConn then bypassConn:Disconnect() end
    bypassConn = RunService.Heartbeat:Connect(function()
        if not FARM.bypassActive then return end
        local char = LocalPlayer.Character; if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.CanCollide then
                p.CanCollide = false
            end
        end
    end)
end

local function stopBypass()
    if bypassConn then bypassConn:Disconnect(); bypassConn = nil end
end

local function startCollect()
    if collectTask then task.cancel(collectTask) end
    collectTask = task.spawn(function()
        while FARM.collectActive do
            pcall(function()
                if not collectRF then return end
                for i = 1, 60 do
                    task.spawn(function()
                        pcall(function() collectRF:InvokeServer(i) end)
                    end)
                end
            end)
            task.wait(0.5)
        end
    end)
end

local function stopCollect()
    FARM.collectActive = false
end

local function startBuy()
    if buyTask then task.cancel(buyTask) end
    buyTask = task.spawn(function()
        while FARM.buyActive do
            pcall(function()
                if not purchaseRF then return end
                for _, egg in ipairs(BuyEggList) do
                    if egg.active then
                        purchaseRF:InvokeServer(egg.id, 1)
                        task.wait(0.1)
                    end
                end
            end)
            task.wait(0.5)
        end
    end)
end

local function stopBuy()
    FARM.buyActive = false
end

LocalPlayer.CharacterAdded:Connect(function()
    FARM.farmActive = false; FARM.walkActive = false
    FARM.vaultActive = false; FARM.bypassActive = false
    FARM.collectActive = false; FARM.buyActive = false
    FARM.hitCount = 0
    stopFarm(); stopWalk(); stopVault(); stopBypass(); stopCollect(); stopBuy()
end)

-- ==========================================
-- GUI
-- ==========================================

local targetParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

for _, old in ipairs({ "JenFarmGui" }) do
    local f = targetParent:FindFirstChild(old); if f then f:Destroy() end
end

local Theme = {
    BG        = Color3.fromRGB(20, 12, 28),
    Card      = Color3.fromRGB(36, 22, 48),
    Border    = Color3.fromRGB(236, 72, 153),
    Purple    = Color3.fromRGB(168, 85, 247),
    Active    = Color3.fromRGB(219, 39, 119),
    Inactive  = Color3.fromRGB(42, 26, 56),
    TextOn    = Color3.fromRGB(255, 255, 255),
    TextOff   = Color3.fromRGB(190, 160, 205),
    TextMuted = Color3.fromRGB(140, 110, 160),
    Pink      = Color3.fromRGB(255, 192, 230),
    Gold      = Color3.fromRGB(255, 210, 100),
}

local SG = Instance.new("ScreenGui")
SG.Name           = "JenFarmGui"
SG.ResetOnSpawn   = false
SG.IgnoreGuiInset = true
SG.DisplayOrder   = 9999
SG.Parent         = targetParent

-- ==========================================
-- OPEN BUTTON (minimised state)
-- ==========================================

local openBtn = Instance.new("TextButton", SG)
openBtn.Size                 = UDim2.new(0, 40, 0, 40)
openBtn.Position             = UDim2.new(0, 12, 0.5, -20)
openBtn.BackgroundColor3     = Theme.BG
openBtn.BackgroundTransparency = 0.2
openBtn.Text                 = ""
openBtn.Visible              = false
openBtn.ZIndex               = 2000
openBtn.Active               = true
openBtn.Draggable            = true
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
local obs = Instance.new("UIStroke", openBtn)
obs.Color = Theme.Border; obs.Thickness = 2
local obImg = Instance.new("ImageLabel", openBtn)
obImg.Size               = UDim2.new(0, 30, 0, 30)
obImg.Position           = UDim2.new(0.5, -15, 0.5, -15)
obImg.BackgroundTransparency = 1
obImg.Image              = OpenBtnId
obImg.ScaleType          = Enum.ScaleType.Fit
obImg.ZIndex             = 2001

-- ==========================================
-- MAIN WINDOW
-- ==========================================

local WIN_W    = 200
local HEADER_H = 52   -- logo + title + subtitle
local HITBAR_H = 20
local FOOTER_H = 22
local SCROLL_H = 260  -- visible scroll area height
local WIN_H    = HEADER_H + HITBAR_H + SCROLL_H + FOOTER_H

local win = Instance.new("Frame", SG)
win.Name                   = "MainWin"
win.Size                   = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position               = UDim2.new(0, 12, 0.5, -(WIN_H / 2))
win.BackgroundColor3       = Theme.BG
win.BackgroundTransparency = 0.15
win.BorderSizePixel        = 0
win.Active                 = true
win.Draggable              = true
win.ClipsDescendants       = true
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local ws = Instance.new("UIStroke", win)
ws.Color = Theme.Border; ws.Thickness = 1.6

-- ==========================================
-- HEADER
-- ==========================================

local header = Instance.new("Frame", win)
header.Size                   = UDim2.new(1, 0, 0, HEADER_H)
header.Position               = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3       = Theme.Card
header.BackgroundTransparency = 0.3
header.BorderSizePixel        = 0

-- Logo
local hLogo = Instance.new("ImageLabel", header)
hLogo.Size                 = UDim2.new(0, 28, 0, 28)
hLogo.Position             = UDim2.new(0, 7, 0.5, -14)
hLogo.BackgroundTransparency = 1
hLogo.Image                = LogoId
hLogo.ScaleType            = Enum.ScaleType.Fit

-- Title: Break a Brainrot Egg
local hTitle = Instance.new("TextLabel", header)
hTitle.Size                = UDim2.new(1, -80, 0, 18)
hTitle.Position            = UDim2.new(0, 40, 0, 7)
hTitle.BackgroundTransparency = 1
hTitle.Text                = "Break a Brainrot Egg"
hTitle.TextColor3          = Theme.Pink
hTitle.TextSize            = 11
hTitle.Font                = Enum.Font.GothamBold
hTitle.TextXAlignment      = Enum.TextXAlignment.Left
hTitle.TextTruncate        = Enum.TextTruncate.AtEnd

-- Subtitle: JEN FARM
local hSub = Instance.new("TextLabel", header)
hSub.Size                  = UDim2.new(1, -80, 0, 14)
hSub.Position              = UDim2.new(0, 40, 0, 27)
hSub.BackgroundTransparency = 1
hSub.Text                  = "JEN FARM"
hSub.TextColor3            = Theme.TextMuted
hSub.TextSize              = 9
hSub.Font                  = Enum.Font.GothamSemibold
hSub.TextXAlignment        = Enum.TextXAlignment.Left

-- Min button
local minBtn = Instance.new("TextButton", header)
minBtn.Size             = UDim2.new(0, 18, 0, 18)
minBtn.Position         = UDim2.new(1, -42, 0.5, -9)
minBtn.BackgroundColor3 = Color3.fromRGB(55, 35, 75)
minBtn.Text             = "-"
minBtn.TextColor3       = Theme.TextOn
minBtn.TextSize         = 13
minBtn.Font             = Enum.Font.GothamBold
minBtn.BorderSizePixel  = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

-- Close button
local closeBtn = Instance.new("TextButton", header)
closeBtn.Size             = UDim2.new(0, 18, 0, 18)
closeBtn.Position         = UDim2.new(1, -21, 0.5, -9)
closeBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize         = 9
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

-- ==========================================
-- HIT COUNTER BAR
-- ==========================================

local hitBar = Instance.new("Frame", win)
hitBar.Size                   = UDim2.new(1, 0, 0, HITBAR_H)
hitBar.Position               = UDim2.new(0, 0, 0, HEADER_H)
hitBar.BackgroundColor3       = Color3.fromRGB(30, 16, 40)
hitBar.BackgroundTransparency = 0.3
hitBar.BorderSizePixel        = 0

local hitLabel = Instance.new("TextLabel", hitBar)
hitLabel.Size                 = UDim2.fromScale(1, 1)
hitLabel.BackgroundTransparency = 1
hitLabel.Text                 = "Hits this session: 0"
hitLabel.TextColor3           = Theme.Gold
hitLabel.TextSize             = 10
hitLabel.Font                 = Enum.Font.GothamBold

RunService.Heartbeat:Connect(function()
    hitLabel.Text = "Hits this session: " .. FARM.hitCount
end)

-- ==========================================
-- SCROLL FRAME
-- ==========================================

local scrollTop = HEADER_H + HITBAR_H

local scroll = Instance.new("ScrollingFrame", win)
scroll.Size                   = UDim2.new(1, 0, 0, SCROLL_H)
scroll.Position               = UDim2.new(0, 0, 0, scrollTop)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = Theme.Border
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.ScrollingDirection     = Enum.ScrollingDirection.Y
scroll.ClipsDescendants       = true

local sLayout = Instance.new("UIListLayout", scroll)
sLayout.SortOrder = Enum.SortOrder.LayoutOrder
sLayout.Padding   = UDim.new(0, 4)

local sPad = Instance.new("UIPadding", scroll)
sPad.PaddingTop    = UDim.new(0, 6)
sPad.PaddingLeft   = UDim.new(0, 6)
sPad.PaddingRight  = UDim.new(0, 9)
sPad.PaddingBottom = UDim.new(0, 6)

-- ==========================================
-- FOOTER — made by jenicakes
-- ==========================================

local footer = Instance.new("Frame", win)
footer.Size                   = UDim2.new(1, 0, 0, FOOTER_H)
footer.Position               = UDim2.new(0, 0, 1, -FOOTER_H)
footer.BackgroundColor3       = Theme.Card
footer.BackgroundTransparency = 0.4
footer.BorderSizePixel        = 0

local footerDivider = Instance.new("Frame", footer)
footerDivider.Size            = UDim2.new(1, 0, 0, 1)
footerDivider.Position        = UDim2.new(0, 0, 0, 0)
footerDivider.BackgroundColor3 = Theme.Border
footerDivider.BackgroundTransparency = 0.6
footerDivider.BorderSizePixel = 0

local footerLabel = Instance.new("TextLabel", footer)
footerLabel.Size              = UDim2.new(1, 0, 1, -1)
footerLabel.Position          = UDim2.new(0, 0, 0, 1)
footerLabel.BackgroundTransparency = 1
footerLabel.Text              = "made by jenicakes"
footerLabel.TextColor3        = Theme.TextMuted
footerLabel.TextSize          = 9
footerLabel.Font              = Enum.Font.GothamSemibold
footerLabel.TextXAlignment    = Enum.TextXAlignment.Center

-- ==========================================
-- TOGGLE BUILDER
-- ==========================================

local function makeToggle(order, labelOff, labelOn, onEnable, onDisable)
    local btn = Instance.new("TextButton", scroll)
    btn.Size                   = UDim2.new(1, 0, 0, 28)
    btn.LayoutOrder            = order
    btn.BackgroundColor3       = Theme.Inactive
    btn.BackgroundTransparency = 0.2
    btn.Text                   = labelOff
    btn.TextColor3             = Theme.TextOff
    btn.TextSize               = 10
    btn.Font                   = Enum.Font.GothamSemibold
    btn.BorderSizePixel        = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", btn)
    s.Color       = Theme.Purple
    s.Thickness   = 1
    s.Transparency = 0.6

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            btn.Text             = labelOn
            btn.BackgroundColor3 = Theme.Active
            btn.TextColor3       = Theme.TextOn
            s.Color              = Theme.Border
            s.Transparency       = 0.2
            onEnable()
        else
            btn.Text             = labelOff
            btn.BackgroundColor3 = Theme.Inactive
            btn.TextColor3       = Theme.TextOff
            s.Color              = Theme.Purple
            s.Transparency       = 0.6
            onDisable()
        end
    end)
    return btn
end

local function makeSep(order, text)
    local lbl = Instance.new("TextLabel", scroll)
    lbl.Size                   = UDim2.new(1, 0, 0, 14)
    lbl.LayoutOrder            = order
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text
    lbl.TextColor3             = Theme.TextMuted
    lbl.TextSize               = 9
    lbl.Font                   = Enum.Font.GothamSemibold
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
end

-- ==========================================
-- FEATURE TOGGLES
-- ==========================================

makeSep(0, "── Key Vault ──")

makeToggle(1, "Auto Farm: OFF", "Auto Farm: ON",
    function() FARM.farmActive = true;    startFarm()    end,
    function() FARM.farmActive = false;   stopFarm()     end)

makeToggle(2, "Auto Walk: OFF", "Auto Walk: ON",
    function() FARM.walkActive = true;    startWalk()    end,
    function() FARM.walkActive = false;   stopWalk()     end)

makeToggle(3, "Hit Egg Vault: OFF", "Hit Egg Vault: ON",
    function() FARM.vaultActive = true;   startVault()   end,
    function() FARM.vaultActive = false;  stopVault()    end)

makeToggle(4, "Bypass Zones: OFF", "Bypass Zones: ON",
    function() FARM.bypassActive = true;  startBypass()  end,
    function() FARM.bypassActive = false; stopBypass()   end)

makeToggle(5, "Collect Money: OFF", "Collect Money: ON",
    function() FARM.collectActive = true;  startCollect() end,
    function() FARM.collectActive = false; stopCollect()  end)

makeSep(6, "── Buy Eggs ──")

for i, egg in ipairs(BuyEggList) do
    local eBtn = Instance.new("TextButton", scroll)
    eBtn.Size                   = UDim2.new(1, 0, 0, 24)
    eBtn.LayoutOrder            = 6 + i
    eBtn.BackgroundColor3       = Theme.Inactive
    eBtn.BackgroundTransparency = 0.2
    eBtn.Text                   = "[ ] " .. egg.name
    eBtn.TextColor3             = Theme.TextOff
    eBtn.TextSize               = 9
    eBtn.Font                   = Enum.Font.GothamSemibold
    eBtn.BorderSizePixel        = 0
    Instance.new("UICorner", eBtn).CornerRadius = UDim.new(0, 6)
    eBtn.MouseButton1Click:Connect(function()
        egg.active            = not egg.active
        eBtn.Text             = egg.active and ("[✓] " .. egg.name) or ("[ ] " .. egg.name)
        eBtn.TextColor3       = egg.active and Theme.TextOn or Theme.TextOff
        eBtn.BackgroundColor3 = egg.active and Color3.fromRGB(30, 20, 40) or Theme.Inactive
    end)
end

makeToggle(11, "Auto Buy: OFF", "Auto Buy: ON",
    function() FARM.buyActive = true;  startBuy()  end,
    function() FARM.buyActive = false; stopBuy()   end)

-- ==========================================
-- MIN / CLOSE / OPEN
-- ==========================================

minBtn.MouseButton1Click:Connect(function()
    win.Visible     = false
    openBtn.Visible = true
end)

openBtn.MouseButton1Click:Connect(function()
    openBtn.Visible = false
    win.Visible     = true
end)

closeBtn.MouseButton1Click:Connect(function()
    SG:Destroy()
end)
