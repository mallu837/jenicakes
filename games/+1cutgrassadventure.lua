local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TeleportService = game:GetService("TeleportService")

local lp = Players.LocalPlayer

-- Clean up any existing hub instances
if getgenv().JenicakesHub and type(getgenv().JenicakesHub.Unload) == "function" then
    pcall(function() getgenv().JenicakesHub:Unload() end)
end

-- ==========================================
-- 1. CONFIGURATION & STATE
-- ==========================================
local Cfg = {
    -- Farm & Loot
    strength = false,
    strengthDelay = 0.05,
    autoLoot = false,
    lootMagnetRadius = 500,
    lootFilterEnabled = true,
    selectedRarities = {"Mythic"},
    minSellPrice = 0,

    -- Sell Settings
    sell = false,
    pauseSell = false,
    sellThreshold = 100,

    -- Player & Rebirth
    speedEnabled = false,
    speedValue = 50,
    autoRebirth = false,

    -- Shop Settings
    autoBuyCutter = false,
    selectedCutters = {},
    autoBuyAura = false,
    selectedAuras = {},

    -- Travel Settings
    targetWorld = 1,

    -- Misc Settings
    hideGrass = false,
    instantPrompts = true,
    antiAfk = true,
    autoRejoin = false,
}

local Hub = {
    Version = "1.0.0",
    Running = true,
    Window = nil,
    WindUI = nil,
    Connections = {},
    Settings = Cfg
}

getgenv().JenicakesHub = Hub

-- Data Tables
local RarityTiers = {
    Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, 
    Mythic = 6, Secret = 7, Godly = 8, Divine = 9, Celestial = 10, 
    Eternal = 11, Transcendance = 12, Cosmic = 13, Ascendant = 14, 
    Primordial = 15, Empyrean = 16, Omniversal = 17, Singularity = 18, 
    Exalted = 19, Infinite = 20, Genesis = 21, Anomalous = 22, 
    Paradox = 23, Absolute = 24
}

local RarityWeights = {
    Common = 10, Uncommon = 20, Rare = 50, Epic = 100, Legendary = 200,
    Mythic = 500, Secret = 1000, Godly = 800, Divine = 2000, Celestial = 3000,
    Eternal = 4000, Transcendance = 5000, Cosmic = 6000, Ascendant = 7000,
    Primordial = 8000, Empyrean = 9000, Omniversal = 10000, Singularity = 12000,
    Exalted = 14000, Infinite = 16000, Genesis = 18000, Anomalous = 20000,
    Paradox = 25000, Absolute = 50000
}

local WorldRequirements = {
    [1] = 1, [2] = 185, [3] = 380, [4] = 570, [5] = 750, [6] = 950
}

local CuttersList = {
    "RustyScythe", "WoodenCutter", "IronScythe", "GoldenCutter", 
    "DiamondScythe", "ButcherKnife", "LaserCutter", "VoidBlade"
}

local AurasList = {
    "RedAura", "BlueAura", "GreenAura", "GoldenAura", 
    "DarkAura", "RainbowAura", "CosmicAura"
}

-- Internal State Variables
local nextClick, nextUpgrade, nextRebirth, nextLoot, nextGearBuy = 0, 0, 0, 0, 0
local upgradeBackoff = 0
local isSellingInProgress = false
local lastFarmCFrame = nil
local antiAfkCon = nil
local currentStatus = "Idle"
local statusParagraph = nil

-- ==========================================
-- 2. REMOTE FINDER
-- ==========================================
local Svc = nil
local function resolveServices()
    pcall(function()
        local idx = ReplicatedStorage:WaitForChild("Packages", 4):WaitForChild("_Index", 4)
        for _, child in ipairs(idx:GetChildren()) do
            if child.Name:match("knit") and child:FindFirstChild("knit") and child.knit:FindFirstChild("Services") then
                Svc = child.knit.Services
                return
            end
        end
    end)
    if not Svc then
        pcall(function()
            if ReplicatedStorage:FindFirstChild("Services") then Svc = ReplicatedStorage.Services end
        end)
    end
end
resolveServices()

local function findRemote(svcNames, folderType, remoteNames)
    if type(svcNames) == "string" then svcNames = {svcNames} end
    if type(remoteNames) == "string" then remoteNames = {remoteNames} end
    
    if Svc then
        for _, sName in ipairs(svcNames) do
            local s = Svc:FindFirstChild(sName)
            if s then
                local f = s:FindFirstChild(folderType)
                if f then
                    for _, rName in ipairs(remoteNames) do
                        local r = f:FindFirstChild(rName)
                        if r then return r end
                    end
                end
            end
        end
    end

    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        for _, rName in ipairs(remoteNames) do
            if d.Name == rName then
                if folderType == "RE" and d:IsA("RemoteEvent") then return d end
                if folderType == "RF" and d:IsA("RemoteFunction") then return d end
            end
        end
    end
    return nil
end

local R = {
    StrengthClick = findRemote("StrengthService", "RE", {"ClickRequested", "Click"}),
    SellLoot = findRemote("DataService", "RF", {"SellAllBackpackLoot", "SellLoot", "Sell"}),
    Rebirth = findRemote({"RebirtService", "RebirthService"}, "RE", {"RebirthButtonClicked", "Rebirth"}),
    GetRebirth = findRemote({"RebirtService", "RebirthService"}, "RF", {"GetState", "GetRebirthState"}),
    UpgSpeed = findRemote("UpgradesService", "RE", {"SpeedButtonClicked", "SpeedUpgrade"}),
    UpgCarry = findRemote("UpgradesService", "RE", {"CarryButtonClicked", "CarryUpgrade"}),
    UpgAtkSpeed = findRemote("UpgradesService", "RE", {"AttackSpeedButtonClicked", "AttackSpeedUpgrade"}),
    UpgAtkRange = findRemote("UpgradesService", "RE", {"AttackRangeButtonClicked", "AttackRangeUpgrade"}),
    NotEnoughMoney = findRemote("UpgradesService", "RE", {"NotEnoughMoney"}),
    GetBackpack = findRemote("DataService", "RF", {"GetBackpackSlotsSummary", "GetBackpack"}),
    BuyCutter = findRemote("CuttersShopService", "RF", {"BuyCutter"}),
    BuyAura = findRemote("AuraService", "RF", {"BuyOrToggleAura"}),
    TeleportToWorld = findRemote("WorldService", "RF", {"TeleportToWorld"}),
}

-- ==========================================
-- 3. HELPER FUNCTIONS
-- ==========================================
local function updateStatus(text)
    currentStatus = text
    if statusParagraph then
        pcall(function() statusParagraph:SetDesc("Current Status: " .. currentStatus) end)
    end
end

local function getPlayerLevel()
    local stats = lp:FindFirstChild("leaderstats")
    if stats then
        local lvl = stats:FindFirstChild("Level") or stats:FindFirstChild("Lvl")
        if lvl then return tonumber(lvl.Value) or 0 end
    end
    return tonumber(lp:GetAttribute("Level")) or 0
end

local function setAntiAfk(enabled)
    if getconnections then
        for _, c in ipairs(getconnections(lp.Idled)) do
            pcall(function() c:Disable() end)
            pcall(function() c:Disconnect() end)
        end
    end
    if antiAfkCon then antiAfkCon:Disconnect() antiAfkCon = nil end
    if enabled then
        antiAfkCon = lp.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end
setAntiAfk(Cfg.antiAfk)

local function char()
    local c = lp.Character
    if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid") then return c end
    return nil
end

local function hrp() 
    local c = char() 
    return c and c:FindFirstChild("HumanoidRootPart") 
end

local function getBackpackInfo()
    local count, cap = 0, 0
    local attrCount = lp:GetAttribute("BackpackCount") or lp:GetAttribute("BackpackRaw") or lp:GetAttribute("LootCount") or lp:GetAttribute("Backpack")
    local attrCap = lp:GetAttribute("BackpackCapacity") or lp:GetAttribute("CapacityRaw") or lp:GetAttribute("BackpackMax") or lp:GetAttribute("MaxBackpack")
    if attrCount then count = tonumber(attrCount) or count end
    if attrCap then cap = tonumber(attrCap) or cap end

    if (cap == 0 or count == 0) and R.GetBackpack then
        local ok, s = pcall(R.GetBackpack.InvokeServer, R.GetBackpack)
        if ok and type(s) == "table" then
            count = tonumber(s.Count) or tonumber(s.count) or count
            cap = tonumber(s.Capacity) or tonumber(s.capacity) or tonumber(s.Max) or cap
        end
    end
    local isFull = (cap > 0 and count >= cap)
    local pct = (cap > 0) and math.floor((count / cap) * 100) or 0
    return {count = count, cap = cap, pct = pct, full = isFull}
end

local function teleportToBase()
    local baseBtn = lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("TopGUI") and lp.PlayerGui.TopGUI:FindFirstChild("Top") and lp.PlayerGui.TopGUI.Top:FindFirstChild("BaseButton")
    if baseBtn then
        if firesignal then pcall(firesignal, baseBtn.Activated) pcall(firesignal, baseBtn.MouseButton1Click) end
        if getconnections then
            for _, name in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
                for _, conn in ipairs(getconnections(baseBtn[name])) do pcall(conn.Fire, conn) end
            end
        end
    end
    task.wait(0.1)
    local w1 = Workspace:FindFirstChild("Worlds") and Workspace.Worlds:FindFirstChild("World_1")
    if w1 and hrp() then
        local spawnPart = w1:FindFirstChild("Spawn_Point_1") or w1:FindFirstChild("Spawn") or w1:FindFirstChild("Safe_Zone_0")
        if spawnPart then
            local pos = spawnPart:IsA("BasePart") and spawnPart.Position or spawnPart:GetPivot().Position
            hrp().CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        end
    end
end

local function doSellAtBase()
    if isSellingInProgress then return end
    isSellingInProgress = true
    updateStatus("Selling Loot...")
    local root = hrp()
    if not root then isSellingInProgress = false return end
    lastFarmCFrame = root.CFrame
    teleportToBase()
    task.wait(0.35)
    root = hrp()
    local w1 = Workspace:FindFirstChild("Worlds") and Workspace.Worlds:FindFirstChild("World_1")
    local sellPart = nil
    if w1 then
        local sellModel = w1:FindFirstChild("Sell")
        if sellModel then
            local tp = sellModel:FindFirstChild("TriggerPlace")
            local claim = tp and tp:FindFirstChild("ClaimPart")
            if claim and claim:IsA("BasePart") then sellPart = claim end
        end
    end
    if root and sellPart then
        root.CFrame = CFrame.new(sellPart.Position + Vector3.new(0, 2.5, 0))
        task.wait(0.15)
        pcall(firetouchinterest, root, sellPart, 0)
        pcall(firetouchinterest, root, sellPart, 1)
    end
    if R.SellLoot then
        pcall(R.SellLoot.InvokeServer, R.SellLoot)
        task.wait(0.25)
        pcall(R.SellLoot.InvokeServer, R.SellLoot)
        task.wait(0.2)
    end
    if lastFarmCFrame and hrp() then hrp().CFrame = lastFarmCFrame end
    isSellingInProgress = false
    updateStatus("Farming...")
end

local function makePromptInstant(prompt)
    if Cfg.instantPrompts and prompt and prompt:IsA("ProximityPrompt") then
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
        end)
    end
end
for _, d in ipairs(Workspace:GetDescendants()) do if d:IsA("ProximityPrompt") then makePromptInstant(d) end end
Workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then makePromptInstant(d) end end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    if Cfg.instantPrompts then prompt.HoldDuration = 0 pcall(fireproximityprompt, prompt) end
end)

local function getPrioritizedLootPrompts()
    local prompts = {}
    local root = hrp()
    local rPos = root and root.Position or Vector3.zero
    local searchContainers = {Workspace:FindFirstChild("Zones"), Workspace}

    for _, container in ipairs(searchContainers) do
        if container then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d:GetAttribute("LootPickupPrompt") == true then
                    local attachment = d.Parent
                    local basePart = attachment and attachment.Parent
                    local lootModel = basePart and basePart.Parent
                    local pos = nil
                    if attachment and attachment:IsA("Attachment") then pos = attachment.WorldPosition
                    elseif basePart and basePart:IsA("BasePart") then pos = basePart.Position
                    elseif lootModel and lootModel:IsA("Model") then pos = lootModel:GetPivot().Position end
                    if pos then
                        local dist = (pos - rPos).Magnitude
                        if dist <= Cfg.lootMagnetRadius then
                            local weight = 50
                            local canPickup = true
                            if lootModel then
                                local price = tonumber(lootModel:GetAttribute("LootSellPrice")) or 0
                                local rarity = tostring(lootModel:GetAttribute("LootRarity") or "Common")
                                if Cfg.lootFilterEnabled then
                                    local isSelected = false
                                    for _, selected in ipairs(Cfg.selectedRarities) do
                                        if selected == rarity then isSelected = true break end
                                    end
                                    if not isSelected then canPickup = false end
                                    if price < Cfg.minSellPrice then canPickup = false end
                                end
                                weight = (RarityWeights[rarity] or 50) + (price / 1000)
                            end
                            if canPickup then
                                table.insert(prompts, {prompt = d, pos = pos, dist = dist, weight = weight})
                            end
                        end
                    end
                end
            end
            if container.Name == "Zones" and #prompts > 0 then break end
        end
    end
    table.sort(prompts, function(a, b) if a.weight ~= b.weight then return a.weight > b.weight end return a.dist < b.dist end)
    return prompts
end

local function doLootCollection()
    local root = hrp()
    if not root or not Cfg.autoLoot then return false end
    local prompts = getPrioritizedLootPrompts()
    if #prompts == 0 then return false end
    local target = prompts[1]
    if target and target.pos then
        updateStatus("Looting: " .. target.prompt.Parent.Parent.Name)
        root.CFrame = CFrame.new(target.pos + Vector3.new(0, 2.5, 0))
        task.wait(0.08)
        pcall(fireproximityprompt, target.prompt)
        return true
    end
    return false
end

local function doUpgrades()
    if tick() < upgradeBackoff then return end
    if Cfg.upgAll or Cfg.upgSpeed then if R.UpgSpeed then pcall(R.UpgSpeed.FireServer, R.UpgSpeed) end end
    if Cfg.upgAll or Cfg.upgCarry then if R.UpgCarry then pcall(R.UpgCarry.FireServer, R.UpgCarry) end end
    if Cfg.upgAll or Cfg.upgAtkSpeed then if R.UpgAtkSpeed then pcall(R.UpgAtkSpeed.FireServer, R.UpgAtkSpeed) end end
    if Cfg.upgAll or Cfg.upgAtkRange then if R.UpgAtkRange then pcall(R.UpgAtkRange.FireServer, R.UpgAtkRange) end end
end

local function doAutoBuyGear()
    if tick() < nextGearBuy then return end
    
    if Cfg.autoBuyCutter and R.BuyCutter then
        for _, cutter in ipairs(Cfg.selectedCutters) do
            pcall(function() R.BuyCutter:InvokeServer(cutter) end)
            updateStatus("Buying Cutter: " .. cutter)
            task.wait(0.1)
        end
    end
    
    if Cfg.autoBuyAura and R.BuyAura then
        for _, aura in ipairs(Cfg.selectedAuras) do
            pcall(function() R.BuyAura:InvokeServer(aura) end)
            updateStatus("Buying Aura: " .. aura)
            task.wait(0.1)
        end
    end
    
    nextGearBuy = tick() + 5
end

local function doTravelToWorld(worldNum)
    if R.TeleportToWorld then
        local myLevel = getPlayerLevel()
        local requiredLevel = WorldRequirements[worldNum] or 1
        if myLevel < requiredLevel then
            updateStatus("Underleveled for World " .. worldNum)
            return
        end
        updateStatus("Traveling to World " .. worldNum)
        pcall(function() R.TeleportToWorld:InvokeServer(worldNum) end)
        task.wait(3)
    end
end

local function doRebirth()
    if not Cfg.autoRebirth or not R.Rebirth then return end
    updateStatus("Checking Rebirth...")
    if R.GetRebirth then
        local ok, st = pcall(R.GetRebirth.InvokeServer, R.GetRebirth)
        if ok and type(st) == "table" and st.CanRebirth == true then pcall(R.Rebirth.FireServer, R.Rebirth) end
    else
        pcall(R.Rebirth.FireServer, R.Rebirth)
    end
end

if R.NotEnoughMoney then
    pcall(function() R.NotEnoughMoney.Connect(R.NotEnoughMoney, function() upgradeBackoff = tick() + 6 end) end)
end

-- ==========================================
-- 4. WINDUI INTERFACE SETUP
-- ==========================================
local windUI = loadstring(game:HttpGet("https://github.com/mallu837/JenicakesUI/releases/latest/download/main.lua"))()
Hub.WindUI = windUI

local jenicakesWindow = windUI:CreateWindow({
    Title = "Jenicakes Hub",
    Icon = "sparkles",
    Author = "+1 Cut Grass Adventure",
    Folder = "JenicakesHub_Config",
    Size = UDim2.fromOffset(620, 500),
    Transparent = true,
    Theme = "Dark",
    Acrylic = false,
    Resizable = true,
})

Hub.Window = jenicakesWindow
pcall(function() jenicakesWindow:SetToTheCenter() end)

---------------------------------------------------------
-- TAB 1: MAIN TAB
---------------------------------------------------------
local mainTab = jenicakesWindow:Tab({ Title = "Main", Icon = "home" })

mainTab:Section({ Title = "Status" })
statusParagraph = mainTab:Paragraph({
    Title = "Script State",
    Desc = "Current Status: " .. currentStatus
})

mainTab:Section({ Title = "Farming & Loot" })

mainTab:Toggle({
    Title = "Auto Strength / Click",
    Desc = "Automatically mine grass",
    Value = Cfg.strength,
    Callback = function(val) Cfg.strength = val end
})

mainTab:Toggle({
    Title = "Auto Collect Loot",
    Desc = "Automatically pickup nearby dropped items",
    Value = Cfg.autoLoot,
    Callback = function(val) Cfg.autoLoot = val end
})

mainTab:Toggle({
    Title = "Enable Loot Filter",
    Desc = "Only pickup loot matching filters",
    Value = Cfg.lootFilterEnabled,
    Callback = function(val) Cfg.lootFilterEnabled = val end
})

local rarityList = {}
for name, _ in pairs(RarityTiers) do table.insert(rarityList, name) end
table.sort(rarityList, function(a, b) return RarityTiers[a] < RarityTiers[b] end)

mainTab:Dropdown({
    Title = "Select Rarities to Collect",
    Multi = true,
    Values = rarityList,
    Value = Cfg.selectedRarities,
    Callback = function(val)
        if type(val) == "table" then Cfg.selectedRarities = val else Cfg.selectedRarities = {val} end
    end
})

mainTab:Slider({
    Title = "Loot Scan Radius",
    Value = { Min = 50, Max = 2000, Default = Cfg.lootMagnetRadius },
    Step = 25,
    Callback = function(val) Cfg.lootMagnetRadius = val end
})

mainTab:Section({ Title = "Rebirth" })
mainTab:Toggle({
    Title = "Auto Rebirth",
    Desc = "Automatically rebirth when available",
    Value = Cfg.autoRebirth,
    Callback = function(val) Cfg.autoRebirth = val end
})

---------------------------------------------------------
-- TAB 2: SELL TAB
---------------------------------------------------------
local sellTab = jenicakesWindow:Tab({ Title = "Sell", Icon = "shopping-bag" })

sellTab:Section({ Title = "Auto Sell Settings" })

sellTab:Toggle({
    Title = "Auto Sell Loot",
    Desc = "Automatically teleport to base and sell items",
    Value = Cfg.sell,
    Callback = function(val) Cfg.sell = val end
})

sellTab:Slider({
    Title = "Sell Threshold (%)",
    Value = { Min = 10, Max = 100, Default = Cfg.sellThreshold },
    Step = 5,
    Callback = function(val) Cfg.sellThreshold = val end
})

sellTab:Slider({
    Title = "Minimum Item Price Cutoff",
    Value = { Min = 0, Max = 10000, Default = Cfg.minSellPrice },
    Step = 100,
    Callback = function(val) Cfg.minSellPrice = val end
})

---------------------------------------------------------
-- TAB 3: SHOP TAB
---------------------------------------------------------
local shopTab = jenicakesWindow:Tab({ Title = "Shop", Icon = "shopping-cart" })

shopTab:Section({ Title = "Cutter Shop" })

shopTab:Toggle({
    Title = "Auto Buy Cutters",
    Desc = "Automatically purchase selected cutters",
    Value = Cfg.autoBuyCutter,
    Callback = function(val) Cfg.autoBuyCutter = val end
})

shopTab:Dropdown({
    Title = "Select Cutters to Buy",
    Multi = true,
    Values = CuttersList,
    Value = Cfg.selectedCutters,
    Callback = function(val)
        if type(val) == "table" then Cfg.selectedCutters = val else Cfg.selectedCutters = {val} end
    end
})

shopTab:Section({ Title = "Aura Shop" })

shopTab:Toggle({
    Title = "Auto Buy Auras",
    Desc = "Automatically purchase selected auras",
    Value = Cfg.autoBuyAura,
    Callback = function(val) Cfg.autoBuyAura = val end
})

shopTab:Dropdown({
    Title = "Select Auras to Buy",
    Multi = true,
    Values = AurasList,
    Value = Cfg.selectedAuras,
    Callback = function(val)
        if type(val) == "table" then Cfg.selectedAuras = val else Cfg.selectedAuras = {val} end
    end
})

---------------------------------------------------------
-- TAB 4: TELEPORT TAB
---------------------------------------------------------
local tpTab = jenicakesWindow:Tab({ Title = "Teleport", Icon = "map-pin" })

tpTab:Section({ Title = "World Travel" })

tpTab:Dropdown({
    Title = "Select Target World",
    Values = { "World 1", "World 2", "World 3", "World 4", "World 5", "World 6" },
    Value = "World " .. tostring(Cfg.targetWorld),
    Callback = function(val)
        local num = tonumber(val:match("%d+"))
        if num then Cfg.targetWorld = num end
    end
})

tpTab:Button({
    Title = "Teleport to World",
    Callback = function()
        doTravelToWorld(Cfg.targetWorld)
    end
})

---------------------------------------------------------
-- TAB 5: UPGRADES TAB
---------------------------------------------------------
local upgTab = jenicakesWindow:Tab({ Title = "Upgrades", Icon = "zap" })

upgTab:Section({ Title = "Stat Upgrades" })

upgTab:Toggle({
    Title = "Auto Buy All Upgrades",
    Desc = "Continuously purchase all stat upgrades",
    Value = Cfg.upgAll,
    Callback = function(val) Cfg.upgAll = val end
})

upgTab:Toggle({
    Title = "Buy Speed Upgrade",
    Value = Cfg.upgSpeed,
    Callback = function(val) Cfg.upgSpeed = val end
})

upgTab:Toggle({
    Title = "Buy Carry Upgrade",
    Value = Cfg.upgCarry,
    Callback = function(val) Cfg.upgCarry = val end
})

upgTab:Toggle({
    Title = "Buy Attack Speed Upgrade",
    Value = Cfg.upgAtkSpeed,
    Callback = function(val) Cfg.upgAtkSpeed = val end
})

upgTab:Toggle({
    Title = "Buy Attack Range Upgrade",
    Value = Cfg.upgAtkRange,
    Callback = function(val) Cfg.upgAtkRange = val end
})

---------------------------------------------------------
-- TAB 6: MISC TAB
---------------------------------------------------------
local miscTab = jenicakesWindow:Tab({ Title = "Misc", Icon = "settings" })

miscTab:Section({ Title = "Performance & Automation" })

miscTab:Toggle({
    Title = "Hide Grass (FPS BOOST)",
    Desc = "Hides nearby grass objects to improve client performance",
    Value = Cfg.hideGrass,
    Callback = function(val) Cfg.hideGrass = val end
})

miscTab:Toggle({
    Title = "Instant Prompts",
    Desc = "Removes hold time for all proximity prompts",
    Value = Cfg.instantPrompts,
    Callback = function(val) Cfg.instantPrompts = val end
})

miscTab:Toggle({
    Title = "Anti AFK",
    Desc = "Prevents client from being kicked for idling",
    Value = Cfg.antiAfk,
    Callback = function(val)
        Cfg.antiAfk = val
        setAntiAfk(val)
    end
})

miscTab:Toggle({
    Title = "Auto Rejoin",
    Desc = "Automatically rejoins the server upon disconnection",
    Value = Cfg.autoRejoin,
    Callback = function(val) Cfg.autoRejoin = val end
})

miscTab:Section({ Title = "Community & Support" })

miscTab:Paragraph({
    Title = "Discord Community",
    Desc = "Join our Discord server for updates and script feedback!"
})

miscTab:Button({
    Title = "Copy Discord Invite",
    Callback = function()
        local link = "https://discord.gg/GFZYsspybS"
        if setclipboard then
            setclipboard(link)
        elseif toclipboard then
            toclipboard(link)
        end
    end
})

---------------------------------------------------------
-- UNLOAD FUNCTION
---------------------------------------------------------
function Hub:Unload()
    self.Running = false

    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self.Connections)

    if self.Window and type(self.Window.Destroy) == "function" then
        pcall(function() self.Window:Destroy() end)
    end

    getgenv().JenicakesHub = nil
end

-- ==========================================
-- 5. LOOPS & EXECUTION
-- ==========================================
-- Auto Rejoin Event
lp.OnTeleport:Connect(function()
    if Cfg.autoRejoin then
        task.wait(2)
        TeleportService:Teleport(game.PlaceId, lp)
    end
end)

-- Hide Grass Loop
task.spawn(function()
    while Hub.Running do
        task.wait(1)
        if Cfg.hideGrass then
            local myRoot = hrp()
            if myRoot then
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj.Name:match("Grass") and obj:IsA("BasePart") then
                        local dist = (myRoot.Position - obj.Position).Magnitude
                        if dist < 300 then
                            obj.Transparency = 1
                            obj.CanCollide = false
                        end
                    end
                end
            end
        end
    end
end)

-- Speed Boost Loop
RunService.Heartbeat:Connect(function(dt)
    if not Hub.Running then return end
    local c = char()
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if h and root and Cfg.speedEnabled then
        if h.WalkSpeed ~= Cfg.speedValue then h.WalkSpeed = Cfg.speedValue end
        if h.MoveDirection.Magnitude > 0 then
            local extra = math.max(0, Cfg.speedValue - 16)
            root.CFrame = root.CFrame + (h.MoveDirection * (extra * dt))
        end
    end
end)

-- Main Farm Loop
task.spawn(function()
    task.wait(0.3)
    updateStatus("Idle")
    while Hub.Running do
        local t = tick()
        local c = char()
        local root = hrp()
        if c and root and not isSellingInProgress then
            local bp = getBackpackInfo()
            if Cfg.sell and not Cfg.pauseSell and (bp.full or (bp.cap > 0 and (bp.count >= bp.cap or bp.pct >= Cfg.sellThreshold))) then
                doSellAtBase()
            else
                if Cfg.autoLoot and t > nextLoot then
                    if doLootCollection() then nextLoot = t + 0.12 else updateStatus("Farming...") end
                end
                if Cfg.strength and t > nextClick and R.StrengthClick then
                    pcall(R.StrengthClick.FireServer, R.StrengthClick)
                    nextClick = t + Cfg.strengthDelay
                    if currentStatus ~= "Farming..." and not isSellingInProgress then updateStatus("Farming...") end
                end
                if Cfg.autoBuyCutter or Cfg.autoBuyAura then
                    doAutoBuyGear()
                end
            end
            if (Cfg.upgAll or Cfg.upgSpeed or Cfg.upgCarry or Cfg.upgAtkSpeed or Cfg.upgAtkRange) and t > nextUpgrade then 
                doUpgrades() 
                nextUpgrade = t + 2.5 
            end
            if Cfg.autoRebirth and t > nextRebirth then 
                doRebirth() 
                nextRebirth = t + 3.5 
            end
        end
        task.wait(0.12)
    end
end)
