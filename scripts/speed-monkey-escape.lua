--[[
    RAINZXDEV | +1 Speed Monkey Escape Autofarm
    PlaceId: 114697347887839

    Built from the supplied RBXL/RBXM client + shared module paths.

    IMPORTANT AUDIT NOTES
    ---------------------
    v1.1 WIN PAYOUT FIX:
      - ReturnButton client Touched only animates the pad / prompts x2 Wins.
      - Actual Wins are server-side Touched logic.
      - Real replicated off-pad -> through-pad -> off-pad movement is required.
      - Every payout is verified by Data.Wins increasing.
      - If rejected, Checkpoints 1..Order-1 are primed before retrying.

    Money:
      - CollectionService tag "ReturnButton" is the game's stage Wins button.
      - ReturnButton parent/model exposes World, Order and DoubleWins attributes.
      - Reward values come from ReplicatedStorage.Config.Main.StageWins.
      - TeleportStage is NOT used: the real UI checks a Wins price before calling it.
      - Highest unlocked world + highest valid ReturnButton is the fast Wins route.

    Speed / progression:
      - Treadmills are touch/zone based; there is no legitimate client "give speed" remote.
      - Known multipliers:
          Basic 1x
          Playtime Reward 1.5x
          Golden 3x
          Diamond 9x
          Galaxy 25x
          Void 100x
          Celestial 1000x
          Sunken 2x
          Quantum Event 10x
      - Best owned Trail increases Speed.
      - Best owned Aura increases Wins.
      - EquipBestCharms accepts "Speed" or "Wins".
      - Rebirth requirement is Main.RebirthLevels[Rebirths + 1].
      - Rebirth permanent Speed multiplier: +0.5x each rebirth.
      - Worlds unlock at 8 / 16 / 24 / 32 rebirths.

    Free/progression routes:
      - SelectUpgrade(index)
      - Rebirth()
      - TeleportWorld(world)
      - CollectShard(index)
      - RequestOfflineEarnings / ClaimOfflineEarnings
      - ClaimFreeReward after 30 min playtime
      - ClaimStreakReward(rewardKey)
      - RedeemCode(code)
      - UsePotion(exact potion name)
      - EquipBestCharms("Speed" / "Wins")
      - EquipTrail(name)
      - EquipAura(name)
      - Optional BuyTrail / BuyAura
      - PromptJoinRace -> JoinRace()
      - SecretDoorSpawned -> SecretDoorRequestEnter()
      - SecretDoorEntered -> OpenSecretChest(index)

    Events:
      - Quantum Treadmill: 10x, 300 seconds
      - Secret Door: 300 seconds
      - Race rewards can contain Wins, potions, spins or charms
      - GlobalWinsMulti / GlobalSpeedMulti are automatically respected by the server

    The supplied save could not contain the original FilteringEnabled server Script
    sources, so server-side validation itself cannot be inspected from the save.
    This script follows the real replicated client routes and lets the server decide
    whether each action is valid.
]]

-- ============================================================================
-- RERUN SAFETY
-- ============================================================================

local GENV = (getgenv and getgenv()) or _G
local SCRIPT_KEY = "__rainzxdev_MONKEY_ESCAPE_AUTOFARM"
local PLACE_ID = 114697347887839

if GENV[SCRIPT_KEY] and type(GENV[SCRIPT_KEY]) == "table" then
    pcall(function()
        GENV[SCRIPT_KEY]:Unload()
    end)
end

-- ============================================================================
-- SERVICES
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

if game.PlaceId ~= PLACE_ID then
    warn("[RAINZXDEV] +1 Speed Monkey Escape autofarm: wrong PlaceId " .. tostring(game.PlaceId))
    return
end

-- ============================================================================
-- GAME OBJECTS / MODULES
-- ============================================================================

local Data = LocalPlayer:WaitForChild("Data", 30)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local Config = ReplicatedStorage:WaitForChild("Config", 30)
local Util = ReplicatedStorage:WaitForChild("Util", 30)

if not Data or not Remotes or not Config or not Util then
    warn("[RAINZXDEV] Required game objects failed to replicate.")
    return
end

local function safeRequire(object)
    if not object then
        return nil
    end

    local ok, result = pcall(require, object)
    if ok then
        return result
    end

    return nil
end

local Main = safeRequire(Config:FindFirstChild("Main")) or {}
local RebirthsConfig = safeRequire(Config:FindFirstChild("Rebirths")) or {Multi = 0.5}
local TreadmillsConfig = safeRequire(Config:FindFirstChild("Treadmills")) or {Multis = {}}
local FreeRewardConfig = safeRequire(Config:FindFirstChild("FreeReward")) or {PlaytimeRequired = 30}
local PotionsConfig = safeRequire(Config:FindFirstChild("Potions")) or {}
local CodesConfig = safeRequire(Config:FindFirstChild("Codes")) or {Available = {}, Active = {}}
local StreakConfig = safeRequire(Config:FindFirstChild("Streak")) or {Rewards = {}}
local UpgradesConfig = safeRequire(Config:FindFirstChild("Upgrades")) or {}
local TrailsConfig = safeRequire(Config:FindFirstChild("Trails")) or {}
local AurasConfig = safeRequire(Config:FindFirstChild("Auras")) or {}

local PlayerUtil = safeRequire(Util:FindFirstChild("PlayerUtil"))
local BigNum = safeRequire(Util:FindFirstChild("BigNum"))
local Formatter = safeRequire(Util:FindFirstChild("Formatter"))

if not PlayerUtil or not BigNum then
    warn("[RAINZXDEV] PlayerUtil or BigNum failed to load.")
    return
end

-- ============================================================================
-- FARM STATE
-- ============================================================================

local Farm = {
    Version = "1.1.0",
    Running = true,
    MasterEnabled = false,
    BusyMovement = false,
    CurrentAction = "Ready",
    CurrentTreadmill = "None",
    CurrentWinButton = "None",
    LastWorldSwitch = 0,
    LastUpgrade = 0,
    LastEquipment = 0,
    LastRewardCheck = 0,
    LastCodes = 0,
    LastOfflineRequest = 0,
    LastPotionUse = {
        Speed = 0,
        Wins = 0,
    },
    LastRemote = {},
    Connections = {},
    Gui = nil,

    State = {
        AutoWins = true,
        AutoTreadmill = true,
        AutoWorld = true,
        AutoUpgrade = true,
        AutoRebirth = false,

        AutoBestAura = true,
        AutoBestTrail = true,
        AutoBestCharms = true,
        AutoBuyAuras = false,
        AutoBuyTrails = false,

        AutoShards = true,
        AutoCodes = true,
        AutoOffline = true,
        AutoFreeReward = true,
        AutoStreak = true,
        AutoRace = false,
        AutoSecretDoor = false,

        AutoSpeedPotion = false,
        AutoWinsPotion = false,
    },

    Config = {
        Mode = "Money",
        Profile = "Turbo",

        WinTouchDelay = 0.34,
        TouchHold = 0.035,

        -- ReturnButton rewards are server-side Touched logic. firetouchinterest
        -- alone only drives local listeners, so the farm performs a real
        -- replicated off-pad -> through-pad -> off-pad sweep.
        ServerTouchOffHeight = 6.0,
        ServerTouchCenterHeight = 0.65,
        ServerTouchEnterDelay = 0.14,
        ServerTouchContactDelay = 0.22,
        ServerTouchExitDelay = 0.10,
        WinVerifyDelay = 0.18,
        WinTouchAttempts = 3,
        CheckpointTouchDelay = 0.18,
        CheckpointRetryDelay = 0.20,

        WorldCooldown = 1.0,
        UpgradeCooldown = 0.75,
        EquipmentCooldown = 1.5,
        RewardInterval = 4.0,
        PotionCooldown = 2.0,

        MoneyWinTouches = 10,
        BalancedWinTouches = 4,
        ProgressWinTouches = 1,

        MoneySpeedBurst = 0.55,
        BalancedSpeedBurst = 1.25,
        ProgressSpeedBurst = 2.75,

        MovementYOffset = 2.4,
        TreadmillRefresh = 0.10,
        SecretDoorDelay = 0.15,
    },

    Metrics = {
        WinTouches = 0,
        WinPayouts = 0,
        WinTouchFailures = 0,
        CheckpointsPrimed = 0,
        TreadmillBursts = 0,
        Rebirths = 0,
        WorldSwitches = 0,
        Upgrades = 0,
        Shards = 0,
        CodesAttempted = 0,
        RewardsClaimed = 0,
        PotionUses = 0,
        RaceJoins = 0,
        SecretDoorEntries = 0,
        SecretChests = 0,
        RemoteErrors = 0,
    },
}

GENV[SCRIPT_KEY] = Farm

-- ============================================================================
-- TRACKING / CLEANUP
-- ============================================================================

local function track(connection)
    if connection then
        table.insert(Farm.Connections, connection)
    end
    return connection
end

function Farm:Unload()
    if not self.Running then
        return
    end

    self.Running = false
    self.MasterEnabled = false

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(self.Connections)

    if self.Gui then
        pcall(function()
            self.Gui:Destroy()
        end)
        self.Gui = nil
    end

    if GENV[SCRIPT_KEY] == self then
        GENV[SCRIPT_KEY] = nil
    end
end

-- ============================================================================
-- GENERIC HELPERS
-- ============================================================================

local function setAction(text)
    Farm.CurrentAction = tostring(text or "")
end

local function now()
    return os.clock()
end

local function getValue(name, default)
    local object = Data:FindFirstChild(name)
    if object and object:IsA("ValueBase") then
        return object.Value
    end
    return default
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local character = getCharacter()
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function inRace()
    return LocalPlayer:GetAttribute("InRace") == true
end

local function isDead()
    local humanoid = getHumanoid()
    if not humanoid then
        return true
    end

    if humanoid.Health <= 0 then
        return true
    end

    local ok, tagged = pcall(function()
        return humanoid:HasTag("Dead")
    end)

    return ok and tagged == true
end

local function formatNumber(value)
    if Formatter and type(Formatter.Format) == "function" then
        local ok, result = pcall(Formatter.Format, value)
        if ok then
            return tostring(result)
        end
    end

    local number = tonumber(value)
    if number then
        if math.abs(number) >= 1e9 then
            return string.format("%.3g", number)
        end
        return tostring(math.floor(number + 0.5))
    end

    return tostring(value or 0)
end

local function winsToNumber()
    local wins = Data:FindFirstChild("Wins")
    if not wins then
        return 0
    end

    if BigNum and type(BigNum.ToNumber) == "function" then
        local ok, result = pcall(BigNum.ToNumber, wins)
        if ok and type(result) == "number" then
            return result
        end
    end

    if wins:IsA("ValueBase") and type(wins.Value) == "number" then
        return wins.Value
    end

    return 0
end


-- Compare Wins snapshots without assuming the game stores ordinary numbers.
-- BigNum supports enormous World 4/5 values, so use its own comparison first.
local function winsSnapshot()
    local wins = Data:FindFirstChild("Wins")
    if not wins then
        return nil
    end

    if BigNum and type(BigNum.Clone) == "function" then
        local ok, result = pcall(BigNum.Clone, wins)
        if ok then
            return result
        end
    end

    -- BigNum's helpers accept the Value object itself in this game.
    return wins
end

local function winsIncreased(before)
    if before == nil then
        return false
    end

    local current = Data:FindFirstChild("Wins")
    if not current then
        return false
    end

    if BigNum and type(BigNum.GreaterThan) == "function" then
        local ok, result = pcall(BigNum.GreaterThan, current, before)
        if ok then
            return result == true
        end
    end

    if BigNum and type(BigNum.ToNumber) == "function" then
        local okA, a = pcall(BigNum.ToNumber, current)
        local okB, b = pcall(BigNum.ToNumber, before)
        if okA and okB and type(a) == "number" and type(b) == "number" then
            return a > b
        end
    end

    return winsToNumber() > 0
end

local function hasWins(amount)
    local wins = Data:FindFirstChild("Wins")
    if not wins or type(amount) ~= "number" then
        return false
    end

    if BigNum and type(BigNum.GreaterEqual) == "function" then
        local ok, result = pcall(BigNum.GreaterEqual, wins, amount)
        if ok then
            return result == true
        end
    end

    return winsToNumber() >= amount
end

local function getLevel()
    local ok, result = pcall(PlayerUtil.GetLevel, Data)
    if ok and type(result) == "number" then
        return result
    end

    return tonumber(getValue("Level", 0)) or 0
end

local function getRebirths()
    return tonumber(getValue("Rebirths", 0)) or 0
end

local function getWorld()
    return tonumber(getValue("World", 1)) or 1
end

local function getRemote(name)
    return Remotes:FindFirstChild(name)
end

local function remoteReady(name, cooldown)
    local current = now()
    local last = Farm.LastRemote[name] or 0

    if current - last < (cooldown or 0) then
        return false
    end

    Farm.LastRemote[name] = current
    return true
end

local function fireRemote(name, cooldown, ...)
    local remote = getRemote(name)
    if not remote or not remote:IsA("RemoteEvent") then
        return false
    end

    if not remoteReady(name, cooldown or 0) then
        return false
    end

    local args = table.pack(...)
    local ok = pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)

    if not ok then
        Farm.Metrics.RemoteErrors = Farm.Metrics.RemoteErrors + 1
    end

    return ok
end

local function invokeRemote(name, cooldown, ...)
    local remote = getRemote(name)
    if not remote or not remote:IsA("RemoteFunction") then
        return false, nil
    end

    if not remoteReady(name, cooldown or 0) then
        return false, nil
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)

    if not ok then
        Farm.Metrics.RemoteErrors = Farm.Metrics.RemoteErrors + 1
        return false, result
    end

    return true, result
end

local function resolvePart(object, preferredNames)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    end

    for _, name in ipairs(preferredNames or {}) do
        local found = object:FindFirstChild(name, true)
        if found and found:IsA("BasePart") then
            return found
        end
    end

    if object:IsA("Model") and object.PrimaryPart then
        return object.PrimaryPart
    end

    return object:FindFirstChildWhichIsA("BasePart", true)
end

local function moveToPart(part, offsetY)
    local root = getRoot()
    if not root or not part or not part.Parent then
        return false
    end

    local y = offsetY
    if type(y) ~= "number" then
        y = Farm.Config.MovementYOffset
    end

    local target = part.CFrame * CFrame.new(0, y, 0)

    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = target
    end)

    return ok
end

local function touchPart(part)
    local root = getRoot()
    if not root or not part or not part.Parent then
        return false
    end

    moveToPart(part, Farm.Config.MovementYOffset)
    task.wait(Farm.Config.TouchHold)

    local fired = false

    if type(firetouchinterest) == "function" then
        local ok = pcall(function()
            firetouchinterest(root, part, 0)
            task.wait()
            firetouchinterest(root, part, 1)
        end)
        fired = ok
    end

    if not fired and type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(part.Touched, root)
        end)
        fired = ok
    end

    -- CFrame overlap itself is the final fallback; Roblox will often emit Touched
    -- naturally on the next physics step.
    if not fired then
        pcall(function()
            root.CFrame = part.CFrame
        end)
        task.wait()
        pcall(function()
            root.CFrame = part.CFrame * CFrame.new(0, 1.25, 0)
        end)
    end

    return true
end


local function getWinsVerificationValue()
    local wins = Data:FindFirstChild("Wins")
    if not wins then
        return nil
    end

    if BigNum and type(BigNum.ToNumber) == "function" then
        local ok, value = pcall(BigNum.ToNumber, wins)
        if ok and type(value) == "number" then
            return value
        end
    end

    if wins:IsA("ValueBase") then
        return wins.Value
    end

    return nil
end

local function payoutChanged(before)
    if before == nil then
        return false
    end

    local after = getWinsVerificationValue()
    return type(after) == "number" and after > before
end

-- This is the important v1.1 fix.
--
-- ReturnButton client code has a local Touched listener for animation/purchase
-- prompting, but the actual Wins award is server-side. Executor-only
-- firetouchinterest/firesignal does NOT guarantee that server listener runs.
--
-- Force the character itself to leave contact, enter the button volume for
-- several replication frames, then leave again.
local function serverPhysicalTouch(part)
    local root = getRoot()
    local character = getCharacter()

    if not root or not character or not part or not part.Parent then
        return false
    end

    local humanoid = getHumanoid()
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    local oldAutoRotate = humanoid.AutoRotate

    local function setRoot(cf)
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = cf
        end)

        -- Allow the client-owned character transform to replicate to the server.
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
    end

    local up = part.CFrame.UpVector
    local off = part.CFrame + up * Farm.Config.ServerTouchOffHeight
    local contact = part.CFrame + up * Farm.Config.ServerTouchCenterHeight

    pcall(function()
        humanoid.AutoRotate = false
    end)

    -- 1. Explicitly leave the pad. This resets a server-side Touched debounce
    --    that can remain latched when the script repeatedly teleports to the
    --    same CFrame.
    setRoot(off)
    task.wait(Farm.Config.ServerTouchEnterDelay)

    -- 2. Move the real character into the actual Button part volume.
    setRoot(contact)

    -- Locally fire as well so the game's animation/UI follows the same route.
    if type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, part, 0)
        end)
    end

    task.wait(Farm.Config.ServerTouchContactDelay)

    -- 3. Sweep slightly THROUGH the button, not merely onto its top surface.
    --    This gives server physics another crossing frame.
    setRoot(part.CFrame - up * 0.25)
    task.wait(0.08)

    if type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, part, 1)
        end)
    end

    -- 4. Leave the pad again so the next payout attempt starts cleanly.
    setRoot(off)
    task.wait(Farm.Config.ServerTouchExitDelay)

    pcall(function()
        humanoid.AutoRotate = oldAutoRotate
    end)

    return true
end

local function ancestorWorld(object)
    local current = object
    while current and current ~= workspace do
        local number = tonumber(current.Name:match("^World(%d+)$"))
        if number then
            return number
        end
        current = current.Parent
    end
    return nil
end

-- ============================================================================
-- PROFILE
-- ============================================================================

local function applyProfile(name)
    name = tostring(name or "Turbo")

    if name == "Safe" then
        Farm.Config.Profile = "Safe"
        Farm.Config.WinTouchDelay = 0.70
        Farm.Config.TouchHold = 0.08
        Farm.Config.WorldCooldown = 1.75
        Farm.Config.UpgradeCooldown = 1.5
        Farm.Config.EquipmentCooldown = 2.5
        Farm.Config.RewardInterval = 7
        Farm.Config.PotionCooldown = 3
        Farm.Config.MoneyWinTouches = 7
        Farm.Config.BalancedWinTouches = 3
        Farm.Config.ProgressWinTouches = 1
        Farm.Config.MoneySpeedBurst = 0.8
        Farm.Config.BalancedSpeedBurst = 1.6
        Farm.Config.ProgressSpeedBurst = 3.2
        Farm.Config.TreadmillRefresh = 0.16
    elseif name == "Balanced" then
        Farm.Config.Profile = "Balanced"
        Farm.Config.WinTouchDelay = 0.46
        Farm.Config.TouchHold = 0.05
        Farm.Config.WorldCooldown = 1.25
        Farm.Config.UpgradeCooldown = 1.0
        Farm.Config.EquipmentCooldown = 1.8
        Farm.Config.RewardInterval = 5
        Farm.Config.PotionCooldown = 2.5
        Farm.Config.MoneyWinTouches = 8
        Farm.Config.BalancedWinTouches = 4
        Farm.Config.ProgressWinTouches = 1
        Farm.Config.MoneySpeedBurst = 0.65
        Farm.Config.BalancedSpeedBurst = 1.35
        Farm.Config.ProgressSpeedBurst = 2.9
        Farm.Config.TreadmillRefresh = 0.13
    else
        Farm.Config.Profile = "Turbo"
        Farm.Config.WinTouchDelay = 0.34
        Farm.Config.TouchHold = 0.035
        Farm.Config.WorldCooldown = 1.0
        Farm.Config.UpgradeCooldown = 0.75
        Farm.Config.EquipmentCooldown = 1.5
        Farm.Config.RewardInterval = 4
        Farm.Config.PotionCooldown = 2
        Farm.Config.MoneyWinTouches = 10
        Farm.Config.BalancedWinTouches = 4
        Farm.Config.ProgressWinTouches = 1
        Farm.Config.MoneySpeedBurst = 0.55
        Farm.Config.BalancedSpeedBurst = 1.25
        Farm.Config.ProgressSpeedBurst = 2.75
        Farm.Config.TreadmillRefresh = 0.10
    end
end

applyProfile(Farm.Config.Profile)

-- ============================================================================
-- HIGHEST WORLD
-- ============================================================================

local function highestUnlockedWorld()
    local rebirths = getRebirths()
    local best = 1

    for world = 2, 5 do
        local requirement = Main.WorldRebirthsRequired
            and Main.WorldRebirthsRequired["World" .. tostring(world)]

        if type(requirement) == "number" and rebirths >= requirement then
            best = world
        end
    end

    return best
end

local function ensureBestWorld()
    if not Farm.State.AutoWorld or inRace() then
        return false
    end

    if now() - Farm.LastWorldSwitch < Farm.Config.WorldCooldown then
        return false
    end

    local target = highestUnlockedWorld()
    local current = getWorld()

    if target == current then
        return false
    end

    Farm.LastWorldSwitch = now()
    setAction("Switching to World " .. tostring(target))

    if fireRemote("TeleportWorld", Farm.Config.WorldCooldown, target) then
        Farm.Metrics.WorldSwitches = Farm.Metrics.WorldSwitches + 1
        return true
    end

    return false
end

-- ============================================================================
-- CHECKPOINT PRIMING FOR RETURNBUTTON PAYOUTS
-- ============================================================================

local reachedCheckpointEvent = getRemote("ReachedCheckpoint")
local LastReachedCheckpoint = {
    At = 0,
    Args = nil,
}

if reachedCheckpointEvent and reachedCheckpointEvent:IsA("RemoteEvent") then
    track(reachedCheckpointEvent.OnClientEvent:Connect(function(...)
        LastReachedCheckpoint.At = now()
        LastReachedCheckpoint.Args = table.pack(...)
    end))
end

local function getCheckpoint(world, order)
    if type(PlayerUtil.GetCheckpointModel) == "function" then
        local ok, result = pcall(PlayerUtil.GetCheckpointModel, world, order)
        if ok and result then
            return result
        end
    end

    for _, checkpoint in ipairs(CollectionService:GetTagged("Checkpoint")) do
        if checkpoint:GetAttribute("World") == world
            and checkpoint:GetAttribute("Order") == order then
            return checkpoint
        end
    end

    return nil
end

local function getCheckpointTouchPart(checkpoint)
    if not checkpoint then
        return nil
    end

    -- SpawnPoint is confirmed by the game's PlayerUtil/Teleport UI.
    -- Prefer an actual collision/trigger child when present.
    return resolvePart(checkpoint, {
        "Hitbox",
        "Trigger",
        "Checkpoint",
        "Touch",
        "Part",
        "SpawnPoint",
    })
end

local function primeCheckpoint(world, order)
    local checkpoint = getCheckpoint(world, order)
    if not checkpoint then
        return false
    end

    local part = getCheckpointTouchPart(checkpoint)
    if not part then
        return false
    end

    setAction(string.format("Priming checkpoint W%d #%d", world, order))
    local beforeSignal = LastReachedCheckpoint.At

    if not serverPhysicalTouch(part) then
        return false
    end

    task.wait(Farm.Config.CheckpointTouchDelay)

    Farm.Metrics.CheckpointsPrimed = Farm.Metrics.CheckpointsPrimed + 1

    -- ReachedCheckpoint is server -> client feedback when available. We don't
    -- require it because some checkpoint paths may update replicated Data only.
    return LastReachedCheckpoint.At > beforeSignal or true
end

local function primeCheckpointChain(world, returnOrder)
    -- Return Order N corresponds to progress through the earlier checkpoint
    -- chain. Rather than guess one checkpoint and fail forever, prime every
    -- replicated checkpoint up through this payout stage in ascending order.
    --
    -- The Teleport UI itself maps Stage i to Checkpoint (i - 1), so N-1 is the
    -- critical checkpoint. Priming 1..N-1 also satisfies servers that enforce
    -- sequential checkpoint progression.
    local finalOrder = math.max(0, (tonumber(returnOrder) or 1) - 1)

    if finalOrder <= 0 then
        return false
    end

    local touchedAny = false

    for order = 1, finalOrder do
        if not Farm.Running
            or not Farm.MasterEnabled
            or inRace()
            or isDead() then
            break
        end

        if primeCheckpoint(world, order) then
            touchedAny = true
        end

        task.wait(Farm.Config.CheckpointRetryDelay)
    end

    return touchedAny
end

-- ============================================================================
-- RETURN BUTTON / MONEY FARM
-- ============================================================================

local function ownsPass(name)
    local passes = Data:FindFirstChild("Passes")
    if passes and passes:FindFirstChild(name) then
        return true
    end
    return false
end

local function getReturnButtonContainer(tagged)
    if not tagged then
        return nil
    end

    if tagged:IsA("Model") then
        return tagged
    end

    return tagged.Parent
end

local function getReturnButtonInfo(tagged)
    local container = getReturnButtonContainer(tagged)
    if not container then
        return nil
    end

    local world = tonumber(container:GetAttribute("World")) or tonumber(tagged:GetAttribute("World")) or 1
    local order = tonumber(container:GetAttribute("Order")) or tonumber(tagged:GetAttribute("Order"))
    local doubleWins = container:GetAttribute("DoubleWins") == true
        or tagged:GetAttribute("DoubleWins") == true

    if not order then
        return nil
    end

    local worldRewards = Main.StageWins and Main.StageWins["World" .. tostring(world)]
    local baseReward = worldRewards and worldRewards[order]

    if type(baseReward) ~= "number" then
        return nil
    end

    local part
    if tagged:IsA("Model") then
        part = resolvePart(tagged, {"Button", "Hitbox", "Main"})
    else
        part = tagged:IsA("BasePart") and tagged
            or resolvePart(container, {"Button", "Hitbox", "Main"})
    end

    if not part then
        return nil
    end

    return {
        Tagged = tagged,
        Container = container,
        Part = part,
        World = world,
        Order = order,
        DoubleWins = doubleWins,
        BaseReward = baseReward,
        Reward = baseReward * (doubleWins and 2 or 1),
    }
end

local function getBestReturnButton()
    local currentWorld = getWorld()
    local canDouble = ownsPass("x2 Wins")
    local best

    for _, tagged in ipairs(CollectionService:GetTagged("ReturnButton")) do
        local info = getReturnButtonInfo(tagged)

        if info and info.World == currentWorld then
            local allowed = true

            -- Avoid touching the paid double-return button if the player does not
            -- own x2 Wins, because the normal client would open a purchase prompt.
            if info.DoubleWins and not canDouble then
                allowed = false
            end

            if allowed then
                if not best
                    or info.Reward > best.Reward
                    or (info.Reward == best.Reward and info.Order > best.Order) then
                    best = info
                end
            end
        end
    end

    return best
end

local function farmOneWinButton()
    if not Farm.MasterEnabled or not Farm.State.AutoWins then
        return false
    end

    if Farm.BusyMovement or inRace() or isDead() then
        return false
    end

    local info = getBestReturnButton()
    if not info then
        Farm.CurrentWinButton = "No ReturnButton found"
        return false
    end

    Farm.CurrentWinButton = string.format(
        "W%d Stage %d • +%s%s",
        info.World,
        info.Order,
        formatNumber(info.BaseReward),
        info.DoubleWins and " • x2 button" or ""
    )

    Farm.BusyMovement = true

    local function attemptReturnTouch(label)
        local before = getWinsVerificationValue()

        setAction(label .. " • " .. Farm.CurrentWinButton)
        Farm.Metrics.WinTouches = Farm.Metrics.WinTouches + 1

        serverPhysicalTouch(info.Part)
        task.wait(Farm.Config.WinVerifyDelay)

        if payoutChanged(before) then
            Farm.Metrics.WinPayouts = Farm.Metrics.WinPayouts + 1
            setAction("PAYOUT OK • " .. Farm.CurrentWinButton)
            return true
        end

        return false
    end

    -- First try the real return button touch directly.
    for attempt = 1, Farm.Config.WinTouchAttempts do
        if attemptReturnTouch("Return touch " .. tostring(attempt)) then
            Farm.BusyMovement = false
            task.wait(Farm.Config.WinTouchDelay)
            return true
        end
    end

    -- If the player was teleported straight to the return pad, the server may
    -- reject it because the stage checkpoint chain was never reached. Prime the
    -- checkpoints exactly as the game's stage system expects, then retry.
    Farm.Metrics.WinTouchFailures = Farm.Metrics.WinTouchFailures + 1
    setAction("No payout • priming stage checkpoints")

    primeCheckpointChain(info.World, info.Order)
    task.wait(0.20)

    for attempt = 1, Farm.Config.WinTouchAttempts do
        if attemptReturnTouch("Checkpoint retry " .. tostring(attempt)) then
            Farm.BusyMovement = false
            task.wait(Farm.Config.WinTouchDelay)
            return true
        end
    end

    Farm.BusyMovement = false
    setAction("ReturnButton rejected • retrying next cycle")
    task.wait(math.max(0.35, Farm.Config.WinTouchDelay))
    return false
end

-- ============================================================================
-- TREADMILLS / SPEED FARM
-- ============================================================================

local TREADMILL_MULTIPLIERS = {
    TreadmillBasic = 1,
    TreadmillPlaytime = 1.5,
    TreadmillGold = 3,
    TreadmillDiamond = 9,
    TreadmillGalaxy = 25,
    TreadmillVoid = 100,
    TreadmillCelestial = 1000,
    TreadmillSunken = 2,
    TreadmillQuantum = 10,
}

local TREADMILL_PASSES = {
    TreadmillGold = "Golden",
    TreadmillDiamond = "Diamond",
    TreadmillGalaxy = "Galaxy",
    TreadmillVoid = "Void",
    TreadmillCelestial = "Celestial",
}

local function countShards()
    local folder = Data:FindFirstChild("CollectedShards")
    return folder and #folder:GetChildren() or 0
end

local function treadmillAccessible(model)
    if not model or not model.Parent then
        return false
    end

    local name = model.Name

    if name == "TreadmillBasic" then
        return true
    end

    if name == "TreadmillQuantum" then
        return true
    end

    if name == "TreadmillPlaytime" then
        local claimed = Data:FindFirstChild("ClaimedFreeReward")
        return claimed and claimed.Value == true
    end

    if name == "TreadmillSunken" then
        return countShards() >= 9
    end

    local requiredPass = TREADMILL_PASSES[name]
    if requiredPass then
        return ownsPass(requiredPass)
    end

    -- Generic fallback: if a TreadmillLabel exposes Type, match it to Data.Passes.
    for _, descendant in ipairs(model:GetDescendants()) do
        local treadmillType = descendant:GetAttribute("Type")
        if treadmillType then
            return ownsPass(tostring(treadmillType))
        end
    end

    return false
end

local function getBestTreadmill()
    local world = getWorld()
    local best

    for _, object in ipairs(workspace:GetDescendants()) do
        local multiplier = TREADMILL_MULTIPLIERS[object.Name]

        if multiplier and (object:IsA("Model") or object:IsA("BasePart")) then
            local objectWorld = ancestorWorld(object)

            -- Quantum event treadmill can exist outside a World folder.
            local sameWorld = object.Name == "TreadmillQuantum"
                or objectWorld == nil
                or objectWorld == world

            if sameWorld and treadmillAccessible(object) then
                local part = resolvePart(object, {"Hitbox", "Treadmill", "Main", "Part"})

                if part then
                    if not best or multiplier > best.Multiplier then
                        best = {
                            Object = object,
                            Part = part,
                            Multiplier = multiplier,
                            Name = object.Name,
                        }
                    end
                end
            end
        end
    end

    return best
end

local function farmTreadmill(seconds)
    if not Farm.MasterEnabled or not Farm.State.AutoTreadmill then
        return false
    end

    if Farm.BusyMovement or inRace() or isDead() then
        return false
    end

    local treadmill = getBestTreadmill()
    if not treadmill then
        Farm.CurrentTreadmill = "No accessible treadmill"
        return false
    end

    Farm.CurrentTreadmill = string.format("%s • x%s", treadmill.Name, tostring(treadmill.Multiplier))
    Farm.BusyMovement = true
    Farm.Metrics.TreadmillBursts = Farm.Metrics.TreadmillBursts + 1
    setAction("Speed farming on " .. Farm.CurrentTreadmill)

    local finish = now() + math.max(0.15, tonumber(seconds) or 1)

    while Farm.Running
        and Farm.MasterEnabled
        and Farm.State.AutoTreadmill
        and not inRace()
        and now() < finish do

        if not treadmill.Part.Parent then
            break
        end

        moveToPart(treadmill.Part, 1.8)

        if type(firetouchinterest) == "function" then
            local root = getRoot()
            if root then
                pcall(function()
                    firetouchinterest(root, treadmill.Part, 0)
                end)
            end
        end

        task.wait(Farm.Config.TreadmillRefresh)
    end

    if type(firetouchinterest) == "function" then
        local root = getRoot()
        if root and treadmill.Part and treadmill.Part.Parent then
            pcall(function()
                firetouchinterest(root, treadmill.Part, 1)
            end)
        end
    end

    Farm.BusyMovement = false
    return true
end

-- ============================================================================
-- SHARDS
-- ============================================================================

local function collectMissingShards()
    if not Farm.State.AutoShards then
        return
    end

    local folder = Data:FindFirstChild("CollectedShards")
    if not folder then
        return
    end

    for index = 1, 9 do
        if not Farm.Running or not Farm.State.AutoShards then
            break
        end

        if not folder:FindFirstChild(tostring(index)) then
            setAction("Collecting Sunken Shard " .. tostring(index) .. "/9")

            if fireRemote("CollectShard", 0.10, index) then
                Farm.Metrics.Shards = Farm.Metrics.Shards + 1
            end

            task.wait(0.16)
        end
    end
end

-- ============================================================================
-- BEST UPGRADE
-- ============================================================================

local function bestAffordableUpgrade()
    local selected = Data:FindFirstChild("SelectedUpgrade")
    local unlocked = Data:FindFirstChild("UnlockedUpgrades")
    local bestIndex

    for index, info in pairs(UpgradesConfig) do
        if type(index) == "number" and type(info) == "table" then
            local requirement = info.WinsRequirement
            local isUnlocked = unlocked and unlocked:FindFirstChild(tostring(index)) ~= nil
            local affordable = type(requirement) == "number" and hasWins(requirement)

            if isUnlocked or affordable then
                if not bestIndex or index > bestIndex then
                    bestIndex = index
                end
            end
        end
    end

    if bestIndex and selected and selected.Value == bestIndex then
        return nil
    end

    return bestIndex
end

local function selectBestUpgrade()
    if not Farm.State.AutoUpgrade then
        return false
    end

    if now() - Farm.LastUpgrade < Farm.Config.UpgradeCooldown then
        return false
    end

    Farm.LastUpgrade = now()
    local index = bestAffordableUpgrade()

    if not index then
        return false
    end

    if fireRemote("SelectUpgrade", Farm.Config.UpgradeCooldown, index) then
        Farm.Metrics.Upgrades = Farm.Metrics.Upgrades + 1
        setAction("Selected upgrade #" .. tostring(index))
        return true
    end

    return false
end

-- ============================================================================
-- EQUIPMENT / MULTIPLIERS
-- ============================================================================

local function bestUnlockedItem(folderName, configTable)
    local folder = Data:FindFirstChild(folderName)
    if not folder then
        return nil, 1
    end

    local bestName
    local bestMulti = 1

    for _, owned in ipairs(folder:GetChildren()) do
        local info = configTable[owned.Name]
        local multi = info and tonumber(info.Multi)

        if multi and multi > bestMulti then
            bestMulti = multi
            bestName = owned.Name
        end
    end

    return bestName, bestMulti
end

local function equipBestAura()
    if not Farm.State.AutoBestAura then
        return
    end

    local name = bestUnlockedItem("UnlockedAuras", AurasConfig)
    local equipped = Data:FindFirstChild("EquippedAura")

    if name and equipped and equipped.Value ~= name then
        fireRemote("EquipAura", 0.35, name)
    end
end

local function equipBestTrail()
    if not Farm.State.AutoBestTrail then
        return
    end

    local name = bestUnlockedItem("UnlockedTrails", TrailsConfig)
    local equipped = Data:FindFirstChild("EquippedTrail")

    if name and equipped and equipped.Value ~= name then
        fireRemote("EquipTrail", 0.35, name)
    end
end

local function buyNextAffordable(folderName, configTable, remoteName)
    local folder = Data:FindFirstChild(folderName)
    if not folder then
        return false
    end

    local candidates = {}

    for name, info in pairs(configTable) do
        if type(name) == "string"
            and type(info) == "table"
            and type(info.Price) == "number"
            and not folder:FindFirstChild(name) then

            table.insert(candidates, {
                Name = name,
                Price = info.Price,
            })
        end
    end

    table.sort(candidates, function(a, b)
        return a.Price < b.Price
    end)

    for _, item in ipairs(candidates) do
        if hasWins(item.Price) then
            return fireRemote(remoteName, 0.75, item.Name)
        end
    end

    return false
end

local function optimizeEquipment()
    if now() - Farm.LastEquipment < Farm.Config.EquipmentCooldown then
        return
    end

    Farm.LastEquipment = now()

    if Farm.State.AutoBuyAuras then
        buyNextAffordable("UnlockedAuras", AurasConfig, "BuyAura")
    end

    if Farm.State.AutoBuyTrails then
        buyNextAffordable("UnlockedTrails", TrailsConfig, "BuyTrail")
    end

    equipBestAura()
    equipBestTrail()
end

local function equipBestCharms(category)
    if not Farm.State.AutoBestCharms then
        return
    end

    if category ~= "Speed" and category ~= "Wins" then
        return
    end

    fireRemote("EquipBestCharms", 0.40, category)
end

-- ============================================================================
-- POTIONS
-- ============================================================================

local function potionActive(category)
    local active = Data:FindFirstChild("ActivePotions")
    if not active then
        return false
    end

    local info = PotionsConfig[category]
    local buffName = info and info.BuffName
    if not buffName then
        return false
    end

    local value = active:FindFirstChild(buffName)
    return value and value:IsA("ValueBase") and value.Value > 0
end

local function bestOwnedPotion(category)
    local inventory = Data:FindFirstChild("Potions")
    local info = PotionsConfig[category]

    if not inventory or not info or type(info.Tiers) ~= "table" then
        return nil
    end

    for index = #info.Tiers, 1, -1 do
        local tier = info.Tiers[index]
        local object = tier and inventory:FindFirstChild(tier.Name)

        if object and object:IsA("ValueBase") and object.Value > 0 then
            return tier.Name
        end
    end

    return nil
end

local function usePotion(category)
    local enabled = category == "Speed"
        and Farm.State.AutoSpeedPotion
        or category == "Wins"
        and Farm.State.AutoWinsPotion

    if not enabled then
        return false
    end

    if now() - (Farm.LastPotionUse[category] or 0) < Farm.Config.PotionCooldown then
        return false
    end

    if potionActive(category) then
        return false
    end

    local potion = bestOwnedPotion(category)
    if not potion then
        return false
    end

    Farm.LastPotionUse[category] = now()

    if fireRemote("UsePotion", Farm.Config.PotionCooldown, potion) then
        Farm.Metrics.PotionUses = Farm.Metrics.PotionUses + 1
        setAction("Used " .. potion)
        return true
    end

    return false
end

-- ============================================================================
-- REBIRTH
-- ============================================================================

local function nextRebirthRequirement()
    local rebirths = getRebirths()
    return Main.RebirthLevels and Main.RebirthLevels[rebirths + 1]
end

local function canRebirth()
    local requirement = nextRebirthRequirement()
    if type(requirement) ~= "number" then
        return false
    end

    return getLevel() >= requirement
end

local function tryRebirth()
    if not Farm.State.AutoRebirth or inRace() then
        return false
    end

    if not canRebirth() then
        return false
    end

    if fireRemote("Rebirth", 0.80) then
        Farm.Metrics.Rebirths = Farm.Metrics.Rebirths + 1
        setAction("Rebirth #" .. tostring(getRebirths() + 1))
        task.wait(0.45)
        return true
    end

    return false
end

-- ============================================================================
-- FREE REWARDS / CODES / STREAK / OFFLINE
-- ============================================================================

local codesDone = {}

local function redeemActiveCodes()
    if not Farm.State.AutoCodes then
        return
    end

    local active = CodesConfig.Active
    if type(active) ~= "table" then
        return
    end

    for _, code in ipairs(active) do
        if Farm.Running and Farm.State.AutoCodes and not codesDone[code] then
            codesDone[code] = true
            Farm.Metrics.CodesAttempted = Farm.Metrics.CodesAttempted + 1
            setAction("Redeeming code " .. tostring(code))
            invokeRemote("RedeemCode", 0.45, code)
            task.wait(0.50)
        end
    end
end

local function claimFreeReward()
    if not Farm.State.AutoFreeReward then
        return false
    end

    local playtime = Data:FindFirstChild("Playtime")
    local claimed = Data:FindFirstChild("ClaimedFreeReward")

    if not playtime or not claimed or claimed.Value == true then
        return false
    end

    local requiredMinutes = tonumber(FreeRewardConfig.PlaytimeRequired) or 30

    if playtime.Value / 60 >= requiredMinutes then
        if fireRemote("ClaimFreeReward", 1.5) then
            Farm.Metrics.RewardsClaimed = Farm.Metrics.RewardsClaimed + 1
            setAction("Claimed free treadmill reward")
            return true
        end
    end

    return false
end

local function claimStreakRewards()
    if not Farm.State.AutoStreak then
        return
    end

    local streak = Data:FindFirstChild("Streak")
    local claimed = Data:FindFirstChild("StreakClaimed")

    if not streak or not claimed or type(StreakConfig.Rewards) ~= "table" then
        return
    end

    for rewardKey, rewardInfo in pairs(StreakConfig.Rewards) do
        if type(rewardInfo) == "table"
            and type(rewardInfo.Day) == "number"
            and streak.Value >= rewardInfo.Day
            and not claimed:FindFirstChild(tostring(rewardKey)) then

            if fireRemote("ClaimStreakReward", 0.65, rewardKey) then
                Farm.Metrics.RewardsClaimed = Farm.Metrics.RewardsClaimed + 1
                setAction("Claimed streak reward " .. tostring(rewardKey))
            end

            task.wait(0.30)
        end
    end
end

local function requestOffline()
    if not Farm.State.AutoOffline then
        return
    end

    if now() - Farm.LastOfflineRequest < 20 then
        return
    end

    Farm.LastOfflineRequest = now()
    fireRemote("RequestOfflineEarnings", 10)
end

local function claimOffline()
    if not Farm.State.AutoOffline then
        return
    end

    if LocalPlayer:GetAttribute("HasOfflineReward") == true then
        if fireRemote("ClaimOfflineEarnings", 1.0) then
            Farm.Metrics.RewardsClaimed = Farm.Metrics.RewardsClaimed + 1
            setAction("Claimed offline Speed")
        end
    end
end

-- ============================================================================
-- RACES
-- ============================================================================

local promptJoinRace = getRemote("PromptJoinRace")
if promptJoinRace and promptJoinRace:IsA("RemoteEvent") then
    track(promptJoinRace.OnClientEvent:Connect(function()
        if Farm.Running and Farm.State.AutoRace and not inRace() then
            if fireRemote("JoinRace", 2.0) then
                Farm.Metrics.RaceJoins = Farm.Metrics.RaceJoins + 1
                setAction("Joined race")
            end
        end
    end))
end

-- ============================================================================
-- SECRET DOOR EVENT
-- ============================================================================

local secretDoorBusy = false
local secretDoorSpawned = getRemote("SecretDoorSpawned")
local secretDoorEntered = getRemote("SecretDoorEntered")

if secretDoorSpawned and secretDoorSpawned:IsA("RemoteEvent") then
    track(secretDoorSpawned.OnClientEvent:Connect(function(world, doorCFrame, _, keyCFrame)
        if not Farm.Running or not Farm.State.AutoSecretDoor or secretDoorBusy then
            return
        end

        secretDoorBusy = true

        task.spawn(function()
            setAction("Secret Door event: collecting key")

            local root = getRoot()

            -- The game's SecretDoorClient creates both key and door locally from
            -- these event CFrames. Following the same path avoids guessing map parts.
            if root and typeof(keyCFrame) == "CFrame" then
                pcall(function()
                    root.CFrame = keyCFrame * CFrame.new(0, 2, 0)
                end)
                task.wait(Farm.Config.SecretDoorDelay)
            end

            if root and typeof(doorCFrame) == "CFrame" then
                pcall(function()
                    root.CFrame = doorCFrame * CFrame.new(0, 2, -4)
                end)
                task.wait(Farm.Config.SecretDoorDelay)
            end

            if fireRemote("SecretDoorRequestEnter", 1.5) then
                Farm.Metrics.SecretDoorEntries = Farm.Metrics.SecretDoorEntries + 1
                setAction("Requested Secret Door entry")
            end

            task.wait(1.0)
            secretDoorBusy = false
        end)
    end))
end

if secretDoorEntered and secretDoorEntered:IsA("RemoteEvent") then
    track(secretDoorEntered.OnClientEvent:Connect(function(_, canOpenChests)
        if not Farm.Running or not Farm.State.AutoSecretDoor or not canOpenChests then
            return
        end

        -- Asset contains six visual chests. The normal client sends the selected
        -- child's numeric index. Attempt one chest; the server owns the reward.
        task.delay(0.25, function()
            if Farm.Running and Farm.State.AutoSecretDoor then
                if fireRemote("OpenSecretChest", 1.0, 1) then
                    Farm.Metrics.SecretChests = Farm.Metrics.SecretChests + 1
                    setAction("Opened Secret Door chest")
                end
            end
        end)
    end))
end

-- ============================================================================
-- OFFLINE EVENT FAST PATH
-- ============================================================================

local offlineReady = getRemote("OfflineEarningsReady")
if offlineReady and offlineReady:IsA("RemoteEvent") then
    track(offlineReady.OnClientEvent:Connect(function()
        if Farm.Running and Farm.State.AutoOffline then
            task.delay(0.15, function()
                if Farm.Running and Farm.State.AutoOffline then
                    fireRemote("ClaimOfflineEarnings", 0.75)
                end
            end)
        end
    end))
end

-- ============================================================================
-- REWARD WORKER
-- ============================================================================

task.spawn(function()
    task.wait(1.0)

    while Farm.Running do
        if Farm.MasterEnabled then
            requestOffline()
            claimOffline()
            claimFreeReward()
            claimStreakRewards()

            if Farm.State.AutoCodes and now() - Farm.LastCodes > 30 then
                Farm.LastCodes = now()
                redeemActiveCodes()
            end

            if Farm.State.AutoShards and countShards() < 9 then
                collectMissingShards()
            end
        end

        task.wait(Farm.Config.RewardInterval)
    end
end)

-- ============================================================================
-- OPTIMIZER WORKER
-- ============================================================================

task.spawn(function()
    while Farm.Running do
        if Farm.MasterEnabled then
            ensureBestWorld()
            selectBestUpgrade()
            optimizeEquipment()
        end

        task.wait(0.40)
    end
end)

-- ============================================================================
-- MAIN MOVEMENT / MONEY WORKER
-- ============================================================================

local function modePlan()
    local mode = Farm.Config.Mode

    if mode == "Progression" then
        return Farm.Config.ProgressWinTouches, Farm.Config.ProgressSpeedBurst
    end

    if mode == "Balanced" then
        return Farm.Config.BalancedWinTouches, Farm.Config.BalancedSpeedBurst
    end

    return Farm.Config.MoneyWinTouches, Farm.Config.MoneySpeedBurst
end

task.spawn(function()
    while Farm.Running do
        if not Farm.MasterEnabled or inRace() or isDead() then
            task.wait(0.20)
        else
            ensureBestWorld()

            local winTouches, speedBurst = modePlan()

            -- Money phase
            if Farm.State.AutoWins then
                equipBestCharms("Wins")
                usePotion("Wins")

                for _ = 1, winTouches do
                    if not Farm.Running
                        or not Farm.MasterEnabled
                        or inRace()
                        or not Farm.State.AutoWins then
                        break
                    end

                    farmOneWinButton()
                end
            end

            -- Progression phase
            if Farm.Running
                and Farm.MasterEnabled
                and Farm.State.AutoTreadmill
                and not inRace() then

                equipBestCharms("Speed")
                usePotion("Speed")
                farmTreadmill(speedBurst)
                selectBestUpgrade()
            end

            -- Rebirth after both phases so we bank a final Wins pass first.
            if Farm.Running and Farm.MasterEnabled and Farm.State.AutoRebirth then
                if tryRebirth() then
                    task.wait(0.35)
                    ensureBestWorld()
                end
            end

            task.wait(0.05)
        end
    end
end)

-- ============================================================================
-- rainzxdev UI
-- ============================================================================

local PUCK_UI_URL = "https://raw.githubusercontent.com/RAINZXDEV/Puck-Loader/main/ui/PuckUI.lua"
local compiler = loadstring or load

if type(compiler) ~= "function" then
    Farm:Unload()
    error("RAINZXDEV: this environment cannot compile PuckUI", 0)
end

local okUI, uiSource = pcall(function()
    return game:HttpGet(PUCK_UI_URL)
end)

if not okUI or type(uiSource) ~= "string" or #uiSource < 100 then
    Farm:Unload()
    error("RAINZXDEV: failed to download PuckUI: " .. tostring(uiSource), 0)
end

local uiChunk, compileError = compiler(uiSource)
if not uiChunk then
    Farm:Unload()
    error("RAINZXDEV: PuckUI compile error: " .. tostring(compileError), 0)
end

local PuckUI = uiChunk()
if type(PuckUI) ~= "table" or type(PuckUI.CreateWindow) ~= "function" then
    Farm:Unload()
    error("RAINZXDEV: invalid shared PuckUI module", 0)
end

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV | +1 Speed Monkey Escape",
    LoadingTitle = "RAINZXDEV",
    LoadingSubtitle = "Money + progression autofarm",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
})

Farm.Gui = Window.ScreenGui

local HomeTab = Window:CreateTab("Home", "home")
local MoneyTab = Window:CreateTab("Money", "coins")
local SpeedTab = Window:CreateTab("Speed", "zap")
local ProgressionTab = Window:CreateTab("Progression", "trending-up")
local RewardsTab = Window:CreateTab("Rewards", "gift")
local StatsTab = Window:CreateTab("Stats", "bar-chart")
local SettingsTab = Window:CreateTab("Settings", "settings")

-- HOME -----------------------------------------------------------------------

HomeTab:CreateSection("Farm Control")

local MasterToggle
MasterToggle = HomeTab:CreateToggle({
    Name = "Master Autofarm",
    CurrentValue = Farm.MasterEnabled,
    Flag = "MonkeyMasterFarm",
    Callback = function(value)
        Farm.MasterEnabled = value == true
        setAction(Farm.MasterEnabled and "Autofarm started" or "Autofarm paused")
    end,
})

local ModeDropdown = HomeTab:CreateDropdown({
    Name = "Farm Mode",
    Options = {"Money", "Balanced", "Progression"},
    CurrentOption = {Farm.Config.Mode},
    Flag = "MonkeyFarmMode",
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        if value == "Money" or value == "Balanced" or value == "Progression" then
            Farm.Config.Mode = value
            setAction("Mode: " .. value)
        end
    end,
})

local ProfileDropdown = HomeTab:CreateDropdown({
    Name = "Speed Profile",
    Options = {"Turbo", "Balanced", "Safe"},
    CurrentOption = {Farm.Config.Profile},
    Flag = "MonkeyFarmProfile",
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        applyProfile(value)
        setAction("Profile: " .. Farm.Config.Profile)
    end,
})

HomeTab:CreateButton({
    Name = "MAX MONEY • highest world + best Wins button",
    Callback = function()
        Farm.Config.Mode = "Money"
        ModeDropdown:Set({"Money"})
        applyProfile("Turbo")
        ProfileDropdown:Set({"Turbo"})

        Farm.State.AutoWins = true
        Farm.State.AutoWorld = true
        Farm.State.AutoUpgrade = true
        Farm.State.AutoBestAura = true
        Farm.State.AutoBestTrail = true
        Farm.State.AutoBestCharms = true
        Farm.State.AutoShards = true
        Farm.State.AutoCodes = true
        Farm.State.AutoOffline = true
        Farm.State.AutoFreeReward = true
        Farm.State.AutoStreak = true

        Farm.MasterEnabled = true
        MasterToggle:Set(true)

        setAction("MAX MONEY enabled")
        PuckUI:Notify({
            Title = "MAX MONEY",
            Content = "Highest unlocked world + highest valid ReturnButton is active.",
            Duration = 3,
        })
    end,
})

HomeTab:CreateButton({
    Name = "MAX PROGRESSION • speed + wins + rebirths",
    Callback = function()
        Farm.Config.Mode = "Progression"
        ModeDropdown:Set({"Progression"})
        applyProfile("Turbo")
        ProfileDropdown:Set({"Turbo"})

        Farm.State.AutoWins = true
        Farm.State.AutoTreadmill = true
        Farm.State.AutoWorld = true
        Farm.State.AutoUpgrade = true
        Farm.State.AutoRebirth = true
        Farm.State.AutoBestAura = true
        Farm.State.AutoBestTrail = true
        Farm.State.AutoBestCharms = true
        Farm.State.AutoShards = true
        Farm.State.AutoCodes = true
        Farm.State.AutoOffline = true
        Farm.State.AutoFreeReward = true
        Farm.State.AutoStreak = true

        Farm.MasterEnabled = true
        MasterToggle:Set(true)

        setAction("MAX PROGRESSION enabled")
        PuckUI:Notify({
            Title = "MAX PROGRESSION",
            Content = "Treadmill + Wins + automatic rebirth/world progression enabled.",
            Duration = 3,
        })
    end,
})

HomeTab:CreateButton({
    Name = "Pause everything",
    Callback = function()
        Farm.MasterEnabled = false
        MasterToggle:Set(false)
        setAction("Autofarm paused")
    end,
})

HomeTab:CreateSection("Live Overview")
local HomeStatus = HomeTab:CreateParagraph({
    Title = "Status",
    Content = "Loading...",
    Height = 76,
})

-- MONEY ----------------------------------------------------------------------

MoneyTab:CreateSection("Wins Farm")

MoneyTab:CreateToggle({
    Name = "Auto Highest Wins Button",
    CurrentValue = Farm.State.AutoWins,
    Flag = "AutoWins",
    Callback = function(value)
        Farm.State.AutoWins = value == true
    end,
})

MoneyTab:CreateToggle({
    Name = "Auto Best Wins Aura",
    CurrentValue = Farm.State.AutoBestAura,
    Flag = "AutoBestAura",
    Callback = function(value)
        Farm.State.AutoBestAura = value == true
    end,
})

MoneyTab:CreateToggle({
    Name = "Auto Best Charms",
    CurrentValue = Farm.State.AutoBestCharms,
    Flag = "AutoBestCharms",
    Callback = function(value)
        Farm.State.AutoBestCharms = value == true
    end,
})

MoneyTab:CreateToggle({
    Name = "Auto Use Wins Potions",
    CurrentValue = Farm.State.AutoWinsPotion,
    Flag = "AutoWinsPotion",
    Callback = function(value)
        Farm.State.AutoWinsPotion = value == true
    end,
})

MoneyTab:CreateSection("Optional Investments")

MoneyTab:CreateToggle({
    Name = "Auto Buy Affordable Auras",
    CurrentValue = Farm.State.AutoBuyAuras,
    Flag = "AutoBuyAuras",
    Callback = function(value)
        Farm.State.AutoBuyAuras = value == true
    end,
})

MoneyTab:CreateLabel("Auras spend Wins but permanently improve the Wins multiplier.")

-- SPEED ----------------------------------------------------------------------

SpeedTab:CreateSection("Speed Farm")

SpeedTab:CreateToggle({
    Name = "Auto Best Treadmill",
    CurrentValue = Farm.State.AutoTreadmill,
    Flag = "AutoTreadmill",
    Callback = function(value)
        Farm.State.AutoTreadmill = value == true
    end,
})

SpeedTab:CreateToggle({
    Name = "Auto Best Speed Trail",
    CurrentValue = Farm.State.AutoBestTrail,
    Flag = "AutoBestTrail",
    Callback = function(value)
        Farm.State.AutoBestTrail = value == true
    end,
})

SpeedTab:CreateToggle({
    Name = "Auto Use Speed Potions",
    CurrentValue = Farm.State.AutoSpeedPotion,
    Flag = "AutoSpeedPotion",
    Callback = function(value)
        Farm.State.AutoSpeedPotion = value == true
    end,
})

SpeedTab:CreateToggle({
    Name = "Auto Collect 9 Sunken Shards",
    CurrentValue = Farm.State.AutoShards,
    Flag = "AutoShards",
    Callback = function(value)
        Farm.State.AutoShards = value == true
    end,
})

SpeedTab:CreateSection("Optional Investments")

SpeedTab:CreateToggle({
    Name = "Auto Buy Affordable Trails",
    CurrentValue = Farm.State.AutoBuyTrails,
    Flag = "AutoBuyTrails",
    Callback = function(value)
        Farm.State.AutoBuyTrails = value == true
    end,
})

SpeedTab:CreateLabel("Trails spend Wins but permanently improve the Speed multiplier.")

-- PROGRESSION ----------------------------------------------------------------

ProgressionTab:CreateSection("Automatic Progression")

ProgressionTab:CreateToggle({
    Name = "Auto Highest Unlocked World",
    CurrentValue = Farm.State.AutoWorld,
    Flag = "AutoWorld",
    Callback = function(value)
        Farm.State.AutoWorld = value == true
    end,
})

ProgressionTab:CreateToggle({
    Name = "Auto Highest Affordable Upgrade",
    CurrentValue = Farm.State.AutoUpgrade,
    Flag = "AutoUpgrade",
    Callback = function(value)
        Farm.State.AutoUpgrade = value == true
    end,
})

ProgressionTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = Farm.State.AutoRebirth,
    Flag = "AutoRebirth",
    Callback = function(value)
        Farm.State.AutoRebirth = value == true
    end,
})

ProgressionTab:CreateParagraph({
    Title = "World Requirements",
    Content = "World 2: 8 rebirths\nWorld 3: 16\nWorld 4: 24\nWorld 5: 32",
    Height = 66,
})

ProgressionTab:CreateParagraph({
    Title = "Rebirth",
    Content = "Each rebirth adds +0.5x permanent Speed. Auto Rebirth only fires when the game's configured next level requirement is reached.",
    Height = 62,
})

-- REWARDS --------------------------------------------------------------------

RewardsTab:CreateSection("Free Rewards")

RewardsTab:CreateToggle({
    Name = "Auto Redeem Active Codes",
    CurrentValue = Farm.State.AutoCodes,
    Flag = "AutoCodes",
    Callback = function(value)
        Farm.State.AutoCodes = value == true
        if value then
            table.clear(codesDone)
        end
    end,
})

RewardsTab:CreateToggle({
    Name = "Auto Offline Earnings",
    CurrentValue = Farm.State.AutoOffline,
    Flag = "AutoOffline",
    Callback = function(value)
        Farm.State.AutoOffline = value == true
        Farm.LastOfflineRequest = 0
    end,
})

RewardsTab:CreateToggle({
    Name = "Auto 30m Free Treadmill",
    CurrentValue = Farm.State.AutoFreeReward,
    Flag = "AutoFreeReward",
    Callback = function(value)
        Farm.State.AutoFreeReward = value == true
    end,
})

RewardsTab:CreateToggle({
    Name = "Auto Streak Rewards",
    CurrentValue = Farm.State.AutoStreak,
    Flag = "AutoStreak",
    Callback = function(value)
        Farm.State.AutoStreak = value == true
    end,
})

RewardsTab:CreateSection("Server Events")

RewardsTab:CreateToggle({
    Name = "Auto Join Races",
    CurrentValue = Farm.State.AutoRace,
    Flag = "AutoRace",
    Callback = function(value)
        Farm.State.AutoRace = value == true
    end,
})

RewardsTab:CreateToggle({
    Name = "Auto Secret Door",
    CurrentValue = Farm.State.AutoSecretDoor,
    Flag = "AutoSecretDoor",
    Callback = function(value)
        Farm.State.AutoSecretDoor = value == true
    end,
})

RewardsTab:CreateParagraph({
    Title = "Event Handling",
    Content = "Quantum Treadmill is automatically preferred when it is the best accessible treadmill. Race farming pauses normal movement while InRace. Secret Door follows the event key/door route and opens one server-owned chest.",
    Height = 76,
})

-- STATS ----------------------------------------------------------------------

StatsTab:CreateSection("Live Metrics")

local MetricsParagraph = StatsTab:CreateParagraph({
    Title = "Session",
    Content = "Loading...",
    Height = 108,
})

StatsTab:CreateSection("Game Audit")

StatsTab:CreateParagraph({
    Title = "Fastest Wins Route",
    Content = "ReturnButton tags are the real Wins buttons. v1.1 uses a replicated physics sweep and verifies Data.Wins actually increases. If a direct return touch is rejected, it primes Checkpoints 1..Order-1 and retries.",
    Height = 76,
})

StatsTab:CreateParagraph({
    Title = "Not Used",
    Content = "TeleportStage is intentionally not used because the real client checks and spends Wins for that route. TestGrantProduct/TestGrantPass are also intentionally ignored.",
    Height = 66,
})

-- SETTINGS -------------------------------------------------------------------

SettingsTab:CreateSection("Farm Settings")

SettingsTab:CreateDropdown({
    Name = "Profile",
    Options = {"Turbo", "Balanced", "Safe"},
    CurrentOption = {Farm.Config.Profile},
    Flag = "SettingsFarmProfile",
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        applyProfile(value)
        ProfileDropdown:Set({Farm.Config.Profile})
    end,
})

SettingsTab:CreateButton({
    Name = "Redeem active codes now",
    Callback = function()
        table.clear(codesDone)
        Farm.LastCodes = 0
        task.spawn(redeemActiveCodes)
    end,
})

SettingsTab:CreateButton({
    Name = "Collect missing Sunken Shards now",
    Callback = function()
        task.spawn(collectMissingShards)
    end,
})

SettingsTab:CreateButton({
    Name = "Re-scan best equipment",
    Callback = function()
        Farm.LastEquipment = 0
        task.spawn(optimizeEquipment)
    end,
})

SettingsTab:CreateButton({
    Name = "Unload RAINZXDEV autofarm",
    Callback = function()
        Farm:Unload()
    end,
})

SettingsTab:CreateParagraph({
    Title = "UI",
    Content = "RAINZXDEV shared UI is loaded from RAINZXDEV/Puck-Loader. Use the shared UI keybind from PuckUI Settings to hide/show it.",
    Height = 58,
})

-- ============================================================================
-- UI LIVE REFRESH
-- ============================================================================

local function getMultipliers()
    local speed = 1
    local wins = 1

    local okSpeed, speedResult = pcall(PlayerUtil.GetSpeedMulti, Data)
    if okSpeed and type(speedResult) == "number" then
        speed = speedResult
    end

    local okWins, winsResult = pcall(PlayerUtil.GetWinsMulti, Data)
    if okWins and type(winsResult) == "number" then
        wins = winsResult
    end

    return speed, wins
end

task.spawn(function()
    while Farm.Running do
        local level = getLevel()
        local rebirths = getRebirths()
        local world = getWorld()
        local wins = winsToNumber()
        local nextReq = nextRebirthRequirement()
        local speedMulti, winsMulti = getMultipliers()

        local nextText = type(nextReq) == "number"
            and tostring(nextReq)
            or "MAX"

        pcall(function()
            HomeStatus:Set({
                Title = Farm.MasterEnabled and "AUTOFARM RUNNING" or "AUTOFARM PAUSED",
                Content = string.format(
                    "Mode: %s • %s\nWorld %d • Level %d/%s • Rebirths %d\nWins: %s • Speed x%s • Wins x%s\n%s",
                    Farm.Config.Mode,
                    Farm.Config.Profile,
                    world,
                    level,
                    nextText,
                    rebirths,
                    formatNumber(wins),
                    tostring(speedMulti),
                    tostring(winsMulti),
                    Farm.CurrentAction
                ),
            })
        end)

        pcall(function()
            MetricsParagraph:Set({
                Title = "Session Metrics",
                Content = string.format(
                    "Return touches: %d • Verified payouts: %d • Failed cycles: %d\nCheckpoints primed: %d • Speed bursts: %d • Rebirths: %d\nWorld switches: %d • Upgrades: %d • Shards: %d/9\nRewards: %d • Potions: %d • Codes: %d\nWin target: %s\nTreadmill: %s",
                    Farm.Metrics.WinTouches,
                    Farm.Metrics.WinPayouts,
                    Farm.Metrics.WinTouchFailures,
                    Farm.Metrics.CheckpointsPrimed,
                    Farm.Metrics.TreadmillBursts,
                    Farm.Metrics.Rebirths,
                    Farm.Metrics.WorldSwitches,
                    Farm.Metrics.Upgrades,
                    countShards(),
                    Farm.Metrics.RewardsClaimed,
                    Farm.Metrics.PotionUses,
                    Farm.Metrics.CodesAttempted,
                    Farm.CurrentWinButton,
                    Farm.CurrentTreadmill
                ),
            })
        end)

        task.wait(0.75)
    end
end)

-- ============================================================================
-- INITIAL FREE ROUTE CHECK
-- ============================================================================

task.spawn(function()
    task.wait(0.75)

    if Farm.Running then
        requestOffline()
    end
end)

PuckUI:Notify({
    Title = "RAINZXDEV",
    Content = "+1 Speed Monkey Escape farm loaded. Press MAX MONEY or enable Master Autofarm.",
    Duration = 4,
})
