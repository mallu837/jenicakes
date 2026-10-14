local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local virtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

if getgenv().JenicakesHub and type(getgenv().JenicakesHub.Unload) == "function" then
  pcall(function() getgenv().JenicakesHub:Unload() end)
end

local function f1()
  local v1 = {
    Version = "3.4.0",
    Running = true,
    Window = nil,
    WindUI = nil,
    Connections = {},
    Toggles = {},
    Settings = {
      AutoStealEggs = false,
      AutoPlaceEggs = false,
      AutoHatch = false,
      AutoCollectCash = false,
      AutoEquipBest = false,
      AutoClaimIndex = false,
      AutoFreeGifts = false,
      AutoTreadmill = false,
      AutoClaimBubbles = true,
      AutoUpgradeTreadmill = false,
      AutoUpgradePlot = false,
      AutoSell = false,
      AutoBatAura = false,
      InfiniteJump = false,
      Noclip = false,
      AntiAFK = false,
      TargetZone = "All Zones",
      TargetRarities = { "Any" },
      TargetRarity = "Any",
      MinEggWeight = 0,
      StealDelay = 0.3,
      ReturnDelay = 0.4,
      HatchInterval = 1,
      CollectInterval = 1.5,
      EquipInterval = 5,
      IndexInterval = 10,
      GiftInterval = 15,
      TreadmillSpeedLimit = 0,
      UpgradeReserveCash = 0,
      UpgradeInterval = 3,
      SellThreshold = "1M",
      SellInterval = 10,
      BatAuraRadius = 18,
      BatAuraInterval = 0.25,
    },
  }

  getgenv().JenicakesHub = v1
  local localPlayer = players.LocalPlayer
  local waitForChild = replicatedStorage:WaitForChild("Events", 15)
  local waitForChild2 = waitForChild:WaitForChild("RequestHatch", 10)
  local waitForChild3 = waitForChild:WaitForChild("RequestSell", 10)
  local waitForChild4 = waitForChild:WaitForChild("PlaceTreadmill", 10)
  local waitForChild5 = waitForChild:WaitForChild("LeaveTreadmill", 10)
  local waitForChild6 = waitForChild:WaitForChild("TreadmillBubbleSpawn", 10)
  local waitForChild7 = waitForChild:WaitForChild("TreadmillBubbleClaim", 10)
  local waitForChild8 = waitForChild:WaitForChild("DropEgg", 10)
  local waitForChild9 = waitForChild:WaitForChild("EquipBestPets", 10)
  local waitForChild10 = waitForChild:WaitForChild("ClaimIndexReward", 10)
  local waitForChild11 = waitForChild:WaitForChild("ClaimFreeGift", 10)
  local waitForChild12 = waitForChild:WaitForChild("RequestTreadmillUpgrade", 10)
  local waitForChild13 = waitForChild:WaitForChild("RequestPlotUpgrade", 10)
  local waitForChild14 = waitForChild:WaitForChild("BatSwing", 10)
  local waitForChild15 = waitForChild:WaitForChild("SetOnboardingStep", 10)
  local v2 = require(replicatedStorage:WaitForChild("Modules", 10):WaitForChild("EggConfigurations"))

  task.spawn(function()
    if localPlayer:GetAttribute("OnboardingStep")
      and localPlayer:GetAttribute("OnboardingStep") < 4 then
      pcall(function() waitForChild15:FireServer(4) end)
    end
  end)

  local v3 = {
    { id = "Zone1", name = "Ninja Village", order = 1 },
    { id = "Zone2", name = "Sakura Kingdom", order = 2 },
    { id = "Zone3", name = "Pirate Island", order = 3 },
    { id = "Zone4", name = "Demon Realm", order = 4 },
    { id = "Zone5", name = "Cursed City", order = 5 },
    { id = "Zone6", name = "Soul Realm", order = 6 },
    { id = "Zone7", name = "Striker Academy", order = 7 },
    { id = "Zone8", name = "Dragon Sanctuary", order = 8 },
    { id = "Zone9", name = "Shadow Warzone", order = 9 },
    { id = "Zone10", name = "Cosmic Observatory", order = 10 },
    { id = "Zone11", name = "Spirit City", order = 11 },
    { id = "Zone12", name = "Malevolent Shrine", order = 12 },
  }

  local v4 = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Secret = 7,
    Divine = 8,
    Eternity = 9,
    Sovereign = 10,
  }

  local function f2(p1)
    if not p1 then
      return "Common"
    else
      local rarity = p1:GetAttribute("Rarity")

      if rarity and rarity ~= "None" and rarity ~= "" then
        return rarity
      else
        local originalName = p1:GetAttribute("OriginalName")

        if originalName and v2.EggSettings and v2.EggSettings[originalName] then
          return v2.EggSettings[originalName].Rarity or "Common"
        end

        return "Common"
      end
    end
  end

  local function f3(p2, p3)
    if not p3 then
      return true
    elseif type(p3) == "string" then
      if p3 == "Any" then
        return true
      end

      return string.lower(p3) == string.lower(p2)
    elseif type(p3) == "table" then
      if #p3 == 0 then
        return true
      end

      for index, value in ipairs(p3) do
        if value == "Any" then
          return true
        elseif string.lower(tostring(value)) == string.lower(tostring(p2)) then
          return true
        end
      end

      return false
    else
      return true
    end
  end

  local function f4()
    local findFirstChild = workspace:FindFirstChild("Plot_" .. localPlayer.Name)

    if findFirstChild then
      return findFirstChild
    end

    for index2, value2 in ipairs(workspace.Plots:GetChildren()) do
      local owner = value2:FindFirstChild("Owner")

      if owner and owner.Value == localPlayer then
        return value2
      end

      if tostring(value2:GetAttribute("Owner")) == localPlayer.Name
        or tostring(value2:GetAttribute("Owner")) == tostring(localPlayer.UserId) then
        return value2
      end
    end

    return nil
  end

  local function f5()
    return localPlayer.Character or localPlayer.CharacterAdded:Wait()
  end

  local function f6()
    return f5():WaitForChild("HumanoidRootPart", 5)
  end

  local function f7(p4)
    if type(p4) == "number" then
      return p4
    else
      local v5 = tostring(p4)
      local v6 = string.lower(string.gsub(v5, "[%s,_%$]", ""))

      local v7 = {
        k = 1000,
        m = 1000000,
        b = 1000000000,
        t = 1000000000000,
        qd = 1000000000000000,
        qn = 1000000000000000000,
        sx = 1e+21,
        sp = 1e+24,
      }

      local v8, v9 = string.match(v6, "^(%d*%.?%d+)(%a*)$")
      local v10 = tonumber(v8)

      if not v10 then
        return 0
      end

      if v9 and v7[v9] then
        v10 = v10 * v7[v9]
      end

      return v10
    end
  end

  local function f8(p5)
    if not p5 or not p5.Parent then
      return
    end

    pcall(function()
      local holdDuration = p5.HoldDuration or 0.6

      if fireproximityprompt then
        fireproximityprompt(p5, holdDuration)
      else
        p5:InputHoldBegin()
        task.wait(holdDuration + 0.1)
        p5:InputHoldEnd()
      end
    end)
  end

  local function f9()
    local v11 = f5()
    local v12 = f6()
    local humanoid = v11:FindFirstChildOfClass("Humanoid")
    local v13 = f4()
    local eggHatch = v13 and v13:FindFirstChild("EggHatch")

    if not v12 or not eggHatch then
      return
    end

    v12.CFrame = eggHatch.CFrame + Vector3.new(0, 2.5, 0)
    task.wait(0.2)
    pcall(function() waitForChild8:FireServer() end)
    task.wait(0.2)

    for index3, value3 in ipairs(v11:GetChildren()) do
      local v14 = value3

      if v14:IsA("Tool") and (v14:GetAttribute("OriginalName") or string.find(v14.Name, "Egg"))
        and not v14:GetAttribute("IsBat") and not v14:GetAttribute("IsTreadmill") then
        pcall(function() v14:Activate() end)
        task.wait(0.15)
      end
    end

    for index4, value4 in ipairs(localPlayer.Backpack:GetChildren()) do
      local v15 = value4

      if v15:IsA("Tool") and (v15:GetAttribute("OriginalName") or string.find(v15.Name, "Egg"))
        and not v15:GetAttribute("IsBat") and not v15:GetAttribute("IsTreadmill") then
        if humanoid then
          humanoid:EquipTool(v15)
          task.wait(0.15)
          pcall(function() v15:Activate() end)
          task.wait(0.15)
        end
      end
    end
  end

  local windUI = loadstring(game:HttpGet("https://github.com/mallu837/JenicakesUI/releases/latest/download/main.lua"))()
  v1.WindUI = windUI

  local jenicakesWindow = windUI:CreateWindow({
    Title = "Jenicakes Hub",
    Icon = "egg",
    Author = "Steal Anime Eggs",
    Folder = "JenicakesHub_StealAnimeEggs",
    Size = UDim2.fromOffset(600, 480),
    Transparent = true,
    Theme = "Dark",
    Acrylic = false,
    Resizable = true,
  })

  v1.Window = jenicakesWindow
  pcall(function() jenicakesWindow:SetToTheCenter() end)

  local function f10(p6, p7)
  end

  local function f11(p8, p9)
    v1.Toggles[p8] = p9

    v1[p8] = {
      Set = function(p10, p11)
        v1.Settings[p8] = p11

        if p9 and type(p9.Set) == "function" then
          p9:Set(p11)
        end
      end,
      Toggle = function(p12) p12:Set(not v1.Settings[p8]) end,
      Get = function(p13) return v1.Settings[p8] end,
    }
  end

  local farmingTab = jenicakesWindow:Tab({ Title = "Farming", Icon = "wheat" })
  farmingTab:Section({ Title = "Egg Harvesting & Placing" })

  f11("AutoStealEggs", farmingTab:Toggle({
    Title = "Auto Steal Eggs",
    Desc = "Searches zones for eggs by rarity/weight & brings them to base",
    Value = v1.Settings.AutoStealEggs,
    Callback = function(value5) v1.Settings.AutoStealEggs = value5 end,
  }))

  f11("AutoPlaceEggs", farmingTab:Toggle({
    Title = "Auto Place Eggs",
    Desc = "Continuously deposits any carried or backpack eggs into incubator",
    Value = v1.Settings.AutoPlaceEggs,
    Callback = function(value6) v1.Settings.AutoPlaceEggs = value6 end,
  }))

  local v16 = { "All Zones" }

  for index5, value7 in ipairs(v3) do
    table.insert(v16, value7.id)
  end

  farmingTab:Dropdown({
    Title = "Target Zone (or All Zones)",
    Desc = "Choose 'All Zones' to farm everywhere",
    Values = v16,
    Value = v1.Settings.TargetZone,
    Callback = function(value8)
      v1.Settings.TargetZone = value8
      f10("Target Zone", "Set to: " .. value8)
    end,
  })

  farmingTab:Dropdown({
    Title = "Target Rarities Filter",
    Desc = "Pick one or multiple rarities to steal (Any = all eggs)",
    Values = {
      "Any", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine",
      "Eternity", "Sovereign",
    },
    Value = v1.Settings.TargetRarities,
    Multi = true,
    Callback = function(value9)
      if type(value9) == "table" then
        local v17 = v1.Settings
        v17.TargetRarities = value9
        v173 = #value9 > 0 and table.concat(value9, ", ")
      elseif type(value9) == "string" then
        v1.Settings.TargetRarities = { value9 }
        f10("Rarity Filter", "Selected: " .. value9)
      end
    end,
  })

  farmingTab:Slider({
    Title = "Min Egg Weight Filter",
    Desc = "Ignore eggs with weight below this",
    Value = { Min = 0, Max = 5000, Default = v1.Settings.MinEggWeight },
    Step = 10,
    Callback = function(value10) v1.Settings.MinEggWeight = value10 end,
  })

  farmingTab:Section({ Title = "Incubator & Rewards" })

  f11("AutoHatch", farmingTab:Toggle({
    Title = "Auto Hatch Incubator",
    Desc = "Instantly claims hatched eggs when ready",
    Value = v1.Settings.AutoHatch,
    Callback = function(value11) v1.Settings.AutoHatch = value11 end,
  }))

  f11("AutoCollectCash", farmingTab:Toggle({
    Title = "Auto Collect Cash Pad",
    Desc = "Claims money from your base CollectButton",
    Value = v1.Settings.AutoCollectCash,
    Callback = function(value12) v1.Settings.AutoCollectCash = value12 end,
  }))

  f11("AutoEquipBest", farmingTab:Toggle({
    Title = "Auto Equip Best Animes",
    Desc = "Always equips highest income multiplier animes",
    Value = v1.Settings.AutoEquipBest,
    Callback = function(value13) v1.Settings.AutoEquipBest = value13 end,
  }))

  f11("AutoClaimIndex", farmingTab:Toggle({
    Title = "Auto Claim Index Rewards",
    Desc = "Claims all index rewards in one shot",
    Value = v1.Settings.AutoClaimIndex,
    Callback = function(value14) v1.Settings.AutoClaimIndex = value14 end,
  }))

  f11("AutoFreeGifts", farmingTab:Toggle({
    Title = "Auto Claim Playtime Gifts",
    Desc = "Collects timed session gifts 1-12",
    Value = v1.Settings.AutoFreeGifts,
    Callback = function(value15) v1.Settings.AutoFreeGifts = value15 end,
  }))

  local trainingTab = jenicakesWindow:Tab({ Title = "Training", Icon = "flame" })
  trainingTab:Section({ Title = "Treadmill & Speed" })

  f11("AutoTreadmill", trainingTab:Toggle({
    Title = "Auto Treadmill Trainer",
    Desc = "Equips treadmill tool, places at spawn & trains speed",
    Value = v1.Settings.AutoTreadmill,
    Callback = function(value16) v1.Settings.AutoTreadmill = value16 end,
  }))

  f11("AutoClaimBubbles", trainingTab:Toggle({
    Title = "Auto Claim Speed Bubbles",
    Desc = "Instantly pops every speed bubble the millisecond it spawns",
    Value = v1.Settings.AutoClaimBubbles,
    Callback = function(value17) v1.Settings.AutoClaimBubbles = value17 end,
  }))

  trainingTab:Slider({
    Title = "Target Speed Limit (0 = continuous)",
    Value = { Min = 0, Max = 50000, Default = v1.Settings.TreadmillSpeedLimit },
    Step = 500,
    Callback = function(value18) v1.Settings.TreadmillSpeedLimit = value18 end,
  })

  trainingTab:Section({ Title = "Automatic Upgrades" })

  f11("AutoUpgradeTreadmill", trainingTab:Toggle({
    Title = "Auto Upgrade Treadmill",
    Desc = "Buys higher treadmill tier when affordable",
    Value = v1.Settings.AutoUpgradeTreadmill,
    Callback = function(value19) v1.Settings.AutoUpgradeTreadmill = value19 end,
  }))

  f11("AutoUpgradePlot", trainingTab:Toggle({
    Title = "Auto Upgrade Plot Capacity",
    Desc = "Increases plot size and egg holding capacity",
    Value = v1.Settings.AutoUpgradePlot,
    Callback = function(value20) v1.Settings.AutoUpgradePlot = value20 end,
  }))

  local sellingTab = jenicakesWindow:Tab({ Title = "Selling", Icon = "circle-dollar-sign" })
  sellingTab:Section({ Title = "Inventory Management" })

  f11("AutoSell", sellingTab:Toggle({
    Title = "Smart Auto Sell",
    Desc = "Periodically sells animes earning below threshold",
    Value = v1.Settings.AutoSell,
    Callback = function(value21) v1.Settings.AutoSell = value21 end,
  }))

  sellingTab:Input({
    Title = "Sell Income Threshold",
    Desc = "e.g. 10K, 1M, 100M, 1B",
    Value = v1.Settings.SellThreshold,
    Placeholder = "1M",
    Callback = function(value22)
      v1.Settings.SellThreshold = value22
      f10("Threshold Set", "Selling below " .. value22)
    end,
  })

  sellingTab:Dropdown({
    Title = "Quick Presets",
    Values = { "10K", "100K", "1M", "100M", "1B", "100B", "1T" },
    Value = v1.Settings.SellThreshold,
    Callback = function(value23)
      v1.Settings.SellThreshold = value23
      f10("Preset Set", "Selling below " .. value23)
    end,
  })

  sellingTab:Button({
    Title = "Instant Sell All Below Threshold",
    Callback = function()
      local v18 = f7(v1.Settings.SellThreshold)

      if v18 > 0 then
        pcall(function() waitForChild3:FireServer("BelowIncome", v18) end)
        f10("Sold", "Sold animes below " .. v1.Settings.SellThreshold)
      end
    end,
  })

  local combatTab = jenicakesWindow:Tab({ Title = "Combat", Icon = "swords" })
  combatTab:Section({ Title = "Base Defense" })

  f11("AutoBatAura", combatTab:Toggle({
    Title = "Auto Bat Defense Aura",
    Desc = "Swings bat at players approaching your base",
    Value = v1.Settings.AutoBatAura,
    Callback = function(value24) v1.Settings.AutoBatAura = value24 end,
  }))

  combatTab:Slider({
    Title = "Aura Detection Radius",
    Value = { Min = 8, Max = 35, Default = v1.Settings.BatAuraRadius },
    Step = 1,
    Callback = function(value25) v1.Settings.BatAuraRadius = value25 end,
  })

  local teleportsTab = jenicakesWindow:Tab({ Title = "Teleports", Icon = "map-pin" })
  teleportsTab:Section({ Title = "Waypoints" })

  teleportsTab:Button({
    Title = "Teleport to Your Base",
    Callback = function()
      local v19 = f4()
      local v20 = v19 and (v19:FindFirstChild("Spawn") or v19:FindFirstChild("EggHatch"))
      local v21 = f6()

      if v20 and v21 then
        v21.CFrame = v20.CFrame + Vector3.new(0, 3, 0)
      end
    end,
  })

  teleportsTab:Button({
    Title = "Teleport to Sell NPC (Sanji)",
    Callback = function()
      local v22 = workspace
      local v23 = f6()
      local sanjipnj = v22:FindFirstChild("Sanjipnj") or workspace:FindFirstChild("SellNPC")

      if sanjipnj and v23 then
        local humanoidRootPart = sanjipnj:FindFirstChild("HumanoidRootPart")
          or sanjipnj:FindFirstChild("Head") or sanjipnj.PrimaryPart

        if humanoidRootPart then
          v23.CFrame = humanoidRootPart.CFrame + Vector3.new(0, 2, 4)
        end
      end
    end,
  })

  teleportsTab:Section({ Title = "Zones (1-12)" })

  for index6, value26 in ipairs(v3) do
    local v24 = value26

    teleportsTab:Button({
      Title = "Zone " .. tostring(v24.order) .. ": " .. v24.name,
      Callback = function()
        local v25 = f6()
        local findFirstChild2 = workspace.Eggs:FindFirstChild(v24.id)

        if findFirstChild2 and v25 then
          local eggSpawn = findFirstChild2:FindFirstChild("EggSpawn")
            or findFirstChild2:FindFirstChildWhichIsA("BasePart")

          if eggSpawn then
            v25.CFrame = eggSpawn.CFrame + Vector3.new(0, 4, 0)
            f10("Teleported", "Arrived at " .. v24.name)
          end
        end
      end,
    })
  end

  local miscTab = jenicakesWindow:Tab({ Title = "Misc", Icon = "sliders" })

  miscTab:Section({ Title = "Configuration System" })

  local configFolder = "JenicakesHub_Configs"
  if makefolder and not isfolder(configFolder) then
    pcall(makefolder, configFolder)
  end

  local configInputName = "My config"
  local selectedConfig = "---"
  local jsonText = ""

  local function applySaveData(data)
    if not data or type(data) ~= "table" or not data.Settings then return end
    for k, v in pairs(data.Settings) do
      v1.Settings[k] = v
      if v1.Toggles[k] and v1.Toggles[k].Set then
        pcall(function() v1.Toggles[k]:Set(v) end)
      end
    end
  end

  local function listConfigFiles()
    local files = { "---" }
    if listfiles and isfolder(configFolder) then
      for _, file in ipairs(listfiles(configFolder)) do
        if file:sub(-5) == ".json" and not file:find("autoload_setting.txt") then
          local filename = file:gsub("\\", "/"):match("([^/]+)%.json$")
          if filename then
            table.insert(files, filename)
          end
        end
      end
    end
    return files
  end

  miscTab:Input({
    Title = "Config Name",
    Value = "My config",
    Callback = function(val)
      configInputName = (val and val ~= "") and val or "My config"
    end
  })

  local configDropdown = miscTab:Dropdown({
    Title = "Saved Configs",
    Values = listConfigFiles(),
    Value = "---",
    Callback = function(val)
      selectedConfig = val
    end
  })

  local function refreshDropdown()
    if configDropdown then
      local newFiles = listConfigFiles()
      if type(configDropdown.SetValues) == "function" then
        configDropdown:SetValues(newFiles)
      elseif type(configDropdown.Refresh) == "function" then
        configDropdown:Refresh(newFiles)
      end
    end
  end

  miscTab:Button({
    Title = "+ Create Config",
    Callback = function()
      if writefile then
        local name = (configInputName ~= "" and configInputName) and configInputName or "My config"
        local path = configFolder .. "/" .. name .. ".json"
        writefile(path, HttpService:JSONEncode({ Settings = v1.Settings }))
        refreshDropdown()
      end
    end
  })

  miscTab:Button({
    Title = "📂 Load Config",
    Callback = function()
      if selectedConfig ~= "---" and isfile then
        local path = configFolder .. "/" .. selectedConfig .. ".json"
        if isfile(path) then
          local raw = readfile(path)
          local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
          if ok and decoded then applySaveData(decoded) end
        end
      end
    end
  })

  miscTab:Button({
    Title = "💾 Overwrite Config",
    Callback = function()
      if selectedConfig ~= "---" and writefile then
        local path = configFolder .. "/" .. selectedConfig .. ".json"
        writefile(path, HttpService:JSONEncode({ Settings = v1.Settings }))
      end
    end
  })

  miscTab:Button({
    Title = "🗑️ Delete Config",
    Callback = function()
      if selectedConfig ~= "---" and delfile then
        local path = configFolder .. "/" .. selectedConfig .. ".json"
        if isfile(path) then
          delfile(path)
          refreshDropdown()
          selectedConfig = "---"
        end
      end
    end
  })

  miscTab:Button({
    Title = "🔄 Refresh Configs",
    Callback = function()
      refreshDropdown()
    end
  })

  local autoloadLabel = miscTab:Paragraph({
    Title = "⭐ Autoload: None",
    Desc = ""
  })

  local function updateAutoloadLabel(name)
    if autoloadLabel and type(autoloadLabel.SetTitle) == "function" then
      autoloadLabel:SetTitle("⭐ Autoload: " .. name)
    end
  end

  miscTab:Button({
    Title = "⭐ Set Autoload",
    Callback = function()
      if selectedConfig ~= "---" and writefile then
        writefile(configFolder .. "/autoload_setting.txt", selectedConfig)
        updateAutoloadLabel(selectedConfig)
      end
    end
  })

  miscTab:Button({
    Title = "🗑️ Clear Autoload",
    Callback = function()
      if writefile then
        writefile(configFolder .. "/autoload_setting.txt", "None")
        updateAutoloadLabel("None")
      end
    end
  })

  local jsonInput = miscTab:Input({
    Title = "Config JSON",
    Value = "Exported JSON appears here",
    Callback = function(val)
      jsonText = val
    end
  })

  miscTab:Button({
    Title = "📥 Import JSON",
    Callback = function()
      if jsonText ~= "" and jsonText ~= "Exported JSON appears here" then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(jsonText) end)
        if ok and decoded then applySaveData(decoded) end
      end
    end
  })

  miscTab:Button({
    Title = "📤 Export JSON",
    Callback = function()
      local str = HttpService:JSONEncode({ Settings = v1.Settings })
      if jsonInput and type(jsonInput.SetValue) == "function" then
        jsonInput:SetValue(str)
      end
      jsonText = str
    end
  })

  miscTab:Button({
    Title = "📋 Copy JSON",
    Callback = function()
      local str = HttpService:JSONEncode({ Settings = v1.Settings })
      if setclipboard then
        setclipboard(str)
      elseif toclipboard then
        toclipboard(str)
      end
    end
  })

  miscTab:Section({ Title = "Mobility & Protections" })

  f11("InfiniteJump", miscTab:Toggle({
    Title = "Infinite Jump",
    Value = v1.Settings.InfiniteJump,
    Callback = function(value27) v1.Settings.InfiniteJump = value27 end,
  }))

  f11("Noclip", miscTab:Toggle({
    Title = "Noclip",
    Value = v1.Settings.Noclip,
    Callback = function(value28) v1.Settings.Noclip = value28 end,
  }))

  f11("AntiAFK", miscTab:Toggle({
    Title = "Anti-AFK Protection",
    Desc = "Prevents 20-minute idle disconnect",
    Value = v1.Settings.AntiAFK,
    Callback = function(value29) v1.Settings.AntiAFK = value29 end,
  }))

  local connect = localPlayer.Idled:Connect(function()
    if v1.Settings.AntiAFK then
      virtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
      task.wait(1)
      virtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
  end)

  table.insert(v1.Connections, connect)

  miscTab:Section({ Title = "Unload" })
  miscTab:Button({ Title = "Clean Unload Script", Callback = function() v1:Unload() end })

  local connect2 = waitForChild6.OnClientEvent:Connect(function(p14)
    if v1.Settings.AutoClaimBubbles then
      pcall(function() waitForChild7:FireServer(p14) end)
    end
  end)

  table.insert(v1.Connections, connect2)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoClaimBubbles then
        pcall(function()
          local treadmillBubbles = localPlayer.PlayerGui:FindFirstChild("TreadmillBubbles")

          if treadmillBubbles then
            for index7, value30 in ipairs(treadmillBubbles:GetDescendants()) do
              if value30:IsA("ImageButton") and value30.Name == "Clic" then
                local parent = value30.Parent

                if parent and parent:IsA("Frame") then
                  for index8, value31 in ipairs(value30:GetChildren()) do
                  end
                end
              end
            end
          end
        end)
      end

      task.wait(0.5)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoStealEggs then
        pcall(function()
          local v26 = f5()
          local v27 = f6()
          local v28 = f4()
          local eggHatch2 = v28 and v28:FindFirstChild("EggHatch")

          if not v27 or not eggHatch2 then
            return
          else
            local count = 0

            for index9, value32 in ipairs(eggHatch2:GetChildren()) do
              if value32:IsA("Model") and value32:GetAttribute("IsEgg") then
                count = count + 1
              end
            end

            if count >= 7 then
              task.wait(2)
              return
            else
              if v26:GetAttribute("OnTreadmill") then
                pcall(function() waitForChild5:FireServer() end)
                task.wait(0.3)
              end

              local v29 = {}

              if v1.Settings.TargetZone == "All Zones" then
                for index10, value33 in ipairs(workspace.Eggs:GetChildren()) do
                  table.insert(v29, value33)
                end
              else
                local findFirstChild3 = workspace.Eggs:FindFirstChild(v1.Settings.TargetZone)

                if findFirstChild3 then
                  table.insert(v29, findFirstChild3)
                end
              end

              local v30 = {}

              for index11, value34 in ipairs(v29) do
                for index12, value35 in ipairs(value34:GetChildren()) do
                  local spawnedEgg = value35:FindFirstChild("SpawnedEgg")

                  if spawnedEgg and spawnedEgg:FindFirstChild("Root")
                    and spawnedEgg.Root:FindFirstChild("ProximityPrompt") then
                    local proximityPrompt = spawnedEgg.Root.ProximityPrompt

                    if proximityPrompt.Enabled then
                      local v31 = tonumber(spawnedEgg:GetAttribute("EggWeight")
                        or spawnedEgg:GetAttribute("Weight") or 0)

                      local v32 = f2(spawnedEgg)

                      if v31 >= v1.Settings.MinEggWeight
                        and f3(v32, v1.Settings.TargetRarities or v1.Settings.TargetRarity) then
                        table.insert(v30, {
                          prompt = proximityPrompt,
                          weight = v31,
                          rank = v4[v32] or 1,
                        })
                      end
                    end
                  end
                end
              end

              table.sort(v30, function(p15, p16)
                if p15.rank ~= p16.rank then
                  return p15.rank > p16.rank
                end

                return p15.weight > p16.weight
              end)

              if #v30 > 0 then
                local prompt = v30[1].prompt
                v27.CFrame = prompt.Parent.CFrame + Vector3.new(0, 1.5, 0)
                task.wait(v1.Settings.StealDelay)
                f8(prompt)
                task.wait(0.5)
                f9()
                task.wait(v1.Settings.ReturnDelay)
              end

              return
            end
          end
        end)
      end

      task.wait(0.6)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoPlaceEggs then
        pcall(function()
          local v33 = f5()
          local v34 = false

          for index13, value36 in ipairs(localPlayer.Backpack:GetChildren()) do
            if value36:IsA("Tool")
              and (value36:GetAttribute("OriginalName") or string.find(value36.Name, "Egg"))
              and not value36:GetAttribute("IsBat") and not value36:GetAttribute("IsTreadmill") then
              v34 = true
              break
            end
          end

          if v34 or v33:GetAttribute("CarryingEgg") or v33:FindFirstChild("CarriedEgg") ~= nil then
            f9()
          end
        end)
      end

      task.wait(1.5)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoHatch then
        pcall(function()
          local v35 = f4()
          local eggHatch3 = v35 and v35:FindFirstChild("EggHatch")
          local v36 = f6()

          if eggHatch3 and v36 then
            for index14, value37 in ipairs(eggHatch3:GetChildren()) do
              local v37 = value37

              if v37:IsA("Model") and v37:GetAttribute("IsEgg") then
                pcall(function() waitForChild2:FireServer(v37) end)
                local root = v37:FindFirstChild("Root")

                local proximityPrompt2 = root
                proximityPrompt2 = root and v37.Root:FindFirstChild("ProximityPrompt")

                if proximityPrompt2 and proximityPrompt2.Enabled
                  and proximityPrompt2.ActionText == "Hatch" then
                  local cframe = v36.CFrame
                  v36.CFrame = v37.Root.CFrame + Vector3.new(0, 1, 0)
                  task.wait(0.12)
                  f8(proximityPrompt2)
                  task.wait(0.15)
                  v36.CFrame = cframe
                end
              end
            end
          end
        end)
      end

      task.wait(v1.Settings.HatchInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoCollectCash then
        pcall(function()
          local v38 = f4()
          local collectButton = v38 and v38:FindFirstChild("CollectButton")
          local pad = collectButton and collectButton:FindFirstChild("Pad")
          local v39 = f6()

          if pad and v39 then
            if firetouchinterest then
              firetouchinterest(v39, pad, 0)
              task.wait(0.05)
              firetouchinterest(v39, pad, 1)
            else
              local cframe2 = v39.CFrame
              v39.CFrame = pad.CFrame + Vector3.new(0, 2, 0)
              task.wait(0.1)
              v39.CFrame = cframe2
            end
          end
        end)
      end

      task.wait(v1.Settings.CollectInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoEquipBest then
        pcall(function() waitForChild9:FireServer() end)
      end

      task.wait(v1.Settings.EquipInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoClaimIndex then
        pcall(function() waitForChild10:InvokeServer("ALL") end)
      end

      task.wait(v1.Settings.IndexInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoFreeGifts then
        pcall(function()
          local count2 = 0

          while true do
            count2 = 1 + count2

            if not (12 >= count2) then
              break
            end

            waitForChild11:InvokeServer(count2)
            task.wait(0.15)
          end
        end)
      end

      task.wait(v1.Settings.GiftInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoTreadmill then
        pcall(function()
          local v40 = f5()
          local v41 = f6()
          local humanoid2 = v40:FindFirstChildOfClass("Humanoid")
          local leaderstats = localPlayer:FindFirstChild("leaderstats")

          local value38 = leaderstats and leaderstats:FindFirstChild("Speed")
              and leaderstats.Speed.Value
            or 0

          if v1.Settings.TreadmillSpeedLimit > 0 and value38 >= v1.Settings.TreadmillSpeedLimit then
            return
          end

          if not v40:GetAttribute("OnTreadmill") then
            local v42 = f4()
            local treadmillSpawn = v42 and v42:FindFirstChild("TreadmillSpawn")

            if treadmillSpawn and v41 then
              v41.CFrame = treadmillSpawn.CFrame + Vector3.new(0, 2.5, 0)
              task.wait(0.2)
            end

            local treadmill = localPlayer.Backpack:FindFirstChild("Treadmill")
              or v40:FindFirstChild("Treadmill")

            if treadmill and humanoid2 then
              humanoid2:EquipTool(treadmill)
              task.wait(0.25)
              local currentCamera = workspace.CurrentCamera

              waitForChild4:FireServer(currentCamera and currentCamera.CFrame.LookVector
                or Vector3.new(0, 0, 1))
            end
          end
        end)
      end

      task.wait(1)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoUpgradeTreadmill or v1.Settings.AutoUpgradePlot then
        pcall(function()
          local leaderstats2 = localPlayer:FindFirstChild("leaderstats")

          if (leaderstats2 and leaderstats2:FindFirstChild("Money") and leaderstats2.Money.Value
              or 0)
            > v1.Settings.UpgradeReserveCash then
            if v1.Settings.AutoUpgradeTreadmill then
              waitForChild12:InvokeServer()
            end

            if v1.Settings.AutoUpgradePlot then
              waitForChild13:InvokeServer()
            end
          end
        end)
      end

      task.wait(v1.Settings.UpgradeInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoSell then
        pcall(function()
          local v43 = f7(v1.Settings.SellThreshold)

          if v43 > 0 then
            waitForChild3:FireServer("BelowIncome", v43)
          end
        end)
      end

      task.wait(v1.Settings.SellInterval)
    end
  end)

  task.spawn(function()
    while v1.Running do
      if v1.Settings.AutoBatAura then
        pcall(function()
          local v44 = f6()

          if v44 then
            for index15, value39 in ipairs(players:GetPlayers()) do
              if value39 ~= localPlayer and value39.Character
                and value39.Character:FindFirstChild("HumanoidRootPart") then
                if (value39.Character.HumanoidRootPart.Position - v44.Position).Magnitude
                  <= v1.Settings.BatAuraRadius then
                  waitForChild14:FireServer()
                  break
                end
              end
            end
          end
        end)
      end

      task.wait(v1.Settings.BatAuraInterval)
    end
  end)

  local connect3 = userInputService.JumpRequest:Connect(function()
    if v1.Settings.InfiniteJump then
      local humanoid3 = f5():FindFirstChildOfClass("Humanoid")

      if humanoid3 then
        humanoid3:ChangeState(Enum.HumanoidStateType.Jumping)
      end
    end
  end)

  table.insert(v1.Connections, connect3)

  local connect4 = runService.Stepped:Connect(function()
    if v1.Settings.Noclip then
      local character = localPlayer.Character

      if character then
        for index16, value40 in ipairs(character:GetDescendants()) do
          if value40:IsA("BasePart") and value40.CanCollide then
            value40.CanCollide = false
          end
        end
      end
    end
  end)

  table.insert(v1.Connections, connect4)

  task.spawn(function()
    task.wait(1)
    local autoPath = configFolder .. "/autoload_setting.txt"
    if isfile and isfile(autoPath) then
      local name = readfile(autoPath)
      if name and name ~= "None" and name ~= "" then
        updateAutoloadLabel(name)
        local cfgPath = configFolder .. "/" .. name .. ".json"
        if isfile(cfgPath) then
          local raw = readfile(cfgPath)
          local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
          if ok and decoded then
            applySaveData(decoded)
          end
        end
      end
    end
  end)

  function v1:Unload()
    self.Running = false

    for index17, value41 in ipairs(self.Connections) do
      local v45 = value41
      pcall(function() v45:Disconnect() end)
    end

    table.clear(self.Connections)

    if self.Window and type(self.Window.Destroy) == "function" then
      pcall(function() self.Window:Destroy() end)
    end

    getgenv().JenicakesHub = nil
  end

  getgenv().JenicakesHub = v1
  return v1
end

f1()
