--[[
    RAINZXDEV Hub · [FPS] One Tap
    Game-specific Auto Aim + optional Auto Shoot + ESP

    Inspected integration notes:
      • Combat characters are tagged "Character" with CollectionService.
      • One Tap's own AimAssistClient targets Torso/Head and uses
        CurrentCamera:GetPartsObscuringTarget for visibility.
      • WeaponClient shoots from Character.Head using CurrentCamera.CFrame.LookVector.
      • WeaponManager default projectile speed is 3850 studs/s and max distance 1500.
      • The experience is FFA, so every alive tagged character except the local
        character is treated as an enemy.

    UI: shared RAINZXDEV PuckUI
]]

local compiler = loadstring or load
if type(compiler) ~= "function" then
    return warn("[RAINZXDEV One Tap] loadstring/load unavailable")
end

local okUI, uiSource = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/suroyah152-web/RAINZXDEV-assets/main/ui/PuckUI.lua")
end)

if not okUI or type(uiSource) ~= "string" or #uiSource < 100 then
    return warn("[RAINZXDEV One Tap] failed to download shared PuckUI")
end

local uiChunk, uiError = compiler(uiSource)
if not uiChunk then
    return warn("[RAINZXDEV One Tap] PuckUI compile failed: " .. tostring(uiError))
end

local okPuck, PuckUI = pcall(uiChunk)
if not okPuck or type(PuckUI) ~= "table" or type(PuckUI.CreateWindow) ~= "function" then
    return warn("[RAINZXDEV One Tap] invalid PuckUI")
end

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if type(ENV.__rainzxdev_ONE_TAP_AIM_ESP_CLEANUP) == "function" then
    pcall(ENV.__rainzxdev_ONE_TAP_AIM_ESP_CLEANUP)
end

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--// Universe support
local ONE_TAP_UNIVERSE_ID = 9294074907
local ONE_TAP_ROOT_PLACE_ID = 90568084448279

if tonumber(game.GameId) ~= ONE_TAP_UNIVERSE_ID then
    warn(("[RAINZXDEV One Tap] Wrong universe. Expected %s, got GameId %s / PlaceId %s")
        :format(tostring(ONE_TAP_UNIVERSE_ID), tostring(game.GameId), tostring(game.PlaceId)))
    return
end

--// Helpers
local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in pairs(value) do
        result[deepCopy(key)] = deepCopy(item)
    end
    return result
end

local function currentCamera()
    return workspace.CurrentCamera
end

local function screenCenter()
    local camera = currentCamera()
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    return Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
end

local function normalizeAutoShootButton(value)
    value = tostring(value or "RMB"):upper()
    return value == "LMB" and "LMB" or "RMB"
end

--// Configuration
local DefaultConfig = {
    AimMode = "Custom",
    Aim = {
        Enabled = true,
        HoldRMB = true,
        VisibleCheck = true,
        AimPoint = "Head", -- Head / Torso / Closest Part

        AutoShoot = false,
        AutoShootButton = "RMB",
        AutoShootRadius = 8,
        AutoShootDelay = 0.00,

        FOV = 180,
        SmoothSpeed = 40,
        MaxDistance = 1500,
        StickyTarget = true,
        StickyMultiplier = 1.35,

        Prediction = true,
        BulletSpeed = 3850,
        PredictionExtra = 0.00,
        PredictionSmoothing = 0.72,
        MaxPredictionOffset = 18,

        AdaptiveSmoothing = true,
        MicroSnapRadius = 1.5,
        TargetPriority = "Hybrid", -- Crosshair / Distance / Low Health / Hybrid
        SwitchDelay = 0.05,
        SwitchThreshold = 0.10,
        LockGrace = 0.16,

        ShowFOV = true,
    },
    ESP = {
        Enabled = true,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        Tracers = false,
        Chams = true,
        MaxDistance = 1500,
    },
}

local Config = deepCopy(DefaultConfig)

-- ============================================================================
-- Persistent Configs
-- ============================================================================

ENV.__rainzxdev_CONFIG_SHARED_STATE = ENV.__rainzxdev_CONFIG_SHARED_STATE or {
    Root = "RAINZXDEV/Configs",
    AutoSaveDefault = true,
    AutoLoadDefault = true,
}

local SharedConfigState = ENV.__rainzxdev_CONFIG_SHARED_STATE
SharedConfigState.Root = tostring(SharedConfigState.Root or "RAINZXDEV/Configs")
if SharedConfigState.AutoSaveDefault == nil then
    SharedConfigState.AutoSaveDefault = true
end
if SharedConfigState.AutoLoadDefault == nil then
    SharedConfigState.AutoLoadDefault = true
end

local FS = {
    Write = type(writefile) == "function" and writefile or nil,
    Read = type(readfile) == "function" and readfile or nil,
    IsFile = type(isfile) == "function" and isfile or nil,
    MakeFolder = type(makefolder) == "function" and makefolder or nil,
    ListFiles = type(listfiles) == "function" and listfiles or nil,
    DeleteFile = type(delfile) == "function" and delfile or nil,
}

local ConfigStore = {
    Id = "OneTap",
    Selected = "default",
    PendingProfile = nil,
    AutoSave = SharedConfigState.AutoSaveDefault == true,
    AutoLoad = SharedConfigState.AutoLoadDefault == true,
    Available = false,
    Applying = false,
    LastFingerprint = nil,
    StatusLabel = nil,
    ProfileDropdown = nil,
    ProfileInput = nil,
}

ConfigStore.Available = FS.Write ~= nil and FS.Read ~= nil and FS.IsFile ~= nil and FS.MakeFolder ~= nil
ConfigStore.Folder = SharedConfigState.Root .. "/" .. ConfigStore.Id
ConfigStore.MetaPath = ConfigStore.Folder .. "/_meta.json"

local function sanitizeConfigName(value, fallback)
    local text = tostring(value or "")
    text = text:gsub("[^%w%-%._ ]", "_")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("%s+", "_")
    text = text:gsub("_+", "_")

    if text == "" then
        text = tostring(fallback or "default")
    end

    return text:sub(1, 80)
end

local function ensureConfigFolders()
    if not FS.MakeFolder then
        return false
    end

    local current = ""
    for part in ConfigStore.Folder:gmatch("[^/\\]+") do
        current = current == "" and part or (current .. "/" .. part)
        pcall(FS.MakeFolder, current)
    end

    return true
end

local function configPath(name)
    return ConfigStore.Folder .. "/" .. sanitizeConfigName(name, "default") .. ".json"
end

local function encodeJSON(value)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(value)
    end)
    return ok and result or nil
end

local function decodeJSON(text)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    return ok and result or nil
end

local function setConfigStatus(text)
    if ConfigStore.StatusLabel and ConfigStore.StatusLabel.Set then
        pcall(function()
            ConfigStore.StatusLabel:Set(tostring(text or ""))
        end)
    end
end

local function configSnapshot()
    return {
        Version = 1,
        AimMode = Config.AimMode,
        Aim = deepCopy(Config.Aim),
        ESP = deepCopy(Config.ESP),
    }
end

local function configFingerprint()
    return encodeJSON(configSnapshot()) or ""
end

local function applyConfigTable(data)
    if type(data) ~= "table" then
        return false
    end

    ConfigStore.Applying = true

    if type(data.AimMode) == "string" and data.AimMode ~= "" then
        Config.AimMode = data.AimMode
    end

    if type(data.Aim) == "table" then
        for key, defaultValue in pairs(DefaultConfig.Aim) do
            if data.Aim[key] ~= nil and type(data.Aim[key]) == type(defaultValue) then
                Config.Aim[key] = data.Aim[key]
            end
        end
    end

    if type(data.ESP) == "table" then
        for key, defaultValue in pairs(DefaultConfig.ESP) do
            if data.ESP[key] ~= nil and type(data.ESP[key]) == type(defaultValue) then
                Config.ESP[key] = data.ESP[key]
            end
        end
    end

    Config.Aim.AutoShootButton = normalizeAutoShootButton(Config.Aim.AutoShootButton)
    ConfigStore.Applying = false
    return true
end

local function saveMeta()
    if not ConfigStore.Available then
        return false
    end

    ensureConfigFolders()
    local text = encodeJSON({
        Version = 1,
        Selected = ConfigStore.Selected,
        AutoSave = ConfigStore.AutoSave,
        AutoLoad = ConfigStore.AutoLoad,
    })

    if not text then
        return false
    end

    return pcall(FS.Write, ConfigStore.MetaPath, text)
end

local function loadMeta()
    if not ConfigStore.Available then
        return
    end

    local okExists, exists = pcall(FS.IsFile, ConfigStore.MetaPath)
    if not okExists or not exists then
        return
    end

    local okRead, text = pcall(FS.Read, ConfigStore.MetaPath)
    if not okRead then
        return
    end

    local data = decodeJSON(text)
    if type(data) ~= "table" then
        return
    end

    if data.Selected ~= nil then
        ConfigStore.Selected = sanitizeConfigName(data.Selected, "default")
    end
    if data.AutoSave ~= nil then
        ConfigStore.AutoSave = data.AutoSave == true
    end
    if data.AutoLoad ~= nil then
        ConfigStore.AutoLoad = data.AutoLoad == true
    end
end

local function saveConfig(name, notify)
    if not ConfigStore.Available then
        setConfigStatus("Unavailable • executor filesystem APIs missing")
        return false
    end

    local clean = sanitizeConfigName(name or ConfigStore.Selected, "default")
    ConfigStore.Selected = clean
    ensureConfigFolders()

    local text = encodeJSON(configSnapshot())
    if not text then
        setConfigStatus("Save failed • JSON error")
        return false
    end

    local okWrite = pcall(FS.Write, configPath(clean), text)
    if not okWrite then
        setConfigStatus("Save failed • write error")
        return false
    end

    saveMeta()
    ConfigStore.LastFingerprint = configFingerprint()
    setConfigStatus("Saved • " .. clean)

    if notify then
        PuckUI:Notify({
            Title = "Configs",
            Content = "Saved " .. clean,
            Duration = 2,
        })
    end

    return true
end

local function loadConfig(name, notify)
    if not ConfigStore.Available then
        setConfigStatus("Unavailable • executor filesystem APIs missing")
        return false
    end

    local clean = sanitizeConfigName(name or ConfigStore.Selected, "default")
    local path = configPath(clean)

    local okExists, exists = pcall(FS.IsFile, path)
    if not okExists or not exists then
        setConfigStatus("Not found • " .. clean)
        return false
    end

    local okRead, text = pcall(FS.Read, path)
    if not okRead then
        setConfigStatus("Load failed • read error")
        return false
    end

    local data = decodeJSON(text)
    if not applyConfigTable(data) then
        setConfigStatus("Load failed • invalid config")
        return false
    end

    ConfigStore.Selected = clean
    saveMeta()
    ConfigStore.LastFingerprint = configFingerprint()
    setConfigStatus("Loaded • " .. clean)

    if notify then
        PuckUI:Notify({
            Title = "Configs",
            Content = "Loaded " .. clean,
            Duration = 2,
        })
    end

    return true
end

local function listConfigProfiles()
    local result = {}
    local seen = {}

    local function add(name)
        local clean = sanitizeConfigName(name, "default")
        if not seen[clean] then
            seen[clean] = true
            table.insert(result, clean)
        end
    end

    add("default")
    add(ConfigStore.Selected)

    if ConfigStore.Available and FS.ListFiles then
        local okList, files = pcall(FS.ListFiles, ConfigStore.Folder)
        if okList and type(files) == "table" then
            for _, file in ipairs(files) do
                local normalized = tostring(file):gsub("\\", "/")
                local base = normalized:match("([^/]+)%.json$")
                if base and base ~= "_meta" then
                    add(base)
                end
            end
        end
    end

    table.sort(result)
    return result
end

local function deleteConfig(name)
    if not ConfigStore.Available or not FS.DeleteFile then
        setConfigStatus("Delete unavailable")
        return false
    end

    local clean = sanitizeConfigName(name or ConfigStore.Selected, "default")
    local path = configPath(clean)
    local okExists, exists = pcall(FS.IsFile, path)
    if not okExists or not exists then
        setConfigStatus("Not found • " .. clean)
        return false
    end

    local okDelete = pcall(FS.DeleteFile, path)
    if not okDelete then
        setConfigStatus("Delete failed")
        return false
    end

    if ConfigStore.Selected == clean then
        ConfigStore.Selected = "default"
    end
    saveMeta()
    setConfigStatus("Deleted • " .. clean)
    return true
end

loadMeta()
if ConfigStore.AutoLoad then
    loadConfig(ConfigStore.Selected, false)
end
ConfigStore.LastFingerprint = configFingerprint()

-- ============================================================================
-- One Tap Runtime Integration
-- ============================================================================

local NativeWeaponClient = nil
local NativeWeaponStatus = "Not scanned"

local function resolveNativeWeaponClient()
    NativeWeaponClient = nil
    NativeWeaponStatus = "Native WeaponClient unavailable • mouse fallback"

    local playerScripts = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
    local startScript = playerScripts and playerScripts:FindFirstChild("Start")
    local gameFolder = startScript and startScript:FindFirstChild("Game")
    local module = gameFolder and gameFolder:FindFirstChild("WeaponClient")

    if not (module and module:IsA("ModuleScript")) then
        return false
    end

    local okRequire, result = pcall(require, module)
    if okRequire and type(result) == "table" and type(result.fire) == "function" then
        NativeWeaponClient = result
        NativeWeaponStatus = "Native WeaponClient.fire ready"
        return true
    end

    return false
end

resolveNativeWeaponClient()

local function localCharacter()
    return LocalPlayer and LocalPlayer.Character or nil
end

local function localCombatReady()
    local character = localCharacter()
    if not character or not character.Parent then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    -- One Tap's own AimAssistClient starts/stops from this attribute.
    if character:GetAttribute("deployed") ~= true then
        return false
    end

    return true
end

local function isMouseHeld(button)
    local inputType = button == "LMB"
        and Enum.UserInputType.MouseButton1
        or Enum.UserInputType.MouseButton2

    local ok, held = pcall(function()
        return UserInputService:IsMouseButtonPressed(inputType)
    end)
    return ok and held or false
end

local function aimActive()
    if not Config.Aim.Enabled or not localCombatReady() then
        return false
    end

    if Config.Aim.HoldRMB then
        return isMouseHeld("RMB")
    end

    return true
end

local function autoShootActive()
    if not Config.Aim.AutoShoot or not localCombatReady() then
        return false
    end

    return isMouseHeld(normalizeAutoShootButton(Config.Aim.AutoShootButton))
end

local function isEnemyCharacter(character)
    if not character or character == localCharacter() or not character.Parent then
        return false
    end

    if not CollectionService:HasTag(character, "Character") then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    if character:FindFirstChildOfClass("ForceField") then
        return false
    end

    return true
end

local function iterateEnemies(callback)
    for _, character in ipairs(CollectionService:GetTagged("Character")) do
        if isEnemyCharacter(character) then
            callback(character)
        end
    end
end

local function getPlayerFromCharacter(character)
    local ok, player = pcall(Players.GetPlayerFromCharacter, Players, character)
    return ok and player or nil
end

local function getDisplayName(character)
    local player = getPlayerFromCharacter(character)
    if player then
        if player.DisplayName and player.DisplayName ~= "" then
            return player.DisplayName
        end
        return player.Name
    end

    return character and character.Name or "Enemy"
end

local function getHealth(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return 0, 100
    end

    return humanoid.Health, math.max(humanoid.MaxHealth, 1)
end

local function worldToScreen(position)
    local camera = currentCamera()
    if not camera then
        return Vector2.zero, false, -1
    end

    local point, onScreen = camera:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), onScreen and point.Z > 0, point.Z
end

local function getCandidateParts(character)
    local parts = {}
    local names = {
        "Head",
        "Hitbox_Head",
        "Torso",
        "UpperTorso",
        "LowerTorso",
        "HumanoidRootPart",
    }

    local seen = {}
    for _, name in ipairs(names) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") and not seen[part] then
            seen[part] = true
            table.insert(parts, part)
        end
    end

    return parts
end

local function getAimPart(character)
    local mode = tostring(Config.Aim.AimPoint or "Head")

    if mode == "Head" then
        local part = character:FindFirstChild("Head") or character:FindFirstChild("Hitbox_Head")
        if part and part:IsA("BasePart") then
            return part
        end
    elseif mode == "Torso" then
        local part = character:FindFirstChild("Torso")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("HumanoidRootPart")
        if part and part:IsA("BasePart") then
            return part
        end
    elseif mode == "Closest Part" then
        local center = screenCenter()
        local bestPart = nil
        local bestDistance = math.huge

        for _, part in ipairs(getCandidateParts(character)) do
            local screen, onScreen = worldToScreen(part.Position)
            if onScreen then
                local distance = (screen - center).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = part
                end
            end
        end

        if bestPart then
            return bestPart
        end
    end

    local fallback = character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Head")
    return fallback and fallback:IsA("BasePart") and fallback or nil
end

local velocityCache = setmetatable({}, {__mode = "k"})

local function getSmoothedVelocity(character, part)
    local raw = part and part.AssemblyLinearVelocity or Vector3.zero
    local entry = velocityCache[character]
    local smoothing = math.clamp(tonumber(Config.Aim.PredictionSmoothing) or 0, 0, 0.98)

    if not entry then
        entry = {Velocity = raw}
        velocityCache[character] = entry
        return raw
    end

    entry.Velocity = entry.Velocity:Lerp(raw, 1 - smoothing)
    return entry.Velocity
end

local function predictPosition(character, part, rawPosition, worldDistance)
    if not Config.Aim.Prediction then
        return rawPosition
    end

    local bulletSpeed = math.max(tonumber(Config.Aim.BulletSpeed) or 3850, 100)
    local extra = math.clamp(tonumber(Config.Aim.PredictionExtra) or 0, 0, 0.25)
    local travelTime = math.clamp(worldDistance / bulletSpeed + extra, 0, 0.35)
    local velocity = getSmoothedVelocity(character, part)
    local offset = velocity * travelTime
    local maxOffset = math.max(tonumber(Config.Aim.MaxPredictionOffset) or 0, 0)

    if maxOffset > 0 and offset.Magnitude > maxOffset then
        offset = offset.Unit * maxOffset
    end

    return rawPosition + offset
end

local function isVisible(character, position)
    if not Config.Aim.VisibleCheck then
        return true
    end

    local camera = currentCamera()
    local localChar = localCharacter()
    if not camera or not localChar then
        return false
    end

    local ignore = {localChar, character}
    local effects = workspace:FindFirstChild("Effects")
    if effects then
        table.insert(ignore, effects)
    end

    local viewmodel = camera:FindFirstChildWhichIsA("Model")
    if viewmodel then
        table.insert(ignore, viewmodel)
    end

    local ok, obscuring = pcall(function()
        return camera:GetPartsObscuringTarget({position}, ignore)
    end)

    return ok and #obscuring == 0
end

local lockedTarget = nil
local lockedTargetLastInfo = nil
local lockedTargetLastValidAt = 0
local lastTargetSwitchAt = 0

local function scoreTarget(screenDistance, worldDistance, health, maxHealth)
    local fov = math.max(tonumber(Config.Aim.FOV) or 1, 1)
    local maxDistance = math.max(tonumber(Config.Aim.MaxDistance) or 1, 1)
    local screenNorm = math.clamp(screenDistance / fov, 0, 2)
    local worldNorm = math.clamp(worldDistance / maxDistance, 0, 2)
    local healthNorm = math.clamp(health / math.max(maxHealth, 1), 0, 1)
    local priority = tostring(Config.Aim.TargetPriority or "Hybrid")

    if priority == "Distance" then
        return worldNorm
    elseif priority == "Low Health" then
        return healthNorm + screenNorm * 0.15
    elseif priority == "Crosshair" then
        return screenNorm
    end

    return screenNorm * 0.72 + worldNorm * 0.18 + healthNorm * 0.10
end

local function targetInfo(character, fovMultiplier)
    if not isEnemyCharacter(character) then
        return nil
    end

    local camera = currentCamera()
    if not camera then
        return nil
    end

    local part = getAimPart(character)
    if not part then
        return nil
    end

    local rawPosition = part.Position
    local worldDistance = (rawPosition - camera.CFrame.Position).Magnitude
    if worldDistance > math.max(tonumber(Config.Aim.MaxDistance) or 0, 1) then
        return nil
    end

    local position = predictPosition(character, part, rawPosition, worldDistance)
    local screenPosition, onScreen = worldToScreen(position)
    if not onScreen then
        return nil
    end

    local screenDistance = (screenPosition - screenCenter()).Magnitude
    local allowedFOV = math.max(tonumber(Config.Aim.FOV) or 0, 1) * (fovMultiplier or 1)
    if screenDistance > allowedFOV then
        return nil
    end

    if not isVisible(character, position) then
        return nil
    end

    local health, maxHealth = getHealth(character)
    return {
        Entity = character,
        Part = part,
        RawPosition = rawPosition,
        Position = position,
        ScreenPosition = screenPosition,
        ScreenDistance = screenDistance,
        WorldDistance = worldDistance,
        Health = health,
        MaxHealth = maxHealth,
        Score = scoreTarget(screenDistance, worldDistance, health, maxHealth),
    }
end

local function clearTarget()
    lockedTarget = nil
    lockedTargetLastInfo = nil
    lockedTargetLastValidAt = 0
end

local function acquireTarget()
    local now = os.clock()
    local stickyScale = Config.Aim.StickyTarget
        and math.max(tonumber(Config.Aim.StickyMultiplier) or 1, 1)
        or 1

    local lockedInfo = nil
    if lockedTarget then
        lockedInfo = targetInfo(lockedTarget, stickyScale)
        if lockedInfo then
            lockedTargetLastInfo = lockedInfo
            lockedTargetLastValidAt = now
        end
    end

    local bestInfo = nil
    iterateEnemies(function(character)
        local info = targetInfo(character, 1)
        if info and (not bestInfo or info.Score < bestInfo.Score) then
            bestInfo = info
        end
    end)

    if not lockedTarget then
        if bestInfo then
            lockedTarget = bestInfo.Entity
            lockedTargetLastInfo = bestInfo
            lockedTargetLastValidAt = now
            lastTargetSwitchAt = now
        end
        return bestInfo
    end

    if lockedInfo then
        if not bestInfo or bestInfo.Entity == lockedTarget then
            return lockedInfo
        end

        if not Config.Aim.StickyTarget then
            lockedTarget = bestInfo.Entity
            lockedTargetLastInfo = bestInfo
            lockedTargetLastValidAt = now
            lastTargetSwitchAt = now
            return bestInfo
        end

        local switchDelay = math.max(tonumber(Config.Aim.SwitchDelay) or 0, 0)
        if now - lastTargetSwitchAt < switchDelay then
            return lockedInfo
        end

        local threshold = math.clamp(tonumber(Config.Aim.SwitchThreshold) or 0, 0, 0.95)
        local requiredScore = lockedInfo.Score * (1 - threshold)
        if bestInfo.Score < requiredScore then
            lockedTarget = bestInfo.Entity
            lockedTargetLastInfo = bestInfo
            lockedTargetLastValidAt = now
            lastTargetSwitchAt = now
            return bestInfo
        end

        return lockedInfo
    end

    local grace = math.max(tonumber(Config.Aim.LockGrace) or 0, 0)
    if lockedTargetLastInfo and isEnemyCharacter(lockedTarget)
        and now - lockedTargetLastValidAt <= grace
    then
        return lockedTargetLastInfo
    end

    if bestInfo then
        lockedTarget = bestInfo.Entity
        lockedTargetLastInfo = bestInfo
        lockedTargetLastValidAt = now
        lastTargetSwitchAt = now
        return bestInfo
    end

    clearTarget()
    return nil
end

local lastAutoShootTarget = nil
local lastAutoShotAttemptAt = 0
local lastAutoShotAt = 0

local function fireNativeOrFallback()
    if not NativeWeaponClient then
        resolveNativeWeaponClient()
    end

    if NativeWeaponClient and type(NativeWeaponClient.fire) == "function" then
        local ok = pcall(NativeWeaponClient.fire)
        if ok then
            return true
        end
        NativeWeaponClient = nil
    end

    if type(mouse1click) == "function" then
        return pcall(mouse1click)
    end

    return false
end

local function tryAutoShoot(info)
    if not autoShootActive() or not info or not info.Entity then
        return
    end

    if lockedTarget ~= info.Entity or not isEnemyCharacter(info.Entity) then
        return
    end

    local fresh = targetInfo(info.Entity, math.max(tonumber(Config.Aim.StickyMultiplier) or 1, 1))
    if not fresh then
        return
    end

    local screenPosition, onScreen = worldToScreen(fresh.Position)
    if not onScreen then
        return
    end

    local errorPixels = (screenPosition - screenCenter()).Magnitude
    local radius = math.clamp(tonumber(Config.Aim.AutoShootRadius) or 8, 1, 50)
    if errorPixels > radius then
        return
    end

    local now = os.clock()
    local delay = math.max(tonumber(Config.Aim.AutoShootDelay) or 0, 0)

    if lastAutoShootTarget ~= info.Entity then
        lastAutoShootTarget = info.Entity
        lastAutoShotAttemptAt = 0
    end

    -- Avoid hammering the module every RenderStepped while still allowing the
    -- game's own firerate/cooldown logic to be the real limiter.
    if now - lastAutoShotAttemptAt < math.max(delay, 0.02) then
        return
    end

    lastAutoShotAttemptAt = now
    if fireNativeOrFallback() then
        lastAutoShotAt = now
    end
end

local function applyAim(dt)
    local shouldAim = aimActive()
    local shouldShoot = autoShootActive()

    if not shouldAim and not shouldShoot then
        if not localCombatReady() or (not Config.Aim.Enabled and not Config.Aim.AutoShoot) then
            clearTarget()
        end
        return
    end

    local info = acquireTarget()
    if not info then
        return
    end

    local camera = currentCamera()
    if not camera then
        return
    end

    if shouldAim then
        local current = camera.CFrame
        local desired = CFrame.lookAt(current.Position, info.Position)
        local speed = math.max(tonumber(Config.Aim.SmoothSpeed) or 0.01, 0.01)

        if Config.Aim.AdaptiveSmoothing then
            local normalized = math.clamp(info.ScreenDistance / math.max(Config.Aim.FOV, 1), 0, 1)
            speed = speed * (0.58 + math.sqrt(normalized) * 1.42)
        end

        local snapRadius = math.max(tonumber(Config.Aim.MicroSnapRadius) or 0, 0)
        local alpha = 1 - math.exp(-speed * math.max(dt, 0))
        if snapRadius > 0 and info.ScreenDistance <= snapRadius then
            alpha = 1
        end

        camera.CFrame = current:Lerp(desired, math.clamp(alpha, 0, 1))
    end

    if shouldShoot then
        tryAutoShoot(info)
    end
end

-- ============================================================================
-- ESP / Overlay
-- ============================================================================

local function getOverlayParent()
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and typeof(parent) == "Instance" then
            return parent
        end
    end

    local okCore = pcall(function()
        return CoreGui.Name
    end)
    if okCore then
        return CoreGui
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local OverlayParent = getOverlayParent()
local oldOverlay = OverlayParent:FindFirstChild("RAINZXDEV_OneTap_Overlay")
if oldOverlay then
    oldOverlay:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RAINZXDEV_OneTap_Overlay"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = OverlayParent

local OverlayFolder = Instance.new("Frame")
OverlayFolder.Name = "ESP"
OverlayFolder.Size = UDim2.fromScale(1, 1)
OverlayFolder.BackgroundTransparency = 1
OverlayFolder.BorderSizePixel = 0
OverlayFolder.Parent = ScreenGui

local espObjects = {}

local function makeStroke(parent, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Color = Color3.fromRGB(255, 78, 78)
    stroke.Transparency = 0
    stroke.Parent = parent
    return stroke
end

local function makeText(parent)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamMedium
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.35
    label.TextSize = 13
    label.ZIndex = 10
    label.Parent = parent
    return label
end

local function createESP(character)
    if espObjects[character] then
        return espObjects[character]
    end

    local holder = Instance.new("Frame")
    holder.Name = "EntityESP"
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Visible = false
    holder.ZIndex = 5
    holder.Parent = OverlayFolder

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Size = UDim2.fromScale(1, 1)
    box.ZIndex = 5
    box.Parent = holder
    local boxStroke = makeStroke(box, 1.5)

    local nameLabel = makeText(holder)
    nameLabel.Name = "Name"
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Position = UDim2.new(0.5, 0, 0, -3)
    nameLabel.Size = UDim2.new(1.8, 0, 0, 18)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center

    local infoLabel = makeText(holder)
    infoLabel.Name = "Info"
    infoLabel.AnchorPoint = Vector2.new(0.5, 0)
    infoLabel.Position = UDim2.new(0.5, 0, 1, 3)
    infoLabel.Size = UDim2.new(1.9, 0, 0, 18)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Center

    local hpBack = Instance.new("Frame")
    hpBack.Name = "HealthBack"
    hpBack.AnchorPoint = Vector2.new(1, 0)
    hpBack.Position = UDim2.new(0, -4, 0, 0)
    hpBack.Size = UDim2.new(0, 4, 1, 0)
    hpBack.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    hpBack.BorderSizePixel = 0
    hpBack.ZIndex = 6
    hpBack.Parent = holder

    local hpFill = Instance.new("Frame")
    hpFill.Name = "Health"
    hpFill.AnchorPoint = Vector2.new(0, 1)
    hpFill.Position = UDim2.new(0, 0, 1, 0)
    hpFill.Size = UDim2.fromScale(1, 1)
    hpFill.BackgroundColor3 = Color3.fromRGB(85, 255, 110)
    hpFill.BorderSizePixel = 0
    hpFill.ZIndex = 7
    hpFill.Parent = hpBack

    local tracer = Instance.new("Frame")
    tracer.Name = "Tracer"
    tracer.AnchorPoint = Vector2.new(0, 0.5)
    tracer.BackgroundColor3 = Color3.fromRGB(255, 78, 78)
    tracer.BorderSizePixel = 0
    tracer.Size = UDim2.fromOffset(0, 1)
    tracer.Visible = false
    tracer.ZIndex = 3
    tracer.Parent = OverlayFolder

    local highlight = Instance.new("Highlight")
    highlight.Name = "RAINZXDEV_OneTap_Highlight"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(255, 60, 60)
    highlight.FillTransparency = 0.82
    highlight.OutlineColor = Color3.fromRGB(255, 115, 115)
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Parent = workspace

    local object = {
        Holder = holder,
        Box = box,
        BoxStroke = boxStroke,
        Name = nameLabel,
        Info = infoLabel,
        HealthBack = hpBack,
        HealthFill = hpFill,
        Tracer = tracer,
        Highlight = highlight,
    }

    espObjects[character] = object
    return object
end

local function hideESPObject(object)
    if not object then
        return
    end

    object.Holder.Visible = false
    object.Tracer.Visible = false
    object.Highlight.Enabled = false
end

local function removeESP(character)
    local object = espObjects[character]
    if not object then
        return
    end

    for _, instance in pairs(object) do
        if typeof(instance) == "Instance" then
            pcall(function()
                instance:Destroy()
            end)
        end
    end

    espObjects[character] = nil
end

local function getBounds(character)
    if not character or not character:IsA("Model") then
        return nil
    end

    local ok, cf, size = pcall(character.GetBoundingBox, character)
    if not ok or typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" then
        return nil
    end

    size = size + Vector3.new(0.25, 0.35, 0.25)
    local half = size * 0.5
    local corners = {
        Vector3.new(-half.X, -half.Y, -half.Z),
        Vector3.new(-half.X, -half.Y,  half.Z),
        Vector3.new(-half.X,  half.Y, -half.Z),
        Vector3.new(-half.X,  half.Y,  half.Z),
        Vector3.new( half.X, -half.Y, -half.Z),
        Vector3.new( half.X, -half.Y,  half.Z),
        Vector3.new( half.X,  half.Y, -half.Z),
        Vector3.new( half.X,  half.Y,  half.Z),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyInFront = false
    local camera = currentCamera()
    if not camera then
        return nil
    end

    for _, localCorner in ipairs(corners) do
        local worldCorner = cf:PointToWorldSpace(localCorner)
        local point = camera:WorldToViewportPoint(worldCorner)
        if point.Z > 0 then
            anyInFront = true
            minX = math.min(minX, point.X)
            minY = math.min(minY, point.Y)
            maxX = math.max(maxX, point.X)
            maxY = math.max(maxY, point.Y)
        end
    end

    if not anyInFront or minX == math.huge then
        return nil
    end

    local width = maxX - minX
    local height = maxY - minY
    if width < 2 or height < 2 then
        return nil
    end

    return minX, minY, width, height
end

local function updateTracer(frame, from, to)
    local delta = to - from
    frame.Position = UDim2.fromOffset(from.X, from.Y)
    frame.Size = UDim2.fromOffset(delta.Magnitude, 1)
    frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local function updateESP()
    if not Config.ESP.Enabled or not localCombatReady() then
        for _, object in pairs(espObjects) do
            hideESPObject(object)
        end
        return
    end

    local camera = currentCamera()
    if not camera then
        return
    end

    local seen = {}
    iterateEnemies(function(character)
        seen[character] = true

        local part = getAimPart(character)
            or character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("Head")

        if not (part and part:IsA("BasePart")) then
            local old = espObjects[character]
            if old then hideESPObject(old) end
            return
        end

        local distance = (part.Position - camera.CFrame.Position).Magnitude
        if distance > math.max(tonumber(Config.ESP.MaxDistance) or 1, 1) then
            local old = espObjects[character]
            if old then hideESPObject(old) end
            return
        end

        local object = createESP(character)
        local minX, minY, width, height = getBounds(character)
        local locked = character == lockedTarget
        local mainColor = locked
            and Color3.fromRGB(100, 255, 125)
            or Color3.fromRGB(255, 78, 78)

        object.BoxStroke.Color = mainColor
        object.Tracer.BackgroundColor3 = mainColor
        object.Highlight.FillColor = mainColor
        object.Highlight.OutlineColor = mainColor
        object.Highlight.Adornee = character
        object.Highlight.Enabled = Config.ESP.Chams

        if minX then
            object.Holder.Visible = true
            object.Holder.Position = UDim2.fromOffset(minX, minY)
            object.Holder.Size = UDim2.fromOffset(width, height)
            object.Box.Visible = Config.ESP.Boxes

            object.Name.Visible = Config.ESP.Names
            object.Name.Text = getDisplayName(character)

            local health, maxHealth = getHealth(character)
            local ratio = math.clamp(health / math.max(maxHealth, 1), 0, 1)
            object.HealthBack.Visible = Config.ESP.Health
            object.HealthFill.Size = UDim2.fromScale(1, ratio)

            local info = {}
            if Config.ESP.Health then
                table.insert(info, ("%d HP"):format(math.max(0, math.floor(health + 0.5))))
            end
            if Config.ESP.Distance then
                table.insert(info, ("%d studs"):format(math.floor(distance + 0.5)))
            end
            object.Info.Visible = #info > 0
            object.Info.Text = table.concat(info, "  •  ")

            if Config.ESP.Tracers then
                local from = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y - 2)
                local to = Vector2.new(minX + width * 0.5, minY + height)
                updateTracer(object.Tracer, from, to)
                object.Tracer.Visible = true
            else
                object.Tracer.Visible = false
            end
        else
            object.Holder.Visible = false
            object.Tracer.Visible = false
        end
    end)

    for character in pairs(espObjects) do
        if not seen[character] or not isEnemyCharacter(character) then
            removeESP(character)
        end
    end
end

--// FOV ring
local FOVRing = Instance.new("Frame")
FOVRing.Name = "FOV"
FOVRing.AnchorPoint = Vector2.new(0.5, 0.5)
FOVRing.BackgroundTransparency = 1
FOVRing.BorderSizePixel = 0
FOVRing.ZIndex = 2
FOVRing.Parent = ScreenGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVRing

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 1
FOVStroke.Transparency = 0.25
FOVStroke.Color = Color3.fromRGB(255, 255, 255)
FOVStroke.Parent = FOVRing

local function updateFOV()
    local center = screenCenter()
    local diameter = math.max(tonumber(Config.Aim.FOV) or 1, 1) * 2
    FOVRing.Position = UDim2.fromOffset(center.X, center.Y)
    FOVRing.Size = UDim2.fromOffset(diameter, diameter)
    FOVRing.Visible = Config.Aim.ShowFOV and Config.Aim.Enabled and localCombatReady()
    FOVStroke.Color = lockedTarget
        and Color3.fromRGB(100, 255, 125)
        or Color3.fromRGB(255, 255, 255)
end

-- ============================================================================
-- RAINZXDEV UI
-- ============================================================================

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV Hub · One Tap",
    GuiName = "RAINZXDEV_OneTap",
    ConfigId = "OneTap",
    DisableBuiltInConfigs = true,
    Width = 500,
    Height = 560,
})

local CombatTab = Window:CreateTab("Combat")
local LegitTab = Window:CreateTab("Legit")
local RageTab = Window:CreateTab("Rage")
local VisualTab = Window:CreateTab("Visuals")
local SettingsTab = Window:CreateTab("Settings")
local ConfigsTab = Window:CreateTab("Configs")

local UIControls = {}
local syncUIFromConfig
local LegitModeLabel
local RageModeLabel
local BackendStatusLabel
local cleanup
local running = true

local function backendStatusText()
    local tagged = #CollectionService:GetTagged("Character")
    return ("One Tap backend • Character tag: %d • %s"):format(tagged, NativeWeaponStatus)
end

CombatTab:CreateSection("Game Integration")
BackendStatusLabel = CombatTab:CreateLabel(backendStatusText())
CombatTab:CreateLabel("Targets use One Tap's Character tag + Head/Torso rigs and the same camera obstruction style as its built-in aim assist.")

CombatTab:CreateSection("Auto Aim")
UIControls.AimEnabled = CombatTab:CreateToggle({
    Name = "Enable Auto Aim",
    CurrentValue = Config.Aim.Enabled,
    Callback = function(value)
        Config.Aim.Enabled = value
        if not value then clearTarget() end
    end,
})

UIControls.AimActivation = CombatTab:CreateDropdown({
    Name = "Aim Activation",
    Options = {"Hold RMB", "Always On"},
    CurrentOption = {Config.Aim.HoldRMB and "Hold RMB" or "Always On"},
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        Config.Aim.HoldRMB = value ~= "Always On"
        if not ConfigStore.Applying then Config.AimMode = "Custom" end
        clearTarget()
    end,
})

CombatTab:CreateSection("Auto Shoot")
UIControls.AutoShoot = CombatTab:CreateToggle({
    Name = "Enable Auto Shoot",
    CurrentValue = Config.Aim.AutoShoot,
    Callback = function(value)
        Config.Aim.AutoShoot = value
        lastAutoShootTarget = nil
        lastAutoShotAttemptAt = 0
    end,
})

UIControls.AutoShootButton = CombatTab:CreateDropdown({
    Name = "Auto Shoot Button",
    Options = {"RMB", "LMB"},
    CurrentOption = {normalizeAutoShootButton(Config.Aim.AutoShootButton)},
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        Config.Aim.AutoShootButton = normalizeAutoShootButton(value)
        lastAutoShootTarget = nil
    end,
})

UIControls.AutoShootRadius = CombatTab:CreateSlider({
    Name = "Shoot Radius",
    Range = {2, 30},
    Increment = 1,
    CurrentValue = Config.Aim.AutoShootRadius,
    Suffix = " px",
    Callback = function(value)
        Config.Aim.AutoShootRadius = value
    end,
})

UIControls.AutoShootDelay = CombatTab:CreateSlider({
    Name = "Extra Shot Delay",
    Range = {0, 0.50},
    Increment = 0.01,
    CurrentValue = Config.Aim.AutoShootDelay,
    Suffix = " s",
    Callback = function(value)
        Config.Aim.AutoShootDelay = value
    end,
})

CombatTab:CreateLabel("Auto Shoot uses One Tap's native WeaponClient.fire when available. It stays off by default.")

CombatTab:CreateSection("Aim Point / Lock")
UIControls.AimPoint = CombatTab:CreateDropdown({
    Name = "Aim Point",
    Options = {"Head", "Torso", "Closest Part"},
    CurrentOption = {Config.Aim.AimPoint},
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        Config.Aim.AimPoint = value or "Head"
        if not ConfigStore.Applying then Config.AimMode = "Custom" end
        clearTarget()
    end,
})

UIControls.StickyTarget = CombatTab:CreateToggle({
    Name = "Sticky Target",
    CurrentValue = Config.Aim.StickyTarget,
    Callback = function(value)
        Config.Aim.StickyTarget = value
        if not value then clearTarget() end
    end,
})

UIControls.VisibleCheck = CombatTab:CreateToggle({
    Name = "Wall / Visibility Check",
    CurrentValue = Config.Aim.VisibleCheck,
    Callback = function(value)
        Config.Aim.VisibleCheck = value
        if not ConfigStore.Applying then Config.AimMode = "Custom" end
        clearTarget()
    end,
})

CombatTab:CreateSection("FOV / Response")
UIControls.ShowFOV = CombatTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Config.Aim.ShowFOV,
    Callback = function(value)
        Config.Aim.ShowFOV = value
    end,
})

UIControls.FOV = CombatTab:CreateSlider({
    Name = "FOV Radius",
    Range = {40, 700},
    Increment = 5,
    CurrentValue = Config.Aim.FOV,
    Suffix = " px",
    Callback = function(value)
        Config.Aim.FOV = value
        if not ConfigStore.Applying then Config.AimMode = "Custom" end
    end,
})

UIControls.AimSpeed = CombatTab:CreateSlider({
    Name = "Aim Speed",
    Range = {4, 140},
    Increment = 1,
    CurrentValue = Config.Aim.SmoothSpeed,
    Callback = function(value)
        Config.Aim.SmoothSpeed = value
        if not ConfigStore.Applying then Config.AimMode = "Custom" end
    end,
})

UIControls.AimDistance = CombatTab:CreateSlider({
    Name = "Aim Max Distance",
    Range = {100, 1500},
    Increment = 25,
    CurrentValue = Config.Aim.MaxDistance,
    Suffix = " studs",
    Callback = function(value)
        Config.Aim.MaxDistance = value
        clearTarget()
    end,
})

CombatTab:CreateSection("Advanced Targeting")
UIControls.TargetPriority = CombatTab:CreateDropdown({
    Name = "Target Priority",
    Options = {"Crosshair", "Distance", "Low Health", "Hybrid"},
    CurrentOption = {Config.Aim.TargetPriority},
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        Config.Aim.TargetPriority = value or "Hybrid"
        clearTarget()
    end,
})

UIControls.Prediction = CombatTab:CreateToggle({
    Name = "Projectile Prediction",
    CurrentValue = Config.Aim.Prediction,
    Callback = function(value)
        Config.Aim.Prediction = value
    end,
})

UIControls.BulletSpeed = CombatTab:CreateSlider({
    Name = "Projectile Speed",
    Range = {500, 6000},
    Increment = 50,
    CurrentValue = Config.Aim.BulletSpeed,
    Suffix = " studs/s",
    Callback = function(value)
        Config.Aim.BulletSpeed = value
    end,
})

UIControls.PredictionExtra = CombatTab:CreateSlider({
    Name = "Extra Prediction",
    Range = {0, 0.20},
    Increment = 0.005,
    CurrentValue = Config.Aim.PredictionExtra,
    Suffix = " s",
    Callback = function(value)
        Config.Aim.PredictionExtra = value
    end,
})

UIControls.PredictionSmoothing = CombatTab:CreateSlider({
    Name = "Prediction Stability",
    Range = {0, 0.95},
    Increment = 0.01,
    CurrentValue = Config.Aim.PredictionSmoothing,
    Callback = function(value)
        Config.Aim.PredictionSmoothing = value
    end,
})

UIControls.MaxPredictionOffset = CombatTab:CreateSlider({
    Name = "Max Prediction Offset",
    Range = {0, 30},
    Increment = 1,
    CurrentValue = Config.Aim.MaxPredictionOffset,
    Suffix = " studs",
    Callback = function(value)
        Config.Aim.MaxPredictionOffset = value
    end,
})

UIControls.AdaptiveSmoothing = CombatTab:CreateToggle({
    Name = "Adaptive Smoothing",
    CurrentValue = Config.Aim.AdaptiveSmoothing,
    Callback = function(value)
        Config.Aim.AdaptiveSmoothing = value
    end,
})

UIControls.MicroSnap = CombatTab:CreateSlider({
    Name = "Micro Snap Radius",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = Config.Aim.MicroSnapRadius,
    Suffix = " px",
    Callback = function(value)
        Config.Aim.MicroSnapRadius = value
    end,
})

UIControls.SwitchDelay = CombatTab:CreateSlider({
    Name = "Target Switch Delay",
    Range = {0, 0.30},
    Increment = 0.01,
    CurrentValue = Config.Aim.SwitchDelay,
    Suffix = " s",
    Callback = function(value)
        Config.Aim.SwitchDelay = value
    end,
})

UIControls.SwitchThreshold = CombatTab:CreateSlider({
    Name = "Switch Improvement Required",
    Range = {0, 0.50},
    Increment = 0.01,
    CurrentValue = Config.Aim.SwitchThreshold,
    Callback = function(value)
        Config.Aim.SwitchThreshold = value
    end,
})

UIControls.LockGrace = CombatTab:CreateSlider({
    Name = "Target Lock Grace",
    Range = {0, 0.50},
    Increment = 0.01,
    CurrentValue = Config.Aim.LockGrace,
    Suffix = " s",
    Callback = function(value)
        Config.Aim.LockGrace = value
    end,
})

--// Visuals
VisualTab:CreateSection("ESP")
UIControls.ESPEnabled = VisualTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Config.ESP.Enabled,
    Callback = function(value)
        Config.ESP.Enabled = value
        if not value then
            for _, object in pairs(espObjects) do
                hideESPObject(object)
            end
        end
    end,
})

UIControls.Boxes = VisualTab:CreateToggle({
    Name = "Boxes",
    CurrentValue = Config.ESP.Boxes,
    Callback = function(value) Config.ESP.Boxes = value end,
})

UIControls.Names = VisualTab:CreateToggle({
    Name = "Names",
    CurrentValue = Config.ESP.Names,
    Callback = function(value) Config.ESP.Names = value end,
})

UIControls.Health = VisualTab:CreateToggle({
    Name = "Health",
    CurrentValue = Config.ESP.Health,
    Callback = function(value) Config.ESP.Health = value end,
})

UIControls.Distance = VisualTab:CreateToggle({
    Name = "Distance",
    CurrentValue = Config.ESP.Distance,
    Callback = function(value) Config.ESP.Distance = value end,
})

UIControls.Chams = VisualTab:CreateToggle({
    Name = "Chams",
    CurrentValue = Config.ESP.Chams,
    Callback = function(value) Config.ESP.Chams = value end,
})

UIControls.Tracers = VisualTab:CreateToggle({
    Name = "Tracers",
    CurrentValue = Config.ESP.Tracers,
    Callback = function(value) Config.ESP.Tracers = value end,
})

VisualTab:CreateSection("ESP Range")
UIControls.ESPDistance = VisualTab:CreateSlider({
    Name = "ESP Max Distance",
    Range = {100, 3000},
    Increment = 50,
    CurrentValue = Config.ESP.MaxDistance,
    Suffix = " studs",
    Callback = function(value) Config.ESP.MaxDistance = value end,
})

VisualTab:CreateLabel("The current aim target is highlighted green; other enemies stay red.")

--// Presets
local function updateAimModeLabels()
    local text = "Current mode • " .. tostring(Config.AimMode or "Custom")
    if LegitModeLabel and LegitModeLabel.Set then LegitModeLabel:Set(text) end
    if RageModeLabel and RageModeLabel.Set then RageModeLabel:Set(text) end
end

local function applyAimPreset(name, values, notification)
    ConfigStore.Applying = true
    Config.AimMode = name
    for key, value in pairs(values or {}) do
        if Config.Aim[key] ~= nil then
            Config.Aim[key] = value
        end
    end
    ConfigStore.Applying = false
    clearTarget()

    if syncUIFromConfig then
        syncUIFromConfig()
    end

    updateAimModeLabels()
    PuckUI:Notify({
        Title = name,
        Content = notification or (name .. " applied"),
        Duration = 2.2,
    })
end

LegitTab:CreateSection("Legit Aim")
LegitModeLabel = LegitTab:CreateLabel("Current mode • " .. tostring(Config.AimMode))

LegitTab:CreateButton({
    Name = "Legit • Subtle",
    Callback = function()
        applyAimPreset("Legit • Subtle", {
            Enabled = true,
            HoldRMB = true,
            VisibleCheck = true,
            AimPoint = "Head",
            FOV = 75,
            SmoothSpeed = 12,
            StickyTarget = true,
            StickyMultiplier = 1.15,
            Prediction = true,
            BulletSpeed = 3850,
            PredictionExtra = 0,
            PredictionSmoothing = 0.84,
            MaxPredictionOffset = 10,
            AdaptiveSmoothing = true,
            MicroSnapRadius = 0.5,
            TargetPriority = "Hybrid",
            SwitchDelay = 0.12,
            SwitchThreshold = 0.22,
            LockGrace = 0.24,
            ShowFOV = false,
        }, "Hold RMB • 75px FOV • smooth visible-target aim")
    end,
})

LegitTab:CreateButton({
    Name = "Legit • Balanced",
    Callback = function()
        applyAimPreset("Legit • Balanced", {
            Enabled = true,
            HoldRMB = true,
            VisibleCheck = true,
            AimPoint = "Head",
            FOV = 120,
            SmoothSpeed = 22,
            StickyTarget = true,
            StickyMultiplier = 1.22,
            Prediction = true,
            BulletSpeed = 3850,
            PredictionExtra = 0,
            PredictionSmoothing = 0.78,
            MaxPredictionOffset = 14,
            AdaptiveSmoothing = true,
            MicroSnapRadius = 1,
            TargetPriority = "Hybrid",
            SwitchDelay = 0.08,
            SwitchThreshold = 0.18,
            LockGrace = 0.21,
            ShowFOV = true,
        }, "Hold RMB • 120px FOV • balanced response")
    end,
})

LegitTab:CreateButton({
    Name = "Legit • Strong",
    Callback = function()
        applyAimPreset("Legit • Strong", {
            Enabled = true,
            HoldRMB = true,
            VisibleCheck = true,
            AimPoint = "Head",
            FOV = 190,
            SmoothSpeed = 38,
            StickyTarget = true,
            StickyMultiplier = 1.30,
            Prediction = true,
            BulletSpeed = 3850,
            PredictionExtra = 0,
            PredictionSmoothing = 0.72,
            MaxPredictionOffset = 18,
            AdaptiveSmoothing = true,
            MicroSnapRadius = 1.5,
            TargetPriority = "Crosshair",
            SwitchDelay = 0.05,
            SwitchThreshold = 0.12,
            LockGrace = 0.17,
            ShowFOV = true,
        }, "Hold RMB • 190px FOV • fast visible-target response")
    end,
})

RageTab:CreateSection("Rage Aim")
RageModeLabel = RageTab:CreateLabel("Current mode • " .. tostring(Config.AimMode))

RageTab:CreateButton({
    Name = "Rage • Visible",
    Callback = function()
        applyAimPreset("Rage • Visible", {
            Enabled = true,
            HoldRMB = false,
            VisibleCheck = true,
            AimPoint = "Head",
            FOV = 520,
            SmoothSpeed = 100,
            StickyTarget = true,
            StickyMultiplier = 1.50,
            Prediction = true,
            BulletSpeed = 3850,
            PredictionExtra = 0,
            PredictionSmoothing = 0.60,
            MaxPredictionOffset = 22,
            AdaptiveSmoothing = false,
            MicroSnapRadius = 5,
            TargetPriority = "Crosshair",
            SwitchDelay = 0,
            SwitchThreshold = 0.06,
            LockGrace = 0.12,
            ShowFOV = true,
        }, "Always On • large FOV • fast • visible targets only")
    end,
})

RageTab:CreateButton({
    Name = "Rage • Max",
    Callback = function()
        applyAimPreset("Rage • Max", {
            Enabled = true,
            HoldRMB = false,
            VisibleCheck = false,
            AimPoint = "Closest Part",
            FOV = 700,
            SmoothSpeed = 140,
            StickyTarget = true,
            StickyMultiplier = 1.65,
            Prediction = true,
            BulletSpeed = 3850,
            PredictionExtra = 0,
            PredictionSmoothing = 0.52,
            MaxPredictionOffset = 25,
            AdaptiveSmoothing = false,
            MicroSnapRadius = 10,
            TargetPriority = "Crosshair",
            SwitchDelay = 0,
            SwitchThreshold = 0.02,
            LockGrace = 0.10,
            ShowFOV = true,
        }, "Always On • max FOV / response • visibility check disabled")
    end,
})

RageTab:CreateSection("Helpers")
RageTab:CreateButton({
    Name = "Always On",
    Callback = function()
        Config.AimMode = "Rage • Custom"
        Config.Aim.Enabled = true
        Config.Aim.HoldRMB = false
        clearTarget()
        if syncUIFromConfig then syncUIFromConfig() end
    end,
})

RageTab:CreateButton({
    Name = "Ignore Walls / Visibility",
    Callback = function()
        Config.AimMode = "Rage • Custom"
        Config.Aim.VisibleCheck = false
        clearTarget()
        if syncUIFromConfig then syncUIFromConfig() end
    end,
})

RageTab:CreateButton({
    Name = "Head Only",
    Callback = function()
        Config.AimMode = "Rage • Custom"
        Config.Aim.AimPoint = "Head"
        clearTarget()
        if syncUIFromConfig then syncUIFromConfig() end
    end,
})

--// Sync loaded configs/presets into controls
syncUIFromConfig = function()
    ConfigStore.Applying = true

    local values = {
        {UIControls.AimEnabled, Config.Aim.Enabled},
        {UIControls.AimActivation, Config.Aim.HoldRMB and "Hold RMB" or "Always On"},
        {UIControls.AutoShoot, Config.Aim.AutoShoot},
        {UIControls.AutoShootButton, normalizeAutoShootButton(Config.Aim.AutoShootButton)},
        {UIControls.AutoShootRadius, Config.Aim.AutoShootRadius},
        {UIControls.AutoShootDelay, Config.Aim.AutoShootDelay},
        {UIControls.AimPoint, Config.Aim.AimPoint},
        {UIControls.StickyTarget, Config.Aim.StickyTarget},
        {UIControls.VisibleCheck, Config.Aim.VisibleCheck},
        {UIControls.ShowFOV, Config.Aim.ShowFOV},
        {UIControls.FOV, Config.Aim.FOV},
        {UIControls.AimSpeed, Config.Aim.SmoothSpeed},
        {UIControls.AimDistance, Config.Aim.MaxDistance},
        {UIControls.TargetPriority, Config.Aim.TargetPriority},
        {UIControls.Prediction, Config.Aim.Prediction},
        {UIControls.BulletSpeed, Config.Aim.BulletSpeed},
        {UIControls.PredictionExtra, Config.Aim.PredictionExtra},
        {UIControls.PredictionSmoothing, Config.Aim.PredictionSmoothing},
        {UIControls.MaxPredictionOffset, Config.Aim.MaxPredictionOffset},
        {UIControls.AdaptiveSmoothing, Config.Aim.AdaptiveSmoothing},
        {UIControls.MicroSnap, Config.Aim.MicroSnapRadius},
        {UIControls.SwitchDelay, Config.Aim.SwitchDelay},
        {UIControls.SwitchThreshold, Config.Aim.SwitchThreshold},
        {UIControls.LockGrace, Config.Aim.LockGrace},
        {UIControls.ESPEnabled, Config.ESP.Enabled},
        {UIControls.Boxes, Config.ESP.Boxes},
        {UIControls.Names, Config.ESP.Names},
        {UIControls.Health, Config.ESP.Health},
        {UIControls.Distance, Config.ESP.Distance},
        {UIControls.Chams, Config.ESP.Chams},
        {UIControls.Tracers, Config.ESP.Tracers},
        {UIControls.ESPDistance, Config.ESP.MaxDistance},
    }

    for _, pair in ipairs(values) do
        local control, value = pair[1], pair[2]
        if control and control.Set then
            pcall(function()
                control:Set(value)
            end)
        end
    end

    ConfigStore.Applying = false
    clearTarget()
    updateAimModeLabels()
end

--// Settings
SettingsTab:CreateSection("One Tap")
SettingsTab:CreateLabel("Universe ID • " .. tostring(ONE_TAP_UNIVERSE_ID))
SettingsTab:CreateLabel("Root Place ID • " .. tostring(ONE_TAP_ROOT_PLACE_ID))
SettingsTab:CreateLabel("Shared PuckUI toggle key defaults to K and follows the global RAINZXDEV UI setting.")

SettingsTab:CreateButton({
    Name = "Re-scan Native Weapon Client",
    Callback = function()
        resolveNativeWeaponClient()
        if BackendStatusLabel and BackendStatusLabel.Set then
            BackendStatusLabel:Set(backendStatusText())
        end
        PuckUI:Notify({
            Title = "One Tap",
            Content = NativeWeaponStatus,
            Duration = 2,
        })
    end,
})

SettingsTab:CreateButton({
    Name = "Reset Aim + ESP Defaults",
    Callback = function()
        Config = deepCopy(DefaultConfig)
        clearTarget()
        velocityCache = setmetatable({}, {__mode = "k"})
        if syncUIFromConfig then syncUIFromConfig() end
        PuckUI:Notify({
            Title = "One Tap",
            Content = "Aim and ESP defaults restored",
            Duration = 2,
        })
    end,
})

SettingsTab:CreateButton({
    Name = "Unload One Tap Script",
    Callback = function()
        if cleanup then
            cleanup()
        end
    end,
})

--// Configs
ConfigsTab:CreateSection("Profiles")
ConfigStore.StatusLabel = ConfigsTab:CreateLabel(
    ConfigStore.Available
        and ("Ready • " .. ConfigStore.Selected)
        or "Unavailable • executor filesystem APIs missing"
)

if ConfigStore.Available then
    ConfigStore.ProfileDropdown = ConfigsTab:CreateDropdown({
        Name = "Config Profile",
        Options = listConfigProfiles(),
        CurrentOption = {ConfigStore.Selected},
        Callback = function(option)
            local value = type(option) == "table" and option[1] or option
            if value ~= nil then
                ConfigStore.Selected = sanitizeConfigName(value, "default")
                ConfigStore.PendingProfile = ConfigStore.Selected
                if ConfigStore.ProfileInput and ConfigStore.ProfileInput.Set then
                    ConfigStore.ProfileInput:Set(ConfigStore.Selected)
                end
                saveMeta()
                setConfigStatus("Selected • " .. ConfigStore.Selected)
            end
        end,
    })

    ConfigStore.ProfileInput = ConfigsTab:CreateInput({
        Name = "Profile Name",
        CurrentValue = ConfigStore.Selected,
        PlaceholderText = "default",
        Callback = function(value)
            ConfigStore.PendingProfile = sanitizeConfigName(value, ConfigStore.Selected)
        end,
    })

    ConfigsTab:CreateButton({
        Name = "Save / Create Profile",
        Callback = function()
            local profile = ConfigStore.PendingProfile or ConfigStore.Selected
            ConfigStore.Selected = sanitizeConfigName(profile, "default")
            if saveConfig(ConfigStore.Selected, true) then
                ConfigStore.ProfileDropdown:Refresh(listConfigProfiles())
                ConfigStore.ProfileDropdown:Set(ConfigStore.Selected)
            end
        end,
    })

    ConfigsTab:CreateButton({
        Name = "Load Selected Profile",
        Callback = function()
            if loadConfig(ConfigStore.Selected, true) then
                syncUIFromConfig()
            end
        end,
    })

    ConfigsTab:CreateButton({
        Name = "Refresh Profiles",
        Callback = function()
            ConfigStore.ProfileDropdown:Refresh(listConfigProfiles())
            ConfigStore.ProfileDropdown:Set(ConfigStore.Selected)
            setConfigStatus("Profiles refreshed")
        end,
    })

    ConfigsTab:CreateButton({
        Name = "Delete Selected Profile",
        Callback = function()
            local deleted = ConfigStore.Selected
            if deleteConfig(deleted) then
                ConfigStore.ProfileDropdown:Refresh(listConfigProfiles())
                ConfigStore.ProfileDropdown:Set(ConfigStore.Selected)
                ConfigStore.ProfileInput:Set(ConfigStore.Selected)
                PuckUI:Notify({
                    Title = "Configs",
                    Content = "Deleted " .. deleted,
                    Duration = 2,
                })
            end
        end,
    })

    ConfigsTab:CreateSection("Automation")
    UIControls.AutoSave = ConfigsTab:CreateToggle({
        Name = "Auto Save",
        CurrentValue = ConfigStore.AutoSave,
        Callback = function(value)
            ConfigStore.AutoSave = value
            saveMeta()
            setConfigStatus(value and "Auto Save enabled" or "Auto Save disabled")
        end,
    })

    UIControls.AutoLoad = ConfigsTab:CreateToggle({
        Name = "Auto Load",
        CurrentValue = ConfigStore.AutoLoad,
        Callback = function(value)
            ConfigStore.AutoLoad = value
            saveMeta()
            setConfigStatus(value and "Auto Load enabled" or "Auto Load disabled")
        end,
    })
else
    ConfigsTab:CreateLabel("Your executor does not expose writefile/readfile/isfile/makefolder, so profiles cannot be saved.")
end

syncUIFromConfig()

-- ============================================================================
-- Main Loops / Cleanup
-- ============================================================================

local renderConnection
local statusAccumulator = 0

renderConnection = RunService.RenderStepped:Connect(function(dt)
    if not running then
        return
    end

    applyAim(dt)
    updateESP()
    updateFOV()

    statusAccumulator = statusAccumulator + dt
    if statusAccumulator >= 1 then
        statusAccumulator = 0
        if BackendStatusLabel and BackendStatusLabel.Set then
            BackendStatusLabel:Set(backendStatusText())
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(0.8)
        if not running then
            break
        end

        if ConfigStore.Available and ConfigStore.AutoSave and not ConfigStore.Applying then
            local fingerprint = configFingerprint()
            if fingerprint ~= "" and fingerprint ~= ConfigStore.LastFingerprint then
                saveConfig(ConfigStore.Selected, false)
            end
        end
    end
end)

cleanup = function()
    if not running then
        return
    end
    running = false

    if renderConnection then
        pcall(function() renderConnection:Disconnect() end)
        renderConnection = nil
    end

    clearTarget()

    for character in pairs(espObjects) do
        removeESP(character)
    end

    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
    end

    if Window and type(Window.Destroy) == "function" then
        pcall(function() Window:Destroy() end)
    end

    if ENV.__rainzxdev_ONE_TAP_AIM_ESP_CLEANUP == cleanup then
        ENV.__rainzxdev_ONE_TAP_AIM_ESP_CLEANUP = nil
    end
end

ENV.__rainzxdev_ONE_TAP_AIM_ESP_CLEANUP = cleanup

PuckUI:Notify({
    Title = "RAINZXDEV Hub · One Tap",
    Content = "Game-specific aim + ESP loaded • " .. NativeWeaponStatus,
    Duration = 3,
})
