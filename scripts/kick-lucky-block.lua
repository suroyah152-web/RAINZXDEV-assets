--[[
    RAINZXDEV Hub · Kick a Lucky Block
    Release v4.6.4
    Place: 89469502395769
]]

local compiler = loadstring or load
if type(compiler) ~= "function" then
    return
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")


local ENV = (getgenv and getgenv()) or _G
if ENV.__rainzxdev_KALB_CLEANUP then
    pcall(ENV.__rainzxdev_KALB_CLEANUP)
end

local okUI, uiSource = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/suroyah152-web/RAINZXDEV-assets/main/ui/PuckUI.lua")
end)
if not okUI or type(uiSource) ~= "string" or #uiSource < 100 then
    return
end

local uiChunk = compiler(uiSource)
if not uiChunk then
    return
end

local okPuck, PuckUI = pcall(uiChunk)
if not okPuck or type(PuckUI) ~= "table" or type(PuckUI.CreateWindow) ~= "function" then
    return
end

local Config = {
    Master = true,
    AutoTutorial = true,
    AutoKick = true,
    PerfectKick = true,
    TurboCollect = true,
    TravelMode = "Walk", -- Walk / Teleport (Safe) / Manual
    KickDelay = 0.40,

    -- Fast Rarity = shortest practical distance inside the highest unlocked
    -- rarity. Balanced Rarity = deeper into that same zone. Max Distance = old
    -- 100% power behaviour.
    FarmKickMode = "Max Distance",
    FarmRarityBuffer = 12,

    AutoOpenLuckyBlocks = true,
    LuckyBlockEveryKicks = 3,

    AutoPlaceBest = true,
    AutoDismissLowRewards = false, -- legacy route disabled; collect then Auto Sell
    ReplaceWeak = true,
    ReplaceThreshold = 1.0, -- replace on any genuine improvement
    AutoCollectCash = true,
    CashCollectInterval = 3.0,

    AutoUpgradeBrainrots = true,
    BrainrotUpgradeSpendFraction = 0.85,
    BrainrotUpgradeMaxPerPass = 18,
    BrainrotUpgradeKeepFraction = 1.00, -- every placed CPS brainrot eligible; lowest levels first

    AutoSellLeftovers = true,
    SellMode = "Sell All UI",
    SellUseNativeSellerTeleport = true,
    SellMaxPerVisit = 20, -- fallback individual mode only
    SellAllButtonTimeout = 1.75,
    SellAllConfirmTimeout = 1.75,

    AutoBuyWeights = true,
    AutoTrain = true,

    AdaptiveTraining = true,

    SmartTrainingCadence = true,
    TrainingBurstEveryKicks = 2,
    TrainingBurstSeconds = 2.5,
    NextRaritySprintMaxSeconds = 7.0,

    AdaptiveDistanceGain = 12,
    AdaptivePlateauThreshold = 4,
    AdaptiveMinTrainSeconds = 3.0,
    AdaptiveMaxTrainSeconds = 8.0,

    -- Fixed fallback only when Adaptive Distance Training is disabled.
    TrainBetweenKicks = 4.0,

    AutoBuySpeed = true,
    SpeedSpendFraction = 0.40,
    AutoRebirth = true,

    -- Automatic rewards / progression
    AutoClaimFreeItem = true,
    AutoClaimOffline = true,
    AutoWheelSpins = true,
    AutoKickBonuses = true,
    AutoKickStyles = true,
    KickStyleMode = "Throughput",
    AutoBaseSlots = true,
    AutoBattlePassClaims = true,
    AutoMailboxRewards = true,
    AutoGroupGift = false,

    -- Event systems
    AutoGymTime = true,
    GymTimeStayUntilEnd = true,
    GymEventTravelMode = "Teleport (Safe)",
    GymEventMissingGrace = 1.50,

    -- Optional/destructive event systems
    AutoSchoolCraft = false,
    AutoSchoolMath = false,
    AutoMightyChest = false,
}

local Runtime = {
    Alive = true,
    Busy = false,
    State = "Starting",
    Connections = {},
    LastCashCollect = 0,
    LastUpgrade = 0,
    LastPlacement = 0,
    LastWeightAction = 0,
    LastSpeedAction = 0,
    LastLuckyOpen = 0,
    LastRebirth = 0,
    KickPower = nil,
    KickMastery = nil,
    EquippedStyle = "Default",
    OwnedStyles = {},
    LastStyleAction = 0,
    SpeedLevel = nil,
    RebirthLevel = nil,
    EquippedWeight = nil,
    OwnedWeights = {},
    RoundActive = false,
    SawKickPhase2 = false,
    LastKickEndedAt = 0,
    LastKickAttemptAt = 0,
    LastKickButtonReturnAt = 0,
    PendingRewardPlacement = false,
    RewardRoundEndedAt = 0,
    LastRewardNames = nil,
    KickOriginPosition = nil,
    KickOriginCFrame = nil,
    KickOriginCapturedAt = 0,
    RewardLandingPosition = nil,
    RewardReturnStartedAt = 0,

    KickToolSnapshot = {},
    LastCollectedAt = 0,
    LastCollectedPayload = nil,
    LastKickSucceeded = nil,
    PostKickPhase = "Idle",

    PreviousKickDistance = nil,
    LastKickDistance = nil,
    BestKickDistance = 0,
    LastDistanceGain = nil,
    ConsecutiveDistancePlateaus = 0,
    DistanceCapturedThisKick = false,
    LastKickPowerAtLaunch = nil,
    LastAdaptiveTrainTarget = nil,
    LastAdaptiveTrainStartPower = nil,
    LastAdaptiveTrainEndPower = nil,
    NeedsImmediateTraining = false,
    LastTrainingCompletedAt = 0,
    LastBonusUiScan = 0,
    TrainingBonusClicks = 0,

    TargetKickPercent = 1,
    TargetKickDistance = nil,
    TargetKickRarity = nil,
    MaxPowerDistance = nil,
    LastKickPowerUiSetAt = 0,

    CompletedKickCycles = 0,
    KicksSinceTraining = 0,
    LastTrainingDuration = 0,
    ObservedTrainingRate = nil,
    DismissCurrentReward = false,
    LastLuckyBlockCycle = -999,
    CycleStartedAt = 0,

    LastSellAt = 0,
    SoldBrainrots = 0,
    LastSellCount = 0,
    LastSellValue = nil,
    LastMailboxClaimAt = 0,
    SmartUpgradeConfirmed = 0,
    SmartUpgradeFailed = 0,

    InTraining = false,
    LastSellReason = nil,
    LastSellDistance = nil,
    LastSellerPromptAt = 0,
    SellFailures = 0,
    LastSellAllStage = nil,

    GymEventPriority = false,
    GymEventActive = false,
    GymEventLastSeenAt = 0,
    GymEventStartedAt = 0,
    GymEventTimerSeconds = nil,
    GymMachineAnchor = nil,
    GymMachinePrompt = nil,
    GymMachineSeat = nil,
    GymMachineName = nil,
    GymMachineLastEnter = 0,
    GymTrainingStartPower = nil,
    GymTrainingGained = 0,
    GymTrainingRate = nil,

    -- Expanded progression / rewards
    AddedSlots = 0,
    WheelSpins = nil,
    WheelBusyUntil = 0,
    LastWheelRequest = 0,
    FreeItemClaimed = nil,
    FreeItemCheckedAt = 0,
    OfflineClaimAttempted = false,
    GroupGiftAttempted = false,
    BattlePassState = nil,
    LastBattlePassClaim = 0,
    SchoolScore = 0,
    LastSchoolCraft = 0,
    LastBaseUpgrade = 0,
    LastBonusClaim = 0,
    ExtraState = "Rewards ready",
    MightyChestPending = false,
}

local function setState(text)
    Runtime.State = tostring(text or "Idle")
end

local function character()
    return LocalPlayer.Character
end

local function humanoid()
    local char = character()
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function rootPart()
    local char = character()
    return char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")) or nil
end

local function isAlive()
    local hum = humanoid()
    return hum ~= nil and hum.Health > 0 and rootPart() ~= nil
end

local function waitAlive(timeout)
    local deadline = os.clock() + (timeout or 10)
    while Runtime.Alive and os.clock() < deadline do
        if isAlive() then
            return true
        end
        task.wait(0.1)
    end
    return isAlive()
end


local PlayerControls = {
    Object = nil,
    DisabledByUs = false,
    LastAttemptAt = 0,
}

local function getPlayerControls(force)
    if PlayerControls.Object then
        return PlayerControls.Object
    end

    if not force and os.clock() - PlayerControls.LastAttemptAt < 1 then
        return nil
    end
    PlayerControls.LastAttemptAt = os.clock()

    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        or LocalPlayer:WaitForChild("PlayerScripts", 5)
    local playerModule = playerScripts
        and (playerScripts:FindFirstChild("PlayerModule")
            or playerScripts:WaitForChild("PlayerModule", 5))

    if not playerModule or not playerModule:IsA("ModuleScript") then
        return nil
    end

    -- This is Roblox's stock PlayerModule. The inspected game's AutoController
    -- requires this exact module and uses GetControls():Disable()/Enable().
    local okModule, module = pcall(require, playerModule)
    if not okModule or module == nil then
        return nil
    end

    local getControls = nil
    pcall(function()
        getControls = module.GetControls
    end)

    if type(getControls) ~= "function" then
        return nil
    end

    local okControls, controls = pcall(function()
        return module:GetControls()
    end)

    if not okControls or controls == nil then
        return nil
    end

    local disableFn, enableFn
    pcall(function()
        disableFn = controls.Disable
        enableFn = controls.Enable
    end)

    if type(disableFn) ~= "function" or type(enableFn) ~= "function" then
        return nil
    end

    PlayerControls.Object = controls
    return controls
end

local function disablePlayerControls()
    local controls = getPlayerControls()
    if not controls then
        return false
    end

    if PlayerControls.DisabledByUs then
        return true
    end

    local ok = pcall(function()
        controls:Disable()
    end)

    if ok then
        PlayerControls.DisabledByUs = true
    end
    return ok
end

local function enablePlayerControls()
    local controls = PlayerControls.Object or getPlayerControls()
    if not controls then
        PlayerControls.DisabledByUs = false
        return false
    end

    if not PlayerControls.DisabledByUs then
        return true
    end

    local ok = pcall(function()
        controls:Enable()
    end)

    PlayerControls.DisabledByUs = false
    return ok
end

local function stopAutomatedWalk()
    local hum = humanoid()
    local root = rootPart()

    if hum and root then
        pcall(function()
            hum:MoveTo(root.Position)
        end)
    end

    enablePlayerControls()
end

local function nudgeJump(reason)
    local hum = humanoid()
    local root = rootPart()
    if not hum or not root or hum.Health <= 0 or root.Anchored then
        return false
    end

    local ok = pcall(function()
        hum.Sit = false
        hum.PlatformStand = false
        hum.Jump = true
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end)

    if ok and reason then
        setState(reason)
    end

    return ok
end

local function hasTag(instance, tag)
    if not instance then
        return false
    end
    local ok, result = pcall(function()
        return instance:HasTag(tag)
    end)
    if ok then
        return result == true
    end
    return CollectionService:HasTag(instance, tag)
end

-- ============================================================================
-- Runtime-safe direct network access
-- The game's Network package stores remotes as children named rev_* / ref_*.
-- No game ModuleScript is required here.
-- ============================================================================

local function waitPath(root, path, timeout)
    local node = root
    local deadline = os.clock() + (timeout or 10)
    for segment in string.gmatch(path, "[^/]+") do
        local remaining = math.max(0.05, deadline - os.clock())
        node = node:FindFirstChild(segment) or node:WaitForChild(segment, remaining)
        if not node then
            return nil
        end
    end
    return node
end

local NetworkRoot = waitPath(ReplicatedStorage, "Shared/Packages/Network", 20)

local function remoteEvent(name)
    if not NetworkRoot then
        return nil
    end
    local remote = NetworkRoot:FindFirstChild("rev_" .. tostring(name))
    if remote and remote:IsA("RemoteEvent") then
        return remote
    end
    return nil
end

local function remoteFunction(name)
    if not NetworkRoot then
        return nil
    end
    local remote = NetworkRoot:FindFirstChild("ref_" .. tostring(name))
    if remote and remote:IsA("RemoteFunction") then
        return remote
    end
    return nil
end

local function fireServer(name, ...)
    local remote = remoteEvent(name)
    if not remote then
        return false
    end
    local args = table.pack(...)
    return pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
end

local function invokeServer(name, ...)
    local remote = remoteFunction(name)
    if not remote then
        return false, nil
    end
    local args = table.pack(...)
    local ok, a, b, c, d = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
    if not ok then
        return false, nil
    end
    return true, a, b, c, d
end

local function connectRemote(name, callback)
    local remote = remoteEvent(name)
    if not remote then
        return
    end
    local connection = remote.OnClientEvent:Connect(callback)
    table.insert(Runtime.Connections, connection)
end

-- ============================================================================
-- Static data copied from the inspected client data modules.
-- This avoids requiring the broken decompiled Data modules at runtime.
-- ============================================================================

local WeightData = {
    {Name="Wooden Stick", PPS=2, Cost=0},
    {Name="Bone Barbell", PPS=5, Cost=7500},
    {Name="Stone Block", PPS=10, Cost=75000},
    {Name="Copper Plate", PPS=50, Cost=500000},
    {Name="Iron Plate", PPS=150, Cost=7250000},
    {Name="Ice Barbell", PPS=400, Cost=250000000},
    {Name="Donut Barbell", PPS=1000, Cost=5000000000},
    {Name="Golden Barbell", PPS=2500, Cost=85000000000},
    {Name="Heaven Plate", PPS=6250, Cost=1200000000000},
    {Name="Mega Golden Barbell", PPS=15000, Cost=18000000000000},
    {Name="Neon Pulse", PPS=50000, Cost=500000000000000},
    {Name="Giant Gold Star Barbell", PPS=100000, Cost=1e16},
    {Name="Emerald Barbell", PPS=400000, Cost=1e18},
    {Name="Planet Barbell", PPS=2000000, Cost=5e20},
    {Name="Big Jupiter", PPS=5000000, Cost=1e23},
    {Name="Black Hole Barbell", PPS=30000000, Cost=5e25},
}

local WeightByName = {}
for _, data in ipairs(WeightData) do
    WeightByName[data.Name] = data
end

-- Exact power -> distance curve from ReplicatedStorage.Shared.Data.KickData.
local KICK_MAX_DISTANCE = 8000

local function kickDistanceFromPower(power)
    power = math.max(0, tonumber(power) or 0)

    if power <= 0 then
        return 0
    end

    local exponent

    if power <= 80000000 then
        exponent = 0.215
    elseif power <= 3831966715 then
        exponent = ((80000000 / power) ^ 0.03) * 0.215
    else
        exponent = ((3831966715 / power) ^ (-0.007059))
            * 0.19143815835186814
    end

    local distance = 60 * (power ^ exponent)

    if distance ~= distance or distance == math.huge then
        return KICK_MAX_DISTANCE
    end

    return math.clamp(distance, 0, KICK_MAX_DISTANCE)
end

local function kickPowerForDistance(distance, minimumPower)
    distance = math.clamp(tonumber(distance) or 0, 0, KICK_MAX_DISTANCE)

    if distance <= 0 then
        return 0
    end

    local low = math.max(0, tonumber(minimumPower) or 0)
    local high = math.max(1, low)

    if kickDistanceFromPower(high) < distance then
        local guard = 0

        while kickDistanceFromPower(high) < distance and guard < 128 do
            high = high * 2
            guard = guard + 1

            if high > 1e300 then
                break
            end
        end
    else
        low = 0
    end

    for _ = 1, 70 do
        local mid = (low + high) * 0.5

        if kickDistanceFromPower(mid) < distance then
            low = mid
        else
            high = mid
        end
    end

    return (low + high) * 0.5
end

-- Exact distance boundaries from Shared.Data.RarityData.
local RarityZones = {
    {Name="Common", Distance=0},
    {Name="Rare", Distance=131},
    {Name="Epic", Distance=301},
    {Name="Legendary", Distance=541},
    {Name="Mythic", Distance=816},
    {Name="Godly", Distance=1136},
    {Name="Secret", Distance=1483},
    {Name="Rainbow", Distance=1862},
    {Name="Hacked", Distance=2297},
    {Name="Demon", Distance=2777},
    {Name="Celestial", Distance=3230},
    {Name="Eternal", Distance=3907},
    {Name="Eternal+", Distance=4926},
    {Name="Abyssal", Distance=6000},
    {Name="Abyssal+", Distance=7073},
}

local function rarityIndexForDistance(distance)
    distance = math.max(0, tonumber(distance) or 0)
    local index = 1

    for i, zone in ipairs(RarityZones) do
        if distance >= zone.Distance then
            index = i
        else
            break
        end
    end

    return index
end

local function fastFarmKickTarget(power)
    power = math.max(0, tonumber(power) or 0)

    if power <= 0 then
        return 1, 0, "Common", 0
    end

    local maxDistance = kickDistanceFromPower(power)
    local zoneIndex = rarityIndexForDistance(maxDistance)
    local zone = RarityZones[zoneIndex]
    local mode = tostring(Config.FarmKickMode or "Max Distance")

    if mode == "Max Distance" then
        return 1, maxDistance, zone.Name, maxDistance
    end

    local nextZone = RarityZones[zoneIndex + 1]
    local zoneMax = nextZone and (nextZone.Distance - 1) or KICK_MAX_DISTANCE
    zoneMax = math.min(zoneMax, maxDistance)

    local targetDistance

    if mode == "Balanced Rarity" then
        local width = math.max(0, zoneMax - zone.Distance)
        targetDistance = zone.Distance + width * 0.40
    else
        -- Rarity is determined only by the distance threshold, so farming near
        -- the start of the zone gives the same rarity with a much shorter flight
        -- and RUN-back path. Keep a small buffer above the threshold.
        targetDistance = math.max(
            30,
            zone.Distance + math.max(5, tonumber(Config.FarmRarityBuffer) or 12)
        )
    end

    targetDistance = math.min(targetDistance, maxDistance)

    local neededPower = kickPowerForDistance(targetDistance, 0)
    local percent = math.clamp(neededPower / power, 0.05, 1)

    return percent, targetDistance, zone.Name, maxDistance
end

local MutationBuffs = {
    Golden=1.5, Diamond=2, Plasma=4, Molten=6, Radioactive=8,
    Shadow=12, Electrified=16, Rainbow=40, Astral=50, Infinity=75,
    Void=12, Virus=14, Wet=16, Alien=22, Bacon=30, Enchanted=12,
    Phantom=35, Volcanic=35, Heavenly=36, Carnival=37,
    ["Block Cup"]=38, Undead=35, Jungle=40, Frozen=40,
}

local BrainrotData = {
    ["Noobini Pizzanini"] = {CPS=2, Rarity="Common", Upgradeable=true},
    ["Lirili Larila"] = {CPS=3, Rarity="Common", Upgradeable=true},
    ["Tim Cheese"] = {CPS=3, Rarity="Common", Upgradeable=true},
    ["Talpa Di Fero"] = {CPS=4, Rarity="Common", Upgradeable=true},
    ["Svinina Bombardino"] = {CPS=5, Rarity="Common", Upgradeable=true},
    ["Pipi Kiwi"] = {CPS=6, Rarity="Common", Upgradeable=true},
    ["Fruli Frula"] = {CPS=7, Rarity="Common", Upgradeable=true},
    ["Trippi Troppi"] = {CPS=7, Rarity="Common", Upgradeable=true},
    ["Gangster Footera"] = {CPS=15, Rarity="Rare", Upgradeable=true},
    ["Bobrito Bandito"] = {CPS=17, Rarity="Rare", Upgradeable=true},
    ["Boneca Ambalabu"] = {CPS=17, Rarity="Rare", Upgradeable=true},
    ["Ta Ta Ta Ta Sahur"] = {CPS=18, Rarity="Rare", Upgradeable=true},
    ["Ballerina Cappuccina"] = {CPS=19, Rarity="Rare", Upgradeable=true},
    ["Cappuccino Assassino"] = {CPS=22, Rarity="Rare", Upgradeable=true},
    ["Brr Brr Patapim"] = {CPS=22, Rarity="Rare", Upgradeable=true},
    ["Cacto Hipopotamo"] = {CPS=26, Rarity="Rare", Upgradeable=true},
    ["Garamararam"] = {CPS=40, Rarity="Epic", Upgradeable=true},
    ["Madung"] = {CPS=44, Rarity="Epic", Upgradeable=true},
    ["Waterdino"] = {CPS=50, Rarity="Epic", Upgradeable=true},
    ["Pesto Mortioni"] = {CPS=52, Rarity="Epic", Upgradeable=true},
    ["Pannaburro"] = {CPS=62, Rarity="Epic", Upgradeable=true},
    ["Orcalero"] = {CPS=64, Rarity="Epic", Upgradeable=true},
    ["Mangolini Parrocini"] = {CPS=64, Rarity="Epic", Upgradeable=true},
    ["John Pork"] = {CPS=72, Rarity="Epic", Upgradeable=true},
    ["Gattatino Nyanino"] = {CPS=76, Rarity="Epic", Upgradeable=true},
    ["Chimpanzini Bananini"] = {CPS=100, Rarity="Legendary", Upgradeable=true},
    ["Plan Red"] = {CPS=130, Rarity="Legendary", Upgradeable=true},
    ["Plan Blue"] = {CPS=140, Rarity="Legendary", Upgradeable=true},
    ["Capi Taco"] = {CPS=150, Rarity="Legendary", Upgradeable=true},
    ["Trulimero Trulicina"] = {CPS=160, Rarity="Legendary", Upgradeable=true},
    ["Bambini Crostini"] = {CPS=160, Rarity="Legendary", Upgradeable=true},
    ["Elefantucci Bananucci"] = {CPS=170, Rarity="Legendary", Upgradeable=true},
    ["Bananita Dolphinita"] = {CPS=235, Rarity="Legendary", Upgradeable=true},
    ["Salamino Pinguino"] = {CPS=280, Rarity="Legendary", Upgradeable=true},
    ["Penguino Cocosino"] = {CPS=450, Rarity="Mythic", Upgradeable=true},
    ["67"] = {CPS=500, Rarity="Mythic", Upgradeable=true},
    ["Burbaloni Luliloli"] = {CPS=550, Rarity="Mythic", Upgradeable=true},
    ["Chef Crabracadabra"] = {CPS=600, Rarity="Mythic", Upgradeable=true},
    ["Capybara Eggplant"] = {CPS=650, Rarity="Mythic", Upgradeable=true},
    ["Bangello"] = {CPS=725, Rarity="Mythic", Upgradeable=true},
    ["Elefanto Frigo"] = {CPS=775, Rarity="Mythic", Upgradeable=true},
    ["Rinooccio Verdini"] = {CPS=880, Rarity="Mythic", Upgradeable=true},
    ["Glorbo Fruttodrillo"] = {CPS=950, Rarity="Mythic", Upgradeable=true},
    ["Udin Din Din Dun"] = {CPS=1850, Rarity="Godly", Upgradeable=true},
    ["Pandaccini Bananini"] = {CPS=2000, Rarity="Godly", Upgradeable=true},
    ["Octopusini Bluberini"] = {CPS=2150, Rarity="Godly", Upgradeable=true},
    ["Strawberelli Flamingelli"] = {CPS=2300, Rarity="Godly", Upgradeable=true},
    ["Sigma Boy"] = {CPS=2450, Rarity="Godly", Upgradeable=true},
    ["Frigo Camelo"] = {CPS=2600, Rarity="Godly", Upgradeable=true},
    ["Orangutini Ananasini"] = {CPS=2700, Rarity="Godly", Upgradeable=true},
    ["Rhino Toasterino"] = {CPS=2950, Rarity="Godly", Upgradeable=true},
    ["Bombardiro Crocodilo"] = {CPS=3100, Rarity="Godly", Upgradeable=true},
    ["Bombini Gusini"] = {CPS=4750, Rarity="Secret", Upgradeable=true},
    ["Castlino Fortini"] = {CPS=5000, Rarity="Exclusive", Upgradeable=true},
    ["Tuff Toucan"] = {CPS=5300, Rarity="Secret", Upgradeable=true},
    ["Fryuro"] = {CPS=5850, Rarity="Secret", Upgradeable=true},
    ["Burguro"] = {CPS=6250, Rarity="Secret", Upgradeable=true},
    ["Guest666"] = {CPS=7000, Rarity="Secret", Upgradeable=true},
    ["Zibra Zubra Zibralini"] = {CPS=7750, Rarity="Secret", Upgradeable=true},
    ["Cavallo Virtuso"] = {CPS=10000, Rarity="Secret", Upgradeable=true},
    ["Gorillo Watermelondrillo"] = {CPS=12000, Rarity="Secret", Upgradeable=true},
    ["Cocofanto Elefanto"] = {CPS=14000, Rarity="Secret", Upgradeable=true},
    ["Bambu Sahur"] = {CPS=12500, Rarity="Exclusive", Upgradeable=true},
    ["W or L"] = {CPS=15000, Rarity="Exclusive", Upgradeable=true},
    ["Girafa Celeste"] = {CPS=16500, Rarity="Divine", Upgradeable=true},
    ["Tralalero Tralala"] = {CPS=17500, Rarity="Divine", Upgradeable=true},
    ["Tralalerita Tralala"] = {CPS=18000, Rarity="Divine", Upgradeable=true},
    ["Peant Jarro"] = {CPS=19500, Rarity="Divine", Upgradeable=true},
    ["Dipperi Chiperini"] = {CPS=20000, Rarity="Divine", Upgradeable=true},
    ["Rexosaurus"] = {CPS=22500, Rarity="Divine", Upgradeable=true},
    ["1x1x1x1"] = {CPS=25000, Rarity="Divine", Upgradeable=true},
    ["Matteo"] = {CPS=30000, Rarity="Divine", Upgradeable=true},
    ["Espresso Signora"] = {CPS=36500, Rarity="Divine", Upgradeable=true},
    ["Alessio"] = {CPS=27500, Rarity="Hacked", Upgradeable=true},
    ["Tripi Tropi Tropa Tripa"] = {CPS=28000, Rarity="Hacked", Upgradeable=true},
    ["SWAG SODA"] = {CPS=29000, Rarity="Hacked", Upgradeable=true},
    ["Stoppo Luminino"] = {CPS=30000, Rarity="Hacked", Upgradeable=true},
    ["Torrtuginni Dragonfrutini"] = {CPS=32000, Rarity="Hacked", Upgradeable=true},
    ["Tictac Sahur"] = {CPS=38000, Rarity="Hacked", Upgradeable=true},
    ["Los Primos Blue"] = {CPS=44500, Rarity="Hacked", Upgradeable=true},
    ["Cactus Pingu"] = {CPS=55000, Rarity="Hacked", Upgradeable=true},
    ["La Vacca Saturno Saturnita"] = {CPS=70000, Rarity="Hacked", Upgradeable=true},
    ["Agarrini La Palini"] = {CPS=90000, Rarity="Hacked", Upgradeable=true},
    ["Bottellini"] = {CPS=75000, Rarity="Exclusive", Upgradeable=true},
    ["Karkerkar Kurkur"] = {CPS=120000, Rarity="OG", Upgradeable=true},
    ["Blackhole Goat"] = {CPS=125000, Rarity="OG", Upgradeable=true},
    ["Cappuccino Clownino"] = {CPS=135000, Rarity="OG", Upgradeable=true},
    ["Compactoroni Diskaloni"] = {CPS=135000, Rarity="OG", Upgradeable=true},
    ["Nuclearo Dinossauro"] = {CPS=190000, Rarity="OG", Upgradeable=true},
    ["Los Nooo My Hotspotsitos"] = {CPS=200000, Rarity="Exclusive", Upgradeable=true},
    ["Chillin Chilli"] = {CPS=220000, Rarity="OG", Upgradeable=true},
    ["Crazylone Pizaione"] = {CPS=225000, Rarity="OG", Upgradeable=true},
    ["Corn Sahur"] = {CPS=225000, Rarity="OG", Upgradeable=true},
    ["Meowl"] = {CPS=275000, Rarity="OG", Upgradeable=true},
    ["Strawberry Elephant"] = {CPS=420000, Rarity="OG", Upgradeable=true},
    ["Dragonfrutina Dolphinita"] = {CPS=475000, Rarity="Celestial", Upgradeable=true},
    ["Guerriro Digitale"] = {CPS=490000, Rarity="Celestial", Upgradeable=true},
    ["Chicleteira Bicicleteira"] = {CPS=500000, Rarity="Celestial", Upgradeable=true},
    ["Pot Hotspot"] = {CPS=525000, Rarity="Celestial", Upgradeable=true},
    ["Krupuk Pagi Pagi"] = {CPS=540000, Rarity="Celestial", Upgradeable=true},
    ["Beluga Beluga"] = {CPS=575000, Rarity="Celestial", Upgradeable=true},
    ["Tralaledon"] = {CPS=625000, Rarity="Celestial", Upgradeable=true},
    ["Anpali Babel"] = {CPS=750000, Rarity="Celestial", Upgradeable=true},
    ["Los Primos"] = {CPS=800000, Rarity="Celestial", Upgradeable=true},
    ["Ketchuru Matsuru"] = {CPS=800000, Rarity="Exclusive", Upgradeable=true},
    ["Mastodontico Telepiedone"] = {CPS=850000, Rarity="Celestial", Upgradeable=true},
    ["Espresso Shockantoni"] = {CPS=1000000, Rarity="Eternal", Upgradeable=true},
    ["Ketupat Kepat"] = {CPS=1250000, Rarity="Eternal", Upgradeable=true},
    ["Professora 67"] = {CPS=1400000, Rarity="Eternal", Upgradeable=true},
    ["Astro Tim"] = {CPS=1500000, Rarity="Eternal", Upgradeable=true},
    ["Dumbelloni"] = {CPS=1750000, Rarity="Eternal", Upgradeable=true},
    ["Baba Yaga"] = {CPS=2000000, Rarity="Eternal", Upgradeable=true},
    ["Don Tiramisotto"] = {CPS=2250000, Rarity="Eternal", Upgradeable=true},
    ["Kicky"] = {CPS=2500000, Rarity="Eternal", Upgradeable=true},
    ["Smelloni Papayoni"] = {CPS=2750000, Rarity="Eternal", Upgradeable=true},
    ["Barbelloni Gymrattoni"] = {CPS=3000000, Rarity="Eternal", Upgradeable=true},
    ["Dribbloni Spaghetti"] = {CPS=7500000, Rarity="Abyssal", Upgradeable=true},
    ["Coinator Baconator"] = {CPS=6500000, Rarity="Abyssal", Upgradeable=true},
    ["Lucky Fella"] = {CPS=5000000, Rarity="Abyssal", Upgradeable=true},
    ["Pulcino Pistoletti"] = {CPS=10000000, Rarity="Abyssal", Upgradeable=true},
    ["Divinello Starblock"] = {CPS=8750000, Rarity="Abyssal", Upgradeable=true},
    ["Cordraculo"] = {CPS=10000000, Rarity="Abyssal", Upgradeable=true},
    ["Harpini Goosini"] = {CPS=11250000, Rarity="Abyssal", Upgradeable=true},
    ["OctoDJ"] = {CPS=15000000, Rarity="Abyssal", Upgradeable=true},
    ["Tubafante"] = {CPS=12500000, Rarity="Abyssal", Upgradeable=true},
    ["Turtinella Melodica"] = {CPS=16500000, Rarity="Abyssal", Upgradeable=true},
    ["W"] = {Best=0.75, Rarity="Exclusive", Upgradeable=false},
    ["Dragon Cannelloni"] = {Best=2, Rarity="Exclusive", Upgradeable=false},
    ["Spaghetti Tualetti"] = {Best=1.5, Rarity="Exclusive", Upgradeable=false},
    ["Esok Sekolah"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Job Job Job Sahur"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Yess My Examen"] = {Best=2.25, Rarity="Exclusive", Upgradeable=false},
    ["Lucky Kick"] = {Best=2.75, Rarity="Exclusive", Upgradeable=false},
    ["Hippocopter"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Auto Grizzlioni"] = {Best=2.25, Rarity="Exclusive", Upgradeable=false},
    ["Los Bombardinos"] = {Best=2.75, Rarity="Exclusive", Upgradeable=false},
    ["Rocky"] = {Best=1.75, Rarity="Exclusive", Upgradeable=false},
    ["Hat Tricky"] = {Best=1.75, Rarity="Exclusive", Upgradeable=false},
    ["GOAT"] = {Best=2.25, Rarity="Exclusive", Upgradeable=false},
    ["Bronze Block Medali"] = {Best=1.25, Rarity="Exclusive", Upgradeable=false},
    ["Golden Block Cuppy"] = {Best=10, Rarity="Exclusive", Upgradeable=false},
    ["Silver Block Cuppy"] = {Best=5, Rarity="Exclusive", Upgradeable=false},
    ["Bronze Block Cuppy"] = {Best=3, Rarity="Exclusive", Upgradeable=false},
    ["Golden Block Medali"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Silver Block Medali"] = {Best=2, Rarity="Exclusive", Upgradeable=false},
    ["Stadoini"] = {Best=2, Rarity="Exclusive", Upgradeable=false},
    ["Cone Cone Cone Sahur"] = {Best=3, Rarity="Exclusive", Upgradeable=false},
    ["Ballberto"] = {Best=1.25, Rarity="Exclusive", Upgradeable=false},
    ["Soccerdino"] = {Best=2.25, Rarity="Exclusive", Upgradeable=false},
    ["Netini Goalini"] = {Best=2.25, Rarity="Exclusive", Upgradeable=false},
    ["Orangutango Supremo"] = {Best=3.2, Rarity="Exclusive", Upgradeable=false},
    ["Croakumber"] = {Best=0.75, Rarity="Exclusive", Upgradeable=false},
    ["Lampuccio Raccoonelli"] = {Best=1.25, Rarity="Exclusive", Upgradeable=false},
    ["Tuki Tuki Taco"] = {Best=1, Rarity="Exclusive", Upgradeable=false},
    ["Professor Tigrellini"] = {Best=2, Rarity="Exclusive", Upgradeable=false},
    ["Patagotitan"] = {Best=1.5, Rarity="Exclusive", Upgradeable=false},
    ["Frigorex"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Velacoraptor"] = {Best=2.75, Rarity="Exclusive", Upgradeable=false},
    ["Bicletairussaurus"] = {Best=3, Rarity="Exclusive", Upgradeable=false},
    ["Jet Jet Raptoret"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Tricerabob"] = {Best=4, Rarity="Exclusive", Upgradeable=false},
    ["Teacherrina"] = {Best=4, Rarity="Exclusive", Upgradeable=false},
    ["Cucumbro Nerdino"] = {CPS=2500000, Rarity="Exclusive", Upgradeable=true},
    ["Locko Blocko"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
    ["Scuolabus Giraffini"] = {Best=3, Rarity="Exclusive", Upgradeable=false},
    ["Donutello"] = {Best=2.75, Rarity="Exclusive", Upgradeable=false},
    ["Professor Penneroni"] = {Best=1.75, Rarity="Exclusive", Upgradeable=false},
    ["Brain Mogger"] = {Best=2.5, Rarity="Exclusive", Upgradeable=false},
}

local function brainrotScore(name, level, mutation)
    local data = BrainrotData[name]

    if not data then
        return 0, 0
    end

    if data.Best then
        -- Exact NewInventory.GetSortInfo behavior from the uploaded game:
        -- Best-% brainrots are tier 2 and sort above CPS brainrots.
        return 2, tonumber(data.Best) or 0
    end

    local base = tonumber(data.CPS) or 0

    if base <= 0 then
        return 0, 0
    end

    local levelNumber = math.clamp(
        math.floor(tonumber(level) or 1),
        1,
        75
    )

    local mutationMultiplier =
        MutationBuffs[tostring(mutation or "")]
        or 1

    -- Exact EntitiesData.GetMultiplierPerLevel:
    -- base CPS × mutation × 1.25^(level-1)
    local currentCPS =
        base
        * mutationMultiplier
        * (1.25 ^ (levelNumber - 1))

    return 1, currentCPS
end

Runtime.BrainrotQualityScore = function(name, level, mutation)
    local data = BrainrotData[name]

    if not data then
        return 0, 0, 0
    end

    if data.Best then
        local best = tonumber(data.Best) or 0
        return 2, best, best
    end

    local base = tonumber(data.CPS) or 0

    if base <= 0 then
        return 0, 0, 0
    end

    local mutationMultiplier =
        MutationBuffs[tostring(mutation or "")]
        or 1

    -- Intrinsic quality intentionally ignores upgrade level.
    -- At the same level, every CPS brainrot scales by the same x1.25^(L-1),
    -- so Base CPS × Mutation is the correct long-term species comparison.
    local quality =
        base * mutationMultiplier

    local _, current =
        brainrotScore(name, level, mutation)

    return 1, quality, current
end

Runtime.BrainrotBeats = function(
    incomingTier,
    incomingQuality,
    incomingCurrent,
    placedTier,
    placedQuality,
    placedCurrent
)
    if incomingTier ~= placedTier then
        return incomingTier > placedTier
    end

    local threshold =
        math.max(
            1,
            tonumber(Config.ReplaceThreshold) or 1
        )

    if incomingQuality > placedQuality * threshold then
        return true
    end

    -- Equal intrinsic quality: preserve the stronger already-upgraded copy,
    -- but allow a higher-level/current-output duplicate to replace a weaker one.
    if threshold <= 1
        and incomingQuality == placedQuality
        and incomingCurrent > placedCurrent
    then
        return true
    end

    return false
end

local function brainrotUpgradeCost(name, level, mutation)
    local data = BrainrotData[name]

    if not data
        or not data.CPS
        or data.Upgradeable == false
    then
        return nil
    end

    local levelNumber = math.clamp(
        math.floor(tonumber(level) or 1),
        1,
        75
    )

    if levelNumber >= 75 then
        return nil
    end

    local base = tonumber(data.CPS) or 0
    local mutationMultiplier =
        MutationBuffs[tostring(mutation or "")]
        or 1

    -- Exact EntitiesData.GetCostForUpgrade:
    -- base CPS × mutation × 1.5^(level-1)
    return math.floor(
        base
        * mutationMultiplier
        * (1.5 ^ (levelNumber - 1))
    )
end

local function brainrotCurrentCPS(name, level, mutation)
    local data = BrainrotData[name]

    if not data or not data.CPS then
        return nil
    end

    local base = tonumber(data.CPS) or 0

    if base <= 0 then
        return nil
    end

    local levelNumber = math.clamp(
        math.floor(tonumber(level) or 1),
        1,
        75
    )

    local mutationMultiplier =
        MutationBuffs[tostring(mutation or "")]
        or 1

    return base
        * mutationMultiplier
        * (1.25 ^ (levelNumber - 1))
end

local function brainrotUpgradeROI(name, level, mutation)
    local currentCPS =
        brainrotCurrentCPS(name, level, mutation)

    local cost =
        brainrotUpgradeCost(name, level, mutation)

    if not currentCPS or not cost or cost <= 0 then
        return nil, nil, nil, nil, nil
    end

    -- Exact level multiplier is x1.25, so every successful level gives +25%
    -- of the current CPS.
    local nextCPS = currentCPS * 1.25
    local gain = nextCPS - currentCPS

    return gain / cost,
        gain,
        cost,
        currentCPS,
        nextCPS
end

local KickStyleData = {
    {Name="Default", Multiplier=1.00, PerfectLength=2.51, Cost=0, AlwaysOwned=true},
    {Name="Stomp", Multiplier=1.10, PerfectLength=2.30, Cost=125},
    {Name="Mule", Multiplier=1.20, PerfectLength=2.11, Cost=500},
    {Name="Ballerina", Multiplier=1.30, PerfectLength=3.10, Cost=1250},
    {Name="Spartan", Multiplier=1.40, PerfectLength=2.53, Cost=3000},
    {Name="Retro", Multiplier=1.50, PerfectLength=3.003, Cost=7500},
    {Name="Acrobatic", Multiplier=1.60, PerfectLength=2.73, Cost=12500},
    {Name="Karate", Multiplier=1.70, PerfectLength=3.08, Cost=17500},
    {Name="Chest", Multiplier=1.50, PerfectLength=2.48},
    {Name="Flip", Multiplier=1.50, PerfectLength=2.77},
    {Name="Lava", Multiplier=1.25, PerfectLength=3.17},
    {Name="Rainbow", Multiplier=1.65, PerfectLength=2.48},
    {Name="Super", Multiplier=1.65, PerfectLength=2.37},
    {Name="Tornado", Multiplier=1.70, PerfectLength=4.45},
}

local SlotUpgradePrices = {
    5000000, 25000000, 75000000, 100000000, 250000000,
    750000000, 1000000000, 2000000000, 5000000000, 10000000000,
    25000000000, 50000000000, 100000000000, 200000000000, 500000000000,
    1000000000000, 5000000000000, 10000000000000, 25000000000000, 50000000000000,
}

local BattlePassFreeXP = {
    [1]=500,[2]=1000,[3]=1500,[4]=2000,[5]=2500,[6]=3000,[7]=3500,[8]=4000,
    [9]=4500,[10]=5000,[11]=5500,[12]=6000,[13]=6500,[14]=7000,[15]=7500,
}
local BattlePassBonusXP = {
    [1]=8250,[2]=9000,[3]=9750,[4]=10500,[5]=11250,
}

local SchoolCraftRecipes = {
    {
        Price=1250, Reward="Cucumbro Nerdino",
        Requirements={
            {Name="Stoppo Luminino",Count=3},
            {Name="Peant Jarro",Count=5},
            {Name="Burguro",Count=5},
        },
    },
    {
        Price=2500, Reward="Professor Penneroni",
        Requirements={
            {Name="Cucumbro Nerdino",Count=3},
            {Name="Karkerkar Kurkur",Count=5},
            {Name="SWAG SODA",Count=5},
        },
    },
    {
        Price=7500, Reward="Brain Mogger",
        Requirements={
            {Name="Professor Penneroni",Count=2},
            {Name="Cucumbro Nerdino",Count=2},
            {Name="Pot Hotspot",Count=5},
        },
    },
}

-- ============================================================================
-- Number / HUD state readers
-- ============================================================================

local Suffixes = {
    k=1e3, m=1e6, b=1e9, t=1e12,
    qa=1e15, qi=1e18, sx=1e21, sp=1e24,
    oc=1e27, no=1e30, dc=1e33,
}

local function parseCompactNumber(value)
    if typeof(value) == "number" then
        return value
    end
    if type(value) ~= "string" then
        return nil
    end

    local text = value:gsub(",", ""):gsub("%$", ""):gsub("%s+", " ")
    local raw = text:match("[-+]?[%d%.]+[eE][-+]?%d+")
    if raw then
        return tonumber(raw)
    end

    local numberText, suffix = text:match("([-+]?[%d%.]+)%s*([%a]+)")
    if numberText then
        local n = tonumber(numberText)
        if not n then
            return nil
        end
        if suffix then
            local mult = Suffixes[suffix:lower()]
            if mult then
                return n * mult
            end
        end
        return n
    end

    return tonumber(text:match("[-+]?[%d%.]+"))
end

local function findHUD()
    return PlayerGui:FindFirstChild("HUD")
end

local RunPhaseCache = {
    LastScan = 0,
    Visible = false,
}

local function guiObjectActuallyVisible(object)
    if not object or not object:IsA("GuiObject") or not object.Visible then
        return false
    end

    local parent = object.Parent
    while parent do
        if parent:IsA("GuiObject") and not parent.Visible then
            return false
        end
        if parent:IsA("ScreenGui") and not parent.Enabled then
            return false
        end
        parent = parent.Parent
    end

    return true
end

local function runPhaseVisible(force)
    local now = os.clock()
    if not force and now - RunPhaseCache.LastScan < 0.03 then
        return RunPhaseCache.Visible
    end

    RunPhaseCache.LastScan = now
    RunPhaseCache.Visible = false

    -- Exact inspected RunUI implementation:
    --   local Run = HUD.Run
    --   Run.Visible = true / false
    local hud = findHUD()
    local runObject = hud and hud:FindFirstChild("Run")

    if runObject and runObject:IsA("GuiObject") and guiObjectActuallyVisible(runObject) then
        RunPhaseCache.Visible = true
        Runtime.PendingRewardPlacement = true
        return true
    end
    if hud then
        local ok, descendants = pcall(hud.GetDescendants, hud)
        if ok and type(descendants) == "table" then
            for _, object in ipairs(descendants) do
                if (object:IsA("TextLabel") or object:IsA("TextButton"))
                    and guiObjectActuallyVisible(object)
                then
                    local normalized = tostring(object.Text or "")
                        :upper()
                        :gsub("%s+", "")

                    if normalized:find("RUN!!", 1, true) then
                        RunPhaseCache.Visible = true
                        Runtime.PendingRewardPlacement = true
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function transformedRewardModel()
    local entities = workspace:FindFirstChild("Entities")
    if not entities then
        return nil
    end

    local model = entities:FindFirstChild(LocalPlayer.Name)
    if model and model:IsA("Model") then
        return model
    end

    return nil
end

local function transformedRewardNames()
    local model = transformedRewardModel()
    local names = {}

    if model then
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("Model") then
                table.insert(names, child.Name)
            end
        end
    end

    return names
end

local function rewardNamesFromPayload(payload)
    local names = {}

    if type(payload) == "string" then
        table.insert(names, payload)
        return names
    end

    if type(payload) ~= "table" then
        return names
    end

    for _, entry in ipairs(payload) do
        if type(entry) == "table" and entry.Name ~= nil then
            table.insert(names, tostring(entry.Name))
        elseif type(entry) == "string" then
            table.insert(names, entry)
        end
    end

    return names
end

local function describeRewardNames()
    local names = transformedRewardNames()

    if #names == 0 then
        names = rewardNamesFromPayload(Runtime.LastRewardNames)
    end

    if #names == 0 then
        names = rewardNamesFromPayload(Runtime.LastCollectedPayload)
    end

    if #names == 0 then
        return "reward"
    end

    return table.concat(names, " + ")
end


local function findFrames()
    return PlayerGui:FindFirstChild("Frames")
end

local function currentBalance()
    local hud = findHUD()
    local label = hud
        and hud:FindFirstChild("BottomLeft")
        and hud.BottomLeft:FindFirstChild("CoinsFrame")
        and hud.BottomLeft.CoinsFrame:FindFirstChild("InsideFrame")
        and hud.BottomLeft.CoinsFrame.InsideFrame:FindFirstChild("CoinLabel")

    if label and label:IsA("TextLabel") then
        return parseCompactNumber(label.Text) or 0
    end
    return 0
end

local function currentKickPower()
    if type(Runtime.KickPower) == "number" then
        return Runtime.KickPower
    end

    local hud = findHUD()
    local label = hud
        and hud:FindFirstChild("BottomLeft")
        and hud.BottomLeft:FindFirstChild("KickLevel")
        and hud.BottomLeft.KickLevel:FindFirstChild("TextLabel")

    if label and label:IsA("TextLabel") then
        return parseCompactNumber(label.Text) or 0
    end
    return 0
end

local function currentKickMastery()
    if type(Runtime.KickMastery) == "number" then
        return Runtime.KickMastery
    end

    local hud = findHUD()
    local mastery = hud
        and hud:FindFirstChild("BottomLeft")
        and hud.BottomLeft:FindFirstChild("KickMastery")
    local inside = mastery and mastery:FindFirstChild("InsideFrame")
    local label = inside and inside:FindFirstChild("CoinLabel")

    if label and label:IsA("TextLabel") then
        return parseCompactNumber(label.Text) or 0
    end

    return 0
end

local function currentSpeedLevel()
    if type(Runtime.SpeedLevel) == "number" then
        return Runtime.SpeedLevel
    end

    local frames = findFrames()
    local speed = frames and frames:FindFirstChild("SpeedUpgrades")
    local scroll = speed and speed:FindFirstChild("ScrollingFrame")
    local card = scroll and scroll:FindFirstChild("+1 Speed")
    local label = card and card:FindFirstChild("NameLabel")

    if label and label:IsA("TextLabel") then
        local runSpeed = parseCompactNumber(label.Text)
        if runSpeed then
            return math.max(0, math.floor(runSpeed - 13 + 0.5))
        end
    end
    return 0
end

local function currentRebirthLevel()
    if type(Runtime.RebirthLevel) == "number" then
        return Runtime.RebirthLevel
    end

    local frames = findFrames()
    local rebirth = frames and frames:FindFirstChild("Rebirth")
    local label = rebirth and rebirth:FindFirstChild("RebirthLevel")
    if label and label:IsA("TextLabel") then
        return math.max(0, math.floor(parseCompactNumber(label.Text) or 0))
    end
    return 0
end

local function tutorialStep()
    return tonumber(LocalPlayer:GetAttribute("TutorialStep"))
end

-- ============================================================================
-- Live remote caches. These are listeners only; no game module require needed.
-- ============================================================================

connectRemote("KickData", function(level, mastery)
    if typeof(level) == "number" then
        Runtime.KickPower = level
    end
    if typeof(mastery) == "number" then
        Runtime.KickMastery = mastery
    end
end)

connectRemote("AnimData", function(owned, equipped)
    Runtime.OwnedStyles = {}

    if type(owned) == "table" then
        for _, name in pairs(owned) do
            if type(name) == "string" then
                Runtime.OwnedStyles[name] = true
            end
        end
    end

    Runtime.EquippedStyle = tostring(equipped or "Default")
end)

connectRemote("SPEED_UPDATE", function(level)
    if typeof(level) == "number" then
        Runtime.SpeedLevel = level
    end
end)

connectRemote("RebirthUpdate", function(level)
    if typeof(level) == "number" then
        Runtime.RebirthLevel = level
    end
end)

connectRemote("Weight_Update", function(equipped, owned)
    Runtime.EquippedWeight = equipped
    Runtime.OwnedWeights = {}
    if type(owned) == "table" then
        for _, name in ipairs(owned) do
            Runtime.OwnedWeights[tostring(name)] = true
        end
    end
end)

connectRemote("kickPhase2", function(rewards)
    Runtime.RoundActive = true
    Runtime.SawKickPhase2 = true
    Runtime.PendingRewardPlacement = true
    Runtime.LastRewardNames = rewards
    Runtime.RewardLandingPosition = nil
    Runtime.RewardReturnStartedAt = 0
    Runtime.DismissCurrentReward = false
    Runtime.PostKickPhase = "RewardRolled"
end)

connectRemote("Collected", function(payload)
    Runtime.LastCollectedAt = os.clock()
    Runtime.LastCollectedPayload = payload
    Runtime.PendingRewardPlacement = true
    Runtime.PostKickPhase = "Collected"
end)

connectRemote("KickEventEnded", function(success)
    Runtime.RoundActive = false
    Runtime.SawKickPhase2 = false

    local now = os.clock()
    Runtime.LastKickEndedAt = now
    Runtime.RewardRoundEndedAt = now
    Runtime.LastKickSucceeded = success == true


    Runtime.CompletedKickCycles = (Runtime.CompletedKickCycles or 0) + 1
    Runtime.KicksSinceTraining = (Runtime.KicksSinceTraining or 0) + 1

    Runtime.DismissCurrentReward = false

    if success == true then
        Runtime.PostKickPhase = "Restored"
    else
        Runtime.PendingRewardPlacement = false
        Runtime.PostKickPhase = "Ended"
    end

    Runtime.NeedsImmediateTraining = true
end)


-- Expanded progression/reward state.
connectRemote("bs_updateClient", function(added)
    if typeof(added) == "number" then
        Runtime.AddedSlots = math.clamp(math.floor(added), 0, 20)
    end
end)

connectRemote("UpdateSpins", function(spins)
    if typeof(spins) == "number" then
        Runtime.WheelSpins = math.max(0, math.floor(spins))
    end
end)

connectRemote("SpinWheel", function()
    Runtime.WheelBusyUntil = os.clock() + 5.25
end)

local function currentWheelSpins()
    local spins = Runtime.WheelSpins

    if typeof(spins) == "number" then
        return math.max(0, math.floor(spins))
    end

    local wheelGui = PlayerGui:FindFirstChild("WheelSpin")
    local buttons = wheelGui and wheelGui:FindFirstChild("Buttons")
    local spinButton = buttons and buttons:FindFirstChild("SpinButton")
    local label = spinButton and spinButton:FindFirstChild("SpinsLabel")

    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        local parsed = tonumber(tostring(label.Text or ""):match("(%d+)"))

        if parsed then
            Runtime.WheelSpins = math.max(0, math.floor(parsed))
            return Runtime.WheelSpins
        end
    end

    return 0
end

connectRemote("CheckFree", function(claimed)
    Runtime.FreeItemClaimed = claimed == true
    Runtime.FreeItemCheckedAt = os.clock()

    if claimed == false and Config.AutoClaimFreeItem then
        task.defer(function()
            if Runtime.Alive and Config.AutoClaimFreeItem then
                Runtime.ExtraState = "Claiming free shop brainrot"
                fireServer("ClaimFree")
                Runtime.FreeItemClaimed = true
            end
        end)
    end
end)

connectRemote("BattlePassDataSend", function(state)
    if type(state) == "table" then
        Runtime.BattlePassState = state
    end
end)

connectRemote("scoreUpdate", function(score)
    if typeof(score) == "number" then
        Runtime.SchoolScore = score
    end
end)

-- Training bonus buttons are client-side popups; the game's button simply sends
-- TaviMishkal back to the server. Claim as soon as the popup is awarded.
connectRemote("TaviMishkal", function(multiplier)
    if not Config.AutoKickBonuses or typeof(multiplier) ~= "number" then
        return
    end

    task.delay(0.03, function()
        if Runtime.Alive and Config.AutoKickBonuses then
            Runtime.LastBonusClaim = os.clock()
            Runtime.ExtraState = ("Claiming x%s kick bonus"):format(tostring(multiplier))
            fireServer("TaviMishkal")
        end
    end)
end)

-- Mighty Chest normally spawns a local key and sends mightyChest when its
-- local Hitbox is touched. This optional helper claims that key after a short,
-- human-scale delay when the server explicitly asks this client to spawn it.
connectRemote("mightyChest", function(distance)
    if not Config.AutoMightyChest or typeof(distance) ~= "number" then
        return
    end

    if Runtime.MightyChestPending then
        return
    end

    Runtime.MightyChestPending = true
    task.delay(0.75, function()
        Runtime.MightyChestPending = false
        if Runtime.Alive and Config.AutoMightyChest then
            Runtime.ExtraState = "Claiming Mighty Chest key"
            fireServer("mightyChest")
        end
    end)
end)

-- Optional Back To School math assist. The server sends the wall table first;
-- each numeric key is the same ID the stock client submits after crossing the
-- correct answer. Pace submissions after RUN starts instead of firing instantly.
connectRemote("mathUPD", function(walls)
    if not Config.AutoSchoolMath or type(walls) ~= "table" then
        return
    end

    local ids = {}
    for id in pairs(walls) do
        if tonumber(id) then
            table.insert(ids, tonumber(id))
        end
    end
    table.sort(ids)

    task.spawn(function()
        local deadline = os.clock() + 20
        while Runtime.Alive and Config.AutoSchoolMath
            and not runPhaseVisible(true)
            and os.clock() < deadline
        do
            task.wait(0.05)
        end

        if not Runtime.Alive or not Config.AutoSchoolMath then
            return
        end

        for _, id in ipairs(ids) do
            if not Runtime.Alive or not Config.AutoSchoolMath then
                break
            end
            Runtime.ExtraState = ("School math answer %d"):format(id)
            fireServer("mathUPD", id)
            task.wait(0.35)
        end
    end)
end)


-- ============================================================================
-- Avoids re-requiring dumped ModuleScripts and avoids executor GUI-click issues.
-- ============================================================================

local NativeControllers = {
    GameHandler = nil,
    KickMinigame = nil,
    LastScan = 0,
}

local function safeRawGet(tbl, key)
    local ok, value = pcall(function()
        return rawget(tbl, key)
    end)
    return ok and value or nil
end

local function safeGet(tbl, key)
    -- Prefer normal indexing so metatable-backed controller fields/functions
    -- are visible. Fall back to rawget for plain tables.
    local ok, value = pcall(function()
        return tbl[key]
    end)

    if ok then
        return value
    end

    return safeRawGet(tbl, key)
end

local function scanLoadedNativeControllers(force)
    if not force and os.clock() - NativeControllers.LastScan < 1 then
        return NativeControllers.GameHandler, NativeControllers.KickMinigame
    end
    NativeControllers.LastScan = os.clock()

    if type(getgc) ~= "function" then
        return NativeControllers.GameHandler, NativeControllers.KickMinigame
    end

    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then
        ok, objects = pcall(getgc)
    end
    if not ok or type(objects) ~= "table" then
        return NativeControllers.GameHandler, NativeControllers.KickMinigame
    end

    local bestGameHandler = NativeControllers.GameHandler
    local bestGameScore = bestGameHandler and 999 or -1

    local bestKickMinigame = NativeControllers.KickMinigame
    local bestMiniScore = bestKickMinigame and 999 or -1

    for _, object in ipairs(objects) do
        if type(object) == "table" then
            -- KickMinigameUI is identified primarily by METHODS. v1.8 wrongly
            -- required InMinigame/Scale to already exist as raw table keys.
            local startFn = safeGet(object, "Start")
            local endFn = safeGet(object, "End")
            local cancelFn = safeGet(object, "Cancel")
            local focusFn = safeGet(object, "FocusOnPerfect")
            local resetFn = safeGet(object, "Reset")

            local miniScore = 0
            if type(startFn) == "function" then miniScore = miniScore + 5 end
            if type(endFn) == "function" then miniScore = miniScore + 5 end
            if type(cancelFn) == "function" then miniScore = miniScore + 3 end
            if type(focusFn) == "function" then miniScore = miniScore + 4 end
            if type(resetFn) == "function" then miniScore = miniScore + 1 end
            if safeGet(object, "InMinigame") ~= nil then miniScore = miniScore + 2 end
            if safeGet(object, "Scale") ~= nil then miniScore = miniScore + 2 end

            -- Start + End are mandatory. The additional methods separate this
            -- from unrelated generic controllers.
            if type(startFn) == "function"
                and type(endFn) == "function"
                and miniScore > bestMiniScore
            then
                bestMiniScore = miniScore
                bestKickMinigame = object
            end

            -- GameHandler is likewise identified by its stable methods, not by
            -- temporary state fields that may legitimately be nil while idle.
            local kickFn = safeGet(object, "Kick")
            local unblockFn = safeGet(object, "UnblockKick")
            local blockFn = safeGet(object, "BlockKick")
            local resetKickFn = safeGet(object, "ResetKick")
            local startGameFn = safeGet(object, "StartGame")

            local gameScore = 0
            if type(kickFn) == "function" then gameScore = gameScore + 7 end
            if type(unblockFn) == "function" then gameScore = gameScore + 4 end
            if type(blockFn) == "function" then gameScore = gameScore + 4 end
            if type(resetKickFn) == "function" then gameScore = gameScore + 2 end
            if type(startGameFn) == "function" then gameScore = gameScore + 1 end
            if safeGet(object, "InGame") ~= nil then gameScore = gameScore + 1 end
            if safeGet(object, "Status") ~= nil then gameScore = gameScore + 1 end

            if type(kickFn) == "function"
                and (type(unblockFn) == "function" or type(blockFn) == "function")
                and gameScore > bestGameScore
            then
                bestGameScore = gameScore
                bestGameHandler = object
            end
        end
    end

    NativeControllers.GameHandler = bestGameHandler
    NativeControllers.KickMinigame = bestKickMinigame

    return bestGameHandler, bestKickMinigame
end

local function startNativeKickMinigame()
    local _, kickMinigame = scanLoadedNativeControllers(false)
    if not kickMinigame then
        _, kickMinigame = scanLoadedNativeControllers(true)
    end
    if not kickMinigame then
        return false, "KickMinigame controller not found (getgc scan)"
    end

    if LocalPlayer:GetAttribute("RoundDebounce")
        or LocalPlayer:GetAttribute("KickDebounced")
    then
        return false, "game kick cooldown active"
    end

    local character = LocalPlayer.Character
    local primary = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
    if not primary then
        return false, "character root missing"
    end

    local startFn = safeGet(kickMinigame, "Start")
    if type(startFn) ~= "function" then
        return false, "controller found but Start is unavailable"
    end

    local ok, err = pcall(function()
        primary.Anchored = true

        local alreadyActive = safeGet(kickMinigame, "InMinigame") == true
        if not alreadyActive then
            startFn(kickMinigame)
        end
    end)

    if not ok then
        pcall(function()
            primary.Anchored = false
        end)
        return false, "KickMinigame.Start error: " .. tostring(err)
    end

    -- Verify the call actually opened the game's minigame.
    local deadline = os.clock() + 1.25
    while Runtime.Alive and os.clock() < deadline do
        local gui = PlayerGui:FindFirstChild("KickMinigame")
        if (gui and gui.Enabled == true)
            or safeGet(kickMinigame, "InMinigame") == true
        then
            return true
        end
        task.wait(0.04)
    end

    pcall(function()
        primary.Anchored = false
    end)

    return false, "Start returned but KickMinigame stayed closed"
end

local function finishNativeKickMinigame(scale)
    local gameHandler, kickMinigame = scanLoadedNativeControllers(false)
    if not gameHandler or not kickMinigame then
        gameHandler, kickMinigame = scanLoadedNativeControllers(true)
    end
    if not gameHandler or not kickMinigame then
        return false, "native kick controllers not found"
    end

    if safeGet(kickMinigame, "InMinigame") ~= true then
        return false, "minigame is not active"
    end

    -- Use the ACTUAL live minigame scale. Do not forge an instant 1.0 server
    -- request. This mirrors the inspected OnInMinigame() client sequence:
    -- KickMinigameUI:End(scale) -> GameHandler:Kick(scale).
    local liveScale = tonumber(safeGet(kickMinigame, "Scale"))
        or tonumber(scale)
        or 0

    liveScale = math.clamp(liveScale, 0, 1)

    local ok = pcall(function()
        kickMinigame:End(liveScale)
        task.wait(0.05)
        gameHandler:Kick(liveScale)
    end)

    return ok, ok and nil or "native minigame finish failed"
end

-- ============================================================================
-- Movement / UI input helpers
-- ============================================================================

local function unequipAndUnanchor()
    pcall(function()
        local hum = humanoid()
        if hum then
            hum:UnequipTools()
        end
        local root = rootPart()
        if root then
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function normalizeTravelMode(value)
    value = tostring(value or "Walk")

    -- Migrate the old unsafe v1.5 "Teleport" value to Walk.
    if value == "Teleport" then
        return "Walk"
    end

    if value == "Teleport (Safe)" or value == "Manual" then
        return value
    end

    return "Walk"
end

local function groundedTravelPosition(target)
    local root = rootPart()
    if not root then
        return nil
    end

    local candidate

    if target:IsA("BasePart") then
        -- Large trigger parts (especially Areas.KickReady) should not be treated
        -- like point destinations. Use the nearest point inside the X/Z footprint.
        local localPos = target.CFrame:PointToObjectSpace(root.Position)
        local half = target.Size * 0.5
        local insetX = math.max(half.X - math.min(4, half.X * 0.25), 0)
        local insetZ = math.max(half.Z - math.min(4, half.Z * 0.25), 0)

        local localX = math.clamp(localPos.X, -insetX, insetX)
        local localZ = math.clamp(localPos.Z, -insetZ, insetZ)
        local world = target.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
        candidate = Vector3.new(world.X, target.Position.Y, world.Z)
    elseif target:IsA("Model") then
        local ok, pivot = pcall(target.GetPivot, target)
        if not ok then
            return nil
        end
        candidate = pivot.Position
    else
        return nil
    end

    -- Ground the destination so an event trigger/pivot cannot place us in mid-air.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignore = {}
    local character = LocalPlayer.Character
    if character then
        table.insert(ignore, character)
    end
    if target:IsA("BasePart") then
        table.insert(ignore, target)
    end

    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = false

    local originY = math.max(root.Position.Y + 120, candidate.Y + 120)
    local result = workspace:Raycast(
        Vector3.new(candidate.X, originY, candidate.Z),
        Vector3.new(0, -500, 0),
        params
    )

    if result then
        return result.Position + Vector3.new(0, 3.25, 0)
    end

    return Vector3.new(candidate.X, root.Position.Y, candidate.Z)
end

local walkToPosition

local function moveTo(target, timeout)
    if not target or not target.Parent or not waitAlive(5) then
        return false
    end

    local root = rootPart()
    local hum = humanoid()
    if not root or not hum then
        return false
    end

    local position = groundedTravelPosition(target)
    if not position then
        return false
    end

    unequipAndUnanchor()

    local mode = normalizeTravelMode(Config.TravelMode)
    Config.TravelMode = mode

    if mode == "Manual" then
        return false
    end

    if mode == "Teleport (Safe)" then
        pcall(function()
            local rotationOnly = root.CFrame - root.CFrame.Position
            root.CFrame = CFrame.new(position) * rotationOnly
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.18)

        local currentRoot = rootPart()
        return currentRoot ~= nil and (currentRoot.Position - position).Magnitude <= 8
    end

    -- Default travel: same PlayerModule-disabled MoveTo architecture used by
    -- the game's AutoController/AutoClass.
    return walkToPosition(position, timeout or 10, 5)
end

walkToPosition = function(position, timeout, radius)
    if typeof(position) ~= "Vector3" or not waitAlive(5) then
        return false
    end

    local root = rootPart()
    local hum = humanoid()
    if not root or not hum then
        return false
    end

    unequipAndUnanchor()

    local controlsDisabled = disablePlayerControls()
    radius = tonumber(radius) or 6

    local reached = false
    local frameError = nil
    local moveConnection
    local bestDistance = math.huge
    local lastProgressAt = os.clock()
    local lastJumpAt = 0

    moveConnection = RunService.PreRender:Connect(function()
        if not Runtime.Alive then
            return
        end

        local currentRoot = rootPart()
        local currentHum = humanoid()

        if not currentRoot
            or not currentHum
            or currentHum.Health <= 0
            or currentRoot.Anchored
        then
            return
        end

        local flatDelta = Vector3.new(
            position.X - currentRoot.Position.X,
            0,
            position.Z - currentRoot.Position.Z
        )

        local ok, err = pcall(function()
            currentHum:MoveTo(position)
        end)

        if not ok then
            frameError = tostring(err)
            return
        end

        if not controlsDisabled and flatDelta.Magnitude > 0.1 then
            pcall(function()
                currentHum:Move(flatDelta.Unit, false)
            end)
        end
    end)

    local deadline = os.clock() + (timeout or 15)

    while Runtime.Alive and os.clock() < deadline do
        root = rootPart()
        hum = humanoid()

        if not root or not hum or hum.Health <= 0 then
            break
        end

        local horizontal = Vector3.new(
            root.Position.X - position.X,
            0,
            root.Position.Z - position.Z
        ).Magnitude

        if horizontal <= radius then
            reached = true
            break
        end

        if horizontal < bestDistance - 0.35 then
            bestDistance = horizontal
            lastProgressAt = os.clock()
        elseif os.clock() - lastProgressAt > 0.85 and os.clock() - lastJumpAt > 0.70 then
            lastJumpAt = os.clock()
            nudgeJump("Automatic walk stuck • jumping")
            lastProgressAt = os.clock()
        end

        if frameError then
            break
        end

        task.wait(0.025)
    end

    if moveConnection then
        pcall(function()
            moveConnection:Disconnect()
        end)
    end

    stopAutomatedWalk()
    return reached
end

local function kickReadyPart()
    local areas = workspace:FindFirstChild("Areas")
    return areas and areas:FindFirstChild("KickReady") or nil
end

local function collectZonePart()
    local zones = workspace:FindFirstChild("Zones")
    return zones and zones:FindFirstChild("CollectZone") or nil
end

local function isInsidePart(part)
    local root = rootPart()
    if not root or not part or not part:IsA("BasePart") then
        return false
    end
    local p = part.CFrame:PointToObjectSpace(root.Position)
    local half = part.Size * 0.5 + Vector3.new(4, 6, 4)
    return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function ensureKickZone()
    -- If the game's own KICK button is visible, we are already in a valid kick
    -- position. Never walk/teleport away from that state.
    local hud = findHUD()
    local kickButton = hud and hud:FindFirstChild("KickButton")
    if kickButton and kickButton:IsA("GuiButton") and kickButton.Visible then
        return true
    end

    local part = kickReadyPart()
    if not part then
        return false
    end
    if isInsidePart(part) then
        return true
    end

    local mode = normalizeTravelMode(Config.TravelMode)
    if mode == "Manual" then
        setState("Walk into the kick zone")
        return false
    end

    setState(mode == "Walk" and "Walking to kick zone" or "Safe teleport to kick zone")
    moveTo(part, 10)

    local deadline = os.clock() + 2.5
    while Runtime.Alive and os.clock() < deadline do
        hud = findHUD()
        kickButton = hud and hud:FindFirstChild("KickButton")

        if kickButton and kickButton:IsA("GuiButton") and kickButton.Visible then
            return true
        end

        if isInsidePart(part) then
            return true
        end
        task.wait(0.05)
    end

    return isInsidePart(part)
end

local InputActionCache = {}

local function findGameInputAction(contextName, actionName, force)
    local cacheKey = tostring(contextName) .. "::" .. tostring(actionName)

    if not force then
        local cached = InputActionCache[cacheKey]
        if cached
            and cached.Context
            and cached.Context.Parent
            and cached.Action
            and cached.Action.Parent
        then
            return cached.Context, cached.Action, cached.Binding
        end
    end

    local roots = {
        ReplicatedStorage,
        LocalPlayer:FindFirstChild("PlayerScripts"),
        PlayerGui,
    }

    for _, root in ipairs(roots) do
        if root then
            local ok, descendants = pcall(root.GetDescendants, root)
            if ok and type(descendants) == "table" then
                for _, object in ipairs(descendants) do
                    if object:IsA("InputContext")
                        and object.Name == contextName
                    then
                        local action = object:FindFirstChild(actionName)

                        if action and action:IsA("InputAction") then
                            local binding = action:FindFirstChild("KeyboardBinding")

                            if not (binding and binding:IsA("InputBinding")) then
                                for _, child in ipairs(action:GetChildren()) do
                                    if child:IsA("InputBinding") then
                                        binding = child
                                        break
                                    end
                                end
                            end

                            InputActionCache[cacheKey] = {
                                Context = object,
                                Action = action,
                                Binding = binding,
                            }

                            return object, action, binding
                        end
                    end
                end
            end
        end
    end

    InputActionCache[cacheKey] = nil
    return nil, nil, nil
end

local function sendKeyCode(keyCode)
    local okService, vim = pcall(function()
        return game:GetService("VirtualInputManager")
    end)

    if not okService or not vim then
        return false, "VirtualInputManager unavailable"
    end

    local ok, err = pcall(function()
        vim:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.006)
        vim:SendKeyEvent(false, keyCode, false, game)
    end)

    return ok, ok and nil or tostring(err)
end


local MovementKeyState = {
    [Enum.KeyCode.W] = false,
    [Enum.KeyCode.A] = false,
    [Enum.KeyCode.S] = false,
    [Enum.KeyCode.D] = false,
}

local ExecutorVirtualKeys = {
    [Enum.KeyCode.W] = 0x57,
    [Enum.KeyCode.A] = 0x41,
    [Enum.KeyCode.S] = 0x53,
    [Enum.KeyCode.D] = 0x44,
}

local function sendMovementKeyState(keyCode, down)
    down = down == true

    if MovementKeyState[keyCode] == down then
        return true
    end

    local sent = false

    -- Primary path: genuine Roblox keyboard input events. This is the same
    -- VirtualInputManager path already proven to work for startKicking.
    local okService, vim = pcall(function()
        return game:GetService("VirtualInputManager")
    end)

    if okService and vim then
        sent = pcall(function()
            vim:SendKeyEvent(down, keyCode, false, game)
        end)
    end

    -- Executor-level keyboard fallback when exposed. These are actual key
    -- down/up events rather than setting Humanoid.MoveDirection/MoveTo.
    if not sent then
        local vk = ExecutorVirtualKeys[keyCode]

        if vk and down and type(keypress) == "function" then
            sent = pcall(keypress, vk)
        elseif vk and not down and type(keyrelease) == "function" then
            sent = pcall(keyrelease, vk)
        end
    end

    if sent then
        MovementKeyState[keyCode] = down
    end

    return sent
end

local function releaseMovementKeys()
    for keyCode, isDown in pairs(MovementKeyState) do
        if isDown then
            sendMovementKeyState(keyCode, false)
        end
    end
end

local function applyWASDToWorldTarget(targetPosition)
    local root = rootPart()
    local camera = workspace.CurrentCamera

    if not root or not camera or typeof(targetPosition) ~= "Vector3" then
        releaseMovementKeys()
        return false, math.huge
    end

    local delta = Vector3.new(
        targetPosition.X - root.Position.X,
        0,
        targetPosition.Z - root.Position.Z
    )

    local distance = delta.Magnitude
    if distance < 0.25 then
        releaseMovementKeys()
        return true, distance
    end

    local desired = delta.Unit

    local look = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector

    local forward = Vector3.new(look.X, 0, look.Z)
    local rightFlat = Vector3.new(right.X, 0, right.Z)

    if forward.Magnitude < 0.01 or rightFlat.Magnitude < 0.01 then
        releaseMovementKeys()
        return false, distance
    end

    forward = forward.Unit
    rightFlat = rightFlat.Unit

    local forwardAmount = desired:Dot(forward)
    local rightAmount = desired:Dot(rightFlat)

    -- Use a low threshold so diagonal W+D/W+A movement is selected naturally
    -- instead of zig-zagging along one axis at a time.
    local threshold = 0.20

    local wantW = forwardAmount > threshold
    local wantS = forwardAmount < -threshold
    local wantD = rightAmount > threshold
    local wantA = rightAmount < -threshold

    -- Near a cardinal boundary, always keep at least the dominant direction held.
    if not wantW and not wantS and not wantA and not wantD then
        if math.abs(forwardAmount) >= math.abs(rightAmount) then
            wantW = forwardAmount >= 0
            wantS = not wantW
        else
            wantD = rightAmount >= 0
            wantA = not wantD
        end
    end

    sendMovementKeyState(Enum.KeyCode.W, wantW)
    sendMovementKeyState(Enum.KeyCode.S, wantS)
    sendMovementKeyState(Enum.KeyCode.A, wantA)
    sendMovementKeyState(Enum.KeyCode.D, wantD)

    return true, distance
end

local function triggerGameInputAction(contextName, actionName, temporaryKey)
    local context, action, binding = findGameInputAction(
        contextName,
        actionName,
        false
    )

    if not action then
        context, action, binding = findGameInputAction(
            contextName,
            actionName,
            true
        )
    end

    if not context or not action then
        return false, (
            "InputAction %s/%s not found"
        ):format(tostring(contextName), tostring(actionName))
    end

    if not binding then
        return false, (
            "KeyboardBinding missing for %s/%s"
        ):format(tostring(contextName), tostring(actionName))
    end

    local oldKey
    local oldEnabled

    local prepared, prepError = pcall(function()
        oldKey = binding.KeyCode
        oldEnabled = context.Enabled

        -- The game's own state normally enables these contexts. Temporarily
        -- enabling it here only affects local input routing; no remote is fired.
        context.Enabled = true
        binding.KeyCode = temporaryKey
    end)

    if not prepared then
        return false, "could not prepare InputBinding: " .. tostring(prepError)
    end

    task.wait()
    local sent, sendError = sendKeyCode(temporaryKey)
    task.wait()

    -- Restore the exact binding/state the game had before our synthetic input.
    pcall(function()
        binding.KeyCode = oldKey
        context.Enabled = oldEnabled
    end)

    if not sent then
        return false, sendError
    end

    return true
end

local function startKickThroughInputAction()
    -- GameHandler.InitKeybinds creates:
    --   canKick -> startKicking
    -- and OnCanKick connects startKicking.Pressed to the exact same
    -- PressedStart() function used by HUD.KickButton.Activated.
    return triggerGameInputAction(
        "canKick",
        "startKicking",
        Enum.KeyCode.F6
    )
end

local function finishKickThroughInputAction()
    -- During the real minigame GameHandler.OnInMinigame connects:
    --   Kick -> kick -> Pressed
    -- Its callback reads KickMinigameUI.Scale, calls End(scale), then Kick(scale).
    return triggerGameInputAction(
        "Kick",
        "kick",
        Enum.KeyCode.F7
    )
end

-- Pre-cache both native actions while the farm is doing tutorial/training work,
-- so arriving at the KICK zone does not pay the first descendant-scan cost.
task.spawn(function()
    task.wait(0.15)
    pcall(function()
        findGameInputAction("canKick", "startKicking", true)
        findGameInputAction("Kick", "kick", true)
    end)
end)

local function sendMouseClick(x, y)
    x = math.floor(x or 1)
    y = math.floor(y or 1)

    -- Prefer VirtualInputManager because it receives the exact coordinates.
    -- mouse1click() by itself only clicks the executor's CURRENT mouse position.
    local okService, vim = pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if okService and vim then
        local ok = pcall(function()
            vim:SendMouseMoveEvent(x, y, game)
            task.wait()
            vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.025)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        if ok then
            return true
        end
    end

    -- Executor fallback: move the mouse onto the requested GUI position first.
    if type(mousemoveabs) == "function" then
        local moved = pcall(mousemoveabs, x, y)
        if moved then
            task.wait()
            if type(mouse1click) == "function" then
                local ok = pcall(mouse1click)
                if ok then
                    return true
                end
            end

            if type(mouse1press) == "function" and type(mouse1release) == "function" then
                local ok = pcall(mouse1press)
                task.wait(0.025)
                pcall(mouse1release)
                if ok then
                    return true
                end
            end
        end
    end

    -- Last fallback for environments without an absolute mouse move helper.
    if type(mouse1click) == "function" then
        return pcall(mouse1click)
    end

    return false
end


local function pressNormalKickInput()
    -- GameHandler.InitKeybinds explicitly binds Kick/kick.KeyboardBinding to
    -- MouseLeftButton. During the minigame ANY normal left click therefore
    -- reaches the exact OnInMinigame -> v2.Pressed callback.
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local x = math.floor(viewport.X * 0.5)
    local y = math.floor(viewport.Y * 0.5)

    return sendMouseClick(x, y)
end

local function fireGuiConnections(signal)
    if type(getconnections) ~= "function" then
        return false
    end

    local ok, connections = pcall(getconnections, signal)
    if not ok or type(connections) ~= "table" then
        return false
    end

    local fired = false
    for _, connection in ipairs(connections) do
        if connection then
            local didFire = false

            if type(connection.Fire) == "function" then
                didFire = pcall(function()
                    connection:Fire()
                end)
            elseif type(connection.Function) == "function" then
                didFire = pcall(connection.Function)
            end

            fired = fired or didFire
        end
    end

    return fired
end

local function setFastFarmKickPower()
    local power = math.max(0, currentKickPower())
    local percent, targetDistance, rarity, maxDistance =
        fastFarmKickTarget(power)

    Runtime.TargetKickPercent = percent
    Runtime.TargetKickDistance = targetDistance
    Runtime.TargetKickRarity = rarity
    Runtime.MaxPowerDistance = maxDistance

    local frames = findFrames()
    local frame = frames and frames:FindFirstChild("SetKickPower")
    local powerFrame = frame and frame:FindFirstChild("PowerFrame")
    local textBox = powerFrame and powerFrame:FindFirstChild("TextBox")

    if not textBox or not textBox:IsA("TextBox") then
        Runtime.ExtraState = "Fast kick target unavailable • using current power setting"
        return false
    end

    local desiredPower = math.max(
        1,
        math.floor(power * percent + 0.5)
    )

    textBox.Text = tostring(desiredPower)

    local fired = false

    if type(firesignal) == "function" then
        fired = pcall(function()
            firesignal(textBox.FocusLost, true)
        end)
    end

    if not fired then
        fired = fireGuiConnections(textBox.FocusLost)
    end

    Runtime.LastKickPowerUiSetAt = os.clock()

    if fired then
        Runtime.ExtraState = (
            "Fast target %s • %.0f studs • %.0f%% power"
        ):format(
            tostring(rarity),
            targetDistance,
            percent * 100
        )
    end

    return fired
end

local function physicalClickGuiButton(button)
    local center = button.AbsolutePosition + button.AbsoluteSize * 0.5

    -- First use the exact AbsolutePosition reported by Roblox.
    if sendMouseClick(center.X, center.Y) then
        return true
    end

    -- Some environments use full-screen coordinates while a normal ScreenGui
    -- is offset by the Roblox top inset. Try that coordinate form only once.
    local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
    if screenGui and not screenGui.IgnoreGuiInset then
        local topLeftInset = select(1, GuiService:GetGuiInset())
        if topLeftInset then
            return sendMouseClick(
                center.X + topLeftInset.X,
                center.Y + topLeftInset.Y
            )
        end
    end

    return false
end

local function clickGuiButton(button)
    if not button or not button:IsA("GuiButton") then
        return false
    end

    if not button.Visible or button.AbsoluteSize.X <= 1 or button.AbsoluteSize.Y <= 1 then
        return false
    end

    -- Only use normal GUI activation paths. No KickEvent/GameHandler shortcut.
    -- Try the same Activated signal the game's client listens to.
    local usedSignal = false

    if type(firesignal) == "function" then
        usedSignal = pcall(function()
            firesignal(button.Activated)
        end)
    end

    if not usedSignal then
        usedSignal = fireGuiConnections(button.Activated)
    end

    if usedSignal then
        return true
    end

    -- No GuiService/controller selection fallback in v1.8; that only produced
    -- the temporary blue selection outline in this executor.
    return physicalClickGuiButton(button)
end

local function kickMinigameGui()
    return PlayerGui:FindFirstChild("KickMinigame")
end

local function minigameActive()
    local gui = kickMinigameGui()
    return gui ~= nil and gui.Enabled == true
end

Runtime.KickErrorVisible = function()
    local ok, descendants =
        pcall(PlayerGui.GetDescendants, PlayerGui)

    if not ok or type(descendants) ~= "table" then
        return false
    end

    for _, object in ipairs(descendants) do
        if (object:IsA("TextLabel")
            or object:IsA("TextButton"))
            and object.Visible
        then
            local value = tostring(object.Text or ""):lower()
            local isKickError =
                value:find("error occured while kicking", 1, true)
                or value:find("error occurred while kicking", 1, true)

            if isKickError and value:find("try again", 1, true) then
                return true
            end
        end
    end

    return false
end

Runtime.KickServerReady = function(button)
    if not button
        or not button:IsA("GuiButton")
        or not button.Visible
    then
        return false
    end

    if minigameActive() then
        return false
    end

    if LocalPlayer:GetAttribute("InGame") == true then
        return false
    end

    if LocalPlayer:GetAttribute("RoundDebounce")
        or LocalPlayer:GetAttribute("KickDebounced")
    then
        return false
    end

    local endedAt = tonumber(Runtime.LastKickEndedAt) or 0

    if endedAt > 0 and os.clock() - endedAt < 0.55 then
        return false
    end

    if Runtime.KickErrorVisible() then
        return false
    end

    local root = rootPart()
    local hum = humanoid()

    if not root or root.Anchored or not hum or hum.Health <= 0 then
        return false
    end

    return true
end

local function finishKickMinigame()
    local gui = kickMinigameGui()
    if not (gui and gui.Enabled == true) then
        return false, "KickMinigame GUI is not active"
    end

    local bar = gui:FindFirstChild("Bar")
    local moving = bar and bar:FindFirstChild("MovingBar")
    if not moving then
        return false, "KickMinigame MovingBar missing"
    end

    local message = gui:FindFirstChild("Message")
    local startedAt = os.clock()
    local deadline = startedAt + 6
    local previousScale = tonumber(moving.Size.Y.Scale) or 0
    local lastAttemptAt = 0
    local attempts = 0

    setState(Config.PerfectKick
        and "Waiting for Perfect (0.97+)"
        or "Waiting to kick")

    while Runtime.Alive and gui.Enabled and os.clock() < deadline do
        local scale = math.clamp(tonumber(moving.Size.Y.Scale) or 0, 0, 1)
        local rising = scale >= previousScale

        local shouldPress
        if Config.PerfectKick then
            -- CustomKick:GetKickFromScale uses 0.97 as the exact Perfect cutoff.
            -- Fire immediately while rising; do NOT add the old 55 ms delay.
            shouldPress = rising and scale >= 0.97
        else
            shouldPress = (os.clock() - startedAt) >= 0.32
        end

        if shouldPress and (os.clock() - lastAttemptAt) >= 0.18 then
            attempts = attempts + 1
            lastAttemptAt = os.clock()
            setState(("Kicking at %.3f"):format(scale))

            -- Preferred finish: a normal MouseLeftButton input. This is the
            -- game's stock Kick/kick binding and avoids the F7 rebinding issue.
            pressNormalKickInput()

            -- A successful input immediately calls End(scale) and GameHandler:Kick.
            local confirmDeadline = os.clock() + 0.55
            while Runtime.Alive and os.clock() < confirmDeadline do
                if Runtime.RoundActive or Runtime.SawKickPhase2 then
                    return true
                end

                if Runtime.KickErrorVisible() then
                    return false, "native kick rejected"
                end

                if message and tostring(message.Text or "") ~= "" then
                    return true
                end

                if not gui.Enabled then
                    return true
                end

                task.wait(0.015)
            end

            -- Compatibility fallback: use the game's InputAction binding once.
            -- This is still normal local input routing, not a kick remote.
            if attempts == 1 and gui.Enabled then
                finishKickThroughInputAction()

                local secondConfirm = os.clock() + 0.45
                while Runtime.Alive and os.clock() < secondConfirm do
                    if Runtime.KickErrorVisible() then
                        return false, "native kick rejected"
                    end

                    if Runtime.RoundActive
                        or Runtime.SawKickPhase2
                        or (message and tostring(message.Text or "") ~= "")
                        or not gui.Enabled
                    then
                        return true
                    end

                    task.wait(0.015)
                end
            end

            if not Config.PerfectKick then
                break
            end
        end

        previousScale = scale
        task.wait()
    end

    return false, ("kick input did not register (%d attempts)"):format(attempts)
end

local function roundActive()
    if Runtime.RoundActive then
        return true
    end

    if minigameActive() then
        return true
    end

    if LocalPlayer:GetAttribute("InGame") == true then
        -- InGame can remain true briefly after the reward has already returned.
        -- Once KickEventEnded has fired and neither the minigame nor RUN phase is
        -- active, do not let that stale attribute freeze the next farm cycle.
        local endedAt =
            tonumber(Runtime.LastKickEndedAt) or 0

        local endedRecently =
            endedAt > 0
            and os.clock() - endedAt <= 1.25

        if endedRecently then
            return false
        end

        if Runtime.SawKickPhase2 then
            return true
        end

        -- Before the first observed KickEventEnded, InGame is still useful as
        -- a fallback signal for the native kick lifecycle.
        if endedAt <= 0 then
            return true
        end
    end

    return false
end

local shouldDismissCurrentKickReward

local function turboCollectKickReward()
    if not Config.TurboCollect then
        stopAutomatedWalk()
        return false
    end

    local areas = workspace:FindFirstChild("Areas")
    local kickReady = areas and areas:FindFirstChild("KickReady")

    if not kickReady or not kickReady:IsA("BasePart") then
        stopAutomatedWalk()
        setState("RUN return: KickReady missing")
        return false
    end

    local root = rootPart()
    local hum = humanoid()
    if not root or not hum then
        stopAutomatedWalk()
        setState("RUN!! Waiting for character")
        return false
    end

    -- Exact inspected AutoController architecture:
    -- PlayerModule controls are disabled first, then AutoClass.Update() is called
    -- from RunService.PreRender. AutoClass.Run calls Humanoid:MoveTo() EVERY frame.
    local controlsDisabled = disablePlayerControls()

    local runWasSeen = runPhaseVisible(true)
    local startEndedAt = Runtime.LastKickEndedAt
    local deadline = os.clock() + 45

    local lastPosition = root.Position
    local lastProgressAt = os.clock()
    local lastJumpAt = 0
    local bestDistance = math.huge
    local latestDistance = math.huge
    local movementFrames = 0
    local fallbackFrames = 0
    local frameError = nil

    local moveConnection
    moveConnection = RunService.PreRender:Connect(function()
        if not Runtime.Alive or not Config.Master then
            return
        end

        local currentRoot = rootPart()
        local currentHum = humanoid()

        if not currentRoot
            or not currentHum
            or currentHum.Health <= 0
            or currentRoot.Anchored
        then
            return
        end

        -- Exact safe return used by the game's own AutoClass.
        -- Never divert the transformed brainrot toward the water.
        local target = kickReady.Position

        local flatDelta = Vector3.new(
            target.X - currentRoot.Position.X,
            0,
            target.Z - currentRoot.Position.Z
        )

        latestDistance = flatDelta.Magnitude

        -- This is the exact command used by AutoClass.Run.
        local okMove, err = pcall(function()
            currentHum:MoveTo(target)
        end)

        if not okMove then
            frameError = tostring(err)
            return
        end

        movementFrames = movementFrames + 1

        -- In executors where stock PlayerModule cannot be required/disabled,
        -- issue the equivalent Humanoid movement direction on the SAME render
        -- frame as a compatibility fallback. This still respects WalkSpeed and
        -- does not teleport or alter velocity.
        if not controlsDisabled and flatDelta.Magnitude > 0.1 then
            pcall(function()
                currentHum:Move(flatDelta.Unit, false)
            end)
            fallbackFrames = fallbackFrames + 1
        end
    end)

    local function cleanupRunMovement()
        if moveConnection then
            pcall(function()
                moveConnection:Disconnect()
            end)
            moveConnection = nil
        end

        stopAutomatedWalk()
        unequipAndUnanchor()
    end

    while Runtime.Alive and Config.Master and os.clock() < deadline do
        root = rootPart()
        hum = humanoid()

        if not root or not hum or hum.Health <= 0 then
            cleanupRunMovement()
            setState("RUN!! Character unavailable")
            return false
        end

        local runNow = runPhaseVisible()
        if runNow then
            runWasSeen = true
            Runtime.PendingRewardPlacement = true
        end

        if root.Anchored then
            setState(runNow
                and "RUN!! Waiting for movement unlock"
                or "Reward cinematic • waiting for RUN!!")
            task.wait(0.025)
        else
            local statusTarget = kickReady.Position

            local currentDistance = Vector3.new(
                root.Position.X - statusTarget.X,
                0,
                root.Position.Z - statusTarget.Z
            ).Magnitude

            latestDistance = currentDistance

            if currentDistance < bestDistance - 0.25 then
                bestDistance = currentDistance
                lastProgressAt = os.clock()
                lastPosition = root.Position
            end

            local endedByRemote = Runtime.LastKickEndedAt > startEndedAt
            local endedByUI = runWasSeen and not runNow

            if endedByRemote or endedByUI then
                Runtime.RoundActive = false
                Runtime.SawKickPhase2 = false
                Runtime.RewardRoundEndedAt = math.max(
                    Runtime.RewardRoundEndedAt or 0,
                    os.clock()
                )

                Runtime.DismissCurrentReward = false
                cleanupRunMovement()

                -- Give Roblox one frame to publish the normal character state
                -- before placement/training takes ownership of movement.
                task.wait()
                return true
            end

            if frameError then
                cleanupRunMovement()
                setState("RUN movement error: " .. frameError)
                return false
            end

            if runWasSeen then
                local modeText = controlsDisabled
                    and "native PreRender MoveTo"
                    or "PreRender MoveTo + Move fallback"

                setState(
                    ("RUN!! Returning to safe side • %.0f studs • %d frames")
                        :format(currentDistance, movementFrames)
                )
            else
                setState("Reward landed • waiting for Tsunami/RUN state")
            end

            -- If the character still has not moved after 0.75 s of PreRender calls,
            -- refresh PlayerModule controls once and keep the every-frame driver alive.
            if runWasSeen and os.clock() - lastProgressAt > 0.75 then
                if not controlsDisabled then
                    PlayerControls.Object = nil
                    controlsDisabled = disablePlayerControls()
                end

                pcall(function()
                    hum.Sit = false
                    hum.PlatformStand = false
                    if hum:GetState() == Enum.HumanoidStateType.Seated then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end)

                if os.clock() - lastJumpAt > 0.70 then
                    lastJumpAt = os.clock()
                    nudgeJump("RUN!! stuck • jumping")
                end

                lastProgressAt = os.clock()
            end

            task.wait(0.025)
        end
    end

    cleanupRunMovement()
    setState(
        ("RUN return timed out • %.0f studs • %d MoveTo frames / %d fallback")
            :format(latestDistance, movementFrames, fallbackFrames)
    )
    return false
end


local function snapshotEntityToolInstances()
    local snapshot = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = character()

    local function scan(container)
        if not container then
            return
        end

        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and hasTag(child, "EntityTool") then
                snapshot[child] = true
            end
        end
    end

    scan(backpack)
    scan(char)
    return snapshot
end

local captureActualKickDistance

local function performKick()
    if not Config.AutoKick or Runtime.Busy or not Runtime.Alive then
        return false
    end

    if roundActive() then
        turboCollectKickReward()
        return false
    end

    if not ensureKickZone() then
        setState("Waiting for KickReady")
        return false
    end

    local hud = findHUD()
    local button = hud and hud:FindFirstChild("KickButton")
    if not button or not button:IsA("GuiButton") then
        setState("Waiting for KICK button")
        return false
    end

    if not button.Visible then
        setState("Waiting for KICK button reset")
        return false
    end

    if not Runtime.KickServerReady(button) then
        if Runtime.KickErrorVisible() then
            Runtime.LastKickAttemptAt = os.clock()
        end
        return false
    end

    -- Prevent duplicate presses if the UI/state takes time to react.
    local now = os.clock()
    local minAttemptGap = math.max(0.20, math.min(1.5, tonumber(Config.KickDelay) or 0.50))
    if now - Runtime.LastKickAttemptAt < minAttemptGap then
        setState("Waiting before next KICK press")
        return false
    end

    Runtime.Busy = true
    Runtime.SawKickPhase2 = false
    Runtime.LastKickAttemptAt = now
    Runtime.CycleStartedAt = now
    Runtime.KickToolSnapshot = snapshotEntityToolInstances()
    Runtime.LastCollectedPayload = nil
    Runtime.LastCollectedAt = 0
    Runtime.LastKickSucceeded = nil
    Runtime.PostKickPhase = "StartingKick"
    Runtime.DistanceCapturedThisKick = false
    Runtime.LastKickPowerAtLaunch = currentKickPower()
    local kickStartedAt = now

    -- Record the EXACT point this kick starts from. After the lucky block lands,
    -- the game transforms/replaces our character, so only keep plain world data.
    local kickRoot = rootPart()
    if kickRoot then
        Runtime.KickOriginPosition = kickRoot.Position
        Runtime.KickOriginCFrame = kickRoot.CFrame
        Runtime.KickOriginCapturedAt = now
    end

    -- Apply the selected distance using the game's normal SetKickPower state.
    -- Max Distance writes the full current Kick Power every single kick.
    setFastFarmKickPower()

    if tostring(Config.FarmKickMode or "Max Distance") == "Max Distance" then
        Runtime.TargetKickPercent = 1
        Runtime.ExtraState = "Kick target • MAX DISTANCE • 100% power"
    end

    -- Deterministic v2.0 path: trigger the game's own
    -- canKick/startKicking InputAction. Its Pressed signal is connected to the
    -- SAME PressedStart() callback as the visible KICK button.
    if not minigameActive() then
        setState("Triggering game startKicking action")

        local started, startReason = startKickThroughInputAction()
        if not started then
            Runtime.Busy = false
            setState("Start action failed: " .. tostring(startReason))
            return false
        end

        local startDeadline = os.clock() + 2.5

        while Runtime.Alive and os.clock() < startDeadline do
            if minigameActive() or Runtime.KickErrorVisible() then
                break
            end
            task.wait(0.04)
        end
    end

    if not minigameActive() then
        Runtime.Busy = false

        if Runtime.KickErrorVisible() then
            Runtime.LastKickSucceeded = false
            Runtime.RoundActive = false
            Runtime.SawKickPhase2 = false
            Runtime.LastKickAttemptAt = os.clock()
            task.wait(0.85)
        end

        return false
    end

    local finished, finishReason = finishKickMinigame()

    if not finished then
        Runtime.Busy = false

        if Runtime.KickErrorVisible()
            or tostring(finishReason):lower():find("rejected", 1, true)
        then
            Runtime.LastKickSucceeded = false
            Runtime.RoundActive = false
            Runtime.SawKickPhase2 = false
            Runtime.LastKickAttemptAt = os.clock()
            task.wait(0.85)
        end

        return false
    end

    -- GameHandler now enters the long kick/result lifecycle. The lucky block can
    -- fly for a while, then kickPhase2 provides the rolled reward(s), then the
    -- client transforms us into those brainrot(s), reveals them, raises the wave,
    -- enables HUD.Run and finally enters Status="Tsunami".
    Runtime.Busy = false
    Runtime.PostKickPhase = "BlockFlying"

    local lifecycleDeadline = os.clock() + 120
    local sawTransform = false
    local sawRun = false

    while Runtime.Alive and Config.Master and os.clock() < lifecycleDeadline do
        if Runtime.LastKickEndedAt > kickStartedAt then
            break
        end

        if Runtime.SawKickPhase2 then
            Runtime.PendingRewardPlacement = true
            Runtime.PostKickPhase = "RewardRolled"
        end

        local transformed = transformedRewardModel()
        if transformed then
            sawTransform = true
            Runtime.PendingRewardPlacement = true
            Runtime.PostKickPhase = "Transformed"
        end

        if runPhaseVisible(true) then
            sawRun = true
            Runtime.PendingRewardPlacement = true
            Runtime.PostKickPhase = "Run"
            captureActualKickDistance()
            Runtime.DismissCurrentReward = false
            break
        end

        if sawTransform then
            setState("Became " .. describeRewardNames() .. " • waiting for RUN!!")
        elseif Runtime.SawKickPhase2 then
            setState("Rolled " .. describeRewardNames() .. " • waiting for landing/reveal")
        else
            setState("Lucky block flying • waiting for result roll")
        end

        task.wait(0.05)
    end

    local returnCompleted = false

    if sawRun or runPhaseVisible(true) then
        Runtime.PostKickPhase = "Run"
        returnCompleted = turboCollectKickReward()
    elseif Runtime.LastKickEndedAt <= kickStartedAt then
        setState("Post-kick lifecycle timed out before RUN!!")
    end

    -- KickCollect is sent by the game's own CollectZone PreRender checker.
    -- KickEventEnded cleans the GameHandler Trove, reverts the visual brainrot,
    -- disables RUN UI and restores the normal character visuals.
    if returnCompleted then
        Runtime.PostKickPhase = "WaitingForTool"
    end

    if Runtime.PendingRewardPlacement and placeFreshKickReward then
        setState(
            returnCompleted
                and "Returned safely • waiting for collected reward"
                or "Checking collected reward"
        )
        placeFreshKickReward()
    end

    -- Do not start another kick merely because a timer expired. Wait for the
    -- game's own KICK button to become visible again and remain stable briefly.
    local resetDeadline = os.clock() + 15
    local visibleSince = nil

    while Runtime.Alive and Config.Master and os.clock() < resetDeadline do
        hud = findHUD()
        button = hud and hud:FindFirstChild("KickButton")

        local ready = Runtime.KickServerReady(button)

        if ready then
            visibleSince = visibleSince or os.clock()

            if os.clock() - visibleSince >= 0.40 then
                Runtime.LastKickButtonReturnAt = os.clock()
                break
            end
        else
            visibleSince = nil
        end

        task.wait(0.10)
    end

    task.wait(
        math.max(
            0.25,
            tonumber(Config.KickDelay) or 0.50
        )
    )

    return true
end

-- ============================================================================
-- Inventory / plot helpers
-- ============================================================================

local function allTools()
    local result = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = character()

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(result, item)
            end
        end
    end
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(result, item)
            end
        end
    end
    return result
end

local function equipTool(tool)
    if not tool or not waitAlive(5) then
        return false
    end
    if tool.Parent == character() then
        return true
    end

    local hum = humanoid()
    local ok = pcall(function()
        hum:UnequipTools()
        task.wait(0.05)
        hum:EquipTool(tool)
    end)
    if ok then
        task.wait(0.15)
    end
    return ok and tool.Parent == character()
end

local function sortedInventoryBrainrotTools()
    local result = {}

    for _, tool in ipairs(allTools()) do
        if tool:IsA("Tool")
            and tool.Parent
            and hasTag(tool, "EntityTool")
        then
            local level =
                tool:GetAttribute("Level") or 1

            local mutation =
                tool:GetAttribute("Mutation")

            local tier, quality, current =
                Runtime.BrainrotQualityScore(
                    tool.Name,
                    level,
                    mutation
                )

            if tier > 0 or quality > 0 then
                table.insert(result, {
                    Tool = tool,
                    Tier = tier,
                    Quality = quality,
                    Value = current,
                    Level = level,
                    Mutation = mutation,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        if a.Tier ~= b.Tier then
            return a.Tier > b.Tier
        end

        if a.Quality ~= b.Quality then
            return a.Quality > b.Quality
        end

        if a.Value ~= b.Value then
            return a.Value > b.Value
        end

        if a.Level ~= b.Level then
            return a.Level > b.Level
        end

        return tostring(a.Tool.Name) < tostring(b.Tool.Name)
    end)

    return result
end

local function bestBrainrotTool()
    local sorted = sortedInventoryBrainrotTools()
    local best = sorted[1]

    if not best then
        return nil, -1, -math.huge
    end

    return best.Tool, best.Tier, best.Quality, best.Value
end


local function freshEntityToolsSinceKick()
    local result = {}
    local snapshot = Runtime.KickToolSnapshot or {}

    for _, tool in ipairs(allTools()) do
        if hasTag(tool, "EntityTool") and not snapshot[tool] then
            table.insert(result, tool)
        end
    end

    table.sort(result, function(a, b)
        local at, aq, ac =
            Runtime.BrainrotQualityScore(
                a.Name,
                a:GetAttribute("Level") or 1,
                a:GetAttribute("Mutation")
            )

        local bt, bq, bc =
            Runtime.BrainrotQualityScore(
                b.Name,
                b:GetAttribute("Level") or 1,
                b:GetAttribute("Mutation")
            )

        if at ~= bt then
            return at > bt
        end

        if aq ~= bq then
            return aq > bq
        end

        return ac > bc
    end)

    return result
end

local function rewardNamedEntityTool()
    local wanted = {}

    local function addPayload(payload)
        for _, name in ipairs(rewardNamesFromPayload(payload)) do
            wanted[name] = true
        end
    end

    addPayload(Runtime.LastRewardNames)
    addPayload(Runtime.LastCollectedPayload)

    if next(wanted) == nil then
        return nil
    end

    for _, tool in ipairs(allTools()) do
        if hasTag(tool, "EntityTool") and wanted[tool.Name] then
            return tool
        end
    end

    return nil
end

local function localPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:GetAttribute("Owner")
        if owner == LocalPlayer.Name or owner == LocalPlayer.DisplayName then
            return plot
        end
    end

    -- Fallback: if the server only has one owned plot and its label matches us.
    for _, plot in ipairs(plots:GetChildren()) do
        for _, descendant in ipairs(plot:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text == LocalPlayer.Name then
                return plot
            end
        end
    end
    return nil
end

local function slotPlacedPart(slot)
    if not slot then
        return nil
    end
    for _, child in ipairs(slot:GetChildren()) do
        if child:GetAttribute("ID") ~= nil then
            return child
        end
    end
    for _, child in ipairs(slot:GetDescendants()) do
        if child:GetAttribute("ID") ~= nil then
            return child
        end
    end
    return nil
end

local function plotSlots()
    local plot = localPlot()
    local slots = plot and plot:FindFirstChild("Slots")
    local result = {}

    if not slots then
        return result
    end

    -- Exact BaseUpgradesServiceClient model:
    -- 10 starting slots + AddedSlots, max +20.
    local added = math.clamp(
        math.floor(tonumber(Runtime.AddedSlots) or 0),
        0,
        20
    )
    local capacity = 10 + added

    for _, slot in ipairs(slots:GetChildren()) do
        local slotName = tostring(slot.Name)
        local indexText = slotName:match("^Slot[%s_%-]*(%d+)$")
            or slotName:match("(%d+)$")
        local index = indexText and tonumber(indexText) or nil

        -- Never treat locked/future visual slots as usable empty slots.
        if index and index >= 1 and index <= capacity then
            table.insert(result, {
                Index = index,
                Slot = slot,
                Part = slotPlacedPart(slot),
            })
        end
    end

    table.sort(result, function(a, b)
        return a.Index < b.Index
    end)

    return result
end

local function plotSlotByIndex(index)
    for _, entry in ipairs(plotSlots()) do
        if entry.Index == index then
            return entry
        end
    end
    return nil
end

local function emptySlotIndex(preferred)
    local slots = plotSlots()
    if preferred then
        for _, entry in ipairs(slots) do
            if entry.Index == preferred and not entry.Part then
                return preferred
            end
        end
    end
    for _, entry in ipairs(slots) do
        if not entry.Part then
            return entry.Index
        end
    end
    return nil
end

local function worstPlacedBrainrot()
    local worst = nil

    for _, entry in ipairs(plotSlots()) do
        local part = entry.Part
        local id = part and part:GetAttribute("ID")

        if id and BrainrotData[id] then
            local tier, quality, current =
                Runtime.BrainrotQualityScore(
                    id,
                    part:GetAttribute("Level") or 1,
                    part:GetAttribute("Mutation")
                )

            if not worst
                or tier < worst.Tier
                or (
                    tier == worst.Tier
                    and quality < worst.Quality
                )
                or (
                    tier == worst.Tier
                    and quality == worst.Quality
                    and current < worst.Value
                )
            then
                worst = {
                    Index = entry.Index,
                    Part = part,
                    ID = id,
                    Tier = tier,
                    Quality = quality,
                    Value = current,
                    Level = part:GetAttribute("Level") or 1,
                    Mutation = part:GetAttribute("Mutation"),
                }
            end
        end
    end

    return worst
end

shouldDismissCurrentKickReward = function()
    -- Disabled in v4.5.3.
    -- Collect safely first; selective Auto Sell handles weak rewards afterward.
    return false
end

local equippedWeightTool

local SELLER_CFRAME =
    CFrame.new(134.125, 0.125, 83.866)
    * CFrame.Angles(0, -1.5707963267948966, 0)

local function findLiveSellerNPC()
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then
        return nil
    end

    for _, object in ipairs(npcs:GetChildren()) do
        if object:IsA("Model") then
            local configuredName = object:GetAttribute("Name")

            if object.Name == "Timmy"
                or tostring(configuredName or "") == "Timmy"
            then
                return object
            end
        end
    end

    for _, object in ipairs(npcs:GetDescendants()) do
        if object:IsA("Model") then
            local configuredName = object:GetAttribute("Name")

            if object.Name == "Timmy"
                or tostring(configuredName or "") == "Timmy"
            then
                return object
            end
        end
    end

    return nil
end

local function sellerPromptAndPart()
    local seller = findLiveSellerNPC()
    if not seller then
        return nil, nil, nil
    end

    local prompt = seller:FindFirstChildWhichIsA(
        "ProximityPrompt",
        true
    )

    local part

    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
        part = prompt.Parent
    end

    if not part then
        part = seller:FindFirstChild("Hitbox", true)
    end

    if not (part and part:IsA("BasePart")) then
        part = seller:FindFirstChild("HumanoidRootPart")
    end

    if not (part and part:IsA("BasePart")) then
        part = seller.PrimaryPart
    end

    return seller, prompt, part
end

local function sellerDistance()
    local root = rootPart()
    local seller, prompt, part = sellerPromptAndPart()

    if not root then
        return math.huge, seller, prompt, part
    end

    local position

    if part then
        position = part.Position
    elseif seller then
        local ok, pivot = pcall(seller.GetPivot, seller)
        if ok and typeof(pivot) == "CFrame" then
            position = pivot.Position
        end
    end

    if not position then
        return math.huge, seller, prompt, part
    end

    return (root.Position - position).Magnitude,
        seller,
        prompt,
        part
end

local function moveIntoSellerRange(forceNear)
    local root = rootPart()
    local hum = humanoid()

    if not root or not hum or root.Anchored then
        Runtime.LastSellReason = "seller move: character unavailable"
        return false
    end

    -- First use the game's exact TeleportController.TeleportToSeller CFrame.
    pcall(function()
        root.CFrame =
            SELLER_CFRAME
            * CFrame.new(0, hum.HipHeight or 0, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    task.wait(0.10)

    local distance, seller, prompt, part = sellerDistance()
    Runtime.LastSellDistance = distance

    local allowed = 12

    if prompt then
        allowed = math.max(
            3,
            math.min(
                18,
                (tonumber(prompt.MaxActivationDistance) or 10) - 1
            )
        )
    end

    if not forceNear and distance <= allowed then
        return true
    end

    -- If the game's fixed teleport ended outside the live prompt range, move
    -- beside the actual Timmy prompt/Hitbox rather than trusting stale coords.
    if part then
        root = rootPart()
        hum = humanoid()

        if not root or not hum then
            return false
        end

        local target = part.Position
        local flatAway = Vector3.new(
            root.Position.X - target.X,
            0,
            root.Position.Z - target.Z
        )

        if flatAway.Magnitude < 0.1 then
            flatAway = Vector3.new(1, 0, 0)
        end

        local standDistance = math.max(
            2.5,
            math.min(4, allowed * 0.45)
        )

        local standPosition =
            target + flatAway.Unit * standDistance

        -- Keep the current/root floor height when possible; this prevents
        -- teleporting into Timmy's body or below the booth floor.
        standPosition = Vector3.new(
            standPosition.X,
            root.Position.Y,
            standPosition.Z
        )

        pcall(function()
            root.CFrame = CFrame.lookAt(
                standPosition,
                Vector3.new(target.X, standPosition.Y, target.Z)
            )
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        task.wait(0.10)
    end

    distance = sellerDistance()
    Runtime.LastSellDistance = distance

    return distance <= math.max(allowed, 18)
end

local function triggerSellerPrompt()
    local seller, prompt = sellerPromptAndPart()

    if not seller or not prompt or not prompt.Enabled then
        return false
    end

    local distance = sellerDistance()
    local allowed = tonumber(prompt.MaxActivationDistance) or 10

    if distance > allowed + 1 then
        return false
    end

    local triggered = false

    if type(fireproximityprompt) == "function" then
        triggered = pcall(function()
            fireproximityprompt(prompt)
        end)
    end

    if not triggered then
        triggered = pcall(function()
            prompt:InputHoldBegin()
            task.wait(
                math.max(
                    0.03,
                    tonumber(prompt.HoldDuration) or 0
                ) + 0.03
            )
            prompt:InputHoldEnd()
        end)
    end

    if not triggered then
        local keyCode = prompt.KeyboardKeyCode
        if keyCode and keyCode ~= Enum.KeyCode.Unknown then
            local ok = sendKeyCode(keyCode)
            triggered = ok == true
        end
    end

    if triggered then
        Runtime.LastSellerPromptAt = os.clock()
    end

    return triggered
end

local function exactToolEquipped(tool)
    local char = character()

    if not char or not tool or tool.Parent ~= char then
        return false
    end

    local held = char:FindFirstChildOfClass("Tool")
    return held == tool
end

local function ensureSellerToolEquipped(tool, timeout)
    if not tool or not tool.Parent then
        return false
    end

    local hum = humanoid()
    if not hum then
        return false
    end

    pcall(function()
        hum:UnequipTools()
    end)
    task.wait(0.06)

    if not tool.Parent then
        return false
    end

    pcall(function()
        hum:EquipTool(tool)
    end)

    local deadline = os.clock() + (timeout or 1.2)

    while Runtime.Alive and os.clock() < deadline do
        if exactToolEquipped(tool) then
            return true
        end
        task.wait(0.025)
    end

    return exactToolEquipped(tool)
end

local function waitForSoldTool(tool, timeout)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = character()
    local deadline = os.clock() + (timeout or 1.2)

    while Runtime.Alive and os.clock() < deadline do
        if not tool
            or not tool.Parent
            or (
                tool.Parent ~= backpack
                and tool.Parent ~= char
            )
        then
            return true
        end

        task.wait(0.025)
    end

    return not tool
        or not tool.Parent
        or (
            tool.Parent ~= backpack
            and tool.Parent ~= char
        )
end

local function schoolCraftProtectedTools(tools)
    local protected = {}

    if not Config.AutoSchoolCraft then
        return protected
    end

    local required = {}

    for _, recipe in ipairs(SchoolCraftRecipes) do
        for _, requirement in ipairs(recipe.Requirements or {}) do
            local name = requirement.Name
            local count = requirement.Count or 1

            required[name] = math.max(
                required[name] or 0,
                count
            )
        end
    end

    local byName = {}

    for _, tool in ipairs(tools) do
        if tool:IsA("Tool") and hasTag(tool, "EntityTool") then
            byName[tool.Name] = byName[tool.Name] or {}
            table.insert(byName[tool.Name], tool)
        end
    end

    for name, count in pairs(required) do
        local list = byName[name] or {}

        table.sort(list, function(a, b)
            local at, av = brainrotScore(
                a.Name,
                a:GetAttribute("Level") or 1,
                a:GetAttribute("Mutation")
            )
            local bt, bv = brainrotScore(
                b.Name,
                b:GetAttribute("Level") or 1,
                b:GetAttribute("Mutation")
            )

            if at ~= bt then
                return at < bt
            end

            return av < bv
        end)

        for i = 1, math.min(count, #list) do
            protected[list[i]] = true
        end
    end

    return protected
end

local function leftoverBrainrotsToSell()
    if not Config.AutoSellLeftovers
        or Runtime.PendingRewardPlacement
        or roundActive()
        or Runtime.Busy
    then
        return {}
    end

    if emptySlotIndex(nil) then
        return {}
    end

    local weakest = worstPlacedBrainrot()
    if not weakest then
        return {}
    end

    local tools = allTools()
    local protected = schoolCraftProtectedTools(tools)
    local result = {}

    for _, tool in ipairs(tools) do
        local data = BrainrotData[tool.Name]

        if tool:IsA("Tool")
            and tool.Parent
            and hasTag(tool, "EntityTool")
            and data
            and (data.CPS or data.Best)
            and not protected[tool]
        then
            local level =
                tool:GetAttribute("Level") or 1

            local mutation =
                tool:GetAttribute("Mutation")

            local tier, quality, current =
                Runtime.BrainrotQualityScore(
                    tool.Name,
                    level,
                    mutation
                )

            local improvesPlot =
                Runtime.BrainrotBeats(
                    tier,
                    quality,
                    current,
                    weakest.Tier,
                    weakest.Quality,
                    weakest.Value
                )

            if not improvesPlot then
                table.insert(result, {
                    Tool = tool,
                    Tier = tier,
                    Quality = quality,
                    Value = current,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        if a.Tier ~= b.Tier then
            return a.Tier < b.Tier
        end

        if a.Quality ~= b.Quality then
            return a.Quality < b.Quality
        end

        return a.Value < b.Value
    end)

    return result
end

Runtime.SellHeldBrainrot = function()
    if remoteFunction("B_Sell") then
        return invokeServer("B_Sell")
    end

    if remoteEvent("B_Sell") then
        local ok = fireServer("B_Sell")
        return ok, nil
    end

    Runtime.LastSellReason = "B_Sell remote not found"
    return false, nil
end

Runtime.InventoryEntityToolCount = function()
    local count = 0

    for _, tool in ipairs(allTools()) do
        if tool:IsA("Tool")
            and tool.Parent
            and hasTag(tool, "EntityTool")
        then
            count = count + 1
        end
    end

    return count
end

Runtime.GuiTextBlob = function(object)
    if not object then
        return ""
    end

    local pieces = {}

    if object:IsA("TextLabel")
        or object:IsA("TextButton")
        or object:IsA("TextBox")
    then
        table.insert(pieces, tostring(object.Text or ""))
    end

    local ok, descendants =
        pcall(object.GetDescendants, object)

    if ok and type(descendants) == "table" then
        for _, child in ipairs(descendants) do
            if child:IsA("TextLabel")
                or child:IsA("TextButton")
                or child:IsA("TextBox")
            then
                table.insert(
                    pieces,
                    tostring(child.Text or "")
                )
            end
        end
    end

    return table.concat(pieces, " "):lower()
end

Runtime.VisibleGuiButtons = function()
    local result = {}
    local ok, descendants =
        pcall(PlayerGui.GetDescendants, PlayerGui)

    if not ok or type(descendants) ~= "table" then
        return result
    end

    for _, object in ipairs(descendants) do
        if object:IsA("GuiButton")
            and guiObjectActuallyVisible(object)
            and object.AbsoluteSize.X > 2
            and object.AbsoluteSize.Y > 2
        then
            table.insert(result, object)
        end
    end

    return result
end

Runtime.FindSellAllButton = function()
    local best
    local bestScore = -1

    for _, button in ipairs(Runtime.VisibleGuiButtons()) do
        local blob = Runtime.GuiTextBlob(button)
        local score = 0

        if blob:find("sell all", 1, true) then
            score = score + 1000
        end

        if blob:find("brainrot", 1, true) then
            score = score + 250
        end

        if blob:find("sell", 1, true) then
            score = score + 80
        end

        if blob:find("all", 1, true) then
            score = score + 40
        end

        if score > bestScore and score >= 1000 then
            bestScore = score
            best = button
        end
    end

    return best
end

Runtime.SellerConfirmationContext = function(button)
    local node = button
    local depth = 0
    local pieces = {}

    while node
        and depth < 5
        and node ~= PlayerGui
    do
        table.insert(
            pieces,
            Runtime.GuiTextBlob(node)
        )

        node = node.Parent
        depth = depth + 1
    end

    return table.concat(pieces, " "):lower()
end

Runtime.FindSellAllConfirmButton = function()
    local best
    local bestScore = -1

    for _, button in ipairs(Runtime.VisibleGuiButtons()) do
        local blob = Runtime.GuiTextBlob(button)
        local context =
            Runtime.SellerConfirmationContext(button)

        local sellerContext =
            context:find("sell all", 1, true)
            or context:find("brainrot", 1, true)
            or context:find("are you sure", 1, true)
            or context:find("confirm", 1, true)

        if sellerContext then
            local score = 0

            if blob:find("confirm", 1, true) then
                score = score + 1000
            end

            if blob:find("yes", 1, true) then
                score = score + 900
            end

            if blob:find("sell all", 1, true) then
                score = score + 850
            end

            if blob:find("sell", 1, true) then
                score = score + 500
            end

            if blob:find("okay", 1, true)
                or blob:find("ok", 1, true)
            then
                score = score + 350
            end

            -- Explicitly avoid negative/cancel actions.
            if blob:find("cancel", 1, true)
                or blob:find("no", 1, true)
                or blob:find("back", 1, true)
            then
                score = score - 2000
            end

            if score > bestScore and score > 0 then
                bestScore = score
                best = button
            end
        end
    end

    return best
end

Runtime.WaitForSellerButton = function(finder, timeout)
    local deadline =
        os.clock() + math.max(0.25, tonumber(timeout) or 1.75)

    while Runtime.Alive and os.clock() < deadline do
        local button = finder()

        if button then
            return button
        end

        task.wait(0.025)
    end

    return nil
end

Runtime.TrySellAllUI = function(expectedLeftovers)

    local beforeCount =
        Runtime.InventoryEntityToolCount()

    if beforeCount <= 0 then
        Runtime.LastSellAllStage = "inventory already empty"
        return true, 0
    end

    -- Sell All is only safe when EVERY inventory EntityTool is already classified
    -- as a leftover. If not, the existing selective seller remains the fallback.
    if tonumber(expectedLeftovers) ~= beforeCount then
        Runtime.LastSellAllStage =
            ("unsafe for Sell All • leftovers %d / inventory %d")
                :format(
                    tonumber(expectedLeftovers) or 0,
                    beforeCount
                )

        return false, 0
    end

    if Config.AutoSchoolCraft then
        Runtime.LastSellAllStage =
            "school crafting enabled • using selective seller"
        return false, 0
    end

    Runtime.LastSellAllStage = "opening Timmy dialogue"
    Runtime.LastSellReason = "opening Sell All dialogue"

    triggerSellerPrompt()

    local sellAllButton =
        Runtime.WaitForSellerButton(
            Runtime.FindSellAllButton,
            Config.SellAllButtonTimeout
        )

    if not sellAllButton then
        Runtime.LastSellAllStage =
            "Sell All option not found"
        return false, 0
    end

    Runtime.LastSellAllStage = "clicking Sell All option"
    setState("Timmy • clicking Sell All Brainrots")

    if not clickGuiButton(sellAllButton) then
        Runtime.LastSellAllStage =
            "Sell All option click failed"
        return false, 0
    end

    task.wait(0.08)

    -- Some game versions may process Sell All immediately. Verify before
    -- requiring the second confirmation.
    local afterFirstClick =
        Runtime.InventoryEntityToolCount()

    if afterFirstClick < beforeCount then
        local sold = beforeCount - afterFirstClick

        Runtime.LastSellAllStage =
            "Sell All completed on first option"

        return true, sold
    end

    Runtime.LastSellAllStage =
        "waiting for Sell All confirmation"

    local confirmButton =
        Runtime.WaitForSellerButton(
            Runtime.FindSellAllConfirmButton,
            Config.SellAllConfirmTimeout
        )

    if not confirmButton then
        Runtime.LastSellAllStage =
            "Sell All confirmation not found"
        return false, 0
    end

    Runtime.LastSellAllStage =
        "clicking confirmation"

    setState("Timmy • confirming Sell All Brainrots")

    if not clickGuiButton(confirmButton) then
        Runtime.LastSellAllStage =
            "Sell All confirmation click failed"
        return false, 0
    end

    local deadline = os.clock() + 2.5

    while Runtime.Alive and os.clock() < deadline do
        local remaining =
            Runtime.InventoryEntityToolCount()

        if remaining < beforeCount then
            local sold =
                beforeCount - remaining

            Runtime.LastSellAllStage =
                ("Sell All confirmed • %d removed")
                    :format(sold)

            return true, sold
        end

        task.wait(0.04)
    end

    Runtime.LastSellAllStage =
        "confirmation clicked but inventory unchanged"

    return false, 0
end

local function autoSellLeftoverBrainrots()
    if not Config.AutoSellLeftovers
        or roundActive()
        or Runtime.Busy
        or Runtime.PendingRewardPlacement
        or Runtime.InTraining
    then
        return false
    end

    if os.clock() - (Runtime.LastSellAt or 0) < 1.5 then
        return false
    end

    local candidates = leftoverBrainrotsToSell()

    if #candidates == 0 then
        local empty = emptySlotIndex(nil)
        local weakest = worstPlacedBrainrot()

        if empty then
            Runtime.LastSellReason =
                "plot still has usable empty slot " .. tostring(empty)
        elseif not weakest then
            Runtime.LastSellReason =
                "no readable placed brainrot to compare against"
        else
            Runtime.LastSellReason =
                "no inventory brainrot is weaker than current plot"
        end

        return false
    end

    local root = rootPart()
    local hum = humanoid()

    if not root or not hum or root.Anchored then
        Runtime.LastSellReason = "character unavailable"
        return false
    end

    Runtime.LastSellAt = os.clock()
    Runtime.Busy = true
    Runtime.LastSellReason = "moving to Timmy"

    local returnCFrame = root.CFrame
    local sold = 0
    local failures = 0
    local totalValue = 0

    local maxSell = math.max(
        1,
        math.floor(tonumber(Config.SellMaxPerVisit) or 20)
    )

    local maxFailures = math.max(
        3,
        math.min(8, maxSell)
    )

    -- Always unequip first. v4.5's background weight equip could otherwise
    -- prevent an EntityTool from becoming the exact held Tool B_Sell reads.
    pcall(function()
        hum:UnequipTools()
    end)
    task.wait(0.06)

    local inRange = true

    if Config.SellUseNativeSellerTeleport then
        setState("Going to Timmy sell booth")
        inRange = moveIntoSellerRange(false)
    else
        local distance = sellerDistance()
        Runtime.LastSellDistance = distance
        inRange = distance <= 18
    end

    if not inRange then
        Runtime.LastSellReason = "could not reach Timmy prompt range"
        Runtime.SellFailures = (Runtime.SellFailures or 0) + 1
    else
        -- Triggering the real prompt is not strictly required by the dumped
        -- client B_Sell path, but it also satisfies any live proximity/dialogue
        -- checks the current server may enforce.
        triggerSellerPrompt()
        task.wait(0.10)

        local usedSellAll = false

        if tostring(Config.SellMode or "Sell All UI") == "Sell All UI" then
            local sellAllOk, sellAllSold =
                Runtime.TrySellAllUI(#candidates)

            if sellAllOk and sellAllSold > 0 then
                sold = sellAllSold
                usedSellAll = true

                Runtime.SoldBrainrots =
                    (Runtime.SoldBrainrots or 0)
                    + sellAllSold

                Runtime.LastSellReason =
                    Runtime.LastSellAllStage
                    or "Sell All confirmed"
            end
        end

        if not usedSellAll then
            Runtime.LastSellReason =
                (Runtime.LastSellAllStage
                    and (
                        "Sell All fallback • "
                        .. Runtime.LastSellAllStage
                    ))
                or "using selective individual seller"

            for _, candidate in ipairs(candidates) do
                if sold >= maxSell then
                    break
                end

            local tool = candidate.Tool

            if tool and tool.Parent then
                local distance = sellerDistance()
                Runtime.LastSellDistance = distance

                if distance > 18 then
                    moveIntoSellerRange(true)
                    distance = sellerDistance()
                    Runtime.LastSellDistance = distance
                end

                setState(
                    ("Selling %s • Timmy %.1f studs")
                        :format(
                            tostring(tool.Name),
                            tonumber(distance) or -1
                        )
                )

                local equipped =
                    ensureSellerToolEquipped(tool, 1.25)

                if equipped then
                    -- Let replication/server see the exact held EntityTool.
                    task.wait(0.16)

                    local ok, value = Runtime.SellHeldBrainrot()
                    local disappeared =
                        waitForSoldTool(tool, 0.85)

                    -- Retry once from immediately beside live Timmy if the direct
                    -- call returned nothing / the tool remained.
                    if not disappeared then
                        Runtime.LastSellReason =
                            "first B_Sell did not remove tool • retrying near Timmy"

                        moveIntoSellerRange(true)
                        triggerSellerPrompt()

                        if tool and tool.Parent then
                            ensureSellerToolEquipped(tool, 1.25)
                            task.wait(0.25)

                            local retryOk, retryValue =
                                Runtime.SellHeldBrainrot()

                            if retryOk then
                                ok = true
                                if retryValue ~= nil then
                                    value = retryValue
                                end
                            end

                            disappeared =
                                waitForSoldTool(tool, 1.25)
                        end
                    end

                    if disappeared then
                        sold = sold + 1
                        Runtime.SoldBrainrots =
                            (Runtime.SoldBrainrots or 0) + 1
                        Runtime.LastSellReason =
                            "confirmed sold " .. tostring(tool.Name)

                        if type(value) == "number" then
                            totalValue = totalValue + value
                        end
                    else
                        failures = failures + 1
                        Runtime.SellFailures =
                            (Runtime.SellFailures or 0) + 1
                        Runtime.LastSellReason =
                            "B_Sell failed to remove " .. tostring(tool.Name)

                        -- Two consecutive failures means the live seller/server
                        -- state is not ready. Stop instead of remote-spamming.
                        if failures >= maxFailures then
                            break
                        end
                    end
                else
                    failures = failures + 1
                    Runtime.SellFailures =
                        (Runtime.SellFailures or 0) + 1
                    Runtime.LastSellReason =
                        "could not equip exact EntityTool"

                    if failures >= maxFailures then
                        break
                    end
                end

                task.wait(0.05)
            end
        end
        end
    end

    -- Returning >20 studs also closes the client Timmy dialogue cleanly.
    root = rootPart()

    if Config.SellUseNativeSellerTeleport and root then
        pcall(function()
            root.CFrame = returnCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.05)
    end

    unequipAndUnanchor()
    Runtime.Busy = false
    Runtime.LastSellCount = sold

    if totalValue > 0 then
        Runtime.LastSellValue = totalValue
    end

    if sold > 0 then
        if tostring(Config.SellMode or "Sell All UI") == "Sell All UI"
            and Runtime.LastSellAllStage
            and Runtime.LastSellAllStage:find("confirmed", 1, true)
        then
            setState(
                ("Sell All confirmed • %d brainrot%s sold")
                    :format(
                        sold,
                        sold == 1 and "" or "s"
                    )
            )
        else
            setState(
                ("Sold %d leftover brainrot%s • confirmed")
                    :format(
                        sold,
                        sold == 1 and "" or "s"
                    )
            )
        end
        return true
    end

    setState(
        "Auto Sell failed • "
        .. tostring(Runtime.LastSellReason or "unknown reason")
    )
    return false
end

local function slotWorldPosition(slot)
    if not slot then
        return nil
    end

    if slot:IsA("BasePart") then
        return slot.Position
    end

    if slot:IsA("Model") then
        local ok, pivot = pcall(slot.GetPivot, slot)
        if ok and typeof(pivot) == "CFrame" then
            return pivot.Position
        end
    end

    local part = slot:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function brainrotToolScore(tool)
    if not tool
        or not tool:IsA("Tool")
        or not tool.Parent
        or not hasTag(tool, "EntityTool")
    then
        return 0, 0, 0
    end

    return Runtime.BrainrotQualityScore(
        tool.Name,
        tool:GetAttribute("Level") or 1,
        tool:GetAttribute("Mutation")
    )
end

local function brainrotActuallyImprovesPlot(
    tier,
    quality,
    current,
    weakest
)
    if not weakest then
        return true
    end

    return Runtime.BrainrotBeats(
        tier,
        quality,
        current,
        weakest.Tier,
        weakest.Quality,
        weakest.Value
    )
end

local function choosePlotSlotForBrainrot(
    tier,
    quality,
    current,
    preferredSlot,
    allowPreferredForce
)
    -- forceAny is intentionally NOT allowed to force a worse replacement.
    -- It only preserves tutorial behavior for an empty preferred slot.
    if preferredSlot then
        local entry = plotSlotByIndex(preferredSlot)

        if entry and not entry.Part then
            return preferredSlot, "PreferredEmpty"
        end
    end

    local empty = emptySlotIndex(nil)
    if empty then
        return empty, "Empty"
    end

    if not Config.ReplaceWeak then
        return nil, "PlotFull"
    end

    local weakest = worstPlacedBrainrot()
    if not weakest then
        return nil, "NoWeakest"
    end

    if brainrotActuallyImprovesPlot(tier, quality, current, weakest) then
        return weakest.Index, "ReplaceWeakest"
    end

    return nil, "NotBetter"
end

local function waitForBrainrotPlacement(tool, index, beforePart, timeout)
    local deadline = os.clock() + (timeout or 1.25)

    while Runtime.Alive and os.clock() < deadline do
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local char = character()

        local toolGone =
            not tool
            or not tool.Parent
            or (
                tool.Parent ~= backpack
                and tool.Parent ~= char
            )

        local entry = plotSlotByIndex(index)
        local currentPart = entry and entry.Part or nil

        local slotChanged =
            currentPart ~= nil
            and currentPart ~= beforePart

        if toolGone or slotChanged then
            return true
        end

        task.wait(0.025)
    end

    return false
end

local function placeBestBrainrot(forceAny, preferredSlot, preferredTool)
    if not Config.AutoPlaceBest or roundActive() or Runtime.Busy then
        return false
    end

    if os.clock() - Runtime.LastPlacement < 0.15 then
        return false
    end

    local tool
    local tier
    local quality
    local current

    if preferredTool
        and preferredTool.Parent
        and preferredTool:IsA("Tool")
        and hasTag(preferredTool, "EntityTool")
    then
        tool = preferredTool
        tier, quality, current = brainrotToolScore(tool)
    else
        tool, tier, quality, current = bestBrainrotTool()
    end

    if not tool then
        return false
    end

    local index, reason = choosePlotSlotForBrainrot(
        tier,
        quality,
        current,
        preferredSlot,
        forceAny
    )

    if not index then
        if reason == "NotBetter" then
            Runtime.ExtraState =
                tostring(tool.Name)
                .. " is weaker than current plot • reserved for seller"
        end
        return false
    end

    Runtime.Busy = true

    local entry = plotSlotByIndex(index)
    local beforePart = entry and entry.Part or nil
    local slotPosition = entry and slotWorldPosition(entry.Slot) or nil

    if slotPosition then
        local reached = false
        local mode = normalizeTravelMode(Config.TravelMode)

        if mode == "Teleport (Safe)"
            and entry
            and entry.Slot
            and (
                entry.Slot:IsA("BasePart")
                or entry.Slot:IsA("Model")
            )
        then
            setState("Safe teleporting best brainrot to plot")
            reached = moveTo(entry.Slot, 8)
        elseif mode == "Manual" then
            setState("Manual travel • move near plot slot")
            reached = false
        else
            setState("Walking best brainrot to plot")
            reached = walkToPosition(slotPosition, 20, 6)
        end

        if not reached then
            Runtime.Busy = false
            setState("Could not reach plot slot")
            return false
        end
    end

    if reason == "ReplaceWeakest" then
        setState(
            ("Replacing weakest slot with %s")
                :format(tostring(tool.Name))
        )
    else
        setState(
            ("Placing best inventory brainrot: %s")
                :format(tostring(tool.Name))
        )
    end

    local equipped = equipTool(tool)
    local sent = equipped and fireServer("S_Interact", index)

    Runtime.LastPlacement = os.clock()

    local confirmed = false

    if sent then
        confirmed = waitForBrainrotPlacement(
            tool,
            index,
            beforePart,
            1.25
        )
    end

    Runtime.Busy = false

    if confirmed then
        Runtime.PendingRewardPlacement = false
        Runtime.ExtraState =
            ("Confirmed plot placement: %s")
                :format(tostring(tool.Name))
        return true
    end

    Runtime.ExtraState =
        ("Placement not confirmed: %s")
            :format(tostring(tool.Name))

    return false
end

local function reconcileBestInventoryBrainrots(maxPlacements)
    if not Config.AutoPlaceBest
        or roundActive()
        or Runtime.Busy
    then
        return 0
    end

    local maximum = math.max(
        1,
        math.floor(tonumber(maxPlacements) or 10)
    )

    local placed = 0
    local attempts = 0

    while Runtime.Alive
        and Config.Master
        and not roundActive()
        and placed < maximum
        and attempts < maximum * 3
    do
        attempts = attempts + 1

        local sorted = sortedInventoryBrainrotTools()
        local best = sorted[1]

        if not best
            or not best.Tool
            or not best.Tool.Parent
        then
            break
        end

        local index = choosePlotSlotForBrainrot(
            best.Tier,
            best.Quality,
            best.Value,
            nil,
            false
        )

        if not index then
            break
        end

        Runtime.LastPlacement = 0

        if placeBestBrainrot(false, nil, best.Tool) then
            placed = placed + 1
            task.wait(0.04)
        else
            break
        end
    end

    if placed > 0 then
        Runtime.ExtraState =
            ("Best plot reconciliation • %d placed")
                :format(placed)
    end

    return placed
end

placeFreshKickReward = function()
    if not Runtime.PendingRewardPlacement then
        return false
    end

    local deadline = os.clock() + 8

    while Runtime.Alive and Config.Master and os.clock() < deadline do
        local root = rootPart()
        local hum = humanoid()

        if not root or not hum or hum.Health <= 0 or root.Anchored then
            setState("Collection finished • waiting for normal character")
            task.wait(0.06)
        else
            local freshTools = freshEntityToolsSinceKick()

            if #freshTools == 0 then
                local named = rewardNamedEntityTool()

                if named then
                    freshTools = {named}
                end
            end

            if #freshTools > 0 then
                if Runtime.Busy then
                    setState(
                        "Fresh brainrot ready • waiting for placement priority"
                    )
                    task.wait(0.05)
                else
                    Runtime.PostKickPhase = "Placing"

                    -- Re-rank the ENTIRE exact 168-brainrot catalog, including
                    -- upgraded CPS, mutations and Best-% units.
                    local placed = reconcileBestInventoryBrainrots(
                        math.max(1, #freshTools + 4)
                    )

                    Runtime.PendingRewardPlacement = false
                Runtime.RewardLandingPosition = nil
                Runtime.KickToolSnapshot =
                    snapshotEntityToolInstances()
                Runtime.NeedsImmediateTraining = true

                if placed > 0 then
                    Runtime.PostKickPhase = "Placed"
                    setState(
                        "Best brainrot set placed • weak extras go to seller"
                    )
                else
                    Runtime.PostKickPhase = "StoredUnplacedReward"
                    setState(
                        "New reward weaker than plot • reserved for Auto Sell"
                    )
                end

                    return true
                end
            end

            if Runtime.LastCollectedAt > 0 then
                if os.clock() - Runtime.LastCollectedAt > 2.5
                    and not runPhaseVisible(true)
                    and not transformedRewardModel()
                then
                    Runtime.PendingRewardPlacement = false
                    Runtime.RewardLandingPosition = nil
                    Runtime.PostKickPhase = "NoEntityTool"
                    Runtime.NeedsImmediateTraining = true
                    stopAutomatedWalk()
                    unequipAndUnanchor()
                    return true
                end
            elseif Runtime.LastKickEndedAt > 0
                and os.clock() - Runtime.LastKickEndedAt > 3.5
                and not runPhaseVisible(true)
                and not transformedRewardModel()
            then
                -- KickEventEnded happened but Collected/tool delivery was missed.
                -- Release the lifecycle instead of permanently parking at base.
                Runtime.PendingRewardPlacement = false
                Runtime.RewardLandingPosition = nil
                Runtime.PostKickPhase = "RewardDeliveryMissed"
                Runtime.NeedsImmediateTraining = true
                stopAutomatedWalk()
                unequipAndUnanchor()
                return true
            end

            task.wait(0.06)
        end
    end

    Runtime.PostKickPhase = "PlacementTimeout"
    Runtime.PendingRewardPlacement = false
    Runtime.RewardLandingPosition = nil
    Runtime.NeedsImmediateTraining = true
    Runtime.RoundActive = false
    Runtime.SawKickPhase2 = false
    stopAutomatedWalk()
    unequipAndUnanchor()
    return false
end

local function collectBaseCash()
    if not Config.AutoCollectCash then
        return false
    end
    if os.clock() - Runtime.LastCashCollect < Config.CashCollectInterval then
        return false
    end

    Runtime.LastCashCollect = os.clock()
    local did = false
    for _, entry in ipairs(plotSlots()) do
        local id = entry.Part and entry.Part:GetAttribute("ID")
        if id and BrainrotData[id] then
            fireServer("B_Collect", entry.Index)
            did = true
        end
    end
    if did then
        setState("Collecting base cash")
    end
    return did
end

local function openPlacedLuckyBlock()
    if not Config.AutoOpenLuckyBlocks then
        return false
    end
    for _, entry in ipairs(plotSlots()) do
        local id = entry.Part and entry.Part:GetAttribute("ID")
        if id and not BrainrotData[id] then
            local models = ReplicatedStorage:FindFirstChild("Objects")
            models = models and models:FindFirstChild("LuckyBlockModels")
            if models and models:FindFirstChild(tostring(id)) then
                setState("Opening placed lucky block")
                fireServer("LB_OpenRequest", entry.Index)
                task.wait(0.18)
                return true
            end
        end
    end
    return false
end

local function openLuckyBlockTool()
    if not Config.AutoOpenLuckyBlocks or roundActive() or Runtime.Busy then
        return false
    end
    if os.clock() - Runtime.LastLuckyOpen < 0.35 then
        return false
    end

    local chosen
    for _, tool in ipairs(allTools()) do
        if hasTag(tool, "LuckyBlockTool") then
            chosen = tool
            break
        end
    end
    if not chosen then
        return openPlacedLuckyBlock()
    end

    local every = math.max(
        1,
        math.floor(tonumber(Config.LuckyBlockEveryKicks) or 3)
    )

    if (Runtime.CompletedKickCycles or 0)
        - (Runtime.LastLuckyBlockCycle or -999) < every
    then
        return openPlacedLuckyBlock()
    end

    Runtime.Busy = true
    setState("Opening lucky block")
    local ok = equipTool(chosen) and fireServer("lb_open")
    Runtime.LastLuckyOpen = os.clock()
    Runtime.LastLuckyBlockCycle = Runtime.CompletedKickCycles or 0
    task.wait(0.10)
    Runtime.Busy = false
    return ok
end

local function waitForBrainrotUpgrade(part, previousLevel, timeout)
    local deadline = os.clock() + (timeout or 0.9)

    while Runtime.Alive and os.clock() < deadline do
        if part and part.Parent then
            local level = part:GetAttribute("Level") or 1
            if level > previousLevel then
                return true, level
            end
        end

        task.wait(0.025)
    end

    return false, previousLevel
end

local function upgradeOneBrainrot(preferredIndex)
    if not Config.AutoUpgradeBrainrots then
        return false
    end

    if os.clock() - Runtime.LastUpgrade < 0.20 then
        return false
    end

    local balance = currentBalance()
    local choice

    for _, entry in ipairs(plotSlots()) do
        if not preferredIndex or entry.Index == preferredIndex then
            local part = entry.Part
            local id = part and part:GetAttribute("ID")

            if id and BrainrotData[id] and BrainrotData[id].CPS then
                local level = part:GetAttribute("Level") or 1

                if level < 75 then
                    local roi, gain, cost =
                        brainrotUpgradeROI(
                            id,
                            level,
                            part:GetAttribute("Mutation")
                        )

                    if cost and cost <= balance then
                        local candidate = {
                            Index = entry.Index,
                            Part = part,
                            ID = id,
                            Level = level,
                            Cost = cost,
                            ROI = roi or 0,
                            Gain = gain or 0,
                        }

                        if not choice
                            or candidate.ROI > choice.ROI
                            or (
                                candidate.ROI == choice.ROI
                                and candidate.Gain > choice.Gain
                            )
                        then
                            choice = candidate
                        end
                    end
                end
            end
        end
    end

    if not choice then
        return false
    end

    Runtime.LastUpgrade = os.clock()
    setState(
        ("Upgrading %s L%d → L%d")
            :format(choice.ID, choice.Level, choice.Level + 1)
    )

    if not fireServer("B_Upgrade", choice.Index) then
        return false
    end

    local confirmed = waitForBrainrotUpgrade(
        choice.Part,
        choice.Level,
        0.9
    )

    if confirmed then
        Runtime.SmartUpgradeConfirmed =
            (Runtime.SmartUpgradeConfirmed or 0) + 1
    else
        Runtime.SmartUpgradeFailed =
            (Runtime.SmartUpgradeFailed or 0) + 1
    end

    return confirmed
end

local function smartUpgradeCandidate(remainingBudget)
    local entries = {}
    local hasEmpty = emptySlotIndex(nil) ~= nil

    for _, entry in ipairs(plotSlots()) do
        local part = entry.Part
        local id = part and part:GetAttribute("ID")

        if id and BrainrotData[id] and BrainrotData[id].CPS then
            local level = part:GetAttribute("Level") or 1

            if level < 75 then
                local mutation = part:GetAttribute("Mutation")
                local tier, quality, currentValue =
                    Runtime.BrainrotQualityScore(
                        id,
                        level,
                        mutation
                    )

                local roi, gain, cost, currentCPS, nextCPS =
                    brainrotUpgradeROI(id, level, mutation)

                if cost and cost <= remainingBudget then
                    table.insert(entries, {
                        Index = entry.Index,
                        Part = part,
                        ID = id,
                        Level = level,
                        Mutation = mutation,
                        Tier = tier,
                        Quality = quality,
                        Value = currentValue,
                        Cost = cost,
                        ROI = roi or 0,
                        Gain = gain or 0,
                        BaseCPS = tonumber(BrainrotData[id].CPS) or 0,
                        CurrentCPS = currentCPS or 0,
                        NextCPS = nextCPS or 0,
                    })
                end
            end
        end
    end

    if #entries == 0 then
        return nil
    end

    if not hasEmpty and #entries >= 4 then
        table.sort(entries, function(a, b)
            if a.Tier ~= b.Tier then
                return a.Tier < b.Tier
            end

            if a.Quality ~= b.Quality then
                return a.Quality < b.Quality
            end

            return a.Value < b.Value
        end)

        local keepFraction = math.clamp(
            tonumber(Config.BrainrotUpgradeKeepFraction) or 1.00,
            0.25,
            1
        )

        local skipCount = math.floor(
            #entries * (1 - keepFraction) + 0.5
        )

        if skipCount > 0 and skipCount < #entries then
            local keep = {}

            for i = skipCount + 1, #entries do
                table.insert(keep, entries[i])
            end

            entries = keep
        end
    end

    table.sort(entries, function(a, b)
        if a.Level ~= b.Level then
            return a.Level < b.Level
        end

        if a.ROI ~= b.ROI then
            return a.ROI > b.ROI
        end

        if a.CurrentCPS ~= b.CurrentCPS then
            return a.CurrentCPS > b.CurrentCPS
        end

        return a.Cost < b.Cost
    end)

    return entries[1]
end

local function upgradeBrainrotsBatch(maxOverride)
    if not Config.AutoUpgradeBrainrots
        or roundActive()
        or Runtime.Busy
    then
        return false
    end

    if os.clock() - Runtime.LastUpgrade < 0.20 then
        return false
    end

    local startingBalance = currentBalance()
    if startingBalance <= 0 then
        return false
    end

    local spendFraction = math.clamp(
        tonumber(Config.BrainrotUpgradeSpendFraction) or 0.55,
        0.05,
        1
    )

    local passBudget = startingBalance * spendFraction
    local spent = 0
    local upgraded = 0
    local failed = 0

    local maximum = math.max(
        1,
        math.floor(
            tonumber(maxOverride)
            or tonumber(Config.BrainrotUpgradeMaxPerPass)
            or 18
        )
    )

    while Runtime.Alive
        and Config.Master
        and upgraded < maximum
        and not roundActive()
        and not Runtime.Busy
    do
        local remainingBudget = passBudget - spent
        if remainingBudget <= 0 then
            break
        end

        local candidate = smartUpgradeCandidate(remainingBudget)
        if not candidate then
            break
        end

        Runtime.LastUpgrade = os.clock()
        Runtime.ExtraState = (
            "%s • base %.0f • L%d %.0f→%.0f CPS • cost $%.0f"
        ):format(
            candidate.ID,
            candidate.BaseCPS or 0,
            candidate.Level,
            candidate.CurrentCPS or 0,
            candidate.NextCPS or 0,
            candidate.Cost
        )

        local sent = fireServer("B_Upgrade", candidate.Index)

        if not sent then
            failed = failed + 1
            break
        end

        local confirmed = waitForBrainrotUpgrade(
            candidate.Part,
            candidate.Level,
            0.85
        )

        if confirmed then
            upgraded = upgraded + 1
            spent = spent + candidate.Cost
            Runtime.SmartUpgradeConfirmed =
                (Runtime.SmartUpgradeConfirmed or 0) + 1
        else
            failed = failed + 1
            Runtime.SmartUpgradeFailed =
                (Runtime.SmartUpgradeFailed or 0) + 1
            break
        end

        task.wait(0.025)
    end

    if upgraded > 0 then
        setState(
            ("Smart upgrades • %d confirmed • spent $%.0f")
                :format(upgraded, spent)
        )
        return true
    end

    if failed > 0 then
        Runtime.ExtraState =
            "Brainrot upgrade not confirmed • retrying later"
    end

    return false
end

local function estimateStyleCycleTime(style)
    local distance = Runtime.TargetKickDistance
        or kickDistanceFromPower(currentKickPower())

    local flight = distance / math.max(
        1,
        30 * (style.Multiplier or 1)
    )

    return (style.PerfectLength or 3) + flight
end

local function bestAvailableKickStyle()
    local mastery = math.max(0, currentKickMastery())
    local owned = Runtime.OwnedStyles or {}
    local mode = tostring(Config.KickStyleMode or "Throughput")

    local best = nil
    local bestMetric = nil

    for _, data in ipairs(KickStyleData) do
        local isOwned = data.AlwaysOwned == true or owned[data.Name] == true
        local canBuy = data.Cost ~= nil and data.Cost <= mastery
        local available = isOwned or canBuy

        if available then
            local estimated = estimateStyleCycleTime(data)
            local metric

            if mode == "Max Multiplier" then
                metric = -(data.Multiplier or 1)
            else
                metric = estimated
            end

            if bestMetric == nil or metric < bestMetric then
                bestMetric = metric
                best = {
                    Name = data.Name,
                    Multiplier = data.Multiplier or 1,
                    PerfectLength = data.PerfectLength or 3,
                    Cost = data.Cost,
                    Owned = isOwned,
                    EstimatedTime = estimated,
                }
            end
        end
    end

    return best
end

local function buyOrEquipBestKickStyle()
    if not Config.AutoKickStyles or roundActive() or Runtime.Busy then
        return false
    end
    if os.clock() - Runtime.LastStyleAction < 1 then
        return false
    end

    local target = bestAvailableKickStyle()
    if not target then
        return false
    end

    if Runtime.EquippedStyle == target.Name then
        return false
    end

    Runtime.LastStyleAction = os.clock()

    if not target.Owned then
        if target.Cost == nil then
            return false
        end

        Runtime.ExtraState = (
            "Buying kick style %s • x%.2f"
        ):format(target.Name, target.Multiplier)

        fireServer("Shop_Buy", "KickStyles", target.Name)
        task.wait(0.12)
        Runtime.OwnedStyles[target.Name] = true
    end

    Runtime.ExtraState = (
        "Equipping %s • x%.2f • est %.1fs"
    ):format(
        target.Name,
        target.Multiplier,
        target.EstimatedTime or 0
    )

    fireServer("StyleToggle", target.Name)
    Runtime.EquippedStyle = target.Name
    task.wait(0.06)
    return true
end

-- ============================================================================
-- Weight / training / speed / rebirth
-- ============================================================================

local function refreshOwnedWeightsFromTools()
    local owned = {}
    for _, tool in ipairs(allTools()) do
        if hasTag(tool, "SquatTool") or WeightByName[tool.Name] then
            if WeightByName[tool.Name] then
                owned[tool.Name] = true
            end
        end
    end
    for name in pairs(Runtime.OwnedWeights) do
        owned[name] = true
    end
    return owned
end

local function bestAffordableWeight(forceWooden)
    if forceWooden then
        return "Wooden Stick"
    end

    local balance = currentBalance()
    local owned = refreshOwnedWeightsFromTools()
    local best = nil
    for _, data in ipairs(WeightData) do
        if owned[data.Name] or data.Cost <= balance then
            if not best or data.PPS > best.PPS then
                best = data
            end
        end
    end
    return best and best.Name or nil
end

equippedWeightTool = function()
    local char = character()
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and (hasTag(tool, "SquatTool") or WeightByName[tool.Name]) then
                return tool
            end
        end
    end

    local targetName = Runtime.EquippedWeight
    local fallback
    for _, tool in ipairs(allTools()) do
        if tool:IsA("Tool") and (hasTag(tool, "SquatTool") or WeightByName[tool.Name]) then
            if targetName and tool.Name == targetName then
                return tool
            end
            fallback = fallback or tool
        end
    end
    return fallback
end


local TrainingBonusButtonClicks = setmetatable({}, {__mode = "k"})

local function trainingMultiplierFromText(value)
    local compact = tostring(value or "")
        :upper()
        :gsub("%s+", "")
        :gsub("×", "X")

    if compact == "X2" or compact == "2X" then
        return 2
    elseif compact == "X5" or compact == "5X" then
        return 5
    elseif compact == "X10" or compact == "10X" then
        return 10
    end

    return nil
end

local function trainingMultiplierForButton(button)
    if not button or not button:IsA("GuiButton") then
        return nil
    end

    if button:IsA("TextButton") then
        local direct = trainingMultiplierFromText(button.Text)
        if direct then
            return direct
        end
    end

    local ok, descendants = pcall(button.GetDescendants, button)
    if ok and type(descendants) == "table" then
        for _, child in ipairs(descendants) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                local mult = trainingMultiplierFromText(child.Text)
                if mult then
                    return mult
                end
            end
        end
    end

    local parent = button.Parent
    if parent and parent:IsA("GuiObject") then
        local children = parent:GetChildren()
        local parentName = tostring(parent.Name or ""):lower()
        local buttonName = tostring(button.Name or ""):lower()

        local likelyPopup =
            parentName:find("bonus", 1, true)
            or parentName:find("tavi", 1, true)
            or parentName:find("mish", 1, true)
            or parentName:find("mult", 1, true)
            or buttonName:find("bonus", 1, true)
            or buttonName:find("tavi", 1, true)
            or buttonName:find("mish", 1, true)

        if likelyPopup or #children <= 12 then
            for _, child in ipairs(children) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    local mult = trainingMultiplierFromText(child.Text)
                    if mult then
                        return mult
                    end
                end
            end
        end
    end

    return nil
end

local function clickVisibleTrainingBonusPopups(force)
    if not Config.AutoKickBonuses or not Runtime.Alive then
        return 0
    end

    if not equippedWeightTool() then
        return 0
    end

    local now = os.clock()
    if not force and now - (Runtime.LastBonusUiScan or 0) < 0.025 then
        return 0
    end
    Runtime.LastBonusUiScan = now

    local clicked = 0
    local ok, descendants = pcall(PlayerGui.GetDescendants, PlayerGui)
    if not ok or type(descendants) ~= "table" then
        return 0
    end

    for _, object in ipairs(descendants) do
        if object:IsA("GuiButton") and guiObjectActuallyVisible(object) then
            local multiplier = trainingMultiplierForButton(object)

            if multiplier then
                local lastClick = TrainingBonusButtonClicks[object] or 0

                if now - lastClick >= 0.20 then
                    TrainingBonusButtonClicks[object] = now

                    local didClick = clickGuiButton(object)
                    if didClick then
                        clicked = clicked + 1
                        Runtime.TrainingBonusClicks =
                            (Runtime.TrainingBonusClicks or 0) + 1
                        Runtime.LastBonusClaim = now
                        Runtime.ExtraState =
                            ("Clicked x%s training bonus")
                            :format(tostring(multiplier))

                        task.delay(0.01, function()
                            if Runtime.Alive and Config.AutoKickBonuses then
                                fireServer("TaviMishkal")
                            end
                        end)
                    end
                end
            end
        end
    end

    return clicked
end


local buyOrEquipBestWeight
local trainFor

local function currentWeightPPS()
    local name = Runtime.EquippedWeight

    if not name then
        local tool = equippedWeightTool()
        name = tool and tool.Name or nil
    end

    if not name then
        name = bestAffordableWeight(false)
    end

    local data = name and WeightByName[name] or nil
    return data and math.max(0, tonumber(data.PPS) or 0) or 2
end

captureActualKickDistance = function()
    if Runtime.DistanceCapturedThisKick then
        return Runtime.LastKickDistance
    end

    local origin = Runtime.KickOriginPosition
    local root = rootPart()

    if typeof(origin) ~= "Vector3" or not root then
        return nil
    end

    local delta = Vector3.new(
        root.Position.X - origin.X,
        0,
        root.Position.Z - origin.Z
    )

    local distance = delta.Magnitude

    if distance < 20 then
        return nil
    end

    Runtime.DistanceCapturedThisKick = true

    local previous = Runtime.LastKickDistance
    Runtime.PreviousKickDistance = previous
    Runtime.LastKickDistance = distance
    Runtime.BestKickDistance = math.max(Runtime.BestKickDistance or 0, distance)

    if previous and previous > 0 then
        local gain = distance - previous
        Runtime.LastDistanceGain = gain

        if gain < (tonumber(Config.AdaptivePlateauThreshold) or 3) then
            Runtime.ConsecutiveDistancePlateaus =
                math.min((Runtime.ConsecutiveDistancePlateaus or 0) + 1, 5)
        else
            Runtime.ConsecutiveDistancePlateaus = 0
        end
    else
        Runtime.LastDistanceGain = nil
        Runtime.ConsecutiveDistancePlateaus = 0
    end

    return distance
end

local function calculateAdaptiveTrainingTarget()
    local power = math.max(0, currentKickPower())
    local pps = math.max(0.001, currentWeightPPS())
    local estimatedDistance = kickDistanceFromPower(power)

    local baseGain = math.max(
        1,
        tonumber(Config.AdaptiveDistanceGain) or 12
    )

    local desiredDistanceGain = baseGain
    local targetDistance = estimatedDistance + baseGain

    if tostring(Config.FarmKickMode or "Max Distance") ~= "Max Distance" then
        local zoneIndex = rarityIndexForDistance(estimatedDistance)
        local nextZone = RarityZones[zoneIndex + 1]

        if nextZone then
            -- Progression training now has a useful goal: unlock the next rarity.
            -- We still cap time below, so a distant threshold is approached over
            -- multiple fast farm cycles rather than one giant training pause.
            targetDistance = nextZone.Distance + 5
            desiredDistanceGain = math.max(
                1,
                targetDistance - estimatedDistance
            )
        else
            targetDistance = math.min(
                KICK_MAX_DISTANCE,
                estimatedDistance + baseGain
            )
        end
    else
        local plateaus = math.max(
            0,
            Runtime.ConsecutiveDistancePlateaus or 0
        )

        local plateauMultiplier = 1 + math.min(plateaus, 4) * 0.75
        desiredDistanceGain = baseGain * plateauMultiplier

        if Runtime.LastDistanceGain and Runtime.LastDistanceGain <= 0 then
            desiredDistanceGain =
                desiredDistanceGain + baseGain * 0.50
        end

        targetDistance = math.min(
            KICK_MAX_DISTANCE,
            estimatedDistance + desiredDistanceGain
        )
    end

    local formulaTarget = kickPowerForDistance(targetDistance, power)

    local minSeconds = math.max(
        0,
        tonumber(Config.AdaptiveMinTrainSeconds) or 4
    )

    local maxSeconds = math.max(
        minSeconds,
        tonumber(Config.AdaptiveMaxTrainSeconds) or 10
    )

    local targetPower = math.max(
        formulaTarget,
        power + pps * minSeconds
    )

    Runtime.LastAdaptiveTrainTarget = targetPower
    return targetPower, maxSeconds, targetDistance, desiredDistanceGain
end

local function adaptiveTrainBeforeKick()
    if not Config.AutoTrain
        or not Config.AdaptiveTraining
        or roundActive()
    then
        return false
    end

    Runtime.LastWeightAction = 0
    buyOrEquipBestWeight(false)
    task.wait(0.12)

    local startPower = currentKickPower()
    local targetPower, maxSeconds, _, desiredGain =
        calculateAdaptiveTrainingTarget()

    if targetPower <= startPower + 0.001 then
        return false
    end

    Runtime.LastAdaptiveTrainStartPower = startPower

    setState(
        ("Training %.0f → %.0f power • target +%.0f studs")
            :format(startPower, targetPower, desiredGain)
    )

    local trained = trainFor(maxSeconds, targetPower)
    unequipAndUnanchor()

    Runtime.LastAdaptiveTrainEndPower = currentKickPower()
    Runtime.LastTrainingCompletedAt = os.clock()
    return trained == true
end

local function smartTrainingBeforeKick()
    if not Config.AutoTrain or roundActive() then
        return false
    end

    if not Config.SmartTrainingCadence then
        return adaptiveTrainBeforeKick()
    end

    Runtime.LastWeightAction = 0
    buyOrEquipBestWeight(false)
    task.wait(0.08)

    local power = math.max(0, currentKickPower())
    local estimatedDistance = kickDistanceFromPower(power)
    local zoneIndex = rarityIndexForDistance(estimatedDistance)
    local nextZone = RarityZones[zoneIndex + 1]

    local observedRate = tonumber(Runtime.ObservedTrainingRate)
    if not observedRate or observedRate <= 0 then
        observedRate = math.max(0.001, currentWeightPPS())
    end

    if nextZone then
        local targetPower = kickPowerForDistance(nextZone.Distance + 5, power)
        local gap = math.max(0, targetPower - power)
        local eta = gap / observedRate

        if eta <= (tonumber(Config.NextRaritySprintMaxSeconds) or 7) then
            setState(
                ("Rarity sprint • %s in ~%.1fs")
                    :format(nextZone.Name, eta)
            )

            local duration = math.min(
                tonumber(Config.AdaptiveMaxTrainSeconds) or 8,
                math.max(0.5, eta + 0.5)
            )

            trainFor(duration, targetPower)
            unequipAndUnanchor()
            return true
        end
    end

    local every = math.max(
        1,
        math.floor(tonumber(Config.TrainingBurstEveryKicks) or 2)
    )

    if (Runtime.KicksSinceTraining or 0) >= every then
        local burst = math.max(
            0.5,
            tonumber(Config.TrainingBurstSeconds) or 2.5
        )
        local target = power + observedRate * burst

        setState(
            ("Fast training burst • %.1fs")
                :format(burst)
        )

        trainFor(burst, target)
        unequipAndUnanchor()
        return true
    end

    Runtime.ExtraState = (
        "Skipping training this kick • %d/%d cadence"
    ):format(Runtime.KicksSinceTraining or 0, every)
    return false
end

buyOrEquipBestWeight = function(forceWooden)
    if not Config.AutoBuyWeights or roundActive() then
        return false
    end
    if os.clock() - Runtime.LastWeightAction < 0.45 then
        return false
    end

    local targetName = bestAffordableWeight(forceWooden)
    if not targetName then
        return false
    end

    local owned = refreshOwnedWeightsFromTools()

    -- Do not waste maintenance cycles re-equipping the same already-selected weight.
    if owned[targetName] and Runtime.EquippedWeight == targetName then
        return false
    end

    Runtime.LastWeightAction = os.clock()

    if not owned[targetName] then
        -- ShopController itself only sends Shop_Buy(shop,item); physical shop
        -- proximity is only needed by the tutorial presentation.
        if tutorialStep() == 11 then
            local shop = workspace:FindFirstChild("Shops")
            shop = shop and shop:FindFirstChild("WeightShop")
            local touch = shop and shop:FindFirstChild("TouchPart")
            if touch then
                moveTo(touch, 6)
            end
        end

        setState("Buying " .. targetName)
        fireServer("Shop_Buy", "WeightShop", targetName)
        task.wait(0.22)
    end

    if Runtime.EquippedWeight ~= targetName then
        setState("Equipping " .. targetName)
        fireServer("WeightEquip", targetName)
        task.wait(0.18)
        return true
    end

    return not owned[targetName]
end

trainFor = function(seconds, targetLevel)
    if not Config.AutoTrain or roundActive() then
        return false
    end

    Runtime.InTraining = true

    buyOrEquipBestWeight(targetLevel and targetLevel <= 100)
    local tool = equippedWeightTool()
    if not tool then
        -- The server may have just equipped it; look again after a moment.
        task.wait(0.3)
        tool = equippedWeightTool()
    end
    if not tool then
        Runtime.InTraining = false
        return false
    end

    if not equipTool(tool) then
        Runtime.InTraining = false
        return false
    end

    local started = os.clock()
    local startPowerObserved = currentKickPower()
    local duration = math.max(0, tonumber(seconds) or 0)
    local lastStatusAt = 0
    local bonusClicksAtStart = Runtime.TrainingBonusClicks or 0

    while Runtime.Alive and Config.Master and Config.AutoTrain and not roundActive() do
        local power = currentKickPower()

        clickVisibleTrainingBonusPopups(false)

        if targetLevel and power >= targetLevel then
            break
        end

        if duration > 0 and os.clock() - started >= duration then
            break
        end

        if os.clock() - lastStatusAt >= 0.25 then
            lastStatusAt = os.clock()

            local elapsed = os.clock() - started
            local claimed =
                (Runtime.TrainingBonusClicks or 0) - bonusClicksAtStart

            if targetLevel then
                setState(
                    ("Training %.0f / %.0f power • %.1fs • bonuses %d")
                        :format(power, targetLevel, elapsed, claimed)
                )
            else
                setState(
                    ("Training kick power • %.1fs • bonuses %d")
                        :format(elapsed, claimed)
                )
            end
        end

        task.wait(0.025)
    end

    clickVisibleTrainingBonusPopups(true)

    local endedAt = os.clock()
    local elapsed = math.max(0.001, endedAt - started)
    local endPowerObserved = currentKickPower()
    local gained = math.max(0, endPowerObserved - startPowerObserved)

    Runtime.LastTrainingDuration = elapsed
    Runtime.LastTrainingCompletedAt = endedAt
    Runtime.KicksSinceTraining = 0

    if gained > 0 and elapsed >= 0.25 then
        local rate = gained / elapsed

        if Runtime.GymEventPriority then
            if Runtime.GymTrainingRate then
                Runtime.GymTrainingRate =
                    Runtime.GymTrainingRate * 0.65 + rate * 0.35
            else
                Runtime.GymTrainingRate = rate
            end
        else
            if Runtime.ObservedTrainingRate then
                Runtime.ObservedTrainingRate =
                    Runtime.ObservedTrainingRate * 0.65 + rate * 0.35
            else
                Runtime.ObservedTrainingRate = rate
            end
        end
    end

    Runtime.InTraining = false
    return true
end

local Gym = {}
Gym.Event = {
    LastMachineScan = 0,
    LastVerifiedPart = nil,
    LastVerifiedMachine = nil,
    LastVerifyAt = 0,
}

Gym.currentLiftMachineMultiplier = function()
    return math.max(
        1,
        tonumber(LocalPlayer:GetAttribute("liftMachine")) or 1
    )
end

Gym.currentGymSpeedMultiplier = function()
    return math.max(
        1,
        tonumber(LocalPlayer:GetAttribute("gym_speed")) or 1
    )
end

Gym.currentGymPowerMultiplier = function()
    return math.max(
        1,
        tonumber(LocalPlayer:GetAttribute("gym_power")) or 1
    )
end

Gym.liveLiftMachines = function()
    local result = {}
    local ok, tagged = pcall(
        CollectionService.GetTagged,
        CollectionService,
        "LiftMachine"
    )

    if not ok or type(tagged) ~= "table" then
        return result
    end

    for _, machine in ipairs(tagged) do
        if machine
            and machine.Parent
            and machine:IsDescendantOf(workspace)
        then
            table.insert(result, machine)
        end
    end

    return result
end

Gym.nearestLiftMachine = function()
    local machines = Gym.liveLiftMachines()

    if #machines == 0 then
        return nil
    end

    local root = rootPart()
    local best
    local bestDistance

    for _, machine in ipairs(machines) do
        local position

        if machine:IsA("BasePart") then
            position = machine.Position
        elseif machine:IsA("Model") then
            local ok, pivot = pcall(machine.GetPivot, machine)

            if ok then
                position = pivot.Position
            end
        end

        if not position then
            local part = machine:FindFirstChildWhichIsA("BasePart", true)

            if part then
                position = part.Position
            end
        end

        local distance =
            root
            and position
            and (root.Position - position).Magnitude
            or 0

        if not bestDistance or distance < bestDistance then
            bestDistance = distance
            best = machine
        end
    end

    return best
end

Gym.gymTimeActive = function(force)
    local machine = Gym.nearestLiftMachine()

    if machine then
        Runtime.GymEventActive = true
        Runtime.GymEventLastSeenAt = os.clock()
        Runtime.GymMachineName = machine.Name
        Runtime.GymMachineAnchor = machine

        return true, nil, machine
    end

    local grace = math.max(
        0.20,
        tonumber(Config.GymEventMissingGrace) or 1.50
    )

    local active =
        Runtime.GymEventActive
        and os.clock() - (Runtime.GymEventLastSeenAt or 0) <= grace

    if not active then
        Runtime.GymEventActive = false
    end

    return active, nil, nil
end

Gym.isDescendantOfNamedFolder = function(object, folderName)
    local node = object and object.Parent

    while node do
        if node.Name == folderName then
            return true
        end

        node = node.Parent
    end

    return false
end

Gym.liftMachinePartScore = function(part)
    if not part or not part:IsA("BasePart") then
        return -math.huge
    end

    local name = tostring(part.Name or ""):lower()
    local score = 0

    -- The sister LuckMachine uses StandingPlatforms + matching Hitboxes.
    -- Prefer the same live structure when LiftMachine supplies it.
    if Gym.isDescendantOfNamedFolder(part, "StandingPlatforms") then
        score = score + 1200
    end

    if Gym.isDescendantOfNamedFolder(part, "Hitboxes") then
        score = score + 1100
    end

    if name:find("standing", 1, true)
        or name:find("platform", 1, true)
        or name:find("pad", 1, true)
    then
        score = score + 500
    end

    if name:find("hitbox", 1, true)
        or name:find("zone", 1, true)
    then
        score = score + 450
    end

    if name:find("lift", 1, true)
        or name:find("squat", 1, true)
    then
        score = score + 250
    end

    if part.Transparency >= 0.95 and not part.CanCollide then
        score = score + 80
    end

    if part.Size.X >= 3 and part.Size.Z >= 3 then
        score = score + 60
    end

    return score
end

Gym.liftMachineCandidateParts = function(machine)
    local candidates = {}
    local seen = {}

    local function add(part)
        if part
            and part:IsA("BasePart")
            and part.Parent
            and not seen[part]
        then
            seen[part] = true

            table.insert(candidates, {
                Part = part,
                Score = Gym.liftMachinePartScore(part),
            })
        end
    end

    if not machine then
        return candidates
    end

    if machine:IsA("BasePart") then
        add(machine)
    elseif machine:IsA("Model") then
        add(machine.PrimaryPart)
    end

    local standing =
        machine:FindFirstChild("StandingPlatforms", true)

    if standing then
        for _, child in ipairs(standing:GetDescendants()) do
            add(child)
        end

        for _, child in ipairs(standing:GetChildren()) do
            add(child)
        end
    end

    local hitboxes =
        machine:FindFirstChild("Hitboxes", true)

    if hitboxes then
        for _, child in ipairs(hitboxes:GetDescendants()) do
            add(child)
        end

        for _, child in ipairs(hitboxes:GetChildren()) do
            add(child)
        end
    end

    for _, descendant in ipairs(machine:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local score = Gym.liftMachinePartScore(descendant)

            if score >= 200 then
                add(descendant)
            end
        end
    end

    if #candidates == 0 then
        add(machine:FindFirstChildWhichIsA("BasePart", true))
    end

    table.sort(candidates, function(a, b)
        return a.Score > b.Score
    end)

    return candidates
end

Gym.gymTargetPosition = function(part)
    local root = rootPart()
    local hum = humanoid()

    if not part or not root or not hum then
        return nil
    end

    local isHitbox =
        Gym.isDescendantOfNamedFolder(part, "Hitboxes")
        or tostring(part.Name):lower():find("hitbox", 1, true)
        or tostring(part.Name):lower():find("zone", 1, true)

    if isHitbox then
        -- Put HRP inside the actual overlap volume. This is the exact thing the
        -- game's machine logic checks for on the related LuckMachine system.
        return part.Position
    end

    -- Natural standing position on top of a physical machine platform.
    local rootHalf = math.max(1, root.Size.Y * 0.5)
    local yOffset =
        part.Size.Y * 0.5
        + math.max(1.5, hum.HipHeight or 2)
        + rootHalf

    return part.CFrame:PointToWorldSpace(
        Vector3.new(0, yOffset, 0)
    )
end

Gym.moveToLiftMachinePart = function(part)
    if not part
        or not part.Parent
        or not waitAlive(3)
    then
        return false
    end

    local root = rootPart()

    if not root or root.Anchored then
        return false
    end

    local target = Gym.gymTargetPosition(part)

    if not target then
        return false
    end

    unequipAndUnanchor()

    local mode =
        normalizeTravelMode(Config.GymEventTravelMode)

    if mode == "Manual" then
        return (
            Vector3.new(
                root.Position.X - target.X,
                0,
                root.Position.Z - target.Z
            ).Magnitude <= 7
        )
    end

    if mode == "Teleport (Safe)" then
        pcall(function()
            local rotationOnly =
                root.CFrame - root.CFrame.Position

            root.CFrame =
                CFrame.new(target)
                * rotationOnly

            root.AssemblyLinearVelocity =
                Vector3.zero

            root.AssemblyAngularVelocity =
                Vector3.zero
        end)

        task.wait(0.16)

        root = rootPart()

        return root ~= nil
            and (root.Position - target).Magnitude <= 8
    end

    return walkToPosition(target, 12, 5)
end

Gym.ensureGymTrainingTool = function()
    local tool = equippedWeightTool()

    if tool
        and tool.Parent == character()
        and hasTag(tool, "SquatTool")
    then
        return tool
    end

    Runtime.LastWeightAction = 0
    buyOrEquipBestWeight(false)

    task.wait(0.10)

    tool = equippedWeightTool()

    if not tool then
        return nil
    end

    if tool.Parent ~= character() then
        if not equipTool(tool) then
            return nil
        end
    end

    task.wait(0.08)

    return tool
end

Gym.waitForLiftMachineRecognition = function(timeout)
    local deadline =
        os.clock() + (timeout or 0.9)

    while Runtime.Alive
        and os.clock() < deadline
    do
        if Gym.currentLiftMachineMultiplier() > 1 then
            return true
        end

        clickVisibleTrainingBonusPopups(false)
        task.wait(0.025)
    end

    return Gym.currentLiftMachineMultiplier() > 1
end

Gym.enterGymMachine = function(forceRescan)
    local machine =
        forceRescan
        and Gym.nearestLiftMachine()
        or Runtime.GymMachineAnchor

    if not machine
        or not machine.Parent
        or not machine:IsDescendantOf(workspace)
    then
        machine = Gym.nearestLiftMachine()
    end

    if not machine then
        Runtime.ExtraState =
            "Gym Time active • waiting for tagged LiftMachine"
        return false
    end

    Runtime.GymMachineAnchor = machine
    Runtime.GymMachineName = machine.Name

    -- If the server already recognizes us, do not disturb a good squat.
    if Gym.currentLiftMachineMultiplier() > 1 then
        Gym.ensureGymTrainingTool()
        return true
    end

    local candidates =
        Gym.liftMachineCandidateParts(machine)

    if Gym.Event.LastVerifiedMachine == machine
        and Gym.Event.LastVerifiedPart
        and Gym.Event.LastVerifiedPart.Parent
    then
        table.insert(
            candidates,
            1,
            {
                Part = Gym.Event.LastVerifiedPart,
                Score = math.huge,
            }
        )
    end

    local maximum =
        math.min(#candidates, 10)

    for index = 1, maximum do
        local part = candidates[index].Part

        setState(
            ("GYM TIME • trying Lift Machine zone %d/%d")
                :format(index, maximum)
        )

        if Gym.moveToLiftMachinePart(part) then
            local tool = Gym.ensureGymTrainingTool()

            if tool
                and Gym.waitForLiftMachineRecognition(0.90)
            then
                Gym.Event.LastVerifiedMachine =
                    machine

                Gym.Event.LastVerifiedPart =
                    part

                Gym.Event.LastVerifyAt =
                    os.clock()

                Runtime.GymMachineLastEnter =
                    os.clock()

                Runtime.ExtraState =
                    (
                        "Lift Machine recognized • x%.0f speed"
                    ):format(
                        Gym.currentLiftMachineMultiplier()
                    )

                return true
            end
        end

        unequipAndUnanchor()
        task.wait(0.05)
    end

    Runtime.ExtraState =
        "Lift Machine found but squat zone not recognized yet"

    return false
end

Gym.gymMachineProgress = function(machine)
    if not machine or not machine.Parent then
        return 1, 0, 0
    end

    local multiplier =
        tonumber(machine:GetAttribute("Multiplier"))
        or Gym.currentLiftMachineMultiplier()
        or 1

    local squats =
        tonumber(machine:GetAttribute("Squats"))
        or 0

    local goal =
        tonumber(machine:GetAttribute("Goal"))
        or 0

    return multiplier, squats, goal
end

Gym.gymMachineNeedsReenter = function()
    local machine = Runtime.GymMachineAnchor

    if not machine
        or not machine.Parent
        or not machine:IsDescendantOf(workspace)
    then
        return true
    end

    if Gym.currentLiftMachineMultiplier() <= 1 then
        return true
    end

    local tool = equippedWeightTool()

    if not tool
        or tool.Parent ~= character()
        or not hasTag(tool, "SquatTool")
    then
        return true
    end

    return false
end

Gym.gymTimerText = function(seconds)
    local machine = Runtime.GymMachineAnchor
    local multiplier, squats, goal =
        Gym.gymMachineProgress(machine)

    if goal > 0 and multiplier < 5 then
        return (
            "x%.0f • %.0f/%.0f lifts"
        ):format(
            multiplier,
            squats,
            goal
        )
    end

    if multiplier >= 5 then
        return "x5 MAX Lift Speed"
    end

    return "Lift Machine active"
end

Gym.handleGymTimeEvent = function()
    if not Config.AutoGymTime
        or roundActive()
        or Runtime.PendingRewardPlacement
    then
        return false
    end

    local active, _, machine =
        Gym.gymTimeActive(true)

    if not active then
        return false
    end

    Runtime.GymEventPriority = true
    Runtime.InTraining = true

    if Runtime.GymEventStartedAt <= 0 then
        Runtime.GymEventStartedAt =
            os.clock()

        Runtime.GymTrainingStartPower =
            currentKickPower()

        Runtime.GymTrainingGained = 0
        Runtime.GymTrainingRate = nil
    end

    if machine then
        Runtime.GymMachineAnchor = machine
    end

    Gym.enterGymMachine(true)

    local lastPower = currentKickPower()
    local lastRateAt = os.clock()
    local lastMachineCheck = 0

    while Runtime.Alive
        and Config.Master
        and Config.AutoGymTime
        and not roundActive()
        and not Runtime.PendingRewardPlacement
    do
        active, _, machine =
            Gym.gymTimeActive(false)

        if not active then
            break
        end

        if machine then
            Runtime.GymMachineAnchor = machine
        end

        if Gym.gymMachineNeedsReenter()
            and os.clock() - lastMachineCheck >= 0.35
        then
            lastMachineCheck = os.clock()
            Runtime.InTraining = false
            unequipAndUnanchor()
            Runtime.InTraining = true
            Gym.enterGymMachine(true)
        else
            Gym.ensureGymTrainingTool()
        end

        clickVisibleTrainingBonusPopups(false)

        local now = os.clock()

        if now - lastRateAt >= 0.40 then
            local power = currentKickPower()
            local deltaTime =
                math.max(0.001, now - lastRateAt)

            local gained =
                math.max(0, power - lastPower)

            local rate =
                gained / deltaTime

            if rate > 0 then
                if Runtime.GymTrainingRate then
                    Runtime.GymTrainingRate =
                        Runtime.GymTrainingRate * 0.60
                        + rate * 0.40
                else
                    Runtime.GymTrainingRate = rate
                end
            end

            lastPower = power
            lastRateAt = now

            Runtime.GymTrainingGained =
                math.max(
                    0,
                    power
                    - (
                        Runtime.GymTrainingStartPower
                        or power
                    )
                )
        end

        local eventMultiplier, squats, goal =
            Gym.gymMachineProgress(
                Runtime.GymMachineAnchor
            )

        local recognized =
            Gym.currentLiftMachineMultiplier()

        local weatherSpeed =
            Gym.currentGymSpeedMultiplier()

        local weatherPower =
            Gym.currentGymPowerMultiplier()

        local progressText

        if eventMultiplier >= 5 then
            progressText = "x5 MAX"
        elseif goal > 0 then
            progressText =
                ("x%.0f %.0f/%.0f")
                    :format(
                        eventMultiplier,
                        squats,
                        goal
                    )
        else
            progressText =
                ("x%.0f")
                    :format(eventMultiplier)
        end

        setState(
            (
                "GYM TIME • %s • active x%.0f • "
                .. "+%.0f Kick • %.0f/s"
            ):format(
                progressText,
                recognized,
                Runtime.GymTrainingGained or 0,
                Runtime.GymTrainingRate or 0
            )
        )

        if weatherSpeed > 1
            or weatherPower > 1
        then
            Runtime.ExtraState =
                (
                    "Gym stack • machine x%.0f • "
                    .. "gym speed x%.0f • gym power x%.0f"
                ):format(
                    recognized,
                    weatherSpeed,
                    weatherPower
                )
        end

        if not Config.GymTimeStayUntilEnd then
            -- Optional early release only after the machine itself reaches x5.
            -- Default remains ON because x5 is the most valuable part to train.
            if eventMultiplier >= 5
                and os.clock()
                    - (Runtime.GymEventStartedAt or os.clock())
                    >= 15
            then
                break
            end
        end

        task.wait(0.025)
    end

    local stillActive =
        select(1, Gym.gymTimeActive(true))


    clickVisibleTrainingBonusPopups(true)

    Runtime.GymEventPriority = false
    Runtime.GymEventActive = false
    Runtime.InTraining = false
    Runtime.GymEventStartedAt = 0
    Runtime.GymEventTimerSeconds = nil
    Runtime.GymMachineAnchor = nil
    Runtime.GymMachinePrompt = nil
    Runtime.GymMachineSeat = nil
    Runtime.GymMachineName = nil

    unequipAndUnanchor()

    -- The whole event was already a training phase. Do not immediately perform
    -- another regular training burst before the next Max Distance kick.
    Runtime.KicksSinceTraining = 0
    Runtime.LastTrainingCompletedAt =
        os.clock()

    Runtime.NeedsImmediateTraining = false

    if stillActive then
        setState(
            "Gym Time x5 phase released • resuming farm"
        )
    else
        setState(
            (
                "Gym Time ended • +%.0f Kick gained • "
                .. "resuming Max Distance"
            ):format(
                Runtime.GymTrainingGained or 0
            )
        )
    end

    return true
end


local function speedCostForLevel(level)
    level = math.max(0, math.floor(tonumber(level) or 0))
    local adjusted = level - 4
    if adjusted <= 0 then
        return 0
    end
    return 50 * (1.45 ^ (adjusted - 1))
end

local function getAffordableSpeedCount(level, budget, maxCount)
    level = math.max(0, math.floor(tonumber(level) or 0))
    budget = math.max(0, tonumber(budget) or 0)
    maxCount = math.max(1, math.floor(tonumber(maxCount) or 250))

    local spent = 0
    local count = 0

    while count < maxCount do
        local cost = speedCostForLevel(level + count)
        if spent + cost > budget then
            break
        end
        spent = spent + cost
        count = count + 1
    end

    return count, spent
end

local function buySpeedOnce(targetLevel)
    if not Config.AutoBuySpeed or roundActive() then
        return false
    end
    if os.clock() - Runtime.LastSpeedAction < 0.35 then
        return false
    end

    local level = currentSpeedLevel()
    if targetLevel and level >= targetLevel then
        return false
    end

    local balance = currentBalance()
    local budget
    local maxCount

    if targetLevel then
        budget = balance
        maxCount = math.max(1, targetLevel - level)
    else
        budget = balance * math.clamp(tonumber(Config.SpeedSpendFraction) or 0.20, 0.01, 1)
        maxCount = 100
    end

    local added = getAffordableSpeedCount(level, budget, maxCount)
    if added <= 0 then
        return false
    end

    if targetLevel then
        added = math.min(added, math.max(0, targetLevel - level))
    end
    if added <= 0 then
        return false
    end

    local shops = workspace:FindFirstChild("Shops")
    local shop = shops and shops:FindFirstChild("SpeedShop")
    local touch = shop and shop:FindFirstChild("TouchPart")

    -- Only tutorial needs the visible shop visit.
    if tutorialStep() == 15 and touch then
        moveTo(touch, 6)
    end

    Runtime.LastSpeedAction = os.clock()
    setState(("Buying +%d speed"):format(added))
    fireServer("SPEED_UPGRADE", added)
    task.wait(0.18)
    return true
end

local function tryRebirth()
    if not Config.AutoRebirth or roundActive() then
        return false
    end
    if os.clock() - Runtime.LastRebirth < 2 then
        return false
    end

    local level = currentRebirthLevel()
    if level >= 10 then
        return false
    end

    local requirement = 10 ^ (level + 3)
    if currentKickPower() < requirement then
        return false
    end

    Runtime.LastRebirth = os.clock()
    setState("Rebirthing")
    fireServer("RebirthRequest")
    task.wait(1.2)
    return true
end

-- ============================================================================
-- Tutorial automation using the tutorial's real conditions, not forced step flags.
-- ============================================================================

local function showWeightUI()
    local frames = findFrames()
    local ui = frames and frames:FindFirstChild("WeightUI")
    if ui then
        ui.Visible = true
        return true
    end
    return false
end

local function showSpeedUI()
    local frames = findFrames()
    local ui = frames and frames:FindFirstChild("SpeedUpgrades")
    if ui then
        ui.Visible = true
        return true
    end
    return false
end

local function tutorialPlacedIndex()
    for _, entry in ipairs(plotSlots()) do
        local id = entry.Part and entry.Part:GetAttribute("ID")
        if id and BrainrotData[id] then
            return entry.Index
        end
    end
    return nil
end

local function handleTutorial()
    if not Config.AutoTutorial then
        return false
    end

    local step = tutorialStep()
    if not step or step < 1 or step > 17 then
        return false
    end

    if step == 1 then
        setState("Tutorial: welcome")
        task.wait(0.5)
        return true
    elseif step == 2 then
        setState("Tutorial: go to kick zone")
        ensureKickZone()
        task.wait(0.2)
        return true
    elseif step == 3 then
        setState("Tutorial: start kick")
        local old = Config.AutoKick
        Config.AutoKick = true
        performKick()
        Config.AutoKick = old
        return true
    elseif step == 4 then
        setState("Tutorial: perfect kick")
        if minigameActive() then
            finishKickMinigame()
        else
            local old = Config.AutoKick
            Config.AutoKick = true
            performKick()
            Config.AutoKick = old
        end
        task.wait(0.2)
        return true
    elseif step == 5 then
        setState("Tutorial: RUN reward back")
        if runPhaseVisible(true) then
            Runtime.PendingRewardPlacement = true
        end
        turboCollectKickReward()
        task.wait(0.08)
        return true
    elseif step == 6 then
        setState("Tutorial: equip brainrot")
        local tool = bestBrainrotTool()
        if tool then
            equipTool(tool)
        end
        task.wait(0.2)
        return true
    elseif step == 7 then
        setState("Tutorial: place brainrot")
        placeBestBrainrot(true, 5)
        task.wait(0.25)
        return true
    elseif step == 8 then
        setState("Tutorial: collect cash")
        Runtime.LastCashCollect = 0
        collectBaseCash()
        task.wait(0.2)
        return true
    elseif step == 9 then
        setState("Tutorial: buy first upgrade")
        local index = tutorialPlacedIndex()
        if index then
            Runtime.LastUpgrade = 0
            upgradeOneBrainrot(index)
        end
        task.wait(0.25)
        return true
    elseif step == 10 then
        setState("Tutorial: weight shop")
        local shops = workspace:FindFirstChild("Shops")
        local shop = shops and shops:FindFirstChild("WeightShop")
        local touch = shop and shop:FindFirstChild("TouchPart")
        if touch then
            moveTo(touch, 8)
        end
        task.wait(0.25)
        return true
    elseif step == 11 then
        setState("Tutorial: open weight shop")
        showWeightUI()
        task.wait(0.3)
        return true
    elseif step == 12 then
        setState("Tutorial: buy wooden stick")
        local old = Config.AutoBuyWeights
        Config.AutoBuyWeights = true
        Runtime.LastWeightAction = 0
        buyOrEquipBestWeight(true)
        Config.AutoBuyWeights = old
        task.wait(0.3)
        return true
    elseif step == 13 then
        setState("Tutorial: equip wooden stick")
        local tool = equippedWeightTool()
        if tool then
            equipTool(tool)
        else
            local old = Config.AutoBuyWeights
            Config.AutoBuyWeights = true
            Runtime.LastWeightAction = 0
            buyOrEquipBestWeight(true)
            Config.AutoBuyWeights = old
        end
        task.wait(0.2)
        return true
    elseif step == 14 then
        setState("Tutorial: train to 100 kick power")
        if currentKickPower() < 100 then
            local oldTrain = Config.AutoTrain
            local oldBuy = Config.AutoBuyWeights
            Config.AutoTrain = true
            Config.AutoBuyWeights = true
            trainFor(0.8, 100)
            Config.AutoTrain = oldTrain
            Config.AutoBuyWeights = oldBuy
        end
        task.wait(0.1)
        return true
    elseif step == 15 then
        setState("Tutorial: speed shop")
        local shops = workspace:FindFirstChild("Shops")
        local shop = shops and shops:FindFirstChild("SpeedShop")
        local touch = shop and shop:FindFirstChild("TouchPart")
        if touch then
            moveTo(touch, 8)
        end
        showSpeedUI()
        task.wait(0.3)
        return true
    elseif step == 16 then
        setState("Tutorial: buy 5 speed upgrades")
        if currentSpeedLevel() < 5 then
            local old = Config.AutoBuySpeed
            Config.AutoBuySpeed = true
            Runtime.LastSpeedAction = 0
            buySpeedOnce(5)
            Config.AutoBuySpeed = old
        end
        task.wait(0.15)
        return true
    elseif step == 17 then
        setState("Tutorial: return to kick zone")
        local frames = findFrames()
        if frames then
            local speed = frames:FindFirstChild("SpeedUpgrades")
            if speed then speed.Visible = false end
            local weight = frames:FindFirstChild("WeightUI")
            if weight then weight.Visible = false end
        end
        ensureKickZone()
        task.wait(0.25)
        return true
    end

    return false
end

-- ============================================================================
-- Main loop
-- ============================================================================

local function maintenancePass()
    if Runtime.PendingRewardPlacement then
        setState("Pending kick reward • finishing collect/place cycle")
        placeFreshKickReward()
        return true
    end

    if tryRebirth() then
        return true
    end

    if openPlacedLuckyBlock() then
        return true
    end

    if openLuckyBlockTool() then
        return true
    end

    if reconcileBestInventoryBrainrots(6) > 0 then
        return true
    end

    return false
end

local function farmIteration()
    if not Config.Master then
        setState("Paused")
        task.wait(0.25)
        return
    end

    if not waitAlive(2) then
        setState("Waiting for character")
        task.wait(0.4)
        return
    end

    if handleTutorial() then
        return
    end

    if runPhaseVisible(true) then
        Runtime.PendingRewardPlacement = true
        Runtime.PostKickPhase = "Run"
        captureActualKickDistance()
        Runtime.DismissCurrentReward = false
        turboCollectKickReward()
        task.wait(0.05)
        return
    end

    -- Post-return repair. KickEventEnded is authoritative once RUN/minigame are
    -- gone, even if the game's InGame attribute has not cleared yet.
    if Runtime.LastKickEndedAt > 0
        and os.clock() - Runtime.LastKickEndedAt < 4
        and not minigameActive()
        and not runPhaseVisible(false)
    then
        Runtime.RoundActive = false
        Runtime.SawKickPhase2 = false
        stopAutomatedWalk()
        unequipAndUnanchor()
    end

    if roundActive() then
        setState("Kick lifecycle active • waiting for RUN/result")
        task.wait(0.05)
        return
    end

    if Runtime.PendingRewardPlacement then
        setState("Finishing returned reward before training")
        placeFreshKickReward()
        return
    end

    if Config.AutoGymTime
        and select(1, Gym.gymTimeActive(true))
    then
        Gym.handleGymTimeEvent()
        return
    end

    if Runtime.NeedsImmediateTraining
        and Config.AutoTrain
        and Config.AutoKick
    then
        if tryRebirth() then
            Runtime.NeedsImmediateTraining = true
            return
        end

        -- Placement gets absolute priority over the next training/kick.
        if reconcileBestInventoryBrainrots(6) > 0 then
            Runtime.NeedsImmediateTraining = true
            return
        end

        -- The background worker can be starved by fast kick cycles. Give it a
        -- tiny guaranteed window here: at most two confirmed upgrades.
        if Config.AutoUpgradeBrainrots then
            upgradeBrainrotsBatch(6)
        end

        setState("Returned • throughput training check")

        if Config.AdaptiveTraining then
            smartTrainingBeforeKick()
        elseif Config.TrainBetweenKicks > 0
            and (Runtime.KicksSinceTraining or 0) >=
                math.max(
                    1,
                    tonumber(Config.TrainingBurstEveryKicks) or 2
                )
        then
            trainFor(Config.TrainBetweenKicks, nil)
            unequipAndUnanchor()
        end

        Runtime.NeedsImmediateTraining = false

        -- Training itself can cross a rebirth threshold.
        if tryRebirth() then
            Runtime.NeedsImmediateTraining = true
            return
        end

        if Config.AutoKick and not roundActive() then
            performKick()
        end
        return
    end

    if maintenancePass() then
        return
    end

    if Config.AutoTrain and Config.AutoKick then
        if Config.AdaptiveTraining then
            smartTrainingBeforeKick()
        elseif Config.TrainBetweenKicks > 0 then
            trainFor(Config.TrainBetweenKicks, nil)
            unequipAndUnanchor()
        end
    elseif Config.AutoTrain and not Config.AutoKick then
        trainFor(1.5, nil)
    end

    if Config.AutoKick then
        performKick()
    else
        setState("Progression maintenance")
        task.wait(0.25)
    end
end

local function farmLoop()
    while Runtime.Alive do
        local ok = pcall(farmIteration)

        if not ok then
            Runtime.Busy = false

            pcall(releaseMovementKeys)
            pcall(stopAutomatedWalk)
            pcall(unequipAndUnanchor)

            if Runtime.LastKickEndedAt > 0
                and not runPhaseVisible(false)
                and not minigameActive()
            then
                Runtime.RoundActive = false
                Runtime.SawKickPhase2 = false

                if Runtime.PendingRewardPlacement
                    and os.clock()
                        - Runtime.LastKickEndedAt
                        > 4
                then
                    Runtime.PendingRewardPlacement = false
                    Runtime.NeedsImmediateTraining = true
                end
            end

            task.wait(0.35)
        end
    end
end


Runtime.TryBaseSlotUpgrade = function()
    if not Config.AutoBaseSlots
        or roundActive()
        or Runtime.Busy
    then
        return false
    end

    local added = math.clamp(
        math.floor(tonumber(Runtime.AddedSlots) or 0),
        0,
        20
    )

    if added >= 20 then
        return false
    end

    if os.clock() - (Runtime.LastBaseUpgrade or 0) < 0.75 then
        return false
    end

    local capacity = 10 + added
    local occupied = 0

    for _, entry in ipairs(plotSlots()) do
        if entry.Part then
            occupied = occupied + 1
        end
    end

    if occupied < capacity - 1 then
        return false
    end

    local cost = SlotUpgradePrices[added + 1]

    if not cost or currentBalance() < cost then
        return false
    end

    Runtime.LastBaseUpgrade = os.clock()
    Runtime.ExtraState = (
        "Buying usable plot slot %d • $%.0f"
    ):format(capacity + 1, cost)

    return fireServer("bs_upgrade")
end

Runtime.CountToolsNamed = function(name)
    local count = 0

    for _, tool in ipairs(allTools()) do
        if tool:IsA("Tool") and tool.Name == name then
            count = count + 1
        end
    end

    return count
end

Runtime.TrySchoolCraft = function()
    if not Config.AutoSchoolCraft
        or roundActive()
        or Runtime.Busy
    then
        return false
    end

    if os.clock() - (Runtime.LastSchoolCraft or 0) < 1 then
        return false
    end

    for index = #SchoolCraftRecipes, 1, -1 do
        local recipe = SchoolCraftRecipes[index]
        local canCraft =
            type(recipe) == "table"
            and (Runtime.SchoolScore or 0)
                >= (recipe.Price or math.huge)

        if canCraft then
            for _, requirement in ipairs(recipe.Requirements or {}) do
                if Runtime.CountToolsNamed(requirement.Name)
                    < (requirement.Count or 1)
                then
                    canCraft = false
                    break
                end
            end
        end

        if canCraft then
            Runtime.LastSchoolCraft = os.clock()
            fireServer("b2s_Craft", index)
            task.wait(0.35)
            return true
        end
    end

    return false
end

Runtime.RequestFreeItemCheck = function()
    if not Config.AutoClaimFreeItem
        or Runtime.FreeItemClaimed == true
    then
        return false
    end

    if os.clock() - (Runtime.FreeItemCheckedAt or 0) < 5 then
        return false
    end

    Runtime.FreeItemCheckedAt = os.clock()
    return fireServer("CheckFree")
end

Runtime.ClaimOfflineIfVisible = function()
    if not Config.AutoClaimOffline
        or Runtime.OfflineClaimAttempted
    then
        return false
    end

    local frames = findFrames()
    local offline =
        frames and frames:FindFirstChild("OfflineFrame")

    if not offline or not offline.Visible then
        return false
    end

    Runtime.OfflineClaimAttempted = true
    return fireServer("Offline_Claim")
end

Runtime.TryGroupGift = function()
    if not Config.AutoGroupGift
        or Runtime.GroupGiftAttempted
    then
        return false
    end

    Runtime.GroupGiftAttempted = true

    if not workspace:FindFirstChild("FreeGift") then
        return false
    end

    return fireServer("GroupClaim")
end

Runtime.AutoWheelSpin = function()
    if not Config.AutoWheelSpins then
        return false
    end

    if os.clock() < (Runtime.WheelBusyUntil or 0) then
        return false
    end

    if os.clock() - (Runtime.LastWheelRequest or 0) < 5.4 then
        return false
    end

    local spins = currentWheelSpins()

    if spins <= 0 then
        return false
    end

    Runtime.LastWheelRequest = os.clock()
    Runtime.WheelBusyUntil = os.clock() + 5.25
    return fireServer("RequestSpin")
end

Runtime.AutoClaimBattlePass = function()
    if not Config.AutoBattlePassClaims then
        return false
    end

    local state = Runtime.BattlePassState

    if type(state) ~= "table"
        or typeof(state.XP) ~= "number"
    then
        return false
    end

    if os.clock() - (Runtime.LastBattlePassClaim or 0) < 10 then
        return false
    end

    Runtime.LastBattlePassClaim = os.clock()

    state.UnlockedFreeRewards =
        state.UnlockedFreeRewards or {}
    state.UnlockedPremiumRewards =
        state.UnlockedPremiumRewards or {}
    state.UnlockedBonusRewards =
        state.UnlockedBonusRewards or {}

    local did = false

    for id = 1, 15 do
        local needed = BattlePassFreeXP[id]

        if needed
            and state.XP >= needed
            and not table.find(state.UnlockedFreeRewards, id)
        then
            local ok, claimed =
                invokeServer("BattlePassAttemptClaim", id, "Free")

            if ok and claimed then
                table.insert(state.UnlockedFreeRewards, id)
                did = true
            end

            task.wait(0.04)
        end

        if state.HasPremium
            and needed
            and state.XP >= needed
            and not table.find(state.UnlockedPremiumRewards, id)
        then
            local ok, claimed =
                invokeServer("BattlePassAttemptClaim", id, "Premium")

            if ok and claimed then
                table.insert(state.UnlockedPremiumRewards, id)
                did = true
            end

            task.wait(0.04)
        end
    end

    for id = 1, 5 do
        local needed = BattlePassBonusXP[id]

        if needed
            and state.XP >= needed
            and not table.find(state.UnlockedBonusRewards, id)
        then
            local ok, claimed =
                invokeServer("BattlePassAttemptBonusClaim", id, "Bonus")

            if ok and claimed then
                table.insert(state.UnlockedBonusRewards, id)
                did = true
            end

            task.wait(0.04)
        end
    end

    return did
end

Runtime.AutoClaimMailboxRewards = function()
    if not Config.AutoMailboxRewards then
        return false
    end

    if os.clock() - (Runtime.LastMailboxClaimAt or 0) < 60 then
        return false
    end

    Runtime.LastMailboxClaimAt = os.clock()

    local ids = {
        "2586061570371093144",
        "7058748194620048013",
        "5736338153371992847",
    }

    local did = false

    for _, eventID in ipairs(ids) do
        if fireServer("MailClaim", eventID) then
            did = true
        end
        task.wait(0.03)
    end

    return did
end

Runtime.RewardsBackgroundIteration = function()
    if not Runtime.Alive then
        return
    end

    Runtime.RequestFreeItemCheck()
    Runtime.ClaimOfflineIfVisible()
    Runtime.TryGroupGift()
    Runtime.AutoClaimMailboxRewards()

    if not roundActive() and not Runtime.Busy then
        Runtime.AutoWheelSpin()
        Runtime.AutoClaimBattlePass()
    end
end

Runtime.RewardsBackgroundLoop = function()
    while Runtime.Alive do
        pcall(Runtime.RewardsBackgroundIteration)
        task.wait(0.30)
    end
end


Runtime.FastProgressionBackgroundIteration = function()
    if not Runtime.Alive or not Config.Master then
        return
    end

    if roundActive() or Runtime.Busy then
        return
    end

    collectBaseCash()

    if Runtime.GymEventPriority then
        return
    end

    if Runtime.InTraining then
        -- Cash collection is safe, but do not move/equip/sell/upgrade while the
        -- training loop owns the current weight.
        return
    end

    Runtime.TryBaseSlotUpgrade()

    -- Never sell/upgrade around stale inventory. First make sure every strong
    -- inventory brainrot has been compared against the exact current plot.
    if reconcileBestInventoryBrainrots(4) > 0 then
        return
    end

    autoSellLeftoverBrainrots()

    if not Runtime.Busy then
        upgradeBrainrotsBatch()

        if Config.AutoBuySpeed then
            buySpeedOnce(nil)
        end

        if Config.AutoKickStyles then
            buyOrEquipBestKickStyle()
        end

        -- Weight buying/equipping is handled immediately before training.
        -- Keeping a weight equipped while idle blocks Timmy's B_Sell held-tool
        -- path and can interfere with placement, so do not equip it here.

        if Config.AutoSchoolCraft and not Runtime.PendingRewardPlacement then
            Runtime.TrySchoolCraft()
        end
    end
end

Runtime.FastProgressionBackgroundLoop = function()
    while Runtime.Alive do
        pcall(Runtime.FastProgressionBackgroundIteration)
        task.wait(0.55)
    end
end


-- ============================================================================
-- UI
-- ============================================================================

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV Hub · Kick a Lucky Block",
    GuiName = "RAINZXDEV_KickALuckyBlock",
    ConfigId = "KickALuckyBlock",
    Width = 500,
    Height = 560,
})

local FarmTab = Window:CreateTab("Autofarm")
local ProgressTab = Window:CreateTab("Progress")
local RewardsTab = Window:CreateTab("Rewards")
local EventsTab = Window:CreateTab("Events")
local TutorialTab = Window:CreateTab("Tutorial")
local SettingsTab = Window:CreateTab("Settings")

FarmTab:CreateSection("Smart Autofarm")
FarmTab:CreateToggle({
    Name="Enable Smart Autofarm",
    CurrentValue=Config.Master,
    Flag="KALB_Master_v30",
    Callback=function(v)
        Config.Master=v
        if not v then
            pcall(releaseMovementKeys)
            pcall(stopAutomatedWalk)
        end
    end
})
FarmTab:CreateToggle({Name="Auto Kick Lucky Blocks", CurrentValue=Config.AutoKick, Flag="KALB_AutoKick", Callback=function(v) Config.AutoKick=v end})
FarmTab:CreateToggle({Name="Perfect Kick", CurrentValue=Config.PerfectKick, Flag="KALB_PerfectKick", Callback=function(v) Config.PerfectKick=v end})
FarmTab:CreateToggle({Name="Auto Return Reward To Base", CurrentValue=Config.TurboCollect, Flag="KALB_ReturnReward_v22", Callback=function(v) Config.TurboCollect=v end})

FarmTab:CreateDropdown({
    Name="Travel Mode",
    Options={"Walk","Teleport (Safe)","Manual"},
    CurrentOption={normalizeTravelMode(Config.TravelMode)},
    Flag="KALB_TravelMode_v16",
    Callback=function(option)
        local value = type(option)=="table" and option[1] or option
        Config.TravelMode = normalizeTravelMode(value)
    end,
})

FarmTab:CreateDropdown({
    Name="Kick Distance Mode",
    Options={"Fast Rarity","Balanced Rarity","Max Distance"},
    CurrentOption={Config.FarmKickMode},
    Flag="KALB_FarmKickMode_v453",
    Callback=function(option)
        local value = type(option)=="table" and option[1] or option
        Config.FarmKickMode = tostring(value or "Max Distance")
    end,
})

FarmTab:CreateSlider({
    Name="Rarity Distance Buffer",
    Range={5,50}, Increment=1,
    CurrentValue=Config.FarmRarityBuffer,
    Suffix=" studs",
    Flag="KALB_RarityBuffer_v43",
    Callback=function(v) Config.FarmRarityBuffer=v end,
})


FarmTab:CreateSlider({
    Name="Open Inventory Lucky Block Every",
    Range={1,10}, Increment=1,
    CurrentValue=Config.LuckyBlockEveryKicks,
    Suffix=" kicks",
    Flag="KALB_LuckyCadence_v44",
    Callback=function(v) Config.LuckyBlockEveryKicks=v end,
})

FarmTab:CreateSlider({
    Name="Post-Kick Cooldown", Range={0.2,2}, Increment=0.1, CurrentValue=Config.KickDelay,
    Suffix=" s", Flag="KALB_KickDelay_v464", Callback=function(v) Config.KickDelay=v end,
})


ProgressTab:CreateSection("Brainrots & Cash")
ProgressTab:CreateToggle({Name="Auto Open Lucky Blocks", CurrentValue=Config.AutoOpenLuckyBlocks, Flag="KALB_OpenBlocks", Callback=function(v) Config.AutoOpenLuckyBlocks=v end})
ProgressTab:CreateToggle({Name="Auto Place Best Brainrot", CurrentValue=Config.AutoPlaceBest, Flag="KALB_PlaceBest", Callback=function(v) Config.AutoPlaceBest=v end})
ProgressTab:CreateToggle({Name="Replace Weaker Placed Brainrots", CurrentValue=Config.ReplaceWeak, Flag="KALB_ReplaceWeak", Callback=function(v) Config.ReplaceWeak=v end})
ProgressTab:CreateSlider({Name="Base Quality Improvement", Range={1,3}, Increment=0.05, CurrentValue=Config.ReplaceThreshold, Suffix="x", Flag="KALB_BaseQualityThreshold_v462", Callback=function(v) Config.ReplaceThreshold=v end})
ProgressTab:CreateToggle({Name="Auto Collect Base Cash", CurrentValue=Config.AutoCollectCash, Flag="KALB_CollectCash", Callback=function(v) Config.AutoCollectCash=v end})
ProgressTab:CreateSlider({Name="Cash Collect Interval", Range={0.25,10}, Increment=0.25, CurrentValue=Config.CashCollectInterval, Suffix=" s", Flag="KALB_CashInterval", Callback=function(v) Config.CashCollectInterval=v end})
ProgressTab:CreateToggle({Name="Auto Upgrade Brainrots", CurrentValue=Config.AutoUpgradeBrainrots, Flag="KALB_UpgradeBrainrots_v457", Callback=function(v) Config.AutoUpgradeBrainrots=v end})
ProgressTab:CreateSlider({
    Name="Brainrot Upgrade Cash Budget",
    Range={10,100}, Increment=5,
    CurrentValue=math.floor(Config.BrainrotUpgradeSpendFraction*100+0.5),
    Suffix="%",
    Flag="KALB_UpgradeBudget_v458",
    Callback=function(v)
        Config.BrainrotUpgradeSpendFraction =
            math.clamp(v/100,0.10,1)
    end,
})
ProgressTab:CreateSlider({
    Name="Max Upgrades Per Background Pass",
    Range={2,30}, Increment=1,
    CurrentValue=Config.BrainrotUpgradeMaxPerPass,
    Flag="KALB_UpgradeBatch_v458",
    Callback=function(v)
        Config.BrainrotUpgradeMaxPerPass =
            math.max(1, math.floor(v))
    end,
})
ProgressTab:CreateSlider({
    Name="Upgradeable Plot Fraction",
    Range={25,100}, Increment=5,
    CurrentValue=math.floor(Config.BrainrotUpgradeKeepFraction*100+0.5),
    Suffix="%",
    Flag="KALB_UpgradeKeep_v458",
    Callback=function(v)
        Config.BrainrotUpgradeKeepFraction =
            math.clamp(v/100,0.25,1)
    end,
})
ProgressTab:CreateToggle({
    Name="Auto Sell Leftover Inventory Brainrots",
    CurrentValue=Config.AutoSellLeftovers,
    Flag="KALB_AutoSell_v45",
    Callback=function(v) Config.AutoSellLeftovers=v end,
})
ProgressTab:CreateDropdown({
    Name="Auto Sell Method",
    Options={"Sell All UI","Selective Individual"},
    CurrentOption={Config.SellMode},
    Flag="KALB_SellMode_v459",
    Callback=function(option)
        local value =
            type(option)=="table"
            and option[1]
            or option

        Config.SellMode =
            tostring(value or "Sell All UI")
    end,
})
ProgressTab:CreateToggle({
    Name="Use Native Seller Teleport",
    CurrentValue=Config.SellUseNativeSellerTeleport,
    Flag="KALB_SellerTeleport_v45",
    Callback=function(v) Config.SellUseNativeSellerTeleport=v end,
})
ProgressTab:CreateSlider({
    Name="Max Brainrots Per Sell Visit",
    Range={1,20}, Increment=1,
    CurrentValue=Config.SellMaxPerVisit,
    Flag="KALB_SellBatch_v458",
    Callback=function(v) Config.SellMaxPerVisit=v end,
})

ProgressTab:CreateSection("Player Progression")
ProgressTab:CreateToggle({Name="Auto Buy / Equip Best Weight", CurrentValue=Config.AutoBuyWeights, Flag="KALB_BestWeight", Callback=function(v) Config.AutoBuyWeights=v end})
ProgressTab:CreateToggle({Name="Auto Train Kick Power", CurrentValue=Config.AutoTrain, Flag="KALB_AutoTrain", Callback=function(v) Config.AutoTrain=v end})
ProgressTab:CreateToggle({
    Name="Adaptive Distance Training",
    CurrentValue=Config.AdaptiveTraining,
    Flag="KALB_AdaptiveTrain_v44",
    Callback=function(v) Config.AdaptiveTraining=v end,
})
ProgressTab:CreateToggle({
    Name="Smart Throughput Training",
    CurrentValue=Config.SmartTrainingCadence,
    Flag="KALB_SmartTrain_v44",
    Callback=function(v) Config.SmartTrainingCadence=v end,
})
ProgressTab:CreateSlider({
    Name="Training Burst Every",
    Range={1,6}, Increment=1,
    CurrentValue=Config.TrainingBurstEveryKicks,
    Suffix=" kicks",
    Flag="KALB_TrainCadence_v44",
    Callback=function(v) Config.TrainingBurstEveryKicks=v end,
})
ProgressTab:CreateSlider({
    Name="Training Burst Length",
    Range={1,8}, Increment=0.5,
    CurrentValue=Config.TrainingBurstSeconds,
    Suffix=" s",
    Flag="KALB_TrainBurst_v44",
    Callback=function(v) Config.TrainingBurstSeconds=v end,
})
ProgressTab:CreateSlider({
    Name="Next Rarity Sprint Limit",
    Range={3,15}, Increment=1,
    CurrentValue=Config.NextRaritySprintMaxSeconds,
    Suffix=" s",
    Flag="KALB_RaritySprint_v44",
    Callback=function(v) Config.NextRaritySprintMaxSeconds=v end,
})
ProgressTab:CreateDropdown({
    Name="Kick Style Selection",
    Options={"Throughput","Max Multiplier"},
    CurrentOption={Config.KickStyleMode},
    Flag="KALB_StyleMode_v44",
    Callback=function(option)
        local value = type(option)=="table" and option[1] or option
        Config.KickStyleMode=tostring(value or "Throughput")
    end,
})
ProgressTab:CreateSlider({
    Name="Target Distance Gain / Kick",
    Range={5,40}, Increment=1,
    CurrentValue=Config.AdaptiveDistanceGain,
    Suffix=" studs",
    Flag="KALB_AdaptiveDistance_v44",
    Callback=function(v) Config.AdaptiveDistanceGain=v end,
})
ProgressTab:CreateSlider({
    Name="Minimum Adaptive Training Time",
    Range={1,12}, Increment=1,
    CurrentValue=Config.AdaptiveMinTrainSeconds,
    Suffix=" s",
    Flag="KALB_AdaptiveMinTrain_v44",
    Callback=function(v) Config.AdaptiveMinTrainSeconds=v end,
})
ProgressTab:CreateSlider({
    Name="Max Adaptive Training Time",
    Range={4,25}, Increment=1,
    CurrentValue=Config.AdaptiveMaxTrainSeconds,
    Suffix=" s",
    Flag="KALB_AdaptiveMaxTrain_v44",
    Callback=function(v) Config.AdaptiveMaxTrainSeconds=v end,
})
ProgressTab:CreateSlider({
    Name="Fixed Train Time (Adaptive Off)",
    Range={0,15}, Increment=0.25,
    CurrentValue=Config.TrainBetweenKicks,
    Suffix=" s",
    Flag="KALB_TrainBetween_v44",
    Callback=function(v) Config.TrainBetweenKicks=v end,
})
ProgressTab:CreateToggle({Name="Auto Buy Speed", CurrentValue=Config.AutoBuySpeed, Flag="KALB_AutoSpeed", Callback=function(v) Config.AutoBuySpeed=v end})
ProgressTab:CreateToggle({Name="Auto Rebirth", CurrentValue=Config.AutoRebirth, Flag="KALB_AutoRebirth", Callback=function(v) Config.AutoRebirth=v end})
ProgressTab:CreateToggle({Name="Auto Buy / Equip Best Kick Style", CurrentValue=Config.AutoKickStyles, Flag="KALB_KickStyles_v40", Callback=function(v) Config.AutoKickStyles=v end})

ProgressTab:CreateToggle({Name="Auto Buy Plot Slots When Nearly Full", CurrentValue=Config.AutoBaseSlots, Flag="KALB_BaseSlots_v40", Callback=function(v) Config.AutoBaseSlots=v end})
ProgressTab:CreateSlider({
    Name="Speed Spend Budget", Range={5,100}, Increment=5,
    CurrentValue=math.floor(Config.SpeedSpendFraction*100+0.5), Suffix="%",
    Flag="KALB_SpeedBudget_v43",
    Callback=function(v) Config.SpeedSpendFraction=math.clamp(v/100,0.05,1) end,
})

RewardsTab:CreateSection("Automatic Claims")
RewardsTab:CreateToggle({Name="Auto Claim Free Shop Brainrot", CurrentValue=Config.AutoClaimFreeItem, Flag="KALB_FreeItem_v40", Callback=function(v) Config.AutoClaimFreeItem=v; Runtime.FreeItemCheckedAt=0 end})
RewardsTab:CreateToggle({Name="Auto Claim Offline Earnings", CurrentValue=Config.AutoClaimOffline, Flag="KALB_Offline_v40", Callback=function(v) Config.AutoClaimOffline=v; if v then Runtime.OfflineClaimAttempted=false end end})
RewardsTab:CreateToggle({Name="Auto Spin Free / Owned Wheel Spins", CurrentValue=Config.AutoWheelSpins, Flag="KALB_Wheel_v40", Callback=function(v) Config.AutoWheelSpins=v end})
RewardsTab:CreateToggle({Name="Auto Claim Training Bonus Popups", CurrentValue=Config.AutoKickBonuses, Flag="KALB_KickBonus_v40", Callback=function(v) Config.AutoKickBonuses=v end})
RewardsTab:CreateToggle({Name="Auto Claim Battle Pass Rewards", CurrentValue=Config.AutoBattlePassClaims, Flag="KALB_BattlePass_v40", Callback=function(v) Config.AutoBattlePassClaims=v; Runtime.LastBattlePassClaim=0 end})
RewardsTab:CreateToggle({
    Name="Auto Check Mailbox Event Rewards",
    CurrentValue=Config.AutoMailboxRewards,
    Flag="KALB_Mailbox_v45",
    Callback=function(v)
        Config.AutoMailboxRewards=v
        Runtime.LastMailboxClaimAt=0
    end,
})
RewardsTab:CreateToggle({Name="Try Group / Favorite Gift (If Eligible)", CurrentValue=Config.AutoGroupGift, Flag="KALB_GroupGift_v40", Callback=function(v) Config.AutoGroupGift=v; if v then Runtime.GroupGiftAttempted=false end end})

EventsTab:CreateSection("Gym Time / Lift Machine")
EventsTab:CreateToggle({
    Name="Prioritize Gym Time",
    CurrentValue=Config.AutoGymTime,
    Flag="KALB_GymTime_v454",
    Callback=function(v) Config.AutoGymTime=v end,
})
EventsTab:CreateToggle({
    Name="Stay Until Event Ends",
    CurrentValue=Config.GymTimeStayUntilEnd,
    Flag="KALB_GymStay_v454",
    Callback=function(v) Config.GymTimeStayUntilEnd=v end,
})
EventsTab:CreateDropdown({
    Name="Gym Event Travel",
    Options={"Teleport (Safe)","Walk","Manual"},
    CurrentOption={Config.GymEventTravelMode},
    Flag="KALB_GymTravel_v454",
    Callback=function(option)
        local value =
            type(option)=="table"
            and option[1]
            or option

        Config.GymEventTravelMode =
            normalizeTravelMode(
                tostring(value or "Teleport (Safe)")
            )
    end,
})

EventsTab:CreateSection("Back To School")
EventsTab:CreateToggle({Name="Auto Craft Highest School Recipe", CurrentValue=Config.AutoSchoolCraft, Flag="KALB_SchoolCraft_v40", Callback=function(v) Config.AutoSchoolCraft=v end})
EventsTab:CreateToggle({Name="Auto Solve Math Event IDs", CurrentValue=Config.AutoSchoolMath, Flag="KALB_SchoolMath_v40", Callback=function(v) Config.AutoSchoolMath=v end})

EventsTab:CreateSection("Random Events")
EventsTab:CreateToggle({Name="Auto Claim Mighty Chest Key", CurrentValue=Config.AutoMightyChest, Flag="KALB_MightyChest_v40", Callback=function(v) Config.AutoMightyChest=v end})

TutorialTab:CreateSection("Tutorial Automation")
TutorialTab:CreateToggle({Name="Auto Follow Tutorial", CurrentValue=Config.AutoTutorial, Flag="KALB_AutoTutorial", Callback=function(v) Config.AutoTutorial=v end})

Runtime.Cleanup = function()
    if not Runtime.Alive then
        return
    end
    Runtime.Alive = false
    Config.Master = false

    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Runtime.Connections)

    pcall(releaseMovementKeys)
    pcall(stopAutomatedWalk)
    pcall(enablePlayerControls)
    unequipAndUnanchor()
end

ENV.__rainzxdev_KALB_CLEANUP = Runtime.Cleanup

SettingsTab:CreateSection("Script")
SettingsTab:CreateButton({
    Name="Unload Autofarm",
    NoConfig=true,
    Callback=function()
        Runtime.Cleanup()
        pcall(function()
            if Window and Window.Destroy then
                Window:Destroy()
            end
        end)
    end,
})


task.spawn(farmLoop)
task.spawn(Runtime.FastProgressionBackgroundLoop)
task.spawn(Runtime.RewardsBackgroundLoop)

PuckUI:Notify({
    Title="Kick a Lucky Block",
    Content="Autofarm ready • server-ready kick protection enabled",
    Duration=2,
})
