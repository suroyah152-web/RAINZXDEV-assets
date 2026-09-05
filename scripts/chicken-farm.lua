-- Chicken Farm Autofarm v10.2 - Full Chicken Farm Build + Compatibility Mode
-- Built from the game's own client routes / progression logic.
-- Chicken Farm only: wrong-place execution exits safely instead of teleporting.
-- Client-originated place changes AND same-place server hops are blocked when possible.
-- Server-forced transfers are checked after teleport and returned to the original server instance when queueing is supported.
-- Progression logic uses the game's ChickenMath, Luckyblocks and GlobalEvents modules when available.
-- Re-run safe: executing a new copy shuts down the previous copy first.

local GENV = (getgenv and getgenv()) or _G

-- This experience exposes two places in ReplicatedStorage.Paper.Shared.Config:
--   MainPlaceId    = 137233438285284
--   TestingPlaceId = 136763386266562
-- v7 treats the main place as the farm destination.
local MAIN_PLACE_ID = 137233438285284
local SECONDARY_PLACE_ID = 136763386266562
local AUTO_RESUME_FILE = "ChickenFarm_Autofarm_v8_2_AutoResume.lua"

-- Lock to the exact server instance we started farming in.  A queued bootstrap
-- can pre-seed this value so the lock survives a teleport/re-execution.
-- Compatibility-first session lock. Manual execution always locks to the
-- server the user is CURRENTLY in; stale JobIds from an older execution are
-- never allowed to stop the GUI from loading.
local LOCKED_JOB_ID = (game.PlaceId == MAIN_PLACE_ID and tostring(game.JobId or "")) or ""
GENV.__CHICKEN_FARM_LOCKED_JOB_ID = LOCKED_JOB_ID

local EarlyPlayers = game:GetService("Players")
local EarlyTeleportService = game:GetService("TeleportService")
local EarlyLocalPlayer = EarlyPlayers.LocalPlayer or EarlyPlayers.PlayerAdded:Wait()

-- Cross-game compatibility mode.
-- In the real Chicken Farm place we use its actual modules/remotes. Elsewhere
-- the same full UI is allowed to load with a harmless local backend so manual
-- loader selection never teleports, errors, or stops at startup.
local CROSS_GAME_MODE = game.PlaceId ~= MAIN_PLACE_ID

-- Minimal startup indicator. If startup fails, leave this visible with the
-- exact stage instead of silently returning.
local BootGui, BootLabel
do
    local okBoot = pcall(function()
        BootGui = Instance.new("ScreenGui")
        BootGui.Name = "ChickenFarmV82Boot"
        BootGui.ResetOnSpawn = false
        BootGui.IgnoreGuiInset = false

        BootLabel = Instance.new("TextLabel")
        BootLabel.Name = "Status"
        BootLabel.Size = UDim2.fromOffset(420, 42)
        BootLabel.Position = UDim2.new(0.5, -210, 0, 18)
        BootLabel.BackgroundColor3 = Color3.fromRGB(24, 26, 31)
        BootLabel.BackgroundTransparency = 0.08
        BootLabel.BorderSizePixel = 0
        BootLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        BootLabel.Font = Enum.Font.GothamMedium
        BootLabel.TextSize = 14
        BootLabel.Text = "Chicken Farm v10.2: starting..."
        BootLabel.Parent = BootGui

        local parent
        local okHui, hui = pcall(function()
            if type(gethui) == "function" then return gethui() end
        end)
        if okHui and hui then parent = hui end
        if not parent then
            local okCore = pcall(function() BootGui.Parent = game:GetService("CoreGui") end)
            if not okCore then parent = EarlyLocalPlayer:WaitForChild("PlayerGui", 5) end
        end
        if parent then BootGui.Parent = parent end
    end)
    if not okBoot then
        BootGui, BootLabel = nil, nil
    end
end

local function bootStatus(text)
    if BootLabel then
        pcall(function() BootLabel.Text = "Chicken Farm v10.2: " .. tostring(text) end)
    end
end

bootStatus(CROSS_GAME_MODE and "starting compatibility mode..." or "loading core game modules...")

local PreviousState
local PreviousConfig
local PreviousVersion
if GENV.__CHICKEN_FARM_AUTOFARM then
    pcall(function()
        if type(GENV.__CHICKEN_FARM_AUTOFARM.State) == "table" then
            PreviousState = table.clone(GENV.__CHICKEN_FARM_AUTOFARM.State)
        end
        if type(GENV.__CHICKEN_FARM_AUTOFARM.Config) == "table" then
            PreviousConfig = table.clone(GENV.__CHICKEN_FARM_AUTOFARM.Config)
        end
        PreviousVersion = GENV.__CHICKEN_FARM_AUTOFARM.Version
        GENV.__CHICKEN_FARM_AUTOFARM:Unload()
    end)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local Paper
local ChickenMath
local ChickenTable
local Luckyblocks
local GlobalEvents

local ok, err = pcall(function()
    if CROSS_GAME_MODE then
        -- Same script/UI, harmless compatibility backend. Nothing here attempts
        -- to imitate or modify Chicken Farm's real server state.
        local compatStats = {
            Cash = 0, Eggs = 0, EggsProcessing = 0, TotalChickens = 0,
            Chickens = 0, Rebirth = 0, CashCollect = 0, Gems = 0,
            Friends = 0, InGroup = false, LastGroupClaim = 0,
            ProcessLevel = 0, ProcessingLevel = 0, ProcessSpeedUpgrade = 0,
            BuyTierLevel = 1, EquippedLuckyBlock = 0, Tutorial = true,
            AwardedChicken = 0,
        }

        Paper = {
            Network = {
                InvokeServer = function()
                    return false, "Chicken Farm backend unavailable in this place"
                end,
                FireServer = function()
                    return false
                end,
            },
            Stats = {
                LoadedAsync = function() return true end,
                GetValue = function(a, b)
                    local name = b or a
                    return compatStats[name]
                end,
                Changed = function()
                    return nil
                end,
            },
            Number = {
                format = function(value)
                    return tostring(value or 0)
                end,
            },
            Misc = {
                GetUnixTime = function() return os.time() end,
            },
        }

        ChickenMath = {
            GetProcessAmount = function() return 1 end,
            GetUpgradeBoost = function() return 1 end,
            GetRebirthReq = function() return math.huge end,
            GetRebirthBoost = function() return 1 end,
            GetBuyChickenCost = function() return math.huge end,
            GetLuckyBlockCost = function() return math.huge end,
            GetUpgTierReq = function() return math.huge end,
            GetUpgTierCost = function() return math.huge end,
            GetProcessCost = function() return math.huge end,
            GetUpgradeCost = function() return math.huge end,
        }

        ChickenTable = {}
        for i = 1, 64 do ChickenTable[i] = {} end
        Luckyblocks = { Blocks = {} }
        GlobalEvents = {
            GetBoost = function() return 1 end,
            IsActive = function() return false end,
        }
        return
    end

    -- Slow joins can replicate the game framework several seconds after the
    -- Roblox loading screen disappears. Give all required paths one shared
    -- 30-second startup window instead of timing each path independently.
    local deadline = os.clock() + 30

    local function waitPath(root, path)
        local current = root

        for _, childName in ipairs(path) do
            local child = current:FindFirstChild(childName)

            while not child and os.clock() < deadline do
                task.wait(0.05)
                child = current:FindFirstChild(childName)
            end

            if not child then
                return nil
            end

            current = child
        end

        return current
    end

    local paperModule = waitPath(ReplicatedStorage, {"Paper"})
    local chickenModule = waitPath(ReplicatedStorage, {"Modules", "Shared", "Chickens"})
    local chickenTableModule = waitPath(ReplicatedStorage, {"Tables", "Chickens"})

    if not paperModule or not chickenModule or not chickenTableModule then
        error(
            "Required Chicken Farm modules did not replicate within 30 seconds "
            .. "(Paper=" .. tostring(paperModule ~= nil)
            .. ", ChickensModule=" .. tostring(chickenModule ~= nil)
            .. ", ChickensTable=" .. tostring(chickenTableModule ~= nil) .. ")"
        )
    end

    Paper = require(paperModule)
    ChickenMath = require(chickenModule)
    ChickenTable = require(chickenTableModule)

    -- Optional optimizer modules never block startup.
    local tablesFolder = ReplicatedStorage:FindFirstChild("Tables")
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local sharedFolder = modulesFolder and modulesFolder:FindFirstChild("Shared")

    local luckyModule = tablesFolder and tablesFolder:FindFirstChild("Luckyblocks")
    if luckyModule then
        pcall(function()
            Luckyblocks = require(luckyModule)
        end)
    end

    local globalModule = sharedFolder and sharedFolder:FindFirstChild("GlobalEvents")
    if globalModule then
        pcall(function()
            GlobalEvents = require(globalModule)
        end)
    end
end)

if not ok or not Paper or not Paper.Network or not Paper.Stats then
    local fail = "core modules failed: " .. tostring(err)
    bootStatus(fail)
    warn("[Chicken Farm Autofarm v10.2] " .. fail)
    return
end

bootStatus("waiting for player stats...")
local statsOk, statsErr = pcall(function()
    Paper.Stats.LoadedAsync()
end)
if not statsOk then
    -- Stats loading failure should not kill the GUI; loops will simply wait for
    -- values and the status panel will expose the error.
    bootStatus("stats load warning: " .. tostring(statsErr))
else
    bootStatus("building autofarm...")
end

local Farm = {
    Version = 10.2,
    Running = true,
    Connections = {},
    EggAttempts = {},
    EggIds = {},
    EggWorkers = {},
    LuckyAttempts = {},
    RouteLocks = {},
    RouteFailures = {},
    RouteAdaptive = {},
    ReactiveLocks = {},
    LastAction = CROSS_GAME_MODE and "Compatibility mode - real Chicken Farm backend is unavailable here" or "Starting...",
    LastError = "",
    MasterEnabled = true,
    SpendBusy = false,
    Metrics = {
        EggPickups = 0,
        EggAttempts = 0,
        CashCollects = 0,
        Deposits = 0,
        ChickenBuys = 0,
        Merges = 0,
        ProcessUpgrades = 0,
        TierUpgrades = 0,
        GemUpgrades = 0,
        Rebirths = 0,
        LuckyOpened = 0,
        LuckyDiscarded = 0,
        RewardsClaimed = 0,
        RemoteErrors = 0,
        RouteSuccesses = 0,
        RouteRejects = 0,
        Started = os.clock(),
        StartCash = 0,
        StartChickens = 0,
        StartRebirth = 0,
    },
    Config = {
        Profile = "Turbo",
        ProcessBacklogTarget = 5,
        EggStartDelay = 0.115,
        EggAttemptCooldown = 0.055,
        EggFallbackDelay = 0.035,
        EggSweepInterval = 0.18,
        EggRetryDelay = 0.075,
        EggMaxAttempts = 42,
        DepositInterval = 0.16,
        CashInterval = 0.18,
        BuyInterval = 0.10,
        MergeInterval = 0.16,
        UpgradeInterval = 0.12,
        TierInterval = 0.30,
        GemInterval = 0.20,

        -- Route cooldowns are separate from loop intervals. Turbo lowers both,
        -- while invokeLocked still backs off automatically when a route rejects.
        CashCooldown = 0.20,
        DepositCooldown = 0.18,
        BuyCooldown = 0.075,
        MergeCooldown = 0.14,
        ProcessCooldown = 0.10,
        TierCooldown = 0.24,
        GemCooldown = 0.16,
        LuckyCooldown = 0.24,
        RebirthCooldown = 1.0,
        FailureBackoffBase = 0.10,
        FailureBackoffMax = 0.90,

        -- Turbo can buy several affordable batches in one planning pass.
        BuyBurst = 4,
        BuyBurstGap = 0.08,

        -- Formula-driven optimizer settings.
        MergeBurst = 6,
        MergeBurstGap = 0.045,
        LuckyMinROI = 1.05,
        LuckyDecisionInterval = 0.35,
        RewardInterval = 20,
        SmartRebirthReserveAt = 0.55,
        SmartRebirthMinBoostGain = 1.50,
        RebirthSettleDelay = 0.10,
        AdaptiveMinFactor = 0.58,
        AdaptiveMaxFactor = 2.75,
        AdaptiveSuccessStep = 0.965,
        AdaptiveFailureStep = 1.35,
        RebirthEmergencyProcessBacklog = 35,
        RebirthEmergencyProcessCostFraction = 0.02,
        MaxDynamicMergeBurst = 14,
        ReactiveDebounce = 0.04,
    },
    State = {
        AutoEggs = true,
        AutoCollectables = true,
        AutoCash = true,
        AutoDeposit = true,
        AutoBuy = true,
        AutoMerge = true,
        AutoProcessUpgrade = true,
        AutoTierUpgrade = true,
        AutoGemUpgrades = true,
        AutoGroupReward = true,
        AutoRewards = true,
        AutoLuckyBlocks = true,
        LuckyROI = true,
        SmartSpending = true,
        EventAware = true,
        SmartRebirth = true,
        LockMainPlace = not CROSS_GAME_MODE,
        AutoRebirth = false,
    }
}

-- Preserve the user's toggles when the script is re-executed.
if type(PreviousState) == "table" then
    for key, value in pairs(PreviousState) do
        if Farm.State[key] ~= nil and type(value) == "boolean" then
            Farm.State[key] = value
        end
    end
end

if type(PreviousConfig) == "table" then
    for key, value in pairs(PreviousConfig) do
        if Farm.Config[key] ~= nil and type(value) == type(Farm.Config[key]) then
            Farm.Config[key] = value
        end
    end
end

-- Upgrading from an older version automatically starts in Turbo. Re-executing v9
-- preserves whichever v9 profile the user selected.
if PreviousVersion ~= 8.2 then
    Farm.Config.Profile = "Turbo"
end

GENV.__CHICKEN_FARM_AUTOFARM = Farm

local TELEPORT_METHODS = {
    Teleport = true,
    TeleportAsync = true,
    TeleportToPlaceInstance = true,
    TeleportToPrivateServer = true,
    TeleportPartyAsync = true,
    TeleportToSpawnByName = true,
}

local function shortJob(id)
    id = tostring(id or "")
    if #id <= 12 then return id end
    return id:sub(1, 6) .. "…" .. id:sub(-5)
end

local function sameLockedInstanceTarget(method, args)
    local destination = args[1]
    if type(destination) ~= "number" then
        return true -- unknown signature: do not risk breaking unrelated calls
    end
    if destination ~= MAIN_PLACE_ID then
        return false
    end

    -- Teleport()/TeleportPartyAsync()/TeleportToPrivateServer()/TeleportToSpawnByName()
    -- targeting the current PlaceId still create/move to another server instance.
    if method == "Teleport" or method == "TeleportPartyAsync" or method == "TeleportToPrivateServer" or method == "TeleportToSpawnByName" then
        return false
    end

    if method == "TeleportToPlaceInstance" then
        local requestedJob = args[2]
        return type(requestedJob) == "string" and requestedJob == LOCKED_JOB_ID
    end

    if method == "TeleportAsync" then
        local options = args[3]
        if typeof(options) == "Instance" and options:IsA("TeleportOptions") then
            local ok, requestedJob = pcall(function() return options.ServerInstanceId end)
            return ok and type(requestedJob) == "string" and requestedJob ~= "" and requestedJob == LOCKED_JOB_ID
        end
        -- No ServerInstanceId means Roblox chooses another server.
        return false
    end

    return true
end

-- Layer 1: block client-originated place changes AND same-place server hops.
-- This cannot cancel a teleport initiated authoritatively by the game server.
local HM = rawget(GENV, "hookmetamethod") or hookmetamethod
local GNCM = rawget(GENV, "getnamecallmethod") or getnamecallmethod
local NCC = rawget(GENV, "newcclosure") or newcclosure
if not GENV.__CHICKEN_FARM_SESSION_GUARD_INSTALLED
    and type(HM) == "function" and type(GNCM) == "function" and type(NCC) == "function" then
    local oldNamecall
    oldNamecall = HM(game, "__namecall", NCC(function(self, ...)
        local method = GNCM()
        local activeFarm = GENV.__CHICKEN_FARM_AUTOFARM
        if self == TeleportService
            and TELEPORT_METHODS[method]
            and activeFarm
            and activeFarm.Running
            and activeFarm.State
            and activeFarm.State.LockMainPlace
            and not GENV.__CHICKEN_FARM_ALLOW_TELEPORT then
            local args = table.pack(...)
            if not sameLockedInstanceTarget(method, args) then
                local destination = args[1]
                activeFarm.LastAction = "Blocked server transfer: " .. tostring(method) .. " -> " .. tostring(destination)
                activeFarm.LastError = "Session lock kept Job " .. shortJob(LOCKED_JOB_ID)
                return nil
            end
        end
        return oldNamecall(self, ...)
    end))
    GENV.__CHICKEN_FARM_SESSION_GUARD_INSTALLED = true
end

local function queueReturnToMain()
    -- v9 intentionally does not embed/compile a second copy of itself.
    -- If queue_on_teleport exists, queue only a tiny server-return guard.
    -- This preserves the farm's startup compatibility; after a server-forced
    -- transfer the user may need to re-execute the farm once returned.
    local q = queue_on_teleport or queueonteleport
    if not q then
        local okSyn, synObj = pcall(function() return syn end)
        if okSyn and synObj and synObj.queue_on_teleport then
            q = synObj.queue_on_teleport
        end
    end
    if not q or LOCKED_JOB_ID == "" then
        return false
    end

    local returnCode = string.format([=[
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local p = Players.LocalPlayer or Players.PlayerAdded:Wait()
local targetPlace = %d
local targetJob = %q
task.wait(0.75)
if game.PlaceId ~= targetPlace or tostring(game.JobId) ~= targetJob then
    pcall(function()
        TeleportService:TeleportToPlaceInstance(targetPlace, targetJob, p)
    end)
end
]=], MAIN_PLACE_ID, LOCKED_JOB_ID)
    return pcall(q, returnCode)
end

local function track(connection)
    if connection then
        table.insert(Farm.Connections, connection)
    end
    return connection
end

local function stat(name, player)
    local success, value
    if player then
        success, value = pcall(Paper.Stats.GetValue, player, name)
    else
        success, value = pcall(Paper.Stats.GetValue, name)
    end
    if success then
        return value
    end
    return nil
end

local function setError(route, err)
    Farm.Metrics.RemoteErrors = Farm.Metrics.RemoteErrors + 1
    Farm.LastError = tostring(route) .. ": " .. tostring(err)
end

-- Returns true when the transport completed and the server did not explicitly
-- return false. This fixes v3 treating a successful nil-returning InvokeServer
-- action as a failure.
local function invoke(route, ...)
    local args = table.pack(...)
    local transportOk, a, b, c = pcall(function()
        return Paper.Network.InvokeServer(route, table.unpack(args, 1, args.n))
    end)
    if not transportOk then
        setError(route, a)
        return false, a
    end
    if a == false then
        return false, b or "server rejected", a, b, c
    end
    return true, a, b, c
end

local function fire(route, ...)
    local args = table.pack(...)
    local transportOk, result = pcall(function()
        Paper.Network.FireServer(route, table.unpack(args, 1, args.n))
    end)
    if not transportOk then
        setError(route, result)
        return false, result
    end
    return true, result
end

local function setAction(text)
    Farm.LastAction = tostring(text or "Idle")
end

-- Per-route cooldown + small failure backoff. This prevents one rejected route
-- from being hammered while allowing unrelated farm work to continue.
local function invokeLocked(route, cooldown, ...)
    if not Farm.MasterEnabled then
        return false, "paused"
    end

    local now = os.clock()
    local readyAt = Farm.RouteLocks[route] or 0
    if now < readyAt then
        return false, "cooldown"
    end

    local baseCooldown = cooldown or 0.15
    local factor = Farm.RouteAdaptive[route] or 1
    local effectiveCooldown = baseCooldown * factor

    Farm.RouteLocks[route] = now + effectiveCooldown
    local ok, a, b, c = invoke(route, ...)
    if ok then
        Farm.RouteFailures[route] = 0
        Farm.Metrics.RouteSuccesses = Farm.Metrics.RouteSuccesses + 1
        Farm.RouteAdaptive[route] = math.max(
            Farm.Config.AdaptiveMinFactor,
            factor * Farm.Config.AdaptiveSuccessStep
        )
        return true, a, b, c
    end

    Farm.Metrics.RouteRejects = Farm.Metrics.RouteRejects + 1
    local failures = (Farm.RouteFailures[route] or 0) + 1
    Farm.RouteFailures[route] = failures
    Farm.RouteAdaptive[route] = math.min(
        Farm.Config.AdaptiveMaxFactor,
        math.max(1, factor * Farm.Config.AdaptiveFailureStep)
    )
    Farm.RouteLocks[route] = math.max(
        Farm.RouteLocks[route],
        now + math.min(Farm.Config.FailureBackoffBase * failures, Farm.Config.FailureBackoffMax)
    )
    return false, a, b, c
end
-- Cash/gem spending actions are serialized so Buy/Process/Tier/Gem loops do not
-- race each other against the same wallet snapshot.
local function invokeSpendLocked(route, cooldown, ...)
    if Farm.SpendBusy then
        return false, "spend busy"
    end

    local args = table.pack(...)
    Farm.SpendBusy = true
    local callOk, packed = pcall(function()
        return table.pack(invokeLocked(route, cooldown, table.unpack(args, 1, args.n)))
    end)
    Farm.SpendBusy = false

    if not callOk then
        setError(route, packed)
        return false, packed
    end
    return table.unpack(packed, 1, packed.n)
end

local function safeNumber(value, fallback)
    if type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge then
        return value
    end
    return fallback or 0
end

local function getGlobalBoost(name)
    if not Farm.State.EventAware or type(GlobalEvents) ~= "table" or type(GlobalEvents.GetBoost) ~= "function" then
        return 1
    end
    local okBoost, value = pcall(GlobalEvents.GetBoost, name)
    if okBoost and type(value) == "number" and value > 0 then
        return value
    end
    return 1
end

local function isGlobalEventActive(name)
    if not Farm.State.EventAware or type(GlobalEvents) ~= "table" or type(GlobalEvents.IsActive) ~= "function" then
        return false
    end
    local okActive, value = pcall(GlobalEvents.IsActive, name)
    return okActive and value == true
end

local function getFriendProcessMultiplier()
    -- The server exposes the friend count in supported builds. If it is absent,
    -- fall back to 1x rather than doing expensive friendship web lookups.
    local friends = stat("Friends")
    if type(friends) == "number" and friends > 0 then
        return 1 + friends * 0.30
    end
    return 1
end

local function getEffectiveProcessPerSecond()
    local level = stat("ProcessingLevel")
    if type(level) ~= "number" then return 0 end

    local okAmount, perSecond = pcall(ChickenMath.GetProcessAmount, level)
    if not okAmount or type(perSecond) ~= "number" or perSecond <= 0 then return 0 end

    local processUpgrade = stat("ProcessSpeedUpgrade")
    if type(processUpgrade) == "number" and type(ChickenMath.GetUpgradeBoost) == "function" then
        local okBoost, boost = pcall(ChickenMath.GetUpgradeBoost, "ProcessSpeedUpgrade", processUpgrade)
        if okBoost and type(boost) == "number" and boost > 0 then
            perSecond = perSecond * boost
        end
    end

    perSecond = perSecond * getFriendProcessMultiplier() * getGlobalBoost("ProcessingSpeed")
    return perSecond
end

local function getProcessBacklogSeconds()
    local processing = stat("EggsProcessing")
    if type(processing) ~= "number" then return 0 end
    local perSecond = getEffectiveProcessPerSecond()
    if perSecond <= 0 then return 0 end
    return processing / perSecond
end

local function getEventSummary()
    local parts = {}
    local egg = getGlobalBoost("EggMultiplier")
    local proc = getGlobalBoost("ProcessingSpeed")
    local cash = getGlobalBoost("CashMultiplier")
    if egg > 1 then table.insert(parts, "Egg x" .. tostring(egg)) end
    if proc > 1 then table.insert(parts, "Proc x" .. tostring(proc)) end
    if cash > 1 then table.insert(parts, "Cash x" .. tostring(cash)) end
    if isGlobalEventActive("Rainbow") then table.insert(parts, "RAINBOW") end
    if isGlobalEventActive("MaximizeEggMultiplier") then table.insert(parts, "MAX EGG") end
    return #parts > 0 and table.concat(parts, " + ") or "None"
end

local function getNextRebirthData()
    local rebirth = stat("Rebirth")
    if type(rebirth) ~= "number" then return nil end
    local okReq, requirement = pcall(ChickenMath.GetRebirthReq, rebirth + 1)
    local okCur, currentBoost = pcall(ChickenMath.GetRebirthBoost, rebirth)
    local okNext, nextBoost = pcall(ChickenMath.GetRebirthBoost, rebirth + 1)
    if not okReq or type(requirement) ~= "number" then return nil end
    currentBoost = okCur and type(currentBoost) == "number" and currentBoost or 1
    nextBoost = okNext and type(nextBoost) == "number" and nextBoost or currentBoost
    return rebirth, requirement, currentBoost, nextBoost, nextBoost / math.max(currentBoost, 1e-9)
end

local function getRebirthSaveFraction(gain)
    gain = safeNumber(gain, 1)
    return math.clamp(0.82 - math.min(math.max(gain - 1, 0), 2.5) * 0.11, 0.48, 0.78)
end

local function getRebirthSavingInfo(cash)
    if not (Farm.State.AutoRebirth and Farm.State.SmartRebirth) then
        return false
    end
    local rebirth, requirement, currentBoost, nextBoost, gain = getNextRebirthData()
    if not rebirth or type(requirement) ~= "number" or requirement <= 0 then
        return false
    end
    if gain < Farm.Config.SmartRebirthMinBoostGain then
        return false
    end
    local threshold = requirement * getRebirthSaveFraction(gain)
    return safeNumber(cash, 0) >= threshold, requirement, threshold, gain
end

local function canSpendCash(cost, category, cash)
    cost = safeNumber(cost, 0)
    cash = safeNumber(cash, stat("Cash"))
    if cost <= 0 or not Farm.State.SmartSpending then
        return true
    end

    local saving, requirement = getRebirthSavingInfo(cash)
    if not saving then
        return cash >= cost
    end

    if category == "processing" then
        local backlog = getProcessBacklogSeconds()
        if backlog >= Farm.Config.RebirthEmergencyProcessBacklog
            and cost <= requirement * Farm.Config.RebirthEmergencyProcessCostFraction then
            return cash >= cost
        end
    end

    return false
end

local function reactiveReady(key)
    local now = os.clock()
    if now < (Farm.ReactiveLocks[key] or 0) then return false end
    Farm.ReactiveLocks[key] = now + Farm.Config.ReactiveDebounce
    return true
end

local function estimateMergeOperations(inventory)
    if type(inventory) ~= "table" then return 1 end
    local maxTier = type(ChickenTable) == "table" and #ChickenTable or 64
    local counts = {}
    for tier, amount in pairs(inventory) do
        if type(tier) == "number" and type(amount) == "number" then
            counts[tier] = math.max(0, math.floor(amount))
        end
    end
    local operations = 0
    for tier = 1, maxTier - 1 do
        local merges = math.floor((counts[tier] or 0) / 3)
        if merges > 0 then
            operations = operations + merges
            counts[tier + 1] = (counts[tier + 1] or 0) + merges
        end
    end
    return operations
end

local function getLuckyBlockInfo(index, totalChickens)
    if type(index) ~= "number" or index <= 0 then return nil end
    local block = type(Luckyblocks) == "table" and type(Luckyblocks.Blocks) == "table" and Luckyblocks.Blocks[index] or nil
    if type(block) ~= "table" then return nil end

    local expectedValue = 0
    if type(block.Chances) == "table" then
        for chickenTier, chance in pairs(block.Chances) do
            if type(chickenTier) == "number" and type(chance) == "number" then
                local okCost, buyEquivalent = pcall(ChickenMath.GetBuyChickenCost, totalChickens or 0, chickenTier, 1)
                if okCost and type(buyEquivalent) == "number" then
                    expectedValue = expectedValue + buyEquivalent * (chance / 100)
                end
            end
        end
    end

    local okPrice, price = pcall(ChickenMath.GetLuckyBlockCost, totalChickens or 0, index)
    price = okPrice and type(price) == "number" and price or nil
    local roi = price and price > 0 and expectedValue / price or 0
    return block, price, expectedValue, roi
end

local function isCurrentLuckyBlockFree()
    -- Stat names changed in some builds; accept the known variants without
    -- assuming one exists.
    for _, name in ipairs({"IsCurrentLuckyBlockFree", "CurrentLuckyBlockFree", "LuckyBlockFree", "FreeLuckyBlock"}) do
        local value = stat(name)
        if type(value) == "boolean" then return value end
        if type(value) == "number" then return value ~= 0 end
    end
    return false
end

local function canTierUpgrade(cash, total, tier)
    local reqOk, requirement = pcall(ChickenMath.GetUpgTierReq, tier)
    local costOk, cost = pcall(ChickenMath.GetUpgTierCost, tier)
    if not reqOk or not costOk or cost == nil then
        return false, nil
    end
    local enoughChickens = type(requirement) ~= "number" or total >= requirement
    local enoughCash = type(cost) ~= "number" or cash >= cost
    return enoughChickens and enoughCash, cost
end

local function shouldReserveForProcessing(cash)
    if not Farm.State.SmartSpending or not Farm.State.AutoProcessUpgrade then
        return false
    end
    local level = stat("ProcessingLevel")
    if type(level) ~= "number" then
        return false
    end
    local okCost, cost = pcall(ChickenMath.GetProcessCost, level)
    if not okCost or type(cost) ~= "number" or cash < cost then
        return false
    end
    local tutorial = stat("Tutorial")
    if tutorial == 7 then
        return true
    end
    return getProcessBacklogSeconds() >= Farm.Config.ProcessBacklogTarget
end

local function getCashReserve(cash, total, tier)
    if not Farm.State.SmartSpending then
        return 0
    end

    local reserve = 0

    if Farm.State.AutoTierUpgrade and type(tier) == "number" and type(total) == "number" then
        local reqOk, requirement = pcall(ChickenMath.GetUpgTierReq, tier)
        local costOk, cost = pcall(ChickenMath.GetUpgTierCost, tier)
        if reqOk and costOk and type(cost) == "number" then
            local enoughChickens = type(requirement) ~= "number" or total >= requirement
            if enoughChickens then
                reserve = math.max(reserve, cost)
            end
        end
    end

    if Farm.MasterEnabled and Farm.State.AutoProcessUpgrade then
        local level = stat("ProcessingLevel")
        -- If a ProcessingSpeed event is active, the temporary multiplier can clear
        -- the queue for us, so require a larger backlog before reserving upgrade cash.
        local eventAdjustedTarget = Farm.Config.ProcessBacklogTarget * math.max(1, getGlobalBoost("ProcessingSpeed") ^ 0.5)
        if type(level) == "number" and getProcessBacklogSeconds() >= eventAdjustedTarget then
            local okCost, cost = pcall(ChickenMath.GetProcessCost, level)
            if okCost and type(cost) == "number" then
                reserve = math.max(reserve, cost)
            end
        end
    end

    -- Once we are meaningfully close to the next rebirth, stop spending the
    -- entire wallet on chickens. Reaching the next permanent cash multiplier
    -- is worth far more than a few extra pre-rebirth purchases.
    if Farm.State.AutoRebirth and Farm.State.SmartRebirth then
        local saving, requirement = getRebirthSavingInfo(cash)
        if saving and type(requirement) == "number" then
            reserve = math.max(reserve, requirement)
        end
    end

    return math.min(reserve, safeNumber(cash, 0))
end

local function canAttempt(cache, id, cooldown)
    if not id then
        return false
    end
    local now = os.clock()
    local last = cache[id]
    if last and now - last < cooldown then
        return false
    end
    cache[id] = now
    return true
end

local function rememberEggId(id)
    if id == nil then
        return nil
    end

    -- Instance.Name is always a string. Egg Dropped can give us a number,
    -- so keep the original typed id and recover numeric ids from old models.
    local key = tostring(id)
    if Farm.EggIds[key] == nil then
        Farm.EggIds[key] = id
    end
    return Farm.EggIds[key]
end

local function resolveEggId(idOrName)
    if idOrName == nil then
        return nil
    end

    local key = tostring(idOrName)
    local remembered = Farm.EggIds[key]
    if remembered ~= nil then
        return remembered
    end

    -- Most dropped egg ids in this game are numeric. A Model.Name converts
    -- them to text, which is not necessarily accepted by the server.
    local numeric = tonumber(key)
    if numeric ~= nil then
        Farm.EggIds[key] = numeric
        return numeric
    end

    Farm.EggIds[key] = idOrName
    return idOrName
end

local function getEggModel(id)
    local eggsFolder = workspace:FindFirstChild("Eggs")
    if not eggsFolder or id == nil then
        return nil
    end
    return eggsFolder:FindFirstChild(tostring(id))
end

local function getCharacterRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
end

-- The game's own CollectEgg() is called by a transparent Part.Touched listener.
-- Triggering that listener is preferable to only sending the remote because it
-- follows the exact local collection path and removes the collected egg model.
local function triggerEggTouch(model)
    if not model or not model.Parent then
        return false
    end

    local root = getCharacterRoot()
    if not root then
        return false
    end

    local sensor = model:FindFirstChild("Part")
    if not (sensor and sensor:IsA("BasePart")) then
        sensor = model:FindFirstChild("Hitbox", true)
    end
    if not (sensor and sensor:IsA("BasePart")) then
        sensor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    end
    if not sensor then
        return false
    end

    -- Executor touch API: this makes the game's own Touched callback receive a
    -- part from our character, exactly like walking into the egg.
    if type(firetouchinterest) == "function" then
        local ok = pcall(function()
            firetouchinterest(root, sensor, 0)
            task.wait()
            firetouchinterest(root, sensor, 1)
        end)
        if ok then
            return true
        end
    end

    -- Some environments expose firesignal instead of firetouchinterest.
    if type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(sensor.Touched, root)
        end)
        if ok then
            return true
        end
    end

    -- getconnections() is another compatible fallback used by DEX-style
    -- environments. Fire only this local Touched signal's connections.
    if type(getconnections) == "function" then
        local ok, connections = pcall(getconnections, sensor.Touched)
        if ok and type(connections) == "table" then
            local fired = false
            for _, connection in next, connections do
                if type(connection) == "table" or typeof(connection) == "RBXScriptConnection" then
                    local success = pcall(function()
                        if connection.Fire then
                            connection:Fire(root)
                            fired = true
                        elseif connection.Function then
                            connection.Function(root)
                            fired = true
                        end
                    end)
                    if success and fired then
                        break
                    end
                end
            end
            if fired then
                return true
            end
        end
    end

    return false
end

local function collectEggId(id)
    if not Farm.Running or not Farm.MasterEnabled or not Farm.State.AutoEggs then
        return false
    end

    id = resolveEggId(id)
    if id == nil then
        return false
    end

    local key = tostring(id)
    if not canAttempt(Farm.EggAttempts, key, Farm.Config.EggAttemptCooldown) then
        return false
    end

    local model = getEggModel(id)
    Farm.Metrics.EggAttempts = Farm.Metrics.EggAttempts + 1

    -- Prefer the game's actual local pickup callback when the model exists.
    if model and triggerEggTouch(model) then
        setAction("Collecting egg " .. key)

        -- The touch path normally sends the game's own collection call. If the
        -- model survives briefly, send the same server route directly as a fast
        -- recovery path instead of waiting for the next full worker retry.
        task.delay(Farm.Config.EggFallbackDelay, function()
            if Farm.Running and Farm.MasterEnabled and Farm.State.AutoEggs and getEggModel(id) then
                fire("Collect Egg", id)
            end
        end)

        return true
    end

    -- Remote fallback. Crucially this uses the original/numeric id rather than
    -- blindly sending Model.Name as a string.
    fire("Collect Egg", id)
    setAction("Collecting egg " .. key)
    return true
end

local function startEggWorker(id)
    if id == nil then
        return
    end

    id = rememberEggId(id)
    local key = tostring(id)
    if Farm.EggWorkers[key] then
        return
    end
    Farm.EggWorkers[key] = true

    task.spawn(function()
        -- The original game rejects pickup until >0.1 s after Egg Dropped.
        task.wait(Farm.Config.EggStartDelay)

        local attempts = 0
        local sawEgg = false
        while Farm.Running and Farm.MasterEnabled and Farm.State.AutoEggs and attempts < Farm.Config.EggMaxAttempts do
            attempts = attempts + 1

            local model = getEggModel(id)
            if not model then
                if sawEgg then
                    Farm.Metrics.EggPickups = Farm.Metrics.EggPickups + 1
                end
                break
            end

            sawEgg = true
            collectEggId(id)
            task.wait(Farm.Config.EggRetryDelay)
        end

        Farm.EggWorkers[key] = nil
        Farm.EggAttempts[key] = nil
    end)
end

local function collectLuckyId(id)
    if not Farm.Running or not Farm.MasterEnabled or not Farm.State.AutoLuckyBlocks then
        return
    end
    if not canAttempt(Farm.LuckyAttempts, tostring(id), 1.5) then
        return
    end
    invokeLocked("Collect Lucky Block", Farm.Config.LuckyCooldown, id)
end

-- Listen to the game's multiplexed network event so we retain the ORIGINAL
-- egg id before Roblox converts it to Instance.Name text.
if not CROSS_GAME_MODE then
    local remotesFolder = ReplicatedStorage:WaitForChild("Paper"):WaitForChild("Remotes")
    local rawEvent = remotesFolder:WaitForChild("__remoteevent")

    track(rawEvent.OnClientEvent:Connect(function(route, ...)
        if not Farm.Running or not Farm.MasterEnabled then
            return
        end

        local args = table.pack(...)

        if route == "Egg Dropped" then
            local id = args[1]
            rememberEggId(id)
            if Farm.State.AutoEggs then
                startEggWorker(id)
            end
        elseif route == "LuckyBlock Dropped" and Farm.State.AutoLuckyBlocks then
            local id = args[1]
            task.delay(0.15, collectLuckyId, id)
        elseif route == "PAPER_COLLECTABLE_CREATED" and Farm.State.AutoCollectables then
            local id = args[1]
            if id ~= nil then
                task.defer(function()
                    fire("PAPER_COLLECT_COLLECTABLE", id)
                end)
            end
        end
    end))
end

-- React immediately to newly-parented egg models as a second path in case the
-- network event was missed or the script was injected during a spawn burst.
local boundEggFolder
local function bindEggFolder(folder)
    if not folder or folder == boundEggFolder then return end
    boundEggFolder = folder
    track(folder.ChildAdded:Connect(function(object)
        if not Farm.Running or not Farm.MasterEnabled then return end
        task.defer(function()
            if Farm.State.AutoLuckyBlocks and object:GetAttribute("LuckyBlock") ~= nil then
                collectLuckyId(object.Name)
            elseif Farm.State.AutoEggs then
                startEggWorker(resolveEggId(object.Name))
            end
        end)
    end))
end

bindEggFolder(workspace:FindFirstChild("Eggs"))
track(workspace.ChildAdded:Connect(function(child)
    if child.Name == "Eggs" then
        bindEggFolder(child)
    end
end))

-- Catch eggs that existed before the autofarm was injected. Numeric model names
-- are converted back to numbers so Collect Egg gets the expected id type.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled then
            local eggsFolder = workspace:FindFirstChild("Eggs")
            if eggsFolder then
                bindEggFolder(eggsFolder)
                for _, object in ipairs(eggsFolder:GetChildren()) do
                    if Farm.State.AutoLuckyBlocks and object:GetAttribute("LuckyBlock") ~= nil then
                        collectLuckyId(object.Name)
                    elseif Farm.State.AutoEggs then
                        startEggWorker(resolveEggId(object.Name))
                    end
                end
            end
        end
        task.wait(Farm.Config.EggSweepInterval)
    end
end)

-- Cash collector. The game's own client uses a 0.25 second local debounce.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoCash then
            local waitingCash = stat("CashCollect")
            if type(waitingCash) == "number" and waitingCash > 0 then
                local success = invokeLocked("Collect Cash", Farm.Config.CashCooldown)
                if success then
                    Farm.Metrics.CashCollects = Farm.Metrics.CashCollects + 1
                    setAction("Collected cash")
                end
            end
        end
        task.wait(Farm.Config.CashInterval)
    end
end)

-- Deposit eggs into processing.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoDeposit then
            local eggs = stat("Eggs")
            if type(eggs) == "number" and eggs > 0 then
                local success = invokeLocked("Deposit Eggs", Farm.Config.DepositCooldown)
                if success then
                    Farm.Metrics.Deposits = Farm.Metrics.Deposits + 1
                    setAction("Deposited eggs")
                end
            end
        end
        task.wait(Farm.Config.DepositInterval)
    end
end)

-- Buy the biggest affordable batch. Turbo can chain several purchases in one
-- planning pass, which is much quicker when cash is accumulating rapidly.
task.spawn(function()
    local batches = {100, 25, 5, 1}

    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoBuy then
            local cash = stat("Cash")
            local total = stat("TotalChickens")
            local tier = stat("BuyTierLevel")

            if type(cash) == "number" and type(total) == "number" and type(tier) == "number" then
                local burstLimit = math.max(1, math.floor(Farm.Config.BuyBurst or 1))
                if Farm.State.EventAware then
                    if getGlobalBoost("EggMultiplier") > 1 or isGlobalEventActive("Rainbow") or isGlobalEventActive("MaximizeEggMultiplier") then
                        burstLimit = burstLimit + 2
                    elseif getGlobalBoost("CashMultiplier") > 1 then
                        burstLimit = burstLimit + 1
                    end
                end

                for burst = 1, burstLimit do
                    local reserveCash = getCashReserve(cash, total, tier)
                    local selectedAmount
                    local selectedCost

                    for _, amount in ipairs(batches) do
                        local success, cost = pcall(ChickenMath.GetBuyChickenCost, total, tier, amount)
                        if success and type(cost) == "number" and cash >= cost and (cash - cost) >= reserveCash then
                            selectedAmount = amount
                            selectedCost = cost
                            break
                        end
                    end

                    if not selectedAmount then
                        break
                    end

                    local bought = invokeSpendLocked("Buy Chickens", Farm.Config.BuyCooldown, selectedAmount)
                    if not bought then
                        break
                    end

                    Farm.Metrics.ChickenBuys = Farm.Metrics.ChickenBuys + selectedAmount
                    setAction("Bought " .. selectedAmount .. " chickens")

                    -- Predict the next wallet/inventory snapshot so Turbo does not
                    -- have to wait for client stat replication before planning again.
                    cash = math.max(0, cash - selectedCost)
                    total = total + selectedAmount

                    if burst < burstLimit then
                        task.wait(Farm.Config.BuyBurstGap)
                    end
                end
            end
        end
        task.wait(Farm.Config.BuyInterval)
    end
end)

-- Merge chains are exponential value, so clear them in short bursts instead of
-- waiting one full loop interval between every possible server-side merge.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoMerge then
            local inventory = stat("Chickens", LocalPlayer)
            local shouldMerge = false

            if type(inventory) == "table" then
                local maxTier = type(ChickenTable) == "table" and #ChickenTable or math.huge
                for tier, amount in pairs(inventory) do
                    if type(tier) == "number" and type(amount) == "number" and amount >= 3 and tier < maxTier then
                        shouldMerge = true
                        break
                    end
                end
            else
                shouldMerge = true
            end

            if shouldMerge then
                local estimatedOps = estimateMergeOperations(inventory)
                local burst = math.max(1, math.floor(Farm.Config.MergeBurst or 1))
                if estimatedOps > burst then
                    burst = math.min(Farm.Config.MaxDynamicMergeBurst, estimatedOps)
                end
                for i = 1, burst do
                    local merged = invokeLocked("Merge Chickens", Farm.Config.MergeCooldown)
                    if not merged then break end
                    Farm.Metrics.Merges = Farm.Metrics.Merges + 1
                    setAction("Merge chain x" .. tostring(i))
                    if i < burst then task.wait(Farm.Config.MergeBurstGap) end
                end
            end
        end
        task.wait(Farm.Config.MergeInterval)
    end
end)

-- Processing-level cash upgrade.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoProcessUpgrade then
            local cash = stat("Cash")
            local level = stat("ProcessingLevel")
            if type(cash) == "number" and type(level) == "number" then
                local success, cost = pcall(ChickenMath.GetProcessCost, level)
                if success and type(cost) == "number" and cash >= cost then
                    local tutorial = stat("Tutorial")
                    local processEvent = getGlobalBoost("ProcessingSpeed")
                    local target = Farm.Config.ProcessBacklogTarget * math.max(1, processEvent ^ 0.5)
                    local shouldUpgrade = not Farm.State.SmartSpending
                        or tutorial == 7
                        or getProcessBacklogSeconds() >= target

                    if shouldUpgrade and canSpendCash(cost, "processing", cash) then
                        local upgraded = invokeSpendLocked("Upgrade Process Level", Farm.Config.ProcessCooldown)
                        if upgraded then
                            Farm.Metrics.ProcessUpgrades = Farm.Metrics.ProcessUpgrades + 1
                            setAction("Upgraded processing")
                        end
                    end
                end
            end
        end
        task.wait(Farm.Config.UpgradeInterval)
    end
end)

-- Unlock the next chicken buy tier as soon as the server requirements are met.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoTierUpgrade then
            local tier = stat("BuyTierLevel")
            local total = stat("TotalChickens")
            local cash = stat("Cash")

            if type(tier) == "number" and type(total) == "number" and type(cash) == "number" then
                local reqOk, requirement = pcall(ChickenMath.GetUpgTierReq, tier)
                local costOk, cost = pcall(ChickenMath.GetUpgTierCost, tier)

                if reqOk and costOk and cost ~= nil then
                    local enoughChickens = type(requirement) ~= "number" or total >= requirement
                    local enoughCash = type(cost) ~= "number" or cash >= cost
                    local rebirth = safeNumber(stat("Rebirth"), 0)
                    local rebirthUnlocked = tier < rebirth * 2
                    local plannerAllows = type(cost) ~= "number" or canSpendCash(cost, "tier", cash)
                    if enoughChickens and enoughCash and rebirthUnlocked and plannerAllows then
                        local upgraded = invokeSpendLocked("Upgrade Buy Tier Level", Farm.Config.TierCooldown)
                        if upgraded then
                            Farm.Metrics.TierUpgrades = Farm.Metrics.TierUpgrades + 1
                            setAction("Unlocked next buy tier")
                        end
                    end
                end
            end
        end
        task.wait(Farm.Config.TierInterval)
    end
end)

-- Dynamic gem optimizer. We compare marginal permanent gain per gem rather
-- than walking a fixed list. OfflineMulti is intentionally ignored while the
-- active autofarm is running because it does not improve current-session income.
task.spawn(function()
    local activeUpgrades = {"ProcessSpeedUpgrade", "DepositMultiUpgrade", "StartingCashUpgrade"}

    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoGemUpgrades then
            local gems = stat("Gems")
            if type(gems) == "number" and gems > 0 then
                local backlog = getProcessBacklogSeconds()
                local rebirthEnabled = Farm.State.AutoRebirth and Farm.State.SmartRebirth
                local bestName, bestScore, bestCost

                for _, upgradeName in ipairs(activeUpgrades) do
                    local level = stat(upgradeName)
                    if type(level) == "number" then
                        local okCost, cost = pcall(ChickenMath.GetUpgradeCost, upgradeName, level)
                        if okCost and type(cost) == "number" and cost > 0 and gems >= cost then
                            local score = 0

                            if upgradeName == "StartingCashUpgrade" then
                                -- Starting cash grows about 2.25x per level in this build;
                                -- it is extremely valuable when rebirth cycling is enabled.
                                local okNow, nowAmount = pcall(ChickenMath.GetUpgradeBoost, upgradeName, level)
                                local okNext, nextAmount = pcall(ChickenMath.GetUpgradeBoost, upgradeName, level + 1)
                                if okNow and okNext and type(nowAmount) == "number" and type(nextAmount) == "number" and nowAmount > 0 then
                                    score = (nextAmount / nowAmount - 1) / cost * (rebirthEnabled and 3.0 or 0.35)
                                end
                            else
                                local okNow, nowBoost = pcall(ChickenMath.GetUpgradeBoost, upgradeName, level)
                                local okNext, nextBoost = pcall(ChickenMath.GetUpgradeBoost, upgradeName, level + 1)
                                if okNow and okNext and type(nowBoost) == "number" and type(nextBoost) == "number" and nowBoost > 0 then
                                    score = (nextBoost / nowBoost - 1) / cost
                                end

                                if upgradeName == "ProcessSpeedUpgrade" then
                                    -- Processing is only worth prioritizing when it is the bottleneck.
                                    local pressure = math.clamp(backlog / math.max(Farm.Config.ProcessBacklogTarget, 0.1), 0.15, 6)
                                    score = score * pressure / math.max(getGlobalBoost("ProcessingSpeed") ^ 0.5, 1)
                                elseif upgradeName == "DepositMultiUpgrade" then
                                    -- Cash/egg events make every permanent deposit multiplier more valuable.
                                    score = score * math.max(1, getGlobalBoost("CashMultiplier") ^ 0.25)
                                    score = score * math.max(1, getGlobalBoost("EggMultiplier") ^ 0.15)
                                end
                            end

                            if score > (bestScore or -math.huge) then
                                bestName, bestScore, bestCost = upgradeName, score, cost
                            end
                        end
                    end
                end

                if bestName and bestCost and gems >= bestCost then
                    local bought = invokeSpendLocked("Purchase Upgrade", Farm.Config.GemCooldown, bestName)
                    if bought then
                        Farm.Metrics.GemUpgrades = Farm.Metrics.GemUpgrades + 1
                        setAction("Best gem upgrade: " .. bestName)
                    end
                end
            end
        end
        task.wait(Farm.Config.GemInterval)
    end
end)

-- Free group reward, respecting the game's 600-second cooldown.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoGroupReward then
            local inGroup = stat("InGroup")
            local last = stat("LastGroupClaim")

            if inGroup and type(last) == "number" then
                local nowUnix = os.time()
                pcall(function()
                    if Paper.Misc and Paper.Misc.GetUnixTime then
                        nowUnix = Paper.Misc.GetUnixTime()
                    end
                end)

                local savingForRebirth = getRebirthSavingInfo(safeNumber(stat("Cash"), 0))
                if nowUnix >= last + 600 and not savingForRebirth then
                    local claimed = invokeLocked("Claim Group Reward", 1)
                    if claimed then setAction("Claimed group reward") end
                end
            end
        end
        task.wait(5)
    end
end)

-- Claim passive rewards the normal client exposes. These are deliberately
-- low-frequency; if a route is unavailable in a future build, invokeLocked's
-- backoff keeps it from affecting the main farm.
task.spawn(function()
    -- Offline earnings are primarily useful once after joining/rejoining.
    task.wait(1.5)
    if Farm.Running and Farm.MasterEnabled and Farm.State.AutoRewards then
        local okOffline = invokeLocked("Claim Offline Earnings", 5)
        if okOffline then
            Farm.Metrics.RewardsClaimed = Farm.Metrics.RewardsClaimed + 1
            setAction("Claimed offline earnings")
        end
    end

    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoRewards then
            local okCash = invokeLocked("Claim Cash Rewards", 5)
            if okCash then
                Farm.Metrics.RewardsClaimed = Farm.Metrics.RewardsClaimed + 1
                setAction("Claimed cash reward")
            end
        end
        task.wait(Farm.Config.RewardInterval)
    end
end)

-- Lucky-block chain: collect dropped block -> decide by exact expected-value ROI -> open/claim or discard.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoLuckyBlocks then
            local awarded = stat("AwardedChicken")
            local equipped = stat("EquippedLuckyBlock")

            if type(awarded) == "number" and awarded ~= 0 then
                local claimed = fire("Claim Opened Chicken")
                if claimed then setAction("Claimed lucky chicken") end
            elseif type(equipped) == "number" and equipped ~= 0 then
                local free = isCurrentLuckyBlockFree()
                local total = safeNumber(stat("TotalChickens"), 0)
                local block, price, expected, roi = getLuckyBlockInfo(equipped, total)
                local shouldOpen = true

                if Farm.State.LuckyROI and not free and block then
                    shouldOpen = roi >= Farm.Config.LuckyMinROI
                end

                if shouldOpen and not free and type(price) == "number" then
                    shouldOpen = canSpendCash(price, "lucky", safeNumber(stat("Cash"), 0))
                end

                if shouldOpen then
                    local opened = invokeSpendLocked("Open Lucky Block", 0.55)
                    if opened then
                        Farm.Metrics.LuckyOpened = Farm.Metrics.LuckyOpened + 1
                        local label = block and block.Name or tostring(equipped)
                        setAction(string.format("Opened %s lucky block%s", label, free and " (FREE)" or string.format(" ROI %.2fx", roi)))
                    end
                else
                    local discarded = invokeLocked("Discard Lucky Block", 0.55)
                    if discarded then
                        Farm.Metrics.LuckyDiscarded = Farm.Metrics.LuckyDiscarded + 1
                        setAction(string.format("Discarded %s lucky block (ROI %.2fx)", block.Name, roi))
                    end
                end
            end
        end
        task.wait(Farm.Config.LuckyDecisionInterval)
    end
end)

-- Smart rebirth: use the game's permanent multiplier curve and only rebirth
-- when the next boost is materially better. It also performs a last cash/egg
-- flush immediately before the reset and then lets the normal buy loop recover.
task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled and Farm.State.AutoRebirth then
            local cash = stat("Cash")
            local rebirth, requirement, currentBoost, nextBoost, gain = getNextRebirthData()

            if type(cash) == "number" and rebirth and requirement and cash >= requirement then
                local smartOkay = (not Farm.State.SmartRebirth) or gain >= Farm.Config.SmartRebirthMinBoostGain
                if smartOkay then
                    -- Claim already-finished cash, but do not deposit fresh eggs immediately
                    -- before the reset because those eggs may be wiped while still processing.
                    if safeNumber(stat("CashCollect"), 0) > 0 then
                        invokeLocked("Collect Cash", 0.05)
                    end
                    task.wait(Farm.Config.RebirthSettleDelay)

                    cash = safeNumber(stat("Cash"), cash)
                    if cash < requirement then
                        task.wait(0.08)
                        continue
                    end

                    local rebirthed = invokeSpendLocked("Rebirth", Farm.Config.RebirthCooldown)
                    if rebirthed then
                        Farm.Metrics.Rebirths = Farm.Metrics.Rebirths + 1
                        setAction(string.format("Rebirth %d -> %d | %.2fx permanent jump", rebirth, rebirth + 1, gain))
                        -- Clear stale wallet locks so post-rebirth starting cash is spent immediately.
                        Farm.RouteLocks["Buy Chickens"] = 0
                        Farm.RouteLocks["Upgrade Buy Tier Level"] = 0
                        task.wait(0.12)
                    end
                end
            end
        end
        task.wait(0.35)
    end
end)

-- v9 reactive fast path. The original polling loops stay active as a fallback.
local function hookStatChanged(name, callback)
    pcall(function()
        local connection = Paper.Stats.Changed(name, function()
            if Farm.Running then task.defer(callback) end
        end)
        if typeof(connection) == "RBXScriptConnection" then
            track(connection)
        end
    end)
end

hookStatChanged("CashCollect", function()
    if Farm.MasterEnabled and Farm.State.AutoCash and reactiveReady("cash")
        and safeNumber(stat("CashCollect"), 0) > 0 then
        local ok = invokeLocked("Collect Cash", Farm.Config.CashCooldown)
        if ok then Farm.Metrics.CashCollects = Farm.Metrics.CashCollects + 1 end
    end
end)

hookStatChanged("Eggs", function()
    if Farm.MasterEnabled and Farm.State.AutoDeposit and reactiveReady("deposit")
        and safeNumber(stat("Eggs"), 0) > 0 then
        local ok = invokeLocked("Deposit Eggs", Farm.Config.DepositCooldown)
        if ok then Farm.Metrics.Deposits = Farm.Metrics.Deposits + 1 end
    end
end)

hookStatChanged("Chickens", function()
    if Farm.MasterEnabled and Farm.State.AutoMerge and reactiveReady("merge") then
        local inventory = stat("Chickens", LocalPlayer)
        if estimateMergeOperations(inventory) > 0 then
            local ok = invokeLocked("Merge Chickens", Farm.Config.MergeCooldown)
            if ok then Farm.Metrics.Merges = Farm.Metrics.Merges + 1 end
        end
    end
end)

-- Periodically prune ids/cooldowns from eggs that no longer exist so long
-- farming sessions do not grow the tracking tables forever.
task.spawn(function()
    while Farm.Running do
        task.wait(30)
        local eggsFolder = workspace:FindFirstChild("Eggs")
        for key in pairs(Farm.EggIds) do
            if not Farm.EggWorkers[key] and (not eggsFolder or not eggsFolder:FindFirstChild(key)) then
                Farm.EggIds[key] = nil
                Farm.EggAttempts[key] = nil
            end
        end
        for key, last in pairs(Farm.LuckyAttempts) do
            if os.clock() - last > 30 then
                Farm.LuckyAttempts[key] = nil
            end
        end
    end
end)

-- =========================
-- rainzxdev SHARED UI
-- =========================
-- Every RAINZXDEV game script uses this same UI source. The loader remains separate.
local PUCK_UI_URL = "https://raw.githubusercontent.com/suroyah152-web/RAINZXDEV-assets/main/ui/PuckUI.lua"
local uiCompiler = loadstring or load
if type(uiCompiler) ~= "function" then
    error("RAINZXDEV: this environment cannot compile the shared UI module", 0)
end

local uiOk, uiSource = pcall(function()
    return game:HttpGet(PUCK_UI_URL)
end)
if not uiOk or type(uiSource) ~= "string" or #uiSource < 100 then
    error("RAINZXDEV: failed to download shared PuckUI: " .. tostring(uiSource), 0)
end

local uiChunk, uiCompileError = uiCompiler(uiSource)
if not uiChunk then
    error("RAINZXDEV: PuckUI compile error: " .. tostring(uiCompileError), 0)
end

local ChickenUI = uiChunk()
if type(ChickenUI) ~= "table" or type(ChickenUI.CreateWindow) ~= "function" then
    error("RAINZXDEV: shared PuckUI returned an invalid library", 0)
end

local function applyProfile(name)
    Farm.Config.Profile = name

    if name == "Turbo" then
        Farm.Config.ProcessBacklogTarget = 5
        Farm.Config.EggStartDelay = 0.115
        Farm.Config.EggAttemptCooldown = 0.055
        Farm.Config.EggFallbackDelay = 0.035
        Farm.Config.EggSweepInterval = 0.18
        Farm.Config.EggRetryDelay = 0.075
        Farm.Config.DepositInterval = 0.16
        Farm.Config.CashInterval = 0.18
        Farm.Config.BuyInterval = 0.10
        Farm.Config.MergeInterval = 0.16
        Farm.Config.UpgradeInterval = 0.12
        Farm.Config.TierInterval = 0.30
        Farm.Config.GemInterval = 0.20
        Farm.Config.CashCooldown = 0.20
        Farm.Config.DepositCooldown = 0.18
        Farm.Config.BuyCooldown = 0.075
        Farm.Config.MergeCooldown = 0.14
        Farm.Config.ProcessCooldown = 0.10
        Farm.Config.TierCooldown = 0.24
        Farm.Config.GemCooldown = 0.16
        Farm.Config.LuckyCooldown = 0.24
        Farm.Config.FailureBackoffBase = 0.10
        Farm.Config.FailureBackoffMax = 0.90
        Farm.Config.BuyBurst = 4
        Farm.Config.BuyBurstGap = 0.08
    elseif name == "Economy" then
        Farm.Config.ProcessBacklogTarget = 14
        Farm.Config.EggStartDelay = 0.14
        Farm.Config.EggAttemptCooldown = 0.12
        Farm.Config.EggFallbackDelay = 0.08
        Farm.Config.EggSweepInterval = 0.85
        Farm.Config.EggRetryDelay = 0.14
        Farm.Config.DepositInterval = 0.50
        Farm.Config.CashInterval = 0.38
        Farm.Config.BuyInterval = 0.30
        Farm.Config.MergeInterval = 0.65
        Farm.Config.UpgradeInterval = 0.35
        Farm.Config.TierInterval = 1.05
        Farm.Config.GemInterval = 0.55
        Farm.Config.CashCooldown = 0.28
        Farm.Config.DepositCooldown = 0.38
        Farm.Config.BuyCooldown = 0.20
        Farm.Config.MergeCooldown = 0.34
        Farm.Config.ProcessCooldown = 0.26
        Farm.Config.TierCooldown = 0.60
        Farm.Config.GemCooldown = 0.34
        Farm.Config.LuckyCooldown = 0.45
        Farm.Config.FailureBackoffBase = 0.20
        Farm.Config.FailureBackoffMax = 1.50
        Farm.Config.BuyBurst = 1
        Farm.Config.BuyBurstGap = 0.12
    else
        Farm.Config.Profile = "Balanced"
        Farm.Config.ProcessBacklogTarget = 8
        Farm.Config.EggStartDelay = 0.13
        Farm.Config.EggAttemptCooldown = 0.09
        Farm.Config.EggFallbackDelay = 0.055
        Farm.Config.EggSweepInterval = 0.50
        Farm.Config.EggRetryDelay = 0.11
        Farm.Config.DepositInterval = 0.28
        Farm.Config.CashInterval = 0.26
        Farm.Config.BuyInterval = 0.17
        Farm.Config.MergeInterval = 0.32
        Farm.Config.UpgradeInterval = 0.20
        Farm.Config.TierInterval = 0.58
        Farm.Config.GemInterval = 0.32
        Farm.Config.CashCooldown = 0.24
        Farm.Config.DepositCooldown = 0.28
        Farm.Config.BuyCooldown = 0.13
        Farm.Config.MergeCooldown = 0.24
        Farm.Config.ProcessCooldown = 0.16
        Farm.Config.TierCooldown = 0.42
        Farm.Config.GemCooldown = 0.24
        Farm.Config.LuckyCooldown = 0.35
        Farm.Config.FailureBackoffBase = 0.15
        Farm.Config.FailureBackoffMax = 1.20
        Farm.Config.BuyBurst = 2
        Farm.Config.BuyBurstGap = 0.10
    end
end

applyProfile(Farm.Config.Profile)

local Window = ChickenUI:CreateWindow({
    Name = "Chicken Farm • v11.2.1",
    LoadingTitle = "Chicken Farm Autofarm",
    LoadingSubtitle = "RAINZXDEV • adaptive progression",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
})
Farm.Gui = Window.ScreenGui

if BootGui then
    pcall(function() BootGui:Destroy() end)
    BootGui, BootLabel = nil, nil
end

local HomeTab = Window:CreateTab("Home", "home")
local FarmingTab = Window:CreateTab("Farming", "egg")
local ProgressionTab = Window:CreateTab("Progression", "trending-up")
local RewardsTab = Window:CreateTab("Rewards", "gift")
local SafetyTab = Window:CreateTab("Safety", "shield")
local StatsTab = Window:CreateTab("Stats", "bar-chart")
local SettingsTab = Window:CreateTab("Settings", "settings")

HomeTab:CreateSection("Farm Control")
local MasterToggle
MasterToggle = HomeTab:CreateToggle({
    Name = "Master Autofarm",
    CurrentValue = Farm.MasterEnabled,
    Flag = "MasterAutofarm",
    Callback = function(value)
        Farm.MasterEnabled = value
        setAction(value and "Farm resumed" or "Farm paused")
    end,
})

local ProfileDropdown = HomeTab:CreateDropdown({
    Name = "Farm Profile",
    Options = {"Turbo", "Balanced", "Economy"},
    CurrentOption = {Farm.Config.Profile},
    Flag = "FarmProfile",
    Callback = function(option)
        local profile = type(option) == "table" and option[1] or option
        applyProfile(profile)
        setAction("Profile: " .. Farm.Config.Profile)
        ChickenUI:Notify({Title = "Profile changed", Content = Farm.Config.Profile .. " profile is active.", Duration = 2.5})
    end,
})

local toggleControls = {}
local function setFarmToggle(key, value)
    if Farm.State[key] == nil then return end
    Farm.State[key] = value == true
    local control = toggleControls[key]
    if control and control:Get() ~= Farm.State[key] then
        control:Set(Farm.State[key])
    end
end

HomeTab:CreateButton({
    Name = "MAX FARM • Turbo + all safe automation",
    Callback = function()
        applyProfile("Turbo")
        ProfileDropdown:Set({"Turbo"})
        Farm.MasterEnabled = true
        if MasterToggle:Get() ~= true then MasterToggle:Set(true) end
        for key in pairs(Farm.State) do
            if key ~= "AutoRebirth" then
                Farm.State[key] = true
                local control = toggleControls[key]
                if control and control:Get() ~= true then control:Set(true) end
            end
        end
        Farm.State.AutoRebirth = false
        if toggleControls.AutoRebirth and toggleControls.AutoRebirth:Get() ~= false then
            toggleControls.AutoRebirth:Set(false)
        end
        setAction("MAX FARM optimizer enabled")
        ChickenUI:Notify({Title = "MAX FARM", Content = "Turbo profile + every non-reset farm enabled.", Duration = 3})
    end,
})

HomeTab:CreateButton({
    Name = "Pause everything",
    Callback = function()
        Farm.MasterEnabled = false
        if MasterToggle:Get() ~= false then MasterToggle:Set(false) end
        setAction("Farm paused")
    end,
})

local HomeStatus = HomeTab:CreateParagraph({
    Title = "Live Overview",
    Content = "Loading farm statistics...",
})

local function addStateToggle(tab, key, name)
    local control = tab:CreateToggle({
        Name = name,
        CurrentValue = Farm.State[key] == true,
        Flag = key,
        Callback = function(value)
            Farm.State[key] = value
            setAction(name .. ": " .. (value and "ON" or "OFF"))
        end,
    })
    toggleControls[key] = control
    return control
end

FarmingTab:CreateSection("Core Farm")
addStateToggle(FarmingTab, "AutoEggs", "Auto Collect Eggs")
addStateToggle(FarmingTab, "AutoCollectables", "Auto Collect Pickups")
addStateToggle(FarmingTab, "AutoCash", "Auto Collect Cash")
addStateToggle(FarmingTab, "AutoDeposit", "Auto Deposit Eggs")
addStateToggle(FarmingTab, "AutoBuy", "Auto Buy Chickens")
addStateToggle(FarmingTab, "AutoMerge", "Auto Merge Chickens")

FarmingTab:CreateSection("Manual Actions")
FarmingTab:CreateButton({Name = "Collect Cash Now", Callback = function()
    local ok = invoke("Collect Cash")
    setAction(ok and "Manual cash collection" or "Manual cash collection failed")
end})
FarmingTab:CreateButton({Name = "Deposit Eggs Now", Callback = function()
    local ok = invoke("Deposit Eggs")
    setAction(ok and "Manual egg deposit" or "Manual egg deposit failed")
end})
FarmingTab:CreateButton({Name = "Merge Chickens Now", Callback = function()
    local ok = invoke("Merge Chickens")
    setAction(ok and "Manual merge" or "Manual merge failed")
end})

ProgressionTab:CreateSection("Automatic Progression")
addStateToggle(ProgressionTab, "AutoProcessUpgrade", "Auto Processing Upgrade")
addStateToggle(ProgressionTab, "AutoTierUpgrade", "Auto Buy-Tier Upgrade")
addStateToggle(ProgressionTab, "AutoGemUpgrades", "Auto Gem Upgrade ROI")
addStateToggle(ProgressionTab, "AutoLuckyBlocks", "Auto Lucky Blocks")
addStateToggle(ProgressionTab, "LuckyROI", "Lucky Block ROI Filter")
addStateToggle(ProgressionTab, "SmartSpending", "Smart Cash / Bottleneck Logic")
addStateToggle(ProgressionTab, "EventAware", "Global Event Optimizer")
addStateToggle(ProgressionTab, "SmartRebirth", "Smart Rebirth Planner")

ProgressionTab:CreateSection("Rebirth")
addStateToggle(ProgressionTab, "AutoRebirth", "Auto Rebirth • RESETS PROGRESS")
ProgressionTab:CreateParagraph({
    Title = "Smart Rebirth",
    Content = "Leave Smart Rebirth ON. Auto Rebirth stays opt-in because rebirth deliberately resets current progression in exchange for the permanent multiplier.",
})

RewardsTab:CreateSection("Automatic Rewards")
addStateToggle(RewardsTab, "AutoGroupReward", "Auto Group Reward")
addStateToggle(RewardsTab, "AutoRewards", "Auto Passive / Cash Rewards")
RewardsTab:CreateSection("Claim Now")
RewardsTab:CreateButton({Name = "Claim Group Reward", Callback = function()
    local ok = invoke("Claim Group Reward")
    setAction(ok and "Group reward requested" or "Group reward unavailable")
end})
RewardsTab:CreateButton({Name = "Claim Cash Rewards", Callback = function()
    local ok = invoke("Claim Cash Rewards")
    setAction(ok and "Cash rewards requested" or "Cash rewards unavailable")
end})
RewardsTab:CreateButton({Name = "Claim Offline Earnings", Callback = function()
    local ok = invoke("Claim Offline Earnings")
    setAction(ok and "Offline earnings requested" or "Offline earnings unavailable")
end})

SafetyTab:CreateSection("Session Protection")
addStateToggle(SafetyTab, "LockMainPlace", "Lock Place + Current Server")
local ServerParagraph = SafetyTab:CreateParagraph({
    Title = "Current Session",
    Content = "Checking PlaceId and JobId...",
})
SafetyTab:CreateParagraph({
    Title = "How session lock works",
    Content = "Client-originated place changes and same-place server hops are blocked when the executor exposes hook APIs. Server-forced teleports cannot always be cancelled client-side.",
})

StatsTab:CreateSection("Live Economy")
local EconomyParagraph = StatsTab:CreateParagraph({Title = "Economy", Content = "Loading..."})
local PerformanceParagraph = StatsTab:CreateParagraph({Title = "Farm Performance", Content = "Loading..."})
local OptimizerParagraph = StatsTab:CreateParagraph({Title = "Optimizer", Content = "Loading..."})

SettingsTab:CreateSection("Script")
SettingsTab:CreateButton({Name = "Disable every farm toggle", Callback = function()
    Farm.MasterEnabled = false
    if MasterToggle:Get() ~= false then MasterToggle:Set(false) end
    for key in pairs(Farm.State) do
        Farm.State[key] = false
        local control = toggleControls[key]
        if control and control:Get() ~= false then control:Set(false) end
    end
    setAction("All farming disabled")
end})

function Farm:Unload()
    if not self.Running then return end
    self.Running = false

    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.Connections)

    if self.Gui then
        pcall(function() self.Gui:Destroy() end)
    end

    if GENV.__CHICKEN_FARM_AUTOFARM == self then
        GENV.__CHICKEN_FARM_AUTOFARM = nil
    end
end

Window:SetCloseCallback(function()
    Farm:Unload()
end)
SettingsTab:CreateButton({Name = "Unload Chicken Farm v11", Callback = function()
    Farm:Unload()
end})

-- Session baselines for useful gain stats.
Farm.Metrics.StartCash = safeNumber(stat("Cash"), 0)
Farm.Metrics.StartChickens = safeNumber(stat("TotalChickens"), 0)
Farm.Metrics.StartRebirth = safeNumber(stat("Rebirth"), 0)

-- Character recovery: the egg touch collector fetches the current root each try,
-- so no stale character references are retained across deaths/respawns.
track(LocalPlayer.CharacterAdded:Connect(function()
    setAction("Character respawned - collector recovered")
end))

-- Layer 2: server-authoritative teleports cannot reliably be cancelled client-side.
local lastTeleportQueue = 0
track(LocalPlayer.OnTeleport:Connect(function(teleportState, placeId)
    if not Farm.Running or not Farm.State.LockMainPlace then return end

    local stateName = tostring(teleportState)
    if stateName:find("Started") or stateName:find("WaitingForServer") or stateName:find("InProgress") then
        local now = os.clock()
        if now - lastTeleportQueue > 0.5 then
            lastTeleportQueue = now
            setAction("Transfer detected -> validating Place + Job after teleport")
            local queued = queueReturnToMain()
            if not queued then
                Farm.LastError = "Transfer detected; queue_on_teleport unavailable."
            end
        end
    end
end))

local function compact(n)
    if Paper.Number and Paper.Number.format then
        local success, result = pcall(Paper.Number.format, n)
        if success then return tostring(result) end
    end
    return tostring(n)
end

local function signedCompact(n)
    n = safeNumber(n, 0)
    return (n >= 0 and "+" or "") .. compact(n)
end

-- Live ChickenUI paragraphs.
task.spawn(function()
    while Farm.Running and Window and Window.ScreenGui and Window.ScreenGui.Parent do
        local cash = stat("Cash") or 0
        local eggs = stat("Eggs") or 0
        local processing = stat("EggsProcessing") or 0
        local chickens = stat("TotalChickens") or 0
        local rebirth = stat("Rebirth") or 0
        local gems = stat("Gems") or 0
        local buyTier = stat("BuyTierLevel") or 0
        local processLevel = stat("ProcessLevel") or 0

        local elapsed = math.max(os.clock() - Farm.Metrics.Started, 1)
        local eggRate = Farm.Metrics.EggPickups / elapsed * 60
        local backlog = getProcessBacklogSeconds()
        local cashGain = safeNumber(cash, 0) - Farm.Metrics.StartCash
        local chickenGain = safeNumber(chickens, 0) - Farm.Metrics.StartChickens
        local workerCount = 0
        for _ in pairs(Farm.EggWorkers) do workerCount = workerCount + 1 end

        HomeStatus:Set({
            Title = Farm.MasterEnabled and "Farm Running • " .. Farm.Config.Profile or "Farm Paused • " .. Farm.Config.Profile,
            Content = string.format(
                "Cash $%s (%s)  •  Eggs %s  •  Chickens %s (%s)\nRebirth %s  •  %.1f eggs/min  •  %.1fs processing backlog\nLast: %s",
                compact(cash), signedCompact(cashGain), compact(eggs), compact(chickens), signedCompact(chickenGain),
                compact(rebirth), eggRate, backlog, tostring(Farm.LastAction)
            ),
        })

        EconomyParagraph:Set({
            Title = "Economy",
            Content = string.format(
                "Cash: $%s (%s)\nEggs: %s  •  Processing: %s  •  Gems: %s\nChickens: %s (%s)  •  Buy Tier: %s  •  Process Level: %s",
                compact(cash), signedCompact(cashGain), compact(eggs), compact(processing), compact(gems),
                compact(chickens), signedCompact(chickenGain), compact(buyTier), compact(processLevel)
            ),
        })

        PerformanceParagraph:Set({
            Title = "Farm Performance",
            Content = string.format(
                "Eggs/min: %.1f  •  Egg workers: %d\nBuys: %s  •  Merges: %s  •  Deposits: %s\nRoute success/reject: %s/%s  •  Errors: %s",
                eggRate, workerCount, compact(Farm.Metrics.ChickenBuys), compact(Farm.Metrics.Merges), compact(Farm.Metrics.Deposits),
                compact(Farm.Metrics.RouteSuccesses), compact(Farm.Metrics.RouteRejects), compact(Farm.Metrics.RemoteErrors)
            ),
        })

        OptimizerParagraph:Set({
            Title = "Optimizer",
            Content = string.format(
                "Event: %s\nLucky opened/discarded: %d/%d  •  Rebirths this session: %d\nSmart spending: %s  •  Event optimizer: %s  •  Smart rebirth: %s",
                getEventSummary(), Farm.Metrics.LuckyOpened, Farm.Metrics.LuckyDiscarded, Farm.Metrics.Rebirths,
                Farm.State.SmartSpending and "ON" or "OFF", Farm.State.EventAware and "ON" or "OFF", Farm.State.SmartRebirth and "ON" or "OFF"
            ),
        })

        ServerParagraph:Set({
            Title = "Current Session",
            Content = string.format(
                "PlaceId: %s\nJobId: %s\nLocked Job: %s\nSession lock: %s",
                tostring(game.PlaceId), shortJob(game.JobId), shortJob(LOCKED_JOB_ID), Farm.State.LockMainPlace and "ON" or "OFF"
            ),
        })

        task.wait(0.5)
    end
end)

ChickenUI:Notify({
    Title = "Chicken Farm v11.2 loaded",
    Content = "Interface ready. Change the UI keybind from Settings.",
    Duration = 4,
})

print("[Chicken Farm Autofarm v11.2] Loaded - adaptive progression interface ready")
