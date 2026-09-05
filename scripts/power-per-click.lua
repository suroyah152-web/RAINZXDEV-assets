--[[
    RAINZXDEV | +1 Power Per Click | Smart Autofarm v2.0 ADVANCED
    Place: 74889851913797

    Built from a static inspection of the supplied .rbxl/.rbxm export.

    Important game-native systems used by this script:
      * ClickTrainEvent                 -> power/click training
      * RebirthFunction                 -> GetState / Rebirth
      * WorldTeleportRemote             -> GetState / Go
      * UpgradeFunction                 -> GetState / Buy
      * PetFunction                     -> GetState / HatchEgg / EquipBest
      * DailyRewardFunction             -> GetState / Claim
      * QuestFunction                   -> GetState / Claim
      * GroupRewardsFunc                -> GetState / Claim
      * PlaytimeChestsFunction          -> state / claim
      * SpinWheelFunction               -> Spin
      * WallConfig / WallConfig2..5     -> cave layout / HP / payouts

    The normal game OP autoclicker uses:
      * 0.111111... sec while on a training pad
      * 0.125 / AutoClickSpeedMult away from a training pad
    Those are the default rates here too instead of blindly flooding the server.
]]

local EXPECTED_PLACE_ID = 74889851913797

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local GENV
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    GENV = ok and type(env) == "table" and env or _G
else
    GENV = _G
end

local SCRIPT_KEY = "__rainzxdev_PLUS1_POWER_SMART_FARM"
if type(GENV[SCRIPT_KEY]) == "table" and type(GENV[SCRIPT_KEY].Unload) == "function" then
    pcall(function()
        GENV[SCRIPT_KEY]:Unload()
    end)
end

-- Remove a previous copy of our GUI if an older script did not unload cleanly.
pcall(function()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, name in ipairs({
            "RAINZXDEV_Plus1Power",
            "RAINZXDEV_PowerFarm",
        }) do
            local old = pg:FindFirstChild(name)
            if old then
                old:Destroy()
            end
        end
    end
end)

-- ==========================================================================
-- PUCK UI
-- ==========================================================================

local PUCK_UI_URL = "https://raw.githubusercontent.com/RAINZXDEV/Puck-Loader/main/ui/PuckUI.lua"
local compiler = loadstring or load
if type(compiler) ~= "function" then
    warn("[RAINZXDEV] loadstring/load is unavailable")
    return
end

local okUiSource, uiSource = pcall(function()
    return game:HttpGet(PUCK_UI_URL)
end)

if not okUiSource or type(uiSource) ~= "string" or #uiSource < 100 then
    warn("[RAINZXDEV] Could not load PuckUI:", uiSource)
    return
end

-- Generic names can be mistaken for native menu widgets by some games.
-- PuckUI holds these through local variables, so renaming the instance names is safe.
uiSource = string.gsub(uiSource, 'Name%s*=%s*"Main"', 'Name = "PuckPowerRoot"', 1)
uiSource = string.gsub(uiSource, 'Name%s*=%s*"TitleBar"', 'Name = "PuckPowerTitleBar"', 1)
uiSource = string.gsub(uiSource, 'Name%s*=%s*"Close"', 'Name = "PuckPowerClose"', 1)

local uiChunk, uiCompileError = compiler(uiSource)
if not uiChunk then
    warn("[RAINZXDEV] PuckUI compile error:", uiCompileError)
    return
end

local okUi, PuckUI = pcall(uiChunk)
if not okUi or type(PuckUI) ~= "table" or type(PuckUI.CreateWindow) ~= "function" then
    warn("[RAINZXDEV] Invalid PuckUI:", PuckUI)
    return
end

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV | +1 Power Per Click",
    GuiName = "RAINZXDEV_Plus1Power",
    Width = 520,
    Height = 570,
})

local FarmTab = Window:CreateTab("Farm")
local ProgressTab = Window:CreateTab("Progression")
local EconomyTab = Window:CreateTab("Economy")
local PetsTab = Window:CreateTab("Pets")
local ChallengesTab = Window:CreateTab("Challenges")
local RewardsTab = Window:CreateTab("Rewards")
local SettingsTab = Window:CreateTab("Settings")

-- ==========================================================================
-- STATE / CONFIG
-- ==========================================================================

local Farm = {
    Running = true,
    Connections = {},
    PassCache = {},

    Config = {
        AutoPower = true,
        BestTrainingPad = true,
        AutoRebirth = true,
        AutoHighestWorld = true,
        AutoWins = false,
        RebirthWhileWins = false,

        AutoUpgrades = true,

        -- Smart economy systems found in the full place inspection.
        SmartWinsReservePercent = 25,
        AutoSwords = true,
        AutoAuras = true,
        AutoEquipBestAura = true,
        AutoGemForge = true,
        AutoEquipBestTitle = true,
        AutoFreeTitleRolls = true,
        AutoPaidTitleRolls = false,
        MaxPaidTitleRollsPerCycle = 3,
        AutoSmartEnchants = false,
        AutoLockEnchantTier = 4,
        ManagePotionServerMode = false,
        AutoPotionServerMode = false,

        AutoEquipBest = true,
        AutoHatch = false,
        EggSpendPercent = 25,
        AutoPetFusion = true,
        AutoPetIndexClaims = true,

        -- Optional special-mode farms. OFF by default so the working normal
        -- power/cave progression remains authoritative until the user enables one.
        AutoArena = false,
        AutoInfinityCave = false,
        AutoEruptionCave = false,
        AutoGlacierDig = false,
        GlacierMaxRiskPercent = 18,
        GlacierBankWithPet = true,

        AutoDaily = true,
        AutoQuests = true,
        AutoGroupReward = true,
        AutoPlaytimeChests = true,
        AutoSpins = true,
        AutoSecretCode = true,

        PadTravelMode = "Teleport",
        ClickNearestEnemy = true,
        MaxCaveHitsPerWall = 20,
        CaveWalkSpeedFloor = 16,
    },

    Runtime = {
        Phase = "Starting",
        LastError = nil,
        ClicksSent = 0,
        RebirthsDone = 0,
        UpgradesBought = 0,
        SwordsBought = 0,
        AurasBought = 0,
        GemUpgradesBought = 0,
        TitlesRolled = 0,
        EnchantRolls = 0,
        PetMerges = 0,
        PetIndexClaims = 0,
        EggsHatched = 0,
        RewardsClaimed = 0,
        CaveCashouts = 0,

        CurrentWorld = 1,
        DesiredWorld = 1,
        SelectedPadName = "None",
        SelectedPadMult = 1,
        LastPadConfirm = 1,
        LastWorldResult = "None",
        LastRebirthResult = "None",
        LastUpgrade = "None",
        LastSword = "None",
        LastAura = "None",
        LastGem = "None",
        LastTitle = "None",
        LastEnchant = "None",
        LastPet = "None",
        LastReward = "None",
        LastCave = "None",
        LastChallenge = "None",
        LastSecretCode = "Not tried",
        ActiveGameEvent = "None",

        WorldTraveling = false,
        PadMoving = false,
        CaveMoving = false,
        MovementOwner = nil,
        MovementOwnerUntil = 0,
        SecretCodeTried = false,
        PotionModeApplied = nil,
        ArenaLive = false,
        ArenaJoined = false,
        GlacierState = nil,
        LastPadMoveAt = -math.huge,
        LastWorldCheck = -math.huge,
        LastWorldTravel = -math.huge,
        LastRebirthCheck = -math.huge,
        LastUpgradeCheck = -math.huge,
        LastPetCheck = -math.huge,
        LastHatchCheck = -math.huge,
        LastEconomyCheck = -math.huge,
        LastFusionCheck = -math.huge,
        LastIndexCheck = -math.huge,
        LastTitleCheck = -math.huge,
        LastChallengeCheck = -math.huge,
        LastRewardCheck = -math.huge,
    },
}

GENV[SCRIPT_KEY] = Farm

local function track(connection)
    if connection then
        table.insert(Farm.Connections, connection)
    end
    return connection
end

local function setPhase(text)
    Farm.Runtime.Phase = tostring(text or "")
end

local function setError(err)
    Farm.Runtime.LastError = err and tostring(err) or nil
end

-- ==========================================================================
-- REMOTES / MODULES
-- ==========================================================================

local function remote(name, className)
    local obj = ReplicatedStorage:FindFirstChild(name)
    if obj and (not className or obj:IsA(className)) then
        return obj
    end
    return nil
end

local ClickTrainEvent = remote("ClickTrainEvent", "RemoteEvent")
local RebirthFunction = remote("RebirthFunction", "RemoteFunction")
local WorldTeleportRemote = remote("WorldTeleportRemote", "RemoteFunction")
local UpgradeFunction = remote("UpgradeFunction", "RemoteFunction")
local PetFunction = remote("PetFunction", "RemoteFunction")
local DailyRewardFunction = remote("DailyRewardFunction", "RemoteFunction")
local QuestFunction = remote("QuestFunction", "RemoteFunction")
local GroupRewardsFunc = remote("GroupRewardsFunc", "RemoteFunction")
local SpinWheelFunction = remote("SpinWheelFunction", "RemoteFunction")
local PlaytimeChestsFunction = remote("PlaytimeChestsFunction", "RemoteFunction")
local AuraFunction = remote("AuraFunction", "RemoteFunction")
local TitleFunction = remote("TitleFunction", "RemoteFunction")
local PotionFunction = remote("PotionFunction", "RemoteFunction")
local SwordEnchantFunction = remote("SwordEnchantFunction", "RemoteFunction")
local CodeFunction = remote("CodeFunction", "RemoteFunction")
local GemFunction = remote("GemFunction", "RemoteFunction")

local ArenaJoinEvent = remote("ArenaJoinEvent", "RemoteEvent")
local ArenaSyncEvent = remote("ArenaSyncEvent", "RemoteEvent")
local InfinityRunEvent = remote("InfinityRunEvent", "RemoteEvent")
local EruptionRunEvent = remote("EruptionRunEvent", "RemoteEvent")
local GlacierDigEvent = remote("GlacierDigEvent", "RemoteEvent")
local GlacierChoiceEvent = remote("GlacierChoiceEvent", "RemoteEvent")
local CaveEventAnnounce = remote("CaveEventAnnounce", "RemoteEvent")

local function safeRequire(name)
    local obj = ReplicatedStorage:FindFirstChild(name)
    if not obj or not obj:IsA("ModuleScript") then
        return nil
    end
    local ok, value = pcall(require, obj)
    return ok and value or nil
end

local AuraConfig = safeRequire("AuraConfig")
local GemConfig = safeRequire("GemConfig")
local TitleConfig = safeRequire("TitleConfig")
local PotionConfig = safeRequire("PotionConfig")
local SwordLadder = safeRequire("SwordLadder")
local SwordEnchantConfig = safeRequire("SwordEnchantConfig")
local TileCodeSecret = safeRequire("TileCodeSecret")

local LevelProgression = nil
pcall(function()
    LevelProgression = require(ReplicatedStorage:WaitForChild("LevelProgression", 10))
end)

local function invoke(rf, ...)
    if not rf or not rf:IsA("RemoteFunction") then
        return false, nil, "remote unavailable"
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        return rf:InvokeServer(table.unpack(args, 1, args.n))
    end)

    if not ok then
        return false, nil, tostring(result)
    end

    return true, result, nil
end

-- ==========================================================================
-- PLAYER / CHARACTER HELPERS
-- ==========================================================================

local function characterParts()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health <= 0 or not root then
        return nil
    end

    return character, humanoid, root
end

local function valueObject(name)
    return LocalPlayer:FindFirstChild(name)
end

local function numericValue(name, default)
    local obj = valueObject(name)
    local n = obj and tonumber(obj.Value)
    return n or default
end

local function getStrength()
    return numericValue("Strength", 0)
end

local function getLevel()
    return numericValue("Level", 1)
end

local function getWins()
    local direct = LocalPlayer:FindFirstChild("Wins")
    if direct and tonumber(direct.Value) then
        return tonumber(direct.Value)
    end

    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local value = leaderstats and leaderstats:FindFirstChild("Wins")
    return value and tonumber(value.Value) or 0
end

local function getRebirths()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local value = leaderstats and leaderstats:FindFirstChild("Rebirths")
    return value and tonumber(value.Value) or 0
end

local function getTrainingMultiplier()
    return math.max(1, numericValue("TrainingMultiplier", 1))
end

local function worldFromX(x)
    if x > 7000 then
        return 5
    elseif x > 5000 then
        return 4
    elseif x > 3000 then
        return 3
    elseif x > 1000 then
        return 2
    end
    return 1
end

local function currentWorld()
    local _, _, root = characterParts()
    if root then
        Farm.Runtime.CurrentWorld = worldFromX(root.Position.X)
    end
    return Farm.Runtime.CurrentWorld
end

local function horizontalDistance(a, b)
    return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function safeMoveTo(position, reach, timeout)
    local character, humanoid, root = characterParts()
    if not character then
        return false
    end

    reach = tonumber(reach) or 4
    timeout = tonumber(timeout) or 12
    local started = os.clock()
    local lastPosition = root.Position
    local lastMovedAt = os.clock()

    humanoid.Sit = false
    humanoid.PlatformStand = false
    if humanoid.WalkSpeed < Farm.Config.CaveWalkSpeedFloor then
        -- Do not force a high exploit speed; only prevent a zero/crippled movement state.
        humanoid.WalkSpeed = Farm.Config.CaveWalkSpeedFloor
    end

    while Farm.Running and os.clock() - started < timeout do
        character, humanoid, root = characterParts()
        if not character then
            return false
        end

        if horizontalDistance(root.Position, position) <= reach then
            humanoid:Move(Vector3.zero, false)
            return true
        end

        humanoid:MoveTo(position)

        if (root.Position - lastPosition).Magnitude > 1 then
            lastPosition = root.Position
            lastMovedAt = os.clock()
        elseif os.clock() - lastMovedAt > 1.3 then
            humanoid.Jump = true
            lastMovedAt = os.clock()
            lastPosition = root.Position
        end

        task.wait(0.08)
    end

    return false
end

-- ==========================================================================
-- ADVANCED MOVEMENT / ECONOMY HELPERS
-- ==========================================================================

local function arenaBossIsLive()
    if type(_G.ArenaBossLive) == "function" then
        local ok, live = pcall(_G.ArenaBossLive)
        if ok then return live == true end
    end
    return Farm.Runtime.ArenaLive == true
end

local function glacierCanRun()
    return LocalPlayer:GetAttribute("InGlacierDig") == true
        or (tonumber(LocalPlayer:GetAttribute("GlacierTickets")) or 0) > 0
end

local function specialChallengeEnabled()
    return Farm.Config.AutoInfinityCave
        or Farm.Config.AutoEruptionCave
        or (Farm.Config.AutoGlacierDig and glacierCanRun())
        or (Farm.Config.AutoArena and arenaBossIsLive())
end

local function movementBusy(exceptOwner)
    local owner = Farm.Runtime.MovementOwner
    if owner and owner ~= exceptOwner and os.clock() < (Farm.Runtime.MovementOwnerUntil or 0) then
        return true
    end
    if owner and os.clock() >= (Farm.Runtime.MovementOwnerUntil or 0) then
        Farm.Runtime.MovementOwner = nil
    end
    return false
end

local function acquireMovement(owner, timeout)
    if movementBusy(owner) then
        return false
    end
    Farm.Runtime.MovementOwner = owner
    Farm.Runtime.MovementOwnerUntil = os.clock() + (tonumber(timeout) or 15)
    return true
end

local function releaseMovement(owner)
    if Farm.Runtime.MovementOwner == owner then
        Farm.Runtime.MovementOwner = nil
        Farm.Runtime.MovementOwnerUntil = 0
    end
end

local function travelToPosition(position, reach, timeout, mode)
    if typeof(position) ~= "Vector3" then
        return false
    end
    mode = mode or Farm.Config.PadTravelMode
    if mode == "Walk" then
        return safeMoveTo(position, reach or 4, timeout or 14)
    end
    local character, humanoid, root = characterParts()
    if not character then
        return false
    end
    humanoid.Sit = false
    humanoid.PlatformStand = false
    local target = position + Vector3.new(0, 3, 0)
    local ok = pcall(function()
        character:PivotTo(CFrame.new(target, target + root.CFrame.LookVector))
    end)
    if not ok then
        pcall(function() root.CFrame = CFrame.new(target) end)
    end
    task.wait(0.10)
    return true
end

local function spendableWins()
    local reserve = math.clamp(tonumber(Farm.Config.SmartWinsReservePercent) or 25, 0, 95) / 100
    return math.max(0, getWins() * (1 - reserve))
end

local function canSpendWins(cost)
    cost = tonumber(cost)
    return cost ~= nil and cost >= 0 and cost <= spendableWins()
end

local function objectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then return obj:GetPivot().Position end
    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

-- ==========================================================================
-- WORLD PROGRESSION
-- ==========================================================================

local function getWorldState()
    local ok, result, err = invoke(WorldTeleportRemote, "GetState")
    if not ok or type(result) ~= "table" then
        Farm.Runtime.LastWorldResult = err or "GetState failed"
        return nil
    end

    if result.ok == false then
        Farm.Runtime.LastWorldResult = tostring(result.err or "server rejected GetState")
        return nil
    end

    return result
end

local function highestUnlockedWorld(state)
    if type(state) ~= "table" then
        return currentWorld()
    end

    local rebirths = tonumber(state.rebirths) or getRebirths()

    local checks = {
        {5, "w5Available", "req5", 370},
        {4, "w4Available", "req4", 265},
        {3, "w3Available", "req3", 160},
        {2, "w2Available", "req", 45},
    }

    for _, entry in ipairs(checks) do
        local id, availableKey, reqKey, fallback = table.unpack(entry)
        local available = state[availableKey]
        local requirement = tonumber(state[reqKey]) or fallback

        if available == true and rebirths >= requirement then
            return id
        end
    end

    return 1
end

local function travelToWorld(worldId)
    worldId = tonumber(worldId)
    if not worldId or worldId < 1 or worldId > 5 then
        return false
    end

    if currentWorld() == worldId then
        Farm.Runtime.DesiredWorld = worldId
        return true
    end

    if Farm.Runtime.WorldTraveling then
        return false
    end

    Farm.Runtime.WorldTraveling = true
    Farm.Runtime.DesiredWorld = worldId
    setPhase("Travelling to World " .. worldId)

    local ok, result, err = invoke(WorldTeleportRemote, "Go", worldId)
    if not ok or type(result) ~= "table" or result.ok ~= true then
        Farm.Runtime.LastWorldResult = err or (type(result) == "table" and tostring(result.err)) or "travel failed"
        Farm.Runtime.WorldTraveling = false
        return false
    end

    Farm.Runtime.LastWorldResult = "World " .. worldId .. " accepted"
    Farm.Runtime.LastWorldTravel = os.clock()

    local deadline = os.clock() + 4
    while Farm.Running and os.clock() < deadline do
        if currentWorld() == worldId then
            break
        end
        task.wait(0.1)
    end

    task.wait(0.35)
    Farm.Runtime.WorldTraveling = false
    return currentWorld() == worldId
end

local function goHighestWorld()
    local state = getWorldState()
    if not state then
        return false
    end

    local target = highestUnlockedWorld(state)
    Farm.Runtime.DesiredWorld = target
    return travelToWorld(target)
end

-- ==========================================================================
-- TRAINING PAD DISCOVERY
-- ==========================================================================

local function trainingRootForWorld(worldId)
    if worldId == 1 then
        return Workspace:FindFirstChild("PrototypeTrainingArea")
    end

    local world = Workspace:FindFirstChild("World" .. tostring(worldId))
    return world and world:FindFirstChild("PrototypeTrainingArea") or nil
end

local function inheritedAttribute(instance, name, stopAt)
    local cursor = instance
    while cursor do
        local value = cursor:GetAttribute(name)
        if value ~= nil then
            return value
        end
        if cursor == stopAt then
            break
        end
        cursor = cursor.Parent
    end
    return nil
end

local function representativePart(instance)
    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        if instance.PrimaryPart then
            return instance.PrimaryPart
        end

        local preferred = instance:FindFirstChild("GlowTile", true)
            or instance:FindFirstChild("Pad", true)
            or instance:FindFirstChild("Floor", true)

        if preferred and preferred:IsA("BasePart") then
            return preferred
        end
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function ownsPass(passId)
    passId = tonumber(passId)
    if not passId or passId <= 0 then
        return false
    end

    if Farm.PassCache[passId] ~= nil then
        return Farm.PassCache[passId]
    end

    local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, LocalPlayer.UserId, passId)
    Farm.PassCache[passId] = ok and owned == true or false
    return Farm.PassCache[passId]
end

local function padUnlocked(instance, root)
    local requirement = tonumber(inheritedAttribute(instance, "RebirthReq", root)) or 0
    if getRebirths() >= requirement then
        return true, requirement, false
    end

    local passId = tonumber(inheritedAttribute(instance, "PassId", root))
    if passId and passId > 0 and ownsPass(passId) then
        return true, requirement, true
    end

    return false, requirement, false
end

local function findBestTrainingPad(worldId)
    local root = trainingRootForWorld(worldId)
    if not root then
        return nil
    end

    local all = {root}
    for _, descendant in ipairs(root:GetDescendants()) do
        table.insert(all, descendant)
    end

    local seenParts = {}
    local best = nil

    for _, object in ipairs(all) do
        local multiplier = tonumber(object:GetAttribute("Multiplier"))
        if multiplier and multiplier > 1 then
            local part = representativePart(object)
            if part and part:IsA("BasePart") and not seenParts[part] then
                seenParts[part] = true

                local unlocked, requirement, viaPass = padUnlocked(object, root)
                if unlocked then
                    local candidate = {
                        Object = object,
                        Part = part,
                        Multiplier = multiplier,
                        Requirement = requirement,
                        ViaPass = viaPass,
                    }

                    if not best or candidate.Multiplier > best.Multiplier then
                        best = candidate
                    end
                end
            end
        end
    end

    return best
end

local function pointOnTop(part)
    local _, humanoid, root = characterParts()
    if not humanoid or not root then
        return part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)
    end

    local y = part.Position.Y + part.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2 + 0.25
    return Vector3.new(part.Position.X, y, part.Position.Z)
end

local function moveToTrainingPad(candidate)
    if not candidate or not candidate.Part or not candidate.Part.Parent then
        return false
    end

    if Farm.Runtime.PadMoving or Farm.Runtime.CaveMoving or Farm.Runtime.WorldTraveling then
        return false
    end

    Farm.Runtime.PadMoving = true
    Farm.Runtime.SelectedPadName = candidate.Object.Name
    Farm.Runtime.SelectedPadMult = candidate.Multiplier
    Farm.Runtime.LastPadMoveAt = os.clock()
    setPhase(string.format("Moving to best training pad (x%s)", tostring(candidate.Multiplier)))

    local character, humanoid, root = characterParts()
    if not character then
        Farm.Runtime.PadMoving = false
        return false
    end

    local target = pointOnTop(candidate.Part)
    local success = false

    if Farm.Config.PadTravelMode == "Walk" then
        success = safeMoveTo(target, math.max(2, math.min(candidate.Part.Size.X, candidate.Part.Size.Z) * 0.35), 18)
    else
        -- Position exactly on top of the real pad. The server remains authoritative
        -- for TrainingMultiplier, which we verify below before considering this done.
        pcall(function()
            character:PivotTo(CFrame.new(target))
        end)
        task.wait(0.18)
        success = true
    end

    -- Give the game's pad detector/touch logic time to update TrainingMultiplier.
    local deadline = os.clock() + 2.4
    local confirmed = getTrainingMultiplier()

    while Farm.Running and os.clock() < deadline do
        confirmed = getTrainingMultiplier()
        if confirmed >= candidate.Multiplier * 0.95 then
            break
        end

        if Farm.Config.PadTravelMode ~= "Walk" then
            character, humanoid, root = characterParts()
            if character and os.clock() + 1.4 < deadline then
                -- tiny physical nudge inside the pad can wake touch/zone detection
                humanoid:MoveTo(target + Vector3.new(0.6, 0, 0.6))
            end
        end

        task.wait(0.1)
    end

    Farm.Runtime.LastPadConfirm = confirmed
    Farm.Runtime.PadMoving = false

    if confirmed >= candidate.Multiplier * 0.95 then
        setPhase(string.format("Training x%s", tostring(confirmed)))
        return true
    end

    if success then
        Farm.Runtime.LastError = string.format(
            "Reached %s but TrainingMultiplier stayed at %s",
            candidate.Object.Name,
            tostring(confirmed)
        )
    end

    return false
end

local function goBestTrainingPad()
    local worldId = currentWorld()
    local candidate = findBestTrainingPad(worldId)
    if not candidate then
        Farm.Runtime.SelectedPadName = "None found"
        Farm.Runtime.SelectedPadMult = 1
        return false
    end

    Farm.Runtime.SelectedPadName = candidate.Object.Name
    Farm.Runtime.SelectedPadMult = candidate.Multiplier

    if getTrainingMultiplier() >= candidate.Multiplier * 0.95 then
        Farm.Runtime.LastPadConfirm = getTrainingMultiplier()
        return true
    end

    return moveToTrainingPad(candidate)
end

-- ==========================================================================
-- CLICK / POWER FARM
-- ==========================================================================

local function nearestEnemy()
    if not Farm.Config.ClickNearestEnemy then
        return nil
    end

    local live = Workspace:FindFirstChild("LiveEnemies")
    local _, _, root = characterParts()
    if not live or not root then
        return nil
    end

    local best = nil
    local bestDistance = math.huge

    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") then
            local part = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
            if part then
                local distance = (part.Position - root.Position).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    best = model
                end
            end
        end
    end

    return best
end

local clickAccumulator = 0
track(RunService.Heartbeat:Connect(function(dt)
    if not Farm.Running or not Farm.Config.AutoPower then
        clickAccumulator = 0
        return
    end

    if not ClickTrainEvent or not ClickTrainEvent.Parent then
        ClickTrainEvent = remote("ClickTrainEvent", "RemoteEvent")
        if not ClickTrainEvent then
            return
        end
    end

    local onPad = getTrainingMultiplier() > 1
    if _G.OnTrainingPadLocal ~= nil then
        onPad = _G.OnTrainingPadLocal == true or onPad
    end

    local interval
    if onPad then
        interval = 0.1111111111111111
    else
        local speedMult = math.max(1, numericValue("AutoClickSpeedMult", 1))
        interval = 0.125 / speedMult
    end

    clickAccumulator = clickAccumulator + dt
    local sentThisFrame = 0

    while clickAccumulator >= interval and sentThisFrame < 3 do
        clickAccumulator = clickAccumulator - interval
        sentThisFrame = sentThisFrame + 1

        local ok = pcall(function()
            ClickTrainEvent:FireServer(nearestEnemy())
        end)

        if ok then
            Farm.Runtime.ClicksSent = Farm.Runtime.ClicksSent + 1
        end
    end
end))

-- ==========================================================================
-- REBIRTH
-- ==========================================================================

local function canRebirthLocally()
    local rebirths = getRebirths()
    local level = getLevel()

    if type(LevelProgression) == "table" and type(LevelProgression.GetMaxLevelForRebirth) == "function" then
        local ok, requirement = pcall(LevelProgression.GetMaxLevelForRebirth, rebirths)
        if ok and tonumber(requirement) then
            return level >= requirement, requirement
        end
    end

    local ok, state = invoke(RebirthFunction, "GetState")
    if ok and type(state) == "table" then
        return state.CanRebirth == true, tonumber(state.NextRequirement)
    end

    return false, nil
end

local function doRebirth()
    local can, requirement = canRebirthLocally()
    if not can then
        return false
    end

    setPhase("Rebirthing")
    local before = getRebirths()
    local ok, result, err = invoke(RebirthFunction, "Rebirth")

    if not ok or type(result) ~= "table" then
        Farm.Runtime.LastRebirthResult = err or "no result"
        return false
    end

    local accepted = false
    if tonumber(result.Rebirths) and tonumber(result.Rebirths) > before then
        accepted = true
    elseif type(result.Message) == "string" and string.find(string.lower(result.Message), "complete", 1, true) then
        accepted = true
    end

    if accepted then
        Farm.Runtime.RebirthsDone = Farm.Runtime.RebirthsDone + 1
        Farm.Runtime.LastRebirthResult = "Success -> " .. tostring(result.Rebirths or getRebirths())
        Farm.Runtime.LastPadMoveAt = -math.huge
        task.wait(0.18)
        return true
    end

    Farm.Runtime.LastRebirthResult = tostring(result.Message or "server did not confirm")
    if requirement then
        Farm.Runtime.LastRebirthResult = Farm.Runtime.LastRebirthResult .. " (need " .. tostring(requirement) .. ")"
    end
    return false
end

-- ==========================================================================
-- UPGRADES
-- ==========================================================================

local function buyAffordableUpgradeOnce()
    if not UpgradeFunction then
        UpgradeFunction = remote("UpgradeFunction", "RemoteFunction")
    end
    if not UpgradeFunction then
        return false
    end

    local ok, state = invoke(UpgradeFunction, "GetState")
    if not ok or type(state) ~= "table" or type(state.upgrades) ~= "table" then
        return false
    end

    local wins = tonumber(state.wins) or getWins()
    local affordable = {}

    for _, item in ipairs(state.upgrades) do
        if type(item) == "table" and item.id ~= nil and not item.maxed then
            local cost = tonumber(item.cost)
            if cost and cost <= wins and canSpendWins(cost) then
                table.insert(affordable, item)
            end
        end
    end

    if #affordable == 0 then
        return false
    end

    -- Lowest cost first gives reliable, broad progression instead of draining all
    -- wins into one expensive card while cheap multipliers remain available.
    table.sort(affordable, function(a, b)
        return (tonumber(a.cost) or math.huge) < (tonumber(b.cost) or math.huge)
    end)

    local item = affordable[1]
    local buyOk, result = invoke(UpgradeFunction, "Buy", item.id)
    if buyOk and type(result) == "table" and result.success == true then
        Farm.Runtime.UpgradesBought = Farm.Runtime.UpgradesBought + 1
        Farm.Runtime.LastUpgrade = tostring(item.name or item.id) .. " @ " .. tostring(item.cost)
        return true
    end

    return false
end

-- ==========================================================================
-- ADVANCED ECONOMY: SWORDS / AURAS / GEMS / TITLES / ENCHANTS / POTIONS
-- ==========================================================================

local function ownedSwordSet()
    local set = {}
    local folder = LocalPlayer:FindFirstChild("OwnedSwords")
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BoolValue") and child.Value then
                set[child.Name] = true
            end
        end
    end
    return set, folder
end

local function swordStandRoots()
    local roots = {}
    local w1 = Workspace:FindFirstChild("ShopStands")
    if w1 then table.insert(roots, w1) end
    for worldId = 2, 5 do
        local world = Workspace:FindFirstChild("World" .. worldId)
        local stands = world and world:FindFirstChild("ShopStands")
        if stands then table.insert(roots, stands) end
    end
    return roots
end

local function findSwordStand(tier)
    for _, root in ipairs(swordStandRoots()) do
        for _, stand in ipairs(root:GetChildren()) do
            if stand.Name:gsub("Stand$", "") == tier then
                return stand
            end
        end
    end
    return nil
end

local function standTouchPart(stand)
    local pedestal = stand and stand:FindFirstChild("ShopPedestal")
    if not pedestal then return representativePart(stand) end
    for _, obj in ipairs(pedestal:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanTouch then return obj end
    end
    return representativePart(pedestal)
end

local function buyBestAffordableSwordOnce()
    if not SwordLadder or type(SwordLadder.LADDER) ~= "table" and type(SwordLadder.buyableSet) ~= "function" then
        return false
    end
    local owned, folder = ownedSwordSet()
    if not folder or type(SwordLadder.buyableSet) ~= "function" then return false end
    local buyable = SwordLadder.buyableSet(owned)
    local candidates = {}
    local list = SwordLadder.LADDER or SwordLadder.LIST or SwordLadder.SWORDS or {}
    if #list == 0 then
        -- Exported SwordLadder keeps the list as the module's array component.
        for i, value in ipairs(SwordLadder) do list[i] = value end
    end
    local unlockedWorld = highestUnlockedWorld(getWorldState())
    local function swordWorld(index)
        if index <= (SwordLadder.W1_MAX_RUNG or 17) then return 1 end
        if index <= (SwordLadder.W2_MAX_RUNG or 33) then return 2 end
        if index <= (SwordLadder.W3_MAX_RUNG or 47) then return 3 end
        if index <= (SwordLadder.W4_MAX_RUNG or 63) then return 4 end
        return 5
    end
    for index, sword in ipairs(list) do
        if type(sword) == "table" and swordWorld(index) <= unlockedWorld and buyable[sword.tier] and not owned[sword.tier] then
            local cost = tonumber(sword.cost)
            local stand = findSwordStand(sword.tier)
            local passId = stand and tonumber(stand:GetAttribute("PassId")) or 0
            if stand and cost and canSpendWins(cost) and passId <= 0 then
                table.insert(candidates, {sword=sword, stand=stand, cost=cost})
            end
        end
    end
    if #candidates == 0 then return false end
    table.sort(candidates, function(a,b)
        if a.sword.power == b.sword.power then return a.cost < b.cost end
        return (tonumber(a.sword.power) or 0) > (tonumber(b.sword.power) or 0)
    end)
    local choice = candidates[1]
    if not acquireMovement("Sword", 8) then return false end
    local part = standTouchPart(choice.stand)
    if not part then releaseMovement("Sword"); return false end
    setPhase("Buying sword: " .. tostring(choice.sword.display or choice.sword.tier))
    local before = folder:FindFirstChild(choice.sword.tier)
    travelToPosition(pointOnTop(part), 3, 8)
    local _, _, root = characterParts()
    if root and type(firetouchinterest) == "function" then
        pcall(firetouchinterest, root, part, 0)
        task.wait(0.05)
        pcall(firetouchinterest, root, part, 1)
    end
    local started = os.clock()
    local bought = false
    while os.clock() - started < 1.4 do
        local flag = folder:FindFirstChild(choice.sword.tier)
        if flag and (not flag:IsA("BoolValue") or flag.Value) then bought = true break end
        task.wait(0.08)
    end
    releaseMovement("Sword")
    Farm.Runtime.LastPadMoveAt = -math.huge
    if bought then
        Farm.Runtime.SwordsBought += 1
        Farm.Runtime.LastSword = tostring(choice.sword.display or choice.sword.tier) .. " @ " .. tostring(choice.cost)
        return true
    end
    Farm.Runtime.LastSword = "Stand reached; purchase not confirmed: " .. tostring(choice.sword.tier)
    return false
end

local function getAuraState()
    AuraFunction = AuraFunction or remote("AuraFunction", "RemoteFunction")
    if not AuraFunction then return nil end
    local ok, state = invoke(AuraFunction, "GetState")
    return ok and type(state)=="table" and state or nil
end

local function equipBestAura(state)
    if not AuraConfig or type(AuraConfig.AURAS) ~= "table" then return false end
    state = state or getAuraState()
    if not state or type(state.owned) ~= "table" then return false end
    local best, bestMult = nil, -math.huge
    for _, aura in ipairs(AuraConfig.AURAS) do
        if state.owned[aura.key] and (tonumber(aura.powerMult) or 0) > bestMult then
            best, bestMult = aura, tonumber(aura.powerMult) or 0
        end
    end
    if not best or state.equipped == best.key then return false end
    local ok, result = invoke(AuraFunction, "Equip", best.key)
    if ok and type(result)=="table" and result.success then
        Farm.Runtime.LastAura = "Equipped " .. tostring(best.name) .. " x" .. tostring(best.powerMult)
        return true
    end
    return false
end

local function buyBestAffordableAuraOnce()
    if not AuraConfig or type(AuraConfig.AURAS) ~= "table" then return false end
    local state = getAuraState()
    if not state or type(state.owned) ~= "table" then return false end
    local best = nil
    for _, aura in ipairs(AuraConfig.AURAS) do
        if not state.owned[aura.key] and canSpendWins(aura.cost) then
            if not best or (tonumber(aura.powerMult) or 0) > (tonumber(best.powerMult) or 0) then best=aura end
        end
    end
    if not best then
        if Farm.Config.AutoEquipBestAura then return equipBestAura(state) end
        return false
    end
    local ok, result = invoke(AuraFunction, "Buy", best.key)
    if ok and type(result)=="table" and result.success then
        Farm.Runtime.AurasBought += 1
        Farm.Runtime.LastAura = "Bought " .. tostring(best.name) .. " x" .. tostring(best.powerMult)
        task.wait(0.08)
        if Farm.Config.AutoEquipBestAura then equipBestAura(result) end
        return true
    end
    return false
end

local function buyGemUpgradeOnce()
    GemFunction = GemFunction or remote("GemFunction", "RemoteFunction")
    if not GemFunction or not GemConfig or type(GemConfig.UPGRADES)~="table" or type(GemConfig.cost)~="function" then return false end
    local ok, state = invoke(GemFunction, "GetState")
    if not ok or type(state)~="table" then return false end
    local gems = tonumber(state.gems) or 0
    local levels = type(state.levels)=="table" and state.levels or {}
    local priority = Farm.Config.AutoWins
        and {gemFind=1, damage=2, attackSpeed=3, chainBreak=4, clickPower=5}
        or {gemFind=1, clickPower=2, damage=3, attackSpeed=4, chainBreak=5}
    local choices = {}
    for _, upg in ipairs(GemConfig.UPGRADES) do
        local level = tonumber(levels[upg.id]) or 0
        local cost = GemConfig.cost(upg, level)
        if cost and cost <= gems then
            table.insert(choices, {upg=upg,cost=cost,rank=priority[upg.id] or 99})
        end
    end
    table.sort(choices,function(a,b) if a.rank==b.rank then return a.cost<b.cost end return a.rank<b.rank end)
    local choice=choices[1]
    if not choice then return false end
    local buyOk,result=invoke(GemFunction,"Buy",choice.upg.id)
    if buyOk and type(result)=="table" and result.ok then
        Farm.Runtime.GemUpgradesBought += 1
        Farm.Runtime.LastGem = tostring(choice.upg.name) .. " Lv " .. tostring(result.level or "?")
        return true
    end
    return false
end

local function getTitleState()
    TitleFunction = TitleFunction or remote("TitleFunction", "RemoteFunction")
    if not TitleFunction then return nil end
    local ok,state=invoke(TitleFunction,"GetState")
    return ok and type(state)=="table" and state or nil
end

local function equipBestTitle(state)
    if not TitleConfig or type(TitleConfig.BY_ID)~="table" then return false end
    state=state or getTitleState()
    if not state or type(state.titles)~="table" then return false end
    local bestId,bestMult=nil,-math.huge
    for _, entry in ipairs(state.titles) do
        if type(entry)=="table" and entry.owned then
            local cfg=TitleConfig.BY_ID[entry.id]
            local mult=cfg and tonumber(cfg.mult) or 0
            if mult>bestMult then bestId,bestMult=entry.id,mult end
        end
    end
    if not bestId or state.equipped==bestId then return false end
    local ok,result=invoke(TitleFunction,"Equip",bestId)
    if ok and type(result)=="table" and result.ok then
        Farm.Runtime.LastTitle="Equipped title #"..tostring(bestId).." x"..tostring(bestMult)
        return true
    end
    return false
end

local function rollTitlesSmart()
    if not TitleConfig then return false end
    local state=getTitleState(); if not state then return false end
    local rolled=false
    if Farm.Config.AutoFreeTitleRolls and state.freeRoll then
        local ok,result=invoke(TitleFunction,"Roll","base")
        if ok and type(result)=="table" and result.err==nil and result.rolled~=nil then
            Farm.Runtime.TitlesRolled += 1; rolled=true; Farm.Runtime.LastTitle="Used FREE base title roll"
            state=result.state or getTitleState() or state
        end
    end
    if Farm.Config.AutoPaidTitleRolls then
        local cost=tonumber(TitleConfig.ROLL_COST) or 10
        local maxRolls=math.max(1,tonumber(Farm.Config.MaxPaidTitleRollsPerCycle) or 3)
        for _=1,maxRolls do
            if not canSpendWins(cost) then break end
            local ok,result=invoke(TitleFunction,"Roll","base")
            if not ok or type(result)~="table" or result.err~=nil or result.rolled==nil then break end
            Farm.Runtime.TitlesRolled += 1; rolled=true; Farm.Runtime.LastTitle="Rolled base title"
            task.wait(0.08)
        end
        state=getTitleState() or state
    end
    if Farm.Config.AutoEquipBestTitle then equipBestTitle(state) end
    return rolled
end

local function smartEnchantOnce()
    SwordEnchantFunction = SwordEnchantFunction or remote("SwordEnchantFunction", "RemoteFunction")
    if not SwordEnchantFunction then return false end
    local ok,state=invoke(SwordEnchantFunction,"GetState")
    if not ok or type(state)~="table" then return false end
    local threshold=math.clamp(tonumber(Farm.Config.AutoLockEnchantTier) or 4,1,5)
    local locked=type(state.locked)=="table" and state.locked or {}
    local slots=type(state.slots)=="table" and state.slots or {}
    for i=1,4 do
        local slot=slots[tostring(i)] or slots[i]
        if type(slot)=="table" and (tonumber(slot.tier) or 0)>=threshold and not (locked[tostring(i)] or locked[i]) then
            local lockOk,lockResult=invoke(SwordEnchantFunction,"Lock",i)
            if lockOk and (type(lockResult)~="table" or lockResult.err==nil) then Farm.Runtime.LastEnchant="Locked tier "..tostring(slot.tier).." slot "..i; return true end
        end
    end
    local cost=tonumber(state.cost)
    if not cost or not canSpendWins(cost) then return false end
    local rollOk,result=invoke(SwordEnchantFunction,"Roll")
    if rollOk and type(result)=="table" and result.err==nil and type(result.results)=="table" then
        Farm.Runtime.EnchantRolls += 1
        Farm.Runtime.LastEnchant="Rolled sword enchants @ "..tostring(cost)
        return true
    end
    return false
end

local function applyPotionAutoMode()
    if not Farm.Config.ManagePotionServerMode then return false end
    PotionFunction = PotionFunction or remote("PotionFunction", "RemoteFunction")
    if not PotionFunction then return false end
    local desired=Farm.Config.AutoPotionServerMode==true
    if Farm.Runtime.PotionModeApplied==desired then return false end
    local ok,result=invoke(PotionFunction,"SetAuto",desired)
    if ok then
        Farm.Runtime.PotionModeApplied=desired
        Farm.Runtime.LastReward="Server auto-potions "..(desired and "ON" or "OFF")
        return true
    end
    return false
end

-- ==========================================================================
-- PETS / EGGS
-- ==========================================================================

local function equipBestPets()
    if not PetFunction then
        PetFunction = remote("PetFunction", "RemoteFunction")
    end
    if not PetFunction then
        return false
    end

    local ok, result = invoke(PetFunction, "EquipBest")
    if ok and type(result) == "table" and result.success == true then
        Farm.Runtime.LastPet = "Equipped best pets"
        return true
    end

    return false
end

local function hatchBestAffordableEgg()
    if not PetFunction then
        PetFunction = remote("PetFunction", "RemoteFunction")
    end
    if not PetFunction then
        return false
    end

    local ok, state = invoke(PetFunction, "GetState")
    if not ok or type(state) ~= "table" or type(state.eggs) ~= "table" then
        return false
    end

    local wins = getWins()
    local budget = wins * math.clamp(tonumber(Farm.Config.EggSpendPercent) or 25, 1, 100) / 100
    local bestIndex = nil
    local bestEgg = nil
    local bestCost = -1

    for index, egg in ipairs(state.eggs) do
        if type(egg) == "table" then
            local cost = tonumber(egg.cost)
            local isRobux = egg.robux == true or (tonumber(egg.productId) or 0) > 0 and not cost

            if cost and not isRobux and cost <= budget and cost > bestCost then
                bestIndex = index
                bestEgg = egg
                bestCost = cost
            end
        end
    end

    if not bestIndex then
        return false
    end

    local hatchOk, result = invoke(PetFunction, "HatchEgg", bestIndex, 1)
    if hatchOk and type(result) == "table" and result.success == true then
        Farm.Runtime.EggsHatched = Farm.Runtime.EggsHatched + 1
        Farm.Runtime.LastPet = "Hatched " .. tostring(bestEgg.name or ("egg #" .. bestIndex))
        task.delay(0.15, equipBestPets)
        return true
    end

    return false
end

local function claimOrStartPetMerge()
    if not PetFunction then PetFunction=remote("PetFunction","RemoteFunction") end
    if not PetFunction then return false end
    local ok,mergeState=invoke(PetFunction,"GetMerge")
    if ok and type(mergeState)=="table" and mergeState.merge then
        local remaining=tonumber(mergeState.merge.remaining) or math.huge
        if remaining<=0 then
            local claimOk,result=invoke(PetFunction,"ClaimMerge")
            if claimOk and type(result)=="table" and result.success then
                Farm.Runtime.PetMerges += 1; Farm.Runtime.LastPet="Claimed merged pet"; task.delay(0.1,equipBestPets); return true
            end
        end
        return false
    end
    local stateOk,state=invoke(PetFunction,"GetState")
    if not stateOk or type(state)~="table" or type(state.owned)~="table" then return false end
    local groups={}
    for _,pet in ipairs(state.owned) do
        if type(pet)=="table" then
            local variant=pet.variant or "Normal"
            if variant~="Rainbow" and pet.name then
                local key=tostring(pet.name).."\0"..variant
                groups[key]=groups[key] or {name=pet.name,variant=variant,count=0}
                groups[key].count += 1
            end
        end
    end
    local choice=nil
    for _,g in pairs(groups) do
        if g.count>=3 and (not choice or (g.variant=="Golden" and choice.variant~="Golden") or (g.variant==choice.variant and g.count>choice.count)) then choice=g end
    end
    if not choice then return false end
    local startOk,result=invoke(PetFunction,"StartMerge",choice.name,choice.variant)
    if startOk and type(result)=="table" and result.success then
        Farm.Runtime.PetMerges += 1; Farm.Runtime.LastPet="Started "..choice.variant.." merge: "..choice.name; return true
    end
    return false
end

local function claimPetIndexRewards()
    if not PetFunction then PetFunction=remote("PetFunction","RemoteFunction") end
    if not PetFunction then return false end
    local ok,state=invoke(PetFunction,"GetState")
    if not ok or type(state)~="table" or type(state.eggs)~="table" then return false end
    local discovered={}
    if type(state.discovered)=="table" then for k,v in pairs(state.discovered) do if v then discovered[k]=true end end end
    if type(state.owned)=="table" then for _,pet in ipairs(state.owned) do if type(pet)=="table" and pet.name then discovered[pet.name]=true end end end
    local claims=type(state.indexClaims)=="table" and state.indexClaims or {}
    local allRewardEggs=true; local rewardEggCount=0; local claimedAny=false
    for eggIdx,egg in ipairs(state.eggs) do
        if type(egg)=="table" and type(egg.pets)=="table" and #egg.pets>0 then
            local complete=true
            for _,petDef in ipairs(egg.pets) do
                local name=type(petDef)=="table" and (petDef.name or petDef.Name) or tostring(petDef)
                if name and not discovered[name] then complete=false break end
            end
            local already=claims[tostring(eggIdx)]==true or claims[eggIdx]==true
            if complete and not already then
                local claimOk,result=invoke(PetFunction,"ClaimIndexReward",eggIdx)
                if claimOk and type(result)=="table" and result.ok then
                    Farm.Runtime.PetIndexClaims += 1; Farm.Runtime.RewardsClaimed += 1; claimedAny=true
                    Farm.Runtime.LastReward="Pet Index egg #"..eggIdx
                    claims[tostring(eggIdx)]=true
                    task.wait(0.06)
                end
            end
            -- Client title condition is first nine reward-bearing egg collections.
            if eggIdx<=9 then
                rewardEggCount += 1
                if not complete then allRewardEggs=false end
            end
        end
    end
    if rewardEggCount>0 and allRewardEggs and not state.indexTitleClaimed then
        local titleOk,result=invoke(PetFunction,"ClaimIndexTitle")
        if titleOk and type(result)=="table" and result.ok then
            Farm.Runtime.PetIndexClaims += 1; Farm.Runtime.RewardsClaimed += 1; claimedAny=true; Farm.Runtime.LastReward="COLLECTOR pet-index title"
        end
    end
    return claimedAny
end

-- ==========================================================================
-- REWARD CLAIMS
-- ==========================================================================

local function claimDaily()
    if not DailyRewardFunction then
        DailyRewardFunction = remote("DailyRewardFunction", "RemoteFunction")
    end
    if not DailyRewardFunction then
        return false
    end

    local ok, state = invoke(DailyRewardFunction, "GetState")
    if ok and type(state) == "table" and state.canClaim == true then
        local claimOk = invoke(DailyRewardFunction, "Claim")
        if claimOk then
            Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
            Farm.Runtime.LastReward = "Daily reward"
            return true
        end
    end

    return false
end

local function claimQuest()
    if not QuestFunction then
        QuestFunction = remote("QuestFunction", "RemoteFunction")
    end
    if not QuestFunction then
        return false
    end

    local ok, state = invoke(QuestFunction, "GetState")
    if not ok or type(state) ~= "table" or type(state.quests) ~= "table" then
        return false
    end

    local ready = false
    for _, quest in ipairs(state.quests) do
        if type(quest) == "table" and quest.id ~= nil then
            local progress = type(state.progress) == "table" and tonumber(state.progress[quest.id]) or 0
            local completed = type(state.completed) == "table" and state.completed[quest.id] == true
            local target = tonumber(quest.target) or math.huge

            if not completed and (progress or 0) >= target then
                ready = true
                break
            end
        end
    end

    if ready then
        local claimOk, result = invoke(QuestFunction, "Claim")
        if claimOk and type(result) == "table" and result.success == true then
            Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
            Farm.Runtime.LastReward = "Quest: " .. tostring(result.quest and result.quest.desc or "claimed")
            return true
        end
    end

    return false
end

local function claimGroupReward()
    if not GroupRewardsFunc then
        GroupRewardsFunc = remote("GroupRewardsFunc", "RemoteFunction")
    end
    if not GroupRewardsFunc then
        return false
    end

    local ok, state = invoke(GroupRewardsFunc, "GetState")
    if ok and type(state) == "table" and state.loaded == true and state.claimed ~= true then
        local claimOk, result = invoke(GroupRewardsFunc, "Claim")
        if claimOk and type(result) == "table" and result.success == true then
            Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
            Farm.Runtime.LastReward = "Group reward"
            return true
        end
    end

    return false
end

local function claimPlaytimeChests()
    if not PlaytimeChestsFunction then
        PlaytimeChestsFunction = remote("PlaytimeChestsFunction", "RemoteFunction")
    end
    if not PlaytimeChestsFunction then
        return false
    end

    local ok, state = invoke(PlaytimeChestsFunction, "state")
    if not ok or type(state) ~= "table" or type(state.chests) ~= "table" then
        return false
    end

    local elapsed = tonumber(state.elapsed) or 0
    local claimedAny = false

    for index, chest in ipairs(state.chests) do
        if type(chest) == "table" and chest.claimed ~= true then
            local needed = (tonumber(chest.min) or math.huge) * 60
            if elapsed >= needed then
                local claimOk, result = invoke(PlaytimeChestsFunction, "claim", index)
                if claimOk and type(result) == "table" and result.ok == true then
                    claimedAny = true
                    Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
                    Farm.Runtime.LastReward = "Playtime chest #" .. tostring(index)
                    if type(result.state) == "table" then
                        state = result.state
                        elapsed = tonumber(state.elapsed) or elapsed
                    end
                    task.wait(0.08)
                end
            end
        end
    end

    return claimedAny
end

local function useFreeSpin()
    if (tonumber(LocalPlayer:GetAttribute("SpinSpins")) or 0) < 1 then
        return false
    end

    if not SpinWheelFunction then
        SpinWheelFunction = remote("SpinWheelFunction", "RemoteFunction")
    end
    if not SpinWheelFunction then
        return false
    end

    local ok, result = invoke(SpinWheelFunction, "Spin")
    if ok and type(result) == "table" and result.ok == true then
        Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
        Farm.Runtime.LastReward = "Free spin (slice " .. tostring(result.slice or "?") .. ")"
        return true
    end

    return false
end

local function redeemPersonalSecretCode()
    if Farm.Runtime.SecretCodeTried then return false end
    Farm.Runtime.SecretCodeTried=true
    CodeFunction = CodeFunction or remote("CodeFunction","RemoteFunction")
    if not CodeFunction or not TileCodeSecret or type(TileCodeSecret.make)~="function" then
        Farm.Runtime.LastSecretCode="Unavailable"
        return false
    end
    local code=TileCodeSecret.make(LocalPlayer.UserId)
    local ok,result=invoke(CodeFunction,"Redeem",code)
    if ok and type(result)=="table" then
        Farm.Runtime.LastSecretCode=code..": "..tostring(result.msg or result.err or (result.success and "redeemed" or "checked"))
        if result.success then Farm.Runtime.RewardsClaimed += 1; Farm.Runtime.LastReward="Secret code "..code end
        return result.success==true
    end
    Farm.Runtime.LastSecretCode=code..": no confirmation"
    return false
end

-- ==========================================================================
-- CAVE / WINS FARM
-- ==========================================================================

local WallConfigCache = {}

local function getWallConfig(worldId)
    if WallConfigCache[worldId] then
        return WallConfigCache[worldId]
    end

    local moduleName = worldId == 1 and "WallConfig" or ("WallConfig" .. tostring(worldId))
    local module = ReplicatedStorage:FindFirstChild(moduleName)
    if not module then
        return nil
    end

    local ok, config = pcall(require, module)
    if ok and type(config) == "table" then
        WallConfigCache[worldId] = config
        return config
    end

    return nil
end

local function caveAttributeName(worldId)
    return worldId == 1 and "CaveWall" or ("CaveWall" .. tostring(worldId))
end

local function caveRoot(worldId)
    local root = worldId == 1 and Workspace or Workspace:FindFirstChild("World" .. tostring(worldId))
    return root and root:FindFirstChild("CaveWorld") or nil
end

local function myCaveDamage()
    local strength = math.max(1, getStrength())
    local mult = 1

    for _, name in ipairs({
        "UpgradeDamageMult",
        "GemDamageMult",
        "EnchantDamageMult",
        "ChestSwordDamageMult",
    }) do
        local value = numericValue(name, 1)
        if value > 0 then
            mult = mult * value
        end
    end

    return math.max(1, math.floor(strength * mult))
end

local function zoneEndWall(config, zone)
    if type(config.zoneEndWall) == "function" then
        local ok, value = pcall(config.zoneEndWall, zone)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return zone * (tonumber(config.WALLS_PER_ZONE) or 10)
end

local function bestCaveZone(config)
    if type(config) ~= "table" or type(config.ZONES) ~= "table" or type(config.wallHp) ~= "function" then
        return 1
    end

    local damage = myCaveDamage()
    local caveEvent = ReplicatedStorage:FindFirstChild("CaveEventLive")
    local hpMultiplier = 1

    if caveEvent and (tonumber(caveEvent:GetAttribute("EndsAt")) or 0) > os.time() then
        hpMultiplier = tonumber(caveEvent:GetAttribute("WallHpMult")) or 1
    end

    local maxHits = math.max(1, tonumber(Farm.Config.MaxCaveHitsPerWall) or 20)
    local best = 1

    for zone = 1, #config.ZONES do
        local wall = zoneEndWall(config, zone)
        local ok, hp = pcall(config.wallHp, wall)
        if not ok or not tonumber(hp) then
            break
        end

        local hits = math.ceil(tonumber(hp) * hpMultiplier / damage)
        if hits <= maxHits then
            best = zone
        else
            break
        end
    end

    return math.clamp(best, 1, #config.ZONES)
end

local function cavePadPosition(worldId, config, zone)
    local cave = caveRoot(worldId)
    local pads = cave and cave:FindFirstChild("Pads")
    local has2x = LocalPlayer:FindFirstChild("Has2xWinsPad")
    local wants2x = has2x and has2x.Value == true

    if pads then
        local part = nil
        if wants2x then
            part = pads:FindFirstChild("CavePad2x_Z" .. tostring(zone))
        end
        part = part or pads:FindFirstChild("CavePad_Z" .. tostring(zone))

        if part and part:IsA("BasePart") then
            return part.Position, part.Name
        end
    end

    if type(config.wallZ) == "function" then
        local ok, z = pcall(config.wallZ, zoneEndWall(config, zone))
        if ok and tonumber(z) then
            local xOffsets = {
                [1] = wants2x and 28.5 or -27.5,
                [2] = wants2x and 28 or -28,
                [3] = wants2x and 28 or -28,
                [4] = wants2x and 28 or -28,
                [5] = wants2x and 28 or -28,
            }
            return Vector3.new((tonumber(config.X) or 0) + xOffsets[worldId], (tonumber(config.FLOOR_TOP) or 2) + 1, tonumber(z) + 39.5), "fallback pad"
        end
    end

    return nil
end

local function caveWallPosition(config, wallIndex)
    if type(config.wallZ) ~= "function" then
        return nil
    end

    local ok, z = pcall(config.wallZ, wallIndex)
    if not ok or not tonumber(z) then
        return nil
    end

    return Vector3.new(
        tonumber(config.X) or 0,
        (tonumber(config.FLOOR_TOP) or 2) + 1,
        tonumber(z) - 4.5
    )
end

local function runCaveCycle()
    if Farm.Runtime.CaveMoving or not Farm.Config.AutoWins then
        return false
    end

    Farm.Runtime.CaveMoving = true
    setPhase("Preparing cave wins")

    if Farm.Config.AutoHighestWorld then
        goHighestWorld()
    end

    local worldId = currentWorld()
    local config = getWallConfig(worldId)
    if not config then
        Farm.Runtime.LastCave = "WallConfig unavailable for World " .. tostring(worldId)
        Farm.Runtime.CaveMoving = false
        return false
    end

    local character, humanoid, root = characterParts()
    if not character then
        Farm.Runtime.CaveMoving = false
        return false
    end

    -- The game's own Auto Wins script does the same initial cave-spawn correction.
    if tonumber(config.START_Z) and root.Position.Z < tonumber(config.START_Z) then
        if typeof(config.CAVE_SPAWN) == "Vector3" then
            pcall(function()
                character:PivotTo(CFrame.new(config.CAVE_SPAWN))
            end)
            task.wait(0.25)
        end
    end

    local attr = caveAttributeName(worldId)
    local targetZone = bestCaveZone(config)
    local endWall = zoneEndWall(config, targetZone)
    local maxWall = type(config.maxWall) == "function" and config.maxWall() or endWall

    Farm.Runtime.LastCave = string.format("World %d -> Zone %d (wall %d)", worldId, targetZone, endWall)

    local cycleStart = os.clock()
    local lastWall = tonumber(LocalPlayer:GetAttribute(attr)) or 1
    local lastAdvanceAt = os.clock()

    while Farm.Running and Farm.Config.AutoWins and os.clock() - cycleStart < 180 do
        local current = tonumber(LocalPlayer:GetAttribute(attr)) or 1

        if current ~= lastWall then
            lastWall = current
            lastAdvanceAt = os.clock()
        end

        if current > endWall or current > maxWall then
            local padPosition, padName = cavePadPosition(worldId, config, targetZone)
            if not padPosition then
                Farm.Runtime.LastCave = "Could not resolve cashout pad"
                break
            end

            setPhase("Cashing out cave wins")
            Farm.Runtime.LastCave = "Cashout: " .. tostring(padName)
            safeMoveTo(padPosition, 2.5, 18)

            local resetDeadline = os.clock() + 8
            while Farm.Running and Farm.Config.AutoWins and os.clock() < resetDeadline do
                local after = tonumber(LocalPlayer:GetAttribute(attr)) or 1
                if after <= 1 then
                    Farm.Runtime.CaveCashouts = Farm.Runtime.CaveCashouts + 1
                    Farm.Runtime.LastCave = "Cashout confirmed"
                    Farm.Runtime.CaveMoving = false
                    return true
                end
                task.wait(0.15)
            end

            Farm.Runtime.LastCave = "Reached cashout, waiting for reset"
            break
        end

        local target = caveWallPosition(config, current)
        if not target then
            Farm.Runtime.LastCave = "Could not resolve wall " .. tostring(current)
            break
        end

        setPhase(string.format("Cave W%d Z%d • wall %d/%d", worldId, targetZone, current, endWall))

        character, humanoid, root = characterParts()
        if not character then
            break
        end

        if horizontalDistance(root.Position, target) > 5 then
            humanoid:MoveTo(target)
        else
            humanoid:Move(Vector3.zero, false)
        end

        -- CaveRenderClient automatically fires CaveHitEvent when close enough.
        -- If a wall has not advanced for a while, nudge/jump rather than spam the remote ourselves.
        if os.clock() - lastAdvanceAt > 2.2 then
            humanoid.Jump = true
            humanoid:MoveTo(target)
            lastAdvanceAt = os.clock() - 1.0
        end

        task.wait(0.07)
    end

    Farm.Runtime.CaveMoving = false
    return false
end

-- ==========================================================================
-- OPTIONAL SPECIAL CHALLENGES
-- ==========================================================================

local function challengeTravel(owner, position, reach)
    if not acquireMovement(owner, 20) then return false end
    local ok=travelToPosition(position,reach or 5,16)
    Farm.Runtime.MovementOwnerUntil=os.clock()+20
    return ok
end

local function arenaStep()
    ArenaJoinEvent=ArenaJoinEvent or remote("ArenaJoinEvent","RemoteEvent")
    if not ArenaJoinEvent then return false end
    local live = arenaBossIsLive()
    if not live then releaseMovement("Arena"); Farm.Runtime.LastChallenge="Arena waiting"; return false end
    if not acquireMovement("Arena",20) then return false end
    if type(_G.ArenaJoin)=="function" then pcall(_G.ArenaJoin) else pcall(function() ArenaJoinEvent:FireServer() end) end
    local boss=Workspace:FindFirstChild("MegaBossLocal")
    local pos=boss and boss:GetPivot().Position or Vector3.new(-2000,14,0)
    travelToPosition(pos + Vector3.new(0,0,10),10,10)
    Farm.Runtime.LastChallenge="Arena boss"
    Farm.Runtime.MovementOwnerUntil=os.clock()+20
    return true
end

local function ownModeWall(roomName,prefix)
    local cave=Workspace:FindFirstChild(roomName)
    local room=cave and cave:FindFirstChild("Room")
    return room and room:FindFirstChild(prefix..LocalPlayer.UserId) or nil
end

local function infinityStep()
    if not acquireMovement("Infinity",20) then return false end
    if not LocalPlayer:GetAttribute("InInfinityCave") then
        local cave=Workspace:FindFirstChild("InfinityCave")
        local island=cave and cave:FindFirstChild("IslandPortal")
        local trigger=island and island:FindFirstChild("InfinityPortalTrigger")
        if not trigger then
            local w2=Workspace:FindFirstChild("World2"); local portal=w2 and w2:FindFirstChild("IslandPortal_W2")
            trigger=portal and portal:FindFirstChild("InfinityPortalTrigger")
        end
        if trigger then travelToPosition(trigger.Position,3,12) end
        Farm.Runtime.LastChallenge="Entering Infinity Cave"; return true
    end
    local wall=ownModeWall("InfinityCave","InfWall_")
    if wall then
        local pos=objectPosition(wall); if pos then travelToPosition(pos,10,10,"Walk") end
        Farm.Runtime.LastChallenge="Infinity Cave wall"
    end
    Farm.Runtime.MovementOwnerUntil=os.clock()+20
    return wall~=nil
end

local function eruptionStep()
    if not acquireMovement("Eruption",20) then return false end
    if not LocalPlayer:GetAttribute("InEruptionCave") then
        local w4=Workspace:FindFirstChild("World4"); local portal=w4 and w4:FindFirstChild("IslandPortal_W4")
        local trigger=portal and portal:FindFirstChild("InfinityPortalTrigger")
        if trigger then travelToPosition(trigger.Position,3,12) end
        Farm.Runtime.LastChallenge="Entering Eruption Cave"; return true
    end
    local wall=ownModeWall("EruptionCave","ErpWall_")
    if wall then local pos=objectPosition(wall); if pos then travelToPosition(pos,10,10,"Walk") end; Farm.Runtime.LastChallenge="Eruption Cave wall" end
    Farm.Runtime.MovementOwnerUntil=os.clock()+20
    return wall~=nil
end

local function glacierStep()
    GlacierChoiceEvent=GlacierChoiceEvent or remote("GlacierChoiceEvent","RemoteEvent")
    if not acquireMovement("Glacier",20) then return false end
    if not LocalPlayer:GetAttribute("InGlacierDig") then
        if (tonumber(LocalPlayer:GetAttribute("GlacierTickets")) or 0)<=0 then
            releaseMovement("Glacier"); Farm.Runtime.LastChallenge="Glacier: no tickets"; return false
        end
        local w5=Workspace:FindFirstChild("World5"); local portal=w5 and w5:FindFirstChild("IslandPortal_W5")
        local trigger=portal and portal:FindFirstChild("Portal")
        if trigger then travelToPosition(trigger.Position,3,12) end
        Farm.Runtime.LastChallenge="Entering Glacier Dig"; return true
    end
    local state=Farm.Runtime.GlacierState
    if type(state)=="table" then
        if state.phase=="choice" or state.state=="choice" then
            local risk=tonumber(state.riskPct) or 0
            local hasPet=state.petCarried~=nil and state.petCarried~=false
            local bank=(Farm.Config.GlacierBankWithPet and hasPet) or risk>=math.max(0,tonumber(Farm.Config.GlacierMaxRiskPercent) or 18)
            if GlacierChoiceEvent then pcall(function() GlacierChoiceEvent:FireServer(bank and "bank" or "deeper") end) end
            Farm.Runtime.LastChallenge="Glacier choice: "..(bank and "BANK" or "DEEPER").." @ "..tostring(risk).."%"
            task.wait(0.3)
        elseif typeof(state.wallPos)=="Vector3" then
            travelToPosition(state.wallPos,12,10,"Walk")
            Farm.Runtime.LastChallenge="Glacier digging"
        end
    end
    Farm.Runtime.MovementOwnerUntil=os.clock()+20
    return true
end

-- Challenge/event state listeners.
if ArenaSyncEvent then
    track(ArenaSyncEvent.OnClientEvent:Connect(function(payload)
        if type(payload)=="table" then
            local kind=payload.type or payload.state
            if kind=="open" then Farm.Runtime.ArenaLive=true
            elseif kind=="joined" then Farm.Runtime.ArenaJoined=true
            elseif kind=="close" or kind=="ended" or kind=="victory" then Farm.Runtime.ArenaLive=false; Farm.Runtime.ArenaJoined=false end
        end
    end))
end
if GlacierDigEvent then
    track(GlacierDigEvent.OnClientEvent:Connect(function(payload)
        if type(payload)=="table" then Farm.Runtime.GlacierState=payload end
    end))
end
if CaveEventAnnounce then
    track(CaveEventAnnounce.OnClientEvent:Connect(function(payload,...)
        if type(payload)=="table" then Farm.Runtime.ActiveGameEvent=tostring(payload.name or payload.title or payload.event or "Cave event")
        else Farm.Runtime.ActiveGameEvent=tostring(payload or "Cave event") end
    end))
end

-- ==========================================================================
-- AUTOMATION LOOPS
-- ==========================================================================

-- Main progression: rebirth -> highest world -> best actual pad multiplier.
task.spawn(function()
    while Farm.Running do
        local now = os.clock()

        if Farm.Config.AutoRebirth
            and (not Farm.Config.AutoWins or Farm.Config.RebirthWhileWins)
            and not specialChallengeEnabled()
            and now - Farm.Runtime.LastRebirthCheck >= 0.18 then

            Farm.Runtime.LastRebirthCheck = now
            local ok, err = pcall(doRebirth)
            if not ok then
                setError(err)
            end
        end

        if Farm.Config.AutoHighestWorld
            and not Farm.Config.AutoWins
            and not specialChallengeEnabled()
            and not movementBusy()
            and not Farm.Runtime.WorldTraveling
            and now - Farm.Runtime.LastWorldCheck >= 3 then

            Farm.Runtime.LastWorldCheck = now
            local ok, err = pcall(goHighestWorld)
            if not ok then
                setError(err)
            end
        end

        if Farm.Config.BestTrainingPad
            and not Farm.Config.AutoWins
            and not specialChallengeEnabled()
            and not movementBusy()
            and not Farm.Runtime.WorldTraveling
            and not Farm.Runtime.PadMoving
            and now - Farm.Runtime.LastPadMoveAt >= 1.25 then

            local ok, err = pcall(goBestTrainingPad)
            if not ok then
                setError(err)
            end

            -- Successful pad confirmation should not cause repeated teleports.
            if getTrainingMultiplier() >= Farm.Runtime.SelectedPadMult * 0.95 then
                Farm.Runtime.LastPadMoveAt = now
            end
        end

        task.wait(0.06)
    end
end)

-- Economy scheduler. Permanent/free improvements get priority; spending systems
-- respect the shared Wins reserve and never invoke Robux product paths.
task.spawn(function()
    while Farm.Running do
        local now=os.clock()
        if now-Farm.Runtime.LastEconomyCheck>=0.75 then
            Farm.Runtime.LastEconomyCheck=now
            local ok,err=pcall(function()
                if Farm.Config.AutoGemForge then buyGemUpgradeOnce() end
                if Farm.Config.AutoUpgrades then buyAffordableUpgradeOnce() end
                if Farm.Config.AutoAuras then buyBestAffordableAuraOnce()
                elseif Farm.Config.AutoEquipBestAura then equipBestAura() end
                if Farm.Config.AutoSwords and not Farm.Config.AutoWins and not specialChallengeEnabled() and not movementBusy() then buyBestAffordableSwordOnce() end
                if Farm.Config.AutoFreeTitleRolls or Farm.Config.AutoPaidTitleRolls or Farm.Config.AutoEquipBestTitle then rollTitlesSmart() end
                if Farm.Config.AutoSmartEnchants then smartEnchantOnce() end
                applyPotionAutoMode()
            end)
            if not ok then setError(err) end
        end
        task.wait(0.15)
    end
end)

-- Pets / hatching.
task.spawn(function()
    while Farm.Running do
        local now = os.clock()

        if Farm.Config.AutoEquipBest and now - Farm.Runtime.LastPetCheck >= 4 then
            Farm.Runtime.LastPetCheck = now
            pcall(equipBestPets)
        end

        if Farm.Config.AutoHatch and now - Farm.Runtime.LastHatchCheck >= 1.0 then
            Farm.Runtime.LastHatchCheck = now
            local ok, err = pcall(hatchBestAffordableEgg)
            if not ok then setError(err) end
        end
        if Farm.Config.AutoPetFusion and now-Farm.Runtime.LastFusionCheck>=4 then
            Farm.Runtime.LastFusionCheck=now
            local ok,err=pcall(claimOrStartPetMerge); if not ok then setError(err) end
        end
        if Farm.Config.AutoPetIndexClaims and now-Farm.Runtime.LastIndexCheck>=12 then
            Farm.Runtime.LastIndexCheck=now
            local ok,err=pcall(claimPetIndexRewards); if not ok then setError(err) end
        end

        task.wait(0.2)
    end
end)

-- Rewards.
task.spawn(function()
    while Farm.Running do
        if os.clock() - Farm.Runtime.LastRewardCheck >= 10 then
            Farm.Runtime.LastRewardCheck = os.clock()

            if Farm.Config.AutoDaily then
                pcall(claimDaily)
            end
            if Farm.Config.AutoQuests then
                pcall(claimQuest)
            end
            if Farm.Config.AutoGroupReward then
                pcall(claimGroupReward)
            end
            if Farm.Config.AutoPlaytimeChests then
                pcall(claimPlaytimeChests)
            end
            if Farm.Config.AutoSpins then pcall(useFreeSpin) end
            if Farm.Config.AutoSecretCode then pcall(redeemPersonalSecretCode) end
        end

        task.wait(0.35)
    end
end)

-- Cave wins loop. It intentionally owns movement while enabled, so pad positioning pauses.
task.spawn(function()
    while Farm.Running do
        if Farm.Config.AutoWins and not specialChallengeEnabled() and not movementBusy("Cave") then
            acquireMovement("Cave", 30)
            local ok, err = pcall(runCaveCycle)
            if not ok then
                setError(err)
                Farm.Runtime.CaveMoving = false
            end
            releaseMovement("Cave")
            task.wait(0.25)
        else
            releaseMovement("Cave")
            task.wait(0.25)
        end
    end
end)

-- Optional challenge scheduler: one special mode owns movement at a time in
-- deterministic priority order so modes never fight each other.
task.spawn(function()
    while Farm.Running do
        if Farm.Config.AutoGlacierDig and glacierCanRun() then pcall(glacierStep)
        elseif Farm.Config.AutoArena and arenaBossIsLive() then pcall(arenaStep)
        elseif Farm.Config.AutoEruptionCave then pcall(eruptionStep)
        elseif Farm.Config.AutoInfinityCave then pcall(infinityStep)
        else
            for _,owner in ipairs({"Glacier","Arena","Eruption","Infinity"}) do releaseMovement(owner) end
        end
        task.wait(0.22)
    end
end)

-- ==========================================================================
-- UI
-- ==========================================================================

FarmTab:CreateSection("Smart Autofarm")
local StatusParagraph = FarmTab:CreateParagraph({
    Title = "+1 Power Per Click",
    Content = "Starting...",
    Height = 105,
})

FarmTab:CreateToggle({
    Name = "Auto Power / Click",
    CurrentValue = Farm.Config.AutoPower,
    Flag = "PuckPower_AutoPower",
    Callback = function(value)
        Farm.Config.AutoPower = value == true
    end,
})

FarmTab:CreateToggle({
    Name = "Use Best Unlocked Training Pad",
    CurrentValue = Farm.Config.BestTrainingPad,
    Flag = "PuckPower_BestPad",
    Callback = function(value)
        Farm.Config.BestTrainingPad = value == true
        Farm.Runtime.LastPadMoveAt = -math.huge
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = Farm.Config.AutoRebirth,
    Flag = "PuckPower_AutoRebirth",
    Callback = function(value)
        Farm.Config.AutoRebirth = value == true
    end,
})

FarmTab:CreateToggle({
    Name = "Use Highest Unlocked World",
    CurrentValue = Farm.Config.AutoHighestWorld,
    Flag = "PuckPower_HighestWorld",
    Callback = function(value)
        Farm.Config.AutoHighestWorld = value == true
        Farm.Runtime.LastWorldCheck = -math.huge
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Wins / Cave Farm",
    CurrentValue = Farm.Config.AutoWins,
    Flag = "PuckPower_AutoWins",
    Callback = function(value)
        Farm.Config.AutoWins = value == true
        if value then
            setPhase("Starting cave farm")
        else
            Farm.Runtime.CaveMoving = false
            Farm.Runtime.LastPadMoveAt = -math.huge
            setPhase("Returning to power farm")
        end
    end,
})

FarmTab:CreateButton({
    Name = "Go To Best Pad Now",
    Callback = function()
        task.spawn(function()
            if Farm.Config.AutoHighestWorld then
                pcall(goHighestWorld)
            end
            pcall(goBestTrainingPad)
        end)
    end,
})

ProgressTab:CreateSection("Progression")
ProgressTab:CreateToggle({
    Name = "Auto Buy Affordable Upgrades",
    CurrentValue = Farm.Config.AutoUpgrades,
    Flag = "PuckPower_AutoUpgrades",
    Callback = function(value)
        Farm.Config.AutoUpgrades = value == true
    end,
})

ProgressTab:CreateToggle({
    Name = "Allow Rebirth During Cave Farm",
    CurrentValue = Farm.Config.RebirthWhileWins,
    Flag = "PuckPower_RebirthWins",
    Callback = function(value)
        Farm.Config.RebirthWhileWins = value == true
    end,
})

ProgressTab:CreateButton({
    Name = "Buy One Affordable Upgrade",
    Callback = function()
        task.spawn(buyAffordableUpgradeOnce)
    end,
})

EconomyTab:CreateSection("Smart Wins Economy")
EconomyTab:CreateSlider({Name="Keep Wins Reserve",Range={0,90},Increment=5,CurrentValue=Farm.Config.SmartWinsReservePercent,Suffix="%",Flag="PuckPower_WinsReserve",Callback=function(v) Farm.Config.SmartWinsReservePercent=tonumber(v) or 25 end})
EconomyTab:CreateToggle({Name="Auto Buy Best Sword",CurrentValue=Farm.Config.AutoSwords,Flag="PuckPower_Swords",Callback=function(v) Farm.Config.AutoSwords=v==true end})
EconomyTab:CreateToggle({Name="Auto Buy Best Affordable Aura",CurrentValue=Farm.Config.AutoAuras,Flag="PuckPower_Auras",Callback=function(v) Farm.Config.AutoAuras=v==true end})
EconomyTab:CreateToggle({Name="Auto Equip Best Aura",CurrentValue=Farm.Config.AutoEquipBestAura,Flag="PuckPower_AuraEquip",Callback=function(v) Farm.Config.AutoEquipBestAura=v==true end})
EconomyTab:CreateToggle({Name="Auto Gem Forge (Adaptive)",CurrentValue=Farm.Config.AutoGemForge,Flag="PuckPower_Gems",Callback=function(v) Farm.Config.AutoGemForge=v==true end})
EconomyTab:CreateToggle({Name="Auto Equip Best Title",CurrentValue=Farm.Config.AutoEquipBestTitle,Flag="PuckPower_TitleEquip",Callback=function(v) Farm.Config.AutoEquipBestTitle=v==true end})
EconomyTab:CreateToggle({Name="Use Free Title Rolls",CurrentValue=Farm.Config.AutoFreeTitleRolls,Flag="PuckPower_FreeTitles",Callback=function(v) Farm.Config.AutoFreeTitleRolls=v==true end})
EconomyTab:CreateToggle({Name="Spend Wins On Base Title Rolls",CurrentValue=Farm.Config.AutoPaidTitleRolls,Flag="PuckPower_PaidTitles",Callback=function(v) Farm.Config.AutoPaidTitleRolls=v==true end})
EconomyTab:CreateSlider({Name="Paid Title Rolls / Cycle",Range={1,20},Increment=1,CurrentValue=Farm.Config.MaxPaidTitleRollsPerCycle,Flag="PuckPower_TitleRollCount",Callback=function(v) Farm.Config.MaxPaidTitleRollsPerCycle=tonumber(v) or 3 end})
EconomyTab:CreateToggle({Name="Smart Sword Enchants (spends Wins)",CurrentValue=Farm.Config.AutoSmartEnchants,Flag="PuckPower_Enchants",Callback=function(v) Farm.Config.AutoSmartEnchants=v==true end})
EconomyTab:CreateSlider({Name="Auto-Lock Enchant Tier",Range={1,5},Increment=1,CurrentValue=Farm.Config.AutoLockEnchantTier,Flag="PuckPower_EnchantTier",Callback=function(v) Farm.Config.AutoLockEnchantTier=tonumber(v) or 4 end})
EconomyTab:CreateToggle({Name="Manage Game Auto-Potions",CurrentValue=Farm.Config.ManagePotionServerMode,Flag="PuckPower_PotionManage",Callback=function(v) Farm.Config.ManagePotionServerMode=v==true; Farm.Runtime.PotionModeApplied=nil end})
EconomyTab:CreateToggle({Name="Game Auto-Use Potions",CurrentValue=Farm.Config.AutoPotionServerMode,Flag="PuckPower_Potions",Callback=function(v) Farm.Config.AutoPotionServerMode=v==true; Farm.Runtime.PotionModeApplied=nil end})
EconomyTab:CreateButton({Name="Run Economy Pass Now",Callback=function() task.spawn(function() pcall(buyGemUpgradeOnce); pcall(buyAffordableUpgradeOnce); pcall(buyBestAffordableAuraOnce); pcall(buyBestAffordableSwordOnce); pcall(rollTitlesSmart) end) end})

PetsTab:CreateSection("Pets / Collection")
PetsTab:CreateToggle({Name="Auto Equip Best Pets",CurrentValue=Farm.Config.AutoEquipBest,Flag="PuckPower_PetsBest2",Callback=function(v) Farm.Config.AutoEquipBest=v==true end})
PetsTab:CreateToggle({Name="Auto Hatch Best Affordable Egg",CurrentValue=Farm.Config.AutoHatch,Flag="PuckPower_Hatch2",Callback=function(v) Farm.Config.AutoHatch=v==true end})
PetsTab:CreateSlider({Name="Egg Wins Spend",Range={1,100},Increment=1,CurrentValue=Farm.Config.EggSpendPercent,Suffix="%",Flag="PuckPower_EggSpend2",Callback=function(v) Farm.Config.EggSpendPercent=tonumber(v) or 25 end})
PetsTab:CreateToggle({Name="Auto Pet Fusion",CurrentValue=Farm.Config.AutoPetFusion,Flag="PuckPower_Fusion",Callback=function(v) Farm.Config.AutoPetFusion=v==true end})
PetsTab:CreateToggle({Name="Auto Pet Index Rewards + Title",CurrentValue=Farm.Config.AutoPetIndexClaims,Flag="PuckPower_Index",Callback=function(v) Farm.Config.AutoPetIndexClaims=v==true end})
PetsTab:CreateButton({Name="Fusion / Index Pass Now",Callback=function() task.spawn(function() pcall(claimOrStartPetMerge); pcall(claimPetIndexRewards); pcall(equipBestPets) end) end})

ChallengesTab:CreateSection("Optional Special Farms")
ChallengesTab:CreateParagraph({Title="Priority",Content="Glacier > Arena > Eruption > Infinity. Enable one at a time for predictable movement. Normal power/cave travel pauses while a special mode is active.",Height=70})
ChallengesTab:CreateToggle({Name="Auto Arena Boss",CurrentValue=Farm.Config.AutoArena,Flag="PuckPower_Arena",Callback=function(v) Farm.Config.AutoArena=v==true end})
ChallengesTab:CreateToggle({Name="Auto Infinity Cave",CurrentValue=Farm.Config.AutoInfinityCave,Flag="PuckPower_Infinity",Callback=function(v) Farm.Config.AutoInfinityCave=v==true end})
ChallengesTab:CreateToggle({Name="Auto Eruption Cave",CurrentValue=Farm.Config.AutoEruptionCave,Flag="PuckPower_Eruption",Callback=function(v) Farm.Config.AutoEruptionCave=v==true end})
ChallengesTab:CreateToggle({Name="Auto Glacier Dig",CurrentValue=Farm.Config.AutoGlacierDig,Flag="PuckPower_Glacier",Callback=function(v) Farm.Config.AutoGlacierDig=v==true end})
ChallengesTab:CreateSlider({Name="Glacier Bank At Risk",Range={0,100},Increment=1,CurrentValue=Farm.Config.GlacierMaxRiskPercent,Suffix="%",Flag="PuckPower_GlacierRisk",Callback=function(v) Farm.Config.GlacierMaxRiskPercent=tonumber(v) or 18 end})
ChallengesTab:CreateToggle({Name="Always Bank Frozen Pet",CurrentValue=Farm.Config.GlacierBankWithPet,Flag="PuckPower_GlacierPet",Callback=function(v) Farm.Config.GlacierBankWithPet=v==true end})

RewardsTab:CreateSection("Automatic Claims")
RewardsTab:CreateToggle({
    Name = "Daily Reward",
    CurrentValue = Farm.Config.AutoDaily,
    Flag = "PuckPower_Daily",
    Callback = function(value)
        Farm.Config.AutoDaily = value == true
    end,
})

RewardsTab:CreateToggle({
    Name = "Completed Quests",
    CurrentValue = Farm.Config.AutoQuests,
    Flag = "PuckPower_Quests",
    Callback = function(value)
        Farm.Config.AutoQuests = value == true
    end,
})

RewardsTab:CreateToggle({
    Name = "Group Reward",
    CurrentValue = Farm.Config.AutoGroupReward,
    Flag = "PuckPower_Group",
    Callback = function(value)
        Farm.Config.AutoGroupReward = value == true
    end,
})

RewardsTab:CreateToggle({
    Name = "Playtime Chests",
    CurrentValue = Farm.Config.AutoPlaytimeChests,
    Flag = "PuckPower_Playtime",
    Callback = function(value)
        Farm.Config.AutoPlaytimeChests = value == true
    end,
})

RewardsTab:CreateToggle({
    Name = "Free Wheel Spins",
    CurrentValue = Farm.Config.AutoSpins,
    Flag = "PuckPower_Spins",
    Callback = function(value)
        Farm.Config.AutoSpins = value == true
    end,
})

RewardsTab:CreateToggle({Name="Personal LUCK Code",CurrentValue=Farm.Config.AutoSecretCode,Flag="PuckPower_SecretCode",Callback=function(v) Farm.Config.AutoSecretCode=v==true; if v then Farm.Runtime.SecretCodeTried=false end end})
RewardsTab:CreateToggle({Name="Pet Index Rewards",CurrentValue=Farm.Config.AutoPetIndexClaims,Flag="PuckPower_IndexRewards",Callback=function(v) Farm.Config.AutoPetIndexClaims=v==true end})

RewardsTab:CreateButton({
    Name = "Claim Everything Available Now",
    Callback = function()
        task.spawn(function()
            pcall(claimDaily)
            pcall(claimQuest)
            pcall(claimGroupReward)
            pcall(claimPlaytimeChests)
            pcall(useFreeSpin)
            pcall(claimPetIndexRewards)
            Farm.Runtime.SecretCodeTried=false
            pcall(redeemPersonalSecretCode)
        end)
    end,
})

SettingsTab:CreateSection("Movement / Farming")
SettingsTab:CreateDropdown({
    Name = "Training Pad Travel",
    Options = {"Teleport", "Walk"},
    CurrentOption = {Farm.Config.PadTravelMode},
    Flag = "PuckPower_PadTravel",
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        Farm.Config.PadTravelMode = value == "Walk" and "Walk" or "Teleport"
        Farm.Runtime.LastPadMoveAt = -math.huge
    end,
})

SettingsTab:CreateToggle({
    Name = "Click Nearest Enemy Too",
    CurrentValue = Farm.Config.ClickNearestEnemy,
    Flag = "PuckPower_EnemyClick",
    Callback = function(value)
        Farm.Config.ClickNearestEnemy = value == true
    end,
})

SettingsTab:CreateSlider({
    Name = "Max Cave Hits Per Wall",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = Farm.Config.MaxCaveHitsPerWall,
    Flag = "PuckPower_CaveHits",
    Callback = function(value)
        Farm.Config.MaxCaveHitsPerWall = tonumber(value) or 20
    end,
})

SettingsTab:CreateButton({
    Name = "Go Highest World Now",
    Callback = function()
        task.spawn(goHighestWorld)
    end,
})

SettingsTab:CreateButton({
    Name = "Rebirth Now If Ready",
    Callback = function()
        task.spawn(doRebirth)
    end,
})

SettingsTab:CreateButton({
    Name = "Unload Autofarm",
    Callback = function()
        Farm:Unload()
    end,
})

-- ==========================================================================
-- STATUS
-- ==========================================================================

task.spawn(function()
    while Farm.Running do
        local world = currentWorld()
        local mult = getTrainingMultiplier()
        local strength = getStrength()
        local wins = getWins()
        local rebirths = getRebirths()
        local level = getLevel()

        StatusParagraph:Set({
            Title = Farm.Config.AutoWins and "Cave Wins Farm" or Farm.Runtime.Phase,
            Content = string.format(
                "Power: %s • Level: %s • Rebirths: %s • Wins: %s\nWorld: %d • Training: x%s\nBest training pad: %s (x%s)",
                tostring(strength),
                tostring(level),
                tostring(rebirths),
                tostring(wins),
                world,
                tostring(mult),
                tostring(Farm.Runtime.SelectedPadName),
                tostring(Farm.Runtime.SelectedPadMult)
            ),
        })

        task.wait(0.35)
    end
end)

-- ==========================================================================
-- RESPAWN / UNLOAD
-- ==========================================================================

track(LocalPlayer.CharacterAdded:Connect(function()
    Farm.Runtime.LastPadMoveAt = -math.huge
    Farm.Runtime.LastWorldCheck = -math.huge
    Farm.Runtime.CaveMoving = false
    Farm.Runtime.MovementOwner = nil
    Farm.Runtime.MovementOwnerUntil = 0
    task.wait(0.75)
end))

function Farm:Unload()
    if not self.Running then
        return
    end

    self.Running = false
    self.Config.AutoPower = false
    self.Config.AutoWins = false
    self.Runtime.CaveMoving = false
    self.Runtime.PadMoving = false
    self.Runtime.MovementOwner = nil
    self.Config.AutoArena = false
    self.Config.AutoInfinityCave = false
    self.Config.AutoEruptionCave = false
    self.Config.AutoGlacierDig = false

    local _, humanoid = characterParts()
    if humanoid then
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    if GENV[SCRIPT_KEY] == self then
        GENV[SCRIPT_KEY] = nil
    end

    pcall(function()
        Window:Destroy()
    end)
end

pcall(function()
    Window:SetCloseCallback(function()
        Farm:Unload()
    end)
end)

if game.PlaceId ~= EXPECTED_PLACE_ID then
    Farm.Runtime.LastError = "Loaded outside inspected PlaceId " .. tostring(EXPECTED_PLACE_ID)
end

PuckUI:Notify({
    Title = "RAINZXDEV",
    Content = "+1 Power autofarm loaded successfully.",
    Duration = 4,
})
