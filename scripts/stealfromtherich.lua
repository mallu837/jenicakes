--// ============================================================
--//  Services & Initialization
--// ============================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Heartbeat   = RunService.Heartbeat

local function SafeCloneRef(inst)
    return inst
end

local RS  = SafeCloneRef(ReplicatedStorage)
local Map = SafeCloneRef(Workspace)

-- Clean up any existing hub instances
if getgenv().JenicakesHub and type(getgenv().JenicakesHub.Unload) == "function" then
    pcall(function() getgenv().JenicakesHub:Unload() end)
end

-- Helper Utilities
local function IsFunction(fn)
    return type(fn) == "function"
end

local function IsLoaded()
    return getgenv().JenicakesHub and getgenv().JenicakesHub.Running == true
end

--// ============================================================
--//  Game Modules & Remotes
--// ============================================================
local Network          = require(RS:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Network"))
local AreaData         = require(RS.Shared.Data.AreaData)
local TrailData        = require(RS.Shared.Data.TrailData)
local ItemData         = require(RS.Shared.Data.ItemData)
local InfiniteMath     = require(RS.Shared.Utility.InfiniteMath)

local ClientBalanceService
do
    local function findBalanceModule()
        local roots = { RS }
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        if ps then table.insert(roots, ps) end
        for _, root in ipairs(roots) do
            local ok, found = pcall(function()
                return root:FindFirstChild("ClientBalanceService", true)
            end)
            if ok and found and found:IsA("ModuleScript") then
                return found
            end
        end
        return nil
    end

    local module
    for _ = 1, 20 do
        module = findBalanceModule()
        if module then break end
        task.wait(0.5)
    end

    local ok, service = false, nil
    if module then ok, service = pcall(require, module) end
    if ok and service then
        ClientBalanceService = service
    else
        warn("[Jenicakes Hub] ClientBalanceService not found, fallback enabled.")
        ClientBalanceService = { Balance = nil }
    end
end

local REMOTE_PLACE_AT          = RS:WaitForChild("re_PLACE_AT", 30)
local REMOTE_SELL_DO           = RS:WaitForChild("re_SELL_DO", 30)
local RF_SELL_QUOTE            = RS:WaitForChild("rf_SELL_QUOTE", 30)
local REMOTE_PLOT_UPGRADE      = RS:WaitForChild("re_PLOT_UPGRADE", 30)
local REMOTE_TREADMILL_UPGRADE = RS:WaitForChild("re_TREADMILL_UPGRADE", 30)
local RF_ITEM_LOADOUT          = RS:WaitForChild("rf_ITEM_LOADOUT", 30)

assert(REMOTE_PLACE_AT and REMOTE_SELL_DO and RF_SELL_QUOTE and REMOTE_PLOT_UPGRADE
    and REMOTE_TREADMILL_UPGRADE and RF_ITEM_LOADOUT, "Core remotes missing")

--// ============================================================
--//  Data & Lists
--// ============================================================
local ZoneDisplayNames = {}
local ZoneNameToId     = {}
local ZoneIdToName     = {}
local ZoneAreaPart     = {}
local Rarities         = {}
local Trails           = {}

local SELL_MODES        = { "Held", "All" }
local SELL_MODE_ARG    = { Held = "held", All = "all" }
local DEPOSIT_POS        = Vector3.new(2437, 4, -928)
local FALLBACK_SELL_POS  = Vector3.new(2437.8, 5, -860)

do
    local areas = {}
    for _, area in ipairs(AreaData.Areas) do
        if type(area) == "table" and type(area.Id) == "string" then
            table.insert(areas, area)
        end
    end
    table.sort(areas, function(a, b) return (a.Order or 0) < (b.Order or 0) end)

    for _, area in ipairs(areas) do
        local label = area.Id .. " - " .. tostring(area.DisplayName or area.Id)
        table.insert(ZoneDisplayNames, label)
        ZoneNameToId[label] = area.Id
        ZoneIdToName[area.Id] = label
        if type(area.AreaPart) == "string" then
            ZoneAreaPart[area.Id] = area.AreaPart
        end
    end

    for index = 1, 20 do
        local tier = ItemData:GetTierByIndex(index)
        if type(tier) == "table" and type(tier.Name) == "string" then
            table.insert(Rarities, tier.Name)
        else
            break
        end
    end
    if #Rarities == 0 then
        Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
    end

    if type(TrailData.Trails) == "table" then
        for _, trail in ipairs(TrailData.Trails) do
            if type(trail) == "table" and type(trail.Id) == "string" then
                table.insert(Trails, trail)
            end
        end
    end
end

--// ============================================================
--//  Global State & Hub Object
--// ============================================================
local State = {
    Enabled = {
        Steal = false, Place = false, Open = false, EquipBest = false,
        BuyEquipSlot = false, Treadmill = false, UpgradeTreadmill = false,
        UpgradePlot = false, ClaimIndex = false, BuyTrails = false, Sell = false,
    },
    RarityFilter = {},
    ZoneFilter = {},
    SellMode = "All",
    TeleportToSellerWhileSelling = false,
    Gens = {
        Steal = 0, Place = 0, Open = 0, EquipBest = 0, BuyEquipSlot = 0,
        Treadmill = 0, UpgradeTreadmill = 0, UpgradePlot = 0, ClaimIndex = 0,
        BuyTrails = 0, Sell = 0,
    },
    TrailOwned = {},
    StealBurst = 3,
    StealBlocked = {},
    StealStatus = "Idle",
    StealCount = 0,
    LastStealAt = 0, LastPlaceAt = 0, LastOpenAt = 0, LastEquipBestAt = 0,
    LastBuySlotAt = 0, LastTreadmillAt = 0, LastUpgradeTreadmillAt = 0,
    LastUpgradePlotAt = 0, LastClaimIndexAt = 0, LastBuyTrailsAt = 0, LastSellAt = 0,
}

-- Set initial default filters
for _, rarity in ipairs(Rarities) do State.RarityFilter[rarity] = true end
for _, zone in ipairs(ZoneDisplayNames) do
    State.ZoneFilter[zone] = true
    local id = ZoneNameToId[zone]
    if id then State.ZoneFilter[id] = true end
end

local Cfg = {
    antiAfk = true,
    autoRejoin = false,
}

local Hub = {
    Version = "1.0.0",
    Running = true,
    Window = nil,
    WindUI = nil,
    Connections = {},
    Settings = Cfg,
    State = State
}

getgenv().JenicakesHub = Hub

local function Track(fn)
    table.insert(Hub.Connections, fn)
end
Hub.Track = Track

local function Notify(text, duration, icon)
    pcall(function()
        if Hub.Window then
            Hub.Window:Notify({
                Title = "Jenicakes Hub",
                Content = tostring(text),
                Icon = icon or "info",
                Duration = duration or 3,
            })
        end
    end)
end

--// ============================================================
--//  Character & World Helpers
--// ============================================================
local function GetRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    return (root and root:IsA("BasePart")) and root or nil
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function TeleportTo(cf)
    local root = GetRoot()
    if not root then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = cf
    return true
end

local function RequestStream(position)
    if typeof(position) ~= "Vector3" then return end
    pcall(function()
        if IsFunction(LocalPlayer.RequestStreamAroundAsync) then
            task.defer(function()
                pcall(function() LocalPlayer:RequestStreamAroundAsync(position) end)
            end)
        end
    end)
end

local function FirePrompt(prompt)
    if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then return false end
    if not IsFunction(fireproximityprompt) then return false end
    return pcall(fireproximityprompt, prompt)
end

--// ============================================================
--//  Economy Helpers
--// ============================================================
local function GetBalance()
    local balance = ClientBalanceService.Balance
    return balance or InfiniteMath.new(0)
end

local function CanAfford(amount)
    local value = tonumber(amount)
    if not value or value <= 0 then return true end
    local ok, result = pcall(function()
        return GetBalance() >= InfiniteMath.new(value)
    end)
    return ok and result == true
end

--// ============================================================
--//  Plot & Area Helpers
--// ============================================================
local function GetOwnPlot()
    for _, child in ipairs(Map:GetChildren()) do
        if child.Name:match("^Plot Building %d+$") then
            local floor = child:FindFirstChild("floor")
            if floor and floor:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                return child, floor
            end
        end
    end
    return nil, nil
end

local function GetOwnPlotFloor()
    local _, floor = GetOwnPlot()
    return floor
end

local function GetBaseCFrame()
    local _, floor = GetOwnPlot()
    if floor then
        local spawn = floor:FindFirstChild("PlayerSpawn")
        if spawn and spawn:IsA("BasePart") then
            return spawn.CFrame * CFrame.new(0, 3, 0)
        end
        return CFrame.new(floor.Position + Vector3.new(0, floor.Size.Y / 2 + 3, 0))
    end
    return nil
end

local function FindAreaPart(areaId)
    local partName = ZoneAreaPart[areaId]
    if type(partName) ~= "string" or partName == "" then return nil end
    local map = Map:FindFirstChild("Map")
    local roots = { map, Map }
    for _, root in ipairs(roots) do
        if root then
            local found = root:FindFirstChild(partName, true)
            if found and found:IsA("BasePart") then return found end
        end
    end
    return nil
end

local function GetAreaPosition(areaId)
    local part = FindAreaPart(areaId)
    if part then
        return Vector3.new(part.Position.X, part.Position.Y + part.Size.Y / 2 + 3, part.Position.Z)
    end
    local crates = Map:FindFirstChild("Crates")
    if crates then
        for _, child in ipairs(crates:GetChildren()) do
            if child:GetAttribute("AreaId") == areaId then
                local position = child:GetPivot().Position
                return Vector3.new(position.X, position.Y + 3, position.Z)
            end
        end
    end
    return nil
end

--// ============================================================
--//  Fixed Filters & Tool Logic
--// ============================================================
local function RarityAllowed(rarity)
    if type(rarity) ~= "string" or rarity == "" then return true end
    if not State.RarityFilter or next(State.RarityFilter) == nil then return true end
    return State.RarityFilter[rarity] == true
end

local function ZoneAllowed(areaId)
    if type(areaId) ~= "string" or areaId == "" then return true end
    if not State.ZoneFilter or next(State.ZoneFilter) == nil then return true end
    
    if State.ZoneFilter[areaId] == true then return true end
    local label = ZoneIdToName[areaId]
    if label and State.ZoneFilter[label] == true then return true end
    return false
end

local function IsCrateTool(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    if tool:GetAttribute("IsBatTool") or tool:GetAttribute("IsBearTrapTool") or tool:GetAttribute("IsTreadmill") then
        return false
    end
    return tool:GetAttribute("CrateUid") ~= nil
end

local function IsCarryingStolen()
    return LocalPlayer:GetAttribute("CarryingStolen") == true
end

local function GetHeldCrateTool()
    if IsCarryingStolen() then return nil end
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    return IsCrateTool(tool) and tool or nil
end

local function GetCrateTools()
    local list = {}
    if IsCarryingStolen() then return list end
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if IsCrateTool(child) then table.insert(list, child) end
        end
    end
    for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if IsCrateTool(child) then table.insert(list, child) end
    end
    return list
end

local function EquipTool(tool)
    if not (tool and tool.Parent) then return false end
    local humanoid = GetHumanoid()
    if not humanoid then return false end
    if tool.Parent == LocalPlayer.Character then return true end
    return pcall(function() humanoid:EquipTool(tool) end)
end

local PromptCache = setmetatable({}, { __mode = "k" })

local function FastPrompt(prompt)
    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        if prompt.MaxActivationDistance < 40 then
            prompt.MaxActivationDistance = 40
        end
    end)
end

local function FindStealPrompt(model)
    local cached = PromptCache[model]
    if not (cached and cached.Parent and cached:IsDescendantOf(model)) then
        cached = nil
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Steal" then
                cached = descendant
                break
            end
        end
        PromptCache[model] = cached
        if cached then FastPrompt(cached) end
    end
    if cached and cached.Enabled then return cached end
    return nil
end

local function CollectCrates()
    local crates = Map:FindFirstChild("Crates")
    if not crates then return {} end
    local list = {}
    for _, child in ipairs(crates:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsCrate") == true then
            local areaId = child:GetAttribute("AreaId")
            local tier = child:GetAttribute("CrateTier")
            
            -- Strictly check filters before building list
            if ZoneAllowed(areaId) and RarityAllowed(tier) then
                local prompt = FindStealPrompt(child)
                if prompt then
                    table.insert(list, {
                        model = child,
                        areaId = areaId,
                        tier = tier,
                        prompt = prompt,
                        position = child:GetPivot().Position,
                    })
                end
            end
        end
    end
    return list
end

local function StealAnchor(crate)
    local prompt = crate.prompt
    local holder = prompt and prompt.Parent
    if holder then
        if holder:IsA("BasePart") then return holder.Position end
        if holder:IsA("Attachment") then return holder.WorldPosition end
    end
    local ok, pivot = pcall(function() return crate.model:GetPivot().Position end)
    return ok and pivot or crate.position
end

--// ============================================================
--//  Placement & Treadmill Helpers
--// ============================================================
local function IsBlockedByFurniture(floor, position)
    for _, child in ipairs(floor:GetChildren()) do
        if child.Name == "AppraisingCrate" or child.Name == "ItemStand" then
            local other = child:GetPivot().Position
            local dx = other.X - position.X
            local dz = other.Z - position.Z
            if dx * dx + dz * dz < 9 then return true end
        end
    end
    return false
end

local function IsSpotOnPlot(floor, position)
    if not floor then return false end
    local localPos = floor.CFrame:PointToObjectSpace(position)
    if math.abs(localPos.X) > floor.Size.X / 2 - 2 or math.abs(localPos.Z) > floor.Size.Z / 2 - 2 then
        return false
    end
    local topY = floor.Position.Y + floor.Size.Y / 2
    if math.abs(position.Y - topY) > 2.5 then return false end
    return not IsBlockedByFurniture(floor, position)
end

local function FindPlacementSpot(floor)
    if not floor then return nil end
    local topY = floor.Position.Y + floor.Size.Y / 2
    local halfX = math.max(1, floor.Size.X / 2 - 2.5)
    local halfZ = math.max(1, floor.Size.Z / 2 - 2.5)
    local step = 3.2

    for x = -halfX, halfX, step do
        for z = -halfZ, halfZ, step do
            local raw = (floor.CFrame * CFrame.new(x, floor.Size.Y / 2, z)).Position
            local candidate = Vector3.new(raw.X, topY, raw.Z)
            if IsSpotOnPlot(floor, candidate) then return candidate end
        end
    end

    local center = Vector3.new(floor.Position.X, topY, floor.Position.Z)
    if IsSpotOnPlot(floor, center) then return center end
    return nil
end

local function GetPlaceYaw(tool)
    if tool and tool:GetAttribute("CrateAreaId") == "Angelic" then
        local root = GetRoot()
        if root then
            local look = root.CFrame.LookVector
            return math.atan2(-look.X, -look.Z)
        end
    end
    return 0
end

local function FindMyTreadmill()
    local treadmills = Map:FindFirstChild("Treadmills")
    if not treadmills then return nil, nil end

    local function beltOf(model)
        local belt = model:FindFirstChild("Belt", true)
        return (belt and belt:IsA("BasePart")) and belt or nil
    end

    local mine = treadmills:FindFirstChild("PersonalTreadmill_" .. tostring(LocalPlayer.UserId))
    if mine then
        local belt = beltOf(mine)
        if belt then return belt, mine end
        for _, child in ipairs(treadmills:GetChildren()) do
            if child:GetAttribute("RiderUserId") == LocalPlayer.UserId or child:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                local found = beltOf(child)
                if found then return found, child end
            end
        end
        return nil, nil
    end

    for _, child in ipairs(treadmills:GetChildren()) do
        if child:GetAttribute("RiderUserId") == LocalPlayer.UserId or child:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            local found = beltOf(child)
            if found then return found, child end
        end
    end
    return nil, nil
end

local function TreadmillMountCFrame(belt, model)
    if not (belt and belt:IsA("BasePart")) then return nil end
    local yaw = model and tonumber(model:GetAttribute("MountYaw")) or 0
    return belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, 0) * CFrame.Angles(0, math.rad(yaw), 0)
end

local function GetSellerCFrame()
    local node = Map:FindFirstChild("Map")
    node = node and node:FindFirstChild("Vendors")
    node = node and node:FindFirstChild("SellPlaces")
    local sell1 = node and node:FindFirstChild("Sell1")
    local npc = sell1 and sell1:FindFirstChild("sellnpc NEW")

    if npc and npc:IsA("Model") then
        return npc:GetPivot() * CFrame.new(0, 2, 5)
    elseif sell1 then
        local prompt = sell1:FindFirstChildWhichIsA("ProximityPrompt", true)
        local holder = prompt and prompt.Parent
        if holder and holder:IsA("BasePart") then
            return CFrame.new(holder.Position + Vector3.new(0, 3, 4))
        end
        return CFrame.new(FALLBACK_SELL_POS)
    else
        return CFrame.new(FALLBACK_SELL_POS)
    end
end

local function GoToSellerIfNeeded()
    if not State.TeleportToSellerWhileSelling then return true end
    local sellerCf = GetSellerCFrame()
    local root = GetRoot()
    if root and (root.Position - sellerCf.Position).Magnitude <= 12 then return true end
    RequestStream(sellerCf.Position)
    return TeleportTo(sellerCf)
end

--// ============================================================
--//  Automation Loop Controller
--// ============================================================
local function StartLoop(name, interval, fn)
    State.Gens[name] = State.Gens[name] + 1
    local generation = State.Gens[name]
    task.spawn(function()
        while IsLoaded() and State.Enabled[name] and State.Gens[name] == generation do
            local ok, err = pcall(fn)
            if not ok then warn("[Jenicakes Hub]", name, err) end
            task.wait(type(interval) == "function" and interval() or interval)
        end
    end)
end

local function ToggleFeature(name, enabled, interval, fn)
    State.Enabled[name] = enabled and true or false
    if State.Enabled[name] then
        StartLoop(name, interval, fn)
    else
        State.Gens[name] = State.Gens[name] + 1
    end
end

--// ============================================================
--//  Core Game Automation Functions
--// ============================================================
local DepositStolen

local function DoStealOnce()
    if not IsLoaded() or not State.Enabled.Steal then return false end

    if IsCarryingStolen() then
        State.StealStatus = "Depositing"
        DepositStolen()
        return false
    end

    local root = GetRoot()
    if not root then
        State.StealStatus = "Waiting for character"
        return false
    end

    local crates = CollectCrates()
    if #crates == 0 then
        State.StealStatus = "Searching for crates"
        return false
    end

    local blocked = State.StealBlocked
    local now = os.clock()
    local target, bestDist
    for _, crate in ipairs(crates) do
        local untilAt = blocked[crate.model]
        if not (untilAt and untilAt > now) then
            blocked[crate.model] = nil
            local dist = (crate.position - root.Position).Magnitude
            if not bestDist or dist < bestDist then
                target, bestDist = crate, dist
            end
        end
    end

    if not target then
        State.StealStatus = "Searching for crates"
        return false
    end

    State.StealStatus = "Grabbing"
    local prompt = target.prompt
    FastPrompt(prompt)
    local spot = StealAnchor(target)
    RequestStream(spot)
    TeleportTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
    if not IsLoaded() or not State.Enabled.Steal then return false end

    local burst = math.clamp(State.StealBurst or 3, 1, 10)
    local deadline = os.clock() + 1.0
    local fired = false
    while IsLoaded() and State.Enabled.Steal and os.clock() < deadline do
        if IsCarryingStolen() or not (prompt.Parent and prompt.Enabled) then break end
        for _ = 1, burst do
            if FirePrompt(prompt) then fired = true end
        end
        Heartbeat:Wait()
        if IsCarryingStolen() then break end
        local me = GetRoot()
        local nowSpot = StealAnchor(target)
        if me and (me.Position - nowSpot).Magnitude > 8 then
            TeleportTo(CFrame.new(nowSpot + Vector3.new(0, 3, 0)))
        end
    end

    if not IsLoaded() or not State.Enabled.Steal then return false end

    if IsCarryingStolen() then
        State.StealCount = State.StealCount + 1
        State.LastStealAt = os.clock()
        State.StealStatus = "Depositing"
        DepositStolen()
    else
        blocked[target.model] = os.clock() + (fired and 0.6 or 0.3)
    end

    return IsLoaded() and State.Enabled.Steal
end

DepositStolen = function()
    if not IsCarryingStolen() then return true end
    RequestStream(DEPOSIT_POS)
    if not TeleportTo(CFrame.new(DEPOSIT_POS + Vector3.new(0, 3, 0))) then return false end
    local deadline = os.clock() + 4
    while IsLoaded() and IsCarryingStolen() and os.clock() < deadline do
        TeleportTo(CFrame.new(DEPOSIT_POS + Vector3.new(0, 3, 0)))
        Heartbeat:Wait()
        if not IsLoaded() then return false end
    end
    return not IsCarryingStolen()
end

local function DoSteal()
    while DoStealOnce() do end
end

local function DoPlace()
    if not IsLoaded() or not State.Enabled.Place then return end
    if IsCarryingStolen() then DepositStolen() return end
    if os.clock() - State.LastPlaceAt < 0.55 then return end

    local floor = GetOwnPlotFloor()
    if not floor then return end

    local tool = GetHeldCrateTool()
    if not tool then
        local tools = GetCrateTools()
        if #tools == 0 then return end
        EquipTool(tools[1])
        task.wait(0.15)
        if IsCarryingStolen() then return end
        tool = GetHeldCrateTool()
        if not tool then return end
    end

    local spot = FindPlacementSpot(floor)
    if not spot then return end
    RequestStream(spot)
    TeleportTo(CFrame.new(spot + Vector3.new(0, 4, 0)))
    task.wait(0.1)
    if not IsLoaded() or not State.Enabled.Place then return end
    if not IsSpotOnPlot(floor, spot) then return end

    local yaw = GetPlaceYaw(tool)
    local ok = pcall(function() REMOTE_PLACE_AT:FireServer(spot, yaw) end)
    if ok then State.LastPlaceAt = os.clock() end
end

local function DoOpen()
    if not IsLoaded() or not State.Enabled.Open then return end
    if os.clock() - State.LastOpenAt < 0.35 then return end

    local plot = GetOwnPlot()
    if not plot then return end
    local root = GetRoot()
    if not root then return end

    local bestPrompt, bestPos, bestDist = nil, nil, nil
    for _, descendant in ipairs(plot:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Enabled and descendant.ActionText == "Open Crate" then
            local parent = descendant.Parent
            local pos
            if parent and parent:IsA("BasePart") then
                pos = parent.Position
            else
                local model = descendant:FindFirstAncestorWhichIsA("Model")
                if model then pos = model:GetPivot().Position end
            end
            if pos then
                local dist = (pos - root.Position).Magnitude
                if not bestDist or dist < bestDist then
                    bestDist = dist
                    bestPrompt = descendant
                    bestPos = pos
                end
            end
        end
    end

    if not (bestPrompt and bestPos) then return end

    RequestStream(bestPos)
    TeleportTo(CFrame.new(bestPos + Vector3.new(0, 3, 0)))
    task.wait(0.1)
    if not IsLoaded() or not State.Enabled.Open then return end
    if FirePrompt(bestPrompt) then State.LastOpenAt = os.clock() end
end

local function DoEquipBest()
    if not IsLoaded() or not State.Enabled.EquipBest then return end
    if os.clock() - State.LastEquipBestAt < 2 then return end
    local ok = pcall(function() RF_ITEM_LOADOUT:InvokeServer("placebest") end)
    if ok then State.LastEquipBestAt = os.clock() end
end

local function DoBuyEquipSlot()
    if not IsLoaded() or not State.Enabled.BuyEquipSlot then return end
    if os.clock() - State.LastBuySlotAt < 1.5 then return end

    local _, floor = GetOwnPlot()
    if not floor then return end

    local ok, data = pcall(function() return RF_ITEM_LOADOUT:InvokeServer("list") end)
    if ok and type(data) == "table" then
        local nextPrice = tonumber(data.NextPrice)
        if nextPrice and nextPrice > 0 and not CanAfford(nextPrice) then return end
        if type(data.Slots) == "number" and type(data.NextSlots) == "number" and data.NextSlots <= data.Slots then
            return
        end
    end

    local fired = pcall(function() REMOTE_PLOT_UPGRADE:FireServer(floor, true) end)
    if fired then State.LastBuySlotAt = os.clock() end
end

local function DoTreadmill()
    if not IsLoaded() or not State.Enabled.Treadmill then return end
    if LocalPlayer:GetAttribute("OnTreadmill") == true then return end
    if os.clock() - State.LastTreadmillAt < 0.8 then return end

    local belt, model = FindMyTreadmill()
    if not belt then return end
    local cf = TreadmillMountCFrame(belt, model)
    if not cf then return end
    RequestStream(cf.Position)
    TeleportTo(cf)
    State.LastTreadmillAt = os.clock()
end

local function TryUpgrade(remote, signName, lastKey, interval)
    if not IsLoaded() then return end
    if os.clock() - (State[lastKey] or 0) < (interval or 1.5) then return end

    local plot = GetOwnPlot()
    if not plot then return end

    local sign = plot:FindFirstChild(signName, true)
    if sign then
        if sign:GetAttribute("CanAfford") == false then return end
        local price = tonumber(sign:GetAttribute("UpgradePrice"))
        if price and price > 0 and not CanAfford(price) then return end
    end

    local ok = pcall(function() remote:FireServer(plot) end)
    if ok then State[lastKey] = os.clock() end
end

local function DoUpgradeTreadmill()
    if not State.Enabled.UpgradeTreadmill then return end
    TryUpgrade(REMOTE_TREADMILL_UPGRADE, "TreadmillSignBoard", "LastUpgradeTreadmillAt", 1.5)
end

local function DoUpgradePlot()
    if not State.Enabled.UpgradePlot then return end
    TryUpgrade(REMOTE_PLOT_UPGRADE, "UpgradeSignBoard", "LastUpgradePlotAt", 1.5)
end

local function DoClaimIndex()
    if not IsLoaded() or not State.Enabled.ClaimIndex then return end
    if os.clock() - State.LastClaimIndexAt < 2 then return end
    local ok = pcall(function() Network.FireServer("INDEX_CLAIM_ALL") end)
    if ok then State.LastClaimIndexAt = os.clock() end
end

local function DoBuyTrails()
    if not IsLoaded() or not State.Enabled.BuyTrails then return end
    if os.clock() - State.LastBuyTrailsAt < 1.2 then return end

    local bought = false
    for _, trail in ipairs(Trails) do
        if not IsLoaded() or not State.Enabled.BuyTrails then break end
        if State.TrailOwned[trail.Id] ~= true then
            local price = tonumber(trail.Price) or 0
            if CanAfford(price) then
                local ok = pcall(function() Network.FireServer("TRAIL_BUY", trail.Id) end)
                if ok then
                    bought = true
                    task.wait(0.2)
                end
            end
        end
    end

    if bought then
        State.LastBuyTrailsAt = os.clock()
        pcall(function() Network.FireServer("TRAIL_STATE") end)
    end
end

local function DoSell()
    if not IsLoaded() or not State.Enabled.Sell then return end
    if os.clock() - State.LastSellAt < 1.2 then return end

    local mode = SELL_MODE_ARG[State.SellMode] or "all"
    if mode == "held" then
        local ok, quote = pcall(function() return RF_SELL_QUOTE:InvokeServer() end)
        if not (ok and type(quote) == "table" and quote.HeldLabel and quote.HeldPrice) then return end
    elseif mode == "all" then
        local ok, quote = pcall(function() return RF_SELL_QUOTE:InvokeServer() end)
        if ok and type(quote) == "table" then
            local count = tonumber(quote.AllCount) or 0
            if count <= 0 then return end
        end
    end

    if not GoToSellerIfNeeded() then return end
    if State.TeleportToSellerWhileSelling then
        task.wait(0.08)
        if not IsLoaded() or not State.Enabled.Sell then return end
    end

    local ok = pcall(function() REMOTE_SELL_DO:FireServer(mode) end)
    if ok then State.LastSellAt = os.clock() end
end

-- Sync Trail Network Event
do
    local connection
    pcall(function()
        connection = Network.OnClientEvent("TRAIL_STATE"):Connect(function(data)
            if type(data) == "table" and type(data.Owned) == "table" then
                State.TrailOwned = data.Owned
            end
        end)
        Network.FireServer("TRAIL_STATE")
    end)
    if connection then
        Track(function() pcall(function() connection:Disconnect() end) end)
    end
end

--// ============================================================
--//  Player Character Tweaks
--// ============================================================
local PlayerTweaks = {
    WalkSpeedEnabled = false,
    WalkSpeed = 32,
    InfJump = false,
    NoClip = false,
    Fly = false,
    FlySpeed = 60,
    InstantPP = false,
    WalkSnapshots = {},
    NoClipSnapshots = {},
    FlyPlatformStand = nil,
    InfJumpConn = nil,
    NoClipConn = nil,
    FlyConn = nil,
    InstantConn = nil,
    InstantSnapshots = {},
}

local function ApplyWalkSpeed(humanoid)
    if not humanoid then return end
    if PlayerTweaks.WalkSnapshots[humanoid] == nil then
        PlayerTweaks.WalkSnapshots[humanoid] = humanoid.WalkSpeed
    end
    if PlayerTweaks.WalkSpeedEnabled then
        humanoid.WalkSpeed = PlayerTweaks.WalkSpeed
    end
end

local function SetWalkSpeedEnabled(enabled)
    PlayerTweaks.WalkSpeedEnabled = enabled and true or false
    local humanoid = GetHumanoid()
    if not humanoid then return end
    if PlayerTweaks.WalkSpeedEnabled then
        ApplyWalkSpeed(humanoid)
    elseif PlayerTweaks.WalkSnapshots[humanoid] ~= nil then
        humanoid.WalkSpeed = PlayerTweaks.WalkSnapshots[humanoid]
    end
end

local function SetInfJump(enabled)
    PlayerTweaks.InfJump = enabled and true or false
    if PlayerTweaks.InfJumpConn then
        PlayerTweaks.InfJumpConn:Disconnect()
        PlayerTweaks.InfJumpConn = nil
    end
    if not PlayerTweaks.InfJump then return end
    PlayerTweaks.InfJumpConn = UserInputService.JumpRequest:Connect(function()
        if not IsLoaded() or not PlayerTweaks.InfJump then return end
        local humanoid = GetHumanoid()
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function SetNoClip(enabled)
    PlayerTweaks.NoClip = enabled and true or false
    if PlayerTweaks.NoClipConn then
        PlayerTweaks.NoClipConn:Disconnect()
        PlayerTweaks.NoClipConn = nil
    end

    local character = LocalPlayer.Character
    if not PlayerTweaks.NoClip then
        for part, canCollide in pairs(PlayerTweaks.NoClipSnapshots) do
            if part and part.Parent then part.CanCollide = canCollide end
        end
        table.clear(PlayerTweaks.NoClipSnapshots)
        return
    end

    local function disableCollision(part)
        if part:IsA("BasePart") and PlayerTweaks.NoClipSnapshots[part] == nil then
            PlayerTweaks.NoClipSnapshots[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    if character then
        for _, descendant in ipairs(character:GetDescendants()) do disableCollision(descendant) end
        PlayerTweaks.NoClipConn = character.DescendantAdded:Connect(function(descendant)
            if PlayerTweaks.NoClip then disableCollision(descendant) end
        end)
    end
end

local function SetFly(enabled)
    PlayerTweaks.Fly = enabled and true or false
    if PlayerTweaks.FlyConn then
        PlayerTweaks.FlyConn:Disconnect()
        PlayerTweaks.FlyConn = nil
    end

    local humanoid = GetHumanoid()
    if not PlayerTweaks.Fly then
        if humanoid and PlayerTweaks.FlyPlatformStand ~= nil then
            humanoid.PlatformStand = PlayerTweaks.FlyPlatformStand
        end
        PlayerTweaks.FlyPlatformStand = nil
        return
    end

    if humanoid then
        PlayerTweaks.FlyPlatformStand = humanoid.PlatformStand
        humanoid.PlatformStand = true
    end

    PlayerTweaks.FlyConn = RunService.RenderStepped:Connect(function()
        if not IsLoaded() or not PlayerTweaks.Fly then return end
        if UserInputService:GetFocusedTextBox() then return end

        local root = GetRoot()
        local camera = Map.CurrentCamera
        if not (root and camera) then return end

        local direction = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.yAxis end

        if direction.Magnitude > 0 then
            root.AssemblyLinearVelocity = direction.Unit * PlayerTweaks.FlySpeed
        else
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

local function SetInstantProximityPrompt(enabled)
    PlayerTweaks.InstantPP = enabled and true or false
    if PlayerTweaks.InstantConn then
        PlayerTweaks.InstantConn:Disconnect()
        PlayerTweaks.InstantConn = nil
    end

    local function restoreAll()
        for prompt, snapshot in pairs(PlayerTweaks.InstantSnapshots) do
            if prompt and prompt.Parent then
                prompt.HoldDuration = snapshot.HoldDuration
                prompt.MaxActivationDistance = snapshot.MaxActivationDistance
                prompt.RequiresLineOfSight = snapshot.RequiresLineOfSight
            end
        end
        table.clear(PlayerTweaks.InstantSnapshots)
    end

    if not PlayerTweaks.InstantPP then
        restoreAll()
        return
    end

    local function patchPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") then return end
        if PlayerTweaks.InstantSnapshots[prompt] == nil then
            PlayerTweaks.InstantSnapshots[prompt] = {
                HoldDuration = prompt.HoldDuration,
                MaxActivationDistance = prompt.MaxActivationDistance,
                RequiresLineOfSight = prompt.RequiresLineOfSight,
            }
        end
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 50
        prompt.RequiresLineOfSight = false
    end

    for _, descendant in ipairs(Map:GetDescendants()) do patchPrompt(descendant) end
    PlayerTweaks.InstantConn = Map.DescendantAdded:Connect(function(descendant)
        if PlayerTweaks.InstantPP then patchPrompt(descendant) end
    end)
end

local function OnCharacterAdded(character)
    task.defer(function()
        if not IsLoaded() then return end
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        if PlayerTweaks.WalkSpeedEnabled then ApplyWalkSpeed(humanoid) end
        if PlayerTweaks.NoClip then SetNoClip(true) end
        if PlayerTweaks.Fly then SetFly(true) end
    end)
end

if LocalPlayer.Character then OnCharacterAdded(LocalPlayer.Character) end
local characterConn = LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
Track(function() characterConn:Disconnect() end)

--// ============================================================
--//  Performance & Misc Tweaks
--// ============================================================
local MiscTweaks = {
    AntiAfk = true,
    Disable3D = false,
    FpsBoost = false,
    AfkConn = nil,
    AfkTask = nil,
    FpsSnapshots = {},
    FpsConn = nil,
}

local function setAntiAfk(enabled)
    Cfg.antiAfk = enabled and true or false
    MiscTweaks.AntiAfk = Cfg.antiAfk

    if getconnections then
        for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
            pcall(function() c:Disable() end)
            pcall(function() c:Disconnect() end)
        end
    end

    if MiscTweaks.AfkConn then MiscTweaks.AfkConn:Disconnect() MiscTweaks.AfkConn = nil end
    if MiscTweaks.AfkTask then pcall(task.cancel, MiscTweaks.AfkTask) MiscTweaks.AfkTask = nil end

    if not MiscTweaks.AntiAfk then return end

    local function simulateAfkInput()
        if not Map.CurrentCamera then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end

    MiscTweaks.AfkConn = LocalPlayer.Idled:Connect(function()
        if IsLoaded() and MiscTweaks.AntiAfk then simulateAfkInput() end
    end)

    MiscTweaks.AfkTask = task.spawn(function()
        local last = os.clock()
        while IsLoaded() and MiscTweaks.AntiAfk do
            task.wait(1)
            if os.clock() - last >= 60 then
                last = os.clock()
                simulateAfkInput()
            end
        end
    end)
end
setAntiAfk(Cfg.antiAfk)

local function SetDisable3D(enabled)
    MiscTweaks.Disable3D = enabled and true or false
    pcall(function() RunService:Set3dRenderingEnabled(not MiscTweaks.Disable3D) end)
end

local function SetFpsBoost(enabled)
    MiscTweaks.FpsBoost = enabled and true or false
    if MiscTweaks.FpsConn then
        MiscTweaks.FpsConn:Disconnect()
        MiscTweaks.FpsConn = nil
    end

    local function restoreAll()
        for instance, snapshot in pairs(MiscTweaks.FpsSnapshots) do
            if instance and instance.Parent then
                for key, value in pairs(snapshot) do
                    pcall(function() instance[key] = value end)
                end
            end
        end
        table.clear(MiscTweaks.FpsSnapshots)
    end

    if not MiscTweaks.FpsBoost then
        restoreAll()
        return
    end

    local function disableEffects(instance)
        if MiscTweaks.FpsSnapshots[instance] then return end
        local isEffect = instance:IsA("ParticleEmitter")
            or instance:IsA("Trail")
            or instance:IsA("Beam")
            or instance:IsA("Fire")
            or instance:IsA("Smoke")
            or instance:IsA("Sparkles")
        if isEffect then
            MiscTweaks.FpsSnapshots[instance] = { Enabled = instance.Enabled }
            instance.Enabled = false
        end
    end

    for _, descendant in ipairs(Map:GetDescendants()) do disableEffects(descendant) end
    if MiscTweaks.FpsSnapshots[Lighting] == nil then
        MiscTweaks.FpsSnapshots[Lighting] = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.GlobalShadows = false
    end
    MiscTweaks.FpsConn = Map.DescendantAdded:Connect(function(descendant)
        if MiscTweaks.FpsBoost then disableEffects(descendant) end
    end)
end

-- Teleport Helpers
local function TeleportToBase()
    local cf = GetBaseCFrame()
    if not cf then return false end
    RequestStream(cf.Position)
    return TeleportTo(cf)
end

local function TeleportToZone(name)
    if type(name) ~= "string" or name == "" then return false end
    local areaId = ZoneNameToId[name] or name
    local position = GetAreaPosition(areaId)
    if not position then return false end
    RequestStream(position)
    return TeleportTo(CFrame.new(position))
end

--// ============================================================
--//  WindUI Interface Construction
--// ============================================================
local windUI = loadstring(game:HttpGet("https://github.com/mallu837/JenicakesUI/releases/latest/download/main.lua"))()
Hub.WindUI = windUI

local jenicakesWindow = windUI:CreateWindow({
    Title = "Jenicakes Hub",
    Icon = "sparkles",
    Author = "Steal From The Rich",
    Folder = "JenicakesHub_Config",
    Size = UDim2.fromOffset(620, 520),
    Transparent = true,
    Theme = "Dark",
    Acrylic = false,
    Resizable = true,
})

Hub.Window = jenicakesWindow
pcall(function() jenicakesWindow:SetToTheCenter() end)

-- User Profile Card (Sidebar Bottom)
pcall(function()
    local avatarUrl = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", LocalPlayer.UserId)
    
    if type(jenicakesWindow.UserProfile) == "function" then
        jenicakesWindow:UserProfile({
            Title = LocalPlayer.DisplayName or LocalPlayer.Name,
            Icon = avatarUrl
        })
    elseif type(jenicakesWindow.AddUserProfile) == "function" then
        jenicakesWindow:AddUserProfile({
            Title = LocalPlayer.DisplayName or LocalPlayer.Name,
            Icon = avatarUrl
        })
    elseif type(jenicakesWindow.User) == "function" then
        jenicakesWindow:User({
            Title = LocalPlayer.DisplayName or LocalPlayer.Name,
            Icon = avatarUrl
        })
    end
end)

---------------------------------------------------------
-- TAB 1: AUTOMATION
---------------------------------------------------------
local autoTab = jenicakesWindow:Tab({ Title = "Automation", Icon = "play" })

autoTab:Section({ Title = "Steal & Deposit" })

autoTab:Toggle({
    Title = "Auto Steal Crates",
    Desc = "Automatically targets and steals crates from zones",
    Value = State.Enabled.Steal,
    Callback = function(val) ToggleFeature("Steal", val, 0, DoSteal) end
})

autoTab:Slider({
    Title = "Steal Burst Count",
    Desc = "Amount of interactions triggered per steal tick",
    Min = 1, Max = 10, Default = State.StealBurst,
    Callback = function(val) State.StealBurst = math.floor(val) end
})

autoTab:Section({ Title = "Base & Crate Management" })

autoTab:Toggle({
    Title = "Auto Place Crates",
    Desc = "Places crates on valid free spots on your plot floor",
    Value = State.Enabled.Place,
    Callback = function(val) ToggleFeature("Place", val, 0.35, DoPlace) end
})

autoTab:Toggle({
    Title = "Auto Open Crates",
    Desc = "Automatically triggers proximity prompts to open crates",
    Value = State.Enabled.Open,
    Callback = function(val) ToggleFeature("Open", val, 0.3, DoOpen) end
})

autoTab:Toggle({
    Title = "Auto Sell",
    Desc = "Sells items automatically according to selected mode",
    Value = State.Enabled.Sell,
    Callback = function(val) ToggleFeature("Sell", val, 1, DoSell) end
})

autoTab:Dropdown({
    Title = "Sell Mode",
    Values = SELL_MODES,
    Default = State.SellMode,
    Callback = function(val) State.SellMode = val end
})

autoTab:Toggle({
    Title = "Teleport to Seller NPC",
    Desc = "Teleports to the selling location when executing a sell",
    Value = State.TeleportToSellerWhileSelling,
    Callback = function(val) State.TeleportToSellerWhileSelling = val end
})

---------------------------------------------------------
-- TAB 2: UPGRADES & PROGRESSION
---------------------------------------------------------
local upgradeTab = jenicakesWindow:Tab({ Title = "Upgrades", Icon = "trending-up" })

upgradeTab:Section({ Title = "Base & Treadmill Upgrades" })

upgradeTab:Toggle({
    Title = "Auto Upgrade Plot",
    Desc = "Purchases base plot upgrades automatically when affordable",
    Value = State.Enabled.UpgradePlot,
    Callback = function(val) ToggleFeature("UpgradePlot", val, 1.2, DoUpgradePlot) end
})

upgradeTab:Toggle({
    Title = "Auto Upgrade Equip Slots",
    Desc = "Unlocks additional item placement slots",
    Value = State.Enabled.BuyEquipSlot,
    Callback = function(val) ToggleFeature("BuyEquipSlot", val, 1.2, DoBuyEquipSlot) end
})

upgradeTab:Toggle({
    Title = "Auto Equip Best Items",
    Desc = "Equips the best items in your loadout periodically",
    Value = State.Enabled.EquipBest,
    Callback = function(val) ToggleFeature("EquipBest", val, 1.5, DoEquipBest) end
})

upgradeTab:Toggle({
    Title = "Auto Ride Treadmill",
    Desc = "Maintains player position on your personal treadmill",
    Value = State.Enabled.Treadmill,
    Callback = function(val) ToggleFeature("Treadmill", val, 0.5, DoTreadmill) end
})

upgradeTab:Toggle({
    Title = "Auto Upgrade Treadmill",
    Desc = "Purchases treadmill upgrades when affordable",
    Value = State.Enabled.UpgradeTreadmill,
    Callback = function(val) ToggleFeature("UpgradeTreadmill", val, 1.2, DoUpgradeTreadmill) end
})

upgradeTab:Toggle({
    Title = "Auto Claim Index",
    Desc = "Claims all available collection index rewards",
    Value = State.Enabled.ClaimIndex,
    Callback = function(val) ToggleFeature("ClaimIndex", val, 2, DoClaimIndex) end
})

upgradeTab:Toggle({
    Title = "Auto Buy Trails",
    Desc = "Buys unowned trail cosmetics when affordable",
    Value = State.Enabled.BuyTrails,
    Callback = function(val) ToggleFeature("BuyTrails", val, 1, DoBuyTrails) end
})

---------------------------------------------------------
-- TAB 3: TELEPORTS & FILTERS
---------------------------------------------------------
local teleportTab = jenicakesWindow:Tab({ Title = "Teleports & Filters", Icon = "map-pin" })

teleportTab:Section({ Title = "Quick Teleports" })

teleportTab:Button({
    Title = "Teleport to Base Plot",
    Callback = function()
        if not TeleportToBase() then Notify("Plot not found!", 3, "alert-circle") end
    end
})

teleportTab:Dropdown({
    Title = "Teleport to Zone",
    Values = ZoneDisplayNames,
    Callback = function(zoneName)
        if not TeleportToZone(zoneName) then Notify("Failed to teleport to zone!", 3, "alert-circle") end
    end
})

teleportTab:Section({ Title = "Filters" })

teleportTab:Dropdown({
    Title = "Zone Filter",
    Values = ZoneDisplayNames,
    Multi = true,
    Default = ZoneDisplayNames,
    Callback = function(selection)
        local set = {}
        if type(selection) == "table" then
            for _, val in pairs(selection) do
                set[val] = true
                local id = ZoneNameToId[val]
                if id then set[id] = true end
            end
        end
        State.ZoneFilter = set
    end
})

teleportTab:Dropdown({
    Title = "Rarity Filter",
    Values = Rarities,
    Multi = true,
    Default = Rarities,
    Callback = function(selection)
        local set = {}
        if type(selection) == "table" then
            for _, val in pairs(selection) do
                set[val] = true
            end
        end
        State.RarityFilter = set
    end
})

---------------------------------------------------------
-- TAB 4: PLAYER TWEAKS
---------------------------------------------------------
local playerTab = jenicakesWindow:Tab({ Title = "Player", Icon = "user" })

playerTab:Section({ Title = "Movement Options" })

playerTab:Toggle({
    Title = "WalkSpeed Modifier",
    Value = PlayerTweaks.WalkSpeedEnabled,
    Callback = function(val) SetWalkSpeedEnabled(val) end
})

playerTab:Slider({
    Title = "WalkSpeed Value",
    Min = 16, Max = 150, Default = PlayerTweaks.WalkSpeed,
    Callback = function(val)
        PlayerTweaks.WalkSpeed = val
        if PlayerTweaks.WalkSpeedEnabled then
            local humanoid = GetHumanoid()
            if humanoid then humanoid.WalkSpeed = val end
        end
    end
})

playerTab:Toggle({
    Title = "Infinite Jump",
    Value = PlayerTweaks.InfJump,
    Callback = function(val) SetInfJump(val) end
})

playerTab:Toggle({
    Title = "Noclip",
    Value = PlayerTweaks.NoClip,
    Callback = function(val) SetNoClip(val) end
})

playerTab:Toggle({
    Title = "Fly Mode",
    Value = PlayerTweaks.Fly,
    Callback = function(val) SetFly(val) end
})

playerTab:Slider({
    Title = "Fly Speed",
    Min = 20, Max = 200, Default = PlayerTweaks.FlySpeed,
    Callback = function(val) PlayerTweaks.FlySpeed = val end
})

playerTab:Toggle({
    Title = "Instant Proximity Prompts",
    Desc = "Removes hold duration and line of sight restrictions",
    Value = PlayerTweaks.InstantPP,
    Callback = function(val) SetInstantProximityPrompt(val) end
})

---------------------------------------------------------
-- TAB 5: MISC & PERFORMANCE
---------------------------------------------------------
local miscTab = jenicakesWindow:Tab({ Title = "Misc", Icon = "settings" })

miscTab:Section({ Title = "Performance & Automation" })

miscTab:Toggle({
    Title = "Anti AFK",
    Desc = "Prevents client from being kicked for idling",
    Value = Cfg.antiAfk,
    Callback = function(val) setAntiAfk(val) end
})

miscTab:Toggle({
    Title = "Auto Rejoin",
    Desc = "Automatically rejoins the server upon disconnection",
    Value = Cfg.autoRejoin,
    Callback = function(val) Cfg.autoRejoin = val end
})

miscTab:Toggle({
    Title = "Disable 3D Rendering",
    Desc = "Reduces CPU/GPU usage drastically for AFK farming",
    Value = MiscTweaks.Disable3D,
    Callback = function(val) SetDisable3D(val) end
})

miscTab:Toggle({
    Title = "FPS Boost",
    Desc = "Disables particles, shadows, and high-impact visual effects",
    Value = MiscTweaks.FpsBoost,
    Callback = function(val) SetFpsBoost(val) end
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
        else
            Notify("Clipboard functionality unavailable", 3, "alert-circle")
        end
    end
})

miscTab:Button({
    Title = "Unload Script",
    Callback = function()
        if getgenv().JenicakesHub and type(getgenv().JenicakesHub.Unload) == "function" then
            getgenv().JenicakesHub:Unload()
        end
    end
})

--// ============================================================
--//  Unload Handler
--// ============================================================
function Hub:Unload()
    self.Running = false

    -- Stop all automation loops
    for name in pairs(State.Gens) do
        State.Gens[name] = State.Gens[name] + 1
        State.Enabled[name] = false
    end

    -- Revert player tweaks
    SetWalkSpeedEnabled(false)
    SetInfJump(false)
    SetNoClip(false)
    SetFly(false)
    SetInstantProximityPrompt(false)

    -- Revert performance tweaks
    setAntiAfk(false)
    SetDisable3D(false)
    SetFpsBoost(false)

    -- Disconnect tracked connections
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn() end)
    end
    table.clear(self.Connections)

    -- Destroy WindUI instance
    if self.Window and type(self.Window.Destroy) == "function" then
        pcall(function() self.Window:Destroy() end)
    end

    getgenv().JenicakesHub = nil
    warn("[Jenicakes Hub] Script successfully unloaded.")
end

-- Auto Rejoin Event Connection
LocalPlayer.OnTeleport:Connect(function()
    if Cfg.autoRejoin then
        task.wait(2)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end)

Notify("Jenicakes Hub loaded!", 4, "sparkles")
