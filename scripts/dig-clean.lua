local EXPECTED_PLACE_ID = 83038462357724

local S = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    CollectionService = game:GetService("CollectionService"),
    VirtualUser = game:GetService("VirtualUser"),
}

local LocalPlayer = S.Players.LocalPlayer
if not LocalPlayer then return end

local GENV = _G
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then GENV = env end
end

local SCRIPT_KEY = "__rainzxdev_DIG_AND_CLEAN_V2_7"
for _, key in ipairs({
    "__rainzxdev_DIG_AND_CLEAN_V0_1",
    "__rainzxdev_DIG_AND_CLEAN_V1_0",
    "__rainzxdev_DIG_AND_CLEAN_V1_1",
    "__rainzxdev_DIG_AND_CLEAN_V1_2",
    "__rainzxdev_DIG_AND_CLEAN_V1_3",
    "__rainzxdev_DIG_AND_CLEAN_V1_4",
    "__rainzxdev_DIG_AND_CLEAN_V1_5",
    "__rainzxdev_DIG_AND_CLEAN_V1_6",
    "__rainzxdev_DIG_AND_CLEAN_V1_7",
    "__rainzxdev_DIG_AND_CLEAN_V1_8",
    "__rainzxdev_DIG_AND_CLEAN_V1_9",
    "__rainzxdev_DIG_AND_CLEAN_V2_0",
    "__rainzxdev_DIG_AND_CLEAN_V2_1",
    "__rainzxdev_DIG_AND_CLEAN_V2_2",
    "__rainzxdev_DIG_AND_CLEAN_V2_3",
    "__rainzxdev_DIG_AND_CLEAN_V2_4",
    "__rainzxdev_DIG_AND_CLEAN_V2_5",
    "__rainzxdev_DIG_AND_CLEAN_V2_6",
    "__rainzxdev_DIG_AND_CLEAN_V2_7",
}) do
    local old = GENV[key]
    if type(old) == "table" and type(old.Unload) == "function" then
        pcall(function() old:Unload() end)
    end
    GENV[key] = nil
end

-- Clear older RAINZXDEV Dig & Clean windows before loading the release UI.
do
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, guiName in ipairs({"RAINZXDEV_DigAndClean", "RAINZXDEV_DigAndClean_Fallback"}) do
            local oldGui = playerGui:FindFirstChild(guiName)
            if oldGui then pcall(function() oldGui:Destroy() end) end
        end
    end
end

local Farm = {
    Running = true,
    Connections = {},
    Config = {
        Master = true,

        AutoDig = true,
        PreferBuriedNodes = true,
        BuriedPriority = "Highest Rarity",
        AutoMoveToDigZone = true,
        MaxPowerTiming = true,
        DigPowerSeconds = 0.275,
        DigClicksPerSecond = 10.95,
        DigTimeout = 36,
        AvoidRecoveryLosses = true,
        RecoverySafeHardDigBoost = true,
        HardDigMaxCps = 49,
        RecoveryAutoDecline = true,
        RecoveryResumeDelay = 0.70,
        RecoverySafeLuckSeconds = 75,
        UseCurrentIslandShops = true,
        ReturnToFarmIslandAfterSell = true,

        AutoClean = true,
        CleanAllDirty = true,
        CleanMaskDelay = 0.12,
        AutoSell = true,
        SellAfterDigs = 3,

        -- Money planner: displayed items earn 60% of their clean sale value per minute.
        SmartMoneyMode = true,
        AutoDisplayBest = true,
        DisplayReplaceRatio = 120,
        DisplayCheckSeconds = 1.25,
        MaxPassivePaybackMinutes = 45,
        AutoBuyPassiveSlots = true,

        AutoBestShovel = true,
        AutoBestDetector = true,
        -- v2.5 buys every meaningful current-island gear upgrade immediately.
        AutoBestSpray = true,
        AutoEquipBestGear = true,
        -- Gear has ZERO reserve/saving restrictions. IslandSaveAtPercent is only
        -- used by passive display/polisher spending, never by gear purchases.
        IslandSaveAtPercent = 65,

        AutoHighestIsland = true,
        IslandReservePercent = 0,

        AutoQuests = true,
        AutoQuestFocus = true,
        AutoOfflineEarnings = true,
        AutoGroupReward = true,
        AutoRedeemCodes = true,

        AutoPolishers = true,
        AutoUpgradePolishers = true,
        AutoUnlockPolishers = true,
        AutoUnlockPlotSections = true,

        AntiAFK = true,
    },
    State = {
        Phase = "Starting",
        LastError = "None",
        Busy = false,
        Data = nil,
        DataAt = -math.huge,
        DataRevision = 0,
        LastDigAt = -math.huge,
        LastCleanAt = -math.huge,
        LastSellAt = -math.huge,
        LastGearAt = -math.huge,
        LastIslandAt = -math.huge,
        LastRewardAt = -math.huge,
        LastPolisherAt = -math.huge,
        LastDisplayAt = -math.huge,
        LastPassiveBuyAt = -math.huge,
        LastCodeAt = -math.huge,
        Digs = 0,
        DigWins = 0,
        DigFails = 0,
        Cleaned = 0,
        Sold = 0,
        GoldFromSales = 0,
        GearBought = 0,
        IslandsUnlocked = 0,
        QuestsClaimed = 0,
        CodesClaimed = 0,
        CodeTried = {},
        DisplayPlacements = 0,
        DisplaySwaps = 0,
        PassiveGoldPerSecond = 0,
        DisplayedValue = 0,
        DisplayedCount = 0,
        LastPassivePurchase = "None",
        LastSmartSpend = "None",
        LastPolishScore = 0,
        BuriedNodes = {},
        BuriedRemoved = {},
        LastItem = "None",
        LastSell = 0,
        LastGear = "None",
        LastIsland = "None",
        LastAction = "Starting",
        ItemsConfirmedSinceSell = 0,
        LastConfirmedInventoryUid = "None",
        LastAwardWaitSeconds = 0,
        LastSellableCount = 0,
        LastBackpackCount = 0,
        LastBackpackLimit = 50,
        RecoveryActive = false,
        RecoveryOffered = 0,
        LastRecovery = "None",
        RecoveryUntil = -math.huge,
        RecoveryGuiSeenAt = -math.huge,
        RecoveryHardLockUntil = -math.huge,
        RecoveryAwaitPopupUntil = -math.huge,
        RecoveryResumeAt = -math.huge,
        RecoveryLastDismissAttempt = -math.huge,
        RecoveryDismissBusy = false,
        RecoverySeenThisOffer = false,
        RecoveryWatchdogTicks = 0,
        RecoverySafeLuckUntil = -math.huge,
        RiskyRarityUntil = {},
        CurrentDigRarity = nil,
        IslandRootCache = {},
        GearShopCache = {},
        LastShopIsland = "None",
        LastGearShopIsland = "None",
        LastSellerShopIsland = "None",
        LastSearchIsland = "None",
        LastSellOriginIsland = "None",
        LastSellReturnIsland = "None",
    },
    Network = {},
    Constants = {},
    UI = {},
}
GENV[SCRIPT_KEY] = Farm

-- UI ------------------------------------------------------------------------

function Farm:LoadPuckUI()
    local compiler = loadstring or load
    if type(compiler) ~= "function" then
        return nil, "loadstring/load unavailable"
    end

    local done, okSource, source = false, false, nil
    task.spawn(function()
        local ok, result = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/RAINZXDEV/Puck-Loader/main/ui/PuckUI.lua")
        end)
        okSource, source, done = ok, result, true
    end)

    local deadline = os.clock() + 3.0
    while not done and os.clock() < deadline do task.wait(0.03) end
    if not done then return nil, "PuckUI download timed out" end
    if not okSource or type(source) ~= "string" or #source < 100 then
        return nil, "PuckUI download failed: " .. tostring(source)
    end

    local chunk, compileErr = compiler(source)
    if not chunk then return nil, "PuckUI compile failed: " .. tostring(compileErr) end
    local ok, result = pcall(chunk)
    if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
        return result, nil
    end
    return nil, "PuckUI init failed: " .. tostring(result)
end

function Farm.UI.Toggle(tab, farm, name, key, flag)
    tab:CreateToggle({
        Name = name,
        CurrentValue = farm.Config[key],
        Flag = flag,
        Callback = function(value) farm.Config[key] = value == true end,
    })
end

function Farm.UI.Slider(tab, farm, name, key, flag, range, increment, normalize)
    tab:CreateSlider({
        Name = name,
        Range = range,
        Increment = increment,
        CurrentValue = farm.Config[key],
        Flag = flag,
        Callback = function(value)
            farm.Config[key] = normalize and normalize(value) or tonumber(value) or farm.Config[key]
        end,
    })
end

function Farm.UI.Dropdown(tab, farm, name, key, flag, options, fallback)
    local allowed = {}
    for _, option in ipairs(options) do allowed[option] = true end
    tab:CreateDropdown({
        Name = name,
        Options = options,
        CurrentOption = {farm.Config[key]},
        Flag = flag,
        Callback = function(value)
            value = type(value) == "table" and value[1] or value
            farm.Config[key] = allowed[value] and value or fallback
        end,
    })
end

local Window = nil
local FallbackGui = nil
local PuckUI, puckUiError = Farm:LoadPuckUI()

if PuckUI then
    local ok, result = pcall(PuckUI.CreateWindow, PuckUI, {
        Name = "RAINZXDEV | Dig & Clean",
        GuiName = "RAINZXDEV_DigAndClean",
        Width = 550,
        Height = 600,
    })
    if ok and result then
        Window = result
    else
        puckUiError = "CreateWindow failed: " .. tostring(result)
    end
end

if Window then
    local FarmTab = Window:CreateTab("Farm")
    local ProgressTab = Window:CreateTab("Progression")
    local UtilityTab = Window:CreateTab("Utilities")
    local SettingsTab = Window:CreateTab("Settings")
    if Window.Center then task.defer(function() pcall(function() Window:Center() end) end) end

    FarmTab:CreateSection("Digging")
    Farm.UI.Toggle(FarmTab, Farm, "Master Autofarm", "Master", "DigCleanV15_Master")
    Farm.UI.Toggle(FarmTab, Farm, "Auto Dig", "AutoDig", "DigCleanV15_Dig")
    Farm.UI.Toggle(FarmTab, Farm, "Prefer Buried Detector Nodes", "PreferBuriedNodes", "DigCleanV15_Buried")
    Farm.UI.Dropdown(FarmTab, Farm, "Buried Priority", "BuriedPriority", "DigCleanV15_BuriedPriority", {"Highest Rarity", "Closest"}, "Highest Rarity")
    Farm.UI.Toggle(FarmTab, Farm, "Auto Move To Dig Zone", "AutoMoveToDigZone", "DigCleanV15_Move")
    Farm.UI.Toggle(FarmTab, Farm, "Avoid Recovery Losses", "AvoidRecoveryLosses", "DigCleanV18_RecoverySafe")
    Farm.UI.Toggle(FarmTab, Farm, "Recovery-Safe Hard Dig Boost", "RecoverySafeHardDigBoost", "DigCleanV18_HardBoost")
    Farm.UI.Slider(FarmTab, Farm, "Hard Dig Max CPS", "HardDigMaxCps", "DigCleanV18_HardCps", {11, 49}, 1)
    Farm.UI.Slider(FarmTab, Farm, "Dig Clicks / Second", "DigClicksPerSecond", "DigCleanV15_CPS", {5, 11}, 0.1, function(v)
        return math.clamp(tonumber(v) or 10.95, 5, 11)
    end)

    FarmTab:CreateSection("Clean & Sell")
    Farm.UI.Toggle(FarmTab, Farm, "Auto Clean", "AutoClean", "DigCleanV15_Clean")
    Farm.UI.Toggle(FarmTab, Farm, "Clean All Dirty Items", "CleanAllDirty", "DigCleanV15_CleanAll")
    Farm.UI.Toggle(FarmTab, Farm, "Auto Sell", "AutoSell", "DigCleanV15_Sell")
    Farm.UI.Toggle(FarmTab, Farm, "Return To Farm Island After Sell", "ReturnToFarmIslandAfterSell", "DigCleanV18_ReturnAfterSell")
    Farm.UI.Slider(FarmTab, Farm, "Sell After Items", "SellAfterDigs", "DigCleanV15_SellCount", {1, 20}, 1, function(v)
        return math.max(1, math.floor(tonumber(v) or 3))
    end)

    FarmTab:CreateSection("Smart Money")
    Farm.UI.Toggle(FarmTab, Farm, "Smart Money Mode", "SmartMoneyMode", "DigCleanV15_SmartMoney")
    Farm.UI.Toggle(FarmTab, Farm, "Display Best Items For Passive Gold", "AutoDisplayBest", "DigCleanV15_Display")
    Farm.UI.Slider(FarmTab, Farm, "Replace Display At % Better", "DisplayReplaceRatio", "DigCleanV15_DisplayRatio", {105, 200}, 5, function(v)
        return math.clamp(math.floor(tonumber(v) or 120), 105, 200)
    end)
    Farm.UI.Toggle(FarmTab, Farm, "Buy Profitable Passive Slots", "AutoBuyPassiveSlots", "DigCleanV15_PassiveSlots")
    Farm.UI.Slider(FarmTab, Farm, "Max Passive Payback (Minutes)", "MaxPassivePaybackMinutes", "DigCleanV15_Payback", {5, 120}, 5, function(v)
        return math.clamp(math.floor(tonumber(v) or 45), 5, 120)
    end)

    ProgressTab:CreateSection("Gear")
    Farm.UI.Toggle(ProgressTab, Farm, "Auto Best Shovel", "AutoBestShovel", "DigCleanV15_Shovel")
    Farm.UI.Toggle(ProgressTab, Farm, "Auto Best Detector", "AutoBestDetector", "DigCleanV15_Detector")
    Farm.UI.Toggle(ProgressTab, Farm, "Auto Best Spray", "AutoBestSpray", "DigCleanV15_Spray")
    Farm.UI.Toggle(ProgressTab, Farm, "Auto Equip Best Gear", "AutoEquipBestGear", "DigCleanV15_Equip")

    ProgressTab:CreateSection("World Progression")
    Farm.UI.Toggle(ProgressTab, Farm, "Auto Highest Island", "AutoHighestIsland", "DigCleanV15_Island")
    Farm.UI.Toggle(ProgressTab, Farm, "Auto Unlock Plot Sections", "AutoUnlockPlotSections", "DigCleanV15_Sections")

    UtilityTab:CreateSection("Rewards")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Quests", "AutoQuests", "DigCleanV15_Quests")
    Farm.UI.Toggle(UtilityTab, Farm, "Focus Daily Quest Requirements", "AutoQuestFocus", "DigCleanV15_QuestFocus")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Offline Earnings", "AutoOfflineEarnings", "DigCleanV15_Offline")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Group Reward", "AutoGroupReward", "DigCleanV15_Group")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Redeem Free Luck Codes", "AutoRedeemCodes", "DigCleanV15_Codes")

    UtilityTab:CreateSection("Polishers")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Polishers", "AutoPolishers", "DigCleanV15_Polish")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Unlock Polishers", "AutoUnlockPolishers", "DigCleanV15_PolishUnlock")
    Farm.UI.Toggle(UtilityTab, Farm, "Auto Upgrade Polishers", "AutoUpgradePolishers", "DigCleanV15_PolishUpgrade")

    SettingsTab:CreateSection("General")
    Farm.UI.Toggle(SettingsTab, Farm, "Anti AFK", "AntiAFK", "DigCleanV15_AntiAFK")
    SettingsTab:CreateButton({Name = "Unload Autofarm", Callback = function() if Farm.Unload then Farm:Unload() end end})
else
    -- Built-in fallback: even if HttpGet/loadstring/shared UI breaks, the user
    -- still gets a visible control surface and a useful loader error.
    local gui = Instance.new("ScreenGui")
    gui.Name = "RAINZXDEV_DigAndClean_Fallback"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    FallbackGui = gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = UDim2.fromOffset(430, 330)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    main.BorderSizePixel = 0
    main.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(18, 12)
    title.Size = UDim2.new(1, -36, 0, 32)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = "RAINZXDEV | Dig & Clean"
    title.Parent = main

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(18, 46)
    sub.Size = UDim2.new(1, -36, 0, 24)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextWrapped = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextYAlignment = Enum.TextYAlignment.Top
    sub.TextColor3 = Color3.fromRGB(190, 190, 200)
    sub.Text = "Fallback controls are active."
    sub.Parent = main

    local y = 82
    local function addToggle(label, key)
        local button = Instance.new("TextButton")
        button.Position = UDim2.fromOffset(18, y)
        button.Size = UDim2.new(1, -36, 0, 34)
        button.BackgroundColor3 = Color3.fromRGB(33, 33, 39)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamMedium
        button.TextSize = 13
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Parent = main
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
        local function refresh() button.Text = label .. ": " .. (Farm.Config[key] and "ON" or "OFF") end
        refresh()
        button.MouseButton1Click:Connect(function() Farm.Config[key] = not Farm.Config[key]; refresh() end)
        y = y + 40
    end
    addToggle("Master Autofarm", "Master")
    addToggle("Auto Dig", "AutoDig")
    addToggle("Auto Clean", "AutoClean")
    addToggle("Auto Sell", "AutoSell")
    addToggle("Auto Best Gear", "AutoEquipBestGear")
    addToggle("Auto Highest Island", "AutoHighestIsland")

end


local function track(conn)
    if conn then table.insert(Farm.Connections, conn) end
    return conn
end

function Farm:SetPhase(text)
    self.State.Phase = tostring(text or "")
end

function Farm:SetError(err)
    self.State.LastError = err and tostring(err) or "None"
end

function Farm:SetAction(text)
    self.State.LastAction = tostring(text or "")
    self:SetPhase(text)
end

local function isModule(obj)
    return obj and obj:IsA("ModuleScript")
end

local function path(root, ...)
    local node = root
    local count = select("#", ...)
    for i = 1, count do
        -- IMPORTANT: select(i, ...) returns every argument from i onward.
        -- Capture it first so FindFirstChild receives ONLY the child name;
        -- otherwise the next path segment is passed as the recursive boolean
        -- and Roblox throws "Unable to cast string to bool".
        local childName = select(i, ...)
        if type(childName) ~= "string" or childName == "" then
            return nil
        end
        node = node and node:FindFirstChild(childName)
        if not node then return nil end
    end
    return node
end

local function safeRequire(obj)
    if not isModule(obj) then return nil end
    local ok, result = pcall(require, obj)
    if ok then return result end
    return nil
end

local function requirePath(...)
    return safeRequire(path(S.ReplicatedStorage, ...))
end

local function requireNetworkWrapper(moduleName, requiredField)
    -- Dig & Clean has TWO sets of similarly named network modules:
    --   ReplicatedStorage.TS.network/* = Global... definitions
    --   the player's local TS/network package = client wrappers
    -- We need the client wrappers exposing DataFunctions/ShovelFunctions/etc.
    local tried = {}

    local function tryModule(obj)
        if not isModule(obj) or obj.Name ~= moduleName or tried[obj] then return nil end
        tried[obj] = true
        local mod = safeRequire(obj)
        if type(mod) == "table" and mod[requiredField] ~= nil then
            return mod
        end
        return nil
    end

    -- Prefer the live PlayerScripts tree. The saved client controllers import
    -- these wrappers relative to their local TS package, not ReplicatedStorage.
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if not playerScripts then
        playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 4)
    end
    if playerScripts then
        -- Try the common exact paths without waiting on each individual module.
        local ts = playerScripts:FindFirstChild("TS")
        if ts then
            local network = ts:FindFirstChild("network")
            local result = tryModule(network and network:FindFirstChild(moduleName))
            if result then return result end
        end
        for _, obj in ipairs(playerScripts:GetDescendants()) do
            local result = tryModule(obj)
            if result then return result end
        end
    end

    -- Include PlayerGui/Backpack-side local packages used by some builds.
    for _, obj in ipairs(LocalPlayer:GetDescendants()) do
        local result = tryModule(obj)
        if result then return result end
    end

    -- Some executor environments expose the already-loaded client modules even
    -- when their Instance path has been changed by the game after boot.
    if type(getloadedmodules) == "function" then
        local okLoaded, loaded = pcall(getloadedmodules)
        if okLoaded and type(loaded) == "table" then
            for _, obj in ipairs(loaded) do
                local result = tryModule(obj)
                if result then return result end
            end
        end
    end

    -- The template tree is another safe place to look if PlayerScripts has not
    -- finished cloning yet.
    local okStarter, starterPlayer = pcall(function()
        return game:GetService("StarterPlayer")
    end)
    local starterScripts = okStarter and starterPlayer and starterPlayer:FindFirstChild("StarterPlayerScripts")
    if starterScripts then
        for _, obj in ipairs(starterScripts:GetDescendants()) do
            local result = tryModule(obj)
            if result then return result end
        end
    end

    local okFirst, replicatedFirst = pcall(function()
        return game:GetService("ReplicatedFirst")
    end)
    if okFirst and replicatedFirst then
        for _, obj in ipairs(replicatedFirst:GetDescendants()) do
            local result = tryModule(obj)
            if result then return result end
        end
    end

    -- Last fallback. The similarly named Global definitions in ReplicatedStorage
    -- are harmless here because they do not contain requiredField.
    for _, obj in ipairs(S.ReplicatedStorage:GetDescendants()) do
        local result = tryModule(obj)
        if result then return result end
    end

    return nil
end

local function promiseInvoke(endpoint, ...)
    if endpoint == nil or type(endpoint.invoke) ~= "function" then
        return false, nil
    end
    local args = table.pack(...)
    local ok, promise = pcall(function()
        return endpoint:invoke(table.unpack(args, 1, args.n))
    end)
    if not ok then return false, nil end
    if type(promise) == "table" and type(promise.await) == "function" then
        local okAwait, success, result = pcall(function()
            return promise:await()
        end)
        if not okAwait then return false, nil end
        if success == true then return true, result end
        return false, result
    end
    return true, promise
end

local function promiseInvokeRetry(endpoint, attempts, delaySeconds, ...)
    local args = table.pack(...)
    for attempt = 1, math.max(1, math.floor(tonumber(attempts) or 1)) do
        local ok, result = promiseInvoke(endpoint, table.unpack(args, 1, args.n))
        if ok then return true, result end
        if attempt < attempts then task.wait(math.max(0.01, tonumber(delaySeconds) or 0.35)) end
    end
    return false, nil
end

local function eventFire(endpoint, ...)
    if endpoint == nil or type(endpoint.fire) ~= "function" then return false end
    local args = table.pack(...)
    return pcall(function()
        endpoint:fire(table.unpack(args, 1, args.n))
    end)
end

-- Network wrappers -----------------------------------------------------------

function Farm:DiscoverNetworks()
    local DataNetwork = (not self.Network.DataFunctions or not self.Network.DataEvents)
        and requireNetworkWrapper("DataNetwork", "DataFunctions") or nil
    local ShovelNetwork = (not self.Network.ShovelFunctions or not self.Network.ShovelEvents)
        and requireNetworkWrapper("ShovelNetwork", "ShovelFunctions") or nil
    local ItemsNetwork = (not self.Network.ItemsFunctions or not self.Network.ItemsEvents)
        and requireNetworkWrapper("ItemsNetwork", "ItemsFunctions") or nil
    local SellNetwork = not self.Network.SellFunctions
        and requireNetworkWrapper("SellNetwork", "SellFunctions") or nil
    local ShopNetwork = not self.Network.ShopFunctions
        and requireNetworkWrapper("ShopNetwork", "ShopFunctions") or nil
    local TravelNetwork = not self.Network.TravelFunctions
        and requireNetworkWrapper("TravelNetwork", "TravelFunctions") or nil
    local DetectorNetwork = (not self.Network.DetectorFunctions or not self.Network.DetectorEvents)
        and requireNetworkWrapper("DetectorNetwork", "DetectorEvents") or nil
    local QuestNetwork = not self.Network.QuestFunctions
        and requireNetworkWrapper("QuestNetwork", "QuestFunctions") or nil
    local OfflineNetwork = not self.Network.OfflineFunctions
        and requireNetworkWrapper("OfflineEarningsNetwork", "OfflineEarningsFunctions") or nil
    local FreeLuckNetwork = not self.Network.GroupFunctions
        and requireNetworkWrapper("FreeLuckNetwork", "FreeLuckFunctions") or nil
    local PolisherNetwork = not self.Network.PolisherFunctions
        and requireNetworkWrapper("PolisherNetwork", "PolisherFunctions") or nil
    local PlotSectionNetwork = not self.Network.PlotSectionFunctions
        and requireNetworkWrapper("PlotSectionNetwork", "PlotSectionFunctions") or nil
    local PedestalNetwork = not self.Network.PedestalFunctions
        and requireNetworkWrapper("PedestalNetwork", "PedestalFunctions") or nil
    local CodeNetwork = not self.Network.CodeFunctions
        and requireNetworkWrapper("CodeNetwork", "CodeFunctions") or nil

    if DataNetwork then
        self.Network.DataFunctions = DataNetwork.DataFunctions or self.Network.DataFunctions
        self.Network.DataEvents = DataNetwork.DataEvents or self.Network.DataEvents
    end
    if ShovelNetwork then
        self.Network.ShovelFunctions = ShovelNetwork.ShovelFunctions or self.Network.ShovelFunctions
        self.Network.ShovelEvents = ShovelNetwork.ShovelEvents or self.Network.ShovelEvents
    end
    if ItemsNetwork then
        self.Network.ItemsFunctions = ItemsNetwork.ItemsFunctions or self.Network.ItemsFunctions
        self.Network.ItemsEvents = ItemsNetwork.ItemsEvents or self.Network.ItemsEvents
    end
    if SellNetwork then self.Network.SellFunctions = SellNetwork.SellFunctions or self.Network.SellFunctions end
    if ShopNetwork then self.Network.ShopFunctions = ShopNetwork.ShopFunctions or self.Network.ShopFunctions end
    if TravelNetwork then self.Network.TravelFunctions = TravelNetwork.TravelFunctions or self.Network.TravelFunctions end
    if DetectorNetwork then
        self.Network.DetectorFunctions = DetectorNetwork.DetectorFunctions or self.Network.DetectorFunctions
        self.Network.DetectorEvents = DetectorNetwork.DetectorEvents or self.Network.DetectorEvents
    end
    if QuestNetwork then self.Network.QuestFunctions = QuestNetwork.QuestFunctions or self.Network.QuestFunctions end
    if OfflineNetwork then self.Network.OfflineFunctions = OfflineNetwork.OfflineEarningsFunctions or self.Network.OfflineFunctions end
    if FreeLuckNetwork then self.Network.GroupFunctions = FreeLuckNetwork.FreeLuckFunctions or self.Network.GroupFunctions end
    if PolisherNetwork then self.Network.PolisherFunctions = PolisherNetwork.PolisherFunctions or self.Network.PolisherFunctions end
    if PlotSectionNetwork then self.Network.PlotSectionFunctions = PlotSectionNetwork.PlotSectionFunctions or self.Network.PlotSectionFunctions end
    if PedestalNetwork then self.Network.PedestalFunctions = PedestalNetwork.PedestalFunctions or self.Network.PedestalFunctions end
    if CodeNetwork then self.Network.CodeFunctions = CodeNetwork.CodeFunctions or self.Network.CodeFunctions end
end

local function coreNetworkReady()
    return Farm.Network.DataFunctions ~= nil
        and Farm.Network.ShovelFunctions ~= nil
        and Farm.Network.ShovelEvents ~= nil
        and Farm.Network.ItemsFunctions ~= nil
        and Farm.Network.ItemsEvents ~= nil
        and Farm.Network.SellFunctions ~= nil
end

-- UI is already on screen at this point. Retry discovery briefly because the
-- player's TS package can finish cloning a moment after the executor starts.
Farm:DiscoverNetworks()
for _ = 1, 16 do
    local moneyNetworksReady = Farm.Network.PedestalFunctions ~= nil
        and Farm.Network.CodeFunctions ~= nil
        and Farm.Network.ShopFunctions ~= nil
        and Farm.Network.TravelFunctions ~= nil
        and Farm.Network.PolisherFunctions ~= nil
        and Farm.Network.PlotSectionFunctions ~= nil
    if coreNetworkReady() and moneyNetworksReady then break end
    task.wait(0.25)
    Farm:DiscoverNetworks()
end

-- Constants -----------------------------------------------------------------

local ShovelsModule = requirePath("TS", "constants", "digging", "Shovels") or {}
local DetectorsModule = requirePath("TS", "constants", "digging", "Detectors") or {}
local SpraysModule = requirePath("TS", "constants", "cleaning", "SprayBottles") or {}
local IslandsModule = requirePath("TS", "constants", "world", "Islands") or {}
local QuestsModule = requirePath("TS", "constants", "quests", "Quests") or {}
local PolisherModule = requirePath("TS", "constants", "plot", "Polishing") or {}
local ItemsModule = requirePath("TS", "constants", "items", "Items") or {}
local ConditionsModule = requirePath("TS", "constants", "items", "Conditions") or {}
local UpstairsModule = requirePath("TS", "constants", "plot", "UpstairsPedestals") or {}
local PlotSectionsModule = requirePath("TS", "constants", "plot", "PlotSections") or {}
local DataUtilsModule = requirePath("TS", "utils", "data", "DataUtils") or {}
local BackpackCapacityModule = requirePath("TS", "constants", "inventory", "BackpackCapacity") or {}
local DiggingConfigModule = requirePath("TS", "constants", "digging", "DiggingConfig") or {}

Farm.Constants.Shovels = ShovelsModule.Shovels or {}
Farm.Constants.Detectors = DetectorsModule.Detectors or {}
Farm.Constants.Sprays = SpraysModule.SprayBottles or SpraysModule.Sprays or {}
Farm.Constants.Islands = IslandsModule.Islands or {}
Farm.Constants.IslandOrder = IslandsModule.ISLAND_ORDER or {"starterIsland", "island2", "island3", "island4", "island5", "island6"}
Farm.Constants.IsQuestComplete = QuestsModule.isQuestComplete
Farm.Constants.PolisherSlotCount = tonumber(PolisherModule.POLISHER_SLOT_COUNT) or 4
Farm.Constants.GoldPolisherSlotCount = tonumber(PolisherModule.GOLD_POLISHER_SLOT_COUNT) or 2
Farm.Constants.Items = ItemsModule.Items or {}
Farm.Constants.ItemValueFor = ItemsModule.itemValueFor
Farm.Constants.RarityOrder = ItemsModule.RARITY_ORDER or {}
Farm.Constants.Conditions = ConditionsModule.Conditions or {}
Farm.Constants.ConditionOrder = ConditionsModule.CONDITION_ORDER or {}
Farm.Constants.NextConditionFor = PolisherModule.nextConditionFor
Farm.Constants.PolishSecondsFor = PolisherModule.polishSecondsFor
Farm.Constants.PolisherUpgradeCostFor = PolisherModule.polisherUpgradeCostFor
Farm.Constants.PolisherUnlockCostFor = PolisherModule.polisherUnlockCostFor
Farm.Constants.PolisherLevelFor = PolisherModule.polisherLevelFor
Farm.Constants.UpstairsPedestalCostFor = UpstairsModule.upstairsPedestalCostFor
Farm.Constants.UpperFloors = UpstairsModule.UPPER_FLOORS or {}
Farm.Constants.PlotSections = PlotSectionsModule.PlotSections or {}
Farm.Constants.DataUtils = DataUtilsModule.DataUtils
Farm.Constants.BackpackCapacity = BackpackCapacityModule.BackpackCapacity
Farm.Constants.DigDifficultyFor = DiggingConfigModule.digDifficultyFor
Farm.Constants.IsDigImpossible = DiggingConfigModule.isDigImpossible
Farm.Constants.DigWinThreshold = tonumber(DiggingConfigModule.DIG_WIN_THRESHOLD) or 0.985
Farm.Constants.DigLoseThreshold = tonumber(DiggingConfigModule.DIG_LOSE_THRESHOLD) or 0.0574
Farm.Constants.DigRevealSeconds = tonumber(DiggingConfigModule.DIG_REVEAL_SECONDS) or 0.72
Farm.Constants.DigMaxClicksPerSecond = tonumber(DiggingConfigModule.DIG_MAX_CLICKS_PER_SECOND) or 50
Farm.Constants.DigMaxClickBurst = tonumber(DiggingConfigModule.DIG_MAX_CLICK_BURST) or 30
Farm.Constants.DigEffectiveClicksPerSecond = tonumber(DiggingConfigModule.DIG_EFFECTIVE_CLICKS_PER_SECOND) or 11
Farm.Constants.DigImpossibleClicksPerSecond = tonumber(DiggingConfigModule.DIG_IMPOSSIBLE_CLICKS_PER_SECOND) or 8
Farm.Constants.DigZoneTag = ShovelsModule.DIG_ZONE_TAG or "DigZone"
Farm.Constants.IslandAttribute = IslandsModule.ISLAND_ID_ATTRIBUTE or "islandId"

function Farm:MissingCore()
    local missing = {}
    for _, pair in ipairs({
        {"DataFunctions", self.Network.DataFunctions},
        {"ShovelFunctions", self.Network.ShovelFunctions},
        {"ShovelEvents", self.Network.ShovelEvents},
        {"ItemsFunctions", self.Network.ItemsFunctions},
        {"ItemsEvents", self.Network.ItemsEvents},
        {"SellFunctions", self.Network.SellFunctions},
    }) do
        if pair[2] == nil then table.insert(missing, pair[1]) end
    end
    return missing
end

function Farm:RefreshData(force)
    if not self.Network.DataFunctions then return nil end
    local age = os.clock() - (self.State.DataAt or -math.huge)
    -- DataPartialUpdate keeps the cached snapshot hot. Even a forced verification
    -- is rate-limited so clean/dig confirmation loops cannot spam requestDataUpdate.
    local minAge = force and 0.20 or 2.50
    if self.State.Data and age < minAge then return self.State.Data end
    local ok, data = promiseInvoke(self.Network.DataFunctions.requestDataUpdate)
    if ok and type(data) == "table" then
        self.State.Data = data
        self.State.DataAt = os.clock()
        return data
    end
    return self.State.Data
end

function Farm:Gold()
    local data = self:RefreshData(false)
    return tonumber(data and data.Gold) or 0
end

local function arrayHas(list, value)
    if type(list) ~= "table" then return false end
    return table.find(list, value) ~= nil
end

-- Inventory is normally an array, but DataUtils partial updates can temporarily
-- leave holes. Use pairs/generic iteration everywhere so threshold checks never
-- silently read a sparse inventory as empty.
function Farm:InventoryEntries(data)
    data = data or self:RefreshData(false)
    local out = {}
    local inventory = type(data and data.Inventory) == "table" and data.Inventory or {}
    for _, entry in pairs(inventory) do
        if type(entry) == "table" then
            table.insert(out, entry)
        end
    end
    return out
end

function Farm:InventoryUidSet(data)
    local set = {}
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if type(entry.uid) == "string" then set[entry.uid] = true end
    end
    return set
end

function Farm:BackpackCount(data)
    data = data or self:RefreshData(false)
    local count = 0
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if entry.pedestalSlot == nil and entry.polisherSlot == nil then
            count = count + 1
        end
    end
    self.State.LastBackpackCount = count
    return count
end

function Farm:BackpackLimit(data)
    data = data or self:RefreshData(false)
    local cap = self.Constants.BackpackCapacity
    local limit = 50
    if cap and type(cap.limitFor) == "function" and type(data) == "table" then
        local ok, value = pcall(cap.limitFor, data)
        if ok and tonumber(value) then limit = math.max(1, math.floor(tonumber(value))) end
    else
        limit = 50 + math.max(0, math.floor(tonumber(data and data.BonusBackpackSlots) or 0))
    end
    self.State.LastBackpackLimit = limit
    return limit
end

function Farm:BackpackFull(data)
    data = data or self:RefreshData(false)
    return self:BackpackCount(data) >= self:BackpackLimit(data)
end

function Farm:IsIslandUnlocked(id, data)
    data = data or self:RefreshData(false)
    if id == "starterIsland" then return true end
    return arrayHas(data and data.UnlockedIslands, id)
end

function Farm:CurrentIsland()
    local data = self:RefreshData(false)
    return data and data.CurrentIsland or "starterIsland"
end

function Farm:CharacterRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function Farm:GuiObjectActuallyVisible(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if obj.Visible ~= true then return false end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local cursor = obj.Parent
    while cursor and cursor ~= playerGui do
        if cursor:IsA("GuiObject") and cursor.Visible == false then return false end
        if cursor:IsA("LayerCollector") and cursor.Enabled == false then return false end
        cursor = cursor.Parent
    end
    return true
end

function Farm:FindRecoveryFrame()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end

    -- Exact game path from RecoverController.setupFrame().
    local main = playerGui:FindFirstChild("Main")
    if main then
        local direct = main:FindFirstChild("Recover")
        if direct and direct:IsA("GuiObject") then return direct end
        direct = main:FindFirstChild("Recover", true)
        if direct and direct:IsA("GuiObject") then return direct end
    end

    -- Name fallback for alternate UI replication layouts.
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("GuiObject") and string.lower(obj.Name) == "recover" then
            return obj
        end
    end

    -- Last-resort content search. This catches an animation wrapper where the
    -- visible outer frame is renamed but the RecoverController text is present.
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local text = tostring(obj.Text or "")
            if text:find("You lost a", 1, true) or text:find("Recover Item", 1, true) then
                local cursor = obj.Parent
                for _ = 1, 8 do
                    if not cursor or cursor == playerGui then break end
                    if cursor:IsA("GuiObject") then
                        local yes = cursor:FindFirstChild("Yes", true)
                        local no = cursor:FindFirstChild("No", true)
                        if yes or no then return cursor end
                    end
                    cursor = cursor.Parent
                end
            end
        end
    end
    return nil
end

function Farm:RecoveryPromptVisible()
    local frame = self:FindRecoveryFrame()
    if not frame then return false, nil end
    return self:GuiObjectActuallyVisible(frame), frame
end

function Farm:FindRecoveryNoButton(frame)
    if not frame then return nil end
    local direct = frame:FindFirstChild("No", true)
    if direct and direct:IsA("GuiButton") then return direct end
    for _, obj in ipairs(frame:GetDescendants()) do
        if obj:IsA("GuiButton") then
            local text = ""
            pcall(function() text = tostring(obj.Text or "") end)
            if string.upper(text):gsub("%s+", "") == "NO" then return obj end
        end
    end
    return nil
end

function Farm:MarkRecoveryFromGui(reason)
    local now = os.clock()
    self.State.RecoveryActive = true
    self.State.RecoveryAwaitPopupUntil = math.max(tonumber(self.State.RecoveryAwaitPopupUntil) or -math.huge, now + 1.20)
    self.State.RecoveryHardLockUntil = math.max(tonumber(self.State.RecoveryHardLockUntil) or -math.huge, now + 1.60)
    self.State.RecoveryResumeAt = math.max(tonumber(self.State.RecoveryResumeAt) or -math.huge, now + (tonumber(self.Config.RecoveryResumeDelay) or 0.70))
    self.State.RecoverySafeLuckUntil = math.max(tonumber(self.State.RecoverySafeLuckUntil) or -math.huge, now + (tonumber(self.Config.RecoverySafeLuckSeconds) or 75))
    if not self.State.RecoverySeenThisOffer or now - (tonumber(self.State.RecoveryGuiSeenAt) or -math.huge) > 1.25 then
        self.State.RecoverySeenThisOffer = true
        self.State.RecoveryGuiSeenAt = now
        self.State.RecoveryOffered = (tonumber(self.State.RecoveryOffered) or 0) + 1
        self.State.LastRecovery = tostring(reason or self.State.LastRecovery or "Recovery GUI")
    end
end

function Farm:RecoveryLocked()
    local now = os.clock()
    local visible = self:RecoveryPromptVisible()
    if visible then
        self:MarkRecoveryFromGui("Recovery popup detected")
        return true
    end
    if self.State.RecoveryActive == true then return true end
    if now < (tonumber(self.State.RecoveryAwaitPopupUntil) or -math.huge) then return true end
    if now < (tonumber(self.State.RecoveryHardLockUntil) or -math.huge) then return true end
    if now < (tonumber(self.State.RecoveryResumeAt) or -math.huge) then return true end
    return false
end

function Farm:DismissRecoveryPrompt()
    if self.State.RecoveryDismissBusy then return false end
    local visible, frame = self:RecoveryPromptVisible()
    if not frame or not visible then return false end

    local now = os.clock()
    if now - (tonumber(self.State.RecoveryLastDismissAttempt) or -math.huge) < 0.16 then return false end
    self.State.RecoveryLastDismissAttempt = now
    self.State.RecoveryDismissBusy = true
    self:MarkRecoveryFromGui(self.State.LastRecovery ~= "None" and self.State.LastRecovery or "Recovery popup")

    local closed = false
    local no = self:FindRecoveryNoButton(frame)
    if no then
        -- Do NOT use VirtualInputManager here. Simulated screen clicks can fall
        -- through the modal and the native DigController interprets them as new
        -- dig attempts (the x43 'Find a dig spot' spam seen in testing).
        if type(firesignal) == "function" then
            local fired = false
            fired = pcall(function() firesignal(no.Activated) end) or fired
            if not fired then fired = pcall(function() firesignal(no.MouseButton1Click) end) or fired end
            if not fired then fired = pcall(function() firesignal(no.MouseButton1Down) end) or fired end
        end
    end

    task.wait(0.04)
    closed = not self:RecoveryPromptVisible()

    if not closed then
        -- Safe visual fallback: never synthesize a world mouse click. The next
        -- recovery offer increments RecoverController.offerId anyway, so hiding
        -- an unresponsive current frame is preferable to accidentally digging.
        pcall(function() frame.Visible = false end)
        task.wait(0.03)
        closed = not self:RecoveryPromptVisible()
    end

    if closed then
        local t = os.clock()
        self.State.RecoveryActive = false
        self.State.RecoveryAwaitPopupUntil = -math.huge
        self.State.RecoveryHardLockUntil = math.max(tonumber(self.State.RecoveryHardLockUntil) or -math.huge, t + 0.20)
        self.State.RecoveryResumeAt = math.max(tonumber(self.State.RecoveryResumeAt) or -math.huge, t + (tonumber(self.Config.RecoveryResumeDelay) or 0.70))
    end
    self.State.RecoveryDismissBusy = false
    return closed
end

function Farm:WaitAndClearRecovery(reason, seconds)
    local now = os.clock()
    local duration = math.max(1.35, tonumber(seconds) or 2.15)
    self.State.RecoveryActive = true
    self.State.RecoverySeenThisOffer = false
    self.State.RecoveryAwaitPopupUntil = math.max(tonumber(self.State.RecoveryAwaitPopupUntil) or -math.huge, now + duration)
    self.State.RecoveryHardLockUntil = math.max(tonumber(self.State.RecoveryHardLockUntil) or -math.huge, now + duration + 0.25)
    self.State.RecoverySafeLuckUntil = math.max(tonumber(self.State.RecoverySafeLuckUntil) or -math.huge, now + (tonumber(self.Config.RecoverySafeLuckSeconds) or 75))

    local deadline = now + duration
    local sawPopup = false
    local lastVisibleAt = -math.huge
    while self.Running and os.clock() < deadline do
        local visible = self:RecoveryPromptVisible()
        if visible then
            sawPopup = true
            lastVisibleAt = os.clock()
            self:MarkRecoveryFromGui(reason or "Dig loss")
            if self.Config.RecoveryAutoDecline ~= false then self:DismissRecoveryPrompt() end
        elseif sawPopup and os.clock() - lastVisibleAt >= 0.20 then
            break
        end
        task.wait(0.04)
    end

    self.State.RecoveryActive = false
    self.State.RecoveryAwaitPopupUntil = -math.huge
    self.State.RecoveryHardLockUntil = math.max(tonumber(self.State.RecoveryHardLockUntil) or -math.huge, os.clock() + 0.20)
    self.State.RecoveryResumeAt = math.max(tonumber(self.State.RecoveryResumeAt) or -math.huge, os.clock() + (tonumber(self.Config.RecoveryResumeDelay) or 0.70))
    return sawPopup
end

function Farm:MoveTo(positionOrCFrame)
    if self:RecoveryLocked() then return false end
    local root = self:CharacterRoot()
    if not root then return false end
    local cf = typeof(positionOrCFrame) == "CFrame" and positionOrCFrame or CFrame.new(positionOrCFrame)
    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = cf
    end)
    if ok then task.wait(0.10) end
    return ok
end

function Farm:DigZonesForIsland(islandId)
    local zones = {}
    for _, zone in ipairs(S.CollectionService:GetTagged(self.Constants.DigZoneTag)) do
        if zone:IsA("BasePart") and zone:GetAttribute(self.Constants.IslandAttribute) == islandId then
            table.insert(zones, zone)
        end
    end
    return zones
end

function Farm:DigZoneForIsland(islandId)
    local best, bestArea = nil, -math.huge
    for _, zone in ipairs(self:DigZonesForIsland(islandId)) do
        local area = zone.Size.X * zone.Size.Z
        if area > bestArea then
            best, bestArea = zone, area
        end
    end
    return best
end

function Farm:IslandRoot(islandId)
    local cached = self.State.IslandRootCache[islandId]
    if cached and cached.Parent then return cached end
    local cfg = self.Constants.Islands[islandId]
    local expectedName = type(cfg) == "table" and cfg.name or nil

    -- The most reliable anchor is a tagged DigZone, which already carries the
    -- authoritative islandId. Walk upward until the named island model/folder.
    local zone = self:DigZoneForIsland(islandId)
    if zone then
        local cursor = zone
        while cursor and cursor ~= S.Workspace do
            if expectedName and cursor.Name == expectedName then
                self.State.IslandRootCache[islandId] = cursor
                return cursor
            end
            cursor = cursor.Parent
        end
    end

    if expectedName then
        for _, obj in ipairs(S.Workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("Folder")) and obj.Name == expectedName then
                self.State.IslandRootCache[islandId] = obj
                return obj
            end
        end
    end
    return nil
end

function Farm:IslandForPosition(position)
    if typeof(position) ~= "Vector3" then return nil, math.huge end
    local bestIsland, bestDistance = nil, math.huge
    for _, zone in ipairs(S.CollectionService:GetTagged(self.Constants.DigZoneTag)) do
        if zone:IsA("BasePart") then
            local islandId = zone:GetAttribute(self.Constants.IslandAttribute)
            if type(islandId) == "string" then
                local p = zone.CFrame:PointToObjectSpace(position)
                local dx = math.max(0, math.abs(p.X) - zone.Size.X * 0.5)
                local dz = math.max(0, math.abs(p.Z) - zone.Size.Z * 0.5)
                local d = math.sqrt(dx * dx + dz * dz)
                if d < bestDistance then
                    bestIsland, bestDistance = islandId, d
                end
            end
        end
    end
    return bestIsland, bestDistance
end

function Farm:NodeBelongsToCurrentIsland(node)
    if type(node) ~= "table" or typeof(node.position) ~= "Vector3" then return false end
    local current = self:CurrentIsland()
    local islandId, edgeDistance = self:IslandForPosition(node.position)
    -- Nodes can sit just off the exact rectangle edge, so allow a small margin,
    -- but never select a node whose nearest DigZone belongs to another island.
    return islandId == current and edgeDistance <= 18
end

function Farm:EnsureDigZone()
    if not self.Config.AutoMoveToDigZone then return true end
    local island = self:CurrentIsland()
    local zone = self:DigZoneForIsland(island)
    -- Never fall back to a random DigZone on another island. That was one source
    -- of cross-island searching/teleports after travel.
    if not zone then return false end
    local root = self:CharacterRoot()
    if root then
        local localPoint = zone.CFrame:PointToObjectSpace(root.Position)
        local insideXZ = math.abs(localPoint.X) <= zone.Size.X * 0.48 and math.abs(localPoint.Z) <= zone.Size.Z * 0.48
        if insideXZ then
            self.State.LastSearchIsland = island
            return true
        end
    end
    self:SetAction("Moving to " .. tostring(island) .. " dig zone")
    local moved = self:MoveTo(zone.CFrame * CFrame.new(0, math.max(2.5, zone.Size.Y * 0.5 + 1.5), 0))
    if moved then self.State.LastSearchIsland = island end
    return moved
end

-- Buried detector nodes ------------------------------------------------------

local RARITY_SCORE = {
    common = 1,
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
    mythic = 6,
    divine = 7,
    eternal = 8,
    transcendent = 9,
    omega = 10,
    anomaly = 11,
    paradox = 12,
    singularity = 13,
}

function Farm:UpdateBuriedNodes(nodes, removed)
    if type(removed) == "table" then
        for _, id in ipairs(removed) do self.State.BuriedNodes[id] = nil end
    end
    if type(nodes) == "table" then
        for _, node in ipairs(nodes) do
            if type(node) == "table" and type(node.id) == "string" and typeof(node.position) == "Vector3" then
                self.State.BuriedNodes[node.id] = node
            end
        end
    end
end

function Farm:BestBuriedNode()
    local root = self:CharacterRoot()
    local best, bestScore = nil, -math.huge
    local now = os.clock()
    for id, node in pairs(self.State.BuriedNodes) do
        if type(id) == "string" and typeof(node.position) == "Vector3"
            and self:NodeBelongsToCurrentIsland(node) then
            local riskyUntil = tonumber(self.State.RiskyRarityUntil[node.rarity]) or -math.huge
            if not self.Config.AvoidRecoveryLosses or now >= riskyUntil then
                local dist = root and (root.Position - node.position).Magnitude or 9999
                local rarity = RARITY_SCORE[node.rarity] or 0
                local score
                if self.Config.BuriedPriority == "Closest" then
                    score = -dist + rarity * 0.001
                else
                    score = rarity * 100000 - dist
                end
                if score > bestScore then
                    best, bestScore = node, score
                end
            end
        end
    end
    return best
end

function Farm:PrepareDetector()
    if not self.Config.PreferBuriedNodes then return end
    local events = self.Network.DetectorEvents
    if events and events.SetDetectorHeld then
        eventFire(events.SetDetectorHeld, true)
    end
end

-- Smart money / value helpers -----------------------------------------------

function Farm:ItemValue(entry, conditionOverride)
    if type(entry) ~= "table" or type(entry.id) ~= "string" then return 0 end
    local condition = conditionOverride or entry.condition
    if type(condition) ~= "string" then return 0 end
    local fn = self.Constants.ItemValueFor
    if type(fn) == "function" then
        local ok, value = pcall(fn, entry.id, condition, tonumber(entry.kg), entry.mutation)
        if ok and tonumber(value) then return math.max(0, tonumber(value)) end
    end
    -- beginCleaning returns a value for freshly cleaned items, but that result is
    -- not persisted on every inventory entry. This fallback is intentionally
    -- conservative so an unknown value is never treated as a top display item.
    return math.max(0, tonumber(entry.value) or 0)
end

function Farm:DisplayedEntries(data)
    local displayed = {}
    for _, entry in ipairs(self:InventoryEntries(data)) do
        local slot = tonumber(entry.pedestalSlot)
        if slot and entry.dirty ~= true and entry.condition ~= nil then
            displayed[math.floor(slot)] = entry
        end
    end
    return displayed
end

function Farm:OwnedPedestalSlots(data)
    data = data or self:RefreshData(false) or {}
    local slots = {}
    -- Base plot has eight permanent pedestal slots. Upper-floor ownership is
    -- tracked separately in player data and each unlocked floor grants slot #1.
    for slot = 1, 8 do table.insert(slots, slot) end
    local function addFloor(sectionId, offset, ownedKey)
        if not arrayHas(data.UnlockedSections, sectionId) then return end
        local owned = math.clamp(math.max(tonumber(data[ownedKey]) or 0, 1), 1, 8)
        for i = 1, math.floor(owned) do table.insert(slots, offset + i) end
    end
    addFloor("Floor2", 8, "OwnedUpstairsPedestals")
    addFloor("Floor3", 16, "OwnedFloor3Pedestals")
    return slots
end

function Farm:DisplayStats(data)
    data = data or self:RefreshData(false)
    local total, count = 0, 0
    for _, entry in pairs(self:DisplayedEntries(data)) do
        total = total + self:ItemValue(entry)
        count = count + 1
    end
    self.State.DisplayedValue = total
    self.State.DisplayedCount = count
    -- VisitorConstants.INCOME_PERCENT_PER_MINUTE = 0.6 => 1% of value / sec.
    self.State.PassiveGoldPerSecond = total * 0.01
    return count, total, total * 0.01
end

function Farm:BestLooseCleanItems(data)
    local candidates = {}
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if type(entry.uid) == "string"
            and entry.dirty ~= true
            and entry.condition ~= nil
            and entry.pedestalSlot == nil
            and entry.polisherSlot == nil
            and entry.favorited ~= true then
            table.insert(candidates, {entry = entry, value = self:ItemValue(entry)})
        end
    end
    table.sort(candidates, function(a, b)
        if a.value == b.value then return tostring(a.entry.uid) < tostring(b.entry.uid) end
        return a.value > b.value
    end)
    return candidates
end

function Farm:DisplayTick(force)
    if not self.Config.AutoDisplayBest or not self.Network.PedestalFunctions then return false end
    local interval = math.max(0.5, tonumber(self.Config.DisplayCheckSeconds) or 1.25)
    if not force and os.clock() - self.State.LastDisplayAt < interval then return false end
    self.State.LastDisplayAt = os.clock()

    local data = self:RefreshData(true)
    if not data then return false end
    local displayed = self:DisplayedEntries(data)
    local candidates = self:BestLooseCleanItems(data)
    local slots = self:OwnedPedestalSlots(data)
    self:DisplayStats(data)

    -- Island unlocks are the strongest active-income multiplier. When we're in
    -- the save window, keep existing displays earning but leave new finds liquid
    -- so SellTick can turn them into the gold needed for the next island.
    if self.Config.SmartMoneyMode and self:SavingForNextIsland(data) then
        return false
    end

    -- Fill free owned slots first. Try all free slots because a just-unlocked
    -- floor can replicate a moment after the data flag arrives.
    if #candidates > 0 then
        for _, slot in ipairs(slots) do
            if displayed[slot] == nil then
                local candidate = candidates[1]
                self:SetAction("Displaying $" .. tostring(math.floor(candidate.value)) .. " item")
                local ok, placed = promiseInvoke(self.Network.PedestalFunctions.placeItem, slot, candidate.entry.uid)
                if ok and placed == true then
                    self.State.DisplayPlacements = self.State.DisplayPlacements + 1
                    self:RefreshData(true)
                    self:DisplayStats(self.State.Data)
                    return true
                end
            end
        end
    end

    -- Once full, only churn a pedestal when the replacement is materially
    -- better. This keeps passive income stable and avoids remote spam.
    if #candidates > 0 then
        local worstSlot, worstEntry, worstValue = nil, nil, math.huge
        for _, slot in ipairs(slots) do
            local entry = displayed[slot]
            if entry then
                local value = self:ItemValue(entry)
                if value < worstValue then
                    worstSlot, worstEntry, worstValue = slot, entry, value
                end
            end
        end
        local best = candidates[1]
        local ratio = math.max(1.01, (tonumber(self.Config.DisplayReplaceRatio) or 120) / 100)
        if worstSlot and best.value > 0 and best.value >= math.max(1, worstValue) * ratio then
            self:SetAction("Upgrading passive display")
            local okPick, picked = promiseInvoke(self.Network.PedestalFunctions.pickupItem, worstSlot)
            if okPick and picked == true then
                self:RefreshData(true)
                local okPlace, placed = promiseInvoke(self.Network.PedestalFunctions.placeItem, worstSlot, best.entry.uid)
                if okPlace and placed == true then
                    self.State.DisplaySwaps = self.State.DisplaySwaps + 1
                    self:RefreshData(true)
                    self:DisplayStats(self.State.Data)
                    return true
                end
                -- If placement is delayed/rejected, leave the slot empty rather
                -- than risking an item loss. Next DisplayTick fills it safely.
                self.State.LastError = "Display replacement will retry"
                return true
            end
        end
    end
    return false
end

function Farm:NextLockedIsland(data)
    data = data or self:RefreshData(false)
    if not data then return nil, nil end
    local unlocked = data.UnlockedIslands or {}
    for _, id in ipairs(self.Constants.IslandOrder) do
        if not arrayHas(unlocked, id) then
            local cfg = self.Constants.Islands[id]
            return id, cfg and tonumber(cfg.cost) or nil
        end
    end
    return nil, nil
end

function Farm:SavingForNextIsland(data)
    if not self.Config.SmartMoneyMode then return false end
    data = data or self:RefreshData(false)
    local _, nextCost = self:NextLockedIsland(data)
    if not nextCost or nextCost <= 0 then return false end
    local gold = tonumber(data and data.Gold) or 0
    local pct = math.clamp((tonumber(self.Config.IslandSaveAtPercent) or 65) / 100, 0.4, 0.95)
    return gold >= nextCost * pct
end

function Farm:BestExcessDisplayCandidate(data)
    local list = self:BestLooseCleanItems(data)
    return list[1]
end

function Farm:PassivePaybackMinutes(cost, itemValue)
    cost, itemValue = tonumber(cost) or math.huge, tonumber(itemValue) or 0
    if cost <= 0 then return 0 end
    if itemValue <= 0 then return math.huge end
    return cost / (itemValue * 0.01) / 60
end

function Farm:SmartPassiveExpansionTick(force)
    if not self.Config.SmartMoneyMode or not self.Config.AutoBuyPassiveSlots then return false end
    if not self.Network.PlotSectionFunctions or not self.Network.PedestalFunctions then return false end
    if not force and os.clock() - self.State.LastPassiveBuyAt < 4 then return false end
    self.State.LastPassiveBuyAt = os.clock()
    local data = self:RefreshData(true)
    if not data then return false end
    local gold = tonumber(data.Gold) or 0
    local unlocked = data.UnlockedSections or {}

    -- Island unlocks have the strongest direct luck multiplier. Never spend on
    -- passive expansion while we're already in the save-for-next-island window.
    if self:SavingForNextIsland(data) then return false end

    -- Polishing unlock is cheap relative to later progression and lets otherwise
    -- idle clean items compound into better pedestal income.
    if self.Config.AutoUnlockPlotSections and not arrayHas(unlocked, "Polishing")
        and self:IsIslandUnlocked("island2", data) then
        local cfg = self.Constants.PlotSections.Polishing
        local cost = cfg and tonumber(cfg.unlockCost) or 1500000
        if gold >= cost * 1.20 then
            self:SetAction("Unlocking smart polishing")
            local ok, result = promiseInvoke(self.Network.PlotSectionFunctions.unlockSection, "Polishing")
            if ok and result == "ok" then
                self.State.LastPassivePurchase = "Polishing"
                self:RefreshData(true)
                return true
            end
        end
    end

    -- Once both paid gold polishers are owned, ExtraPolishers can add more
    -- parallel condition upgrades. Use the real PlotSections cost and only buy
    -- it when it is a small fraction of current cash and we are not saving for
    -- the next island. This avoids repeating the old blind unlock behavior.
    if self.Config.AutoUnlockPlotSections
        and not arrayHas(unlocked, "ExtraPolishers")
        and arrayHas(unlocked, "Polishing")
        and math.floor(tonumber(data.OwnedPolishers) or 1) >= self.Constants.GoldPolisherSlotCount then
        local cfg = self.Constants.PlotSections.ExtraPolishers
        local cost = cfg and tonumber(cfg.unlockCost) or nil
        if cost and cost > 0 and gold >= cost and cost <= gold * 0.18 then
            self:SetAction("Unlocking extra polishers")
            local ok, result = promiseInvoke(self.Network.PlotSectionFunctions.unlockSection, "ExtraPolishers")
            if ok and result == "ok" then
                self.State.LastPassivePurchase = "ExtraPolishers"
                self:RefreshData(true)
                return true
            end
        end
    end

    local candidate = self:BestExcessDisplayCandidate(data)
    if not candidate or candidate.value <= 0 then return false end
    local maxPayback = math.max(5, tonumber(self.Config.MaxPassivePaybackMinutes) or 45)

    -- Each unlocked upper floor grants its first pedestal. Unlock only after the
    -- competing island at the same progression stage is already owned.
    local floorPlans = {
        {section = "Floor2", requiredIsland = "island4", cost = 600000000},
        {section = "Floor3", requiredIsland = "island6", cost = 1000000000000},
    }
    for _, plan in ipairs(floorPlans) do
        if self.Config.AutoUnlockPlotSections
            and not arrayHas(unlocked, plan.section)
            and self:IsIslandUnlocked(plan.requiredIsland, data)
            and gold >= plan.cost then
            local payback = self:PassivePaybackMinutes(plan.cost, candidate.value)
            if payback <= maxPayback then
                self:SetAction(string.format("Unlocking %s (%.1fm payback)", plan.section, payback))
                local ok, result = promiseInvoke(self.Network.PlotSectionFunctions.unlockSection, plan.section)
                if ok and result == "ok" then
                    self.State.LastPassivePurchase = plan.section
                    self:RefreshData(true)
                    return true
                end
            end
        end
    end

    -- Buy additional upper-floor pedestal slots only when the best excess item
    -- can repay the slot cost within the user's configured payback window.
    local floors = {
        {section = "Floor2", offset = 8, key = "OwnedUpstairsPedestals"},
        {section = "Floor3", offset = 16, key = "OwnedFloor3Pedestals"},
    }
    for _, floor in ipairs(floors) do
        if arrayHas(unlocked, floor.section) then
            local owned = math.clamp(math.max(math.floor(tonumber(data[floor.key]) or 0), 1), 1, 8)
            if owned < 8 then
                local nextSlot = floor.offset + owned + 1
                local costFn = self.Constants.UpstairsPedestalCostFor
                local cost = nil
                if type(costFn) == "function" then
                    local okCost, value = pcall(costFn, nextSlot)
                    if okCost then cost = tonumber(value) end
                end
                if cost and gold >= cost then
                    local payback = self:PassivePaybackMinutes(cost, candidate.value)
                    if payback <= maxPayback then
                        self:SetAction(string.format("Buying pedestal %d (%.1fm payback)", nextSlot, payback))
                        local ok, result = promiseInvoke(self.Network.PedestalFunctions.buyPedestal, nextSlot)
                        if ok and result == "ok" then
                            self.State.LastPassivePurchase = "Pedestal " .. tostring(nextSlot)
                            self:RefreshData(true)
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function Farm:IncompleteQuest(taskName)
    if not self.Config.AutoQuestFocus then return nil end
    local data = self:RefreshData(false)
    for _, quest in ipairs(type(data and data.DailyQuests) == "table" and data.DailyQuests or {}) do
        if quest.task == taskName and quest.claimed ~= true and (tonumber(quest.progress) or 0) < (tonumber(quest.target) or 1) then
            return quest
        end
    end
    return nil
end

-- Digging -------------------------------------------------------------------

function Farm:WaitForMaxPower(powerStartedAt)
    local target = tonumber(self.Config.DigPowerSeconds) or 0.275
    target = math.clamp(target, 0.12, 0.55)
    if not self.Config.MaxPowerTiming then target = 0.275 end

    -- A recovery means the current shovel can roll items that are beyond a sane
    -- dig requirement. For a short cooldown use the end of the 0.55s power wave
    -- (1x luck) instead of the 0.275s peak (5x luck). This lowers the chance of
    -- immediately rolling another impossible rarity while gear progression catches up.
    if self.Config.AvoidRecoveryLosses and os.clock() < (tonumber(self.State.RecoverySafeLuckUntil) or -math.huge) then
        target = 0.55
        self:SetAction("Recovery-safe 1x luck charge")
    end

    local deadline = os.clock() + 1.35
    while self.Running and os.clock() < deadline do
        if self:RecoveryPromptVisible() then return end
        local elapsed = S.Workspace:GetServerTimeNow() - (tonumber(powerStartedAt) or S.Workspace:GetServerTimeNow())
        if elapsed >= target then return end
        task.wait(math.min(0.02, math.max(0.005, target - elapsed)))
    end
end

function Farm:SolveDig(sessionId, difficulty)
    if type(sessionId) ~= "string" or type(difficulty) ~= "table" then return false end
    local clickPower = math.max(0.00001, tonumber(difficulty.clickPower) or 0)
    local decay = math.max(0, tonumber(difficulty.decay) or 0)
    local difficultyRatio = decay / clickPower

    local baseCps = math.clamp(tonumber(self.Config.DigClicksPerSecond) or 10.8, 5, tonumber(self.Constants.DigEffectiveClicksPerSecond) or 11)
    local cps = baseCps
    if self.Config.AvoidRecoveryLosses and self.Config.RecoverySafeHardDigBoost then
        local serverMax = math.max(12, (tonumber(self.Constants.DigMaxClicksPerSecond) or 50) - 1.0)
        local maxCps = math.clamp(tonumber(self.Config.HardDigMaxCps) or 49, 11, serverMax)
        if difficultyRatio >= baseCps - 0.35 then
            cps = math.clamp(difficultyRatio + 3.0, 11, maxCps)
            self:SetAction(string.format("Hard dig %.1fx @ %.1f CPS", difficultyRatio, cps))
        end
    elseif difficultyRatio >= (tonumber(self.Constants.DigImpossibleClicksPerSecond) or 8) then
        self:SetAction(string.format("Hard dig %.1fx", difficultyRatio))
    end

    -- Native DigController does not send DigReady until the full mound/item
    -- reveal (0.72s in this build). Matching that timing avoids starting server
    -- click validation while the session is still in reveal state.
    local revealSeconds = math.max(0.50, tonumber(self.Constants.DigRevealSeconds) or 0.72)
    local revealDeadline = os.clock() + revealSeconds
    while self.Running and os.clock() < revealDeadline do
        if self:RecoveryPromptVisible() then return false end
        task.wait(0.02)
    end
    eventFire(self.Network.ShovelEvents.DigReady, sessionId)
    task.wait(0.035)

    local winThreshold = tonumber(self.Constants.DigWinThreshold) or 0.985
    local loseThreshold = tonumber(self.Constants.DigLoseThreshold) or 0.0574
    local progress = 0.33
    local totalClicks = 0
    local clickCredits = math.min(3, tonumber(self.Constants.DigMaxClickBurst) or 30)
    local started = os.clock()
    local last = started
    local lastSend = started
    local sendInterval = 0.10

    -- Native client begins with three effective click credits. Pace them through
    -- the same cumulative DigInput path rather than front-loading an oversized burst.
    if clickCredits > 0 then
        totalClicks = totalClicks + clickCredits
        progress = math.min(1, progress + clickPower * clickCredits)
        eventFire(self.Network.ShovelEvents.DigInput, sessionId, totalClicks)
    end

    local accumulator = 0
    local timeout = math.max(8, tonumber(self.Config.DigTimeout) or 36)
    while self.Running and progress < winThreshold and os.clock() - started < timeout do
        if self:RecoveryPromptVisible() then return false end
        task.wait(0.02)
        local now = os.clock()
        local dt = math.min(0.10, math.max(0, now - last))
        last = now

        progress = math.max(0, progress - decay * dt)
        if progress <= loseThreshold then break end

        accumulator = accumulator + cps * dt
        local clicks = math.floor(accumulator)
        if clicks > 0 then
            accumulator = accumulator - clicks
            totalClicks = totalClicks + clicks
            progress = math.min(1, progress + clickPower * clicks)
        end

        if now - lastSend >= sendInterval then
            eventFire(self.Network.ShovelEvents.DigInput, sessionId, totalClicks)
            lastSend = now
        end
    end

    eventFire(self.Network.ShovelEvents.DigInput, sessionId, totalClicks)
    task.wait(0.05)

    local wonLocally = progress >= winThreshold
    local ok, result = promiseInvokeRetry(self.Network.ShovelFunctions.ResolveDig, 4, 0.35, sessionId, wonLocally, totalClicks)
    return ok and result == true
end

function Farm:DigOnce()
    if not self.Config.AutoDig or not self.Network.ShovelFunctions or not self.Network.ShovelEvents then return false end
    if self:RecoveryLocked() then
        self:DismissRecoveryPrompt()
        return false
    end
    if os.clock() - self.State.LastDigAt < 0.55 then return false end

    -- Never begin a new dig if the backpack is already at capacity. This is the
    -- most important protection against surfacing an item the server cannot add.
    local preData = self:RefreshData(true)
    if self:BackpackFull(preData) then
        self:SetAction("Backpack full - selling before next dig")
        if self.Config.AutoClean and #self:DirtyInventory(preData) > 0 then self:CleanTick() end
        if self.Config.AutoSell then self:SellTick(true) end
        return false
    end

    self.State.LastDigAt = os.clock()
    self:PrepareDetector()

    local preferBuried = self.Config.PreferBuriedNodes
    -- A surfaced-dig daily quest awards a temporary high-multiplier luck boost.
    -- Temporarily ignore detector nodes until that quest is complete.
    if self.Config.AutoQuestFocus and self:IncompleteQuest("surfacedDig") then preferBuried = false end
    local buried = preferBuried and self:BestBuriedNode() or nil
    self.State.CurrentDigRarity = buried and buried.rarity or nil
    if buried then
        self:SetAction("Digging buried " .. tostring(buried.rarity or "item"))
        self:MoveTo(buried.position + Vector3.new(0, 3, 0))
    else
        if not self:EnsureDigZone() then
            self:SetError("No DigZone found")
            return false
        end
        self:SetAction("Starting dig")
    end

    local before = self:RefreshData(true)
    local beforeDug = tonumber(before and before.ItemsDug) or 0
    local beforeUids = self:InventoryUidSet(before)
    local beforeCount = self:BackpackCount(before)

    local okBegin, response
    if buried then
        okBegin, response = promiseInvoke(self.Network.ShovelFunctions.BeginDig, buried.id)
    else
        okBegin, response = promiseInvoke(self.Network.ShovelFunctions.BeginDig)
    end
    if not okBegin or type(response) ~= "table" or type(response.sessionId) ~= "string" then
        if buried then self.State.BuriedNodes[buried.id] = nil end
        self.State.DigFails = self.State.DigFails + 1
        return false
    end

    self.State.Digs = self.State.Digs + 1
    local sessionId = response.sessionId
    local result = response

    if not (response.surfaced and response.difficulty) then
        self:SetAction("Charging max dig luck")
        self:WaitForMaxPower(response.powerStartedAt)
        local serverNow = S.Workspace:GetServerTimeNow()
        local okStop, stopped = promiseInvokeRetry(self.Network.ShovelFunctions.StopPower, 4, 0.35, sessionId, serverNow, false)
        if not okStop or type(stopped) ~= "table" then
            promiseInvokeRetry(self.Network.ShovelFunctions.ResolveDig, 4, 0.35, sessionId, false, 0)
            self.State.DigFails = self.State.DigFails + 1
            self:WaitAndClearRecovery("Power-stop dig lost", 1.85)
            return false
        end
        result = stopped
    end

    local difficulty = result.difficulty or response.difficulty
    local itemId = result.itemId or (result.surfaced and result.surfaced.itemId) or (response.surfaced and response.surfaced.itemId)
    if itemId then self.State.LastItem = tostring(itemId) end

    self:SetAction("Digging " .. tostring(itemId or "item"))
    local won = self:SolveDig(sessionId, difficulty)
    if not won then
        self.State.DigFails = self.State.DigFails + 1
        -- The RecoverController can show the paid recovery UI ~0.5s after the
        -- server decides the dig was lost. Do not trust only the network event:
        -- some executor/client wrapper combinations miss that callback. Poll the
        -- actual GUI and hard-lock ALL movement/actions until it is gone.
        self:WaitAndClearRecovery(tostring(itemId or "item") .. " lost", 1.85)
        return false
    end

    self.State.DigWins = self.State.DigWins + 1
    if buried then self.State.BuriedNodes[buried.id] = nil end

    -- ResolveDig returning true is not enough. The native DigController keeps the
    -- success scene alive for ~0.55s, while the inventory update can arrive after
    -- the resolve response. Do not teleport to another mound until a NEW uid is
    -- visible in inventory (or at minimum the backpack count grows).
    self:SetAction("Securing dug item")
    local awardStarted = os.clock()
    local awardDeadline = awardStarted + 4.0
    local confirmedUid = nil
    local confirmed = false
    local lastForcedAwardRefresh = -math.huge
    while self.Running and os.clock() < awardDeadline do
        local elapsed = os.clock() - awardStarted
        local forceRefresh = elapsed >= 0.65 and os.clock() - lastForcedAwardRefresh >= 0.60
        if forceRefresh then
            self.State.DataAt = -math.huge
            lastForcedAwardRefresh = os.clock()
        end
        local data = self:RefreshData(forceRefresh)
        local entries = self:InventoryEntries(data)
        for _, entry in ipairs(entries) do
            if type(entry.uid) == "string" and not beforeUids[entry.uid] then
                confirmedUid = entry.uid
                confirmed = true
                break
            end
        end
        if confirmed or self:BackpackCount(data) > beforeCount then break end
        task.wait(0.08)
    end
    self.State.LastAwardWaitSeconds = os.clock() - awardStarted

    -- Match the game's own success toss/end-session window before moving away.
    if confirmed or self:BackpackCount(self:RefreshData(true)) > beforeCount then
        self.State.ItemsConfirmedSinceSell = (tonumber(self.State.ItemsConfirmedSinceSell) or 0) + 1
        self.State.LastConfirmedInventoryUid = confirmedUid or "count+1"
        task.wait(0.58)
        self.State.CurrentDigRarity = nil
        return true
    end

    -- ItemsDug may increment earlier than Inventory. Give one final grace period
    -- if the server says the dig counted, but DO NOT immediately teleport onward.
    local after = self:RefreshData(true)
    if (tonumber(after and after.ItemsDug) or 0) > beforeDug then
        self:SetAction("Waiting for item award")
        local grace = os.clock() + 1.5
        local lastForcedGraceRefresh = -math.huge
        while self.Running and os.clock() < grace do
            local forceRefresh = os.clock() - lastForcedGraceRefresh >= 0.60
            if forceRefresh then
                self.State.DataAt = -math.huge
                lastForcedGraceRefresh = os.clock()
            end
            local data = self:RefreshData(forceRefresh)
            if self:BackpackCount(data) > beforeCount then
                self.State.ItemsConfirmedSinceSell = (tonumber(self.State.ItemsConfirmedSinceSell) or 0) + 1
                task.wait(0.58)
                self.State.CurrentDigRarity = nil
                return true
            end
            task.wait(0.10)
        end
    end

    self:SetError("Dig resolved but inventory award was not confirmed")
    self.State.CurrentDigRarity = nil
    return false
end

-- Cleaning ------------------------------------------------------------------

local FULL_CLEAN_MASK = string.rep("/", 64)

function Farm:DirtyInventory(data)
    data = data or self:RefreshData(false)
    local list = {}
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if type(entry) == "table"
            and type(entry.uid) == "string"
            and entry.dirty == true
            and entry.polisherSlot == nil
            and entry.pedestalSlot == nil then
            table.insert(list, entry)
        end
    end
    return list
end

function Farm:CleanItem(entry)
    if not self.Network.ItemsFunctions or not self.Network.ItemsEvents or type(entry) ~= "table" then return false end
    local uid = entry.uid
    if type(uid) ~= "string" then return false end
    self:SetAction("Cleaning " .. tostring(entry.id or uid))
    self.State.LastCleanAt = os.clock()

    local okBegin, result = promiseInvoke(self.Network.ItemsFunctions.beginCleaning, uid)
    if not okBegin or type(result) ~= "table" then return false end

    eventFire(self.Network.ItemsEvents.saveCleanProgress, uid, FULL_CLEAN_MASK)
    task.wait(math.clamp(tonumber(self.Config.CleanMaskDelay) or 0.12, 0.05, 0.5))
    eventFire(self.Network.ItemsEvents.finishCleaning, uid)

    local deadline = os.clock() + 1.25
    while self.Running and os.clock() < deadline do
        local data = self:RefreshData(true)
        local stillDirty = false
        for _, current in ipairs(self:InventoryEntries(data)) do
            if current.uid == uid then
                stillDirty = current.dirty == true
                break
            end
        end
        if not stillDirty then
            self.State.Cleaned = self.State.Cleaned + 1
            return true
        end
        task.wait(0.08)
    end
    return true
end

function Farm:CleanTick()
    if not self.Config.AutoClean then return false end
    local dirty = self:DirtyInventory(self:RefreshData(true))
    if #dirty == 0 then return false end
    if self.Config.CleanAllDirty then
        local did = false
        for _, entry in ipairs(dirty) do
            if not self.Running or not self.Config.Master or not self.Config.AutoClean then break end
            did = self:CleanItem(entry) or did
        end
        return did
    end
    return self:CleanItem(dirty[1])
end

-- Island-local shops ---------------------------------------------------------

local GEAR_FOLDER_BY_CATEGORY = {
    shovel = "BuyShovels",
    detector = "BuyDetectors",
    spray = "Sprays",
}

local function firstBasePart(container)
    if not container then return nil end
    if container:IsA("BasePart") then return container end
    if container:IsA("Model") and container.PrimaryPart then return container.PrimaryPart end
    return container:FindFirstChildWhichIsA("BasePart", true)
end

function Farm:FindStarterSellerRoot()
    -- The game's own SellerNpcController registers Buyer Bob specifically at:
    -- starter island -> NPCs -> Sell -> SellerNPC -> HumanoidRootPart.
    -- Do not assume later islands have independent sellers.
    local starter = self:IslandRoot("starterIsland")
    if starter then
        local npcs = starter:FindFirstChild("NPCs")
        local sellFolder = npcs and npcs:FindFirstChild("Sell")
        local seller = sellFolder and sellFolder:FindFirstChild("SellerNPC")
        local root = seller and seller:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then return root end
        local part = firstBasePart(seller)
        if part then return part end
    end

    -- Robust fallback for maps whose starter-island root model was renamed or
    -- where IslandRoot has not cached yet. Prefer a SellerNPC beneath a Sell
    -- container, matching the native controller hierarchy.
    local looseFallback = nil
    for _, obj in ipairs(S.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "SellerNPC" then
            local root = obj:FindFirstChild("HumanoidRootPart")
            if not (root and root:IsA("BasePart")) then
                root = firstBasePart(obj)
            end
            if root then
                looseFallback = looseFallback or root
                local parent = obj.Parent
                local grand = parent and parent.Parent
                if (parent and parent.Name == "Sell")
                    or (grand and grand.Name == "NPCs") then
                    return root
                end
            end
        end
    end
    return looseFallback
end

function Farm:WaitForIsland(islandId, seconds)
    local deadline = os.clock() + math.max(0.25, tonumber(seconds) or 2.0)
    while self.Running and os.clock() < deadline do
        self.State.DataAt = -math.huge
        local data = self:RefreshData(true)
        if data and data.CurrentIsland == islandId then return true end
        task.wait(0.08)
    end
    return self:CurrentIsland() == islandId
end

function Farm:TravelToShopIsland(islandId)
    if self:RecoveryLocked() then return false end
    if self:CurrentIsland() == islandId then return true end
    if not self.Network.TravelFunctions then return false end
    self:SetAction("Traveling to " .. tostring(islandId) .. " shop")
    local ok, result = promiseInvoke(self.Network.TravelFunctions.travel, islandId)
    if not ok or result ~= "ok" then return false end
    self.State.BuriedNodes = {}
    self.State.IslandRootCache = {}
    self:WaitForIsland(islandId, 2.0)
    task.wait(0.12)
    return self:CurrentIsland() == islandId
end

function Farm:PrepareForSelling()
    local origin = self:CurrentIsland()
    self.State.LastSellOriginIsland = origin

    -- Buyer Bob is the native inventory seller. Travel through the game's own
    -- island network first so server-side island/proximity checks agree with the
    -- physical seller we move beside.
    if origin ~= "starterIsland" then
        if not self:TravelToShopIsland("starterIsland") then
            self:SetError("Could not travel to Buyer Bob")
            return nil, origin
        end
    end

    local seller = self:FindStarterSellerRoot()
    if not seller then
        self:SetError("Buyer Bob seller root not found")
        return nil, origin
    end

    self:SetAction("Using Buyer Bob sell shop")
    if not self:MoveTo(seller.CFrame * CFrame.new(0, 0, -4.5)) then
        self:SetError("Could not move to Buyer Bob")
        return nil, origin
    end
    self.State.LastSellerShopIsland = "starterIsland"
    task.wait(0.12)
    return seller, origin
end

function Farm:RestoreFarmIslandAfterSell(origin)
    if not self.Config.ReturnToFarmIslandAfterSell then return true end
    if not origin or origin == "starterIsland" then
        self.State.LastSellReturnIsland = "starterIsland"
        return true
    end

    local data = self:RefreshData(true)
    if not self:IsIslandUnlocked(origin, data) then return false end
    if not self:TravelToShopIsland(origin) then
        self:SetError("Sold, but could not return to " .. tostring(origin))
        return false
    end

    self.State.LastSellReturnIsland = origin
    self.State.LastIsland = origin
    self.State.BuriedNodes = {}
    self.State.IslandRootCache = {}
    self:MoveToIslandDigZone(origin)

    -- Rebuild detector state after the temporary seller trip so buried-node
    -- results belong to the island we actually resumed farming.
    if self.Network.DetectorEvents and self.Network.DetectorEvents.SetDetectorHeld then
        eventFire(self.Network.DetectorEvents.SetDetectorHeld, false)
        task.wait(0.05)
        eventFire(self.Network.DetectorEvents.SetDetectorHeld, true)
    end
    self.State.LastSearchIsland = origin
    task.wait(0.08)
    return true
end

local GEAR_NPC_NAMES = {
    starterIsland = "Digger Dave",
    island2 = "Scurvy Sam",
    island3 = "Bandage Bart",
    island4 = "Frostbite Finn",
    island5 = "Ember Ike",
    island6 = "Pearly Pete",
}

function Farm:GearShopFolder(islandId)
    self.State.GearShopCache = self.State.GearShopCache or {}
    local cached = self.State.GearShopCache[islandId]
    if cached and cached.Parent then return cached end

    local expectedNpc = GEAR_NPC_NAMES[islandId]
    local root = self:IslandRoot(islandId)
    local zone = self:DigZoneForIsland(islandId)
    local zonePos = zone and zone.Position or nil

    local function looksLikeGearShop(obj)
        if not (obj and obj.Parent and (obj:IsA("Folder") or obj:IsA("Model"))) then return false, 0 end
        local score = 0
        if obj.Name == "Gear" then score = score + 4 end
        if obj:FindFirstChild("BuyShovels") then score = score + 4 end
        if obj:FindFirstChild("BuyDetectors") then score = score + 4 end
        if obj:FindFirstChild("Sprays") then score = score + 3 end
        if obj:FindFirstChild("GearNPC") then score = score + 2 end
        if expectedNpc and obj:FindFirstChild(expectedNpc, true) then score = score + 4 end
        if obj.Parent and obj.Parent.Name == "NPCs" then score = score + 2 end
        return score >= 6, score
    end

    local best, bestScore = nil, -math.huge
    local function consider(obj, bonus)
        local ok, score = looksLikeGearShop(obj)
        if not ok then return end
        score = score + (tonumber(bonus) or 0)
        if root and obj:IsDescendantOf(root) then
            score = score + 3
        end
        local part = firstBasePart(obj)
        if zonePos and part then
            local dist = (part.Position - zonePos).Magnitude
            score = score - math.min(dist / 500, 6)
        end
        if score > bestScore then
            best, bestScore = obj, score
        end
    end

    -- Preferred native path when the island root is available.
    if root then
        local npcs = root:FindFirstChild("NPCs")
        local direct = npcs and npcs:FindFirstChild("Gear")
        consider(direct, 10)
        for _, obj in ipairs(root:GetDescendants()) do
            consider(obj, 0)
        end
    end

    -- Strong fallback: find the expected island gear NPC anywhere in Workspace and
    -- climb to its containing gear stall. This handles islands whose root/config
    -- name does not match the replicated hierarchy exactly.
    if expectedNpc then
        for _, obj in ipairs(S.Workspace:GetDescendants()) do
            if obj.Name == expectedNpc then
                local cursor = obj.Parent
                local depth = 0
                while cursor and cursor ~= S.Workspace and depth < 8 do
                    consider(cursor, 12 - depth)
                    cursor = cursor.Parent
                    depth = depth + 1
                end
            end
        end
    end

    -- Last resort: global scan for any gear-like stall. The expected NPC and the
    -- island dig-zone distance will strongly bias the correct island's shop.
    if not best then
        for _, obj in ipairs(S.Workspace:GetDescendants()) do
            consider(obj, 0)
        end
    end

    if best then
        self.State.GearShopCache[islandId] = best
    end
    return best
end

function Farm:GearRackModel(category, gearId, islandId)
    local gear = self:GearShopFolder(islandId)
    if not gear then return nil end
    local folderName = GEAR_FOLDER_BY_CATEGORY[category]
    local container = folderName and gear:FindFirstChild(folderName)
    if not container then return nil end

    local cfgs = category == "shovel" and self.Constants.Shovels
        or category == "detector" and self.Constants.Detectors
        or self.Constants.Sprays
    local cfg = cfgs and cfgs[gearId]
    local displayName = type(cfg) == "table" and cfg.displayName or nil
    if not displayName then return nil end

    local exact = container:FindFirstChild(displayName, true)
    if exact and exact:IsA("Model") then return exact end
    -- GearShopController only registers models whose model name equals displayName.
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == displayName then return obj end
    end
    return nil
end

function Farm:ResolveGearIsland(data)
    data = data or self:RefreshData(true)
    local function usable(id)
        return type(id) == "string" and self:IsIslandUnlocked(id, data)
    end

    local current = type(data) == "table" and data.CurrentIsland or nil
    if usable(current) then
        return current
    end

    -- Fallback to the island whose search state is active. This is mainly for the
    -- small replication gap immediately after returning from Buyer Bob. Never
    -- fall back to starterIsland merely because that was the last seller route.
    local search = self.State.LastSearchIsland
    if usable(search) and self:GearShopFolder(search) then
        return search
    end

    -- Final fallback: choose the highest unlocked island that actually has a
    -- physical gear shop present. This prevents gear routing from collapsing to
    -- starterIsland when the current island value is briefly stale.
    local best = "starterIsland"
    for _, id in ipairs(self.Constants.IslandOrder or {"starterIsland"}) do
        if usable(id) and self:GearShopFolder(id) then
            best = id
        end
    end
    return best
end

function Farm:GearCandidatesOnIsland(category, configs, owned, data, islandId)
    local gear = self:GearShopFolder(islandId)
    if not gear then return {} end
    local folderName = GEAR_FOLDER_BY_CATEGORY[category]
    local container = folderName and gear:FindFirstChild(folderName)
    if not container then return {} end

    -- Build the candidate list from the models physically present in THIS
    -- island's rack. This is more reliable than cfg.islandId because several
    -- gear config entries do not expose a consistent island field.
    local byDisplay = {}
    for id, cfg in pairs(type(configs) == "table" and configs or {}) do
        if type(id) == "string" and type(cfg) == "table" and type(cfg.displayName) == "string" then
            byDisplay[cfg.displayName] = {id = id, cfg = cfg}
        end
    end

    local seen = {}
    local list = {}
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("Model") then
            local mapped = byDisplay[obj.Name]
            if mapped and not seen[mapped.id] and not arrayHas(owned, mapped.id) then
                local cost = tonumber(mapped.cfg.cost)
                if cost and cost > 0 then
                    seen[mapped.id] = true
                    table.insert(list, {
                        id = mapped.id,
                        cfg = mapped.cfg,
                        cost = cost,
                        metric = (category == "detector" and ((tonumber(mapped.cfg.rarityBias) or 0) * 1000000 + (tonumber(mapped.cfg.luck) or 0)))
                            or (category == "shovel" and ((tonumber(mapped.cfg.power) or 0) * 1000000 + (tonumber(mapped.cfg.walkSpeedPercent) or 0)))
                            or (category == "spray" and ((tonumber(mapped.cfg.dissolveRate) or 0) * 1000000 + (tonumber(mapped.cfg.rangeRating) or 0)))
                            or cost,
                    })
                end
            end
        end
    end

    table.sort(list, function(a, b)
        if a.metric == b.metric then return a.cost < b.cost end
        return a.metric > b.metric
    end)
    return list
end

function Farm:GearNpcRoot(islandId)
    local gear = self:GearShopFolder(islandId)
    local npc = gear and gear:FindFirstChild("GearNPC")
    local rootIsland = self:IslandRoot(islandId)
    if not npc and rootIsland then
        local expected = GEAR_NPC_NAMES[islandId]
        if expected then
            npc = rootIsland:FindFirstChild(expected, true)
        end
    end
    if not npc then return nil end
    local root = npc:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return firstBasePart(npc)
end

function Farm:FindGearShopPoint(category, gearId, islandId)
    local rack = self:GearRackModel(category, gearId, islandId)
    local rackPart = firstBasePart(rack)
    if rackPart then return rackPart end
    -- Only fall back to that island's actual GearNPC. Never wander to a loose
    -- similarly-named model on another island.
    return self:GearNpcRoot(islandId)
end

function Farm:FindGearRackPrompt(category, gearId, islandId, waitSeconds)
    local rack = self:GearRackModel(category, gearId, islandId)
    if not rack then return nil end
    local deadline = os.clock() + math.max(0, tonumber(waitSeconds) or 0)
    repeat
        local prompt = rack:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then return prompt end
        if os.clock() >= deadline then break end
        task.wait(0.04)
    until not self.Running
    return nil
end

function Farm:GearBuyFrame(waitSeconds)
    local deadline = os.clock() + math.max(0, tonumber(waitSeconds) or 0)
    repeat
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local frame = main and main:FindFirstChild("BuyFrame")
        if frame and frame:IsA("GuiObject") and frame.Visible then
            return frame
        end
        if os.clock() >= deadline then break end
        task.wait(0.035)
    until not self.Running
    return nil
end

function Farm:TriggerGearRack(category, gearId, islandId)
    if self:RecoveryLocked() then return false end
    local prompt = self:FindGearRackPrompt(category, gearId, islandId, 1.25)
    if not prompt then return false end

    -- GearShopController creates a CustomPrompt with a native 0.3 second hold.
    -- Different executors implement fireproximityprompt differently, so try the
    -- normal trigger first and then Roblox's own hold begin/end path.
    if type(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt) end)
        if self:GearBuyFrame(0.30) then return true end

        pcall(function() fireproximityprompt(prompt, math.max(0.35, tonumber(prompt.HoldDuration) or 0.30)) end)
        if self:GearBuyFrame(0.35) then return true end
    end

    local held = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(0.36, (tonumber(prompt.HoldDuration) or 0.30) + 0.06))
        prompt:InputHoldEnd()
    end)
    if held and self:GearBuyFrame(0.45) then return true end

    return false
end

function Farm:HideGearBuyFrame(frame)
    frame = frame or self:GearBuyFrame(0)
    if not frame then return false end

    pcall(function() frame.Visible = false end)
    pcall(function()
        if frame:FindFirstChild("Background") then
            frame.Background.Visible = false
        end
    end)
    pcall(function()
        if frame:FindFirstChild("Dim") then
            frame.Dim.Visible = false
        end
    end)
    pcall(function()
        if frame:FindFirstChild("Shadow") then
            frame.Shadow.Visible = false
        end
    end)
    pcall(function() frame.Position = UDim2.new(2, 0, 2, 0) end)
    return true
end

function Farm:ConfirmGearBuyUi(waitSeconds)
    local frame = self:GearBuyFrame(waitSeconds or 0.85)
    if not frame then return false end
    local yes = frame:FindFirstChild("Yes", true)
    if not (yes and yes:IsA("GuiButton")) then
        self:HideGearBuyFrame(frame)
        return false
    end

    local accepted = false
    if type(firesignal) == "function" then
        accepted = pcall(function() firesignal(yes.Activated) end)
    end
    if not accepted then
        accepted = pcall(function() yes:Activate() end)
    end

    -- Instantly suppress the purchase popup for automated buys so it does not
    -- stay on screen while the farm continues.
    self:HideGearBuyFrame(frame)

    -- Some clients redraw the BuyFrame briefly from the shop controller callback,
    -- so keep it hidden for a short cleanup window.
    local deadline = os.clock() + 0.40
    while self.Running and os.clock() < deadline do
        local refresh = self:GearBuyFrame(0)
        if not refresh then break end
        self:HideGearBuyFrame(refresh)
        task.wait(0.03)
    end

    return accepted
end

function Farm:MoveToCurrentIslandShop(category, gearId)
    if not self.Config.UseCurrentIslandShops then return true end
    if self:RecoveryLocked() then return false end
    local data = self:RefreshData(true)
    local islandId = self:ResolveGearIsland(data)
    local part = self:FindGearShopPoint(category, gearId, islandId)
    if not part then
        self:SetError("Missing " .. tostring(islandId) .. " " .. tostring(category) .. " rack")
        return false
    end
    local npcName = GEAR_NPC_NAMES[islandId] or tostring(islandId)
    self:SetAction("Using " .. npcName .. " " .. tostring(category) .. " racks")
    -- Stand close enough for the game's 0.3s custom gear prompt to be valid.
    local moved = self:MoveTo(part.CFrame * CFrame.new(0, 0, -2.6))
    if moved then
        self.State.LastShopIsland = islandId
        self.State.LastGearShopIsland = islandId
        self.State.LastGearNpc = npcName
        task.wait(0.12)
    end
    return moved
end

-- Selling -------------------------------------------------------------------

function Farm:SellableCount(data)
    local count = 0
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if entry.pedestalSlot == nil and entry.polisherSlot == nil and entry.favorited ~= true then
            count = count + 1
        end
    end
    self.State.LastSellableCount = count
    return count
end

function Farm:FindSellerRoot()
    return self:FindStarterSellerRoot()
end

function Farm:MoveToSeller()
    local seller, origin = self:PrepareForSelling()
    return seller ~= nil, origin
end

function Farm:FindInventoryTool(uid)
    if type(uid) ~= "string" then return nil end
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") and obj:GetAttribute("inventoryId") == uid then
                    return obj
                end
            end
        end
    end
    return nil
end

function Farm:UnequipInventoryTools()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then pcall(function() humanoid:UnequipTools() end) end
    task.wait(0.12)
end

function Farm:TriggerSellerPrompt(sellerRoot)
    if not sellerRoot then return false end
    local prompt = sellerRoot:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt and sellerRoot.Parent then
        prompt = sellerRoot.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    if not prompt then return false end
    if type(fireproximityprompt) == "function" then
        return pcall(function() fireproximityprompt(prompt, 0) end)
    end
    return false
end

function Farm:SellLooseItemsIndividually(data)
    if not self.Network.SellFunctions or not self.Network.SellFunctions.sellHeldItem then return false, 0 end
    data = data or self:RefreshData(true)
    local entries = {}
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if type(entry.uid) == "string"
            and entry.pedestalSlot == nil
            and entry.polisherSlot == nil
            and entry.favorited ~= true then
            table.insert(entries, entry)
        end
    end
    if #entries == 0 then return false, 0 end

    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local total = 0
    local soldAny = false
    for _, entry in ipairs(entries) do
        if self:RecoveryLocked() then break end
        local tool = self:FindInventoryTool(entry.uid)
        if tool and humanoid then
            pcall(function()
                if tool.Parent ~= LocalPlayer.Character then humanoid:EquipTool(tool) end
            end)
            task.wait(0.10)
            local ok, amount = promiseInvoke(self.Network.SellFunctions.sellHeldItem)
            if ok and tonumber(amount) then
                total = total + tonumber(amount)
                soldAny = true
                task.wait(0.08)
            end
        end
    end
    self:UnequipInventoryTools()
    return soldAny, total
end

function Farm:SellTick(force)
    if not self.Config.AutoSell or not self.Network.SellFunctions then return false end
    if self:RecoveryLocked() then return false end

    self.State.DataAt = -math.huge
    local data = self:RefreshData(true)
    local sellable = self:SellableCount(data)
    if sellable == 0 then return false end

    local threshold = math.max(1, math.floor(tonumber(self.Config.SellAfterDigs) or 3))
    local confirmedSinceSell = math.max(0, math.floor(tonumber(self.State.ItemsConfirmedSinceSell) or 0))
    local backpackFull = self:BackpackFull(data)
    if not force and not backpackFull and sellable < threshold and confirmedSinceSell < threshold then
        return false
    end

    -- Do not intentionally sell dirty loot at reduced value while auto-clean is active.
    if self.Config.AutoClean and #self:DirtyInventory(data) > 0 then return false end

    self:SetAction(string.format("Selling %d item%s", sellable, sellable == 1 and "" or "s"))
    self.State.LastSellAt = os.clock()
    local beforeGold = tonumber(data and data.Gold) or 0
    local beforeCount = sellable

    local seller, originIsland = self:PrepareForSelling()
    if not seller then
        self:RestoreFarmIslandAfterSell(originIsland)
        return false
    end

    -- Give the server enough time to observe the island/position change. The
    -- native seller is a 10-stud ProximityPrompt, so stand well inside that range.
    self:MoveTo(seller.CFrame * CFrame.new(0, 0, -3.25))
    task.wait(0.35)
    self:TriggerSellerPrompt(seller)
    task.wait(0.15)
    self:UnequipInventoryTools()

    local ok, amount = promiseInvoke(self.Network.SellFunctions.sellInventory)
    if not ok or amount == nil then
        -- Re-read the authoritative data before deciding the bulk sale failed.
        self.State.DataAt = -math.huge
        local refreshed = self:RefreshData(true)
        local stillSellable = self:SellableCount(refreshed)
        if stillSellable > 0 then
            local soldIndividually, individualAmount = self:SellLooseItemsIndividually(refreshed)
            if soldIndividually then
                ok, amount = true, individualAmount
            else
                -- One final bulk attempt after unequipping / prompt activation.
                task.wait(0.20)
                ok, amount = promiseInvoke(self.Network.SellFunctions.sellInventory)
            end
        else
            ok, amount = true, 0
        end
    end

    if not ok or amount == nil then
        self:SetError("Buyer Bob bulk + held-item sell both rejected")
        self:RestoreFarmIslandAfterSell(originIsland)
        return false
    end

    -- Do not resume digging until the data model confirms items were removed.
    local deadline = os.clock() + 3.0
    local afterCount = beforeCount
    local afterGold = beforeGold
    local lastForcedSellRefresh = -math.huge
    while self.Running and os.clock() < deadline do
        if self:RecoveryLocked() then break end
        local forceRefresh = os.clock() - lastForcedSellRefresh >= 0.45
        if forceRefresh then
            self.State.DataAt = -math.huge
            lastForcedSellRefresh = os.clock()
        end
        local after = self:RefreshData(forceRefresh)
        afterCount = self:SellableCount(after)
        afterGold = tonumber(after and after.Gold) or beforeGold
        if afterCount < beforeCount or afterGold > beforeGold then break end
        task.wait(0.08)
    end

    if afterCount >= beforeCount and afterGold <= beforeGold and tonumber(amount) ~= 0 then
        self:SetError("Sell returned but inventory did not update")
        self:RestoreFarmIslandAfterSell(originIsland)
        return false
    end

    local soldCount = math.max(0, beforeCount - afterCount)
    if soldCount > 0 or afterGold > beforeGold or tonumber(amount) and tonumber(amount) > 0 then
        self.State.Sold = self.State.Sold + 1
        self.State.LastSell = tonumber(amount) or math.max(0, afterGold - beforeGold)
        self.State.GoldFromSales = self.State.GoldFromSales + (tonumber(self.State.LastSell) or 0)
        self.State.ItemsConfirmedSinceSell = math.max(0, (tonumber(self.State.ItemsConfirmedSinceSell) or 0) - soldCount)
        if afterCount == 0 then self.State.ItemsConfirmedSinceSell = 0 end
        self:RefreshData(true)
        self:RestoreFarmIslandAfterSell(originIsland)
        return true
    end

    self:RestoreFarmIslandAfterSell(originIsland)
    return false
end

-- Gear ----------------------------------------------------------------------

local function gearMetric(category, cfg)
    if type(cfg) ~= "table" then return -math.huge end
    if category == "detector" then
        return (tonumber(cfg.rarityBias) or 0) * 1000000 + (tonumber(cfg.luck) or 0)
    elseif category == "shovel" then
        return (tonumber(cfg.power) or 0) * 1000000 + (tonumber(cfg.walkSpeedPercent) or 0)
    elseif category == "spray" then
        return (tonumber(cfg.dissolveRate) or 0) * 1000000 + (tonumber(cfg.rangeRating) or 0)
    end
    return tonumber(cfg.cost) or 0
end

local function sortedGearCandidates(category, configs, owned, data, farm)
    local list = {}
    for id, cfg in pairs(type(configs) == "table" and configs or {}) do
        local cost = type(cfg) == "table" and tonumber(cfg.cost) or nil
        if type(id) == "string" and cost and cost > 0 then
            local currentIsland = data and data.CurrentIsland or farm:CurrentIsland()
            local islandOk = cfg.islandId == nil or cfg.islandId == currentIsland
            if islandOk and not arrayHas(owned, id) then
                table.insert(list, {id = id, cfg = cfg, cost = cost, metric = gearMetric(category, cfg)})
            end
        end
    end
    table.sort(list, function(a, b)
        if a.metric == b.metric then return a.cost < b.cost end
        return a.metric > b.metric
    end)
    return list
end

local function bestOwned(configs, owned, category)
    local best, bestMetric = nil, -math.huge
    for _, id in ipairs(type(owned) == "table" and owned or {}) do
        local cfg = configs[id]
        local metric = gearMetric(category, cfg)
        if metric > bestMetric then best, bestMetric = id, metric end
    end
    return best
end

function Farm:BuyBestGearCategory(category, configs, ownedKey, equippedKey, force)
    if not self.Network.ShopFunctions then return false end
    local data = self:RefreshData(true)
    if not data then return false end
    local owned = data[ownedKey] or {}
    local cash = tonumber(data.Gold) or 0
    local islandId = self:ResolveGearIsland(data)

    -- Record the gear context separately from the seller route. The old status
    -- was misleading because Buyer Bob set LastShopIsland to starterIsland.
    if self:GearShopFolder(islandId) then
        self.State.LastShopIsland = islandId
        self.State.LastGearShopIsland = islandId
    end

    -- Only consider gear with a real rack model on the resolved farm island.
    -- This makes an island2 farm impossible to accidentally purchase from the
    -- starter gear catalogue, even if config metadata is missing/ambiguous.
    local candidates = self:GearCandidatesOnIsland(category, configs, owned, data, islandId)

    -- Only purchase a real upgrade. Do not waste gold filling in weaker gear
    -- after a stronger item is already owned.
    local ownedBestMetric = -math.huge
    for _, ownedId in ipairs(type(owned) == "table" and owned or {}) do
        ownedBestMetric = math.max(ownedBestMetric, gearMetric(category, configs and configs[ownedId]))
    end

    for _, candidate in ipairs(candidates) do
        if candidate.metric > ownedBestMetric and candidate.cost <= cash then
            local shopReady = true
            if self.Config.UseCurrentIslandShops then
                if self:CurrentIsland() ~= islandId then
                    shopReady = self:TravelToShopIsland(islandId)
                end
                if shopReady then
                    shopReady = self:MoveToCurrentIslandShop(category, candidate.id)
                end
            end
            if shopReady then
                self:SetAction("Buying " .. tostring(candidate.cfg.displayName or candidate.id))
                local beforeOwned = arrayHas(owned, candidate.id)
                local bought = false

                -- First use the exact rack prompt, matching GearShopController.
                if self.Config.UseCurrentIslandShops and self:TriggerGearRack(category, candidate.id, islandId) then
                    self:ConfirmGearBuyUi(0.95)
                    local deadline = os.clock() + 1.55
                    while self.Running and os.clock() < deadline do
                        local fresh = self:RefreshData(true) or data
                        if arrayHas(fresh[ownedKey] or {}, candidate.id) then
                            data, owned, bought = fresh, fresh[ownedKey] or {}, true
                            break
                        end
                        task.wait(0.07)
                    end
                end

                -- Native network fallback. Do not trust only the returned boolean:
                -- the live client closes the BuyFrame from the callback, while data
                -- replication is the authoritative proof that the purchase happened.
                if not bought and not beforeOwned then
                    promiseInvoke(self.Network.ShopFunctions.buyGear, category, candidate.id)
                    local deadline = os.clock() + 1.65
                    while self.Running and os.clock() < deadline do
                        local fresh = self:RefreshData(true) or data
                        if arrayHas(fresh[ownedKey] or {}, candidate.id) then
                            data, owned, bought = fresh, fresh[ownedKey] or {}, true
                            break
                        end
                        task.wait(0.07)
                    end
                end

                if bought then
                    self.State.GearBought = self.State.GearBought + 1
                    self.State.LastGear = tostring(candidate.cfg.displayName or candidate.id)
                    self.State.LastSmartSpend = self.State.LastGear
                    break
                end
            end
        end
    end

    if self.Config.AutoEquipBestGear then
        data = self:RefreshData(true) or data
        local target = bestOwned(configs, data[ownedKey] or {}, category)
        if target and data[equippedKey] ~= target then
            self:SetAction("Equipping " .. tostring(target))
            local targetCfg = configs and configs[target]
            local targetIsland = type(targetCfg) == "table" and targetCfg.islandId or nil
            local equipped = false

            -- If the best owned item belongs to the island we are physically on,
            -- use its rack prompt (owned prompts become Equip in GearShopController).
            if self.Config.UseCurrentIslandShops and targetIsland == self:ResolveGearIsland(data) then
                if self:MoveToCurrentIslandShop(category, target) and self:TriggerGearRack(category, target, targetIsland) then
                    local deadline = os.clock() + 0.9
                    while self.Running and os.clock() < deadline do
                        local fresh = self:RefreshData(true) or data
                        if fresh[equippedKey] == target then
                            data, equipped = fresh, true
                            break
                        end
                        task.wait(0.07)
                    end
                end
            end

            if not equipped then
                local okRemote, remoteEquipped = promiseInvoke(self.Network.ShopFunctions.equipGear, category, target)
                equipped = okRemote and remoteEquipped == true
            end
            if equipped then
                self:RefreshData(true)
                return true
            end
        end
    end
    return false
end

function Farm:GearTick(force)
    if os.clock() - self.State.LastGearAt < (force and 0.03 or 0.12) then return false end
    self.State.LastGearAt = os.clock()
    local did = false
    -- Gear is immediate progression in v2.5. No category is blocked by reserves
    -- or next-island saving. Detector is checked first, then shovel, then spray.
    if self.Config.AutoBestDetector then
        did = self:BuyBestGearCategory("detector", self.Constants.Detectors, "OwnedDetectors", "EquippedDetector", force) or did
    end
    if self.Config.AutoBestShovel then
        did = self:BuyBestGearCategory("shovel", self.Constants.Shovels, "OwnedShovels", "EquippedShovel", force) or did
    end
    if self.Config.AutoBestSpray then
        did = self:BuyBestGearCategory("spray", self.Constants.Sprays, "OwnedSprays", "EquippedSpray", force) or did
    end
    return did
end

-- Islands -------------------------------------------------------------------

function Farm:HighestAffordableIsland(data)
    data = data or self:RefreshData(false)
    if not data then return nil end
    local gold = tonumber(data.Gold) or 0
    local reserve = gold * math.clamp((tonumber(self.Config.IslandReservePercent) or 0) / 100, 0, 0.95)
    local best = self.Constants.IslandOrder[1] or "starterIsland"
    local unlocked = data.UnlockedIslands or {}
    for index, id in ipairs(self.Constants.IslandOrder) do
        if arrayHas(unlocked, id) then
            best = id
        else
            -- Unlock progression sequentially. The server can reject skipping a
            -- prerequisite even when the player happens to hold enough gold.
            local previous = self.Constants.IslandOrder[index - 1]
            if index == 1 or previous == nil or arrayHas(unlocked, previous) then
                local cfg = self.Constants.Islands[id]
                local cost = cfg and tonumber(cfg.cost) or math.huge
                if cost <= gold - reserve then best = id end
            end
            break
        end
    end
    return best
end

function Farm:MoveToIslandDigZone(id)
    local zone = self:DigZoneForIsland(id)
    if not zone then return false end
    return self:MoveTo(zone.CFrame * CFrame.new(0, math.max(2.5, zone.Size.Y * 0.5 + 1.5), 0))
end

function Farm:IslandTick(force)
    if not self.Config.AutoHighestIsland or not self.Network.TravelFunctions then return false end
    if os.clock() - self.State.LastIslandAt < (force and 0.2 or 4.0) then return false end
    self.State.LastIslandAt = os.clock()
    local data = self:RefreshData(true)
    if not data then return false end
    local target = self:HighestAffordableIsland(data)
    if not target then return false end
    local current = data.CurrentIsland or "starterIsland"

    if target ~= current then
        self:SetAction("Traveling to " .. tostring(target))
        local wasUnlocked = self:IsIslandUnlocked(target, data)
        local ok, result = promiseInvoke(self.Network.TravelFunctions.travel, target)
        if ok and result == "ok" then
            if not wasUnlocked then self.State.IslandsUnlocked = self.State.IslandsUnlocked + 1 end
            self.State.LastIsland = target
            self.State.BuriedNodes = {}
            self.State.IslandRootCache = {}
            self:RefreshData(true)
            task.wait(0.15)
            self:MoveToIslandDigZone(target)
            -- Force the detector/search state to rebuild on the new island so
            -- stale nodes from the previous island can never win selection.
            if self.Network.DetectorEvents and self.Network.DetectorEvents.SetDetectorHeld then
                eventFire(self.Network.DetectorEvents.SetDetectorHeld, false)
                task.wait(0.05)
                eventFire(self.Network.DetectorEvents.SetDetectorHeld, true)
            end
            self.State.LastSearchIsland = target
            -- Immediately evaluate the gear sold on the island we just entered.
            self:GearTick(true)
            return true
        end
    elseif self.Config.AutoMoveToDigZone then
        local root = self:CharacterRoot()
        local zone = self:DigZoneForIsland(current)
        if root and zone then
            local p = zone.CFrame:PointToObjectSpace(root.Position)
            if math.abs(p.X) > zone.Size.X * 0.5 or math.abs(p.Z) > zone.Size.Z * 0.5 then
                return self:MoveToIslandDigZone(current)
            end
        end
    end
    return false
end

-- Rewards / quests -----------------------------------------------------------

function Farm:RewardTick(force)
    if os.clock() - self.State.LastRewardAt < (force and 0.2 or 8) then return false end
    self.State.LastRewardAt = os.clock()
    local did = false

    if self.Config.AutoRedeemCodes and self.Network.CodeFunctions
        and os.clock() - self.State.LastCodeAt >= 30 then
        self.State.LastCodeAt = os.clock()
        local data = self:RefreshData(false) or {}
        local redeemed = type(data.RedeemedCodes) == "table" and data.RedeemedCodes or {}
        for _, code in ipairs({"UPDATE4", "UPDATE3", "UPDATE2", "UPDATE1", "SECRET10"}) do
            local already = redeemed[code] == true or arrayHas(redeemed, code)
            if not already and not self.State.CodeTried[code] then
                self.State.CodeTried[code] = true
                local okCode, result = promiseInvoke(self.Network.CodeFunctions.redeemCode, code)
                if okCode and type(result) == "table" and result.status == "success" then
                    self.State.CodesClaimed = self.State.CodesClaimed + 1
                    did = true
                end
            end
        end
        if did then self:RefreshData(true) end
    end

    if self.Config.AutoOfflineEarnings and self.Network.OfflineFunctions then
        local okReq, info = promiseInvoke(self.Network.OfflineFunctions.requestOfflineEarnings)
        if okReq and type(info) == "table" and (tonumber(info.gold) or 0) > 0 then
            local okClaim, amount = promiseInvoke(self.Network.OfflineFunctions.claimOfflineEarnings)
            if okClaim and tonumber(amount) then did = true end
        end
    end

    if self.Config.AutoGroupReward and self.Network.GroupFunctions then
        local data = self:RefreshData(false)
        if data and data.GroupRewardClaimed ~= true then
            local ok, result = promiseInvoke(self.Network.GroupFunctions.claimGroupReward)
            if ok and result == "claimed" then did = true self:RefreshData(true) end
        end
    end

    if self.Config.AutoQuests and self.Network.QuestFunctions then
        local data = self:RefreshData(true)
        local quests = type(data and data.DailyQuests) == "table" and data.DailyQuests or {}
        local completeFn = self.Constants.IsQuestComplete
        for index, quest in ipairs(quests) do
            local complete = type(completeFn) == "function" and completeFn(quest) or false
            if complete and quest.claimed ~= true then
                local ok, claimed = promiseInvoke(self.Network.QuestFunctions.claimQuest, index - 1)
                if ok and claimed == true then
                    self.State.QuestsClaimed = self.State.QuestsClaimed + 1
                    did = true
                end
            end
        end
        if did then self:RefreshData(true) end
    end

    return did
end

-- Polishers / plot progression ---------------------------------------------

function Farm:AvailablePolisherSlots(data)
    local slots = {}
    local owned = math.clamp(math.floor(tonumber(data and data.OwnedPolishers) or 1), 1, self.Constants.GoldPolisherSlotCount)
    for slot = 1, owned do table.insert(slots, slot) end
    if arrayHas(data and data.UnlockedSections, "ExtraPolishers") then
        for slot = self.Constants.GoldPolisherSlotCount + 1, self.Constants.PolisherSlotCount do
            table.insert(slots, slot)
        end
    end
    return slots, owned
end

function Farm:PolisherTick(force)
    if not self.Config.AutoPolishers or not self.Network.PolisherFunctions then return false end
    if os.clock() - self.State.LastPolisherAt < (force and 0.2 or 4) then return false end
    self.State.LastPolisherAt = os.clock()
    local data = self:RefreshData(true)
    if not data or not arrayHas(data.UnlockedSections, "Polishing") then return false end
    local slots, owned = self:AvailablePolisherSlots(data)
    local did = false

    -- Collect finished jobs first.
    for _, slot in ipairs(slots) do
        local ok, collected = promiseInvoke(self.Network.PolisherFunctions.collectPolish, slot)
        if ok and collected == true then did = true end
    end
    if did then data = self:RefreshData(true) or data end

    -- While saving for the next island, collect completed jobs but do not lock
    -- more liquid inventory into long polish timers. The loose items can be sold
    -- immediately, and polishing resumes after the island purchase.
    if self.Config.SmartMoneyMode and not force and self:SavingForNextIsland(data) then
        if did then self:RefreshData(true) end
        return did
    end

    local occupied = {}
    for _, entry in ipairs(self:InventoryEntries(data)) do
        local slot = tonumber(entry.polisherSlot)
        if slot then occupied[math.floor(slot)] = true end
    end

    -- Rank clean loose items by value gain / real polish second. That is also
    -- proportional to the passive-income gain when the item reaches a pedestal.
    local jobs = {}
    local nextConditionFor = self.Constants.NextConditionFor
    local polishSecondsFor = self.Constants.PolishSecondsFor
    for _, entry in ipairs(self:InventoryEntries(data)) do
        if type(entry.uid) == "string"
            and entry.dirty ~= true
            and type(entry.condition) == "string"
            and entry.pedestalSlot == nil
            and entry.polisherSlot == nil
            and entry.favorited ~= true then
            local nextCondition = type(nextConditionFor) == "function" and nextConditionFor(entry.condition) or nil
            if nextCondition then
                local currentValue = self:ItemValue(entry)
                local nextValue = self:ItemValue(entry, nextCondition)
                local bestSeconds = math.huge
                for _, slot in ipairs(slots) do
                    if not occupied[slot] then
                        local level = 1
                        local levels = type(data.PolisherLevels) == "table" and data.PolisherLevels or {}
                        local raw = levels[tostring(slot)] or levels[slot]
                        level = math.max(1, math.floor(tonumber(raw) or 1))
                        if type(polishSecondsFor) == "function" then
                            local okSec, sec = pcall(polishSecondsFor, entry.id, entry.condition, level)
                            if okSec and tonumber(sec) then bestSeconds = math.min(bestSeconds, math.max(1, tonumber(sec))) end
                        end
                    end
                end
                if bestSeconds < math.huge and nextValue > currentValue then
                    table.insert(jobs, {
                        entry = entry,
                        currentValue = currentValue,
                        nextValue = nextValue,
                        gain = nextValue - currentValue,
                        score = (nextValue - currentValue) / bestSeconds,
                    })
                end
            end
        end
    end
    table.sort(jobs, function(a, b)
        if a.score == b.score then return a.nextValue > b.nextValue end
        return a.score > b.score
    end)

    local ji = 1
    for _, slot in ipairs(slots) do
        if not occupied[slot] then
            local job = jobs[ji]
            if not job then break end
            self:SetAction("Polishing best ROI item")
            local ok, result = promiseInvoke(self.Network.PolisherFunctions.startPolish, slot, job.entry.uid)
            if ok and result == "ok" then
                self.State.LastPolishScore = job.score
                occupied[slot] = true
                ji = ji + 1
                did = true
            end
        end
    end

    -- Gold polisher upgrades are useful, but never let them derail an imminent
    -- island unlock. Buy at most one economic upgrade per tick.
    if self.Config.AutoUpgradePolishers and not self:SavingForNextIsland(data) then
        local costFn = self.Constants.PolisherUpgradeCostFor
        for _, slot in ipairs(slots) do
            local levels = type(data.PolisherLevels) == "table" and data.PolisherLevels or {}
            local level = math.max(1, math.floor(tonumber(levels[tostring(slot)] or levels[slot]) or 1))
            local cost = nil
            if type(costFn) == "function" then
                local okCost, value = pcall(costFn, level)
                if okCost then cost = tonumber(value) end
            end
            local gold = tonumber(data.Gold) or 0
            if cost and cost > 0 and cost <= gold * 0.18 then
                local ok, result = promiseInvoke(self.Network.PolisherFunctions.upgradePolisher, slot)
                if ok and result == "ok" then
                    self.State.LastSmartSpend = "Polisher upgrade"
                    did = true
                    break
                end
            end
        end
    end

    if self.Config.AutoUnlockPolishers and owned < self.Constants.GoldPolisherSlotCount
        and not self:SavingForNextIsland(data) and #jobs > 0 then
        local nextSlot = owned + 1
        local cost = nil
        local costFn = self.Constants.PolisherUnlockCostFor
        if type(costFn) == "function" then
            local okCost, value = pcall(costFn, nextSlot)
            if okCost then cost = tonumber(value) end
        end
        local gold = tonumber(data.Gold) or 0
        if cost and cost > 0 and cost <= gold * 0.25 then
            local ok, result = promiseInvoke(self.Network.PolisherFunctions.unlockPolisher, nextSlot)
            if ok and result == "ok" then
                self.State.LastSmartSpend = "Polisher slot " .. tostring(nextSlot)
                did = true
            end
        end
    end

    if did then self:RefreshData(true) end
    return did
end

function Farm:PlotSectionTick(force)
    if not self.Config.AutoUnlockPlotSections or not self.Network.PlotSectionFunctions then return false end
    if self.Config.SmartMoneyMode and not force then
        return self:SmartPassiveExpansionTick(false)
    end
    local data = self:RefreshData(false)
    if not data then return false end
    local unlocked = data.UnlockedSections or {}
    for _, section in ipairs({"Polishing", "Floor2", "Floor3", "ExtraPolishers"}) do
        if not arrayHas(unlocked, section) then
            local ok, result = promiseInvoke(self.Network.PlotSectionFunctions.unlockSection, section)
            if ok and result == "ok" then
                self:RefreshData(true)
                return true
            end
            if result == "poor" then return false end
        end
    end
    return false
end

-- Scheduler -----------------------------------------------------------------

function Farm:Step()
    if not self.Running or not self.Config.Master or self.State.Busy then return end
    self.State.Busy = true
    local ok, err = pcall(function()
        self:RefreshData(false)

        if self:RecoveryLocked() then
            self:DismissRecoveryPrompt()
            return
        end

        -- Passive/cheap progression checks are deliberately throttled internally.
        self:RewardTick(false)

        -- Refresh threshold/capacity from the actual inventory before starting any
        -- movement to another dig. If selling is due, cleaning gets first chance
        -- and SellTick then verifies the inventory shrink before farming resumes.
        local inventoryData = self:RefreshData(false)
        local sellThreshold = math.max(1, math.floor(tonumber(self.Config.SellAfterDigs) or 3))
        local sellableNow = self:SellableCount(inventoryData)
        local saleDue = self.Config.AutoSell and (self:BackpackFull(inventoryData)
            or sellableNow >= sellThreshold
            or (tonumber(self.State.ItemsConfirmedSinceSell) or 0) >= sellThreshold)

        -- Never let dirty inventory pile up or get sold at dirty value.
        if self.Config.AutoClean and #self:DirtyInventory(inventoryData) > 0 then
            self:CleanTick()
            if self.Config.AutoSell then self:SellTick(false) end
            return
        end

        -- v2.5: current-island gear is the highest-priority money spend. If a
        -- stronger rack item is affordable, buy/equip it immediately. There is no
        -- gear reserve, no next-island saving veto, and no smart-money percentage cap.
        if self:GearTick(false) then return end

        -- Move the most valuable clean loose item onto an owned pedestal before
        -- polishers or selling can consume it. Displayed items are automatically
        -- excluded from both systems, so the strongest passive-income pieces stay put.
        if self.Config.AutoDisplayBest and self:DisplayTick(saleDue) then return end

        -- Only after displays are optimized should polishers consume excess clean
        -- inventory. Polisher-assigned items are excluded from bulk selling.
        self:PolisherTick(false)

        -- Sell exactly when the configured threshold (or backpack capacity) says
        -- it is due. The sale itself verifies the inventory shrink before return.
        if saleDue and self:SellTick(false) then return end

        if self:IslandTick(false) then return end
        if self:SmartPassiveExpansionTick(false) then return end

        -- Main activity.
        if self.Config.AutoDig then
            local won = self:DigOnce()
            if won then
                if self.Config.AutoClean then self:CleanTick() end
                if self.Config.AutoDisplayBest and self:DisplayTick(true) then return end
                if self.Config.AutoSell then self:SellTick(false) end
            end
        end
    end)
    if not ok then self:SetError(err) end
    self.State.Busy = false
end

-- Recovery safety ------------------------------------------------------------
-- Recovery helpers are defined earlier beside movement so every movement entry
-- point uses the same hard-lock implementation. Do not redefine them here.

-- Events --------------------------------------------------------------------


if Farm.Network.DetectorEvents and Farm.Network.DetectorEvents.BuriedNodes then
    local ok, conn = pcall(function()
        return Farm.Network.DetectorEvents.BuriedNodes:connect(function(nodes, removed)
            Farm:UpdateBuriedNodes(nodes, removed)
        end)
    end)
    if ok then track(conn) end
end

if Farm.Network.ItemsEvents and Farm.Network.ItemsEvents.recoveryOffered then
    local ok, recoveryConn = pcall(function()
        return Farm.Network.ItemsEvents.recoveryOffered:connect(function(kg, rarity, tier)
            local now = os.clock()
            Farm.State.RecoveryActive = true
            Farm.State.RecoverySeenThisOffer = false
            Farm.State.RecoveryAwaitPopupUntil = now + 1.35
            Farm.State.RecoveryHardLockUntil = now + 1.90
            Farm.State.RecoveryResumeAt = now + 2.20
            Farm.State.RecoverySafeLuckUntil = math.max(tonumber(Farm.State.RecoverySafeLuckUntil) or -math.huge, now + (tonumber(Farm.Config.RecoverySafeLuckSeconds) or 75))
            Farm.State.LastRecovery = string.format("%s %.1fKG (tier %s)", tostring(rarity), tonumber(kg) or 0, tostring(tier))
            local risky = Farm.State.CurrentDigRarity or rarity
            if Farm.Config.AvoidRecoveryLosses and type(risky) == "string" then
                Farm.State.RiskyRarityUntil[risky] = os.clock() + 90
            end
            Farm:SetError("Recovery offered: " .. Farm.State.LastRecovery .. " - temporarily avoiding similar buried nodes")
            -- RecoverController intentionally waits 0.5s before showing the frame.
            -- The independent watchdog below will dismiss it as soon as it is truly visible.
            task.defer(function()
                task.wait(0.54)
                if Farm.Running and Farm.Config.RecoveryAutoDecline ~= false then Farm:DismissRecoveryPrompt() end
            end)
        end)
    end)
    if ok then track(recoveryConn) end
end

if Farm.Network.ItemsEvents and Farm.Network.ItemsEvents.recoveryGranted then
    local ok, grantedConn = pcall(function()
        return Farm.Network.ItemsEvents.recoveryGranted:connect(function()
            local now = os.clock()
            Farm.State.RecoveryActive = false
            Farm.State.RecoveryAwaitPopupUntil = -math.huge
            Farm.State.RecoveryHardLockUntil = math.max(tonumber(Farm.State.RecoveryHardLockUntil) or -math.huge, now + 0.20)
            Farm.State.RecoveryResumeAt = math.max(tonumber(Farm.State.RecoveryResumeAt) or -math.huge, now + (tonumber(Farm.Config.RecoveryResumeDelay) or 0.70))
        end)
    end)
    if ok then track(grantedConn) end
end

if Farm.Network.ItemsEvents and Farm.Network.ItemsEvents.instantCleaned then
    local ok, conn = pcall(function()
        return Farm.Network.ItemsEvents.instantCleaned:connect(function()
            Farm.State.DataAt = -math.huge
        end)
    end)
    if ok then track(conn) end
end

if Farm.Network.DataEvents and Farm.Network.DataEvents.DataPartialUpdate then
    local ok, conn = pcall(function()
        return Farm.Network.DataEvents.DataPartialUpdate:connect(function(revision, _, partial)
            revision = tonumber(revision) or 0
            if revision <= (Farm.State.DataRevision or 0) then return end
            Farm.State.DataRevision = revision
            local utils = Farm.Constants.DataUtils
            if Farm.State.Data and utils and type(utils.validatePartialData) == "function"
                and type(utils.mergePartialUpdate) == "function"
                and utils.validatePartialData(partial) then
                utils.mergePartialUpdate(Farm.State.Data, partial)
                Farm.State.DataAt = os.clock()
            else
                Farm.State.DataAt = -math.huge
            end
        end)
    end)
    if ok then track(conn) end
end

-- Anti AFK ------------------------------------------------------------------

if Farm.Config.AntiAFK then
    track(LocalPlayer.Idled:Connect(function()
        if not Farm.Running or not Farm.Config.AntiAFK then return end
        pcall(function()
            S.VirtualUser:CaptureController()
            S.VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

function Farm:Unload()
    if not self.Running then return end
    self.Running = false
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    table.clear(self.Connections)
    pcall(function()
        if self.Network.DetectorEvents and self.Network.DetectorEvents.SetDetectorHeld then
            eventFire(self.Network.DetectorEvents.SetDetectorHeld, false)
        end
    end)
    if Window and Window.Destroy then pcall(function() Window:Destroy() end) end
    if FallbackGui then pcall(function() FallbackGui:Destroy() end) end
    if GENV[SCRIPT_KEY] == self then GENV[SCRIPT_KEY] = nil end
end

-- Recovery watchdog ---------------------------------------------------------
-- Runs independently of State.Busy. A recovery offer can arrive while DigOnce
-- is waiting on ResolveDig or an inventory award, so the main scheduler alone
-- cannot be the safety mechanism.
task.spawn(function()
    local lastVisible = -math.huge
    while Farm.Running do
        local visible = Farm:RecoveryPromptVisible()
        if visible then
            lastVisible = os.clock()
            Farm.State.RecoveryWatchdogTicks = (tonumber(Farm.State.RecoveryWatchdogTicks) or 0) + 1
            Farm:MarkRecoveryFromGui(Farm.State.LastRecovery ~= "None" and Farm.State.LastRecovery or "Recovery popup")
            if Farm.Config.RecoveryAutoDecline ~= false then Farm:DismissRecoveryPrompt() end
        elseif Farm.State.RecoveryActive then
            local now = os.clock()
            -- Keep the lock through RecoverController's 0.5s delayed show. Only
            -- clear after the offer window elapsed and the popup has remained gone.
            if now >= (tonumber(Farm.State.RecoveryAwaitPopupUntil) or -math.huge)
                and now - lastVisible >= 0.35 then
                Farm.State.RecoveryActive = false
                Farm.State.RecoveryResumeAt = math.max(tonumber(Farm.State.RecoveryResumeAt) or -math.huge, now + (tonumber(Farm.Config.RecoveryResumeDelay) or 0.70))
            end
        end
        task.wait(0.035)
    end
end)

-- Main scheduler -------------------------------------------------------------

task.spawn(function()
    local missing = Farm:MissingCore()
    if #missing > 0 then
        Farm:SetError("Missing network: " .. table.concat(missing, ", "))
        Farm:SetPhase("Network setup incomplete")
    else
        Farm:SetPhase("Ready")
    end
    Farm:RefreshData(true)
    Farm:PrepareDetector()
    while Farm.Running do
        if Farm.Config.Master then Farm:Step() end
        task.wait(0.12)
    end
end)


return Farm
