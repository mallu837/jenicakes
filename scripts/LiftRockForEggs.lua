-- ==========================================================
-- Jenicakes Hub — Final Script (v20 - Footer Fix & Steal Debugs)
-- ==========================================================

local Jenicakes = loadstring(game:HttpGet("https://raw.githubusercontent.com/mallu837/JenicakesObsiUI/main/Library.lua"))()

local bgAsset = ""
local success, err = pcall(function()
    local rawText = game:HttpGet("https://raw.githubusercontent.com/mallu837/JenicakesObsiUI/main/assets/background.png.txt")
    local b64 = rawText:match("base64,(.+)") or rawText
    if b64:sub(1,1) == '"' then b64 = b64:sub(2, -2) end
    writefile("jenicakes_bg.png", base64decode(b64))
    bgAsset = getcustomasset("jenicakes_bg.png")
end)
if not success then print("Background failed:", err) end

-- ==========================================
-- AUTO-DETECT GAME NAME
-- ==========================================
local function getGameName()
    local s, result = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    if s and result then return result end
    return game.Name
end
local detectedGame = getGameName()

local Window = Jenicakes:CreateWindow({
    Title = "Jenicakes", 
    Subtitle = "Made By Jen",
    Footer = "Game: " .. detectedGame, -- THIS FIXES THE FOOTER
    Size = UDim2.fromOffset(500, 350), 
    Icon = "gavel",
    BackgroundImage = bgAsset, 
    Theme = "Dark",
})

-- Just in case the library uses a Setter method
pcall(function() Window:SetFooter("Made By Jen | Game: " .. detectedGame) end)

-- ==========================================
-- TABS (Main -> Misc -> Shop -> Settings)
-- ==========================================
local MainTab     = Window:AddTab("Main", "home")
local MiscTab     = Window:AddTab("Misc", "shield")
local ShopTab     = Window:AddTab("Shop", "shopping-cart")
local SettingsTab = Window:AddTab("Settings", "settings")

-- ==========================================
-- SHARED SERVICES / REFERENCES
-- ==========================================
local players           = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService        = game:GetService("RunService")
local userInput         = game:GetService("UserInputService")
local localPlayer       = players.LocalPlayer

local defaultSpawn = CFrame.new(197, 4, 286)
local selectedZone = "Select All"
local cachedBench  = nil

local zoneList = { "Select All" }
pcall(function()
    local floors = workspace.Floors:GetChildren()
    table.sort(floors, function(a, b)
        return (a:GetAttribute("ZoneIndex") or 0) > (b:GetAttribute("ZoneIndex") or 0)
    end)
    for _, floor in ipairs(floors) do
        table.insert(zoneList, tostring(floor:GetAttribute("ZoneIndex") or 0) .. " - " .. floor.Name)
    end
end)

local function getHRP()
    local char = localPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = localPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ==========================================
-- STRICT BENCH FINDER
-- ==========================================
local function findMyBench()
    if cachedBench and cachedBench.Parent then return cachedBench end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    local myName = localPlayer.Name
    local myDisplay = localPlayer.DisplayName
    local myId = tostring(localPlayer.UserId)

    for _, plot in ipairs(plots:GetChildren()) do
        local isMine = false
        
        local attrs = {"Owner", "OwnerName", "UserId", "OwnerId", "Player", "Claimer"}
        for _, attr in ipairs(attrs) do
            local val = plot:GetAttribute(attr)
            if val and (tostring(val) == myName or tostring(val) == myId or tostring(val) == myDisplay) then
                isMine = true break
            end
        end

        if not isMine then
            for _, childName in ipairs(attrs) do
                local obj = plot:FindFirstChild(childName)
                if obj then
                    if obj:IsA("StringValue") and (obj.Value == myName or obj.Value == myId) then isMine = true break end
                    if obj:IsA("ObjectValue") and obj.Value == localPlayer then isMine = true break end
                    if obj:IsA("IntValue") and tostring(obj.Value) == myId then isMine = true break end
                end
            end
        end

        if not isMine then
            for _, v in ipairs(plot:GetDescendants()) do
                if v:IsA("StringValue") and (v.Value == myName or v.Value == myId) then isMine = true break end
                if v:IsA("ObjectValue") and v.Value == localPlayer then isMine = true break end
                if v:IsA("IntValue") and tostring(v.Value) == myId then isMine = true break end
                if (v:IsA("TextLabel") or v:IsA("TextButton")) and (v.Text:find(myName) or v.Text:find(myDisplay)) then isMine = true break end
            end
        end

        if isMine then
            local gym = plot:FindFirstChild("Gym")
            if gym and gym:FindFirstChild("Bench") then
                cachedBench = gym.Bench
                return cachedBench
            end
        end
    end
    return nil
end

local function teleportToMyBench()
    local bench = findMyBench()
    local hrp = getHRP()
    if bench and hrp then
        local pivot = bench:IsA("Model") and bench:GetPivot() or bench.CFrame
        hrp.CFrame = pivot + Vector3.new(0, 3, 0)
    elseif hrp then
        hrp.CFrame = defaultSpawn
    end
end

-- ==========================================
-- EGG FINDER & STEALING (With Debug Prints)
-- ==========================================
local function parseZoneName(entry)
    if not entry or entry == "Select All" then return nil end
    return entry:match("^%d+%s*%-%s*(.+)$")
end

local function findPromptInZone(zoneName)
    local hrp = getHRP()
    if not hrp then return nil end
    
    local best, bestDist = nil, math.huge
    local live = workspace:FindFirstChild("Live") or workspace
    
    for _, v in ipairs(live:GetDescendants()) do
        if not _G.Steal then break end
        if v:IsA("ProximityPrompt") and (v.Name == "StealPrompt" or v.ActionText:lower():find("steal")) then
            local parent = v.Parent
            if parent and parent:IsA("BasePart") then
                
                local isInZone = false
                local current = parent
                for i = 1, 6 do
                    if not current or current == workspace then break end
                    local sz = current:GetAttribute("SpawnZone") or current:GetAttribute("Zone") or current:GetAttribute("ZoneName")
                    if sz and (zoneName == nil or tostring(sz):lower():find(zoneName:lower())) then
                        isInZone = true break
                    end
                    if zoneName and current.Name:lower():find(zoneName:lower()) then
                        isInZone = true break
                    end
                    current = current.Parent
                end

                if not zoneName then isInZone = true end

                if isInZone then
                    local dist = (hrp.Position - parent.Position).Magnitude
                    if dist < bestDist then
                        best = v
                        bestDist = dist
                    end
                end
            end
        end
    end
    return best
end

local function stealZone(zoneName)
    if not _G.Steal then return false end
    local hrp = getHRP()
    if not hrp then return false end

    -- 1. Find the guard
    local guardFolder = workspace:FindFirstChild("_GuardVisuals")
    if not guardFolder then 
        print("❌ Error: _GuardVisuals not found in workspace!")
        return false 
    end

    local guard = guardFolder:FindFirstChild(zoneName) or guardFolder:FindFirstChild(zoneName, true)
    if not guard then 
        print("❌ Error: Guard for '" .. tostring(zoneName) .. "' not found!")
        return false 
    end

    -- 2. Teleport to guard
    hrp.CFrame = guard:GetPivot()
    
    -- 3. Wait for StreamingEnabled to load the eggs (wait 2.5 seconds max)
    local prompt = nil
    for i = 1, 5 do
        task.wait(0.5)
        if not _G.Steal then return false end
        prompt = findPromptInZone(zoneName)
        if prompt then break end
    end

    if not prompt then 
        print("💤 No eggs found in " .. zoneName .. " after 2.5s. Returning to base.")
        return false 
    end
    
    print("🥚 Found egg in " .. zoneName .. "! Stealing...")

    -- 4. Teleport to egg
    local parent = prompt.Parent
    if parent and parent:IsA("BasePart") then
        hrp.CFrame = parent.CFrame + Vector3.new(0, 2, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.4)

        -- 5. Jump
        local hum = getHumanoid()
        if hum then
            pcall(function() hum.Jump = true end)
        end
        task.wait(0.1)

        -- 6. Fire prompt
        if _G.Steal and prompt.Parent then
            if prompt:IsA("ProximityPrompt") then
                pcall(function() fireproximityprompt(prompt) end)
            elseif prompt:IsA("ClickDetector") then
                pcall(function() fireclickdetector(prompt) end)
            end
            task.wait(0.2)
        end
    end
    return true
end

-- ==========================================
-- MAIN TAB - Community
-- ==========================================
local MainGroup = MainTab:AddLeftGroupbox("Community", "discord")

MainGroup:AddButton({
    Text = "Copy Discord Invite",
    Func = function()
        pcall(function() setclipboard("https://discord.gg/GFZYsspybS") end)
    end,
})

MainGroup:AddButton({
    Text = "Open Discord Link",
    Func = function()
        pcall(function() setclipboard("https://discord.gg/GFZYsspybS") end)
    end,
})

-- ==========================================
-- MAIN TAB - Auto Farm
-- ==========================================
local EggGroup = MainTab:AddRightGroupbox("Auto Farm", "egg")

EggGroup:AddDropdown("ZoneList", {
    Text = "Zone List",
    Values = zoneList,
    Default = "Select All",
    Callback = function(Value) selectedZone = Value end,
})

EggGroup:AddToggle("AutoSteal", {
    Text = "Auto Steal",
    Default = false,
    Callback = function(Value)
        _G.Steal = Value
        if not Value then teleportToMyBench() return end

        task.spawn(function()
            while _G.Steal do
                local foundAny = false

                if selectedZone == "Select All" then
                    local allFloors = {}
                    pcall(function()
                        allFloors = workspace.Floors:GetChildren()
                        table.sort(allFloors, function(a, b)
                            return (a:GetAttribute("ZoneIndex") or 0) > (b:GetAttribute("ZoneIndex") or 0)
                        end)
                    end)
                    for _, floor in ipairs(allFloors) do
                        if not _G.Steal then break end
                        if stealZone(floor.Name) then 
                            foundAny = true 
                            break 
                        end
                    end
                elseif selectedZone then
                    local zoneName = parseZoneName(selectedZone)
                    if zoneName then 
                        if stealZone(zoneName) then foundAny = true end
                    end
                end

                if not foundAny and _G.Steal then
                    teleportToMyBench()
                    task.wait(2) 
                else
                    teleportToMyBench()
                    task.wait(0.5)
                end
            end
            teleportToMyBench()
        end)
    end,
})

EggGroup:AddToggle("AutoPlace", {
    Text = "Auto Place",
    Default = false,
    Callback = function(Value)
        _G.Place = Value
        if Value then
            task.spawn(function()
                while _G.Place do
                    task.wait(1)
                    pcall(function()
                        local backpack  = localPlayer:FindFirstChild("Backpack")
                        local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
                        local placePet  = replicatedStorage._Net.PlacePet
                        local tools = {}
                        if backpack then
                            for _, item in ipairs(backpack:GetChildren()) do table.insert(tools, item) end
                        end
                        for _, item in ipairs(character:GetChildren()) do table.insert(tools, item) end
                        for _, tool in ipairs(tools) do
                            if tool:IsA("Tool") and tool:GetAttribute("isEgg") == true then
                                local uid = tool:GetAttribute("petUID")
                                if uid then placePet:FireServer(uid, 0, 0) end
                            end
                        end
                    end)
                end
            end)
        end
    end,
})

EggGroup:AddToggle("AutoHatch", {
    Text = "Auto Hatch",
    Default = false,
    Callback = function(Value)
        _G.Hatch = Value
        if Value then
            task.spawn(function()
                while _G.Hatch do
                    task.wait(1)
                    pcall(function()
                        local playerFriends = workspace.Live.PlayerFriends[localPlayer.Name]
                        if playerFriends then
                            for _, v in pairs(playerFriends:GetDescendants()) do
                                if v.Name == "ProximityPrompt" and v.ActionText == "Open" and v.Enabled == true then
                                    replicatedStorage._Net.OpenEgg:FireServer(v.Parent.Parent.Parent.Name)
                                end
                            end
                        end
                    end)
                end
            end)
        end
    end,
})

EggGroup:AddToggle("EquipBest", {
    Text = "Equip Best",
    Default = false,
    Callback = function(Value)
        _G.Equip = Value
        if Value then
            task.spawn(function()
                while _G.Equip do
                    pcall(function() replicatedStorage._Net.EquipBestPets:FireServer() end)
                    task.wait(5)
                end
            end)
        end
    end,
})

EggGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
    Callback = function(Value)
        _G.Rebirth = Value
        if Value then
            task.spawn(function()
                while _G.Rebirth do
                    pcall(function() replicatedStorage._Net.RequestRebirth:FireServer() end)
                    task.wait(5)
                end
            end)
        end
    end,
})

-- ==========================================
-- Auto Pop Bubble
-- ==========================================
EggGroup:AddToggle("AutoPopBubble", {
    Text = "Auto Pop Bubble",
    Default = false,
    Callback = function(Value)
        _G.PopBubble = Value
        if _G.PopBubbleEventCon then
            pcall(function() _G.PopBubbleEventCon:Disconnect() end)
            _G.PopBubbleEventCon = nil
        end
        if not Value then return end

        local ok, con = pcall(function()
            return replicatedStorage._Net.PromptBubble.OnClientEvent:Connect(function(...)
                if not _G.PopBubble then return end
                local args = table.pack(...)
                for i = 1, args.n do
                    if args[i] ~= nil then
                        pcall(function() replicatedStorage._Net.PopBubble:FireServer(args[i]) end)
                    end
                end
            end)
        end)
        if ok then _G.PopBubbleEventCon = con end

        task.spawn(function()
            while _G.PopBubble do
                pcall(function()
                    for _, v in ipairs(workspace:GetDescendants()) do
                        if not _G.PopBubble then break end
                        local n = v.Name:lower()
                        
                        if (n:find("bubble") or n:find("coin") or n:find("cash")) then
                            if v:IsA("ProximityPrompt") then
                                pcall(function() fireproximityprompt(v) end)
                            elseif v:IsA("ClickDetector") then
                                pcall(function() fireclickdetector(v) end)
                            elseif v:IsA("BasePart") or v:IsA("Model") then
                                local pp = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if pp then pcall(function() fireproximityprompt(pp) end) end
                                
                                local cd = v:FindFirstChildWhichIsA("ClickDetector", true)
                                if cd then pcall(function() fireclickdetector(cd) end) end
                                
                                if replicatedStorage._Net:FindFirstChild("PopBubble") then
                                    pcall(function() replicatedStorage._Net.PopBubble:FireServer(v) end)
                                    local uid = v:GetAttribute("UID") or v:GetAttribute("Id") or v:GetAttribute("BubbleId")
                                    if uid then pcall(function() replicatedStorage._Net.PopBubble:FireServer(uid) end) end
                                end
                            end
                        end
                    end
                end)
                task.wait(0.2)
            end
        end)
    end,
})

-- ==========================================
-- MAIN TAB - Auto Gym
-- ==========================================
local GymGroup = MainTab:AddLeftGroupbox("Auto Gym", "dumbbell")

GymGroup:AddToggle("AutoGym", {
    Text = "Auto Gym (Own Bench)",
    Default = false,
    Callback = function(Value)
        _G.Gym = Value
        if Value then
            local hrp = getHRP()
            if hrp and not cachedBench then
                local plots = workspace:FindFirstChild("Plots")
                if plots then
                    local closestPlot, minDist = nil, 50
                    for _, plot in ipairs(plots:GetChildren()) do
                        local gym = plot:FindFirstChild("Gym")
                        if gym and gym:FindFirstChild("Bench") then
                            local benchPart = gym.Bench:IsA("Model") and gym.Bench.PrimaryPart or gym.Bench
                            if benchPart then
                                local d = (hrp.Position - benchPart.Position).Magnitude
                                if d < minDist then
                                    minDist = d
                                    closestPlot = plot
                                end
                            end
                        end
                    end
                    if closestPlot then
                        cachedBench = closestPlot.Gym.Bench
                    end
                end
            end

            task.spawn(function()
                while _G.Gym do
                    pcall(function()
                        local bench = findMyBench()
                        local hrp = getHRP()
                        if bench and hrp then
                            local pivot = bench:IsA("Model") and bench:GetPivot() or bench.CFrame
                            hrp.CFrame = pivot + Vector3.new(0, 3, 0)
                            task.wait(0.2)
                            replicatedStorage._Net.StartBench:FireServer()
                            task.wait(0.2)
                            replicatedStorage._Net.GymGain:FireServer()
                        end
                    end)
                    task.wait(1)
                end
                pcall(function() replicatedStorage._Net.LeaveBench:FireServer() end)
            end)
        end
    end,
})

GymGroup:AddButton({
    Text = "Force Set Base to Current Plot",
    Func = function()
        local hrp = getHRP()
        if not hrp then return end
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return end

        local closestPlot, minDist = nil, math.huge
        for _, plot in ipairs(plots:GetChildren()) do
            local gym = plot:FindFirstChild("Gym")
            if gym and gym:FindFirstChild("Bench") then
                local pivot = plot:GetPivot().Position
                local d = (hrp.Position - pivot).Magnitude
                if d < minDist and d < 50 then
                    minDist = d
                    closestPlot = plot
                end
            end
        end

        if closestPlot then
            local gym = closestPlot:FindFirstChild("Gym")
            cachedBench = gym:FindFirstChild("Bench")
            print("✅ Manually locked base to: " .. closestPlot.Name)
        else
            print("❌ You are not standing close enough to any plot!")
        end
    end,
})

GymGroup:AddToggle("AutoGymUpgrade", {
    Text = "Auto Buy / Upgrade Gym",
    Default = false,
    Callback = function(Value)
        _G.BuyGym = Value
        if Value then
            task.spawn(function()
                while _G.BuyGym do
                    pcall(function()
                        replicatedStorage._Net.BuyGym:FireServer()
                        replicatedStorage._Net.UpgradeGym:FireServer()
                    end)
                    task.wait(3)
                end
            end)
        end
    end,
})

-- ==========================================
-- MISC TAB - Combat
-- ==========================================
local MiscCombat = MiscTab:AddLeftGroupbox("Combat", "shield")

MiscCombat:AddToggle("AntiGuardianFling", {
    Text = "Anti Guardian Fling",
    Default = false,
    Callback = function(Value)
        _G.AntiFling = Value
        if Value then
            if _G.AntiFlingCon then _G.AntiFlingCon:Disconnect() end
            _G.AntiFlingCon = replicatedStorage._Net.GuardianFling.OnClientEvent:Connect(function()
                if _G.AntiFling then
                    teleportToMyBench()
                end
            end)
        else
            if _G.AntiFlingCon then _G.AntiFlingCon:Disconnect() end
            _G.AntiFlingCon = nil
        end
    end,
})

MiscCombat:AddToggle("AntiGuardianSnap", {
    Text = "Pin Position (extra anti-fling)",
    Default = false,
    Callback = function(Value)
        if Value then
            _G.AntiSnapCon = runService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and _G.AntiFling then hrp.AssemblyLinearVelocity = Vector3.zero end
            end)
        else
            if _G.AntiSnapCon then _G.AntiSnapCon:Disconnect() end
            _G.AntiSnapCon = nil
        end
    end,
})

-- ==========================================
-- SHOP TAB
-- ==========================================
local ShopGroup = ShopTab:AddLeftGroupbox("Shop Automation", "shopping-cart")

local trailRarities = {
    "common", "uncommon", "rare", "epic", "legendary",
    "mythic", "cosmic", "secret", "eternal", "divine"
}

ShopGroup:AddToggle("AutoBuyTrails", {
    Text = "Auto Buy All Trails (Rarities)",
    Default = false,
    Callback = function(Value)
        _G.BuyTrails = Value
        if Value then
            task.spawn(function()
                while _G.BuyTrails do
                    for _, rarity in ipairs(trailRarities) do
                        if not _G.BuyTrails then break end
                        pcall(function() replicatedStorage._Net.BuyTrail:FireServer(rarity) end)
                        task.wait(0.5)
                    end
                    task.wait(5)
                end
            end)
        end
    end,
})

ShopGroup:AddButton({
    Text = "Buy All Trails (One Shot)",
    Func = function()
        for _, rarity in ipairs(trailRarities) do
            pcall(function() replicatedStorage._Net.BuyTrail:FireServer(rarity) end)
            task.wait(0.5)
        end
    end,
})

ShopGroup:AddToggle("AutoEquipTrail", {
    Text = "Auto Equip Best Trail",
    Default = false,
    Callback = function(Value)
        _G.EquipTrail = Value
        if Value then
            task.spawn(function()
                while _G.EquipTrail do
                    pcall(function()
                        replicatedStorage._Net.EquipTrail:FireServer("divine")  task.wait(0.5)
                        replicatedStorage._Net.EquipTrail:FireServer("eternal") task.wait(0.5)
                        replicatedStorage._Net.EquipTrail:FireServer("secret")  task.wait(0.5)
                        replicatedStorage._Net.EquipTrail:FireServer("cosmic")  task.wait(0.5)
                        replicatedStorage._Net.EquipTrail:FireServer("mythic")
                    end)
                    task.wait(10)
                end
            end)
        end
    end,
})

ShopGroup:AddToggle("AutoSellAllPets", {
    Text = "Auto Sell All Pets",
    Default = false,
    Callback = function(Value)
        _G.AutoSell = Value
        if Value then
            task.spawn(function()
                while _G.AutoSell do
                    pcall(function() replicatedStorage._Net.SellAllPets:FireServer() end)
                    task.wait(10)
                end
            end)
        end
    end,
})

ShopGroup:AddToggle("AutoUpgradeCarry", {
    Text = "Auto Upgrade Carry",
    Default = false,
    Callback = function(Value)
        _G.UpgradeCarry = Value
        if Value then
            task.spawn(function()
                while _G.UpgradeCarry do
                    pcall(function() replicatedStorage._Net.UpgradeCarry:FireServer() end)
                    task.wait(5)
                end
            end)
        end
    end,
})

-- ==========================================
-- SETTINGS TAB - Player Mods
-- ==========================================
local PlayerGroup = SettingsTab:AddLeftGroupbox("Player Mods", "user")

PlayerGroup:AddSlider("WalkSpeed", {
    Text = "Walk Speed (1-1000)",
    Min = 1, Max = 1000, Default = 16, Rounding = 1,
    Callback = function(Value)
        local hum = getHumanoid() if hum then hum.WalkSpeed = Value end
    end,
})

PlayerGroup:AddSlider("JumpPower", {
    Text = "Jump Power (1-500)",
    Min = 1, Max = 500, Default = 50, Rounding = 1,
    Callback = function(Value)
        local hum = getHumanoid()
        if hum then hum.UseJumpPower = true; hum.JumpPower = Value end
    end,
})

PlayerGroup:AddToggle("Noclip", {
    Text = "Noclip",
    Default = false,
    Callback = function(Value)
        if Value then
            _G.NoclipCon = runService.Stepped:Connect(function()
                local char = localPlayer.Character
                if char then
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
            end)
        else
            if _G.NoclipCon then _G.NoclipCon:Disconnect() end
            local char = localPlayer.Character
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = true end
                end
            end
        end
    end,
})

PlayerGroup:AddToggle("InfJump", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(Value)
        if Value then
            _G.InfJumpCon = userInput.JumpRequest:Connect(function()
                local hum = getHumanoid()
                if hum then hum:ChangeState("Jumping") end
            end)
        else
            if _G.InfJumpCon then _G.InfJumpCon:Disconnect() end
        end
    end,
})

-- ==========================================
-- SETTINGS TAB - Game Settings
-- ==========================================
local GameGroup = SettingsTab:AddRightGroupbox("Game Settings", "settings")

GameGroup:AddToggle("NoPause", {
    Text = "No Pause Game",
    Default = false,
    Callback = function(Value)
        pcall(function() setfflag("FFlagDebugDisablePauseOnFocusLost", Value and "True" or "False") end)
    end,
})

GameGroup:AddToggle("AntiAFK", {
    Text = "Anti-AFK",
    Default = false,
    Callback = function(Value)
        if Value then
            _G.AntiAFKCon = localPlayer.Idled:Connect(function()
                game:GetService("VirtualUser"):CaptureController()
                game:GetService("VirtualUser"):ClickButton2(Vector2.new(500, 500))
            end)
        else
            if _G.AntiAFKCon then _G.AntiAFKCon:Disconnect() end
        end
    end,
})

local InstantProxCon = nil
GameGroup:AddToggle("InstantProx", {
    Text = "Instant Proximity",
    Default = false,
    Callback = function(Value)
        if Value then
            local function makeInstant(obj)
                if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
            end
            for _, v in pairs(workspace:GetDescendants()) do makeInstant(v) end
            InstantProxCon = workspace.DescendantAdded:Connect(makeInstant)
        else
            if InstantProxCon then InstantProxCon:Disconnect() end
        end
    end,
})

GameGroup:AddToggle("LockUI", {
    Text = "Lock UI Window",
    Default = false,
    Callback = function(Value)
        for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") and (string.find(gui.Name:lower(), "jenicakes")
                or string.find(gui.Name:lower(), "obsidian")) then
                for _, frame in pairs(gui:GetDescendants()) do
                    if frame:IsA("Frame") or frame:IsA("TextButton") then
                        if frame.Active    ~= nil then frame.Active    = not Value end
                        if frame.Draggable ~= nil then frame.Draggable = not Value end
                    end
                end
            end
        end
    end,
})

-- ==========================================
-- SETTINGS TAB - Unload Button
-- ==========================================
GameGroup:AddButton({
    Text = "Unload UI",
    Func = function()
        _G.Steal, _G.Place, _G.Hatch, _G.Equip, _G.Rebirth = false, false, false, false, false
        _G.PopBubble, _G.Gym, _G.BuyGym                     = false, false, false
        _G.BuyTrails, _G.EquipTrail, _G.AutoSell, _G.UpgradeCarry = false, false, false, false
        _G.AntiFling = false

        if _G.NoclipCon         then pcall(function() _G.NoclipCon:Disconnect()         end) end
        if _G.InfJumpCon        then pcall(function() _G.InfJumpCon:Disconnect()        end) end
        if _G.AntiAFKCon        then pcall(function() _G.AntiAFKCon:Disconnect()        end) end
        if _G.PopBubbleEventCon then pcall(function() _G.PopBubbleEventCon:Disconnect() end) end
        if _G.AntiFlingCon      then pcall(function() _G.AntiFlingCon:Disconnect()      end) end
        if _G.AntiSnapCon       then pcall(function() _G.AntiSnapCon:Disconnect()       end) end
        if InstantProxCon       then pcall(function() InstantProxCon:Disconnect()       end) end

        pcall(function() setfflag("FFlagDebugDisablePauseOnFocusLost", "False") end)
        teleportToMyBench()

        pcall(function() Window:Destroy() end)
        pcall(function() Window:Unload() end)
        pcall(function() Jenicakes:Destroy() end)
        pcall(function() Jenicakes:Unload() end)

        for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") and (string.find(gui.Name:lower(), "jenicakes")
                or string.find(gui.Name:lower(), "obsidian")
                or string.find(gui.Name:lower(), "hub")) then
                pcall(function() gui:Destroy() end)
            end
        end
        for _, gui in pairs(localPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (string.find(gui.Name:lower(), "jenicakes")
                or string.find(gui.Name:lower(), "obsidian")
                or string.find(gui.Name:lower(), "hub")) then
                pcall(function() gui:Destroy() end)
            end
        end

        _G.NoclipCon, _G.InfJumpCon, _G.AntiAFKCon = nil, nil, nil
        _G.PopBubbleEventCon                        = nil
        _G.AntiFlingCon, _G.AntiSnapCon            = nil, nil
        InstantProxCon                              = nil
    end,
})
