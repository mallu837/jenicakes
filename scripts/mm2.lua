-- [[ Murder Mystery 2 - Jenicakes Hub (Full WindUI Release) ]] --

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.GameId ~= 66654135 then
    game:GetService("Players").LocalPlayer:Kick("Jenicakes Hub: This script is for Murder Mystery 2 only.")
    return
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local Config = {
    Discord = "https://discord.gg/GFZYsspybS",
    ShootCooldown = 1.2,
    StabCooldown = 0.9,
    KillAuraRange = 18,
    GunGrabHold = 0.35,
    FarmSpeed = 25,
    FarmSpeedMax = 28,
    FarmMurdererRadius = 30,
    FarmArrive = 1.5,
    FarmBrake = 20,
    FarmIdleWait = 0.3,
    FarmSettle = 0.15,
    FarmSkipTime = 4,
    XRayTransparency = 0.6,
    DodgeRange = 22,
    DodgeCooldown = 2.5,
    FlingForce = 9e4,
    FlingTime = 2.5,
    SpeedDefault = 16,
    JumpDefault = 50,
    LobbyName = "RegularLobby",
    LockHoldTime = 0.4,
    Colors = {
        Murderer = Color3.fromHSV(0, 0.75, 1),
        Sheriff  = Color3.fromHSV(0.6, 0.7, 1),
        Hero     = Color3.fromHSV(0.14, 0.8, 1),
        Innocent = Color3.fromHSV(0.33, 0.6, 0.95),
        Gun      = Color3.fromHSV(0.12, 0.9, 1),
    }
}

-- State
local State = {
    Alive = true,
    Roles = {},
    LastRoleFetch = 0,
    LastShoot = 0,
    LastStab = 0,
    LastDodge = 0,
    ShootBusy = false,
    KillBusy = false,
    FarmBusy = false,
    FarmHome = nil,
    FarmMover = nil,
    Bag = { Current = 0, Max = 0 },
    SkippedCoins = {},
    XRayMap = nil,
    XRayParts = {},
    Esp = { Players = {}, Gun = nil, Folder = nil },
    LightingDefaults = nil,
    LockedTarget = nil,
    ButtonLocked = false,   -- true while finger is held down
    Opt = {
        AutoGrabGun    = false,
        AutoShoot      = false,
        SilentAim      = false,
        AutoKillAll    = false,
        KillAura       = false,
        KnifeAim       = false,
        AutoDodge      = false,
        Kaitun         = false,
        AutoFarm       = false,
        FarmSpeed      = 25,
        ResetWhenFull  = false,
        AntiFling      = false,
        XRay           = false,
        EspPlayers     = false,
        EspGun         = false,
        RoleNotify     = false,
        SpeedOn        = false,
        WalkSpeed      = 24,
        JumpOn         = false,
        JumpPower      = 70,
        InfJump        = false,
        Noclip         = false,
        Fullbright     = false,
        AntiAfk        = false,
        TrollTarget    = "",
        SkinSource     = "",
        StickTo        = false,
        MobileShootBtn = false,
    }
}

-- Remotes
local Remotes  = ReplicatedStorage:FindFirstChild("Remotes")
local Gameplay = Remotes and Remotes:FindFirstChild("Gameplay")
local Extras   = Remotes and Remotes:FindFirstChild("Extras")

local GameLib = {
    PlayerData    = Gameplay and Gameplay:FindFirstChild("GetCurrentPlayerData"),
    CoinCollected = Gameplay and Gameplay:FindFirstChild("CoinCollected"),
    CoinsStarted  = Gameplay and Gameplay:FindFirstChild("CoinsStarted"),
    RoundStart    = Gameplay and Gameplay:FindFirstChild("RoundStart"),
    RedeemCode    = Extras   and Extras:FindFirstChild("RedeemCode")
}

-- Helpers
local Util = {}

function Util.Root(player)
    local char = (player or LocalPlayer).Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Util.Humanoid(player)
    local char = (player or LocalPlayer).Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Util.Tool(player, name)
    local char    = player and player.Character
    local backpack = player and player:FindFirstChild("Backpack")
    return (char and char:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
end

function Util.IsDead(player)
    local hum = Util.Humanoid(player)
    return not hum or hum.Health <= 0
end

local function ApplyNoclip()
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

-- Round Mechanics
local Round = {}

function Round.RefreshRoles()
    if os.clock() - State.LastRoleFetch < 1.5 then return end
    State.LastRoleFetch = os.clock()
    if GameLib.PlayerData and GameLib.PlayerData:IsA("RemoteFunction") then
        pcall(function() State.Roles = GameLib.PlayerData:InvokeServer() end)
    end
end

function Round.RoleOf(player)
    if not player then return "Innocent" end
    local entry = State.Roles[player.Name]
    if entry and not entry.Dead and entry.Role then return entry.Role end
    if Util.Tool(player, "Knife") then return "Murderer" end
    if Util.Tool(player, "Gun")   then return "Sheriff"  end
    return "Innocent"
end

function Round.FindByRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Round.RoleOf(p) == role and Util.Root(p) then
            return p
        end
    end
    return nil
end

function Round.Map()
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name ~= Config.LobbyName and child:IsA("Model") and child:FindFirstChild("CoinContainer") then
            return child
        end
    end
    return nil
end

function Round.Lobby()
    local lobby = workspace:FindFirstChild(Config.LobbyName)
    if lobby then return lobby end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name:find("Lobby") then return child end
    end
    return nil
end

function Round.IAmPlaying()
    local entry = State.Roles[LocalPlayer.Name]
    local hum   = Util.Humanoid()
    return Round.Map() ~= nil and hum ~= nil and hum.Health > 0 and entry ~= nil and not entry.Dead
end

function Round.GunDrop()
    local map = Round.Map()
    return (map and map:FindFirstChild("GunDrop", true)) or workspace:FindFirstChild("GunDrop")
end

--------------------------------------------------------------------------------
-- Lock Shot Overlay UI (progress bar shown while holding)
--------------------------------------------------------------------------------
local LockShotUI = {}
do
    local SG = Instance.new("ScreenGui")
    SG.Name         = "JenicakesLockShot"
    SG.ResetOnSpawn = false
    SG.DisplayOrder = 20
    SG.Parent       = game:GetService("CoreGui")

    local Card = Instance.new("Frame", SG)
    Card.Size                   = UDim2.fromOffset(180, 52)
    Card.Position               = UDim2.new(0.5, -90, 0.65, 0)
    Card.BackgroundColor3       = Color3.fromRGB(10, 10, 18)
    Card.BackgroundTransparency = 0.35
    Card.BorderSizePixel        = 0
    Card.Visible                = false
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color       = Color3.fromRGB(255, 60, 80)
    CardStroke.Thickness   = 1.2
    CardStroke.Transparency = 0.2

    local LockIcon = Instance.new("TextLabel", Card)
    LockIcon.Size                   = UDim2.fromOffset(28, 28)
    LockIcon.Position               = UDim2.fromOffset(8, 12)
    LockIcon.BackgroundTransparency = 1
    LockIcon.Text                   = "🎯"
    LockIcon.Font                   = Enum.Font.GothamBold
    LockIcon.TextSize               = 20

    local TargetName = Instance.new("TextLabel", Card)
    TargetName.Size                   = UDim2.new(1, -44, 0, 18)
    TargetName.Position               = UDim2.fromOffset(40, 6)
    TargetName.BackgroundTransparency = 1
    TargetName.TextColor3             = Color3.fromRGB(255, 255, 255)
    TargetName.Font                   = Enum.Font.GothamBold
    TargetName.TextSize               = 11
    TargetName.TextXAlignment         = Enum.TextXAlignment.Left
    TargetName.TextTruncate           = Enum.TextTruncate.AtEnd

    local StatusLabel = Instance.new("TextLabel", Card)
    StatusLabel.Size                   = UDim2.new(1, -44, 0, 13)
    StatusLabel.Position               = UDim2.fromOffset(40, 24)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3             = Color3.fromRGB(255, 60, 80)
    StatusLabel.Font                   = Enum.Font.Gotham
    StatusLabel.TextSize               = 10
    StatusLabel.TextXAlignment         = Enum.TextXAlignment.Left

    local BarTrack = Instance.new("Frame", Card)
    BarTrack.Size             = UDim2.new(1, -44, 0, 4)
    BarTrack.Position         = UDim2.fromOffset(40, 40)
    BarTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    BarTrack.BorderSizePixel  = 0
    Instance.new("UICorner", BarTrack).CornerRadius = UDim.new(1, 0)

    local BarFill = Instance.new("Frame", BarTrack)
    BarFill.Size             = UDim2.fromScale(0, 1)
    BarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
    BarFill.BorderSizePixel  = 0
    Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

    local fillConn = nil

    function LockShotUI.StartLock(targetPlayer)
        if not targetPlayer then return end
        TargetName.Text  = targetPlayer.DisplayName
        StatusLabel.Text = "LOCKING..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 80)
        BarFill.Size     = UDim2.fromScale(0, 1)
        Card.Visible     = true

        local startTime = os.clock()
        if fillConn then fillConn:Disconnect() end
        fillConn = RunService.Heartbeat:Connect(function()
            local pct = math.clamp((os.clock() - startTime) / Config.LockHoldTime, 0, 1)
            BarFill.Size = UDim2.fromScale(pct, 1)
            if pct >= 1 then
                StatusLabel.Text       = "🔒 LOCKED"
                StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                State.LockedTarget     = targetPlayer
            else
                State.LockedTarget = nil
            end
        end)
    end

    function LockShotUI.StopLock()
        if fillConn then fillConn:Disconnect(); fillConn = nil end
        Card.Visible = false
        BarFill.Size = UDim2.fromScale(0, 1)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 80)
    end

    function LockShotUI.IsLocked()
        return State.LockedTarget ~= nil
    end
end

--------------------------------------------------------------------------------
-- Target Float UI (draggable, transparent, auto-hide on death)
--------------------------------------------------------------------------------
local TargetFloatUI = {}
do
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name         = "JenicakesTargetUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 10
    ScreenGui.Parent       = game:GetService("CoreGui")

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Size                   = UDim2.fromOffset(220, 58)
    MainFrame.Position               = UDim2.new(0.5, -110, 0.78, 0)
    MainFrame.BackgroundColor3       = Color3.fromRGB(18, 18, 26)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel        = 0
    MainFrame.Visible                = false
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    local Stroke = Instance.new("UIStroke", MainFrame)
    Stroke.Color        = Color3.fromRGB(255, 60, 80)
    Stroke.Thickness    = 1.5
    Stroke.Transparency = 0.2

    local AvatarImage = Instance.new("ImageLabel", MainFrame)
    AvatarImage.Size                   = UDim2.fromOffset(42, 42)
    AvatarImage.Position               = UDim2.fromOffset(8, 8)
    AvatarImage.BackgroundTransparency = 1
    AvatarImage.Image                  = ""
    Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(0, 5)

    local NameLabel = Instance.new("TextLabel", MainFrame)
    NameLabel.Size                   = UDim2.new(1, -60, 0, 16)
    NameLabel.Position               = UDim2.fromOffset(56, 7)
    NameLabel.BackgroundTransparency = 1
    NameLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
    NameLabel.Font                   = Enum.Font.GothamBold
    NameLabel.TextSize               = 11
    NameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    NameLabel.TextTruncate           = Enum.TextTruncate.AtEnd

    local RoleLabel = Instance.new("TextLabel", MainFrame)
    RoleLabel.Size                   = UDim2.new(1, -60, 0, 14)
    RoleLabel.Position               = UDim2.fromOffset(56, 24)
    RoleLabel.BackgroundTransparency = 1
    RoleLabel.TextColor3             = Color3.fromRGB(255, 60, 80)
    RoleLabel.Font                   = Enum.Font.GothamMedium
    RoleLabel.TextSize               = 10
    RoleLabel.TextXAlignment         = Enum.TextXAlignment.Left

    local InfoLabel = Instance.new("TextLabel", MainFrame)
    InfoLabel.Size                   = UDim2.new(1, -60, 0, 13)
    InfoLabel.Position               = UDim2.fromOffset(56, 39)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.TextColor3             = Color3.fromRGB(160, 160, 185)
    InfoLabel.Font                   = Enum.Font.Gotham
    InfoLabel.TextSize               = 9
    InfoLabel.TextXAlignment         = Enum.TextXAlignment.Left

    -- Drag — blocked while button is held
    local dragging, dragStart, frameStart = false, nil, nil

    MainFrame.InputBegan:Connect(function(input)
        if State.ButtonLocked then return end  -- locked while holding shoot
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging   = true
            dragStart  = input.Position
            frameStart = MainFrame.Position
        end
    end)

    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if State.ButtonLocked then dragging = false; return end
        if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            local vp    = workspace.CurrentCamera.ViewportSize
            local newX  = math.clamp(frameStart.X.Offset + delta.X, 0, vp.X - 220)
            local newY  = math.clamp(frameStart.Y.Offset + delta.Y, 0, vp.Y - 58)
            MainFrame.Position = UDim2.fromOffset(newX, newY)
        end
    end)

    -- Death watcher
    local deathConn = nil

    local function WatchTarget(player)
        if deathConn then deathConn:Disconnect(); deathConn = nil end
        if not player then return end
        local function hookHum()
            local hum = Util.Humanoid(player)
            if hum then
                deathConn = hum.Died:Connect(function()
                    TargetFloatUI.Hide()
                    State.LockedTarget = nil
                end)
            end
        end
        hookHum()
        player.CharacterAdded:Connect(function() task.wait(0.1); hookHum() end)
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                TargetFloatUI.Hide()
                State.LockedTarget = nil
            end)
        end
    end)

    function TargetFloatUI.Show(targetPlayer)
        if not targetPlayer then return end
        WatchTarget(targetPlayer)
        task.spawn(function()
            local ok, content, isReady = pcall(function()
                return Players:GetUserThumbnailAsync(
                    targetPlayer.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size150x150
                )
            end)
            AvatarImage.Image = (ok and isReady) and content or ""
        end)
        NameLabel.Text = targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
        RoleLabel.Text = "TARGET: " .. Round.RoleOf(targetPlayer):upper()
        local hum    = Util.Humanoid(targetPlayer)
        local myRoot = Util.Root()
        local tRoot  = Util.Root(targetPlayer)
        local dist   = (myRoot and tRoot) and math.floor((tRoot.Position - myRoot.Position).Magnitude) or 0
        local hp     = hum and math.floor(hum.Health) or 0
        InfoLabel.Text    = string.format("Dist: %dm  HP: %d", dist, hp)
        MainFrame.Visible = true
    end

    function TargetFloatUI.Hide()
        MainFrame.Visible = false
        if deathConn then deathConn:Disconnect(); deathConn = nil end
    end
end

-- Actions
local Actions = {}

function Actions.Equip(tool)
    local hum = Util.Humanoid()
    if hum and tool and tool.Parent ~= LocalPlayer.Character then
        hum:EquipTool(tool)
    end
end

function Actions.ShootMurderer()
    Round.RefreshRoles()
    local murderer = State.LockedTarget or Round.FindByRole("Murderer")
    local gun      = Util.Tool(LocalPlayer, "Gun")
    if not murderer or not gun then
        TargetFloatUI.Hide()
        return false, "Murderer or Gun missing"
    end
    TargetFloatUI.Show(murderer)
    local mRoot  = Util.Root(murderer)
    local myRoot = Util.Root()
    if mRoot and myRoot then
        Actions.Equip(gun)
        task.wait(0.1)
        local attachment = myRoot:FindFirstChild("GunRaycastAttachment")
        local origin     = attachment and attachment.WorldCFrame or myRoot.CFrame
        if gun:FindFirstChild("Shoot") then
            gun.Shoot:FireServer(origin, mRoot.CFrame)
            task.delay(1.5, function() TargetFloatUI.Hide() end)
            return true, murderer.Name
        end
    end
    TargetFloatUI.Hide()
    return false, "Shoot execution failed"
end

function Actions.GrabGun()
    local drop = Round.GunDrop()
    local root = Util.Root()
    if not drop or not root then return false end
    local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
    if part then
        local oldCFrame = root.CFrame
        root.CFrame = part.CFrame
        if firetouchinterest then
            firetouchinterest(root, part, 0)
            firetouchinterest(root, part, 1)
        end
        task.wait(Config.GunGrabHold)
        root.CFrame = oldCFrame
        return true
    end
    return false
end

function Actions.KillAll()
    local knife = Util.Tool(LocalPlayer, "Knife")
    if not knife then return 0 end
    Actions.Equip(knife)
    local events = knife:FindFirstChild("Events")
    if not events then return 0 end
    local kills = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Util.Root(p) and not Util.IsDead(p) then
            local vRoot  = Util.Root(p)
            local myRoot = Util.Root()
            if myRoot and vRoot then
                myRoot.CFrame = vRoot.CFrame * CFrame.new(0, 0, 2)
                events.KnifeStabbed:FireServer()
                events.HandleTouched:FireServer(vRoot)
                kills = kills + 1
                task.wait(0.1)
            end
        end
    end
    return kills
end

-- Hook Engine
if hookmetamethod and checkcaller and getnamecallmethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and method == "FireServer" then
            if State.Opt.SilentAim and self.Name == "Shoot" and self.Parent and self.Parent.Name == "Gun" then
                local m     = State.LockedTarget or Round.FindByRole("Murderer")
                local mRoot = m and Util.Root(m)
                if mRoot then
                    local args = {...}
                    return oldNamecall(self, args[1], mRoot.CFrame)
                end
            elseif State.Opt.KnifeAim and self.Name == "KnifeThrown" and self.Parent and self.Parent.Name == "Events" then
                local nearest, minDist
                local myRoot = Util.Root()
                if myRoot then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and not Util.IsDead(p) and Util.Root(p) then
                            local d = (Util.Root(p).Position - myRoot.Position).Magnitude
                            if not minDist or d < minDist then minDist = d; nearest = Util.Root(p) end
                        end
                    end
                end
                if nearest then
                    local args = {...}
                    return oldNamecall(self, args[1], nearest.Position)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- Farm Engine
local Farm = {}

function Farm.BagFull()
    return State.Bag.Max > 0 and State.Bag.Current >= State.Bag.Max
end

function Farm.CanRun()
    return State.Alive and State.Opt.AutoFarm and Round.IAmPlaying() and not Farm.BagFull()
end

function Farm.NearestCoin(map, origin)
    local murderer = Round.FindByRole("Murderer")
    local threat   = murderer and Util.Root(murderer)
    local best, bestDistance
    for _, coin in ipairs(map.CoinContainer:GetChildren()) do
        local visual    = coin:FindFirstChild("CoinVisual")
        local skippedAt = State.SkippedCoins[coin]
        local skipped   = skippedAt and os.clock() - skippedAt < Config.FarmSkipTime
        local dangerous = threat and (coin.Position - threat.Position).Magnitude < Config.FarmMurdererRadius
        if coin:IsA("BasePart") and visual and not visual:GetAttribute("Collected") and not skipped and not dangerous then
            local distance = (coin.Position - origin).Magnitude
            if not bestDistance or distance < bestDistance then
                best, bestDistance = coin, distance
            end
        end
    end
    return best
end

function Farm.AttachMover(root)
    local attachment = Instance.new("Attachment", root)
    local mover = Instance.new("LinearVelocity", root)
    mover.Attachment0    = attachment
    mover.MaxForce       = math.huge
    mover.RelativeTo     = Enum.ActuatorRelativeTo.World
    mover.VectorVelocity = Vector3.zero
    State.FarmMover = { Attachment = attachment, Velocity = mover }
    return mover
end

function Farm.DetachMover()
    if State.FarmMover then
        State.FarmMover.Velocity:Destroy()
        State.FarmMover.Attachment:Destroy()
        State.FarmMover = nil
    end
end

function Farm.GlideTo(position)
    local root  = Util.Root()
    local mover = State.FarmMover
    if not root or not mover or mover.Velocity.Parent ~= root then
        Farm.DetachMover()
        mover = root and { Velocity = Farm.AttachMover(root) }
    end
    while mover and Farm.CanRun() and root.Parent do
        ApplyNoclip()
        local delta = position - root.Position
        if delta.Magnitude <= Config.FarmArrive then break end
        mover.Velocity.VectorVelocity = delta.Unit * math.min(State.Opt.FarmSpeed, delta.Magnitude * Config.FarmBrake)
        RunService.Heartbeat:Wait()
    end
    if mover then mover.Velocity.VectorVelocity = Vector3.zero end
end

function Farm.Step()
    if State.FarmBusy or not Farm.CanRun() then return end
    State.FarmBusy = true
    task.spawn(function()
        local root = Util.Root()
        if root then Farm.AttachMover(root) end
        State.FarmHome = root and root.CFrame
        while Farm.CanRun() do
            local map, hrp = Round.Map(), Util.Root()
            local coin = map and hrp and Farm.NearestCoin(map, hrp.Position)
            if coin then
                Farm.GlideTo(coin.Position)
                task.wait(Config.FarmSettle)
                State.SkippedCoins[coin] = os.clock()
            else
                task.wait(Config.FarmIdleWait)
            end
        end
        Farm.DetachMover()
        State.FarmBusy = false
        if Util.Humanoid() and State.Opt.ResetWhenFull and Farm.BagFull() then
            Util.Humanoid().Health = 0
        end
    end)
end

-- ESP
local Esp = {}

function Esp.Init()
    State.Esp.Folder        = Instance.new("Folder")
    State.Esp.Folder.Name   = "JenicakesHub_ESP"
    State.Esp.Folder.Parent = game:GetService("CoreGui")
end

function Esp.MakeHighlight(adornee, color)
    local h = Instance.new("Highlight")
    h.FillColor = color; h.OutlineColor = color
    h.FillTransparency = 0.65
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = adornee; h.Parent = State.Esp.Folder
    return h
end

function Esp.MakeLabel(adornee, color)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(180, 36)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.AlwaysOnTop = true; gui.Adornee = adornee
    local label = Instance.new("TextLabel", gui)
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.4
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    gui.Parent = State.Esp.Folder
    return gui, label
end

function Esp.Refresh()
    if not State.Esp.Folder then Esp.Init() end
    local myRoot = Util.Root()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character; local root = Util.Root(p)
        local entry = State.Esp.Players[p]; local role = Round.RoleOf(p)
        local visible = State.Opt.EspPlayers and p ~= LocalPlayer and char and root and role ~= "Dead"
        if not visible then
            if entry then entry.Highlight:Destroy(); entry.Gui:Destroy(); State.Esp.Players[p] = nil end
        else
            if not entry or entry.Character ~= char then
                if entry then entry.Highlight:Destroy(); entry.Gui:Destroy() end
                local gui, label = Esp.MakeLabel(root, Color3.new(1,1,1))
                entry = { Character = char, Highlight = Esp.MakeHighlight(char, Color3.new(1,1,1)), Gui = gui, Label = label }
                State.Esp.Players[p] = entry
            end
            local color = Config.Colors[role] or Config.Colors.Innocent
            local distance = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
            entry.Highlight.FillColor = color; entry.Highlight.OutlineColor = color
            entry.Label.TextColor3 = color
            entry.Label.Text = string.format("%s [%s] %dm", p.DisplayName, role, distance)
        end
    end
    local drop = State.Opt.EspGun and Round.GunDrop()
    if drop then
        if not State.Esp.Gun or State.Esp.Gun.Adornee ~= drop then
            if State.Esp.Gun then State.Esp.Gun.Highlight:Destroy(); State.Esp.Gun.Gui:Destroy() end
            local gui, label = Esp.MakeLabel(drop, Config.Colors.Gun)
            label.Text = "GUN DROP"
            State.Esp.Gun = { Adornee = drop, Highlight = Esp.MakeHighlight(drop, Config.Colors.Gun), Gui = gui }
        end
    elseif State.Esp.Gun then
        State.Esp.Gun.Highlight:Destroy(); State.Esp.Gun.Gui:Destroy(); State.Esp.Gun = nil
    end
end

--------------------------------------------------------------------------------
-- Mobile Shoot Button
-- Tap  → instant shoot
-- Hold → position LOCKS (can't drag), progress bar fills, release fires locked
--------------------------------------------------------------------------------
local MobileShootGui = Instance.new("ScreenGui")
MobileShootGui.Name         = "JenicakesMobileShoot"
MobileShootGui.ResetOnSpawn = false
MobileShootGui.DisplayOrder = 15
MobileShootGui.Parent       = game:GetService("CoreGui")

local ShootButton = Instance.new("TextButton")
ShootButton.Size                   = UDim2.fromOffset(110, 44)
ShootButton.Position               = UDim2.new(1, -125, 1, -180)
ShootButton.BackgroundColor3       = Color3.fromRGB(210, 35, 50)
ShootButton.BackgroundTransparency = 0.2
ShootButton.TextColor3             = Color3.fromRGB(255, 255, 255)
ShootButton.Font                   = Enum.Font.GothamBold
ShootButton.TextSize               = 13
ShootButton.Text                   = "SHOOT"
ShootButton.AutoButtonColor        = false
ShootButton.Visible                = false
ShootButton.Parent                 = MobileShootGui

Instance.new("UICorner", ShootButton).CornerRadius = UDim.new(0, 8)

local SBStroke = Instance.new("UIStroke", ShootButton)
SBStroke.Color     = Color3.fromRGB(255, 80, 100)
SBStroke.Thickness = 2

-- saved position for when button is NOT locked
local savedPosition = ShootButton.Position

local function SetButtonState(state)
    if state == "locked" then
        TweenService:Create(ShootButton, TweenInfo.new(0.15), {
            BackgroundColor3       = Color3.fromRGB(80, 200, 120),
            BackgroundTransparency = 0.1,
        }):Play()
        SBStroke.Color   = Color3.fromRGB(80, 255, 130)
        ShootButton.Text = "🔒 LOCKED"
    elseif state == "hit" then
        ShootButton.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
        ShootButton.Text             = "✓ HIT"
    elseif state == "miss" then
        ShootButton.BackgroundColor3 = Color3.fromRGB(150, 30, 40)
        ShootButton.Text             = "✗ MISS"
    else -- idle
        TweenService:Create(ShootButton, TweenInfo.new(0.15), {
            BackgroundColor3       = Color3.fromRGB(210, 35, 50),
            BackgroundTransparency = 0.2,
        }):Play()
        SBStroke.Color   = Color3.fromRGB(255, 80, 100)
        ShootButton.Text = "SHOOT"
    end
end

-- Drag  (blocked when ButtonLocked = true)
local sbDragging, sbDragStart, sbFrameStart = false, nil, nil

ShootButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not State.ButtonLocked then
            sbDragging   = true
            sbDragStart  = input.Position
            sbFrameStart = ShootButton.Position
        end

        -- start hold timer regardless
        State.ButtonLocked = false
        holdStart          = os.clock()

        local murderer = Round.FindByRole("Murderer")
        if murderer then LockShotUI.StartLock(murderer) end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    -- drag only works when NOT locked
    if sbDragging and not State.ButtonLocked and
    (input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - sbDragStart
        local vp    = workspace.CurrentCamera.ViewportSize
        local newX  = math.clamp(sbFrameStart.X.Offset + delta.X, 0, vp.X - 110)
        local newY  = math.clamp(sbFrameStart.Y.Offset + delta.Y, 0, vp.Y - 44)
        ShootButton.Position = UDim2.fromOffset(newX, newY)
        savedPosition        = ShootButton.Position
    end
end)

-- Heartbeat: once hold threshold reached, lock position
local holdStart = nil

RunService.Heartbeat:Connect(function()
    if holdStart and not State.ButtonLocked then
        if os.clock() - holdStart >= Config.LockHoldTime then
            State.ButtonLocked = true
            sbDragging         = false          -- kill any ongoing drag
            SetButtonState("locked")
        end
    end
end)

ShootButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        local wasLocked = State.ButtonLocked
        sbDragging         = false
        State.ButtonLocked = false
        holdStart          = nil

        local wasLockAcquired = LockShotUI.IsLocked()
        LockShotUI.StopLock()

        if not State.ShootBusy then
            State.ShootBusy = true
            task.spawn(function()
                local gun = Util.Tool(LocalPlayer, "Gun")
                if not gun then Actions.GrabGun(); task.wait(0.4) end
                local ok, _ = Actions.ShootMurderer()
                SetButtonState(ok and "hit" or "miss")
                task.wait(0.8)
                SetButtonState("idle")
                State.LockedTarget = nil
                task.wait(Config.ShootCooldown)
                State.ShootBusy = false
            end)
        else
            SetButtonState("idle")
            State.LockedTarget = nil
        end
    end
end)

-- Visibility loop
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not State.Opt.MobileShootBtn then
                ShootButton.Visible = false
                return
            end
            local murderer = Round.FindByRole("Murderer")
            local hasGun   = Util.Tool(LocalPlayer, "Gun") ~= nil
            local gunDrop  = Round.GunDrop() ~= nil
            ShootButton.Visible = murderer ~= nil and (hasGun or gunDrop) and not Util.IsDead(LocalPlayer)
        end)
    end
end)

--------------------------------------------------------------------------------
-- WindUI
--------------------------------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Jenicakes", Icon = "sparkles", Author = "MM2",
    Folder = "JenicakesHub", Size = UDim2.fromOffset(580, 460),
    Transparent = true, Theme = "Dark",
    User = { Enabled = true, Anonymous = false,
        Callback = function()
            WindUI:Notify({ Title = "User Profile", Content = "Welcome to Jenicakes UI!", Duration = 3 })
        end }
})

-- TAB 1: Coin Farm
local FarmTab = Window:Tab({ Title = "Coin Farm", Icon = "coins" })
FarmTab:Section({ Title = "Auto Farming" })
FarmTab:Toggle({ Title = "Auto Farm Coins (Noclip Included)", Value = false, Callback = function(v) State.Opt.AutoFarm = v end })
FarmTab:Slider({ Title = "Farm Speed", Min = 16, Max = Config.FarmSpeedMax, Default = Config.FarmSpeed, Step = 1, Callback = function(v) State.Opt.FarmSpeed = v end })
FarmTab:Toggle({ Title = "Reset When Bag Full", Value = false, Callback = function(v) State.Opt.ResetWhenFull = v end })

-- TAB 2: Combat
local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
CombatTab:Section({ Title = "Sheriff Features" })
CombatTab:Toggle({ Title = "Silent Aim", Value = false, Callback = function(v) State.Opt.SilentAim = v end })
CombatTab:Toggle({ Title = "Auto Shoot Murderer", Value = false, Callback = function(v) State.Opt.AutoShoot = v end })
CombatTab:Button({ Title = "Shoot Murderer", Callback = function()
    local ok, msg = Actions.ShootMurderer()
    WindUI:Notify({ Title = "Combat", Content = ok and ("Shot " .. tostring(msg)) or tostring(msg), Duration = 3 })
end })
CombatTab:Toggle({ Title = "Auto Grab Gun", Value = false, Callback = function(v) State.Opt.AutoGrabGun = v end })
CombatTab:Button({ Title = "Grab Gun Now", Callback = function()
    local ok = Actions.GrabGun()
    WindUI:Notify({ Title = "Gun Grabber", Content = ok and "Gun grabbed!" or "No gun drop found", Duration = 3 })
end })
CombatTab:Section({ Title = "Mobile Button" })
CombatTab:Toggle({ Title = "Mobile Shoot Button (On/Off)", Value = false, Callback = function(v) State.Opt.MobileShootBtn = v end })
CombatTab:Section({ Title = "Murderer Features" })
CombatTab:Toggle({ Title = "Knife Throw Aim", Value = false, Callback = function(v) State.Opt.KnifeAim = v end })
CombatTab:Toggle({ Title = "Auto Kill All", Value = false, Callback = function(v) State.Opt.AutoKillAll = v end })
CombatTab:Button({ Title = "Kill All Now", Callback = function()
    task.spawn(function()
        local kills = Actions.KillAll()
        WindUI:Notify({ Title = "Kill All", Content = "Killed " .. tostring(kills) .. " players", Duration = 3 })
    end)
end })
CombatTab:Toggle({ Title = "Kill Aura", Value = false, Callback = function(v) State.Opt.KillAura = v end })
CombatTab:Section({ Title = "Auto Win & Dodge" })
CombatTab:Toggle({ Title = "Auto Win (Kaitun Mode)", Value = false, Callback = function(v)
    State.Opt.Kaitun = v; State.Opt.AutoKillAll = v; State.Opt.AutoShoot = v
    State.Opt.AutoGrabGun = v; State.Opt.AutoFarm = v
end })
CombatTab:Toggle({ Title = "Auto Dodge Murderer", Value = false, Callback = function(v) State.Opt.AutoDodge = v end })

-- TAB 3: Visuals
local VisualTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisualTab:Section({ Title = "ESP Options" })
VisualTab:Toggle({ Title = "Role ESP", Value = false, Callback = function(v) State.Opt.EspPlayers = v end })
VisualTab:Toggle({ Title = "Gun Drop ESP", Value = false, Callback = function(v) State.Opt.EspGun = v end })
VisualTab:Section({ Title = "World Visuals" })
VisualTab:Toggle({ Title = "Map X-Ray", Value = false, Callback = function(v)
    State.Opt.XRay = v
    if not v and State.XRayMap then
        for part, original in pairs(State.XRayParts) do
            if part.Parent then part.Transparency = original end
        end
        table.clear(State.XRayParts); State.XRayMap = nil
    end
end })
VisualTab:Toggle({ Title = "Fullbright", Value = false, Callback = function(v)
    State.Opt.Fullbright = v
    if v then
        State.LightingDefaults = { Ambient = Lighting.Ambient, Brightness = Lighting.Brightness }
        Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2
    elseif State.LightingDefaults then
        Lighting.Ambient = State.LightingDefaults.Ambient
        Lighting.Brightness = State.LightingDefaults.Brightness
    end
end })
VisualTab:Section({ Title = "Skins Stealer" })
VisualTab:Input({ Title = "Source Player Name", Placeholder = "Username or Display Name", Callback = function(v) State.Opt.SkinSource = v end })
VisualTab:Button({ Title = "Copy Knife Skin", Callback = function()
    local src = Players:FindFirstChild(State.Opt.SkinSource)
    local tool = src and Util.Tool(src, "Knife")
    local handle = tool and tool:FindFirstChild("Handle")
    local mesh = handle and handle:FindFirstChildWhichIsA("SpecialMesh")
    local myTool = Util.Tool(LocalPlayer, "Knife")
    local myHandle = myTool and myTool:FindFirstChild("Handle")
    local myMesh = myHandle and myHandle:FindFirstChildWhichIsA("SpecialMesh")
    if mesh and myMesh then
        myMesh.MeshId = mesh.MeshId; myMesh.TextureId = mesh.TextureId
        if mesh.Scale then myMesh.Scale = mesh.Scale end
        WindUI:Notify({ Title = "Skins", Content = "Knife skin copied!", Duration = 3 })
    else
        WindUI:Notify({ Title = "Skins Error", Content = "Target does not have a knife available.", Duration = 3 })
    end
end })
VisualTab:Button({ Title = "Copy Gun Skin", Callback = function()
    local src = Players:FindFirstChild(State.Opt.SkinSource)
    local tool = src and Util.Tool(src, "Gun")
    local handle = tool and tool:FindFirstChild("Handle")
    local mesh = handle and handle:FindFirstChildWhichIsA("SpecialMesh")
    local myTool = Util.Tool(LocalPlayer, "Gun")
    local myHandle = myTool and myTool:FindFirstChild("Handle")
    local myMesh = myHandle and myHandle:FindFirstChildWhichIsA("SpecialMesh")
    if mesh and myMesh then
        myMesh.MeshId = mesh.MeshId; myMesh.TextureId = mesh.TextureId
        if mesh.Scale then myMesh.Scale = mesh.Scale end
        WindUI:Notify({ Title = "Skins", Content = "Gun skin copied!", Duration = 3 })
    else
        WindUI:Notify({ Title = "Skins Error", Content = "Target or you do not have a Gun available.", Duration = 3 })
    end
end })

-- TAB 4: Teleport & Troll
local TeleportTab = Window:Tab({ Title = "Teleport & Troll", Icon = "user-x" })
TeleportTab:Section({ Title = "Teleports" })
TeleportTab:Button({ Title = "Teleport to Lobby", Callback = function()
    local l = Round.Lobby(); local r = Util.Root()
    if l and r then r.CFrame = l:GetPivot() + Vector3.new(0,3,0) end
end })
TeleportTab:Button({ Title = "Teleport to Map", Callback = function()
    local m = Round.Map(); local r = Util.Root()
    if m and r then r.CFrame = m:GetPivot() + Vector3.new(0,3,0) end
end })
TeleportTab:Button({ Title = "Teleport to Murderer", Callback = function()
    local m = Round.FindByRole("Murderer"); local mr = m and Util.Root(m); local r = Util.Root()
    if mr and r then r.CFrame = mr.CFrame end
end })
TeleportTab:Section({ Title = "Troll Actions" })
TeleportTab:Input({ Title = "Target Username", Placeholder = "Username", Callback = function(v) State.Opt.TrollTarget = v end })
TeleportTab:Button({ Title = "Fling Target Player", Callback = function()
    local target = Players:FindFirstChild(State.Opt.TrollTarget)
    local root = Util.Root(); local targetRoot = target and Util.Root(target)
    if root and targetRoot then
        local spin = Instance.new("BodyAngularVelocity")
        spin.MaxTorque = Vector3.one * math.huge
        spin.AngularVelocity = Vector3.new(0, Config.FlingForce, 0)
        spin.Parent = root
        local start = os.clock()
        while os.clock() - start < Config.FlingTime do root.CFrame = targetRoot.CFrame; RunService.Heartbeat:Wait() end
        spin:Destroy()
    end
end })
TeleportTab:Toggle({ Title = "Stick To Target Player", Value = false, Callback = function(v) State.Opt.StickTo = v end })
TeleportTab:Button({ Title = "Spectate Target Player", Callback = function()
    local target = Players:FindFirstChild(State.Opt.TrollTarget)
    local hum = target and Util.Humanoid(target)
    if hum then workspace.CurrentCamera.CameraSubject = hum end
end })
TeleportTab:Button({ Title = "Unspectate (Reset Camera)", Callback = function()
    local hum = Util.Humanoid()
    if hum then workspace.CurrentCamera.CameraSubject = hum end
end })

-- TAB 5: Player & Utility
local PlayerTab = Window:Tab({ Title = "Player & Utility", Icon = "settings" })
PlayerTab:Section({ Title = "Movement Settings" })
PlayerTab:Toggle({ Title = "Standalone Noclip", Value = false, Callback = function(v) State.Opt.Noclip = v end })
PlayerTab:Toggle({ Title = "Enable WalkSpeed", Value = false, Callback = function(v)
    State.Opt.SpeedOn = v
    if not v and Util.Humanoid() then Util.Humanoid().WalkSpeed = Config.SpeedDefault end
end })
PlayerTab:Slider({ Title = "WalkSpeed Value", Min = 16, Max = 120, Default = 24, Step = 1, Callback = function(v) State.Opt.WalkSpeed = v end })
PlayerTab:Toggle({ Title = "Infinite Jump", Value = false, Callback = function(v) State.Opt.InfJump = v end })
UserInputService.JumpRequest:Connect(function()
    if State.Opt.InfJump and Util.Humanoid() then Util.Humanoid():ChangeState(Enum.HumanoidStateType.Jumping) end
end)
PlayerTab:Section({ Title = "Utilities & Server" })
PlayerTab:Toggle({ Title = "Anti AFK", Value = false, Callback = function(v) State.Opt.AntiAfk = v end })
LocalPlayer.Idled:Connect(function()
    if State.Opt.AntiAfk then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
end)
PlayerTab:Button({ Title = "Rejoin Game", Callback = function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end })
PlayerTab:Button({ Title = "Copy Discord Link", Callback = function()
    if setclipboard then setclipboard(Config.Discord)
        WindUI:Notify({ Title = "Clipboard", Content = "Discord link copied!", Duration = 3 })
    end
end })

--------------------------------------------------------------------------------
-- Main Loop
--------------------------------------------------------------------------------
task.spawn(function()
    while task.wait(0.15) do
        pcall(function()
            Round.RefreshRoles(); Farm.Step(); Esp.Refresh()
            if State.Opt.Noclip then ApplyNoclip() end
            if State.Opt.SpeedOn and Util.Humanoid() then Util.Humanoid().WalkSpeed = State.Opt.WalkSpeed end
            if State.Opt.StickTo and State.Opt.TrollTarget ~= "" then
                local t = Players:FindFirstChild(State.Opt.TrollTarget)
                local tr = t and Util.Root(t); local r = Util.Root()
                if tr and r then r.CFrame = tr.CFrame * CFrame.new(0,0,2) end
            end
            if State.Opt.AutoDodge and not Util.Tool(LocalPlayer, "Knife") then
                local m = Round.FindByRole("Murderer"); local mr = m and Util.Root(m); local r = Util.Root()
                if mr and r and (mr.Position - r.Position).Magnitude <= Config.DodgeRange
                and os.clock() - State.LastDodge > Config.DodgeCooldown then
                    State.LastDodge = os.clock(); r.CFrame = r.CFrame * CFrame.new(0,0,-25)
                end
            end
            if State.Opt.AutoShoot and Util.Tool(LocalPlayer, "Gun") and not State.ShootBusy then
                State.ShootBusy = true; Actions.ShootMurderer(); task.wait(Config.ShootCooldown); State.ShootBusy = false
            end
            if State.Opt.AutoGrabGun and Round.RoleOf(LocalPlayer) ~= "Murderer" and Round.GunDrop() then
                Actions.GrabGun()
            end
            if State.Opt.KillAura and Util.Tool(LocalPlayer, "Knife") then
                local knife = Util.Tool(LocalPlayer, "Knife"); local root = Util.Root()
                local events = knife and knife:FindFirstChild("Events")
                if events and root then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and not Util.IsDead(p) then
                            local vRoot = Util.Root(p)
                            if vRoot and (vRoot.Position - root.Position).Magnitude <= Config.KillAuraRange then
                                Actions.Equip(knife); events.KnifeStabbed:FireServer(); events.HandleTouched:FireServer(vRoot); break
                            end
                        end
                    end
                end
            end
            if State.Opt.XRay then
                local map = Round.Map() or Round.Lobby()
                if map and State.XRayMap ~= map then
                    State.XRayMap = map
                    for _, part in ipairs(map:GetDescendants()) do
                        if part:IsA("BasePart") then
                            State.XRayParts[part] = part.Transparency
                            part.Transparency = math.max(part.Transparency, Config.XRayTransparency)
                        end
                    end
                end
            end
        end)
    end
end)

WindUI:Notify({
    Title   = "Jenicakes Hub",
    Content = "Tap to shoot. Hold to lock position and fire on release.",
    Duration = 5
})
