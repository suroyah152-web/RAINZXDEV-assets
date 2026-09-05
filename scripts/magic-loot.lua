--[[
    RAINZXDEV | Magic Loot | Autofarm v4.7 RELEASE
    Place: 133188236593503
    Release build with responsive desktop / phone interface.
]]
local EXPECTED_PLACE_ID = 133188236593503
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
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
local SCRIPT_KEY = "__rainzxdev_MAGIC_LOOT_DIRECT_V4_7"
for _, oldKey in ipairs({
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_6",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_5",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_4",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_3",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_2_1",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_2",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_1",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V4_0",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_9",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_8",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_7",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_6",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_5",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_4_2",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_4_1",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_4",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_3",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_2",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_1",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V3_0",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_9",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_8",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_7",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_6",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_5",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_4",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_2",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_1",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V2_0",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_9",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_8",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_5",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_4",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_3",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_2",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_1",
    "__rainzxdev_MAGIC_LOOT_DIRECT_V1_0",
    SCRIPT_KEY,
}) do
    if type(GENV[oldKey]) == "table" and type(GENV[oldKey].Unload) == "function" then
        pcall(function()
            GENV[oldKey]:Unload()
        end)
    end
end
-- ============================================================================
-- GAME MODULES
-- ============================================================================
local UtilsSystem
local okUtils, utilsResult = pcall(function()
    return require(ReplicatedFirst:WaitForChild("AllSideCode", 20):WaitForChild("UtilsSystem", 20))
end)
if okUtils then
    UtilsSystem = utilsResult
end
if type(UtilsSystem) ~= "table" then
    return
end
local GetData = UtilsSystem.GetData
local CfgFind = UtilsSystem.CfgFind
local EnumMgr = UtilsSystem.EnumMgr
local NetMsg = UtilsSystem.NetMsg
local NetWork = UtilsSystem.NetWork
local PlayerData = UtilsSystem.PlayerData
local EquipShop = UtilsSystem.EquipShop
local UIMgr = UtilsSystem.UIMgr
local HumanModule = UtilsSystem.HumanModule
local SystemDungeon = UtilsSystem.SystemDungeon
local DwarfKingAppearPresentation = UtilsSystem.DwarfKingAppearPresentation
if type(NetMsg) ~= "table" or type(NetWork) ~= "table" then
    return
end
local PlayerSkillControlHub = nil
local SkillCommon = nil
pcall(function()
    local clientSide = ReplicatedStorage:FindFirstChild("ClientSideCode")
    local systemSkill = clientSide and clientSide:FindFirstChild("SystemSkill")
    local hubModule = systemSkill and systemSkill:FindFirstChild("PlayerSkillControlHub")
    if hubModule and hubModule:IsA("ModuleScript") then
        PlayerSkillControlHub = require(hubModule)
    end
    local skillModule = systemSkill and systemSkill:FindFirstChild("SkillModule")
    local templates = skillModule and skillModule:FindFirstChild("_Templates")
    local commonModule = templates and templates:FindFirstChild("SkillCommon")
    if commonModule and commonModule:IsA("ModuleScript") then
        SkillCommon = require(commonModule)
    end
end)
pcall(function()
    if PlayerSkillControlHub and type(PlayerSkillControlHub.setDebugAutoAttackEnabled) == "function" then
        PlayerSkillControlHub.setDebugAutoAttackEnabled(true)
    end
end)
local IndexView = nil
pcall(function()
    local clientSide = ReplicatedStorage:FindFirstChild("ClientSideCode")
    local guiScripts = clientSide and clientSide:FindFirstChild("GuiScripts")
    local moduleRoot = guiScripts and guiScripts:FindFirstChild("ModuleScript")
    local indexRoot = moduleRoot and moduleRoot:FindFirstChild("Index")
    local indexModule = indexRoot and indexRoot:FindFirstChild("IndexView")
    if indexModule and indexModule:IsA("ModuleScript") then
        IndexView = require(indexModule)
    end
end)
-- ============================================================================
-- PUCK UI
-- ============================================================================
local PuckUI = nil
local Window = nil
local function loadPuckUI()
    local compiler = loadstring or load
    if type(compiler) ~= "function" then
        return nil
    end
    local okSource, source = pcall(function()
        return game:HttpGet("https://rainzxdev.site/ui/PuckUI.lua")
    end)
    if not okSource or type(source) ~= "string" or #source < 100 then
        return nil
    end
    local chunk = compiler(source)
    if not chunk then
        return nil
    end
    local okUi, result = pcall(chunk)
    if not okUi or type(result) ~= "table" or type(result.CreateWindow) ~= "function" then
        return nil
    end
    return result
end
PuckUI = loadPuckUI()
-- ============================================================================
-- STATE
-- ============================================================================
local Farm = {
    Running = true,
    Connections = {},
    Config = {
        Master = true,
        AutoTrain = true,
        SmartTraining = true,
        AutoRebirth = true,
        IncludeCurrentPaidZone = true,
        AutoWeapon = true,
        AutoHoldBestWand = true,
        AutoArmor = true,
        AutoBroom = true,
        AutoTrainingPotion = true,
        AutoLuckPotion = true,
        AutoDungeonEconomy = true,
        AutoDungeonLoot = true,
        AutoSellMaterials = true,
        AutoSellThresholdPercent = 100,
        BackpackReserveSlots = 0,
        LootPriority = "Smart",
        PrioritizeUnseenIndexLoot = false,
        SmartLootQualityPercent = 65,
        SmartLootBatchWaitSeconds = 0.35,
        SmartLootDeepStagePercent = 82,
        SmartLootFinalHarvestSeconds = 6.0,
        SmartLootAlwaysRarity = 5,
        TemporarilyUnmarkAlchemyForSell = true,
        ResumeDungeonAfterSell = true,
        DungeonBurstSeconds = 28,
        DungeonCooldownSeconds = 28,
        DungeonReentryAttempts = 3,
        DungeonReentryDelay = 0.20,
        DungeonEnemyRange = 19,
        DungeonPositionMode = "Overhead",
        DungeonOrbitSpeed = 0.65,
        CombatDirectLock = true,
        CombatNoclip = true,
        CombatFaceTarget = true,
        PersistCombatPosition = true,
        TargetSwitchGraceSeconds = 0.20,
        WaitForBossIntro = true,
        AutoCodes = true,
        AutoDaily = true,
        AutoOnline = true,
        AutoEventQuestClaims = true,
        AutoFarmEventQuests = false,
        AutoIndexRewards = true,
        MovementMode = "Tween",
        TweenSpeed = 85,
        WalkTimeout = 16,
    },
    Runtime = {
        Phase = "Starting",
        TrainSource = "None",
        TrainGain = 0,
        TrainClicks = 0,
        Rebirths = 0,
        GearBuys = 0,
        GearEquips = 0,
        GearAttempts = 0,
        LastGearRemoteResult = "None",
        PotionsUsed = 0,
        MaterialsSold = 0,
        RewardsClaimed = 0,
        EventQuestClaims = 0,
        IndexClaims = 0,
        CodesTried = false,
        DungeonRunning = false,
        DungeonStartedAt = 0,
        LastDungeonAt = -math.huge,
        LastDungeonStage = 0,
        LastDungeonTarget = "None",
        LastCombatPosition = "None",
        LastCombatAnchor = nil,
        LastCombatEnemyPos = nil,
        LastCombatCFrame = nil,
        PositionTarget = nil,
        PositionTargetSince = -math.huge,
        PositionHoldUntil = -math.huge,
        PositionState = "Idle",
        CombatOrbitAngle = 0,
        CombatOrbitTarget = nil,
        CombatNoclipActive = false,
        CombatNoclipCharacter = nil,
        CombatCollisionCache = {},
        CombatAutoRotateBefore = nil,
        LastEnemySeenAt = -math.huge,
        NoEnemySince = nil,
        LastTargetModel = nil,
        LastBossModel = nil,
        BossFirstSeenAt = -math.huge,
        LastGear = "None",
        LastHeldWand = "None",
        LastHeldWandAt = -math.huge,
        LastReward = "None",
        MovementOwner = nil,
        MovementUntil = 0,
        LastManualTrainAt = -math.huge,
        LastGearAt = -math.huge,
        LastPotionAt = -math.huge,
        LastLuckPotionAt = -math.huge,
        LastRewardAt = -math.huge,
        LastQuestAt = -math.huge,
        LastIndexAt = -math.huge,
        LastRebirthAt = -math.huge,
        LastTrainDecisionAt = -math.huge,
        LastSellAt = -math.huge,
        LastSellResult = "None",
        DungeonBagUsed = 0,
        DungeonBagMax = 0,
        DungeonBagPercent = 0,
        BackpackSize = 0,
        BackpackMax = 0,
        BackpackPercent = 0,
        LastLoot = "None",
        LastLootRarity = 0,
        LastLootValue = 0,
        LastLootStage = 0,
        LootDecision = "None",
        LootBatchStage = 0,
        LootBatchReady = false,
        LootBatchCandidateCount = 0,
        LootBatchMaxValue = 0,
        LootBatchThreshold = 0,
        LastQuest = "None",
        LastIndex = "None",
        ActiveEventQuests = 0,
        BackpackBlocked = false,
        BackpackBlockedReason = "None",
        ProtectedBackpackSlots = 0,
        EmergencySellRequested = false,
        Selling = false,
        LastDungeonSpawnAt = -math.huge,
        DungeonSessionDeadline = 0,
        UnexpectedDungeonExits = 0,
        DungeonReentries = 0,
        LastDungeonExitReason = "None",
        SelectedZoneId = 0,
        SelectedZoneMult = 0,
        SelectedMode = "Manual",
        GearFailureCooldown = {},
        GearTransaction = false,
        GearNetworkBusy = false,
        GearSessionActive = false,
        LastNativeShopAction = "None",
        LastGearServerResult = "None",
        LastGearServerPayload = "None",
        LastPhysicalShop = "None",
        LastPhysicalShopDistance = -1,
        LastPhysicalPromptResult = "None",
        LastGearStatePrep = "None",
        LastBuyWireFormat = "None",
        LiveEquippedIds = {},
        LastLiveShopTarget = "None",
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
local function setError(_)
    -- Errors are intentionally not surfaced or retained in the release UI.
end
local function safeInvoke(message, ...)
    if not message then
        return false, nil
    end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return NetWork.InvokeServer(message, table.unpack(args, 1, args.n))
    end)
    if not ok then
        setError(result)
        return false, nil
    end
    return true, result
end
local function safeFire(message, ...)
    if not message then
        return false
    end
    local args = table.pack(...)
    local ok, err = pcall(function()
        NetWork.FireServer(message, table.unpack(args, 1, args.n))
    end)
    if not ok then
        setError(err)
        return false
    end
    return true
end
-- ============================================================================
-- PLAYER DATA HELPERS
-- ============================================================================
local function getCharacter()
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
local function getDataValue(key)
    if PlayerData and type(PlayerData.GetPlrDataByKey) == "function" then
        local ok, result = pcall(PlayerData.GetPlrDataByKey, LocalPlayer, key)
        if ok and result ~= nil then
            return result
        end
    end
    local obj = LocalPlayer:FindFirstChild(key)
    if obj and obj:IsA("ValueBase") then
        return obj.Value
    end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local stat = leaderstats and leaderstats:FindFirstChild(key)
    if stat and stat:IsA("ValueBase") then
        return stat.Value
    end
    return nil
end
local function getNumber(key, default)
    return tonumber(getDataValue(key)) or default or 0
end
local function getItemCountById(itemId)
    if itemId and GetData and type(GetData.GetItemCountByID) == "function" then
        local ok, value = pcall(GetData.GetItemCountByID, LocalPlayer, itemId)
        if ok and tonumber(value) ~= nil then
            return tonumber(value)
        end
    end
    return nil
end
local function getLevel()
    local id = EnumMgr and EnumMgr.ItemID and EnumMgr.ItemID.Level
    local n = getItemCountById(id)
    if n == nil then n = tonumber(getDataValue("Level")) end
    return math.max(1, math.floor(n or 1))
end
local function getRebirth()
    local id = EnumMgr and EnumMgr.ItemID and EnumMgr.ItemID.Rebirth
    local n = getItemCountById(id)
    if n == nil then n = tonumber(getDataValue("Rebirth")) end
    if n == nil then n = tonumber(getDataValue("Rebirths")) end
    return math.max(0, math.floor(n or 0))
end
local function getGold()
    local id = EnumMgr and EnumMgr.ItemID and EnumMgr.ItemID.Coin
    local n = nil
    if id then
        local bagFolder = LocalPlayer:FindFirstChild("Bag")
        local coinValue = bagFolder and bagFolder:FindFirstChild(tostring(id))
        if coinValue and coinValue:IsA("ValueBase") then
            n = tonumber(coinValue.Value)
        end
    end
    if n == nil and id and GetData and GetData.Bag and type(GetData.Bag.GetItemCountByID) == "function" then
        local ok, value = pcall(GetData.Bag.GetItemCountByID, LocalPlayer, id)
        if ok then n = tonumber(value) end
    end
    if n == nil then n = getItemCountById(id) end
    if n == nil then n = tonumber(getDataValue("Gold")) end
    if n == nil then n = tonumber(getDataValue("Coin")) end
    if n == nil then n = tonumber(getDataValue("Coins")) end
    return math.max(0, n or 0)
end
local function isInDungeon()
    if GetData and type(GetData.IsInDungeonChallenge) == "function" then
        local ok, result = pcall(GetData.IsInDungeonChallenge, LocalPlayer)
        if ok then
            return result == true
        end
    end
    local value = LocalPlayer:FindFirstChild("InDungeonChallenge")
    return value and value:IsA("NumberValue") and value.Value > 0 or false
end
local function isStageJumping()
    local value = LocalPlayer:FindFirstChild("StageJumping")
    return value and value:IsA("NumberValue") and value.Value > 0 or false
end
local function dungeonTransitionActive()
    return isInDungeon() or isStageJumping()
end
local function getRunMaxClear()
    local value = LocalPlayer:FindFirstChild("DungeonRunMaxClear")
    if value and value:IsA("NumberValue") then
        return math.max(0, math.floor(value.Value))
    end
    return math.max(0, math.floor(getNumber("DungeonRunMaxClear", 0)))
end
local function getCareerMaxStage()
    local value = LocalPlayer:FindFirstChild("CareerMaxStage")
    if value and value:IsA("NumberValue") then
        return math.max(0, math.floor(value.Value))
    end
    return math.max(0, math.floor(getNumber("CareerMaxStage", 0)))
end
local function getCurrentTrainId()
    local value = LocalPlayer:FindFirstChild("TrainGroundId")
    if value and value:IsA("NumberValue") then
        return math.floor(value.Value)
    end
    return 0
end
local function isInTrainGround()
    local value = LocalPlayer:FindFirstChild("InTrainGround")
    return value and value:IsA("BoolValue") and value.Value == true or false
end
local function isAutoTraining()
    local value = LocalPlayer:FindFirstChild("IsAutoTraining")
    return value and value:IsA("BoolValue") and value.Value == true or false
end
local function getBag()
    local bag = getDataValue("Bag")
    return type(bag) == "table" and bag or {}
end
local function isLocked(item)
    if type(item) ~= "table" then
        return false
    end
    return item.lock == true or tonumber(item.lock) == 1
end
local function getWarehouseUsage()
    local current, maximum = nil, nil
    if GetData and type(GetData.GetBackpackWarehouseCurrentSize) == "function" then
        local ok, value = pcall(GetData.GetBackpackWarehouseCurrentSize, LocalPlayer)
        if ok then
            current = tonumber(value)
        end
    end
    if GetData and type(GetData.GetBackpackWarehouseMaxSize) == "function" then
        local ok, value = pcall(GetData.GetBackpackWarehouseMaxSize)
        if ok then
            maximum = tonumber(value)
        end
    end
    if current == nil then
        current = 0
        local materialType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Material or nil
        local potionType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Potion or nil
        for _, item in pairs(getBag()) do
            if type(item) == "table" then
                local tp = tonumber(item.tp)
                if materialType and tp == tonumber(materialType) then
                    current = current + 1
                elseif potionType and tp == tonumber(potionType) then
                    local count = math.max(1, math.floor(tonumber(item.count) or 1))
                    current = current + count
                end
            end
        end
    end
    maximum = math.max(1, math.floor(maximum or 999))
    current = math.max(0, math.floor(current or 0))
    local percent = math.clamp((current / maximum) * 100, 0, 100)
    Farm.Runtime.BackpackSize = current
    Farm.Runtime.BackpackMax = maximum
    Farm.Runtime.BackpackPercent = percent
    return current, maximum, percent
end
local function getDungeonBagUsage()
    local usedObj = LocalPlayer:FindFirstChild("LimitBagUsed")
    local used = usedObj and tonumber(usedObj.Value) or 0
    local limitId = EnumMgr and EnumMgr.ItemID and EnumMgr.ItemID.LimitBagSize
    local maximum = getItemCountById(limitId)
    if maximum == nil and limitId then
        local bagFolder = LocalPlayer:FindFirstChild("Bag")
        local value = bagFolder and bagFolder:FindFirstChild(tostring(limitId))
        maximum = value and tonumber(value.Value) or nil
    end
    used = math.max(0, math.floor(used or 0))
    maximum = math.max(1, math.floor(maximum or 1))
    local percent = math.clamp((used / maximum) * 100, 0, 100)
    Farm.Runtime.DungeonBagUsed = used
    Farm.Runtime.DungeonBagMax = maximum
    Farm.Runtime.DungeonBagPercent = percent
    return used, maximum, percent
end
local function itemWarehouseOccupancy(item)
    if type(item) ~= "table" then
        return 0
    end
    local tp = tonumber(item.tp)
    local potionType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Potion or nil
    local materialType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Material or nil
    if materialType and tp == tonumber(materialType) then
        return 1
    end
    if potionType and tp == tonumber(potionType) then
        local stackable = false
        if GetData and type(GetData.IsItemStackable) == "function" and CfgFind and type(CfgFind.FindCfgByID) == "function" then
            local okCfg, cfg = pcall(CfgFind.FindCfgByID, tonumber(item.id), potionType)
            if okCfg and cfg then
                local okStack, value = pcall(GetData.IsItemStackable, cfg)
                stackable = okStack and value == true
            end
        end
        if stackable then
            return math.max(1, math.floor(tonumber(item.count) or 1))
        end
        return 1
    end
    return 0
end
local function getMarkedRecipeId()
    local alchemy = GetData and GetData.Alchemy or nil
    if alchemy and type(alchemy.GetMarkedRecipeId) == "function" then
        local ok, value = pcall(alchemy.GetMarkedRecipeId, LocalPlayer)
        if ok then
            return math.max(0, math.floor(tonumber(value) or 0))
        end
    end
    return math.max(0, math.floor(tonumber(getDataValue("AlchemyMarkRecipeId")) or 0))
end
local function getBackpackBreakdown()
    local sellable, marked, locked, potions = 0, 0, 0, 0
    local materialType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Material or nil
    local potionType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Potion or nil
    local alchemy = GetData and GetData.Alchemy or nil
    for _, item in pairs(getBag()) do
        if type(item) == "table" then
            local occ = itemWarehouseOccupancy(item)
            local tp = tonumber(item.tp)
            if potionType and tp == tonumber(potionType) then
                potions = potions + occ
            elseif materialType and tp == tonumber(materialType) then
                if isLocked(item) then
                    locked = locked + occ
                else
                    local protected = false
                    local id = tonumber(item.id)
                    if id and alchemy and type(alchemy.IsMarkedRecipeMaterial) == "function" then
                        local ok, value = pcall(alchemy.IsMarkedRecipeMaterial, LocalPlayer, id)
                        protected = ok and value == true
                    end
                    if protected then
                        marked = marked + occ
                    else
                        sellable = sellable + occ
                    end
                end
            end
        end
    end
    Farm.Runtime.ProtectedBackpackSlots = marked + locked + potions
    return sellable, marked, locked, potions
end
local function backpackPressureReached()
    local current, maximum, percent = getDungeonBagUsage()
    local threshold = math.clamp(tonumber(Farm.Config.AutoSellThresholdPercent) or 100, 50, 100)
    local reserve = math.clamp(math.floor(tonumber(Farm.Config.BackpackReserveSlots) or 0), 0, math.max(0, maximum - 1))
    local hardLimit = math.max(1, maximum - reserve)
    return current >= maximum or current >= hardLimit or percent >= threshold, current, maximum, percent
end
local function backpackNeedsSell()
    if not (Farm.Config.Master and Farm.Config.AutoSellMaterials) then
        return false
    end
    local pressure = backpackPressureReached()
    return pressure == true
end
-- ============================================================================
-- MOVEMENT (NO SNAP TELEPORTS)
-- ============================================================================
local function movementBusy(owner)
    local active = Farm.Runtime.MovementOwner
    if active and os.clock() >= (Farm.Runtime.MovementUntil or 0) then
        Farm.Runtime.MovementOwner = nil
        Farm.Runtime.MovementUntil = 0
        active = nil
    end
    return active ~= nil and active ~= owner
end
local function acquireMovement(owner, timeout)
    if movementBusy(owner) then
        return false
    end
    Farm.Runtime.MovementOwner = owner
    Farm.Runtime.MovementUntil = os.clock() + (tonumber(timeout) or 20)
    return true
end
local function releaseMovement(owner)
    if Farm.Runtime.MovementOwner == owner then
        Farm.Runtime.MovementOwner = nil
        Farm.Runtime.MovementUntil = 0
    end
end
local function horizontalDistance(a, b)
    return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end
local function walkTo(position, reach, timeout)
    local character, humanoid, root = getCharacter()
    if not character then
        return false
    end
    reach = tonumber(reach) or 4
    timeout = tonumber(timeout) or Farm.Config.WalkTimeout
    local start = os.clock()
    local lastPos = root.Position
    local lastMoved = os.clock()
    humanoid.Sit = false
    humanoid.PlatformStand = false
    while Farm.Running and os.clock() - start < timeout do
        character, humanoid, root = getCharacter()
        if not character then
            return false
        end
        if horizontalDistance(root.Position, position) <= reach and math.abs(root.Position.Y - position.Y) <= 10 then
            humanoid:Move(Vector3.zero, false)
            return true
        end
        humanoid:MoveTo(position)
        if (root.Position - lastPos).Magnitude > 1 then
            lastPos = root.Position
            lastMoved = os.clock()
        elseif os.clock() - lastMoved > 1.15 then
            humanoid.Jump = true
            lastMoved = os.clock()
            lastPos = root.Position
        end
        task.wait(0.07)
    end
    return false
end
local function tweenTo(position, reach, timeout)
    local character, humanoid, root = getCharacter()
    if not character then
        return false
    end
    reach = tonumber(reach) or 3
    timeout = tonumber(timeout) or 20
    local distance = (root.Position - position).Magnitude
    if distance <= reach then
        return true
    end
    local speed = math.max(10, tonumber(Farm.Config.TweenSpeed) or 85)
    local duration = math.max(0.08, distance / speed)
    if duration > timeout then
        duration = timeout
    end
    humanoid.Sit = false
    humanoid.PlatformStand = false
    local look = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.01 then
        flatLook = Vector3.new(0, 0, -1)
    else
        flatLook = flatLook.Unit
    end
    local targetCF = CFrame.lookAt(position, position + flatLook)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCF })
    tween:Play()
    local finished = false
    local conn
    conn = tween.Completed:Connect(function()
        finished = true
        if conn then
            conn:Disconnect()
        end
    end)
    local started = os.clock()
    while Farm.Running and not finished and os.clock() - started < timeout + 0.5 do
        local _, h, r = getCharacter()
        if not r then
            pcall(function() tween:Cancel() end)
            return false
        end
        if (r.Position - position).Magnitude <= reach then
            pcall(function() tween:Cancel() end)
            return true
        end
        task.wait(0.04)
    end
    local _, _, finalRoot = getCharacter()
    return finalRoot ~= nil and (finalRoot.Position - position).Magnitude <= math.max(reach, 5)
end
local function moveTo(position, reach, timeout)
    if Farm.Config.MovementMode == "Walk" then
        return walkTo(position, reach, timeout)
    end
    return tweenTo(position, reach, timeout)
end
local function combatTweenTo(position, lookAtPosition, timeout)
    local character, humanoid, root = getCharacter()
    if not character then
        return false
    end
    local distance = (root.Position - position).Magnitude
    if distance <= 2.25 then
        return true
    end
    humanoid.Sit = false
    humanoid.PlatformStand = false
    local speed = math.max(18, tonumber(Farm.Config.TweenSpeed) or 85)
    local duration = math.clamp(distance / speed, 0.06, math.min(0.55, tonumber(timeout) or 0.55))
    local lookAt = lookAtPosition
    if typeof(lookAt) ~= "Vector3" or (lookAt - position).Magnitude < 0.05 then
        lookAt = position + root.CFrame.LookVector
    end
    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = CFrame.lookAt(position, lookAt) }
    )
    tween:Play()
    local started = os.clock()
    while Farm.Running and os.clock() - started < duration + 0.12 do
        local _, _, liveRoot = getCharacter()
        if not liveRoot then
            pcall(function() tween:Cancel() end)
            return false
        end
        if (liveRoot.Position - position).Magnitude <= 2.5 then
            return true
        end
        task.wait(0.025)
    end
    local _, _, finalRoot = getCharacter()
    return finalRoot ~= nil and (finalRoot.Position - position).Magnitude <= 4
end
local function isPointInsidePart(part, position)
    if not part or not part:IsA("BasePart") then
        return false
    end
    local localPos = part.CFrame:PointToObjectSpace(position)
    local half = part.Size * 0.5
    return math.abs(localPos.X) <= half.X
        and math.abs(localPos.Y) <= half.Y + 3
        and math.abs(localPos.Z) <= half.Z
end
-- ============================================================================
-- SMART TRAINING
-- ============================================================================
local TRAIN_ZONES = {
    { id = 1, mult = 1.5, rebirth = 0 },
    { id = 2, mult = 2, rebirth = 2 },
    { id = 3, mult = 4, rebirth = 5 },
    { id = 4, mult = 6, rebirth = 9 },
    { id = 5, mult = 8, rebirth = 12 },
    { id = 7, mult = 15, rebirth = 18 },
    { id = 10, mult = 20, rebirth = 24 },
}
local PAID_ZONES = {
    [6] = 10,
    [8] = 25,
    [9] = 100,
}
local MANUAL_TICKS_PER_SECOND = 1 / 0.15
local function getTrainZonePart(id)
    if not (GetData and GetData.Train and type(GetData.Train.FindZonePartByTrainId) == "function") then
        return nil
    end
    local ok, part = pcall(GetData.Train.FindZonePartByTrainId, id)
    if ok and part and part:IsA("BasePart") then
        return part
    end
    return nil
end
local function adminTrainReady()
    local part = getTrainZonePart(1000)
    if not part then
        return false
    end
    local node = part
    while node and node ~= Workspace do
        local attr = node:GetAttribute("AdminAbuseTrainReady")
        if attr ~= nil then
            return attr == true
        end
        node = node.Parent
    end
    return false
end
local function chooseTrainingSource()
    local rebirth = getRebirth()
    local bestId = 0
    local bestMult = 0
    local bestRate = MANUAL_TICKS_PER_SECOND
    if adminTrainReady() then
        return "Zone", 1000, 1000, 2000
    end
    for _, zone in ipairs(TRAIN_ZONES) do
        if rebirth >= zone.rebirth then
            local part = getTrainZonePart(zone.id)
            if part then
                local rate = zone.mult * 2
                if rate > bestRate then
                    bestRate = rate
                    bestId = zone.id
                    bestMult = zone.mult
                end
            end
        end
    end
    if Farm.Config.IncludeCurrentPaidZone then
        local current = getCurrentTrainId()
        local paidMult = PAID_ZONES[current]
        if paidMult and getTrainZonePart(current) then
            local rate = paidMult * 2
            if rate > bestRate then
                bestRate = rate
                bestId = current
                bestMult = paidMult
            end
        end
    end
    if bestId > 0 then
        return "Zone", bestId, bestMult, bestRate
    end
    return "Manual", 0, 0, MANUAL_TICKS_PER_SECOND
end
local function leaveTrainZoneForManual()
    if not isInTrainGround() and getCurrentTrainId() <= 0 then
        return true
    end
    if not acquireMovement("Training", 15) then
        return false
    end
    local current = getCurrentTrainId()
    local part = current > 0 and getTrainZonePart(current) or nil
    if part then
        local outsideLocal = Vector3.new(part.Size.X * 0.5 + 7, 2, 0)
        local outside = part.CFrame:PointToWorldSpace(outsideLocal)
        moveTo(outside, 3, 12)
    end
    safeFire(NetMsg.TRAIN_ZONE_UPDATE, { trainId = nil })
    task.wait(0.12)
    releaseMovement("Training")
    return not isInTrainGround()
end
local function enterTrainZone(id)
    local part = getTrainZonePart(id)
    if not part then
        return false
    end
    if getCurrentTrainId() == id and isAutoTraining() then
        return true
    end
    if not acquireMovement("Training", 20) then
        return false
    end
    local target = part.Position + Vector3.new(0, math.min(2, math.max(0.5, part.Size.Y * 0.25)), 0)
    setPhase("Moving to training x" .. tostring(Farm.Runtime.SelectedZoneMult))
    local moved = moveTo(target, math.max(2, math.min(part.Size.X, part.Size.Z) * 0.25), 18)
    local _, _, root = getCharacter()
    if moved and root and isPointInsidePart(part, root.Position) then
        safeFire(NetMsg.TRAIN_ZONE_UPDATE, { trainId = id })
        local deadline = os.clock() + 0.90
        while Farm.Running and os.clock() < deadline do
            if getCurrentTrainId() == id or isAutoTraining() then
                releaseMovement("Training")
                return true
            end
            task.wait(0.08)
        end
    end
    releaseMovement("Training")
    return getCurrentTrainId() == id or isAutoTraining()
end
local function refreshTrainingDecision(force)
    if Farm.Runtime.GearTransaction then
        return
    end
    if not Farm.Config.AutoTrain or not Farm.Config.Master or isInDungeon() then
        return
    end
    local now = os.clock()
    if not force and now - Farm.Runtime.LastTrainDecisionAt < 1.0 then
        return
    end
    Farm.Runtime.LastTrainDecisionAt = now
    local mode, zoneId, mult = chooseTrainingSource()
    Farm.Runtime.SelectedMode = mode
    Farm.Runtime.SelectedZoneId = zoneId
    Farm.Runtime.SelectedZoneMult = mult
    if mode == "Manual" then
        Farm.Runtime.TrainSource = "Manual wand (0.15s)"
        if isInTrainGround() or getCurrentTrainId() > 0 then
            leaveTrainZoneForManual()
        end
    else
        Farm.Runtime.TrainSource = "Training zone x" .. tostring(mult)
        if getCurrentTrainId() ~= zoneId or not isAutoTraining() then
            enterTrainZone(zoneId)
        end
    end
end
local function manualTrainTick()
    if Farm.Runtime.GearNetworkBusy then return false end
    if not (Farm.Config.Master and Farm.Config.AutoTrain) then
        return false
    end
    if isInTrainGround() or isAutoTraining() then
        return false
    end
    local now = os.clock()
    if now - Farm.Runtime.LastManualTrainAt < 0.152 then
        return false
    end
    Farm.Runtime.LastManualTrainAt = now
    local ok, result = safeInvoke(NetMsg.TRAIN_MANUAL_CLICK, {})
    if not ok or type(result) ~= "table" or result.ok ~= true then
        return false
    end
    local gain = tonumber(result.gain) or 0
    if gain > 0 then
        Farm.Runtime.TrainSource = "Manual Power (global)"
        Farm.Runtime.TrainGain = gain
        Farm.Runtime.TrainClicks = Farm.Runtime.TrainClicks + 1
        return true
    end
    return false
end
-- ============================================================================
-- REBIRTH
-- ============================================================================
local function getNextRebirthCfg()
    if not (CfgFind and type(CfgFind.GetCfgByNameAndID) == "function") then
        return nil
    end
    local ok, cfg = pcall(CfgFind.GetCfgByNameAndID, "rebirthConf", getRebirth() + 1)
    return ok and cfg or nil
end
local function tryRebirth()
    if Farm.Runtime.GearTransaction then return false end
    if not (Farm.Config.Master and Farm.Config.AutoRebirth) or isInDungeon() then
        return false
    end
    local cfg = getNextRebirthCfg()
    if type(cfg) ~= "table" then
        return false
    end
    local need = math.floor(tonumber(cfg.LvNeed) or math.huge)
    if getLevel() < need then
        return false
    end
    local old = getRebirth()
    setPhase("Rebirthing")
    local ok, result = safeInvoke(NetMsg.PLAYER_REBIRTH)
    if ok and result then
        local deadline = os.clock() + 2
        while Farm.Running and os.clock() < deadline do
            if getRebirth() > old then
                Farm.Runtime.Rebirths = Farm.Runtime.Rebirths + 1
                Farm.Runtime.LastTrainDecisionAt = -math.huge
                setPhase("Rebirth complete")
                return true
            end
            task.wait(0.08)
        end
        Farm.Runtime.LastTrainDecisionAt = -math.huge
        return true
    end
    return false
end
-- ============================================================================
-- EQUIPMENT SHOP
-- ============================================================================
local function equippedId(saveKey)
    if EquipShop and type(EquipShop.GetEquippedCfgId) == "function" then
        local ok, id = pcall(EquipShop.GetEquippedCfgId, LocalPlayer, saveKey)
        if ok and tonumber(id) then
            return tonumber(id)
        end
    end
    return tonumber(getDataValue(saveKey)) or 0
end
local function ownsItem(id, itemType)
    id = tonumber(id)
    itemType = tonumber(itemType) or itemType
    if EquipShop and type(EquipShop.GetSaveKey) == "function" then
        local okKey, saveKey = pcall(EquipShop.GetSaveKey, itemType)
        if okKey and saveKey and equippedId(saveKey) == id then
            return true
        end
    end
    if EquipShop and type(EquipShop.OwnsInBag) == "function" then
        local ok, result = pcall(EquipShop.OwnsInBag, LocalPlayer, id, itemType)
        if ok then
            return result == true
        end
    end
    for _, item in pairs(getBag()) do
        if type(item) == "table" and tonumber(item.id) == tonumber(id) and tonumber(item.tp) == tonumber(itemType) then
            if (tonumber(item.count) or 1) > 0 then
                return true
            end
        end
    end
    return false
end
local function ownsItemNativeBag(id, itemType)
    id = tonumber(id)
    itemType = tonumber(itemType) or itemType
    if EquipShop and type(EquipShop.OwnsInBag) == "function" then
        local ok, result = pcall(EquipShop.OwnsInBag, LocalPlayer, id, itemType)
        if ok then
            return result == true
        end
    end
    for _, item in pairs(getBag()) do
        if type(item) == "table" and tonumber(item.id) == id and tonumber(item.tp) == tonumber(itemType) then
            return true
        end
    end
    return false
end
local function buildShop(confName)
    if not (EquipShop and type(EquipShop.BuildShopList) == "function") then
        return {}
    end
    local ok, list = pcall(EquipShop.BuildShopList, confName)
    return ok and type(list) == "table" and list or {}
end
local function cfgIsBetter(cfg, oldCfg, itemType)
    if not oldCfg then
        return true
    end
    if EquipShop and type(EquipShop.IsAutoEquipBetter) == "function" then
        local ok, result = pcall(EquipShop.IsAutoEquipBetter, cfg, oldCfg, itemType, LocalPlayer)
        if ok then
            return result == true
        end
    end
    return (tonumber(cfg.Price) or 0) > (tonumber(oldCfg.Price) or 0)
end
local function findCfg(id, itemType)
    if EquipShop and type(EquipShop.FindShopCfg) == "function" then
        local ok, cfg = pcall(EquipShop.FindShopCfg, id, itemType)
        if ok and type(cfg) == "table" then
            return cfg
        end
    end
    if CfgFind and type(CfgFind.FindCfgByID) == "function" then
        local ok, cfg = pcall(CfgFind.FindCfgByID, id, itemType)
        if ok and type(cfg) == "table" then
            return cfg
        end
    end
    if CfgFind and type(CfgFind.GetCfgByNameAndID) == "function" and EnumMgr and EnumMgr.ItemType then
        local confName = nil
        if tonumber(itemType) == tonumber(EnumMgr.ItemType.Weapon) then
            confName = "weaponConf"
        elseif tonumber(itemType) == tonumber(EnumMgr.ItemType.Armor) then
            confName = "armorConf"
        elseif tonumber(itemType) == tonumber(EnumMgr.ItemType.Broom) then
            confName = "broomConf"
        end
        if confName then
            local ok, cfg = pcall(CfgFind.GetCfgByNameAndID, confName, tonumber(id) or id)
            if ok and type(cfg) == "table" then
                return cfg
            end
        end
    end
    return nil
end
local function gearAllowedByRebirth(cfg)
    if type(cfg) ~= "table" then
        return false
    end
    local raw = cfg.NeedRebirth
    if raw == nil then raw = cfg.RebirthNeed end
    if raw == nil then raw = cfg.Rebirth end
    if raw == nil then
        return true
    end
    return getRebirth() >= (tonumber(raw) or 0)
end
local function isCoinGear(cfg)
    if type(cfg) ~= "table" then
        return false
    end
    if EquipShop and type(EquipShop.IsCoinPurchasable) == "function" then
        local ok, result = pcall(EquipShop.IsCoinPurchasable, cfg)
        if ok then
            return result == true
        end
    end
    return (tonumber(cfg.Price) or 0) > 0
end
local function gearCooldownKey(itemType, id)
    return tostring(tonumber(itemType) or itemType) .. ":" .. tostring(tonumber(id) or id)
end
local function shopUiNameForType(itemType)
    local n = tonumber(itemType)
    if n == tonumber(EnumMgr.ItemType.Weapon) then return "Weapon" end
    if n == tonumber(EnumMgr.ItemType.Armor) then return "Armor" end
    if n == tonumber(EnumMgr.ItemType.Broom) then return "Broom" end
    return nil
end
-- ============================================================================
-- NATIVE WORLD SHOP ENTRY
-- ============================================================================
local findNativeShopRoot
local PhysicalGearShopCache = {}
local function cachedPhysicalGearShop(shopName)
    local row = PhysicalGearShopCache[shopName]
    if row == false then
        return nil, nil, true
    end
    if row and row.part and row.part.Parent and row.prompt and row.prompt.Parent then
        if tostring(row.part:GetAttribute("UiName") or "") == tostring(shopName) then
            return row.prompt, row.part, false
        end
    end
    PhysicalGearShopCache[shopName] = nil
    return nil, nil, false
end
local function findPhysicalGearShop(shopName, timeout)
    local prompt, part, knownMissing = cachedPhysicalGearShop(shopName)
    if prompt and part then
        return prompt, part
    end
    if knownMissing then
        return nil, nil
    end
    local deadline = os.clock() + math.max(0.08, tonumber(timeout) or 0.75)
    repeat
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local uiName = tostring(obj:GetAttribute("UiName") or "")
                if uiName == "Weapon" or uiName == "Armor" or uiName == "Broom" then
                    local p = obj:FindFirstChildOfClass("ProximityPrompt")
                    if p then
                        PhysicalGearShopCache[uiName] = { prompt = p, part = obj }
                        if uiName == shopName then
                            return p, obj
                        end
                    end
                end
            end
        end
        task.wait(0.03)
    until not Farm.Running or os.clock() >= deadline
    PhysicalGearShopCache[shopName] = false
    return nil, nil
end
local function triggerPhysicalShopPrompt(prompt)
    if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then
        return false, "prompt unavailable"
    end
    if type(fireproximityprompt) == "function" then
        local ok, err = pcall(function()
            fireproximityprompt(prompt)
        end)
        if ok then
            return true, "fireproximityprompt"
        end
        return false, tostring(err)
    end
    local ok, err = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(0.05, (tonumber(prompt.HoldDuration) or 0) + 0.06))
        prompt:InputHoldEnd()
    end)
    return ok, ok and "InputHold" or tostring(err)
end
local function enterPhysicalGearShop(shopName)
    local prompt, part = findPhysicalGearShop(shopName, 0.75)
    if not (prompt and part) then
        Farm.Runtime.LastPhysicalShop = shopName .. " prompt not found"
        Farm.Runtime.LastPhysicalPromptResult = "not found"
        local knownPhysical = shopName == "Weapon" or shopName == "Armor"
        return nil, knownPhysical, knownPhysical and "physical prompt not replicated" or "no physical prompt"
    end
    Farm.Runtime.LastPhysicalShop = part:GetFullName()
    local _, _, root = getCharacter()
    if not root then
        return nil, true, "character unavailable"
    end
    local maxDistance = math.max(5, tonumber(prompt.MaxActivationDistance) or 10)
    local distance = (root.Position - part.Position).Magnitude
    Farm.Runtime.LastPhysicalShopDistance = distance
    if distance > math.max(3, maxDistance * 0.72) then
        if not acquireMovement("GearShop", 24) then
            Farm.Runtime.LastPhysicalPromptResult = "movement busy: " .. tostring(Farm.Runtime.MovementOwner)
            return nil, true, "movement busy"
        end
        setPhase("Moving to real " .. shopName .. " shop")
        local yOffset = math.clamp(part.Size.Y * 0.5 + 1.5, 1.5, 4)
        local target = part.Position + Vector3.new(0, yOffset, 0)
        local moved = moveTo(target, math.max(1.75, maxDistance * 0.38), 20)
        releaseMovement("GearShop")
        if not moved then
            Farm.Runtime.LastPhysicalPromptResult = "could not reach shop"
            return nil, true, "could not reach physical shop"
        end
        _, _, root = getCharacter()
        if not root then
            return nil, true, "character lost at shop"
        end
        distance = (root.Position - part.Position).Magnitude
        Farm.Runtime.LastPhysicalShopDistance = distance
    end
    if distance > maxDistance + 1.5 then
        Farm.Runtime.LastPhysicalPromptResult = string.format("too far %.1f/%.1f", distance, maxDistance)
        return nil, true, "outside prompt range"
    end
    local promptOk, promptResult = triggerPhysicalShopPrompt(prompt)
    Farm.Runtime.LastPhysicalPromptResult = string.format(
        "%s @ %.1f studs (%s)", tostring(promptOk), distance, tostring(promptResult)
    )
    local deadline = os.clock() + 1.35
    while Farm.Running and os.clock() < deadline do
        local rootUi = findNativeShopRoot and findNativeShopRoot(shopName) or nil
        if rootUi and rootUi:IsA("GuiObject") and rootUi.Visible then
            return rootUi, true, "opened by physical prompt"
        end
        task.wait(0.012)
    end
    return nil, true, promptOk and "real prompt fired; waiting for real UI" or "real prompt input failed"
end
findNativeShopRoot = function(shopName)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local sg = pg and pg:FindFirstChild("ScreenGui")
    return sg and sg:FindFirstChild(shopName) or nil
end
local function nativeShopRootVisible(root)
    return root ~= nil
        and root.Parent ~= nil
        and root:IsA("GuiObject")
        and root.Visible == true
end
local function openNativeShop(shopName)
    if not shopName then
        return nil
    end
    local existing = findNativeShopRoot(shopName)
    if nativeShopRootVisible(existing) then
        Farm.Runtime.LastNativeShopAction = shopName .. " real UI already open"
        return existing
    end
    local physicalRoot, hasPhysicalPrompt, physicalReason = enterPhysicalGearShop(shopName)
    if physicalRoot then
        Farm.Runtime.LastNativeShopAction = shopName .. " opened through real prompt"
        return physicalRoot
    end
    if hasPhysicalPrompt then
        Farm.Runtime.LastNativeShopAction = shopName .. " waiting for real UI: " .. tostring(physicalReason)
        return nil
    end
    if not (NetMsg.SHOW_LOCAL_UI and NetWork and type(NetWork.FireBindable) == "function") then
        return nil
    end
    Farm.Runtime.LastNativeShopAction = shopName .. " has no physical prompt; local UI fallback"
    pcall(function()
        NetWork.FireBindable(NetMsg.SHOW_LOCAL_UI, shopName, nil, true, true)
    end)
    local deadline = os.clock() + 0.65
    while Farm.Running and os.clock() < deadline do
        local root = findNativeShopRoot(shopName)
        if nativeShopRootVisible(root) then
            return root
        end
        task.wait(0.012)
    end
    return findNativeShopRoot(shopName)
end
local function closeNativeShop(shopName)
    if not shopName then return end
    local root = findNativeShopRoot(shopName)
    if root and root:IsA("GuiObject") and root.Visible then
        pcall(function() root.Visible = false end)
    end
    if NetMsg.SHOW_LOCAL_UI and NetWork and type(NetWork.FireBindable) == "function" then
        pcall(function()
            NetWork.FireBindable(NetMsg.SHOW_LOCAL_UI, shopName, nil, false, true)
        end)
    end
    if UIMgr then
        if type(UIMgr.SetMainUIVisible) == "function" then
            pcall(UIMgr.SetMainUIVisible, true)
        end
        if type(UIMgr.UpdateBlurVisible) == "function" then
            pcall(UIMgr.UpdateBlurVisible)
        end
    end
end
local function guiVisibleChainLocal(object)
    local current = object
    while current do
        if current:IsA("GuiObject") and current.Visible == false then return false end
        if current:IsA("LayerCollector") and current.Enabled == false then return false end
        current = current.Parent
    end
    return true
end
local function liveShopEquippedId(root)
    if not nativeShopRootVisible(root) then return nil, nil end
    for _, frame in ipairs(root:GetDescendants()) do
        if frame:IsA("GuiObject") then
            local idText = string.match(frame.Name, "^Equip_(%d+)$")
            if idText then
                for _, obj in ipairs(frame:GetDescendants()) do
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox"))
                        and guiVisibleChainLocal(obj) then
                        local text = string.lower(tostring(obj.Text or ""))
                        if string.find(text, "equipped", 1, true) then
                            return tonumber(idText), frame
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end
local function confNameToShopName(confName)
    if confName == "weaponConf" then return "Weapon" end
    if confName == "armorConf" then return "Armor" end
    if confName == "broomConf" then return "Broom" end
    return nil
end
local function rememberLiveEquipped(confName, root)
    local liveId = select(1, liveShopEquippedId(root))
    if liveId then Farm.Runtime.LiveEquippedIds[confName] = liveId end
    return liveId
end
local function resolveLiveNextShopTarget(root, itemType, confName)
    if not nativeShopRootVisible(root) then return nil end
    local currentId = rememberLiveEquipped(confName, root)
    if not currentId then
        Farm.Runtime.LastLiveShopTarget = tostring(confName) .. ": no visible Equipped card"
        return nil
    end
    local list = buildShop(confName)
    local currentSort = 0
    for _, entry in ipairs(list) do
        if tonumber(entry.id) == currentId then
            currentSort = tonumber(entry.cfg and entry.cfg.Sort) or 0
            break
        end
    end
    if currentSort <= 0 then
        local cfg = findCfg(currentId, itemType)
        currentSort = tonumber(cfg and cfg.Sort) or 0
    end
    local candidates = {}
    for _, entry in ipairs(list) do
        local id = tonumber(entry.id)
        local cfg = entry.cfg
        local sort = tonumber(cfg and cfg.Sort) or 0
        local price = tonumber(cfg and cfg.Price) or 0
        local liveCard = id and root:FindFirstChild("Equip_" .. tostring(id), true) or nil
        if id and cfg and liveCard and sort > currentSort and price > 0
            and isCoinGear(cfg) and gearAllowedByRebirth(cfg)
            and not ownsItem(id, itemType) then
            table.insert(candidates, {id=id,cfg=cfg,sort=sort,price=price})
        end
    end
    table.sort(candidates, function(a,b)
        if a.sort == b.sort then
            if a.price == b.price then return a.id < b.id end
            return a.price < b.price
        end
        return a.sort < b.sort
    end)
    local target = candidates[1]
    Farm.Runtime.LastLiveShopTarget = target and string.format(
        "%s LIVE equipped=%s sort=%s -> target=%s sort=%s price=%s",
        tostring(confName), tostring(currentId), tostring(currentSort),
        tostring(target.id), tostring(target.sort), tostring(target.price)
    ) or string.format("%s LIVE equipped=%s sort=%s -> no target", tostring(confName), tostring(currentId), tostring(currentSort))
    Farm.Runtime.GearResolvedTarget = Farm.Runtime.LastLiveShopTarget
    return target
end
local function confNameForItemType(itemType)
    local n = tonumber(itemType)
    if n == tonumber(EnumMgr.ItemType.Weapon) then return "weaponConf" end
    if n == tonumber(EnumMgr.ItemType.Armor) then return "armorConf" end
    if n == tonumber(EnumMgr.ItemType.Broom) then return "broomConf" end
    return nil
end
local function prepareGearPurchaseState()
    Farm.Runtime.GearTransaction = true
    if dungeonTransitionActive() then
        Farm.Runtime.LastGearStatePrep = "blocked: dungeon/stage transition"
        return false, "dungeon/stage transition active"
    end
    if isInTrainGround() or isAutoTraining() or getCurrentTrainId() > 0 then
        local oldTrain = getCurrentTrainId()
        safeFire(NetMsg.TRAIN_ZONE_UPDATE, { trainId = nil })
        local part = oldTrain > 0 and getTrainZonePart(oldTrain) or nil
        local _, _, root = getCharacter()
        if part and root and isPointInsidePart(part, root.Position) then
            if acquireMovement("GearPrep", 12) then
                local outsideLocal = Vector3.new(part.Size.X * 0.5 + 8, 2, 0)
                local outside = part.CFrame:PointToWorldSpace(outsideLocal)
                moveTo(outside, 3, 10)
                releaseMovement("GearPrep")
            end
        end
        local trainDeadline = os.clock() + 0.45
        while Farm.Running and os.clock() < trainDeadline do
            if not isInTrainGround() and not isAutoTraining() and getCurrentTrainId() <= 0 then
                break
            end
            safeFire(NetMsg.TRAIN_ZONE_UPDATE, { trainId = nil })
            task.wait(0.025)
        end
    end
    local flying = false
    if GetData and type(GetData.GetIsFly) == "function" then
        local okFly, value = pcall(GetData.GetIsFly, LocalPlayer)
        flying = okFly and value == true
    end
    local character = LocalPlayer.Character
    flying = flying or (character and character:GetAttribute("JetPacking") ~= nil) or LocalPlayer:GetAttribute("BroomFly") == true
    if flying and NetMsg.DISMOUNT_BROOM then
        safeInvoke(NetMsg.DISMOUNT_BROOM)
        task.wait(0.04)
    end
    local clean = not dungeonTransitionActive()
        and not isInTrainGround()
        and not isAutoTraining()
        and getCurrentTrainId() <= 0
    Farm.Runtime.LastGearStatePrep = string.format(
        "clean=%s trainId=%s inTrain=%s autoTrain=%s dungeon=%s stage=%s",
        tostring(clean), tostring(getCurrentTrainId()), tostring(isInTrainGround()),
        tostring(isAutoTraining()), tostring(isInDungeon()), tostring(isStageJumping())
    )
    return clean, Farm.Runtime.LastGearStatePrep
end
local function nativeShopPurchaseAndEquip(id, itemType, saveKey, label, sessionRoot, keepOpen)
    id = tonumber(id)
    local shopName = shopUiNameForType(itemType)
    if not id or not shopName then return false, "invalid gear target", sessionRoot end
    Farm.Runtime.GearTransaction = true
    local root = nativeShopRootVisible(sessionRoot) and sessionRoot or openNativeShop(shopName)
    local function finish(ok, message)
        Farm.Runtime.GearNetworkBusy = false
        if not keepOpen then closeNativeShop(shopName) end
        Farm.Runtime.GearTransaction = Farm.Runtime.GearSessionActive == true
        return ok, message, root
    end
    if not nativeShopRootVisible(root) then
        return finish(false, "shop did not open")
    end
    Farm.Runtime.GearNetworkBusy = true
    local confName = confNameForItemType(itemType)
    local liveTarget = confName and resolveLiveNextShopTarget(root, itemType, confName) or nil
    if liveTarget and tonumber(liveTarget.id) then
        id = tonumber(liveTarget.id)
        Farm.Runtime.LastGear = string.format("Buying %s %s (%s Gold) [live shop]", label, id, liveTarget.price)
    end
    local cfg = findCfg(id, itemType)
    local price = cfg and tonumber(cfg.Price) or 0
    local beforeGold = getGold()
    if price > 0 and beforeGold < price then
        return finish(false, string.format("not affordable (%s/%s Gold)", beforeGold, price))
    end
    local function liveEquipped()
        local liveId = select(1, liveShopEquippedId(findNativeShopRoot(shopName) or root))
        if liveId and confName then Farm.Runtime.LiveEquippedIds[confName] = liveId end
        return tonumber(liveId) == id
    end
    local function owned()
        return ownsItemNativeBag(id, itemType) or ownsItem(id, itemType) or liveEquipped()
    end
    local accepted = owned()
    if not accepted then
        Farm.Runtime.LastBuyWireFormat = "native-table"
        Farm.Runtime.LastGearServerPayload = string.format(
            "equipID=%s itemType=%s price=%s gold=%s", id, tostring(itemType), price, beforeGold
        )
        local function buyOnce(tag)
            local ok, result = safeInvoke(NetMsg.EQUIP_SHOP_BUY, {
                equipID = id,
                itemType = tonumber(itemType) or itemType,
            })
            Farm.Runtime.LastGearServerResult = string.format("%s ok=%s result=%s", tag, tostring(ok), tostring(result))
            Farm.Runtime.LastNativeShopAction = string.format(
                "BUY %s %s -> ok=%s result=%s", label, id, tostring(ok), tostring(result)
            )
            return ok and result == true
        end
        accepted = buyOnce("native-table")
        local deadline = os.clock() + (accepted and 0.22 or 0.12)
        while Farm.Running and os.clock() < deadline and not owned() and getGold() >= beforeGold do
            task.wait(0.012)
        end
        if not owned() and getGold() >= beforeGold and not accepted then
            task.wait(0.05)
            accepted = buyOnce("native-table retry")
            deadline = os.clock() + 0.22
            while Farm.Running and os.clock() < deadline and not owned() and getGold() >= beforeGold do
                task.wait(0.015)
            end
        end
        if not accepted and not owned() and getGold() >= beforeGold then
            return finish(false, "server rejected buy")
        end
        if accepted and not ownsItem(id, itemType) and not liveEquipped() then
            deadline = os.clock() + 0.28
            while Farm.Running and os.clock() < deadline and not ownsItem(id, itemType) and not liveEquipped() do
                task.wait(0.02)
            end
        end
    end
    if equippedId(saveKey) ~= id and not liveEquipped() then
        local ok, result = safeInvoke(NetMsg.EQUIP_SHOP_EQUIP, {
            equipID = id,
            itemType = itemType,
        })
        Farm.Runtime.LastNativeShopAction = string.format(
            "EQUIP %s %s -> ok=%s result=%s", label, id, tostring(ok), tostring(result)
        )
        if ok and result == true then
            local deadline = os.clock() + 0.24
            while Farm.Running and os.clock() < deadline and equippedId(saveKey) ~= id and not liveEquipped() do
                task.wait(0.018)
            end
            if equippedId(saveKey) == id or liveEquipped() then
                Farm.Runtime.GearEquips = Farm.Runtime.GearEquips + 1
            end
        end
    end
    local isOwned = ownsItem(id, itemType) or liveEquipped() or getGold() < beforeGold
    local isEquipped = equippedId(saveKey) == id or liveEquipped()
    Farm.Runtime.LastNativeShopAction = string.format(
        "%s %s owned=%s equipped=%s", label, id, tostring(isOwned), tostring(isEquipped)
    )
    return finish(isOwned, isEquipped and "owned+equipped" or (isOwned and "owned" or "not owned"))
end
local function waitForEquipped(saveKey, id, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 1.0)
    while Farm.Running and os.clock() < deadline do
        if equippedId(saveKey) == tonumber(id) then
            return true
        end
        task.wait(0.05)
    end
    return equippedId(saveKey) == tonumber(id)
end
local function equipOwnedVerified(id, itemType, saveKey, label)
    id = tonumber(id)
    if not id or id <= 0 or not ownsItem(id, itemType) then
        return false
    end
    if equippedId(saveKey) == id then
        return true
    end
    local ok, result = safeInvoke(NetMsg.EQUIP_SHOP_EQUIP, {
        equipID = id,
        itemType = itemType,
    })
    if not ok or result ~= true then
        Farm.Runtime.LastGear = string.format("Equip rejected %s %s", label, tostring(id))
        return false
    end
    local verifyTime = (saveKey == "Weapon" and equippedId(saveKey) <= 0) and 0.18 or 0.35
    if waitForEquipped(saveKey, id, verifyTime) then
        Farm.Runtime.GearEquips = Farm.Runtime.GearEquips + 1
        Farm.Runtime.LastGear = string.format("Equipped %s %s", label, tostring(id))
        return true
    end
    if saveKey == "Weapon" and result == true then
        Farm.Runtime.GearEquips = Farm.Runtime.GearEquips + 1
        Farm.Runtime.LastGear = string.format("Equipped %s %s (server confirmed)", label, tostring(id))
        return true
    end
    Farm.Runtime.LastGear = string.format("Equip not replicated %s %s", label, tostring(id))
    return false
end
local function equipBestOwned(itemType, confName, saveKey, label)
    local list = buildShop(confName)
    if #list == 0 then
        Farm.Runtime.LastGear = label .. " shop unavailable"
        return false
    end
    local currentId = equippedId(saveKey)
    if currentId <= 0 and Farm.Runtime.LiveEquippedIds then
        currentId = tonumber(Farm.Runtime.LiveEquippedIds[confName]) or 0
    end
    local currentCfg = currentId > 0 and findCfg(currentId, itemType) or nil
    local bestId = currentId
    local bestCfg = currentCfg
    for _, entry in ipairs(list) do
        local id = tonumber(entry.id)
        local cfg = entry.cfg
        if id and cfg and ownsItem(id, itemType) and gearAllowedByRebirth(cfg) then
            if not bestCfg or cfgIsBetter(cfg, bestCfg, itemType) then
                bestId = id
                bestCfg = cfg
            end
        end
    end
    if bestId > 0 and bestId ~= currentId then
        return equipOwnedVerified(bestId, itemType, saveKey, label)
    end
    return bestId > 0
end
-- ============================================================================
-- HELD WAND GUARD
-- ============================================================================
Farm.Fast = Farm.Fast or {}
function Farm.Fast._numberValue(name)
    local value = LocalPlayer:FindFirstChild(name)
    if value and value:IsA("NumberValue") then
        return tonumber(value.Value) or 0
    end
    return 0
end
function Farm.Fast.nativeDungeonCombatBlocked()
    local inChallenge = Farm.Fast._numberValue("InDungeonChallenge") > 0
    local inEventCombat = Farm.Fast._numberValue("InEventCombat") > 0
    if not inChallenge then
        return inEventCombat
    end
    if Farm.Fast._numberValue("InStageSafeArea") > 0 then
        return inEventCombat
    end
    return true
end
function Farm.Fast.heldSwitchBlocked()
    return isAutoTraining() or Farm.Fast.nativeDungeonCombatBlocked()
end
function Farm.Fast.getHeldToolbarOnlyId()
    if GetData and type(GetData.GetHeldToolbarOnlyId) == "function" then
        local ok, value = pcall(GetData.GetHeldToolbarOnlyId, LocalPlayer)
        if ok then
            return math.max(0, tonumber(value) or 0)
        end
    end
    return 0
end
function Farm.Fast.getBestOwnedWandBagItem()
    if not (EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Weapon) then return nil end
    local weaponType = tonumber(EnumMgr.ItemType.Weapon)
    local bestItem, bestCfg = nil, nil
    for _, item in pairs(getBag()) do
        if type(item) == "table"
            and tonumber(item.tp) == weaponType
            and (tonumber(item.count) or 1) > 0
            and (tonumber(item.onlyID) or 0) > 0 then
            local cfg = findCfg(tonumber(item.id), weaponType)
            if cfg and (not bestCfg or cfgIsBetter(cfg, bestCfg, weaponType)) then
                bestItem, bestCfg = item, cfg
            end
        end
    end
    return bestItem
end
function Farm.Fast.findToolbarSlotForOnlyId(onlyId)
    if not GetData then return nil end
    if type(GetData.GetBackpackToolbarItemSlotMin) ~= "function"
        or type(GetData.GetBackpackToolbarSlotCount) ~= "function"
        or type(GetData.GetBackpackToolbarItemAtUiSlot) ~= "function" then
        return nil
    end
    local bag = getBag()
    local okMin, minSlot = pcall(GetData.GetBackpackToolbarItemSlotMin)
    local okMax, maxSlot = pcall(GetData.GetBackpackToolbarSlotCount)
    if not (okMin and okMax) then return nil end
    for slot = tonumber(minSlot) or 1, tonumber(maxSlot) or 9 do
        local okItem, item = pcall(GetData.GetBackpackToolbarItemAtUiSlot, bag, slot, LocalPlayer)
        if okItem and item then
            local id = tonumber(type(item) == "table" and item.onlyID or item) or 0
            if id == tonumber(onlyId) then return slot end
        end
    end
    return nil
end
function Farm.Fast.ensureBestWandHeld(reason, timeout)
    if not Farm.Config.AutoHoldBestWand then return true end
    if Farm.Fast.heldSwitchBlocked() then
        Farm.Runtime.LastHeldWand = "Deferred: combat/training blocks held switch"
        return false
    end
    local item = Farm.Fast.getBestOwnedWandBagItem()
    if not item then
        Farm.Runtime.LastHeldWand = "No owned Wand found in Bag"
        return false
    end
    local onlyId = tonumber(item.onlyID) or 0
    local wandId = tonumber(item.id) or 0
    if onlyId <= 0 then return false end
    if Farm.Fast.getHeldToolbarOnlyId() == onlyId then
        Farm.Runtime.LastHeldWand = string.format("Holding Wand %s", tostring(wandId))
        return true
    end
    Farm.Runtime.LastHeldWandAt = os.clock()
    Farm.Runtime.LastHeldWand = string.format("Holding Wand %s (%s)", tostring(wandId), tostring(reason or "guard"))
    safeFire(NetMsg.BACKPACK_TOGGLE_HELD, { onlyID = onlyId })
    local deadline = os.clock() + math.clamp(tonumber(timeout) or 0.24, 0.08, 0.5)
    while Farm.Running and os.clock() < deadline do
        if Farm.Fast.getHeldToolbarOnlyId() == onlyId then
            Farm.Runtime.LastHeldWand = string.format("Holding Wand %s OK", tostring(wandId))
            return true
        end
        if Farm.Fast.heldSwitchBlocked() then return false end
        task.wait(0.02)
    end
    local slot = Farm.Fast.findToolbarSlotForOnlyId(onlyId)
    if slot and not Farm.Fast.heldSwitchBlocked() then
        safeFire(NetMsg.BACKPACK_TOGGLE_HELD, { uiSlotIndex = slot })
        local d2 = os.clock() + 0.16
        while Farm.Running and os.clock() < d2 do
            if Farm.Fast.getHeldToolbarOnlyId() == onlyId then
                Farm.Runtime.LastHeldWand = string.format("Holding Wand %s OK", tostring(wandId))
                return true
            end
            task.wait(0.02)
        end
    end
    if Farm.Fast.getHeldToolbarOnlyId() <= 0 then
        Farm.Runtime.LastHeldWand = string.format("Wand %s hold requested", tostring(wandId))
        return true
    end
    Farm.Runtime.LastHeldWand = string.format("Wand %s hold unconfirmed", tostring(wandId))
    return false
end
function Farm.Fast.stopTrainingForDungeonFast()
    if not (isInTrainGround() or isAutoTraining() or getCurrentTrainId() > 0) then return true end
    safeFire(NetMsg.TRAIN_ZONE_UPDATE, { trainId = nil })
    local deadline = os.clock() + 0.65
    while Farm.Running and os.clock() < deadline do
        if not isInTrainGround() and not isAutoTraining() and getCurrentTrainId() <= 0 then return true end
        task.wait(0.035)
    end
    return not isAutoTraining()
end
function Farm.Fast.prepareWandForDungeon(reason)
    Farm.Fast.stopTrainingForDungeonFast()
    if Farm.Fast.nativeDungeonCombatBlocked() then
        Farm.Runtime.LastHeldWand = "Combat already active; hold deferred"
        return false
    end
    return Farm.Fast.ensureBestWandHeld(reason or "pre-dungeon", 0.28)
end
function Farm.Fast.buildMissingCoinLadder(itemType, confName)
    local list = buildShop(confName)
    local candidates = {}
    for _, entry in ipairs(list) do
        local id = tonumber(entry.id)
        local cfg = entry.cfg
        local price = cfg and tonumber(cfg.Price) or 0
        local sort = cfg and (tonumber(cfg.Sort) or 0) or 0
        if id and cfg
            and isCoinGear(cfg)
            and price > 0
            and gearAllowedByRebirth(cfg)
            and not ownsItem(id, itemType) then
            table.insert(candidates, {
                id = id,
                cfg = cfg,
                price = price,
                sort = sort,
            })
        end
    end
    table.sort(candidates, function(a, b)
        if a.sort == b.sort then
            if a.price == b.price then return a.id < b.id end
            return a.price < b.price
        end
        return a.sort < b.sort
    end)
    return candidates
end
function Farm.Fast.resolveEquippedShopProgress(itemType, confName, saveKey, list)
    local currentId = equippedId(saveKey)
    local remembered = Farm.Runtime.LiveEquippedIds[confName]
    local shopName = confNameToShopName(confName)
    local visibleRoot = shopName and findNativeShopRoot(shopName) or nil
    if nativeShopRootVisible(visibleRoot) then
        local liveId = rememberLiveEquipped(confName, visibleRoot)
        if liveId then remembered = liveId end
    end
    if (tonumber(currentId) or 0) <= 0 and tonumber(remembered) then
        currentId = tonumber(remembered)
    end
    if (tonumber(currentId) or 0) <= 0 and confName == "weaponConf"
        and Farm.Fast and type(Farm.Fast.getBestOwnedWandBagItem) == "function" then
        local bagWand = Farm.Fast.getBestOwnedWandBagItem()
        if type(bagWand) == "table" and tonumber(bagWand.id) then
            currentId = tonumber(bagWand.id)
        end
    end
    local currentCfg = nil
    local currentSort = 0
    for _, entry in ipairs(list or {}) do
        if tonumber(entry.id) == tonumber(currentId) then
            currentCfg = entry.cfg
            currentSort = tonumber(entry.cfg and entry.cfg.Sort) or 0
            break
        end
    end
    if not currentCfg and currentId > 0 and CfgFind and type(CfgFind.GetCfgByNameAndID) == "function" then
        local ok, cfg = pcall(CfgFind.GetCfgByNameAndID, confName, currentId)
        if ok and type(cfg) == "table" then
            currentCfg = cfg
            currentSort = tonumber(cfg.Sort) or 0
        end
    end
    if currentSort <= 0 then
        for _, entry in ipairs(list or {}) do
            local id = tonumber(entry.id)
            local sort = tonumber(entry.cfg and entry.cfg.Sort) or 0
            if id and sort > currentSort and ownsItem(id, itemType) then
                currentSort = sort
                currentCfg = entry.cfg
            end
        end
    end
    Farm.Runtime.GearEquippedId = tonumber(currentId) or 0
    Farm.Runtime.GearEquippedSort = tonumber(currentSort) or 0
    return tonumber(currentId) or 0, currentCfg, tonumber(currentSort) or 0
end
function Farm.Fast.buildBetterCoinCandidates(itemType, confName, saveKey)
    local list = buildShop(confName)
    local currentId, currentCfg, currentSort = Farm.Fast.resolveEquippedShopProgress(itemType, confName, saveKey, list)
    local normal = {}
    for _, entry in ipairs(list) do
        local id = tonumber(entry.id)
        local cfg = entry.cfg
        local price = cfg and tonumber(cfg.Price) or 0
        local sort = cfg and (tonumber(cfg.Sort) or 0) or 0
        local better = false
        if currentSort > 0 then
            better = sort > currentSort
        elseif currentCfg then
            better = cfgIsBetter(cfg, currentCfg, itemType)
        else
            better = true
        end
        if id and cfg
            and isCoinGear(cfg)
            and price > 0
            and better
            and gearAllowedByRebirth(cfg)
            and not ownsItem(id, itemType) then
            table.insert(normal, { id = id, cfg = cfg, price = price, sort = sort })
        end
    end
    table.sort(normal, function(a, b)
        if a.sort == b.sort then
            if a.price == b.price then return a.id < b.id end
            return a.price < b.price
        end
        return a.sort < b.sort
    end)
    local first = normal[1]
    local resolvedText = first and string.format(
        "equipped=%s sort=%s -> target=%s sort=%s price=%s",
        tostring(currentId), tostring(currentSort), tostring(first.id), tostring(first.sort), tostring(first.price)
    ) or string.format("equipped=%s sort=%s -> no target", tostring(currentId), tostring(currentSort))
    if confName == "weaponConf" or Farm.Runtime.GearResolvedTarget == nil then
        Farm.Runtime.GearResolvedTarget = resolvedText
    end
    return normal
end
function Farm.Fast.buyGearUpgradeChain(itemType, confName, saveKey, label, maxPurchases)
    local list = buildShop(confName)
    if #list == 0 then
        Farm.Runtime.LastGear = label .. " shop list empty"
        return false
    end
    local preCandidates = Farm.Fast.buildBetterCoinCandidates(itemType, confName, saveKey)
    local preCandidate = preCandidates[1]
    local preGold = getGold()
    if not preCandidate or tonumber(preCandidate.price) > preGold then
        local idleShop = shopUiNameForType(itemType)
        if idleShop then closeNativeShop(idleShop) end
        Farm.Runtime.LastGear = preCandidate
            and string.format("Waiting for %s %s: %s/%s Gold", label, tostring(preCandidate.id), tostring(preGold), tostring(preCandidate.price))
            or (label .. " has no purchasable upgrade")
        return false
    end
    Farm.Runtime.GearSessionActive = true
    Farm.Runtime.GearTransaction = true
    local stateOk, stateWhy = prepareGearPurchaseState()
    if not stateOk then
        Farm.Runtime.LastGear = label .. " buy waiting for clean state: " .. tostring(stateWhy)
        Farm.Runtime.GearSessionActive = false
        Farm.Runtime.GearTransaction = false
        return false
    end
    equipBestOwned(itemType, confName, saveKey, label)
    local boughtAny = false
    local chainFailed = false
    local shopName = shopUiNameForType(itemType)
    local shopSessionRoot = nil
    local shopSessionOpened = false
    maxPurchases = math.max(1, math.floor(tonumber(maxPurchases) or 3))
    for _ = 1, maxPurchases do
        local gold = getGold()
        local candidates = Farm.Fast.buildBetterCoinCandidates(itemType, confName, saveKey)
        local candidate = candidates[1]
        if not candidate then
            break
        end
        local candidateKey = gearCooldownKey(itemType, candidate.id)
        if candidate.price > gold or os.clock() < (Farm.Runtime.GearFailureCooldown[candidateKey] or 0) then
            break
        end
        local key = candidateKey
        setPhase(string.format("Buying %s %s", label, tostring(candidate.id)))
        Farm.Runtime.LastGear = string.format("Buying %s %s (%s Gold)", label, tostring(candidate.id), tostring(candidate.price))
        local beforeGold = getGold()
        Farm.Runtime.GearAttempts = (Farm.Runtime.GearAttempts or 0) + 1
        local nativeOk, nativeResult, liveRoot = nativeShopPurchaseAndEquip(
            candidate.id, itemType, saveKey, label, shopSessionRoot, true
        )
        if nativeShopRootVisible(liveRoot) then
            shopSessionRoot = liveRoot
            shopSessionOpened = true
        end
        local owned = ownsItem(candidate.id, itemType)
        Farm.Runtime.LastGearRemoteResult = string.format(
            "%s %s native=%s (%s) Gold=%s->%s owned=%s",
            label, tostring(candidate.id), tostring(nativeOk), tostring(nativeResult),
            tostring(beforeGold), tostring(getGold()), tostring(owned)
        )
        if not owned then
            chainFailed = true
            Farm.Runtime.GearFailureCooldown[key] = os.clock() + 1.0
            Farm.Runtime.LastGear = string.format("Buy failed %s %s • %s", label, tostring(candidate.id), tostring(Farm.Runtime.LastGearRemoteResult))
            break
        end
        boughtAny = true
        Farm.Runtime.GearBuys = Farm.Runtime.GearBuys + 1
        Farm.Runtime.LastGear = string.format("Bought %s %s", label, tostring(candidate.id))
        if equippedId(saveKey) ~= tonumber(candidate.id) then
            task.wait(0.01)
            equipOwnedVerified(candidate.id, itemType, saveKey, label)
        end
        if tonumber(itemType) == tonumber(EnumMgr.ItemType.Weapon) and Farm.Config.AutoHoldBestWand then
            Farm.Fast.ensureBestWandHeld("new wand", 0.18)
        end
        task.wait(0.012)
    end
    if shopName then
        closeNativeShop(shopName)
        Farm.Runtime.LastNativeShopAction = string.format(
            "%s shop closed after %s", label, chainFailed and "failed attempt" or "gear pass"
        )
    end
    equipBestOwned(itemType, confName, saveKey, label)
    Farm.Runtime.GearNetworkBusy = false
    Farm.Runtime.GearSessionActive = false
    Farm.Runtime.GearTransaction = false
    return boughtAny
end
function Farm.Fast.getNextGearCost()
    if not (EnumMgr and EnumMgr.ItemType) then
        return nil, nil
    end
    local bestGoal = nil
    local bestLabel = nil
    local specs = {
        { enabled = Farm.Config.AutoWeapon, itemType = EnumMgr.ItemType.Weapon, conf = "weaponConf", save = "Weapon", label = "Wand" },
        { enabled = Farm.Config.AutoArmor, itemType = EnumMgr.ItemType.Armor, conf = "armorConf", save = "Armor", label = "Armor" },
        { enabled = Farm.Config.AutoBroom, itemType = EnumMgr.ItemType.Broom, conf = "broomConf", save = "NowBroom", label = "Broom" },
    }
    for _, spec in ipairs(specs) do
        if spec.enabled and spec.itemType then
            local candidates = Farm.Fast.buildBetterCoinCandidates(spec.itemType, spec.conf, spec.save)
            local nextEntry = candidates[1]
            if nextEntry and (not bestGoal or nextEntry.price < bestGoal) then
                bestGoal = nextEntry.price
                bestLabel = spec.label .. " " .. tostring(nextEntry.id)
            end
        end
    end
    return bestGoal, bestLabel
end
function Farm.Fast.getNextAffordableGearNow()
    if not (EnumMgr and EnumMgr.ItemType) then
        return nil, nil, nil
    end
    local gold = getGold()
    local specs = {
        { enabled = Farm.Config.AutoWeapon, itemType = EnumMgr.ItemType.Weapon, conf = "weaponConf", save = "Weapon", label = "Wand" },
        { enabled = Farm.Config.AutoArmor, itemType = EnumMgr.ItemType.Armor, conf = "armorConf", save = "Armor", label = "Armor" },
        { enabled = Farm.Config.AutoBroom, itemType = EnumMgr.ItemType.Broom, conf = "broomConf", save = "NowBroom", label = "Broom" },
    }
    local best = nil
    for _, spec in ipairs(specs) do
        if spec.enabled and spec.itemType then
            local candidates = Farm.Fast.buildBetterCoinCandidates(spec.itemType, spec.conf, spec.save)
            local entry = candidates[1]
            if entry and entry.price <= gold then
                if not best or entry.price < best.price then
                    best = {
                        label = spec.label,
                        id = entry.id,
                        price = entry.price,
                    }
                end
            end
        end
    end
    if best then
        return best.label, best.id, best.price
    end
    return nil, nil, nil
end
function Farm.Fast.getVisibleGearShopName()
    for _, shopName in ipairs({ "Weapon", "Armor", "Broom" }) do
        local root = findNativeShopRoot(shopName)
        if nativeShopRootVisible(root) then
            return shopName
        end
    end
    return nil
end
function Farm.Fast.gearTick(force)
    if Farm.Runtime.GearTransaction then return end
    if not (Farm.Config.Master and EnumMgr and EnumMgr.ItemType) then
        return
    end
    if dungeonTransitionActive() then
        local label, id, price = Farm.Fast.getNextAffordableGearNow()
        if label and id then
            Farm.Runtime.LastGear = string.format(
                "Queued %s %s (%s Gold) - buy after dungeon", tostring(label), tostring(id), tostring(price)
            )
        end
        return
    end
    local visibleShop = Farm.Fast.getVisibleGearShopName()
    local specs = {
        { enabled = Farm.Config.AutoWeapon, shop = "Weapon", itemType = EnumMgr.ItemType.Weapon, conf = "weaponConf", save = "Weapon", label = "Wand", max = 12 },
        { enabled = Farm.Config.AutoArmor, shop = "Armor", itemType = EnumMgr.ItemType.Armor, conf = "armorConf", save = "Armor", label = "Armor", max = 10 },
        { enabled = Farm.Config.AutoBroom, shop = "Broom", itemType = EnumMgr.ItemType.Broom, conf = "broomConf", save = "NowBroom", label = "Broom", max = 6 },
    }
    for _, spec in ipairs(specs) do
        if spec.enabled and spec.itemType and (visibleShop == nil or visibleShop == spec.shop) then
            local candidates = Farm.Fast.buildBetterCoinCandidates(spec.itemType, spec.conf, spec.save)
            local candidate = candidates[1]
            if candidate and candidate.price <= getGold() then
                Farm.Fast.buyGearUpgradeChain(spec.itemType, spec.conf, spec.save, spec.label, spec.max)
                return
            elseif visibleShop == spec.shop then
                closeNativeShop(spec.shop)
                Farm.Runtime.LastGear = candidate
                    and string.format("Waiting for %s %s: %s/%s Gold", spec.label, tostring(candidate.id), tostring(getGold()), tostring(candidate.price))
                    or (spec.label .. " shop closed; no next upgrade")
                Farm.Runtime.LastNativeShopAction = spec.label .. " shop closed - not affordable"
                return
            end
        end
    end
end
-- ============================================================================
-- TRAINING POTIONS
-- ============================================================================
local TRAINING_POTION_IDS = {
    [9200102] = 2, -- +5 training / Power gain
    [9200101] = 1, -- +2 training / Power gain
}
local LUCK_POTION_IDS = {
    [9200104] = 2, -- +5 Luck
    [9200103] = 1, -- +2 Luck
}
local function getTimedBuffValue(attrId)
    local folder = LocalPlayer:FindFirstChild("Attrs_Buff")
    local value = folder and folder:FindFirstChild(tostring(attrId))
    return value and tonumber(value.Value) or 0
end
local function findBestPotion(idMap)
    local best = nil
    local bestTier = -1
    for _, item in pairs(getBag()) do
        if type(item) == "table" then
            local id = tonumber(item.id)
            local onlyId = tonumber(item.onlyID)
            local tier = id and idMap[id]
            if tier and onlyId and onlyId > 0 and not isLocked(item) and tier > bestTier then
                bestTier = tier
                best = item
            end
        end
    end
    return best
end
local function drinkPotion(item, label)
    local onlyId = type(item) == "table" and tonumber(item.onlyID) or nil
    if not onlyId then return false end
    local ok, result = safeInvoke(NetMsg.DRINK_POTION, { onlyID = onlyId })
    if ok and result ~= false then
        Farm.Runtime.PotionsUsed = Farm.Runtime.PotionsUsed + 1
        setPhase("Used " .. tostring(label) .. " potion")
        return true
    end
    return false
end
local function potionTick()
    if Farm.Runtime.GearTransaction then return false end
    if not Farm.Config.Master then return false end
    local used = false
    if Farm.Config.AutoTrainingPotion and getTimedBuffValue(22) <= 0 then
        used = drinkPotion(findBestPotion(TRAINING_POTION_IDS), "training") or used
        if used then task.wait(0.12) end
    end
    if Farm.Config.AutoLuckPotion and getTimedBuffValue(19) <= 0 then
        used = drinkPotion(findBestPotion(LUCK_POTION_IDS), "luck") or used
    end
    return used
end
-- ============================================================================
-- CODES / REWARDS
-- ============================================================================
local KNOWN_CODES = {
    "UPD2",
    "admin abuse1",
    "PETPARTY",
    "TRAININGFIX",
    "DRAGONROAR",
}
local function redeemCodesOnce()
    if Farm.Runtime.GearTransaction then return end
    if Farm.Runtime.CodesTried or not Farm.Config.AutoCodes then
        return
    end
    Farm.Runtime.CodesTried = true
    for _, code in ipairs(KNOWN_CODES) do
        if not Farm.Running or not Farm.Config.AutoCodes then
            break
        end
        local ok, result = safeInvoke(NetMsg.REDEEM_CODE, string.upper(code))
        if ok and result then
            Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
            Farm.Runtime.LastReward = "Code: " .. code
        end
        task.wait(0.45)
    end
end
local function claimDaily()
    if Farm.Runtime.GearTransaction then return false end
    if not Farm.Config.AutoDaily then
        return false
    end
    local login = getDataValue("Login")
    if type(login) ~= "table" then
        return false
    end
    local keys = {}
    for key in pairs(login) do
        local n = tonumber(key)
        if n then
            table.insert(keys, n)
        end
    end
    table.sort(keys)
    for _, day in ipairs(keys) do
        local state = login[tostring(day)] or login[day]
        if type(state) == "table" and tonumber(state.State) == 1 then
            local ok, result = safeInvoke(NetMsg.CLAIM_DAILY_AWARD, day)
            if ok and result then
                Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
                Farm.Runtime.LastReward = "Daily " .. tostring(day)
                return true
            end
        end
    end
    return false
end
local function claimOnline()
    if Farm.Runtime.GearTransaction then return false end
    if not Farm.Config.AutoOnline then
        return false
    end
    if not (CfgFind and type(CfgFind.GetOnlineAwardList) == "function" and type(CfgFind.IsOnlineTierClaimable) == "function") then
        return false
    end
    local state = getDataValue("OnlineBox")
    if type(state) ~= "table" then
        return false
    end
    local view = {}
    for k, v in pairs(state) do
        view[k] = v
    end
    local okList, list = pcall(CfgFind.GetOnlineAwardList)
    if not okList or type(list) ~= "table" then
        return false
    end
    for _, cfg in ipairs(list) do
        local id = tonumber(cfg.id)
        if id and id > 0 then
            local okClaimable, claimable = pcall(CfgFind.IsOnlineTierClaimable, view, cfg)
            if okClaimable and claimable then
                local ok, result = safeInvoke(NetMsg.CLAIM_ONLINE_AWARD, id)
                if ok and result then
                    Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
                    Farm.Runtime.LastReward = "Online " .. tostring(id)
                    return true
                end
            end
        end
    end
    return false
end
-- ============================================================================
-- EVENT QUESTS / COLLECTION INDEX
-- ============================================================================
local TASK_KILL_SPECIFIC = "\229\135\187\230\157\128N\229\143\170\230\140\135\229\174\154\230\128\170\231\137\169"
local TASK_KILL_ANY = "\229\135\187\230\157\128\228\187\187\230\132\143\230\128\170\231\137\169"
local TASK_COLLECT_SPECIFIC = "\230\148\182\233\155\134N\228\184\170\230\140\135\229\174\154\230\157\144\230\150\153"
local TASK_COLLECT_ANY = "\230\148\182\233\155\134N\228\184\170\228\187\187\230\132\143\230\157\144\230\150\153"
local TASK_CLEAR_DUNGEON = "\233\128\154\229\133\179N\230\172\161\228\187\187\230\132\143\229\133\179\229\141\161"
local DUNGEON_TASK_TYPES = {
    [TASK_KILL_SPECIFIC] = true,
    [TASK_KILL_ANY] = true,
    [TASK_COLLECT_SPECIFIC] = true,
    [TASK_COLLECT_ANY] = true,
    [TASK_CLEAR_DUNGEON] = true,
}
local function copyAcceptedList(value)
    if type(value) ~= "table" then return nil end
    local out = {}
    for _, v in ipairs(value) do
        local text = tostring(v or "")
        if text ~= "" then table.insert(out, text) end
    end
    return #out > 0 and out or nil
end
local function getEventTaskRows()
    if not (PlayerData and CfgFind and EnumMgr and EnumMgr.TaskResetType) then return {} end
    local okEvent, event = pcall(PlayerData.GetPlrDataByKey, LocalPlayer, "Event")
    if not okEvent or type(event) ~= "table" or type(event.EventTask) ~= "table" then return {} end
    local root = event.EventTask
    local onceDone = type(root.Once) == "table" and type(root.Once.Completed) == "table" and root.Once.Completed or {}
    local refill = false
    pcall(function()
        local cfg = CfgFind.GetEventGameConfig()
        refill = type(cfg) == "table" and cfg.OnceTaskRefill == true
    end)
    local weather = nil
    pcall(function()
        local util = UtilsSystem.EventWeatherUtil
        if util and type(util.GetEffectiveWeather) == "function" then weather = util.GetEffectiveWeather() end
    end)
    local defs = {
        { EnumMgr.TaskResetType.Timed, "Timed" },
        { EnumMgr.TaskResetType.Daily, "Daily" },
        { EnumMgr.TaskResetType.Once, "Once" },
    }
    local rows = {}
    for _, def in ipairs(defs) do
        local resetType, key = def[1], def[2]
        if resetType ~= nil then
            local section = type(root[key]) == "table" and root[key] or {}
            local accepted
            local shouldProcess = true
            if key == "Once" and refill then
                accepted = nil
            else
                accepted = copyAcceptedList(section.Accepted)
                if not accepted then
                    shouldProcess = false
                end
            end
            if shouldProcess then
                local okTags, tags = pcall(CfgFind.BuildEventTaskActiveOnlyTags, {
                    resetType = resetType,
                    weather = weather,
                    onceDone = onceDone,
                    accepted = accepted,
                    onceAccepted = accepted,
                    onceRefill = refill,
                })
                if okTags and type(tags) == "table" then
                    local progressMap = type(section.Progress) == "table" and section.Progress or {}
                    local completedMap = type(section.Completed) == "table" and section.Completed or {}
                    for _, onlyTag in ipairs(tags) do
                        local okCfg, cfg = pcall(CfgFind.GetTaskCfgByOnlyTag, onlyTag)
                        if okCfg and type(cfg) == "table" then
                            local needRaw = cfg.need
                            local need = type(needRaw) == "table" and tonumber(needRaw[1]) or tonumber(needRaw)
                            need = math.max(1, math.floor(need or 1))
                            local progress = tonumber(progressMap[onlyTag]) or 0
                            local claimed = tonumber(completedMap[onlyTag]) == 1
                            table.insert(rows, {
                                onlyTag = onlyTag,
                                cfg = cfg,
                                need = need,
                                progress = progress,
                                claimed = claimed,
                                canClaim = (not claimed) and progress >= need,
                                resetType = resetType,
                            })
                        end
                    end
                end
            end
        end
    end
    Farm.Runtime.ActiveEventQuests = #rows
    return rows
end
local function taskTypeOf(row)
    local tt = row and row.cfg and row.cfg.TaskType
    return type(tt) == "table" and tostring(tt[1] or "") or tostring(tt or "")
end
local function getActiveQuestMaterialTargets()
    local targets = {}
    local materialType = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Material
    for _, row in ipairs(getEventTaskRows()) do
        if not row.claimed and row.progress < row.need and taskTypeOf(row) == TASK_COLLECT_SPECIFIC then
            local param = row.cfg and row.cfg.param
            local id = tonumber(type(param) == "table" and param[1] or param)
            if id then
                local okCfg, cfg = pcall(CfgFind.FindCfgByID, id)
                if okCfg and type(cfg) == "table" and (not materialType or tonumber(cfg.tp) == tonumber(materialType)) then
                    targets[id] = true
                end
            end
        end
    end
    return targets
end
local function hasDungeonQuestWork()
    for _, row in ipairs(getEventTaskRows()) do
        if not row.claimed and row.progress < row.need and DUNGEON_TASK_TYPES[taskTypeOf(row)] then
            return true
        end
    end
    return false
end
local function claimEventTasks()
    if Farm.Runtime.GearTransaction then return false end
    if not (Farm.Config.Master and Farm.Config.AutoEventQuestClaims and NetMsg.EVENT_TASK_CLAIM) then return false end
    local claimedAny = false
    for _, row in ipairs(getEventTaskRows()) do
        if row.canClaim then
            local ok, result = safeInvoke(NetMsg.EVENT_TASK_CLAIM, row.onlyTag)
            if ok and result == true then
                claimedAny = true
                Farm.Runtime.EventQuestClaims = Farm.Runtime.EventQuestClaims + 1
                Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
                Farm.Runtime.LastQuest = "Claimed " .. tostring(row.onlyTag)
                task.wait(0.16)
            end
        end
    end
    return claimedAny
end
local function getIndexSnapshots()
    if not (IndexView and type(IndexView.buildAllTabSnapshots) == "function" and PlayerData) then return nil end
    local okSave, save = pcall(PlayerData.GetPlrDataByKey, LocalPlayer, "Index")
    if not okSave or type(save) ~= "table" then return nil end
    local ok, snapshots = pcall(IndexView.buildAllTabSnapshots, save)
    return ok and type(snapshots) == "table" and snapshots or nil
end
local function getUncollectedIndexMaterialSet()
    local snapshots = getIndexSnapshots()
    local material = snapshots and snapshots.Material
    local unlocked = material and material.unlockSet
    if type(unlocked) ~= "table" then return {} end
    local unseen = {}
    setmetatable(unseen, {
        __index = function(_, key)
            local numeric = tonumber(key)
            if not numeric then return false end
            return unlocked[numeric] ~= true and unlocked[tostring(numeric)] ~= true and unlocked[numeric] ~= 1 and unlocked[tostring(numeric)] ~= 1
        end,
    })
    return unseen
end
local function claimIndexRewards()
    if Farm.Runtime.GearTransaction then return false end
    if not (Farm.Config.Master and Farm.Config.AutoIndexRewards and NetMsg.INDEX_CLAIM_REWARD) then return false end
    local claimedAny = false
    for _, tag in ipairs({ "Material", "Potion" }) do
        for _ = 1, 5 do
            local snapshots = getIndexSnapshots()
            local progress = snapshots and snapshots[tag] and snapshots[tag].progress
            if not (progress and progress.canClaim and progress.targetProgress ~= nil) then break end
            local target = tonumber(progress.targetProgress)
            if not target then break end
            local ok, result = safeInvoke(NetMsg.INDEX_CLAIM_REWARD, { tag = tag, progress = target })
            if not (ok and type(result) == "table") then break end
            claimedAny = true
            Farm.Runtime.IndexClaims = Farm.Runtime.IndexClaims + 1
            Farm.Runtime.RewardsClaimed = Farm.Runtime.RewardsClaimed + 1
            Farm.Runtime.LastIndex = string.format("%s %d", tag, target)
            task.wait(0.18)
        end
    end
    return claimedAny
end
-- ============================================================================
-- MATERIAL SELLING
-- ============================================================================
local function collectSellableMaterialIds()
    local ids = {}
    local itemTypeMaterial = EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Material or nil
    if not itemTypeMaterial then
        return ids
    end
    for _, item in pairs(getBag()) do
        if type(item) == "table" and tonumber(item.tp) == tonumber(itemTypeMaterial) and not isLocked(item) then
            local id = tonumber(item.id)
            local onlyId = tonumber(item.onlyID)
            if id and onlyId then
                local sellable = true
                if GetData and type(GetData.IsMaterialSellable) == "function" and CfgFind and type(CfgFind.FindCfgByID) == "function" then
                    local okCfg, cfg = pcall(CfgFind.FindCfgByID, id, itemTypeMaterial)
                    if okCfg and cfg then
                        local okSell, result = pcall(GetData.IsMaterialSellable, cfg)
                        if okSell then
                            sellable = result == true
                        end
                    end
                end
                local protected = false
                local alchemy = GetData and GetData.Alchemy or nil
                if alchemy and type(alchemy.IsMarkedRecipeMaterial) == "function" then
                    local okProtected, result = pcall(alchemy.IsMarkedRecipeMaterial, LocalPlayer, id)
                    protected = okProtected and result == true
                end
                if sellable and not protected then
                    table.insert(ids, onlyId)
                end
            end
        end
    end
    return ids
end
local function toggleAlchemyRecipeMark(recipeId, wantMarked)
    recipeId = math.max(0, math.floor(tonumber(recipeId) or 0))
    if recipeId <= 0 or not (NetMsg and NetMsg.ALCHEMY_MARK_RECIPE) then
        return false
    end
    local before = getMarkedRecipeId()
    if wantMarked and before == recipeId then
        return true
    elseif not wantMarked and before == 0 then
        return true
    end
    local ok, result = safeInvoke(NetMsg.ALCHEMY_MARK_RECIPE, { recipeId = recipeId })
    if not (ok and result == true) then
        return false
    end
    local deadline = os.clock() + 1.5
    while Farm.Running and os.clock() < deadline do
        local now = getMarkedRecipeId()
        if wantMarked then
            if now == recipeId then
                return true
            end
        elseif now == 0 then
            return true
        end
        task.wait(0.05)
    end
    local now = getMarkedRecipeId()
    return wantMarked and now == recipeId or (not wantMarked and now == 0)
end
local function sellMaterials()
    if Farm.Runtime.GearTransaction then return false end
    if not (Farm.Config.Master and Farm.Config.AutoSellMaterials) then
        return false
    end
    local beforeSize = select(1, getWarehouseUsage())
    local originalMark = getMarkedRecipeId()
    local temporarilyUnmarked = false
    if Farm.Config.TemporarilyUnmarkAlchemyForSell and originalMark > 0 then
        local _, marked = getBackpackBreakdown()
        if marked > 0 then
            temporarilyUnmarked = toggleAlchemyRecipeMark(originalMark, false)
            if temporarilyUnmarked then
                task.wait(0.08)
            end
        end
    end
    local ids = collectSellableMaterialIds()
    if #ids == 0 then
        if temporarilyUnmarked then
            toggleAlchemyRecipeMark(originalMark, true)
        end
        local _, marked, locked, potions = getBackpackBreakdown()
        Farm.Runtime.LastSellResult = string.format("No sellable slots (marked %d, locked %d, potions %d)", marked, locked, potions)
        return false
    end
    Farm.Runtime.LastSellAt = os.clock()
    local ok, result = safeInvoke(NetMsg.SELL_MATERIAL, { onlyIDList = ids })
    if not (ok and result == true) then
        if temporarilyUnmarked then
            toggleAlchemyRecipeMark(originalMark, true)
        end
        Farm.Runtime.LastSellResult = "Sell request rejected"
        return false
    end
    local deadline = os.clock() + 3.0
    local afterSize = beforeSize
    while Farm.Running and os.clock() < deadline do
        afterSize = select(1, getWarehouseUsage())
        if afterSize < beforeSize then
            break
        end
        task.wait(0.06)
    end
    if temporarilyUnmarked then
        toggleAlchemyRecipeMark(originalMark, true)
    end
    local _, marked, locked, potions = getBackpackBreakdown()
    if afterSize < beforeSize then
        Farm.Runtime.MaterialsSold = Farm.Runtime.MaterialsSold + #ids
        Farm.Runtime.LastReward = "Sold " .. tostring(#ids) .. " materials"
        Farm.Runtime.LastSellResult = string.format("Sold %d (%d -> %d slots)", #ids, beforeSize, afterSize)
        return true
    end
    Farm.Runtime.LastSellResult = string.format("Sell accepted; Bag still %d (marked %d locked %d potions %d)", afterSize, marked, locked, potions)
    return false
end
-- ============================================================================
-- DUNGEON ECONOMY FARM
-- ============================================================================
local function getBroomDungeonLimitById(id)
    if not (EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Broom) then
        return 0
    end
    id = tonumber(id) or 0
    if id <= 0 then
        return 0
    end
    local cfg = findCfg(id, EnumMgr.ItemType.Broom)
    if type(cfg) ~= "table" or tonumber(cfg.tp) ~= tonumber(EnumMgr.ItemType.Broom) then
        return 0
    end
    return math.max(0, math.floor(tonumber(cfg.Dungeon) or 0))
end

local function getBroomJumpMax()
    local id = tonumber(equippedId("NowBroom")) or tonumber(getDataValue("NowBroom")) or 0
    return getBroomDungeonLimitById(id)
end

-- The native Stage Jump UI uses the equipped broom's Dungeon value. Before each
-- dungeon session, find the owned broom that reaches the deepest dungeon stage
-- and equip it. This never buys a broom; Auto Best Broom remains responsible
-- for purchases/upgrades.
local function prepareBestOwnedDungeonBroom()
    if not (EnumMgr and EnumMgr.ItemType and EnumMgr.ItemType.Broom) then
        return 0, 0
    end

    local broomType = EnumMgr.ItemType.Broom
    local bestId = 0
    local bestLimit = 0
    local bestSort = -math.huge
    local seen = {}

    local function consider(id)
        id = tonumber(id) or 0
        if id <= 0 or seen[id] then
            return
        end
        seen[id] = true
        if not ownsItem(id, broomType) then
            return
        end
        local cfg = findCfg(id, broomType)
        if type(cfg) ~= "table" or not gearAllowedByRebirth(cfg) then
            return
        end
        local limit = math.max(0, math.floor(tonumber(cfg.Dungeon) or 0))
        local sort = tonumber(cfg.Sort) or 0
        if limit > bestLimit or (limit == bestLimit and limit > 0 and sort > bestSort) then
            bestId = id
            bestLimit = limit
            bestSort = sort
        end
    end

    consider(equippedId("NowBroom"))
    for _, item in pairs(getBag()) do
        if type(item) == "table" and tonumber(item.tp) == tonumber(broomType)
            and (tonumber(item.count) or 1) > 0 then
            consider(item.id)
        end
    end

    if bestId <= 0 then
        return 0, 0
    end

    local currentId = tonumber(equippedId("NowBroom")) or 0
    if currentId ~= bestId then
        equipOwnedVerified(bestId, broomType, "NowBroom", "Broom")
        currentId = tonumber(equippedId("NowBroom")) or currentId
    end

    -- Prefer the value that is actually replicated as equipped. If replication
    -- is slightly delayed but the server accepted the equip, keep the selected
    -- broom limit as a short-lived fallback for the immediately following jump.
    local equippedLimit = getBroomDungeonLimitById(currentId)
    if currentId == bestId and equippedLimit > 0 then
        return bestId, equippedLimit
    end
    return bestId, math.max(equippedLimit, bestLimit)
end

local function getActualJumpMax(broomLimitOverride)
    local career = getCareerMaxStage()
    local broom = math.max(0, math.floor(tonumber(broomLimitOverride) or getBroomJumpMax()))
    if career <= 0 or broom <= 0 then
        return 0
    end
    return math.max(0, math.min(career + 1, broom))
end

-- Match the game's Stage Jump menu: only stages with a TeleIcon are actual
-- teleport destinations. Pick the deepest such destination the current broom
-- and career progress can reach.
local function getFurthestTeleportStage(maxJump)
    maxJump = math.max(0, math.floor(tonumber(maxJump) or 0))
    if maxJump <= 0 then
        return 0
    end
    if not (CfgFind and type(CfgFind.GetCfgByName) == "function") then
        return maxJump
    end

    local ok, dungeonCfg = pcall(CfgFind.GetCfgByName, "dungeonConf")
    if not ok or type(dungeonCfg) ~= "table" then
        return maxJump
    end

    local furthest = 0
    for id, cfg in pairs(dungeonCfg) do
        local stage = tonumber(id)
        local teleIcon = type(cfg) == "table" and cfg.TeleIcon or nil
        if stage and stage > 0 and stage <= maxJump
            and type(teleIcon) == "string" and teleIcon ~= "" then
            furthest = math.max(furthest, math.floor(stage))
        end
    end
    return furthest > 0 and furthest or maxJump
end

local function waitForBroomStageJumpLanding(targetStage, timeout)
    local started = os.clock()
    local deadline = started + math.max(2, tonumber(timeout) or 8)
    local sawJump = false
    local sawDungeon = false

    while Farm.Running and os.clock() < deadline do
        local jumping = isStageJumping()
        local inDungeon = isInDungeon()
        sawJump = sawJump or jumping
        sawDungeon = sawDungeon or inDungeon

        local currentStage = 0
        if Farm.Dungeon and type(Farm.Dungeon.currentStageId) == "function" then
            local okStage, stage = pcall(Farm.Dungeon.currentStageId)
            if okStage then currentStage = math.max(0, math.floor(tonumber(stage) or 0)) end
        end

        -- Do not begin normal farming while the broom jump is still animating.
        -- Once landed, either the requested stage or any live dungeon stage is
        -- enough to hand control back to the normal dungeon driver.
        if not jumping and inDungeon then
            if currentStage >= targetStage or (sawJump and currentStage > 0) then
                Farm.Runtime.LastDungeonStage = math.max(Farm.Runtime.LastDungeonStage or 0, currentStage, targetStage)
                return true
            end
            if not sawJump and os.clock() - started >= 1.6 and currentStage > 0 then
                return true
            end
        end

        -- If the request was rejected, stop waiting and let the normal walk-in
        -- route take over instead of stalling the whole autofarm.
        if not sawJump and not sawDungeon and os.clock() - started >= 1.75 then
            return false
        end
        task.wait(0.035)
    end

    return isInDungeon() and not isStageJumping()
end
local function getNextBattleArea()
    local stage = getRunMaxClear() + 1
    if stage <= 0 then
        return nil, nil
    end
    local scene = Workspace:FindFirstChild("场景")
    if not scene then
        return nil, stage
    end
    local model = scene:FindFirstChild(tostring(stage))
    if not model then
        return nil, stage
    end
    local part = model:FindFirstChild("战斗区域", true)
    if part and part:IsA("BasePart") then
        return part, stage
    end
    return nil, stage
end
local function modelPosition(model)
    if not model or not model.Parent then
        return nil
    end
    if model:IsA("BasePart") then
        return model.Position
    end
    if model:IsA("Model") then
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if root and root:IsA("BasePart") then
            return root.Position
        end
        local ok, pivot = pcall(model.GetPivot, model)
        if ok then
            return pivot.Position
        end
    end
    return nil
end
local function modelCFrame(model)
    if not model or not model.Parent then
        return nil
    end
    if model:IsA("BasePart") then
        return model.CFrame
    end
    if model:IsA("Model") then
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if root and root:IsA("BasePart") then
            return root.CFrame
        end
        local ok, pivot = pcall(model.GetPivot, model)
        if ok then
            return pivot
        end
    end
    return nil
end
local function isBossEnemy(enemy)
    if not enemy or not enemy.Parent then
        return false
    end
    if enemy:GetAttribute("Boss") == true then
        return true
    end
    if enemy:IsA("Model") then
        local primary = enemy.PrimaryPart
        if primary and primary:GetAttribute("Boss") == true then
            return true
        end
        local root = enemy:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") and root:GetAttribute("Boss") == true then
            return true
        end
    elseif enemy:IsA("BasePart") and enemy:GetAttribute("Boss") == true then
        return true
    end
    return false
end
local function bossIntroPlaying()
    if not Farm.Config.WaitForBossIntro then
        return false
    end
    if type(DwarfKingAppearPresentation) ~= "table"
        or type(DwarfKingAppearPresentation.IsPlaying) ~= "function" then
        return false
    end
    local ok, playing = pcall(DwarfKingAppearPresentation.IsPlaying)
    return ok and playing == true
end
local function waitForBossIntro(maxSeconds)
    if not Farm.Config.WaitForBossIntro then
        return true
    end
    maxSeconds = tonumber(maxSeconds) or 12
    local started = os.clock()
    while Farm.Running and bossIntroPlaying() and os.clock() - started < maxSeconds do
        setPhase("Waiting for boss intro")
        Farm.Runtime.LastDungeonTarget = "Boss intro..."
        task.wait(0.08)
    end
    return not bossIntroPlaying()
end
-- ============================================================================
-- DUNGEON COMBAT POSITION CONTROLLER
-- ============================================================================
Farm.Position = Farm.Position or {}
function Farm.Position.mode()
    return tostring(Farm.Config.DungeonPositionMode or "Overhead")
end
function Farm.Position.enemyClearance(enemy)
    local extra = 0
    if enemy and enemy.Parent and enemy:IsA("Model") then
        local ok, size = pcall(enemy.GetExtentsSize, enemy)
        if ok and typeof(size) == "Vector3" then
            extra = math.clamp(math.max(size.X, size.Z) * 0.12, 0, 7)
        end
    end
    return extra
end
function Farm.Position.seedOrbit(enemy)
    if Farm.Runtime.CombatOrbitTarget == enemy then
        return
    end
    Farm.Runtime.CombatOrbitTarget = enemy
    local enemyCF = modelCFrame(enemy)
    local _, _, root = getCharacter()
    if not enemyCF or not root then
        Farm.Runtime.CombatOrbitAngle = 0
        return
    end
    local relative = enemyCF:VectorToObjectSpace(root.Position - enemyCF.Position)
    Farm.Runtime.CombatOrbitAngle = math.atan2(relative.Z, relative.X)
end
function Farm.Position.desiredCFrame(enemy)
    if not enemy or not enemy.Parent then
        return nil
    end
    local enemyCF = modelCFrame(enemy)
    if not enemyCF then
        return nil
    end
    local mode = Farm.Position.mode()
    if mode == "Normal" then
        return nil
    end
    local enemyPos = enemyCF.Position
    local requested = math.clamp(tonumber(Farm.Config.DungeonEnemyRange) or 19, 6, 55)
    local look = enemyCF.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then
        flat = Vector3.new(0, 0, -1)
    else
        flat = flat.Unit
    end
    local right = Vector3.new(-flat.Z, 0, flat.X)
    local horizontal = math.min(55, requested + Farm.Position.enemyClearance(enemy))
    local desired
    if mode == "Overhead" then
        local height = math.min(requested, 28)
        desired = enemyPos + Vector3.new(0, height, 0)
    elseif mode == "Below" then
        local depth = math.min(requested, 28)
        desired = enemyPos - Vector3.new(0, depth, 0)
    elseif mode == "Behind" then
        desired = enemyPos - flat * horizontal + Vector3.new(0, 2.5, 0)
    elseif mode == "Front" then
        desired = enemyPos + flat * horizontal + Vector3.new(0, 2.5, 0)
    elseif mode == "Side" then
        desired = enemyPos + right * horizontal + Vector3.new(0, 2.5, 0)
    elseif mode == "Left" then
        desired = enemyPos - right * horizontal + Vector3.new(0, 2.5, 0)
    elseif mode == "Orbit" then
        Farm.Position.seedOrbit(enemy)
        local angle = tonumber(Farm.Runtime.CombatOrbitAngle) or 0
        local radius = requested
        local height = math.min(8, math.max(3, radius * 0.12))
        desired = enemyPos
            + right * (math.cos(angle) * radius)
            + flat * (math.sin(angle) * radius)
            + Vector3.new(0, height, 0)
    else
        desired = enemyPos - flat * horizontal + Vector3.new(0, 2.5, 0)
    end
    if Farm.Config.CombatFaceTarget == false then
        local _, _, root = getCharacter()
        if root then
            return CFrame.new(desired) * (root.CFrame - root.CFrame.Position)
        end
        return CFrame.new(desired)
    end
    if (enemyPos - desired).Magnitude < 0.05 then
        return CFrame.new(desired)
    end
    if mode == "Overhead" then
        return CFrame.lookAt(desired, enemyPos, Vector3.new(0, 0, -1))
    elseif mode == "Below" then
        return CFrame.lookAt(desired, enemyPos, Vector3.new(0, 0, 1))
    end
    return CFrame.lookAt(desired, enemyPos)
end
function Farm.Position.setNoclip(active)
    active = active == true and Farm.Config.CombatNoclip == true
    local character, humanoid = getCharacter()
    if not active or not character then
        if Farm.Runtime.CombatNoclipActive then
            for part, oldValue in pairs(Farm.Runtime.CombatCollisionCache or {}) do
                if part and part.Parent and part:IsA("BasePart") then
                    pcall(function()
                        part.CanCollide = oldValue == true
                    end)
                end
            end
            if humanoid and Farm.Runtime.CombatAutoRotateBefore ~= nil then
                pcall(function()
                    humanoid.AutoRotate = Farm.Runtime.CombatAutoRotateBefore == true
                end)
            end
        end
        Farm.Runtime.CombatCollisionCache = {}
        Farm.Runtime.CombatNoclipActive = false
        Farm.Runtime.CombatNoclipCharacter = nil
        Farm.Runtime.CombatAutoRotateBefore = nil
        return
    end
    if Farm.Runtime.CombatNoclipActive
        and Farm.Runtime.CombatNoclipCharacter == character then
        return
    end
    if Farm.Runtime.CombatNoclipActive then
        Farm.Position.setNoclip(false)
    end
    Farm.Runtime.CombatCollisionCache = {}
    Farm.Runtime.CombatNoclipCharacter = character
    Farm.Runtime.CombatNoclipActive = true
    Farm.Runtime.CombatAutoRotateBefore = humanoid and humanoid.AutoRotate or nil
    if humanoid then
        pcall(function()
            humanoid.AutoRotate = false
            humanoid.Sit = false
            humanoid.PlatformStand = false
        end)
    end
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            Farm.Runtime.CombatCollisionCache[object] = object.CanCollide
            pcall(function()
                object.CanCollide = false
            end)
        end
    end
end
function Farm.Position.setTarget(enemy)
    if not enemy or not enemy.Parent then
        return false
    end
    if Farm.Runtime.PositionTarget ~= enemy then
        Farm.Runtime.PositionTarget = enemy
        Farm.Runtime.PositionTargetSince = os.clock()
        Farm.Runtime.PositionState = "Tracking"
        Farm.Runtime.PositionHoldUntil = -math.huge
        Farm.Position.seedOrbit(enemy)
    end
    local enemyPos = modelPosition(enemy)
    local cf = Farm.Position.desiredCFrame(enemy)
    if enemyPos then
        Farm.Runtime.LastCombatEnemyPos = enemyPos
        Farm.Runtime.LastEnemySeenAt = os.clock()
        Farm.Runtime.NoEnemySince = nil
    end
    if cf then
        Farm.Runtime.LastCombatCFrame = cf
        Farm.Runtime.LastCombatAnchor = cf.Position
    end
    Farm.Runtime.LastCombatPosition = Farm.Position.mode()
    Farm.Runtime.LastTargetModel = enemy
    return true
end
function Farm.Position.holdLast(seconds)
    if not Farm.Config.PersistCombatPosition then
        Farm.Runtime.PositionTarget = nil
        Farm.Runtime.PositionHoldUntil = -math.huge
        Farm.Runtime.PositionState = "Idle"
        Farm.Position.setNoclip(false)
        return false
    end
    Farm.Runtime.PositionTarget = nil
    Farm.Runtime.PositionHoldUntil = math.max(
        tonumber(Farm.Runtime.PositionHoldUntil) or -math.huge,
        os.clock() + math.max(0.05, tonumber(seconds) or 0.20)
    )
    Farm.Runtime.PositionState = "Handoff"
    return typeof(Farm.Runtime.LastCombatCFrame) == "CFrame"
end
function Farm.Position.release(clearAnchor)
    Farm.Runtime.PositionTarget = nil
    Farm.Runtime.PositionHoldUntil = -math.huge
    Farm.Runtime.PositionState = "Idle"
    Farm.Runtime.CombatOrbitTarget = nil
    Farm.Position.setNoclip(false)
    if clearAnchor == true then
        Farm.Runtime.LastCombatAnchor = nil
        Farm.Runtime.LastCombatEnemyPos = nil
        Farm.Runtime.LastCombatCFrame = nil
    end
end
function Farm.Position.applyCFrame(cf)
    if typeof(cf) ~= "CFrame" then
        return false
    end
    local _, humanoid, root = getCharacter()
    if not root or not humanoid then
        return false
    end
    pcall(function()
        humanoid.Sit = false
        humanoid.PlatformStand = false
        if Farm.Config.CombatDirectLock == false then
            local distance = (root.Position - cf.Position).Magnitude
            local alpha = distance <= 8 and 1 or math.clamp(85 / math.max(distance, 85), 0.28, 0.82)
            root.CFrame = root.CFrame:Lerp(cf, alpha)
        else
            root.CFrame = cf
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end
function Farm.Position.step(dt)
    if not Farm.Running
        or not Farm.Config.Master
        or not Farm.Runtime.DungeonRunning
        or not isInDungeon()
        or Farm.Runtime.Selling then
        Farm.Position.release(false)
        return
    end
    if bossIntroPlaying() then
        Farm.Position.setNoclip(false)
        return
    end
    local mode = Farm.Position.mode()
    if mode == "Normal" then
        Farm.Position.setNoclip(false)
        return
    end
    local target = Farm.Runtime.PositionTarget
    if target and target.Parent then
        if mode == "Orbit" then
            Farm.Runtime.CombatOrbitAngle = (tonumber(Farm.Runtime.CombatOrbitAngle) or 0)
                + math.max(0.1, tonumber(Farm.Config.DungeonOrbitSpeed) or 0.65)
                * math.pi * 2 * math.max(0, tonumber(dt) or 0)
        end
        local cf = Farm.Position.desiredCFrame(target)
        if cf then
            Farm.Runtime.LastCombatCFrame = cf
            Farm.Runtime.LastCombatAnchor = cf.Position
            local pos = modelPosition(target)
            if pos then Farm.Runtime.LastCombatEnemyPos = pos end
            Farm.Position.setNoclip(true)
            Farm.Position.applyCFrame(cf)
            return
        end
    end
    if Farm.Config.PersistCombatPosition
        and os.clock() <= (tonumber(Farm.Runtime.PositionHoldUntil) or -math.huge)
        and typeof(Farm.Runtime.LastCombatCFrame) == "CFrame" then
        Farm.Position.setNoclip(true)
        Farm.Position.applyCFrame(Farm.Runtime.LastCombatCFrame)
        return
    end
    Farm.Position.setNoclip(false)
end
function Farm.Position.stageAnchor(area)
    if not area or not area:IsA("BasePart") then
        return nil
    end
    local mode = Farm.Position.mode()
    local requested = math.clamp(tonumber(Farm.Config.DungeonEnemyRange) or 19, 6, 55)
    local center = area.Position
    local look = area.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then
        flat = Vector3.new(0, 0, -1)
    else
        flat = flat.Unit
    end
    local right = Vector3.new(-flat.Z, 0, flat.X)
    if mode == "Overhead" then
        return center + Vector3.new(0, math.min(requested, 28), 0)
    elseif mode == "Below" then
        return center - Vector3.new(0, math.min(requested, 28), 0)
    elseif mode == "Orbit" then
        return center + right * requested + Vector3.new(0, math.min(8, math.max(3, requested * 0.12)), 0)
    elseif mode == "Behind" then
        return center - flat * requested + Vector3.new(0, 2.5, 0)
    elseif mode == "Front" then
        return center + flat * requested + Vector3.new(0, 2.5, 0)
    elseif mode == "Side" then
        return center + right * requested + Vector3.new(0, 2.5, 0)
    elseif mode == "Left" then
        return center - right * requested + Vector3.new(0, 2.5, 0)
    end
    return nil
end
function Farm.Position.prePositionForStage(area)
    if not Farm.Config.PersistCombatPosition then
        return false
    end
    local anchor = Farm.Position.stageAnchor(area)
    if not anchor then
        return false
    end
    local lookAt = area.Position
    local cf = CFrame.lookAt(anchor, lookAt)
    Farm.Runtime.LastCombatAnchor = anchor
    Farm.Runtime.LastCombatEnemyPos = lookAt
    Farm.Runtime.LastCombatCFrame = cf
    Farm.Runtime.PositionHoldUntil = os.clock() + 1.5
    Farm.Runtime.PositionState = "Stage pre-position"
    return combatTweenTo(anchor, lookAt, 0.36)
end
local function gatherEnemies()
    if SystemDungeon then
        local stage = 0
        if type(SystemDungeon.GetCurrentStageId) == "function" then
            local okStage, value = pcall(SystemDungeon.GetCurrentStageId, LocalPlayer)
            if okStage then stage = math.max(0, math.floor(tonumber(value) or 0)) end
        end
        if stage > 0 and type(SystemDungeon.GetAliveStageEnemiesForStage) == "function" then
            local ok, list = pcall(SystemDungeon.GetAliveStageEnemiesForStage, LocalPlayer, stage)
            if ok and type(list) == "table" then return list end
        end
        if type(SystemDungeon.GetAliveStageEnemies) == "function" then
            local ok, list = pcall(SystemDungeon.GetAliveStageEnemies, LocalPlayer)
            if ok and type(list) == "table" then return list end
        end
    end
    if SkillCommon and type(SkillCommon.gatherAliveCombatHostiles) == "function" then
        local ok, list = pcall(SkillCommon.gatherAliveCombatHostiles, LocalPlayer)
        if ok and type(list) == "table" then return list end
    end
    return {}
end
local function nearestEnemy()
    local _, _, root = getCharacter()
    if not root then return nil, nil, math.huge end
    local list = gatherEnemies()
    local sticky = Farm.Runtime.LastTargetModel
    if sticky and sticky.Parent then
        for _, enemy in ipairs(list) do
            if enemy == sticky then
                local pos = modelPosition(enemy)
                if pos then return enemy, pos, (root.Position - pos).Magnitude end
                break
            end
        end
    end
    local best, bestPos, bestDist = nil, nil, math.huge
    local bossBest, bossPos, bossDist = nil, nil, math.huge
    for _, enemy in ipairs(list) do
        local pos = modelPosition(enemy)
        if pos then
            local dist = (root.Position - pos).Magnitude
            if isBossEnemy(enemy) then
                if dist < bossDist then bossBest, bossPos, bossDist = enemy, pos, dist end
            elseif dist < bestDist then
                best, bestPos, bestDist = enemy, pos, dist
            end
        end
    end
    if bossBest then return bossBest, bossPos, bossDist end
    return best, bestPos, bestDist
end
local function setNativeTarget(enemy)
    local target = ReplicatedStorage:FindFirstChild("NowTargetCurrent")
    if target and target:IsA("ObjectValue") then
        pcall(function()
            target.Value = enemy
        end)
    end
end
Farm.Dungeon = Farm.Dungeon or {}
function Farm.Dungeon.isStageSafe()
    return Farm.Fast._numberValue("InStageSafeArea") > 0
end
function Farm.Dungeon.currentStageId()
    if SystemDungeon and type(SystemDungeon.GetCurrentStageId) == "function" then
        local ok, value = pcall(SystemDungeon.GetCurrentStageId, LocalPlayer)
        if ok then
            local id = math.max(0, math.floor(tonumber(value) or 0))
            if id > 0 then return id end
        end
    end
    return 0
end
function Farm.Dungeon.hasStageCombatSession(stage)
    stage = math.max(0, math.floor(tonumber(stage) or 0))
    if stage <= 0 then return false end
    if SystemDungeon and type(SystemDungeon.HasStageCombatSession) == "function" then
        local ok, value = pcall(SystemDungeon.HasStageCombatSession, LocalPlayer, stage)
        if ok then return value == true end
    end
    return Farm.Dungeon.currentStageId() == stage and isInDungeon()
end
function Farm.Dungeon.stageReady(stage, wasInDungeon)
    stage = math.max(0, math.floor(tonumber(stage) or 0))
    if stage > 0 then
        if Farm.Dungeon.currentStageId() == stage then return true end
        if Farm.Dungeon.hasStageCombatSession(stage) then return true end
    end
    if not wasInDungeon and isInDungeon() then return true end
    return #gatherEnemies() > 0
end
function Farm.Dungeon.waitForNativeStageSpawn(area, stage, wasInDungeon)
    if not area or not area:IsA("BasePart") then return false end
    local started = os.clock()
    local hardDeadline = started + 12
    local sawIntro = false
    local introEndedAt = nil
    while Farm.Running and os.clock() < hardDeadline do
        local _, _, root = getCharacter()
        if not root or not isPointInsidePart(area, root.Position) then
            return false
        end
        local playing = bossIntroPlaying()
        if playing then
            sawIntro = true
            introEndedAt = nil
            setPhase("Waiting for boss intro inside stage trigger")
            Farm.Runtime.LastDungeonTarget = "Boss intro..."
        else
            if sawIntro and not introEndedAt then introEndedAt = os.clock() end
            if os.clock() - started >= 0.45 and Farm.Dungeon.stageReady(stage, wasInDungeon) then
                return true
            end
            if not sawIntro and os.clock() - started >= 0.65 then
                return true
            end
            if introEndedAt and os.clock() - introEndedAt >= 0.75 then
                return true
            end
        end
        task.wait(0.03)
    end
    return Farm.Dungeon.stageReady(stage, wasInDungeon)
end
local function returnToTownAndSell(reason)
    if Farm.Runtime.Selling then
        return false
    end
    if not (Farm.Config.Master and Farm.Config.AutoSellMaterials) then
        return false
    end
    Farm.Runtime.Selling = true
    Farm.Runtime.EmergencySellRequested = false
    setNativeTarget(nil)
    releaseMovement("Dungeon")
    local current, maximum = getDungeonBagUsage()
    setPhase(string.format("%s - returning to sell (%d/%d)", tostring(reason or "Backpack"), current, maximum))
    Farm.Runtime.LastDungeonTarget = "Selling backpack"
    if isInDungeon() then
        safeFire(NetMsg.DUNGEON_RETURN_TOWN)
        local leaveDeadline = os.clock() + 8
        while Farm.Running and isInDungeon() and os.clock() < leaveDeadline do
            task.wait(0.04)
        end
    end
    if isInDungeon() then
        Farm.Runtime.LastSellResult = "Could not leave dungeon"
        Farm.Runtime.Selling = false
        return false
    end
    task.wait(0.07)
    local sold = false
    for attempt = 1, 3 do
        sold = sellMaterials()
        local nowSize = select(1, getDungeonBagUsage())
        if nowSize < current then
            break
        end
        if not backpackNeedsSell() then
            sold = true
            break
        end
        task.wait(0.10)
    end
    local afterCurrent, afterMaximum, afterPercent = getDungeonBagUsage()
    local stillPressure = backpackPressureReached()
    if stillPressure then
        Farm.Runtime.BackpackBlocked = true
        Farm.Runtime.BackpackBlockedReason = string.format("Dungeon bag still %d/%d after return/sell", afterCurrent, afterMaximum)
        Farm.Runtime.LastSellResult = Farm.Runtime.LastSellResult .. " | BLOCKED: " .. Farm.Runtime.BackpackBlockedReason
    else
        Farm.Runtime.BackpackBlocked = false
        Farm.Runtime.BackpackBlockedReason = "None"
    end
    Farm.Runtime.Selling = false
    Farm.Runtime.LastDungeonTarget = "None"
    Farm.Runtime.LastTrainDecisionAt = -math.huge
    if sold and not stillPressure then
        pcall(Farm.Fast.gearTick, true)
        if Farm.Config.AutoHoldBestWand and not Farm.Fast.heldSwitchBlocked() then
            Farm.Fast.ensureBestWandHeld("after sell/gear", 0.18)
        end
        setPhase("Backpack sold - gear checked")
        if Farm.Config.ResumeDungeonAfterSell then
            Farm.Runtime.LastDungeonAt = -math.huge
        end
    else
        setPhase("Backpack sell failed")
    end
    return sold
end
local PickupPrompts = setmetatable({}, {__mode = "k"})
local LastPickupPromptScanAt = -math.huge
local function getDropsClientRoot()
    local root = Workspace:FindFirstChild("DropsClient")
    return root and root:IsA("Model") and root or nil
end
local function promptLooksLikeDungeonLoot(inst)
    if not (inst and inst:IsA("ProximityPrompt")) then
        return false
    end
    if inst.Name == "PickupPrompt" then
        return true
    end
    local node = inst.Parent
    while node and node ~= Workspace do
        if node:IsA("Model") then
            if node:GetAttribute("ItemId") ~= nil
                or node:GetAttribute("DropId") ~= nil
                or node:GetAttribute("DropID") ~= nil
                or node.Name == "DropItem" then
                return true
            end
        end
        node = node.Parent
    end
    local action = string.lower(tostring(inst.ActionText or ""))
    local object = string.lower(tostring(inst.ObjectText or ""))
    return string.find(action, "pick", 1, true) ~= nil
        or string.find(action, "collect", 1, true) ~= nil
        or string.find(object, "loot", 1, true) ~= nil
        or string.find(object, "drop", 1, true) ~= nil
end
local function registerPickupPrompt(inst)
    if promptLooksLikeDungeonLoot(inst) then
        PickupPrompts[inst] = true
    end
end
local function refreshPickupPrompts(force)
    local now = os.clock()
    if not force and now - LastPickupPromptScanAt < 0.15 then
        return
    end
    LastPickupPromptScanAt = now
    -- Magic Loot's real client drop controller stores active dungeon drops under
    -- Workspace.DropsClient/<rarity>/<dropId>/Root/PickupPrompt.
    local root = getDropsClientRoot()
    local scanRoot = root or Workspace
    for _, inst in ipairs(scanRoot:GetDescendants()) do
        registerPickupPrompt(inst)
    end
end
refreshPickupPrompts(true)
track(Workspace.DescendantAdded:Connect(registerPickupPrompt))
track(Workspace.DescendantRemoving:Connect(function(inst)
    if PickupPrompts[inst] then
        PickupPrompts[inst] = nil
    end
end))
local RARITY_NAMES = {
    [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic",
    [5] = "Legendary", [6] = "Mythic", [7] = "Secret",
}
local function getDropModelFromPrompt(prompt)
    local node = prompt and prompt.Parent
    local fallback = nil
    while node and node ~= Workspace do
        if node:IsA("Model") then
            if node:GetAttribute("ItemId") ~= nil then
                return node
            end
            if not fallback and (node.Name == "DropItem"
                or node:GetAttribute("DropId") ~= nil
                or node:GetAttribute("DropID") ~= nil) then
                fallback = node
            end
        end
        node = node.Parent
    end
    return fallback
end
Farm.Loot = Farm.Loot or {}
Farm.Loot.PickupCooldown = Farm.Loot.PickupCooldown or setmetatable({}, {__mode = "k"})
function Farm.Loot.currentStageId()
    local aggro = Farm.Fast and Farm.Fast._numberValue and Farm.Fast._numberValue("DungeonAggroStage") or 0
    aggro = math.max(0, math.floor(tonumber(aggro) or 0))
    if aggro > 0 then return aggro end
    if Farm.Dungeon and type(Farm.Dungeon.currentStageId) == "function" then
        local ok, stage = pcall(Farm.Dungeon.currentStageId)
        stage = ok and math.max(0, math.floor(tonumber(stage) or 0)) or 0
        if stage > 0 then return stage end
    end
    return math.max(0, math.floor(tonumber(Farm.Runtime.LastDungeonStage) or 0))
end
function Farm.Loot.resetBatch(stage)
    Farm.Runtime.LootBatchStage = math.max(0, math.floor(tonumber(stage) or 0))
    Farm.Runtime.LootBatchReady = false
    Farm.Runtime.LootBatchCandidateCount = 0
    Farm.Runtime.LootBatchMaxValue = 0
    Farm.Runtime.LootBatchThreshold = 0
    Farm.Loot.BatchStartedAt = nil
    Farm.Loot.BatchFirstPromptAt = nil
    Farm.Loot.BatchLastChangeAt = nil
    Farm.Loot.BatchLastCount = nil
    Farm.Loot.BatchCombatActive = false
end
function Farm.Loot.markCombat(stage)
    stage = math.max(0, math.floor(tonumber(stage) or 0))
    if stage <= 0 then return end
    if tonumber(Farm.Runtime.LootBatchStage) ~= stage or Farm.Loot.BatchCombatActive ~= true then
        Farm.Loot.resetBatch(stage)
    end
    Farm.Loot.BatchCombatActive = true
end
local function getDropInfo(prompt)
    local drop = getDropModelFromPrompt(prompt)
    if not drop then return nil end
    local itemId = tonumber(drop:GetAttribute("ItemId"))
    local xyd = tonumber(drop:GetAttribute("Xyd")) or 1
    local value = tonumber(drop:GetAttribute("GoldValue")) or 0
    local cfg = nil
    if itemId and CfgFind and type(CfgFind.FindCfgByID) == "function" then
        local ok, result = pcall(CfgFind.FindCfgByID, itemId)
        if ok and type(result) == "table" then cfg = result end
    end
    if cfg then
        xyd = tonumber(cfg.xyd) or xyd
        value = tonumber(cfg.GoldValue) or value
    end
    local name = cfg and (cfg.ZhName or cfg.Name) or (drop.Name ~= "DropItem" and drop.Name or tostring(itemId or "Drop"))
    local dropId = drop:GetAttribute("DropId")
        or drop:GetAttribute("DropID")
        or drop:GetAttribute("UID")
        or drop:GetAttribute("Uid")
        or drop:GetAttribute("Guid")
        or drop:GetAttribute("GUID")
        or drop:GetAttribute("Id")
        or drop:GetAttribute("ID")
    -- Game-verified: DropVisual creates the model with Name = dropId, then the
    -- native PickupPrompt callback fires NetMsg.DROP_PICKUP with that same key.
    if dropId == nil and type(drop.Name) == "string" and drop.Name ~= "" and drop.Name ~= "DropItem" then
        dropId = drop.Name
    end
    return {
        model = drop,
        id = itemId,
        rarity = math.max(1, math.floor(xyd or 1)),
        value = math.max(0, value or 0),
        name = tostring(name or itemId or "Drop"),
        dropId = dropId,
        stage = math.max(0, math.floor(tonumber(drop:GetAttribute("Stage")) or 0)),
        landed = drop:GetAttribute("DropLanded") == true or (prompt and prompt.Enabled == true),
        areaId = cfg and tonumber(cfg.AreaID) or nil,
    }
end
function Farm.Loot.stageMatches(info, stage)
    if type(info) ~= "table" then return false end
    stage = math.max(0, math.floor(tonumber(stage) or 0))
    local dropStage = math.max(0, math.floor(tonumber(info.stage) or 0))
    return stage <= 0 or dropStage <= 0 or dropStage == stage
end

-- Smart loot is deliberately progression-biased. Dungeon loot improves as the
-- run goes deeper, so filling LimitBagUsed on the opening stages wastes slots.
-- CareerMaxStage is the best practical estimate of where this character can
-- reach again; the final few seconds become a harvest window if the run is
-- slower than expected.
function Farm.Loot.deepStagePlan(stage)
    stage = math.max(1, math.floor(tonumber(stage) or 1))
    local career = math.max(0, math.floor(tonumber(getCareerMaxStage()) or 0))
    local target = math.max(stage, career > 0 and (career + 1) or stage)
    local pct = math.clamp((tonumber(Farm.Config.SmartLootDeepStagePercent) or 82) / 100, 0.50, 1.00)
    local harvestStart = math.max(stage > target and stage or 1, math.floor(target * pct + 0.5))
    harvestStart = math.min(harvestStart, target)
    local deadline = tonumber(Farm.Runtime.DungeonSessionDeadline) or 0
    local remaining = deadline > 0 and math.max(0, deadline - os.clock()) or math.huge
    local finalSeconds = math.clamp(tonumber(Farm.Config.SmartLootFinalHarvestSeconds) or 6.0, 2.0, 12.0)
    local finalWindow = remaining <= finalSeconds
    return target, harvestStart, remaining, finalWindow
end

function Farm.Loot.smartEligible(info, stage, batchMax, threshold, questTargets, unseen)
    if type(info) ~= "table" then return false end
    local itemId = tonumber(info.id)
    if Farm.Config.AutoFarmEventQuests and itemId and questTargets and questTargets[itemId] then
        return true, "quest"
    end
    if Farm.Config.PrioritizeUnseenIndexLoot and itemId and unseen and unseen[itemId] then
        return true, "index"
    end

    local alwaysRarity = math.clamp(math.floor(tonumber(Farm.Config.SmartLootAlwaysRarity) or 5), 3, 7)
    if (tonumber(info.rarity) or 1) >= alwaysRarity then
        return true, "exceptional rarity"
    end

    local target, harvestStart, remaining, finalWindow = Farm.Loot.deepStagePlan(stage)
    local deepEnough = stage >= harvestStart
    if not deepEnough and not finalWindow then
        return false, string.format("saving slots for stage %d+", harvestStart)
    end

    local qualityRatio = math.clamp((tonumber(Farm.Config.SmartLootQualityPercent) or 65) / 100, 0.10, 0.95)
    -- During the emergency/final harvest window, loosen the floor a little, but
    -- still never fall back to collecting every cheap leftover.
    if finalWindow and stage < harvestStart then
        qualityRatio = math.max(0.45, qualityRatio * 0.78)
    end
    local dynamicFloor = math.max(tonumber(threshold) or 0, (tonumber(batchMax) or 0) * qualityRatio)
    if (tonumber(info.value) or 0) >= dynamicFloor then
        return true, finalWindow and "final harvest" or "deep-stage premium"
    end

    return false, string.format("below smart floor %.0f", dynamicFloor)
end
function Farm.Loot.collectStageCandidates(maxDistance)
    refreshPickupPrompts(false)
    local results = {}
    local _, _, root = getCharacter()
    if not root then return results end
    local stage = Farm.Loot.currentStageId()
    local radius = tonumber(maxDistance) or 90
    for inst in pairs(PickupPrompts) do
        if inst.Parent and inst.Parent:IsA("BasePart") then
            local dist = (root.Position - inst.Parent.Position).Magnitude
            if dist <= radius then
                local info = getDropInfo(inst)
                if info and Farm.Loot.stageMatches(info, stage) then
                    local cooldown = Farm.Loot.PickupCooldown and Farm.Loot.PickupCooldown[info.model] or 0
                    if os.clock() >= (tonumber(cooldown) or 0) then
                        results[#results + 1] = { prompt = inst, dist = dist, info = info }
                    end
                end
            end
        else
            PickupPrompts[inst] = nil
        end
    end
    return results
end
function Farm.Loot.batchReady(maxDistance)
    if tostring(Farm.Config.LootPriority or "Smart") ~= "Smart" then return true end
    local stage = Farm.Loot.currentStageId()
    if stage <= 0 then return true end
    if tonumber(Farm.Runtime.LootBatchStage) ~= stage then
        Farm.Loot.resetBatch(stage)
    end
    Farm.Loot.BatchCombatActive = false
    local now = os.clock()
    if not Farm.Loot.BatchStartedAt then
        Farm.Loot.BatchStartedAt = now
        Farm.Loot.BatchLastChangeAt = now
    end
    local candidates = Farm.Loot.collectStageCandidates(maxDistance)
    local count = #candidates
    local maxValue = tonumber(Farm.Runtime.LootBatchMaxValue) or 0
    for _, row in ipairs(candidates) do
        maxValue = math.max(maxValue, tonumber(row.info and row.info.value) or 0)
    end
    Farm.Runtime.LootBatchMaxValue = maxValue
    Farm.Runtime.LootBatchCandidateCount = math.max(tonumber(Farm.Runtime.LootBatchCandidateCount) or 0, count)
    if count > 0 and not Farm.Loot.BatchFirstPromptAt then
        Farm.Loot.BatchFirstPromptAt = now
    end
    if Farm.Loot.BatchLastCount ~= count then
        Farm.Loot.BatchLastCount = count
        Farm.Loot.BatchLastChangeAt = now
    end
    if Farm.Runtime.LootBatchReady then return true end
    local elapsed = now - (Farm.Loot.BatchStartedAt or now)
    local firstElapsed = Farm.Loot.BatchFirstPromptAt and (now - Farm.Loot.BatchFirstPromptAt) or 0
    local quiet = now - (Farm.Loot.BatchLastChangeAt or now)
    local configuredWait = math.clamp(tonumber(Farm.Config.SmartLootBatchWaitSeconds) or 0.35, 0.15, 1.10)
    local settleFirst = math.min(0.24, configuredWait * 0.70)
    local settleQuiet = math.min(0.10, configuredWait * 0.30)
    if (count > 0 and firstElapsed >= settleFirst and quiet >= settleQuiet) or elapsed >= configuredWait then
        Farm.Runtime.LootBatchReady = true
        local qualityRatio = math.clamp((tonumber(Farm.Config.SmartLootQualityPercent) or 65) / 100, 0.10, 0.95)
        Farm.Runtime.LootBatchThreshold = maxValue > 0 and (maxValue * qualityRatio) or 0
        Farm.Runtime.LootDecision = string.format(
            "Stage %d batch %d • premium >= %s • batch max %s",
            stage,
            tonumber(Farm.Runtime.LootBatchCandidateCount) or count,
            tostring(math.floor(tonumber(Farm.Runtime.LootBatchThreshold) or 0)),
            tostring(math.floor(maxValue))
        )
        return true
    end
    Farm.Runtime.LootDecision = string.format(
        "Waiting stage %d drop batch • landed %d • %.2fs",
        stage, count, elapsed
    )
    return false
end
local function bestPickupPrompt(maxDistance)
    if backpackPressureReached() then return nil, math.huge end
    refreshPickupPrompts(false)
    local _, _, root = getCharacter()
    if not root then return nil, math.huge end
    local mode = tostring(Farm.Config.LootPriority or "Smart")
    local questTargets = mode == "Smart" and getActiveQuestMaterialTargets() or {}
    local unseen = (mode == "Smart" and Farm.Config.PrioritizeUnseenIndexLoot) and getUncollectedIndexMaterialSet() or {}
    local best, bestDist, bestScore, bestInfo = nil, math.huge, -math.huge, nil
    local stage = Farm.Loot.currentStageId()
    local batchMax = math.max(0, tonumber(Farm.Runtime.LootBatchMaxValue) or 0)
    local threshold = math.max(0, tonumber(Farm.Runtime.LootBatchThreshold) or 0)
    if mode == "Smart" and not Farm.Loot.batchReady(maxDistance) then
        return nil, math.huge, nil
    end
    for inst in pairs(PickupPrompts) do
        local allowDisabledSmart = mode == "Smart"
        if inst.Parent and inst.Parent:IsA("BasePart") and (inst.Enabled or allowDisabledSmart) then
            local dist = (root.Position - inst.Parent.Position).Magnitude
            if dist <= (maxDistance or 80) then
                local info = getDropInfo(inst)
                local cooldown = info and Farm.Loot.PickupCooldown and Farm.Loot.PickupCooldown[info.model] or 0
                if info and os.clock() >= (tonumber(cooldown) or 0) and (mode ~= "Smart" or Farm.Loot.stageMatches(info, stage)) then
                    local score = nil
                    if mode == "Nearest" then
                        score = -dist
                    elseif mode == "Value" then
                        score = info.value * 1000 + info.rarity * 10 - dist * 0.01
                    elseif mode == "Rarity" then
                        score = info.rarity * 1000000000 + info.value * 100 - dist
                    else
                        local eligible, reason = Farm.Loot.smartEligible(info, stage, batchMax, threshold, questTargets, unseen)
                        if eligible then
                            local questBoost = Farm.Config.AutoFarmEventQuests and info.id and questTargets[info.id] and 1 or 0
                            local unseenBoost = info.id and unseen[info.id] and 1 or 0
                            local premiumBoost = info.value >= threshold and 1 or 0
                            score = questBoost * 1e18
                                + unseenBoost * 5e17
                                + premiumBoost * 1e16
                                + info.rarity * 1e12
                                + info.value * 1e4
                                - dist
                            info.smartReason = reason
                        end
                    end
                    if score and score > bestScore then
                        best, bestDist, bestScore, bestInfo = inst, dist, score, info
                    end
                end
            end
        else
            PickupPrompts[inst] = nil
        end
    end
    if mode == "Smart" then
        if bestInfo then
            local pct = batchMax > 0 and math.floor((bestInfo.value / batchMax) * 100 + 0.5) or 100
            Farm.Runtime.LootDecision = string.format(
                "Stage %d pick %s • %s Gold • %d%% of batch max • %s",
                stage,
                tostring(bestInfo.name),
                tostring(math.floor(bestInfo.value)),
                pct,
                tostring(bestInfo.smartReason or "smart")
            )
        else
            local target, harvestStart, remaining, finalWindow = Farm.Loot.deepStagePlan(stage)
            Farm.Runtime.LootDecision = string.format(
                "Stage %d skipped cheap loot • harvest stage %d+ • target %d • %.1fs left%s",
                stage, harvestStart, target, remaining == math.huge and 0 or remaining, finalWindow and " • final window" or ""
            )
        end
    end
    return best, bestDist, bestInfo
end
local function triggerPickup(prompt)
    if not prompt or not prompt.Parent or not prompt.Parent:IsA("BasePart") then
        return false
    end
    local info = getDropInfo(prompt)
    if not info or not info.model or not info.model.Parent then
        return false
    end
    local beforeUsed = select(1, getDungeonBagUsage())
    local beforeItemCount = info.id and getItemCountById(info.id) or nil
    if backpackPressureReached() then
        Farm.Runtime.EmergencySellRequested = true
        return false
    end
    local maxActivationDistance = math.max(4, tonumber(prompt.MaxActivationDistance) or 10)
    local target = prompt.Parent.Position
    local pickupReach = math.clamp(maxActivationDistance * 0.28, 1.5, 3.25)
    if not moveTo(target, pickupReach, 8) then
        Farm.Loot.PickupCooldown[info.model] = os.clock() + 0.25
        return false
    end
    if backpackPressureReached() then
        Farm.Runtime.EmergencySellRequested = true
        return false
    end
    local function confirmed()
        if not info.model or not info.model.Parent then return true end
        if not prompt or not prompt.Parent then return true end
        if select(1, getDungeonBagUsage()) > beforeUsed then return true end
        if beforeItemCount ~= nil and info.id then
            local nowCount = getItemCountById(info.id)
            if nowCount ~= nil and nowCount > beforeItemCount then return true end
        end
        return false
    end
    if info.dropId ~= nil and NetMsg.DROP_PICKUP then
        safeFire(NetMsg.DROP_PICKUP, info.dropId)
        local deadline = os.clock() + 0.34
        while Farm.Running and os.clock() < deadline and not confirmed() do
            task.wait(0.018)
        end
    end
    if not confirmed() then
        local wasEnabled = prompt.Enabled
        local oldHoldDuration = prompt.HoldDuration
        pcall(function()
            prompt.Enabled = true
            prompt.HoldDuration = 0
        end)
        for attempt = 1, 3 do
            if confirmed() then break end
            local fired = false
            if type(fireproximityprompt) == "function" then
                fired = pcall(function()
                    fireproximityprompt(prompt, 0)
                end)
            end
            if not fired then
                pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(0.035)
                    prompt:InputHoldEnd()
                end)
            end
            local deadline = os.clock() + (attempt == 1 and 0.30 or 0.22)
            while Farm.Running and os.clock() < deadline and not confirmed() do
                task.wait(0.018)
            end
            if not confirmed() and attempt == 1 then
                local _, _, root = getCharacter()
                if root and prompt.Parent and prompt.Parent:IsA("BasePart") then
                    moveTo(prompt.Parent.Position, 1.5, 2.5)
                end
            end
        end
        if prompt and prompt.Parent then
            pcall(function()
                prompt.HoldDuration = oldHoldDuration
                prompt.Enabled = wasEnabled
            end)
        end
    end
    local picked = confirmed()
    if picked then
        Farm.Runtime.LastLoot = info.name
        Farm.Runtime.LastLootRarity = info.rarity
        Farm.Runtime.LastLootValue = info.value
        Farm.Runtime.LastLootStage = tonumber(info.stage) or Farm.Loot.currentStageId()
        Farm.Runtime.LootDecision = string.format(
            "Picked %s • %s Gold • stage %s",
            tostring(info.name), tostring(math.floor(tonumber(info.value) or 0)), tostring(info.stage or 0)
        )
        Farm.Loot.PickupCooldown[info.model] = nil
    else
        Farm.Loot.PickupCooldown[info.model] = os.clock() + 0.30
        Farm.Runtime.LootDecision = string.format("Pickup retry queued • %s • stage %s", tostring(info.name), tostring(info.stage or 0))
    end
    if backpackPressureReached() then
        Farm.Runtime.EmergencySellRequested = true
        setNativeTarget(nil)
    end
    return picked
end

function Farm.Loot.autoPickupTick()
    if not (Farm.Running and Farm.Config.Master and Farm.Config.AutoDungeonLoot) then
        return false
    end
    if not isInDungeon() or Farm.Runtime.Selling or Farm.Runtime.GearTransaction then
        return false
    end
    if backpackPressureReached() then
        Farm.Runtime.EmergencySellRequested = true
        return false
    end
    -- Do NOT gate loot on InStageSafeArea. The game's own DropVisual enables
    -- PickupPrompt for the active stage before that flag necessarily becomes true.
    -- Only pause pickup while a real enemy/boss presentation is still active.
    if bossIntroPlaying() or #gatherEnemies() > 0 then
        return false
    end
    Farm.Position.release(false)
    setNativeTarget(nil)
    if tostring(Farm.Config.LootPriority or "Smart") == "Smart" and not Farm.Loot.batchReady(100) then
        return false
    end
    local prompt = bestPickupPrompt(100)
    if not prompt then
        return false
    end
    if not acquireMovement("DungeonLoot", 8) then
        return false
    end
    local ok = triggerPickup(prompt)
    releaseMovement("DungeonLoot")
    return ok
end

local function tryEnterDungeon()
    if isInDungeon() and not isStageJumping() then return true end

    Farm.Fast.stopTrainingForDungeonFast()

    -- Equip the owned broom with the highest dungeon reach before asking the
    -- game's native Stage Jump system for the deepest valid teleport destination.
    local _, broomLimit = prepareBestOwnedDungeonBroom()
    local jumpMax = getActualJumpMax(broomLimit)
    local jumpStage = getFurthestTeleportStage(jumpMax)
    if jumpStage > 0 and NetMsg.STAGE_JUMP_REQUEST then
        setPhase("Broom jump to dungeon stage " .. tostring(jumpStage))
        local requested = safeFire(NetMsg.STAGE_JUMP_REQUEST, jumpStage)
        if requested and waitForBroomStageJumpLanding(jumpStage, 8) then
            Farm.Runtime.LastDungeonStage = math.max(Farm.Runtime.LastDungeonStage or 0, jumpStage)
            if Farm.Config.AutoHoldBestWand then
                Farm.Fast.prepareWandForDungeon("broom jump landed")
            end
            return true
        end
    end

    if Farm.Config.AutoHoldBestWand then
        Farm.Fast.prepareWandForDungeon("enter dungeon")
    end

    local area, stage = getNextBattleArea()
    if area and acquireMovement("Dungeon", 24) then
        setPhase("Entering dungeon stage " .. tostring(stage))
        local moved = moveTo(area.Position, math.max(3, math.min(area.Size.X, area.Size.Z) * 0.22), 16)
        if moved then
            local _, _, root = getCharacter()
            local wasInDungeon = isInDungeon()
            if root and isPointInsidePart(area, root.Position) then
                Farm.Runtime.LastDungeonStage = tonumber(stage) or Farm.Runtime.LastDungeonStage
                Farm.Runtime.LastDungeonSpawnAt = os.clock()
                Farm.Dungeon.waitForNativeStageSpawn(area, stage, wasInDungeon)
                Farm.Position.prePositionForStage(area)
            end
        end
        releaseMovement("Dungeon")
        local deadline = os.clock() + 4
        while Farm.Running and os.clock() < deadline do
            if isInDungeon() or #gatherEnemies() > 0 then return true end
            task.wait(0.04)
        end
    end
    return isInDungeon()
end
local function recoverUnexpectedDungeonExit(reason, sessionDeadline)
    if Farm.Runtime.Selling or Farm.Runtime.EmergencySellRequested then return false end
    if isInDungeon() then return true end
    local started = os.clock()
    local sawTransition = false
    local lastTransitionAt = started
    while Farm.Running and os.clock() - started < 2.75 do
        if isInDungeon() then return true end
        local transitioning = isStageJumping() or bossIntroPlaying()
        if transitioning then
            sawTransition = true
            lastTransitionAt = os.clock()
        elseif sawTransition then
            if os.clock() - lastTransitionAt >= 0.30 then break end
        elseif os.clock() - started >= 0.45 then
            break
        end
        task.wait(0.03)
    end
    if sessionDeadline and os.clock() >= sessionDeadline then return false end
    Farm.Runtime.UnexpectedDungeonExits = Farm.Runtime.UnexpectedDungeonExits + 1
    Farm.Runtime.LastDungeonExitReason = tostring(reason or "Unexpected dungeon exit")
    setNativeTarget(nil)
    Farm.Position.release(false)
    Farm.Runtime.LastTargetModel = nil
    releaseMovement("Dungeon")
    local attempts = math.clamp(math.floor(tonumber(Farm.Config.DungeonReentryAttempts) or 3), 1, 6)
    local delay = math.clamp(tonumber(Farm.Config.DungeonReentryDelay) or 0.20, 0.1, 2.0)
    for attempt = 1, attempts do
        if not Farm.Running or Farm.Runtime.Selling or Farm.Runtime.EmergencySellRequested then return false end
        setPhase(string.format("Dungeon ejected - re-enter %d/%d", attempt, attempts))
        if Farm.Config.AutoHoldBestWand and not Farm.Fast.nativeDungeonCombatBlocked() then
            Farm.Fast.prepareWandForDungeon("dungeon re-entry")
        end
        if tryEnterDungeon() then
            Farm.Runtime.DungeonReentries = Farm.Runtime.DungeonReentries + 1
            Farm.Runtime.LastDungeonExitReason = "Recovered"
            Farm.Runtime.NoEnemySince = nil
            Farm.Runtime.LastTargetModel = nil
            return true
        end
        task.wait(delay)
    end
    Farm.Runtime.LastDungeonAt = -math.huge
    setPhase("Dungeon ejected - retrying shortly")
    return false
end
local function dungeonStep()
    if not (Farm.Config.Master and (Farm.Config.AutoDungeonEconomy or Farm.Config.AutoFarmEventQuests)) then return false end
    if not isInDungeon() then return false end
    local currentStage = Farm.Dungeon.currentStageId()
    if currentStage > 0 then Farm.Runtime.LastDungeonStage = currentStage end
    if backpackPressureReached() then
        Farm.Runtime.EmergencySellRequested = true
        local current, maximum = getDungeonBagUsage()
        setPhase(string.format("Dungeon bag %d/%d - sell required", current, maximum))
        setNativeTarget(nil)
        Farm.Position.release(false)
        return false
    end
    if bossIntroPlaying() then
        Farm.Position.release(false)
        waitForBossIntro(12)
        return true
    end
    if Farm.Config.AutoHoldBestWand and not Farm.Fast.heldSwitchBlocked() then
        Farm.Fast.ensureBestWandHeld("dungeon safe window", 0.08)
    end
    local enemy, enemyPos = nearestEnemy()
    if enemy and enemyPos then
        Farm.Loot.markCombat(Farm.Loot.currentStageId())
        local boss = isBossEnemy(enemy)
        if boss then
            if Farm.Runtime.LastBossModel ~= enemy then
                Farm.Runtime.LastBossModel = enemy
                Farm.Runtime.BossFirstSeenAt = os.clock()
            end
            if Farm.Config.WaitForBossIntro and os.clock() - Farm.Runtime.BossFirstSeenAt < 0.25 then
                Farm.Position.holdLast(0.25)
                setPhase("Boss appeared - waiting intro")
                task.wait(0.03)
                return true
            end
            if bossIntroPlaying() then
                Farm.Position.release(false)
                waitForBossIntro(12)
                return true
            end
        else
            Farm.Runtime.LastBossModel = nil
        end
        setNativeTarget(enemy)
        Farm.Runtime.LastDungeonTarget = (boss and "[BOSS] " or "") .. enemy.Name
        setPhase("Dungeon combat - " .. tostring(Farm.Config.DungeonPositionMode))
        Farm.Position.setTarget(enemy)
        return true
    end
    setNativeTarget(nil)
    if Farm.Dungeon.isStageSafe() and not Farm.Fast.nativeDungeonCombatBlocked() then
        Farm.Position.release(false)
    else
        Farm.Position.holdLast(Farm.Config.TargetSwitchGraceSeconds)
    end
    if Farm.Runtime.NoEnemySince == nil then Farm.Runtime.NoEnemySince = os.clock() end
    local noEnemyFor = os.clock() - Farm.Runtime.NoEnemySince
    if Farm.Fast.nativeDungeonCombatBlocked() and noEnemyFor < 1.35 then
        setPhase("Waiting for next dungeon wave")
        if Farm.Config.PersistCombatPosition then
            Farm.Position.holdLast(math.max(0.35, tonumber(Farm.Config.TargetSwitchGraceSeconds) or 0.20))
        end
        return true
    end
    if not Farm.Dungeon.isStageSafe() and Farm.Config.PersistCombatPosition then
        local grace = math.clamp(tonumber(Farm.Config.TargetSwitchGraceSeconds) or 0.20, 0.05, 0.8)
        if noEnemyFor < grace then
            setPhase("Holding safe position for next enemy")
            Farm.Position.holdLast(grace)
            return true
        end
    end
    if Farm.Config.AutoDungeonLoot then
        -- We are already in the no-enemy branch here. Collect current-stage drops
        -- before moving into the next battle area, even if InStageSafeArea is false.
        Farm.Position.release(false)
        setNativeTarget(nil)
        if tostring(Farm.Config.LootPriority or "Smart") == "Smart" and not Farm.Loot.batchReady(90) then
            setPhase("Waiting for full stage loot batch")
            return true
        end
        local prompt = bestPickupPrompt(90)
        if prompt and acquireMovement("Dungeon", 8) then
            setPhase("Collecting dungeon loot")
            triggerPickup(prompt)
            releaseMovement("Dungeon")
            return true
        end
    end
    local area, stage = getNextBattleArea()
    if area then
        Farm.Position.release(false)
    end
    if area and acquireMovement("Dungeon", 18) then
        Farm.Runtime.LastDungeonStage = stage
        setPhase("Advancing to dungeon stage " .. tostring(stage))
        local moved = moveTo(area.Position, math.max(3, math.min(area.Size.X, area.Size.Z) * 0.22), 14)
        if moved then
            local _, _, root = getCharacter()
            if root and isPointInsidePart(area, root.Position) then
                Farm.Runtime.LastDungeonSpawnAt = os.clock()
                local wasInDungeon = isInDungeon()
                Farm.Dungeon.waitForNativeStageSpawn(area, stage, wasInDungeon)
                Farm.Position.prePositionForStage(area)
            end
        end
        releaseMovement("Dungeon")
        return moved
    end
    return false
end
function Farm.Dungeon.waitForSafeExit(maxSeconds)
    local deadline = os.clock() + math.max(0, tonumber(maxSeconds) or 0)
    while Farm.Running and isInDungeon() and os.clock() < deadline do
        if not Farm.Fast.nativeDungeonCombatBlocked() or Farm.Dungeon.isStageSafe() then return true end
        local ok, err = pcall(dungeonStep)
        if not ok then
            setError(err)
            return false
        end
        task.wait(0.045)
    end
    return not Farm.Fast.nativeDungeonCombatBlocked()
end
local function shouldRunDungeonEconomy()
    if Farm.Runtime.GearTransaction then
        return false
    end
    if not Farm.Config.AutoDungeonEconomy then
        return false
    end
    if Farm.Runtime.Selling or Farm.Runtime.BackpackBlocked then
        return false
    end
    if backpackPressureReached() then
        return false
    end
    local questWork = Farm.Config.AutoFarmEventQuests and hasDungeonQuestWork()
    local cooldown = questWork and 3 or Farm.Config.DungeonCooldownSeconds
    if os.clock() - Farm.Runtime.LastDungeonAt < cooldown then
        return false
    end
    if questWork then
        return true
    end
    local cost = Farm.Fast.getNextGearCost()
    if not cost then
        return false
    end
    return getGold() < cost
end
function Farm.Dungeon.driveSession(deadline)
    deadline = tonumber(deadline) or (os.clock() + 28)
    while Farm.Running and (Farm.Config.AutoDungeonEconomy or Farm.Config.AutoFarmEventQuests) and os.clock() < deadline do
        if Farm.Runtime.Selling then return "selling" end
        if not isInDungeon() then
            if not recoverUnexpectedDungeonExit("Lost dungeon state during session", deadline) then return "exit" end
        end
        if backpackPressureReached() then
            Farm.Runtime.EmergencySellRequested = true
            return "bag"
        end
        local ok, err = pcall(dungeonStep)
        if not ok then
            setError(err)
            return "error"
        end
        if Farm.Runtime.EmergencySellRequested then return "bag" end
        task.wait(0.04)
    end
    return "deadline"
end
function Farm.Dungeon.finishSession(reason)
    if isInDungeon() and not backpackPressureReached() and Farm.Fast.nativeDungeonCombatBlocked() then
        Farm.Dungeon.waitForSafeExit(4.0)
    end
    if Farm.Config.AutoDungeonLoot and isInDungeon() and not backpackPressureReached() and #gatherEnemies() == 0 then
        Farm.Position.release(false)
        setNativeTarget(nil)
        local lootDeadline = os.clock() + 4.0
        if tostring(Farm.Config.LootPriority or "Smart") == "Smart" then
            while Farm.Running and os.clock() < lootDeadline and not Farm.Loot.batchReady(100) do
                task.wait(0.03)
            end
        end
        while Farm.Running and os.clock() < lootDeadline do
            if backpackPressureReached() then
                Farm.Runtime.EmergencySellRequested = true
                break
            end
            local prompt = bestPickupPrompt(100)
            if not prompt then break end
            if acquireMovement("Dungeon", 6) then
                triggerPickup(prompt)
                releaseMovement("Dungeon")
            end
            task.wait(0.03)
        end
    end
    if Farm.Runtime.EmergencySellRequested or backpackPressureReached() then
        pcall(returnToTownAndSell, "Backpack full")
        return
    end
    if isInDungeon() then
        setNativeTarget(nil)
        safeFire(NetMsg.DUNGEON_RETURN_TOWN)
        local leaveDeadline = os.clock() + 1.6
        while Farm.Running and isInDungeon() and os.clock() < leaveDeadline do task.wait(0.035) end
        if isInDungeon() then
            safeFire(NetMsg.DUNGEON_RETURN_TOWN)
            leaveDeadline = os.clock() + 1.8
            while Farm.Running and isInDungeon() and os.clock() < leaveDeadline do task.wait(0.04) end
        end
    end
    releaseMovement("Dungeon")
    if not isInDungeon() then
        if Farm.Config.AutoSellMaterials then pcall(sellMaterials) end
        pcall(Farm.Fast.gearTick, true)
        if Farm.Config.AutoHoldBestWand and not Farm.Fast.heldSwitchBlocked() then
            Farm.Fast.ensureBestWandHeld("after dungeon gear", 0.12)
        end
    else
        Farm.Runtime.LastDungeonExitReason = "Return-to-town retry failed"
    end
end
local function runDungeonBurst()
    if Farm.Runtime.GearTransaction or Farm.Runtime.DungeonRunning then return end
    Farm.Runtime.DungeonRunning = true
    Farm.Runtime.DungeonStartedAt = os.clock()
    Farm.Runtime.LastDungeonAt = os.clock()
    Farm.Runtime.NoEnemySince = nil
    Farm.Runtime.LastTargetModel = nil
    Farm.Loot.resetBatch(0)
    pcall(function()
        if PlayerSkillControlHub and type(PlayerSkillControlHub.setDebugAutoAttackEnabled) == "function" then
            PlayerSkillControlHub.setDebugAutoAttackEnabled(true)
        end
    end)
    Farm.Fast.stopTrainingForDungeonFast()
    if Farm.Config.AutoHoldBestWand then Farm.Fast.prepareWandForDungeon("dungeon burst") end
    setPhase("Starting dungeon economy burst")
    if not tryEnterDungeon() then
        Farm.Runtime.DungeonRunning = false
        Farm.Runtime.LastDungeonTarget = "Could not enter"
        local cooldown = math.max(1, tonumber(Farm.Config.DungeonCooldownSeconds) or 28)
        Farm.Runtime.LastDungeonAt = os.clock() - math.max(0, cooldown - 1.5)
        return
    end
    local deadline = os.clock() + math.max(8, tonumber(Farm.Config.DungeonBurstSeconds) or 28)
    Farm.Runtime.DungeonSessionDeadline = deadline
    local reason = Farm.Dungeon.driveSession(deadline)
    Farm.Dungeon.finishSession(reason)
    releaseMovement("Dungeon")
    setNativeTarget(nil)
    Farm.Position.release(true)
    Farm.Runtime.LastTargetModel = nil
    Farm.Runtime.DungeonRunning = false
    Farm.Runtime.LastDungeonTarget = "None"
    Farm.Runtime.LastTrainDecisionAt = -math.huge
    setPhase("Returning to training")
end
track(RunService.Heartbeat:Connect(function(dt)
    Farm.Position.step(dt)
end))
-- ============================================================================
-- AUTOMATION LOOPS
-- ============================================================================
task.spawn(function()
    while Farm.Running do
        if Farm.Config.Master and Farm.Config.AutoTrain and not Farm.Runtime.GearTransaction and not Farm.Runtime.DungeonRunning and not isInDungeon() then
            local ok, err = pcall(refreshTrainingDecision, false)
            if not ok then
                setError(err)
            end
        end
        task.wait(0.12)
    end
end)
task.spawn(function()
    while Farm.Running do
        if Farm.Config.Master and Farm.Config.AutoTrain then
            pcall(manualTrainTick)
            task.wait(0.022)
        else
            task.wait(0.1)
        end
    end
end)
task.spawn(function()
    while Farm.Running do
        local now = os.clock()
        if Farm.Config.Master and Farm.Config.AutoRebirth and now - Farm.Runtime.LastRebirthAt >= 0.35 then
            Farm.Runtime.LastRebirthAt = now
            local ok, err = pcall(tryRebirth)
            if not ok then
                setError(err)
            end
        end
        task.wait(0.12)
    end
end)
do
    local function bindCoinWake()
        local coinId = EnumMgr and EnumMgr.ItemID and EnumMgr.ItemID.Coin
        local bag = LocalPlayer:FindFirstChild("Bag")
        local coinValue = bag and coinId and bag:FindFirstChild(tostring(coinId))
        if not (coinValue and coinValue:IsA("ValueBase")) then
            return false
        end
        if coinValue:GetAttribute("PuckGearWakeBound") == true then
            return true
        end
        coinValue:SetAttribute("PuckGearWakeBound", true)
        track(coinValue:GetPropertyChangedSignal("Value"):Connect(function()
            Farm.Runtime.LastGearAt = -math.huge
        end))
        return true
    end
    if not bindCoinWake() then
        task.spawn(function()
            for _ = 1, 100 do
                if not Farm.Running then return end
                if bindCoinWake() then return end
                task.wait(0.1)
            end
        end)
    end
end
task.spawn(function()
    while Farm.Running do
        local now = os.clock()
        local affordablePrice = nil
        local preOk, _, _, p = pcall(Farm.Fast.getNextAffordableGearNow)
        if preOk then affordablePrice = p end
        local interval = affordablePrice and 0.08 or 0.35
        if Farm.Config.Master and not Farm.Runtime.GearTransaction and now - Farm.Runtime.LastGearAt >= interval then
            Farm.Runtime.LastGearAt = now
            local ok, err = pcall(Farm.Fast.gearTick)
            if not ok then
                setError("Gear worker: " .. tostring(err))
                Farm.Runtime.GearSessionActive = false
                Farm.Runtime.GearNetworkBusy = false
                Farm.Runtime.GearTransaction = false
                pcall(function() closeNativeShop("Weapon") end)
                pcall(function() closeNativeShop("Armor") end)
                pcall(function() closeNativeShop("Broom") end)
            end
        end
        task.wait(0.025)
    end
end)
task.spawn(function()
    while Farm.Running do
        local now = os.clock()
        if Farm.Config.Master and now - Farm.Runtime.LastPotionAt >= 5 then
            Farm.Runtime.LastPotionAt = now
            pcall(potionTick)
        end
        task.wait(0.5)
    end
end)
task.spawn(function()
    task.wait(1.5)
    pcall(redeemCodesOnce)
    while Farm.Running do
        local now = os.clock()
        if Farm.Config.Master and now - Farm.Runtime.LastRewardAt >= 8 then
            Farm.Runtime.LastRewardAt = now
            pcall(claimDaily)
            task.wait(0.20)
            pcall(claimOnline)
            task.wait(0.20)
            pcall(claimEventTasks)
            task.wait(0.20)
            pcall(claimIndexRewards)
        end
        task.wait(0.5)
    end
end)
task.spawn(function()
    while Farm.Running do
        local now = os.clock()
        if Farm.Config.Master and now - Farm.Runtime.LastQuestAt >= 3 then
            Farm.Runtime.LastQuestAt = now
            pcall(claimEventTasks)
        end
        if Farm.Config.Master and now - Farm.Runtime.LastIndexAt >= 3 then
            Farm.Runtime.LastIndexAt = now
            pcall(claimIndexRewards)
        end
        task.wait(0.45)
    end
end)
task.spawn(function()
    while Farm.Running do
        if Farm.Config.Master and Farm.Config.AutoHoldBestWand and not Farm.Runtime.GearTransaction and not Farm.Fast.heldSwitchBlocked() then
            if os.clock() - (Farm.Runtime.LastHeldWandAt or -math.huge) >= 0.18 then
                pcall(Farm.Fast.ensureBestWandHeld, "wand guard", 0.08)
            end
        end
        task.wait(0.12)
    end
end)
task.spawn(function()
    while Farm.Running do
        if Farm.Config.Master and not Farm.Runtime.GearTransaction and not Farm.Runtime.DungeonRunning and shouldRunDungeonEconomy() then
            local ok, err = pcall(runDungeonBurst)
            if not ok then
                Farm.Runtime.DungeonRunning = false
                releaseMovement("Dungeon")
                setError(err)
            end
        end
        task.wait(0.25)
    end
end)
task.spawn(function()
    while Farm.Running do
        if Farm.Config.Master
            and Farm.Config.AutoDungeonLoot
            and isInDungeon()
            and not Farm.Runtime.DungeonRunning
            and not Farm.Runtime.Selling
            and not Farm.Runtime.GearTransaction then
            pcall(Farm.Loot.autoPickupTick)
        end
        task.wait(0.08)
    end
end)
task.spawn(function()
    while Farm.Running do
        if Farm.Config.Master and not Farm.Runtime.GearTransaction and (Farm.Config.AutoDungeonEconomy or Farm.Config.AutoFarmEventQuests) and isInDungeon() and not Farm.Runtime.DungeonRunning then
            Farm.Runtime.DungeonRunning = true
            Farm.Runtime.DungeonStartedAt = os.clock()
            Farm.Runtime.LastDungeonAt = os.clock()
            Farm.Runtime.NoEnemySince = nil
            Farm.Runtime.LastTargetModel = nil
            setPhase("Dungeon detected")
            pcall(function()
                if PlayerSkillControlHub and type(PlayerSkillControlHub.setDebugAutoAttackEnabled) == "function" then
                    PlayerSkillControlHub.setDebugAutoAttackEnabled(true)
                end
            end)
            if Farm.Config.AutoHoldBestWand and not Farm.Fast.heldSwitchBlocked() then
                Farm.Fast.ensureBestWandHeld("detected dungeon", 0.10)
            end
            local deadline = os.clock() + math.max(8, tonumber(Farm.Config.DungeonBurstSeconds) or 28)
            Farm.Runtime.DungeonSessionDeadline = deadline
            local reason = Farm.Dungeon.driveSession(deadline)
            Farm.Dungeon.finishSession(reason)
            releaseMovement("Dungeon")
            setNativeTarget(nil)
            Farm.Runtime.LastTargetModel = nil
            Farm.Runtime.DungeonRunning = false
            Farm.Runtime.LastDungeonTarget = "None"
            Farm.Runtime.LastTrainDecisionAt = -math.huge
        end
        task.wait(0.16)
    end
end)
do
    local limitUsed = LocalPlayer:FindFirstChild("LimitBagUsed")
    if limitUsed and limitUsed:IsA("NumberValue") then
        track(limitUsed:GetPropertyChangedSignal("Value"):Connect(function()
            local pressure = backpackPressureReached()
            if pressure then
                Farm.Runtime.EmergencySellRequested = true
                setNativeTarget(nil)
            end
        end))
    end
end
task.spawn(function()
    while Farm.Running do
        local pressure, current, maximum = backpackPressureReached()
        if not pressure and Farm.Runtime.BackpackBlocked then
            Farm.Runtime.BackpackBlocked = false
            Farm.Runtime.BackpackBlockedReason = "None"
        end
        if Farm.Config.Master and pressure then
            Farm.Runtime.EmergencySellRequested = true
            setNativeTarget(nil)
            if isInDungeon() and Farm.Config.AutoSellMaterials and not Farm.Runtime.Selling then
                task.spawn(function()
                    pcall(returnToTownAndSell, string.format("Backpack pressure %d/%d", current, maximum))
                end)
            elseif not isInDungeon() and Farm.Config.AutoSellMaterials and not Farm.Runtime.Selling then
                task.spawn(function()
                    pcall(returnToTownAndSell, string.format("Backpack pressure %d/%d", current, maximum))
                end)
            end
        elseif not pressure then
            Farm.Runtime.EmergencySellRequested = false
        end
        task.wait(0.04)
    end
end)
track(LocalPlayer.Idled:Connect(function()
    if not Farm.Running then
        return
    end
    pcall(function()
        VirtualUser:Button2Down(Vector2.zero, Workspace.CurrentCamera.CFrame)
        task.wait(0.2)
        VirtualUser:Button2Up(Vector2.zero, Workspace.CurrentCamera.CFrame)
    end)
end))
track(LocalPlayer.CharacterAdded:Connect(function()
    Farm.Runtime.LastTrainDecisionAt = -math.huge
    Farm.Runtime.MovementOwner = nil
    Farm.Runtime.MovementUntil = 0
    task.wait(1)
end))
-- ============================================================================
-- UI
-- ============================================================================
if PuckUI then
    local ok, result = pcall(PuckUI.CreateWindow, PuckUI, {
        Name = "RAINZXDEV | Magic Loot", GuiName = "RAINZXDEV_MagicLoot", Width = 530, Height = 590,
    })
    if ok then Window = result end
end
Farm.UI = Farm.UI or {}
function Farm.UI.toggle(tab, name, key, flag, after)
    return tab:CreateToggle({
        Name = name, CurrentValue = Farm.Config[key], Flag = flag,
        Callback = function(v)
            v = v == true
            Farm.Config[key] = v
            if after then after(v) end
        end,
    })
end
function Farm.UI.slider(tab, name, key, flag, range, increment, normalize)
    return tab:CreateSlider({
        Name = name, Range = range, Increment = increment,
        CurrentValue = Farm.Config[key], Flag = flag,
        Callback = function(v)
            Farm.Config[key] = normalize and normalize(v) or tonumber(v) or Farm.Config[key]
        end,
    })
end
function Farm.UI.dropdown(tab, name, key, flag, options, fallback, after)
    local allowed = {}
    for _, option in ipairs(options) do allowed[option] = true end
    return tab:CreateDropdown({
        Name = name, Options = options, CurrentOption = { Farm.Config[key] }, Flag = flag,
        Callback = function(value)
            value = type(value) == "table" and value[1] or value
            Farm.Config[key] = allowed[value] and value or fallback
            if after then after(Farm.Config[key]) end
        end,
    })
end
function Farm.UI.mappedDropdown(tab, name, key, flag, rows, fallbackValue, after)
    local labels, valueByLabel, labelByValue = {}, {}, {}
    for _, row in ipairs(rows) do
        labels[#labels + 1] = row[1]
        valueByLabel[row[1]] = row[2]
        labelByValue[row[2]] = row[1]
    end
    local currentLabel = labelByValue[Farm.Config[key]] or labelByValue[fallbackValue] or labels[1]
    return tab:CreateDropdown({
        Name = name,
        Options = labels,
        CurrentOption = { currentLabel },
        Flag = flag,
        Callback = function(value)
            value = type(value) == "table" and value[1] or value
            Farm.Config[key] = valueByLabel[value] or fallbackValue
            if after then after(Farm.Config[key]) end
        end,
    })
end
function Farm.UI.button(tab, name, callback)
    return tab:CreateButton({ Name = name, Callback = callback })
end

-- Responsive layout, phone/desktop detection, scaling and centering are
-- owned by shared PuckUI v3.5+. The release UI intentionally keeps the main
-- tabs simple; low-level tuning lives in Advanced instead of competing with
-- the controls a normal player actually needs.
if Window then
    local FarmTab = Window:CreateTab("Farm")
    local GearTab = Window:CreateTab("Gear")
    local DungeonTab = Window:CreateTab("Dungeon")
    local RewardsTab = Window:CreateTab("Rewards")
    local SettingsTab = Window:CreateTab("Settings")
    local AdvancedTab = Window:CreateTab("Advanced")

    local SmartLootAdvancedSection = nil
    local AutoSellAdvancedSection = nil
    local OrbitAdvancedSection = nil
    local SmoothMovementAdvancedSection = nil
    local function refreshAdvancedVisibility()
        if SmartLootAdvancedSection and SmartLootAdvancedSection.Frame then
            SmartLootAdvancedSection.Frame.Visible = tostring(Farm.Config.LootPriority or "Smart") == "Smart"
        end
        if AutoSellAdvancedSection and AutoSellAdvancedSection.Frame then
            AutoSellAdvancedSection.Frame.Visible = Farm.Config.AutoSellMaterials == true
        end
        if OrbitAdvancedSection and OrbitAdvancedSection.Frame then
            OrbitAdvancedSection.Frame.Visible = tostring(Farm.Config.DungeonPositionMode or "Overhead") == "Orbit"
        end
        if SmoothMovementAdvancedSection and SmoothMovementAdvancedSection.Frame then
            SmoothMovementAdvancedSection.Frame.Visible = tostring(Farm.Config.MovementMode or "Tween") == "Tween"
        end
    end

    if Window.Center then
        task.defer(function() pcall(function() Window:Center() end) end)
    end

    -- FARM: only the controls needed for normal progression.
    FarmTab:CreateSection("Autofarm")
    Farm.UI.toggle(FarmTab, "Master Autofarm", "Master", "MagicLoot_v46_Master", function()
        Farm.Runtime.LastTrainDecisionAt = -math.huge
    end)
    Farm.UI.toggle(FarmTab, "Auto Power", "AutoTrain", "MagicLoot_v46_AutoPower", function()
        Farm.Runtime.LastTrainDecisionAt = -math.huge
    end)
    Farm.UI.toggle(FarmTab, "Auto Rebirth", "AutoRebirth", "MagicLoot_v46_Rebirth")

    FarmTab:CreateSection("Consumables")
    Farm.UI.toggle(FarmTab, "Auto Training Potions", "AutoTrainingPotion", "MagicLoot_v46_TrainingPotions")
    Farm.UI.toggle(FarmTab, "Auto Luck Potions", "AutoLuckPotion", "MagicLoot_v46_LuckPotions")

    -- GEAR: automatic choices only. Manual test/force-buy buttons were removed.
    GearTab:CreateSection("Automatic Gear")
    Farm.UI.toggle(GearTab, "Auto Best Wand", "AutoWeapon", "MagicLoot_v46_Wand")
    Farm.UI.toggle(GearTab, "Auto Best Armor", "AutoArmor", "MagicLoot_v46_Armor")
    Farm.UI.toggle(GearTab, "Auto Best Broom", "AutoBroom", "MagicLoot_v46_Broom")

    -- DUNGEON: the whole normal dungeon experience fits into three small groups.
    DungeonTab:CreateSection("Dungeon Autofarm")
    Farm.UI.toggle(DungeonTab, "Auto Dungeon", "AutoDungeonEconomy", "MagicLoot_v46_Dungeon")
    Farm.UI.toggle(DungeonTab, "Auto Loot", "AutoDungeonLoot", "MagicLoot_v46_Loot")
    Farm.UI.toggle(DungeonTab, "Auto Sell", "AutoSellMaterials", "MagicLoot_v46_Sell", function()
        refreshAdvancedVisibility()
    end)

    DungeonTab:CreateSection("Loot Strategy")
    Farm.UI.mappedDropdown(DungeonTab, "Loot Mode", "LootPriority", "MagicLoot_v46_LootMode", {
        { "Smart (Recommended)", "Smart" },
        { "Highest Rarity", "Rarity" },
        { "Highest Value", "Value" },
        { "Nearest Drop", "Nearest" },
    }, "Smart", function()
        refreshAdvancedVisibility()
    end)

    DungeonTab:CreateSection("Combat Position")
    Farm.UI.mappedDropdown(DungeonTab, "Position", "DungeonPositionMode", "MagicLoot_v46_Position", {
        { "Overhead (Recommended)", "Overhead" },
        { "Behind", "Behind" },
        { "Front", "Front" },
        { "Side", "Side" },
        { "Left", "Left" },
        { "Below", "Below" },
        { "Orbit", "Orbit" },
        { "Normal", "Normal" },
    }, "Overhead", function(v)
        if v == "Normal" then Farm.Position.release(false) end
        refreshAdvancedVisibility()
    end)
    Farm.UI.slider(DungeonTab, "Distance", "DungeonEnemyRange", "MagicLoot_v46_EnemyDistance",
        { 6, 55 }, 1, function(v) return math.clamp(tonumber(v) or 19, 6, 55) end)

    -- REWARDS: use outcome-focused language rather than game-internal names.
    RewardsTab:CreateSection("Automatic Rewards")
    Farm.UI.toggle(RewardsTab, "Auto Codes", "AutoCodes", "MagicLoot_v46_Codes", function(v)
        if v then Farm.Runtime.CodesTried = false; task.spawn(redeemCodesOnce) end
    end)
    Farm.UI.toggle(RewardsTab, "Auto Daily Rewards", "AutoDaily", "MagicLoot_v46_Daily")
    Farm.UI.toggle(RewardsTab, "Auto Online Rewards", "AutoOnline", "MagicLoot_v46_Online")
    Farm.UI.toggle(RewardsTab, "Auto Event Quest Rewards", "AutoEventQuestClaims", "MagicLoot_v46_EventClaims")
    Farm.UI.toggle(RewardsTab, "Farm Dungeon Event Quests", "AutoFarmEventQuests", "MagicLoot_v46_EventFarm", function(v)
        if v then Farm.Runtime.LastDungeonAt = -math.huge end
    end)
    Farm.UI.toggle(RewardsTab, "Auto Collection Rewards", "AutoIndexRewards", "MagicLoot_v46_IndexRewards")

    -- SETTINGS: deliberately tiny. Most players should never need Advanced.
    SettingsTab:CreateSection("Movement")
    Farm.UI.mappedDropdown(SettingsTab, "Movement Mode", "MovementMode", "MagicLoot_v46_MoveMode", {
        { "Smooth", "Tween" },
        { "Walk", "Walk" },
    }, "Tween", function()
        refreshAdvancedVisibility()
    end)
    SettingsTab:CreateSection("Script")
    Farm.UI.button(SettingsTab, "Unload Autofarm", function() Farm:Unload() end)

    -- ADVANCED: dependencies are grouped and named explicitly so a user knows
    -- when they matter instead of seeing every implementation control at once.
    SmartLootAdvancedSection = AdvancedTab:CreateSection("Smart Loot")
    Farm.UI.toggle(AdvancedTab, "Prioritize New Collection Loot", "PrioritizeUnseenIndexLoot", "MagicLoot_v46_IndexLoot")
    Farm.UI.slider(AdvancedTab, "Smart Loot Quality", "SmartLootQualityPercent", "MagicLoot_v46_SmartLootQuality",
        { 30, 95 }, 5, function(v) return math.clamp(tonumber(v) or 65, 30, 95) end)

    AutoSellAdvancedSection = AdvancedTab:CreateSection("Auto Sell")
    Farm.UI.slider(AdvancedTab, "Sell At Backpack %", "AutoSellThresholdPercent", "MagicLoot_v46_SellThreshold",
        { 60, 100 }, 1, function(v) return math.clamp(tonumber(v) or 100, 60, 100) end)
    Farm.UI.slider(AdvancedTab, "Reserved Backpack Space", "BackpackReserveSlots", "MagicLoot_v46_BackpackReserve",
        { 0, 5 }, 1, function(v) return math.clamp(math.floor(tonumber(v) or 0), 0, 5) end)
    Farm.UI.toggle(AdvancedTab, "Protect Recipe Materials While Selling", "TemporarilyUnmarkAlchemyForSell", "MagicLoot_v46_RecipeSelling")
    Farm.UI.toggle(AdvancedTab, "Resume Dungeon After Selling", "ResumeDungeonAfterSell", "MagicLoot_v46_ResumeAfterSell")

    AdvancedTab:CreateSection("Combat")
    Farm.UI.toggle(AdvancedTab, "Wait For Boss Intro", "WaitForBossIntro", "MagicLoot_v46_BossIntro")
    Farm.UI.toggle(AdvancedTab, "Hold Position Between Enemies", "PersistCombatPosition", "MagicLoot_v46_PositionHold")
    Farm.UI.slider(AdvancedTab, "Position Hold Time", "TargetSwitchGraceSeconds", "MagicLoot_v46_HoldTime",
        { 0.05, 0.8 }, 0.05, function(v) return math.clamp(tonumber(v) or 0.20, 0.05, 0.8) end)
    Farm.UI.toggle(AdvancedTab, "Stay Locked To Enemy", "CombatDirectLock", "MagicLoot_v46_DirectLock")
    Farm.UI.toggle(AdvancedTab, "Combat Noclip", "CombatNoclip", "MagicLoot_v46_CombatNoclip", function(v)
        if not v then Farm.Position.setNoclip(false) end
    end)
    Farm.UI.toggle(AdvancedTab, "Always Face Enemy", "CombatFaceTarget", "MagicLoot_v46_FaceEnemy")

    OrbitAdvancedSection = AdvancedTab:CreateSection("Orbit")
    Farm.UI.slider(AdvancedTab, "Orbit Speed", "DungeonOrbitSpeed", "MagicLoot_v46_OrbitSpeed",
        { 0.1, 2.0 }, 0.1, function(v) return math.max(0.1, tonumber(v) or 0.65) end)

    AdvancedTab:CreateSection("Dungeon Recovery")
    Farm.UI.slider(AdvancedTab, "Re-entry Attempts", "DungeonReentryAttempts", "MagicLoot_v46_ReentryAttempts",
        { 1, 6 }, 1, function(v) return math.clamp(math.floor(tonumber(v) or 3), 1, 6) end)
    Farm.UI.slider(AdvancedTab, "Time In Dungeon", "DungeonBurstSeconds", "MagicLoot_v46_DungeonTime",
        { 10, 90 }, 1, function(v) return tonumber(v) or 28 end)
    Farm.UI.slider(AdvancedTab, "Time Between Dungeon Runs", "DungeonCooldownSeconds", "MagicLoot_v46_DungeonCooldown",
        { 30, 300 }, 5, function(v) return tonumber(v) or 28 end)

    AdvancedTab:CreateSection("Gear")
    Farm.UI.toggle(AdvancedTab, "Always Hold Best Wand", "AutoHoldBestWand", "MagicLoot_v46_HoldBestWand", function(v)
        if v then task.spawn(function() pcall(Farm.Fast.ensureBestWandHeld, "toggle", 0.18) end) end
    end)

    SmoothMovementAdvancedSection = AdvancedTab:CreateSection("Smooth Movement")
    Farm.UI.slider(AdvancedTab, "Smooth Movement Speed", "TweenSpeed", "MagicLoot_v46_TweenSpeed",
        { 20, 120 }, 1, function(v) return tonumber(v) or 85 end)

    AdvancedTab:CreateSection("Training")
    Farm.UI.toggle(AdvancedTab, "Keep Current Paid Training Zone", "IncludeCurrentPaidZone", "MagicLoot_v46_PaidZone", function()
        Farm.Runtime.LastTrainDecisionAt = -math.huge
    end)

    refreshAdvancedVisibility()
end

-- ============================================================================
-- UNLOAD
-- ============================================================================
function Farm:Unload()
    if not self.Running then
        return
    end
    pcall(function()
        if Farm.Position then Farm.Position.release(true) end
    end)
    self.Running = false
    self.Config.Master = false
    self.Config.AutoTrain = false
    self.Config.AutoDungeonEconomy = false
    self.Config.AutoFarmEventQuests = false
    self.Runtime.DungeonRunning = false
    self.Runtime.GearNetworkBusy = false
    self.Runtime.MovementOwner = nil
    self.Runtime.MovementUntil = 0
    pcall(function()
        safeFire(NetMsg.TRAIN_ZONE_UPDATE, { trainId = nil })
    end)
    pcall(function() closeNativeShop("Weapon") end)
    pcall(function() closeNativeShop("Armor") end)
    pcall(function() closeNativeShop("Broom") end)
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.Connections)
    if GENV[SCRIPT_KEY] == self then
        GENV[SCRIPT_KEY] = nil
    end
    if Window then
        pcall(function() Window:Destroy() end)
    end
end
if Window then
    pcall(function()
        Window:SetCloseCallback(function()
            Farm:Unload()
        end)
    end)
end
if PuckUI and type(PuckUI.Notify) == "function" then
    pcall(function()
        PuckUI:Notify({
            Title = "RAINZXDEV",
            Content = "Magic Loot v4.7 loaded.",
            Duration = 4,
        })
    end)
end
task.spawn(function()
    task.wait(0.04)
    pcall(function() closeNativeShop("Weapon") end)
    pcall(function() closeNativeShop("Armor") end)
    pcall(function() closeNativeShop("Broom") end)
    task.wait(0.015)
    pcall(Farm.Fast.gearTick)
    task.wait(0.03)
    pcall(Farm.Fast.ensureBestWandHeld, "startup", 0.16)
    task.wait(0.05)
    pcall(refreshTrainingDecision, true)
    task.wait(0.06)
    pcall(potionTick)
end)