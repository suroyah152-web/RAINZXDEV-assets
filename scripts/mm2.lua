--[[
    RAINZXDEV Hub · Murder Mystery 2
    Role ESP + Murderer Cam Surroundings + Emote Security Audit
    SHERIFF + CIVILIAN HARD-LOCK FIRST-PERSON SHOOT

    Inspected MM2 client architecture:
      ReplicatedStorage.Modules.CurrentRoundClient
      ReplicatedStorage.Remotes.Gameplay.GetCurrentPlayerData
      ReplicatedStorage.Remotes.Gameplay.PlayerDataChanged
      ReplicatedStorage.Modules.ProfileData
      ReplicatedStorage.Remotes.Inventory.GetProfileData
      ReplicatedStorage.Database.Sync
      ReplicatedStorage.Remotes.Misc.PlayEmote

    Paid/locked emotes are preview-only in the local viewport.
]]

-- ============================================================================
-- Bootstrap / cleanup
-- ============================================================================

local ENV = (getgenv and getgenv()) or _G

if ENV.__rainzxdev_MM2_CLEANUP then
    pcall(ENV.__rainzxdev_MM2_CLEANUP)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local compiler = loadstring or load
if type(compiler) ~= "function" then
    return warn("[RAINZXDEV MM2] loadstring/load unavailable")
end

local okUI, uiSource = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/RAINZXDEV/Puck-Loader/main/ui/PuckUI.lua")
end)

if not okUI or type(uiSource) ~= "string" or #uiSource < 100 then
    return warn("[RAINZXDEV MM2] failed to download shared PuckUI")
end

local uiChunk, uiError = compiler(uiSource)
if not uiChunk then
    return warn("[RAINZXDEV MM2] PuckUI compile failed: " .. tostring(uiError))
end

local okPuck, PuckUI = pcall(uiChunk)
if not okPuck or type(PuckUI) ~= "table" or type(PuckUI.CreateWindow) ~= "function" then
    return warn("[RAINZXDEV MM2] invalid PuckUI")
end

-- ============================================================================
-- Utilities
-- ============================================================================

local destroyed = false
local connections = {}
local espObjects = {}
local roleCache = {}
local currentRoundClient = nil
local profileData = nil
local syncDatabase = nil

local function addConnection(connection)
    if connection then
        table.insert(connections, connection)
    end
    return connection
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c, d = pcall(fn, ...)
    if ok then
        return a, b, c, d
    end
    return nil
end

local function safeRequire(instance)
    if not instance or not instance:IsA("ModuleScript") then
        return nil
    end

    local ok, result = pcall(require, instance)
    if ok then
        return result
    end
    return nil
end

local function findPath(root, ...)
    local current = root
    for _, name in ipairs({...}) do
        if not current then
            return nil
        end
        current = current:FindFirstChild(name)
    end
    return current
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart = nil
    local startPosition = nil
    local dragInput = nil

    addConnection(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    addConnection(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    addConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startPosition then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))
end

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, target = pcall(gethui)
        if ok and target then
            return target
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    end

    return playerGui or game:GetService("CoreGui")
end

-- ============================================================================
-- Configuration
-- ============================================================================

local Settings = {
    ESP = {
        Enabled = true,
        Highlights = true,
        Names = true,
        Roles = true,
        Distance = true,
        ShowDead = false,
        MaxDistance = 1500,
        FillTransparency = 0.72,
    },

    MurderCam = {
        Enabled = true,
        View = "Shoulder",
        Width = 300,
        Height = 195,
        FPS = 20,

        ShowSurroundings = true,
        EnvironmentRadius = 50,
        EnvironmentRefresh = 1.10,
        MaxEnvironmentParts = 160,
        ShowNearbyPlayers = true,

        OrbitYaw = 25,
        OrbitPitch = -10,
        OrbitDistance = 11,
    },

    Emotes = {
        Selected = "",
        AutoStopPreview = true,
    },

    Audit = {
        AutoRestore = true,
        StopTestAnimation = true,
    },
}

local ROLE_COLORS = {
    Murderer = Color3.fromRGB(255, 55, 55),
    Sheriff = Color3.fromRGB(70, 130, 255),
    ["Sheriff/Hero"] = Color3.fromRGB(70, 160, 255),
    Hero = Color3.fromRGB(70, 210, 255),
    Innocent = Color3.fromRGB(70, 230, 95),

    Zombie = Color3.fromRGB(25, 172, 0),
    Survivor = Color3.fromRGB(43, 154, 238),
    Freezer = Color3.fromRGB(150, 220, 250),
    Runner = Color3.fromRGB(0, 200, 100),

    Vampire = Color3.fromRGB(190, 55, 255),
    Hunter = Color3.fromRGB(255, 170, 55),
    Villager = Color3.fromRGB(120, 220, 100),

    Team1 = Color3.fromRGB(255, 90, 90),
    Team2 = Color3.fromRGB(90, 150, 255),

    Unknown = Color3.fromRGB(210, 210, 210),
}

local function roleColor(role)
    return ROLE_COLORS[tostring(role or "")] or ROLE_COLORS.Unknown
end

-- ============================================================================
-- MM2 live round / role backend
-- ============================================================================

local Modules = ReplicatedStorage:FindFirstChild("Modules")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local GameplayRemotes = Remotes and Remotes:FindFirstChild("Gameplay")
local InventoryRemotes = Remotes and Remotes:FindFirstChild("Inventory")
local MiscRemotes = Remotes and Remotes:FindFirstChild("Misc")

local GetCurrentPlayerData = GameplayRemotes and GameplayRemotes:FindFirstChild("GetCurrentPlayerData")
local PlayerDataChangedRemote = GameplayRemotes and GameplayRemotes:FindFirstChild("PlayerDataChanged")
local GetProfileData = InventoryRemotes and InventoryRemotes:FindFirstChild("GetProfileData")
local ProfileDataChanged = InventoryRemotes and InventoryRemotes:FindFirstChild("ProfileDataChanged")
local PlayEmoteRemote = MiscRemotes and MiscRemotes:FindFirstChild("PlayEmote")

local CurrentRoundModule = Modules and Modules:FindFirstChild("CurrentRoundClient")
local ProfileDataModule = Modules and Modules:FindFirstChild("ProfileData")

currentRoundClient = safeRequire(CurrentRoundModule)
profileData = safeRequire(ProfileDataModule)

do
    local database = ReplicatedStorage:FindFirstChild("Database")
    local syncModule = database and database:FindFirstChild("Sync")
    syncDatabase = safeRequire(syncModule)
end

-- Some executors cannot require an already-running MM2 ModuleScript directly.
-- Recover the same live client tables from loaded modules / GC when available.
local function discoverLoadedMM2Tables()
    if type(getloadedmodules) == "function" then
        local ok, modules = pcall(getloadedmodules)
        if ok and type(modules) == "table" then
            for _, module in ipairs(modules) do
                if typeof(module) == "Instance" and module:IsA("ModuleScript") then
                    local name = module.Name

                    if not currentRoundClient and name == "CurrentRoundClient" then
                        currentRoundClient = safeRequire(module)
                    elseif not profileData and name == "ProfileData" then
                        profileData = safeRequire(module)
                    elseif not syncDatabase and name == "Sync"
                        and module.Parent
                        and module.Parent.Name == "Database" then
                        syncDatabase = safeRequire(module)
                    end
                end
            end
        end
    end

    if type(getgc) ~= "function" then
        return
    end

    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then
        return
    end

    for _, object in ipairs(objects) do
        if type(object) == "table" then
            if not currentRoundClient then
                local okRound, hasPlayerData, hasChanged, hasLatest, hasPerk = pcall(function()
                    return type(rawget(object, "PlayerData")) == "table",
                        rawget(object, "PlayerDataChanged") ~= nil,
                        type(rawget(object, "GetLatestPlayerData")) == "function",
                        type(rawget(object, "GetMurdererPerk")) == "function"
                end)

                if okRound and hasPlayerData and hasChanged and hasLatest and hasPerk then
                    currentRoundClient = object
                end
            end

            if not profileData then
                local okProfile, emotes, weapons = pcall(function()
                    return rawget(object, "Emotes"), rawget(object, "Weapons")
                end)

                if okProfile
                    and type(emotes) == "table"
                    and type(emotes.Owned) == "table"
                    and type(weapons) == "table"
                    and type(weapons.Owned) == "table" then
                    profileData = object
                end
            end

            if not syncDatabase then
                local okSync, emotes, weapons, rarity = pcall(function()
                    return rawget(object, "Emotes"),
                        rawget(object, "Weapons"),
                        rawget(object, "Rarity")
                end)

                if okSync
                    and type(emotes) == "table"
                    and type(weapons) == "table"
                    and type(rarity) == "table"
                    and (emotes.sit or emotes.dab or emotes.floss) then
                    syncDatabase = object
                end
            end

            if currentRoundClient and profileData and syncDatabase then
                break
            end
        end
    end
end

discoverLoadedMM2Tables()

local function copyRoleData(source)
    local nextCache = {}

    if type(source) == "table" then
        for playerName, data in pairs(source) do
            if type(playerName) == "string" and type(data) == "table" then
                nextCache[playerName] = data
            end
        end
    end

    roleCache = nextCache
end

local function refreshRoleCache()
    if destroyed then
        return false
    end

    if type(currentRoundClient) == "table"
        and type(currentRoundClient.PlayerData) == "table" then

        copyRoleData(currentRoundClient.PlayerData)
        return true
    end

    if GetCurrentPlayerData and GetCurrentPlayerData:IsA("RemoteFunction") then
        local ok, result = pcall(function()
            return GetCurrentPlayerData:InvokeServer()
        end)

        if ok and type(result) == "table" then
            copyRoleData(result)
            return true
        end
    end

    return false
end

local function refreshProfileData()
    if type(profileData) == "table" then
        return true
    end

    if GetProfileData and GetProfileData:IsA("RemoteFunction") then
        local ok, result = pcall(function()
            return GetProfileData:InvokeServer()
        end)

        if ok and type(result) == "table" then
            profileData = result
            return true
        end
    end

    return false
end

local function weaponFallbackRole(player)
    if not player then
        return "Unknown"
    end

    local function hasNamedTool(container, wanted)
        if not container then
            return false
        end

        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and string.lower(item.Name):find(wanted, 1, true) then
                return true
            end
        end

        return false
    end

    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")

    if hasNamedTool(character, "knife") or hasNamedTool(backpack, "knife") then
        return "Murderer"
    end

    if hasNamedTool(character, "gun") or hasNamedTool(backpack, "gun") then
        return "Sheriff/Hero"
    end

    return "Unknown"
end

local function getPlayerRoundData(player)
    if not player then
        return nil
    end
    return roleCache[player.Name]
end

local function getPlayerRole(player)
    local data = getPlayerRoundData(player)

    if type(data) == "table" and data.Role ~= nil then
        return tostring(data.Role)
    end

    return weaponFallbackRole(player)
end

local function playerIsDead(player)
    local data = getPlayerRoundData(player)
    if type(data) == "table" and data.Dead ~= nil then
        return data.Dead == true
    end

    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health <= 0
end

local function findRolePlayer(role)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not playerIsDead(player) then
            if getPlayerRole(player) == role then
                return player
            end
        end
    end
    return nil
end

local function getMurderer()
    local localRole = getPlayerRole(LocalPlayer)
    if localRole == "Murderer" then
        return LocalPlayer
    end

    return findRolePlayer("Murderer")
end

refreshRoleCache()
refreshProfileData()

if type(currentRoundClient) == "table"
    and currentRoundClient.PlayerDataChanged
    and currentRoundClient.PlayerDataChanged.Event then

    addConnection(currentRoundClient.PlayerDataChanged.Event:Connect(function()
        refreshRoleCache()
    end))
elseif PlayerDataChangedRemote and PlayerDataChangedRemote:IsA("RemoteEvent") then
    addConnection(PlayerDataChangedRemote.OnClientEvent:Connect(function(newData)
        if type(newData) == "table" then
            copyRoleData(newData)
        else
            task.defer(refreshRoleCache)
        end
    end))
end

if ProfileDataChanged then
    if ProfileDataChanged:IsA("BindableEvent") then
        addConnection(ProfileDataChanged.Event:Connect(function(key, value)
            if type(profileData) == "table" and key ~= nil then
                profileData[key] = value
            end
        end))
    elseif ProfileDataChanged:IsA("RemoteEvent") then
        addConnection(ProfileDataChanged.OnClientEvent:Connect(function(key, value)
            if type(profileData) == "table" and key ~= nil then
                profileData[key] = value
            else
                profileData = nil
                task.defer(refreshProfileData)
            end
        end))
    end
end

-- ============================================================================
-- Role ESP
-- ============================================================================

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "RAINZXDEV_MM2_ESP"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 9998
ESPGui.Parent = getGuiParent()

local ESPWorldFolder = Instance.new("Folder")
ESPWorldFolder.Name = "__RAINZXDEV_MM2_ESPWorld"
ESPWorldFolder.Parent = workspace

local function destroyESP(player)
    local object = espObjects[player]
    if not object then
        return
    end

    if object.Highlight then
        object.Highlight:Destroy()
    end

    if object.Billboard then
        object.Billboard:Destroy()
    end

    espObjects[player] = nil
end

local function ensureESP(player)
    local object = espObjects[player]
    if object then
        return object
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "RAINZXDEV_" .. player.Name
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.OutlineTransparency = 0
    highlight.FillTransparency = Settings.ESP.FillTransparency
    highlight.Enabled = false
    highlight.Parent = ESPWorldFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RAINZXDEVRole_" .. player.Name
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromOffset(230, 48)
    billboard.StudsOffset = Vector3.new(0, 3.25, 0)
    billboard.Enabled = false
    billboard.Parent = ESPGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextStrokeTransparency = 0
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = billboard

    object = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
    }

    espObjects[player] = object
    return object
end

local function updatePlayerESP(player)
    if player == LocalPlayer then
        destroyESP(player)
        return
    end

    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local dead = playerIsDead(player)

    local object = ensureESP(player)

    if not Settings.ESP.Enabled
        or not character
        or not head
        or not root
        or (dead and not Settings.ESP.ShowDead) then

        object.Highlight.Enabled = false
        object.Billboard.Enabled = false
        return
    end

    Camera = workspace.CurrentCamera or Camera
    if not Camera then
        object.Highlight.Enabled = false
        object.Billboard.Enabled = false
        return
    end

    local distance = (root.Position - Camera.CFrame.Position).Magnitude

    if distance > Settings.ESP.MaxDistance then
        object.Highlight.Enabled = false
        object.Billboard.Enabled = false
        return
    end

    local role = getPlayerRole(player)
    local color = roleColor(role)

    object.Highlight.Adornee = character
    object.Highlight.FillColor = color
    object.Highlight.OutlineColor = color
    object.Highlight.FillTransparency = Settings.ESP.FillTransparency
    object.Highlight.Enabled = Settings.ESP.Highlights

    object.Billboard.Adornee = head
    object.Billboard.Enabled = Settings.ESP.Names or Settings.ESP.Roles or Settings.ESP.Distance

    local pieces = {}

    if Settings.ESP.Names then
        table.insert(pieces, player.DisplayName or player.Name)
    end

    if Settings.ESP.Roles then
        table.insert(pieces, "[" .. string.upper(role) .. "]")
    end

    if Settings.ESP.Distance then
        table.insert(pieces, tostring(math.floor(distance + 0.5)) .. " studs")
    end

    if dead then
        table.insert(pieces, "[DEAD]")
    end

    object.Label.Text = table.concat(pieces, " ")
    object.Label.TextColor3 = color
end

-- ============================================================================
-- Overlay root
-- ============================================================================

local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "RAINZXDEV_MM2_Overlay"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.DisplayOrder = 9999
OverlayGui.Parent = getGuiParent()

-- ============================================================================
-- Murderer mini cam
-- ============================================================================

local MurderFrame = Instance.new("Frame")
MurderFrame.Name = "MurdererCam"
MurderFrame.AnchorPoint = Vector2.new(1, 0)
MurderFrame.Position = UDim2.new(1, -16, 0, 70)
MurderFrame.Size = UDim2.fromOffset(Settings.MurderCam.Width, Settings.MurderCam.Height)
MurderFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
MurderFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
MurderFrame.BorderSizePixel = 1
MurderFrame.Visible = false
MurderFrame.Parent = OverlayGui

local murderStroke = Instance.new("UIStroke")
murderStroke.Color = ROLE_COLORS.Murderer
murderStroke.Thickness = 1
murderStroke.Parent = MurderFrame

local MurderTitle = Instance.new("TextLabel")
MurderTitle.Name = "Title"
MurderTitle.Size = UDim2.new(1, 0, 0, 24)
MurderTitle.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MurderTitle.BorderSizePixel = 0
MurderTitle.Font = Enum.Font.Code
MurderTitle.TextSize = 12
MurderTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
MurderTitle.TextXAlignment = Enum.TextXAlignment.Left
MurderTitle.Text = "  Murderer Cam"
MurderTitle.Parent = MurderFrame

local MurderViewport = Instance.new("ViewportFrame")
MurderViewport.Name = "Viewport"
MurderViewport.Position = UDim2.fromOffset(4, 28)
MurderViewport.Size = UDim2.new(1, -8, 1, -32)
MurderViewport.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
MurderViewport.BorderSizePixel = 0
MurderViewport.Ambient = Color3.fromRGB(200, 200, 200)
MurderViewport.LightColor = Color3.fromRGB(255, 255, 255)
MurderViewport.LightDirection = Vector3.new(-1, -1, -1)
MurderViewport.Parent = MurderFrame

local MurderWorld = Instance.new("WorldModel")
MurderWorld.Name = "World"
MurderWorld.Parent = MurderViewport

local MurderEnvironment = Instance.new("Folder")
MurderEnvironment.Name = "Environment"
MurderEnvironment.Parent = MurderWorld

local MurderNearbyPlayers = Instance.new("Folder")
MurderNearbyPlayers.Name = "NearbyPlayers"
MurderNearbyPlayers.Parent = MurderWorld

local MurderCamera = Instance.new("Camera")
MurderCamera.FieldOfView = 55
MurderCamera.Parent = MurderViewport
MurderViewport.CurrentCamera = MurderCamera

makeDraggable(MurderTitle, MurderFrame)

local murderTarget = nil
local murderLiveCharacter = nil
local murderClone = nil
local murderPartMap = {}
local lastMurderSync = 0
local lastEnvironmentSync = 0
local lastEnvironmentCenter = nil
local lastNearbyPlayerSync = 0
local nearbyPlayerRefresh = 0.12

local environmentClones = {}
local nearbyPlayerClones = {}
local orbitDragging = false
local orbitLastPosition = nil

local function relativePath(instance, root)
    local parts = {}
    local current = instance

    while current and current ~= root do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end

    return table.concat(parts, "/")
end

local function clearMurderClone()
    murderTarget = nil
    murderLiveCharacter = nil
    murderPartMap = {}

    if murderClone then
        murderClone:Destroy()
        murderClone = nil
    end

    for clonePlayer, entry in pairs(nearbyPlayerClones) do
        if entry.Clone then
            entry.Clone:Destroy()
        end
        nearbyPlayerClones[clonePlayer] = nil
    end
end

local function cloneCharacterForViewport(character)
    if not character then
        return nil
    end

    local oldArchivable = character.Archivable
    character.Archivable = true

    local ok, clone = pcall(function()
        return character:Clone()
    end)

    character.Archivable = oldArchivable

    if not ok or not clone then
        return nil
    end

    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("Script") or item:IsA("LocalScript") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = false
            item.CanTouch = false
            item.CanQuery = false
        end
    end

    clone.Name = "MurdererViewportClone"
    clone.Parent = MurderWorld
    return clone
end

local function buildMurderPartMap(liveCharacter, clone)
    local map = {}

    for _, live in ipairs(liveCharacter:GetDescendants()) do
        if live:IsA("BasePart") then
            local path = relativePath(live, liveCharacter)
            map[path] = live
        end
    end

    murderPartMap = {}

    for _, copy in ipairs(clone:GetDescendants()) do
        if copy:IsA("BasePart") then
            local path = relativePath(copy, clone)
            local live = map[path]
            if live then
                murderPartMap[copy] = live
            end
        end
    end
end

local function ensureMurderTarget(player)
    if not player or not player.Character then
        clearMurderClone()
        return false
    end

    if murderTarget == player
        and murderLiveCharacter == player.Character
        and murderClone
        and murderClone.Parent
        and murderTarget.Character then

        return true
    end

    clearMurderClone()

    murderTarget = player
    murderLiveCharacter = player.Character
    murderClone = cloneCharacterForViewport(player.Character)

    if not murderClone then
        murderTarget = nil
        return false
    end

    buildMurderPartMap(player.Character, murderClone)
    return true
end


local function isDescendantOfAnyCharacter(instance)
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and instance:IsDescendantOf(character) then
            return true
        end
    end
    return false
end

local function cloneEnvironmentPart(livePart)
    if not livePart or not livePart:IsA("BasePart") then
        return nil
    end

    local originalArchivable = livePart.Archivable
    livePart.Archivable = true

    local ok, clone = pcall(function()
        return livePart:Clone()
    end)

    livePart.Archivable = originalArchivable

    if not ok or not clone then
        return nil
    end

    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("Script")
            or descendant:IsA("LocalScript")
            or descendant:IsA("ModuleScript")
            or descendant:IsA("ProximityPrompt")
            or descendant:IsA("ClickDetector") then
            descendant:Destroy()
        end
    end

    clone.Anchored = true
    clone.CanCollide = false
    clone.CanTouch = false
    clone.CanQuery = false
    clone.Parent = MurderEnvironment

    return clone
end

local function clearEnvironment()
    for livePart, clone in pairs(environmentClones) do
        if clone then
            clone:Destroy()
        end
        environmentClones[livePart] = nil
    end
end

local function syncEnvironment(center)
    if not Settings.MurderCam.ShowSurroundings then
        clearEnvironment()
        lastEnvironmentCenter = nil
        return
    end

    local radius = math.max(tonumber(Settings.MurderCam.EnvironmentRadius) or 50, 10)
    local maxParts = math.max(math.floor(tonumber(Settings.MurderCam.MaxEnvironmentParts) or 160), 40)

    -- Map geometry is mostly static. Rebuilding it every few render frames was
    -- the main source of Murderer Cam hitches. Only rescan when the murderer
    -- has moved into a meaningfully different area.
    if lastEnvironmentCenter
        and (center - lastEnvironmentCenter).Magnitude < math.max(10, radius * 0.22) then
        return
    end

    lastEnvironmentCenter = center

    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude

    local excluded = {ESPWorldFolder}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end
    overlap.FilterDescendantsInstances = excluded

    local ok, nearbyParts = pcall(function()
        return workspace:GetPartBoundsInRadius(center, radius, overlap)
    end)

    if not ok or type(nearbyParts) ~= "table" then
        return
    end

    -- Avoid sorting hundreds/thousands of parts. We only need a representative
    -- nearby set for the mini camera, not a perfect duplicate of the whole map.
    local keep = {}
    local count = 0

    for _, livePart in ipairs(nearbyParts) do
        if count >= maxParts then
            break
        end

        if livePart:IsA("BasePart")
            and livePart.Transparency < 0.98
            and livePart.Size.Magnitude > 0.35
            and not isDescendantOfAnyCharacter(livePart) then

            keep[livePart] = true
            count += 1

            local clone = environmentClones[livePart]
            if not clone or not clone.Parent then
                clone = cloneEnvironmentPart(livePart)
                environmentClones[livePart] = clone

                if clone then
                    -- Copy appearance once. Static MM2 map parts do not need
                    -- their material/color rewritten every viewport update.
                    clone.CFrame = livePart.CFrame
                    clone.Size = livePart.Size
                    clone.Color = livePart.Color
                    clone.Material = livePart.Material
                    clone.Transparency = livePart.Transparency
                    clone.Reflectance = livePart.Reflectance
                end
            end
        end
    end

    for livePart, clone in pairs(environmentClones) do
        if not keep[livePart] or not livePart.Parent then
            if clone then
                clone:Destroy()
            end
            environmentClones[livePart] = nil
        end
    end
end

local function makeViewportCharacterClone(player)
    if not player.Character then
        return nil
    end

    local clone = cloneCharacterForViewport(player.Character)
    if not clone then
        return nil
    end

    clone.Name = "Nearby_" .. player.Name
    clone.Parent = MurderNearbyPlayers

    local map = {}
    local liveByPath = {}

    for _, live in ipairs(player.Character:GetDescendants()) do
        if live:IsA("BasePart") then
            liveByPath[relativePath(live, player.Character)] = live
        end
    end

    for _, copy in ipairs(clone:GetDescendants()) do
        if copy:IsA("BasePart") then
            local live = liveByPath[relativePath(copy, clone)]
            if live then
                map[copy] = live
            end
        end
    end

    return {
        Clone = clone,
        Character = player.Character,
        PartMap = map,
    }
end

local function syncNearbyPlayers(center)
    local now = os.clock()
    if now - lastNearbyPlayerSync < nearbyPlayerRefresh then
        return
    end
    lastNearbyPlayerSync = now

    if not Settings.MurderCam.ShowNearbyPlayers then
        for player, entry in pairs(nearbyPlayerClones) do
            if entry.Clone then
                entry.Clone:Destroy()
            end
            nearbyPlayerClones[player] = nil
        end
        return
    end

    local radius = math.max(tonumber(Settings.MurderCam.EnvironmentRadius) or 50, 10)
    local keep = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= murderTarget and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - center).Magnitude <= radius then
                keep[player] = true

                local entry = nearbyPlayerClones[player]

                if not entry
                    or not entry.Clone
                    or not entry.Clone.Parent
                    or entry.Character ~= player.Character then

                    if entry and entry.Clone then
                        entry.Clone:Destroy()
                    end

                    entry = makeViewportCharacterClone(player)
                    nearbyPlayerClones[player] = entry
                end

                if entry then
                    for copy, live in pairs(entry.PartMap) do
                        if copy.Parent and live.Parent then
                            copy.CFrame = live.CFrame
                            copy.Transparency = live.Transparency
                        end
                    end
                end
            end
        end
    end

    for player, entry in pairs(nearbyPlayerClones) do
        if not keep[player] or player.Parent ~= Players then
            if entry.Clone then
                entry.Clone:Destroy()
            end
            nearbyPlayerClones[player] = nil
        end
    end
end

local function orbitCameraPosition(root, focus)
    local yaw = math.rad(tonumber(Settings.MurderCam.OrbitYaw) or 25)
    local pitch = math.rad(math.clamp(tonumber(Settings.MurderCam.OrbitPitch) or -10, -80, 80))
    local distance = math.max(tonumber(Settings.MurderCam.OrbitDistance) or 11, 3)

    local horizontal = math.cos(pitch) * distance
    local offset = Vector3.new(
        math.sin(yaw) * horizontal,
        math.sin(pitch) * distance + 2.5,
        math.cos(yaw) * horizontal
    )

    return focus + offset
end

-- Drag directly inside the mini viewport to orbit around the murderer.
addConnection(MurderViewport.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        orbitDragging = true
        orbitLastPosition = input.Position
    end
end))

addConnection(MurderViewport.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        orbitDragging = false
        orbitLastPosition = nil
    end
end))

addConnection(UserInputService.InputChanged:Connect(function(input)
    if not orbitDragging or not orbitLastPosition then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - orbitLastPosition
        orbitLastPosition = input.Position

        Settings.MurderCam.View = "Orbit"
        Settings.MurderCam.OrbitYaw = (Settings.MurderCam.OrbitYaw - delta.X * 0.35) % 360
        Settings.MurderCam.OrbitPitch = math.clamp(
            Settings.MurderCam.OrbitPitch + delta.Y * 0.25,
            -75,
            65
        )
    end
end))

local function updateMurderCamera()
    if not Settings.MurderCam.Enabled then
        MurderFrame.Visible = false
        return
    end

    local murderer = getMurderer()

    if not murderer
        or murderer == LocalPlayer
        or playerIsDead(murderer)
        or not murderer.Character then

        MurderFrame.Visible = false
        if murderer ~= murderTarget then
            clearMurderClone()
        end
        return
    end

    if not ensureMurderTarget(murderer) then
        MurderFrame.Visible = false
        return
    end

    local character = murderer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")

    if not root or not head then
        MurderFrame.Visible = false
        return
    end

    MurderFrame.Visible = true
    MurderTitle.Text = "  Murderer Cam · " .. tostring(murderer.DisplayName or murderer.Name)

    for clonePart, livePart in pairs(murderPartMap) do
        if clonePart.Parent and livePart.Parent then
            clonePart.CFrame = livePart.CFrame
            clonePart.Transparency = livePart.Transparency
            clonePart.Color = livePart.Color
        end
    end

    local now = os.clock()
    if now - lastEnvironmentSync >= math.max(Settings.MurderCam.EnvironmentRefresh, 0.35) then
        lastEnvironmentSync = now
        syncEnvironment(root.Position)
    end

    syncNearbyPlayers(root.Position)

    local focus = head.Position + Vector3.new(0, 0.2, 0)
    local view = Settings.MurderCam.View

    local camPos
    if view == "Behind" then
        camPos = (root.CFrame * CFrame.new(0, 2.5, 8)).Position
    elseif view == "Front" then
        camPos = (root.CFrame * CFrame.new(0, 2.5, -8)).Position
    elseif view == "Top Down" then
        camPos = root.Position + Vector3.new(0, 16, 1)
    elseif view == "Orbit" then
        camPos = orbitCameraPosition(root, focus)
    else
        camPos = (root.CFrame * CFrame.new(3.5, 2.5, 7)).Position
    end

    MurderCamera.CFrame = CFrame.lookAt(camPos, focus)
end

-- ============================================================================
-- Emote database / preview
-- ============================================================================

local emoteOptions = {}
local emoteOptionToId = {}
local selectedEmoteId = nil

local PreviewFrame = Instance.new("Frame")
PreviewFrame.Name = "EmotePreview"
PreviewFrame.AnchorPoint = Vector2.new(1, 1)
PreviewFrame.Position = UDim2.new(1, -16, 1, -16)
PreviewFrame.Size = UDim2.fromOffset(280, 320)
PreviewFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
PreviewFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
PreviewFrame.BorderSizePixel = 1
PreviewFrame.Visible = false
PreviewFrame.Parent = OverlayGui

local PreviewTitle = Instance.new("TextLabel")
PreviewTitle.Size = UDim2.new(1, 0, 0, 24)
PreviewTitle.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
PreviewTitle.BorderSizePixel = 0
PreviewTitle.Font = Enum.Font.Code
PreviewTitle.TextSize = 12
PreviewTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
PreviewTitle.TextXAlignment = Enum.TextXAlignment.Left
PreviewTitle.Text = "  Emote Preview"
PreviewTitle.Parent = PreviewFrame

local PreviewClose = Instance.new("TextButton")
PreviewClose.AnchorPoint = Vector2.new(1, 0)
PreviewClose.Position = UDim2.new(1, -4, 0, 3)
PreviewClose.Size = UDim2.fromOffset(18, 18)
PreviewClose.BackgroundTransparency = 1
PreviewClose.Font = Enum.Font.Code
PreviewClose.Text = "x"
PreviewClose.TextSize = 12
PreviewClose.TextColor3 = Color3.fromRGB(150, 150, 150)
PreviewClose.Parent = PreviewFrame

local PreviewViewport = Instance.new("ViewportFrame")
PreviewViewport.Position = UDim2.fromOffset(4, 28)
PreviewViewport.Size = UDim2.new(1, -8, 1, -32)
PreviewViewport.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
PreviewViewport.BorderSizePixel = 0
PreviewViewport.Ambient = Color3.fromRGB(200, 200, 200)
PreviewViewport.LightColor = Color3.fromRGB(255, 255, 255)
PreviewViewport.LightDirection = Vector3.new(-1, -1, -1)
PreviewViewport.Parent = PreviewFrame

local PreviewWorld = Instance.new("WorldModel")
PreviewWorld.Parent = PreviewViewport

local PreviewCamera = Instance.new("Camera")
PreviewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 2.8, 7), Vector3.new(0, 2.4, 0))
PreviewCamera.FieldOfView = 45
PreviewCamera.Parent = PreviewViewport
PreviewViewport.CurrentCamera = PreviewCamera

makeDraggable(PreviewTitle, PreviewFrame)

local previewClone = nil
local previewTrack = nil

local function stopEmotePreview()
    if previewTrack then
        pcall(function()
            previewTrack:Stop(0.1)
        end)
        previewTrack = nil
    end

    if previewClone then
        previewClone:Destroy()
        previewClone = nil
    end

    PreviewFrame.Visible = false
end

PreviewClose.MouseButton1Click:Connect(stopEmotePreview)

local function getOwnedEmotes()
    refreshProfileData()

    local owned = {}

    if type(profileData) == "table"
        and type(profileData.Emotes) == "table"
        and type(profileData.Emotes.Owned) == "table" then

        for key, value in pairs(profileData.Emotes.Owned) do
            if type(value) == "string" then
                owned[value] = true
            elseif type(key) == "string" and value then
                owned[key] = true
            end
        end
    end

    if type(profileData) == "table"
        and type(profileData.Toys) == "table"
        and type(profileData.Toys.Owned) == "table" then

        for key, value in pairs(profileData.Toys.Owned) do
            if type(value) == "string" then
                owned[value] = true
            elseif type(key) == "string" and value then
                owned[key] = true
            end
        end
    end

    return owned
end

local function getEmoteCatalog()
    local catalog = {}

    if type(syncDatabase) ~= "table" then
        return catalog
    end

    -- Whitelist of emotes to show
    local allowedEmotes = {
        ["Sit"] = true,
        ["Ninja Rest"] = true,
        ["Dab"] = true,
        ["Floss"] = true,
        ["Zen"] = true,
        ["Zombie"] = true,
    }

    local function addTable(source, sourceType)
        if type(source) ~= "table" then
            return
        end

        for id, info in pairs(source) do
            if type(id) == "string" and type(info) == "table" then
                local name = tostring(info.Name or info.DisplayName or id)
                
                -- Only add if in whitelist
                if allowedEmotes[name] then
                    local item = {}
                    for k, v in pairs(info) do
                        item[k] = v
                    end
                    item.Id = id
                    item.SourceType = sourceType
                    catalog[id] = item
                end
            end
        end
    end

    addTable(syncDatabase.Emotes, "Emotes")
    addTable(syncDatabase.Toys, "Toys")

    return catalog
end

local function priceText(info)
    if not info then
        return ""
    end

    if info.Price == nil then
        return "No price"
    end

    if type(info.Price) == "string" then
        return tostring(info.Price)
    end

    if type(info.Price) == "number" then
        return tostring(info.Price) .. (info.Gems and " Gems" or " Coins")
    end

    return tostring(info.Price)
end

local function buildEmoteOptions()
    local owned = getOwnedEmotes()
    local catalog = getEmoteCatalog()
    local rows = {}

    for id, info in pairs(catalog) do
        local displayName = tostring(info.Name or info.DisplayName or id)

        table.insert(rows, {
            Id = id,
            Text = displayName,
            Sort = string.lower(displayName),
        })
    end

    table.sort(rows, function(a, b)
        if a.Sort == b.Sort then
            return a.Id < b.Id
        end
        return a.Sort < b.Sort
    end)

    emoteOptions = {}
    emoteOptionToId = {}

    for _, row in ipairs(rows) do
        table.insert(emoteOptions, row.Text)
        emoteOptionToId[row.Text] = row.Id
    end

    if #emoteOptions == 0 then
        emoteOptions = {"No emotes found"}
    end

    if not selectedEmoteId and rows[1] then
        selectedEmoteId = rows[1].Id
        Settings.Emotes.Selected = selectedEmoteId
    end

    return emoteOptions
end

local function getEmoteInfo(id)
    local catalog = getEmoteCatalog()
    return catalog[id]
end

local function previewEmote(id)
    local info = getEmoteInfo(id)

    if not info then
        return false, "Emote not found"
    end

    local animationId = tonumber(info.AnimationID or info.AnimationId)

    if not animationId then
        return false, "This emote has no preview AnimationID in MM2's database."
    end

    stopEmotePreview()

    local character = LocalPlayer.Character
    if not character then
        return false, "Character not available"
    end

    local oldArchivable = character.Archivable
    character.Archivable = true

    local ok, clone = pcall(function()
        return character:Clone()
    end)

    character.Archivable = oldArchivable

    if not ok or not clone then
        return false, "Could not clone your avatar"
    end

    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Tool") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = false
            item.CanTouch = false
            item.CanQuery = false
        end
    end

    clone.Name = "EmotePreviewAvatar"
    clone.Parent = PreviewWorld

    local pivot = clone:GetPivot()
    clone:PivotTo(CFrame.new(0, 3, 0) * pivot.Rotation)

    local humanoid = clone:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        clone:Destroy()
        return false, "Preview avatar has no Humanoid"
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. tostring(animationId)

    local loadedOk, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)

    animation:Destroy()

    if not loadedOk or not track then
        clone:Destroy()
        return false, "Roblox could not load this animation"
    end

    track.Looped = info.Loop == true
    track.Priority = Enum.AnimationPriority.Action

    local playOk = pcall(function()
        track:Play(0.1, 1, 1)
    end)

    if not playOk then
        clone:Destroy()
        return false, "Could not start animation"
    end

    previewClone = clone
    previewTrack = track

    PreviewTitle.Text = "  Preview · " .. tostring(info.Name or id)
    PreviewFrame.Visible = true

    return true
end

local function canPlayOwnedEmote(id)
    local owned = getOwnedEmotes()
    return owned[id] == true
end

local function playOwnedEmote(id)
    if not id then
        return false, "No emote selected"
    end

    if not canPlayOwnedEmote(id) then
        return false, "Locked emotes are preview-only."
    end

    if not PlayEmoteRemote then
        return false, "MM2 PlayEmote remote not found"
    end

    local ok = pcall(function()
        if PlayEmoteRemote:IsA("BindableEvent") then
            PlayEmoteRemote:Fire(id)
        elseif PlayEmoteRemote:IsA("RemoteEvent") then
            PlayEmoteRemote:FireServer(id)
        end
    end)

    if not ok then
        return false, "MM2 rejected the play request"
    end

    return true
end

-- ============================================================================
-- Studio-only emote entitlement security audit
-- Public website build: locked to Roblox Studio testing only.
-- ============================================================================

local auditOwnedBackup = nil
local auditSpoofedId = nil
local auditMatchedTrack = nil

local function isStudioAuditAllowed()
    return RunService:IsStudio()
end

local function getOwnedTable()
    refreshProfileData()

    if type(profileData) == "table"
        and type(profileData.Emotes) == "table"
        and type(profileData.Emotes.Owned) == "table" then
        return profileData.Emotes.Owned
    end

    return nil
end

local function shallowCopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function ownedTableContains(owned, id)
    if type(owned) ~= "table" or type(id) ~= "string" then
        return false
    end

    if owned[id] == true then
        return true
    end

    return table.find(owned, id) ~= nil
end

local function restoreAuditOwnership()
    local owned = getOwnedTable()

    if owned and auditOwnedBackup then
        table.clear(owned)
        for key, value in pairs(auditOwnedBackup) do
            owned[key] = value
        end
    end

    if auditMatchedTrack and Settings.Audit.StopTestAnimation then
        pcall(function()
            auditMatchedTrack:Stop(0.1)
        end)
    end

    auditOwnedBackup = nil
    auditSpoofedId = nil
    auditMatchedTrack = nil

    if type(_G.UpdateEmotes) == "function" then
        pcall(_G.UpdateEmotes)
    end
end

local function applyLocalOwnershipSpoof(id)
    if not isStudioAuditAllowed() then
        return false, "Audit disabled: public server testing is blocked."
    end

    local owned = getOwnedTable()
    if not owned then
        return false, "ProfileData.Emotes.Owned is unavailable."
    end

    if ownedTableContains(owned, id) then
        return false, "That emote is already owned; choose a locked emote."
    end

    restoreAuditOwnership()

    owned = getOwnedTable()
    if not owned then
        return false, "Owned table disappeared during refresh."
    end

    auditOwnedBackup = shallowCopyTable(owned)
    auditSpoofedId = id

    -- The inspected MM2 client iterates the Owned array directly, so append
    -- the test id in the same shape rather than replacing the table reference.
    table.insert(owned, id)

    if type(_G.UpdateEmotes) == "function" then
        pcall(_G.UpdateEmotes)
    end

    return ownedTableContains(owned, id),
        "Local replicated ownership table now contains " .. tostring(id)
end

local function animationIdNumber(value)
    if value == nil then
        return nil
    end

    local text = tostring(value)
    return tonumber(text:match("(%d+)$"))
end

local function findMatchingPlayingTrack(animationId)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

    if not animator then
        return nil
    end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animation = track.Animation
        local currentId = animation and animationIdNumber(animation.AnimationId)

        if currentId == animationId then
            return track
        end
    end

    return nil
end

local function runStudioSpoofPlaybackAudit(id)
    if not isStudioAuditAllowed() then
        return false, "Audit disabled: public server testing is blocked."
    end

    if not id or id == "" then
        return false, "Select an emote first."
    end

    local info = getEmoteInfo(id)
    if not info then
        return false, "Selected emote is not in Database.Sync."
    end

    if canPlayOwnedEmote(id) then
        return false, "Choose a locked/unowned emote so the entitlement gate is actually tested."
    end

    local animationId = tonumber(info.AnimationID or info.AnimationId)
    if not animationId then
        return false, "Selected emote has no AnimationID to observe."
    end

    local spoofOk, spoofMessage = applyLocalOwnershipSpoof(id)
    if not spoofOk then
        return false, spoofMessage
    end

    local ownedAfterSpoof = canPlayOwnedEmote(id)

    -- This export exposes Misc.PlayEmote as a BindableEvent. Fire the same
    -- in-client route used by the normal game-emote UI, for Studio-only entitlement testing.
    local fired = false

    if PlayEmoteRemote and PlayEmoteRemote:IsA("BindableEvent") then
        fired = pcall(function()
            PlayEmoteRemote:Fire(id)
        end)
    else
        restoreAuditOwnership()
        return false, "Expected MM2 PlayEmote BindableEvent was not found."
    end

    if not fired then
        restoreAuditOwnership()
        return false, "PlayEmote BindableEvent failed during test."
    end

    task.wait(0.35)

    auditMatchedTrack = findMatchingPlayingTrack(animationId)
    local animationStarted = auditMatchedTrack ~= nil

    local result =
        "Spoof table: " .. (ownedAfterSpoof and "ACCEPTED" or "FAILED")
        .. " • PlayEmote fired: YES"
        .. " • Matching animation: " .. (animationStarted and "STARTED" or "NOT SEEN")

    if Settings.Audit.AutoRestore then
        task.delay(0.75, function()
            if auditSpoofedId == id then
                restoreAuditOwnership()
            end
        end)
    end

    return animationStarted, result
end

-- ============================================================================
-- PuckUI
-- ============================================================================

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV Hub · Murder Mystery 2",
    GuiName = "RAINZXDEV_MM2",
    ConfigId = "MurderMystery2",
    Width = 520,
    Height = 570,
})

local ESPTab = Window:CreateTab("ESP")
local CamTab = Window:CreateTab("Murder Cam")
local EmotesTab = Window:CreateTab("Emotes")
local PlayerTab = Window:CreateTab("Player")
local SettingsTab = Window:CreateTab("Settings")

ESPTab:CreateSection("Role ESP")

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Settings.ESP.Enabled,
    Callback = function(value)
        Settings.ESP.Enabled = value
    end,
})

ESPTab:CreateToggle({
    Name = "Role Highlights",
    CurrentValue = Settings.ESP.Highlights,
    Callback = function(value)
        Settings.ESP.Highlights = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = Settings.ESP.Names,
    Callback = function(value)
        Settings.ESP.Names = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show Roles",
    CurrentValue = Settings.ESP.Roles,
    Callback = function(value)
        Settings.ESP.Roles = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = Settings.ESP.Distance,
    Callback = function(value)
        Settings.ESP.Distance = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show Dead Players",
    CurrentValue = Settings.ESP.ShowDead,
    Callback = function(value)
        Settings.ESP.ShowDead = value
    end,
})

ESPTab:CreateSlider({
    Name = "ESP Max Distance",
    Range = {100, 3000},
    Increment = 50,
    CurrentValue = Settings.ESP.MaxDistance,
    Suffix = " studs",
    Callback = function(value)
        Settings.ESP.MaxDistance = value
    end,
})

ESPTab:CreateSlider({
    Name = "Highlight Transparency",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = math.floor(Settings.ESP.FillTransparency * 100 + 0.5),
    Suffix = "%",
    Callback = function(value)
        Settings.ESP.FillTransparency = math.clamp(value / 100, 0, 1)
    end,
})

ESPTab:CreateSection("Role Backend")

local BackendLabel = ESPTab:CreateLabel(
    type(currentRoundClient) == "table"
        and "Backend • CurrentRoundClient"
        or (GetCurrentPlayerData and "Backend • GetCurrentPlayerData fallback" or "Backend • weapon fallback")
)

local LocalRoleLabel = ESPTab:CreateLabel("Your role • " .. tostring(getPlayerRole(LocalPlayer)))
ESPTab:CreateLabel("Classic: Murderer red · Sheriff blue · Innocent green · Hero cyan")
ESPTab:CreateLabel("Special MM2 modes use their live server role names automatically.")

CamTab:CreateSection("Murderer Cam")

CamTab:CreateToggle({
    Name = "Enable Murderer Cam",
    CurrentValue = Settings.MurderCam.Enabled,
    Callback = function(value)
        Settings.MurderCam.Enabled = value
        if not value then
            MurderFrame.Visible = false
        end
    end,
})

CamTab:CreateDropdown({
    Name = "Camera View",
    Options = {"Shoulder", "Behind", "Front", "Top Down", "Orbit"},
    CurrentOption = {Settings.MurderCam.View},
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        Settings.MurderCam.View = value or "Shoulder"
    end,
})

CamTab:CreateSlider({
    Name = "Window Width",
    Range = {220, 500},
    Increment = 10,
    CurrentValue = Settings.MurderCam.Width,
    Suffix = " px",
    Callback = function(value)
        Settings.MurderCam.Width = value
        MurderFrame.Size = UDim2.fromOffset(Settings.MurderCam.Width, Settings.MurderCam.Height)
    end,
})

CamTab:CreateSlider({
    Name = "Window Height",
    Range = {150, 350},
    Increment = 10,
    CurrentValue = Settings.MurderCam.Height,
    Suffix = " px",
    Callback = function(value)
        Settings.MurderCam.Height = value
        MurderFrame.Size = UDim2.fromOffset(Settings.MurderCam.Width, Settings.MurderCam.Height)
    end,
})

CamTab:CreateSlider({
    Name = "Viewport FPS",
    Range = {10, 60},
    Increment = 5,
    CurrentValue = Settings.MurderCam.FPS,
    Callback = function(value)
        Settings.MurderCam.FPS = value
    end,
})

CamTab:CreateSection("Surroundings")

CamTab:CreateToggle({
    Name = "Show Nearby Map",
    CurrentValue = Settings.MurderCam.ShowSurroundings,
    Callback = function(value)
        Settings.MurderCam.ShowSurroundings = value
        if not value then
            clearEnvironment()
            lastEnvironmentCenter = nil
        else
            lastEnvironmentSync = 0
            lastEnvironmentCenter = nil
        end
    end,
})

CamTab:CreateToggle({
    Name = "Show Nearby Players",
    CurrentValue = Settings.MurderCam.ShowNearbyPlayers,
    Callback = function(value)
        Settings.MurderCam.ShowNearbyPlayers = value
    end,
})

CamTab:CreateSlider({
    Name = "Environment Radius",
    Range = {20, 140},
    Increment = 5,
    CurrentValue = Settings.MurderCam.EnvironmentRadius,
    Suffix = " studs",
    Callback = function(value)
        Settings.MurderCam.EnvironmentRadius = value
        lastEnvironmentSync = 0
        lastEnvironmentCenter = nil
    end,
})

CamTab:CreateSlider({
    Name = "Environment Detail",
    Range = {100, 800},
    Increment = 50,
    CurrentValue = Settings.MurderCam.MaxEnvironmentParts,
    Suffix = " parts",
    Callback = function(value)
        Settings.MurderCam.MaxEnvironmentParts = value
        lastEnvironmentSync = 0
        lastEnvironmentCenter = nil
    end,
})

CamTab:CreateSlider({
    Name = "Map Refresh Rate",
    Range = {35, 200},
    Increment = 5,
    CurrentValue = math.floor(Settings.MurderCam.EnvironmentRefresh * 100 + 0.5),
    Suffix = " /100s",
    Callback = function(value)
        Settings.MurderCam.EnvironmentRefresh = math.clamp(value / 100, 0.35, 2)
    end,
})

CamTab:CreateSection("Free Look")

CamTab:CreateSlider({
    Name = "Orbit Distance",
    Range = {4, 30},
    Increment = 1,
    CurrentValue = Settings.MurderCam.OrbitDistance,
    Suffix = " studs",
    Callback = function(value)
        Settings.MurderCam.OrbitDistance = value
    end,
})

CamTab:CreateButton({
    Name = "Reset Orbit",
    Callback = function()
        Settings.MurderCam.View = "Orbit"
        Settings.MurderCam.OrbitYaw = 25
        Settings.MurderCam.OrbitPitch = -10
        Settings.MurderCam.OrbitDistance = 11
    end,
})

CamTab:CreateLabel("Drag inside the Murderer Cam to freely look around them.")
CamTab:CreateLabel("Performance defaults: 20 FPS · 50 studs · 160 map parts · throttled players.")

CamTab:CreateParagraph({
    Title = "How it works",
    Content = "MM2 does not replicate another player's real camera. This viewport reconstructs the Murderer, nearby map geometry and nearby players locally. Drag inside it to orbit/free-look around the Murderer.",
    Height = 72,
})

local initialEmoteOptions = buildEmoteOptions()

EmotesTab:CreateSection("Emote Browser")

local EmoteStatus = EmotesTab:CreateLabel("Owned emotes can play normally · locked emotes are preview-only")

local EmoteDropdown = EmotesTab:CreateDropdown({
    Name = "Selected Emote",
    Options = initialEmoteOptions,
    CurrentOption = {initialEmoteOptions[1]},
    MaxVisible = 10,
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        local id = emoteOptionToId[value]
        if id then
            selectedEmoteId = id
            Settings.Emotes.Selected = id

            local info = getEmoteInfo(id)

            if info then
                EmoteStatus:Set(tostring(info.Name or id))
            end
        end
    end,
})

EmotesTab:CreateButton({
    Name = "Refresh Emotes / Ownership",
    Callback = function()
        profileData = safeRequire(ProfileDataModule) or profileData
        refreshProfileData()

        local options = buildEmoteOptions()
        EmoteDropdown:Refresh(options)

        PuckUI:Notify({
            Title = "MM2 Emotes",
            Content = "Emote catalog and ownership refreshed.",
            Duration = 2,
        })
    end,
})

EmotesTab:CreateButton({
    Name = "Play Selected",
    Callback = function()
        local ok, err = playOwnedEmote(selectedEmoteId)

        if not ok then
            PuckUI:Notify({
                Title = "MM2 Emotes",
                Content = tostring(err),
                Duration = 2.5,
            })
        end
    end,
})



EmotesTab:CreateSection("Safety / Ownership")
EmotesTab:CreateLabel("Locked paid emotes are never sent to MM2's PlayEmote remote.")
EmotesTab:CreateLabel("Preview uses a local dummy avatar inside the preview window.")

PlayerTab:CreateSection("Player Selection")

local selectedPlayerName = ""
local PlayerDropdown = nil

local function getPlayerOptions()
    local options = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(options, player.Name)
        end
    end

    table.sort(options, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    if #options == 0 then
        return {"No players"}
    end

    return options
end

local function resolveSelectedPlayer()
    if selectedPlayerName == "" or selectedPlayerName == "No players" then
        return nil
    end

    local exact = Players:FindFirstChild(selectedPlayerName)
    if exact and exact:IsA("Player") then
        return exact
    end

    local wanted = string.lower(selectedPlayerName)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and (
                string.lower(player.Name) == wanted
                or string.lower(player.DisplayName) == wanted
            ) then
            return player
        end
    end

    return nil
end

local initialPlayerOptions = getPlayerOptions()
if initialPlayerOptions[1] ~= "No players" then
    selectedPlayerName = initialPlayerOptions[1]
end

PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "Selected Player",
    Options = initialPlayerOptions,
    CurrentOption = {initialPlayerOptions[1]},
    MaxVisible = 10,
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option

        if value and value ~= "No players" then
            selectedPlayerName = tostring(value)
        end
    end,
})

PlayerTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local options = getPlayerOptions()

        if PlayerDropdown and PlayerDropdown.Refresh then
            PlayerDropdown:Refresh(options)
        end

        if options[1] ~= "No players"
            and not Players:FindFirstChild(selectedPlayerName) then

            selectedPlayerName = options[1]

            if PlayerDropdown and PlayerDropdown.Set then
                PlayerDropdown:Set(selectedPlayerName)
            end
        elseif options[1] == "No players" then
            selectedPlayerName = ""
        end

        PuckUI:Notify({
            Title = "Player",
            Content = "Player list refreshed.",
            Duration = 2,
        })
    end,
})

PlayerTab:CreateInput({
    Name = "Player Name Override",
    CurrentValue = "",
    PlaceholderText = "Username or display name",
    Callback = function(value)
        local text = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")

        if text ~= "" then
            selectedPlayerName = text
        end
    end,
})

PlayerTab:CreateSection("Role Targets")

local function findRolePlayerIncludingLocal(role)
    for _, player in ipairs(Players:GetPlayers()) do
        if not playerIsDead(player) and getPlayerRole(player) == role then
            return player
        end
    end
    return nil
end

local function getSheriffOrHero()
    return findRolePlayerIncludingLocal("Sheriff")
        or findRolePlayerIncludingLocal("Hero")
        or findRolePlayerIncludingLocal("Sheriff/Hero")
end

local function getRoleTargetName(player, fallback)
    if not player then
        return tostring(fallback or "None") .. " • none"
    end

    local role = getPlayerRole(player)
    local display = tostring(player.DisplayName or player.Name)

    if player == LocalPlayer then
        display = display .. " (YOU)"
    end

    return tostring(fallback or role) .. " • " .. display .. " [" .. tostring(role) .. "]"
end

local MurdererTargetLabel = PlayerTab:CreateLabel(
    getRoleTargetName(getMurderer(), "Murderer")
)

local SheriffTargetLabel = PlayerTab:CreateLabel(
    getRoleTargetName(getSheriffOrHero(), "Sheriff / Hero")
)

local function refreshRoleTargetLabels()
    local murderer = getMurderer()
    local sheriff = getSheriffOrHero()

    if MurdererTargetLabel and MurdererTargetLabel.Set then
        MurdererTargetLabel:Set(getRoleTargetName(murderer, "Murderer"))
    end

    if SheriffTargetLabel and SheriffTargetLabel.Set then
        SheriffTargetLabel:Set(getRoleTargetName(sheriff, "Sheriff / Hero"))
    end
end

PlayerTab:CreateButton({
    Name = "Refresh Role Targets",
    Callback = function()
        discoverLoadedMM2Tables()
        refreshRoleCache()
        refreshRoleTargetLabels()

        PuckUI:Notify({
            Title = "Role Targets",
            Content = "Murderer / Sheriff targets refreshed.",
            Duration = 2,
        })
    end,
})

-- ============================================================================
-- Exact Infinite Yield fling core
-- ============================================================================

local iyFlinging = false
local iyFlingDied = nil
local iyBambam = nil
local iyNoclipping = nil
local iyNoclipParts = {}
local iyTargetHelperBusy = false

local function iyGetRoot(character)
    if character and character:FindFirstChildOfClass("Humanoid") then
        return character:FindFirstChildOfClass("Humanoid").RootPart
    end
    return nil
end

local function iyStartNoclip()
    pcall(function()
        if iyNoclipping then
            iyNoclipping:Disconnect()
        end
    end)

    task.wait(0.1)
    iyNoclipParts = {}

    iyNoclipping = RunService.Stepped:Connect(function()
        if LocalPlayer.Character ~= nil then
            for _, child in pairs(LocalPlayer.Character:GetDescendants()) do
                if child:IsA("BasePart") and child.CanCollide == true then
                    child.CanCollide = false
                    iyNoclipParts[child] = true
                end
            end
        end
    end)
end

local function iyStopNoclip()
    pcall(function()
        if iyNoclipping then
            iyNoclipping:Disconnect()
        end
    end)

    iyNoclipping = nil
    task.wait(0.1)

    -- Infinite Yield sets the parts it noclipped back to collidable.
    for child, _ in pairs(iyNoclipParts) do
        if typeof(child) == "Instance"
            and child:IsA("BasePart")
            and child.Parent then
            child.CanCollide = true
        end
    end

    iyNoclipParts = {}
end

local function stopExactIYFling()
    iyFlinging = false

    iyStopNoclip()

    if iyFlingDied then
        pcall(function()
            iyFlingDied:Disconnect()
        end)
        iyFlingDied = nil
    end

    task.wait(0.1)

    local speakerChar = LocalPlayer.Character
    local root = iyGetRoot(speakerChar)

    if not speakerChar or not root then
        iyBambam = nil
        return
    end

    -- Exact Infinite Yield unfling reset values.
    for _, v in next, speakerChar:GetDescendants() do
        if v:IsA("BasePart") then
            v.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
            v.Massless = false
            v.Velocity = Vector3.zero
        elseif v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end

    iyBambam = nil
end

local function startExactIYFling()
    -- Mirror Infinite Yield: calling fling first clears its state.
    iyFlinging = false

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = iyGetRoot(character)

    if not character or not humanoid or not root then
        return false, "Character is not ready."
    end

    -- Exact IY physical-property setup.
    for _, child in next, character:GetDescendants() do
        if child:IsA("BasePart") then
            child.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
        end
    end

    -- Exact IY noclip sequence.
    iyStartNoclip()

    task.wait(0.1)

    -- Exact IY BodyAngularVelocity settings.
    local bambam = Instance.new("BodyAngularVelocity")
    bambam.Name = "RAINZXDEV_ExactIYFling"
    bambam.Parent = root
    bambam.AngularVelocity = Vector3.new(0, 99999, 0)
    bambam.MaxTorque = Vector3.new(0, math.huge, 0)
    bambam.P = math.huge
    iyBambam = bambam

    -- Exact IY only iterates direct character children here.
    for _, v in next, character:GetChildren() do
        if v:IsA("BasePart") then
            v.Massless = true
            v.Velocity = Vector3.zero
        end
    end

    iyFlinging = true

    iyFlingDied = humanoid.Died:Connect(function()
        task.spawn(stopExactIYFling)
    end)

    -- Exact Infinite Yield pulse loop:
    -- 99999 for .2 sec, zero for .1 sec, repeat until disabled.
    task.spawn(function()
        while iyFlinging
            and bambam
            and bambam.Parent
            and not destroyed do

            bambam.AngularVelocity = Vector3.new(0, 99999, 0)
            task.wait(0.2)

            if not iyFlinging or not bambam.Parent then
                break
            end

            bambam.AngularVelocity = Vector3.new(0, 0, 0)
            task.wait(0.1)
        end
    end)

    return true
end

local function getAliveRoot(player)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart

    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return nil, nil, nil
    end

    return character, humanoid, root
end

local function touchTargetWithExactIY(player, label)
    if iyTargetHelperBusy then
        PuckUI:Notify({
            Title = "Fling",
            Content = "A target helper is already running.",
            Duration = 2,
        })
        return
    end

    local _, _, targetRoot = getAliveRoot(player)
    local _, _, localRoot = getAliveRoot(LocalPlayer)

    if not targetRoot or not localRoot or player == LocalPlayer then
        PuckUI:Notify({
            Title = "Fling",
            Content = tostring(label or "Target") .. " is unavailable.",
            Duration = 2,
        })
        return
    end

    iyTargetHelperBusy = true

    task.spawn(function()
        local wasAlreadyFlinging = iyFlinging

        if not iyFlinging then
            local ok, err = startExactIYFling()
            if not ok then
                iyTargetHelperBusy = false

                PuckUI:Notify({
                    Title = "Fling",
                    Content = tostring(err),
                    Duration = 2,
                })
                return
            end
        end

        local started = os.clock()
        local attachDuration = 1.45
        local phase = 0

        -- Stay attached to the selected player for the actual fling window.
        -- The IY spin itself is left unchanged; this only follows the target.
        while not destroyed
            and iyFlinging
            and player.Parent == Players
            and os.clock() - started < attachDuration do

            local _, _, liveTargetRoot = getAliveRoot(player)
            local _, _, liveLocalRoot = getAliveRoot(LocalPlayer)

            if not liveTargetRoot or not liveLocalRoot then
                break
            end

            phase += 1

            local targetVelocity = liveTargetRoot.AssemblyLinearVelocity
            local lead = Vector3.new(
                targetVelocity.X,
                math.clamp(targetVelocity.Y, -25, 25),
                targetVelocity.Z
            ) * 0.018

            -- Alternate through tiny offsets so our spinning assembly overlaps
            -- the target's body instead of sitting at one mathematically exact
            -- root point while they move.
            local radius = 0.28
            local angle = phase * 1.9
            local offset = Vector3.new(
                math.cos(angle) * radius,
                ((phase % 5) - 2) * 0.08,
                math.sin(angle) * radius
            )

            liveLocalRoot.CFrame = CFrame.new(
                liveTargetRoot.Position + lead + offset
            )

            -- Keep our velocity from carrying us away between IY pulse changes.
            liveLocalRoot.AssemblyLinearVelocity = Vector3.zero

            RunService.Stepped:Wait()
        end

        -- If the helper started IY fling, stop it after the attach window.
        -- If the user manually enabled Exact IY Fling, leave it on.
        if not wasAlreadyFlinging then
            stopExactIYFling()
        end

        iyTargetHelperBusy = false
    end)
end

PlayerTab:CreateSection("Infinite Yield Fling")

local ExactIYFlingToggle = PlayerTab:CreateToggle({
    Name = "Exact IY Fling (Touch Players)",
    CurrentValue = false,
    Callback = function(value)
        if value then
            local ok, err = startExactIYFling()

            if not ok then
                if ExactIYFlingToggle and ExactIYFlingToggle.Set then
                    ExactIYFlingToggle:Set(false)
                end

                PuckUI:Notify({
                    Title = "Exact IY Fling",
                    Content = tostring(err),
                    Duration = 2,
                })
            end
        else
            task.spawn(stopExactIYFling)
        end
    end,
})

PlayerTab:CreateLabel("This mode mirrors Infinite Yield's actual fling: walk/touch another player while enabled.")
PlayerTab:CreateLabel("Target buttons now follow/attach to the moving player for ~1.45s while IY fling is active.")

PlayerTab:CreateButton({
    Name = "Fling Murderer",
    Callback = function()
        local target = getMurderer()

        if target == LocalPlayer then
            PuckUI:Notify({
                Title = "Fling",
                Content = "You are the Murderer, so there is no remote Murderer target.",
                Duration = 2,
            })
            return
        end

        touchTargetWithExactIY(target, "Murderer")
    end,
})

PlayerTab:CreateButton({
    Name = "Fling Sheriff / Hero",
    Callback = function()
        local target = getSheriffOrHero()

        if target == LocalPlayer then
            PuckUI:Notify({
                Title = "Fling",
                Content = "You are the Sheriff/Hero, so there is no remote Sheriff target.",
                Duration = 2,
            })
            return
        end

        touchTargetWithExactIY(target, "Sheriff / Hero")
    end,
})

PlayerTab:CreateButton({
    Name = "Fling Selected Player",
    Callback = function()
        local target = resolveSelectedPlayer()

        if not target then
            PuckUI:Notify({
                Title = "Fling",
                Content = "Selected player was not found.",
                Duration = 2,
            })
            return
        end

        touchTargetWithExactIY(target, target.Name)
    end,
})

PlayerTab:CreateButton({
    Name = "Stop Exact IY Fling",
    Callback = function()
        task.spawn(stopExactIYFling)

        if ExactIYFlingToggle and ExactIYFlingToggle.Set then
            ExactIYFlingToggle:Set(false)
        end
    end,
})

PlayerTab:CreateSection("Physics Protection")

local antiFlingEnabled = false
local antiFlingConnection = nil
local antiFlingCollisionBackup = setmetatable({}, {__mode = "k"})

local function stopAntiFling()
    antiFlingEnabled = false

    if antiFlingConnection then
        antiFlingConnection:Disconnect()
        antiFlingConnection = nil
    end

    for part, original in pairs(antiFlingCollisionBackup) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
        antiFlingCollisionBackup[part] = nil
    end
end

local function startAntiFling()
    stopAntiFling()
    antiFlingEnabled = true

    -- Same defensive principle as Infinite Yield: player-to-player fling
    -- depends on collision contact, so disable OTHER players' local collision.
    antiFlingConnection = RunService.Stepped:Connect(function()
        if not antiFlingEnabled then
            return
        end

        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= LocalPlayer and other.Character then
                for _, part in ipairs(other.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if antiFlingCollisionBackup[part] == nil then
                            antiFlingCollisionBackup[part] = part.CanCollide
                        end
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

PlayerTab:CreateToggle({
    Name = "Anti Fling",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startAntiFling()
        else
            stopAntiFling()
        end
    end,
})

PlayerTab:CreateLabel("Anti Fling uses Infinite Yield's collision-disable approach.")


-- ============================================================================
-- Sheriff / Hero auto shoot
-- Isolated in its own function scope to avoid Luau's main-chunk local limit.
-- ============================================================================

local function installSheriffAutoShoot()
    PlayerTab:CreateSection("Sheriff Auto Shoot")

    local autoShootBusy = false
    local sheriffShootAttempts = 4

    local SheriffShootStatus = PlayerTab:CreateLabel("Auto Shoot • V • ready")

    local function setStatus(text)
        if SheriffShootStatus and SheriffShootStatus.Set then
            SheriffShootStatus:Set("Auto Shoot • V • " .. tostring(text))
        end
    end

    local function getGunTool()
        local character = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

        local function scan(container)
            if not container then
                return nil
            end

            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") then
                    local tagged = false

                    pcall(function()
                        tagged = CollectionService:HasTag(item, "Weapon_Gun")
                    end)

                    local lower = string.lower(item.Name)

                    if tagged
                        or lower == "gun"
                        or lower:find("gun", 1, true) then
                        return item
                    end
                end
            end

            return nil
        end

        return scan(character) or scan(backpack)
    end

    local function localCanShoot()
        local role = getPlayerRole(LocalPlayer)

        -- Allow Sheriff/Hero and civilians/innocents who have picked up the gun.
        -- Never allow the Murderer to use this helper.
        if role == "Murderer" then
            return false, role
        end

        local hasGun = getGunTool() ~= nil

        if role == "Sheriff"
            or role == "Hero"
            or role == "Sheriff/Hero" then
            return true, role
        end

        -- MM2 may expose the ordinary non-murder role using different strings
        -- depending on the round/mode. Possessing the gun is the final authority.
        if hasGun then
            return true, role
        end

        return false, role
    end

    local function equipGun()
        local tool = getGunTool()
        if not tool then
            return nil
        end

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid and tool.Parent ~= character then
            pcall(function()
                humanoid:EquipTool(tool)
            end)

            task.wait(0.08)
        end

        return tool
    end

    local function getAimPart(player)
        local character = player and player.Character
        if not character then
            return nil
        end

        -- Prefer the largest central body area. Head aiming looked precise but
        -- was much easier to miss when Roblox updated the target/camera between frames.
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("Head")
    end

    local function firstPersonAimAndShoot(murderer)
        local tool = equipGun()

        if not tool then
            return false, "Sheriff gun not found"
        end

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local camera = workspace.CurrentCamera
        local aimPart = getAimPart(murderer)

        if not humanoid or not camera or not aimPart then
            return false, "Murderer target unavailable"
        end

        local oldCameraMode = LocalPlayer.CameraMode
        local oldMinZoom = LocalPlayer.CameraMinZoomDistance
        local oldMaxZoom = LocalPlayer.CameraMaxZoomDistance
        local oldMouseBehavior = UserInputService.MouseBehavior
        local oldCameraType = camera.CameraType
        local oldCameraSubject = camera.CameraSubject

        local aimConnection = nil
        local aimBindName = "RAINZXDEV_MM2_SheriffAim_" .. tostring(math.random(100000, 999999))

        local function stopAimLock()
            pcall(function()
                RunService:UnbindFromRenderStep(aimBindName)
            end)

            if aimConnection then
                pcall(function()
                    aimConnection:Disconnect()
                end)
                aimConnection = nil
            end
        end

        local function restoreCamera()
            stopAimLock()

            pcall(function()
                LocalPlayer.CameraMode = oldCameraMode
                LocalPlayer.CameraMinZoomDistance = oldMinZoom
                LocalPlayer.CameraMaxZoomDistance = oldMaxZoom
                UserInputService.MouseBehavior = oldMouseBehavior

                local currentCamera = workspace.CurrentCamera
                if currentCamera then
                    currentCamera.CameraType = oldCameraType
                    currentCamera.CameraSubject = oldCameraSubject or humanoid
                end
            end)
        end

        local success, err = pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 0.5

            camera = workspace.CurrentCamera
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid

            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            end)

            -- Let the built-in CameraModule fully enter first person first.
            for _ = 1, 4 do
                RunService.RenderStepped:Wait()
            end

            -- CameraModule updates around priority 200. Bind after it so our aim
            -- is the final camera CFrame the MM2 gun sees when it reads mouse.Hit.
            RunService:BindToRenderStep(
                aimBindName,
                Enum.RenderPriority.Camera.Value + 50,
                function()
                    if destroyed then
                        return
                    end

                    local currentCamera = workspace.CurrentCamera
                    local currentAimPart = getAimPart(murderer)

                    if not currentCamera or not currentAimPart or not currentAimPart.Parent then
                        return
                    end

                    -- Hitscan: aim at the current torso center, not a predicted point.
                    -- Small vertical lift biases toward the chest while staying in the
                    -- largest part of the character hitbox.
                    local targetPosition = currentAimPart.Position + Vector3.new(0, 0.1, 0)

                    currentCamera.CFrame = CFrame.lookAt(
                        currentCamera.CFrame.Position,
                        targetPosition
                    )
                end
            )

            -- Hold the hard aim lock for several rendered frames so both the Roblox
            -- camera and MM2's gun LocalScript observe the same centered ray.
            for _ = 1, 7 do
                RunService.RenderStepped:Wait()
            end

            -- Activate while the hard-lock render binding is still running.
            tool:Activate()

            -- Keep aim locked through the actual Activated handler / raycast.
            for _ = 1, 4 do
                RunService.RenderStepped:Wait()
            end

            pcall(function()
                tool:Deactivate()
            end)

            task.wait(0.03)
        end)

        restoreCamera()

        if not success then
            return false, tostring(err)
        end

        return true
    end

    local function runSheriffAutoShoot()
        if autoShootBusy then
            return
        end

        autoShootBusy = true

        task.spawn(function()
            local function finish(message)
                setStatus(message)
                autoShootBusy = false
            end

            refreshRoleCache()

            local canShoot, role = localCanShoot()

            if not canShoot then
                finish("blocked • your role is " .. tostring(role))

                PuckUI:Notify({
                    Title = "Sheriff Auto Shoot",
                    Content = "V works for Sheriff/Hero or a civilian who currently has the Sheriff gun.",
                    Duration = 2,
                })
                return
            end

            local murderer = getMurderer()

            if not murderer
                or murderer == LocalPlayer
                or playerIsDead(murderer) then

                finish("no live Murderer")
                return
            end

            if not getGunTool() then
                finish("no gun")

                PuckUI:Notify({
                    Title = "Sheriff Auto Shoot",
                    Content = "No Sheriff gun was found. Civilians must pick up the dropped gun first.",
                    Duration = 2,
                })
                return
            end

            for attempt = 1, sheriffShootAttempts do
                refreshRoleCache()

                if playerIsDead(murderer)
                    or getPlayerRole(murderer) ~= "Murderer" then

                    finish("Murderer eliminated")
                    return
                end

                setStatus("hard-lock aim • shot " .. tostring(attempt))

                local fired, fireError = firstPersonAimAndShoot(murderer)

                if not fired then
                    finish("failed • " .. tostring(fireError))
                    return
                end

                task.wait(1.30)
            end

            refreshRoleCache()

            if playerIsDead(murderer)
                or getPlayerRole(murderer) ~= "Murderer" then
                finish("Murderer eliminated")
            else
                finish("shots complete")
            end
        end)
    end

    PlayerTab:CreateButton({
        Name = "Shoot Murderer [V] (Sheriff/Civilian)",
        Callback = runSheriffAutoShoot,
    })

    PlayerTab:CreateLabel(
        "Press V: hard-lock first-person aim to the Murderer torso, then fire while the lock is active."
    )

    addConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == Enum.KeyCode.V then
            runSheriffAutoShoot()
        end
    end))
end

installSheriffAutoShoot()

PlayerTab:CreateSection("Sheriff Gun")

local autoTPDroppedGun = false
local lastGunTeleportAt = 0

local function isInsideAnyCharacter(instance)
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and instance:IsDescendantOf(character) then
            return true
        end
    end
    return false
end

local function gunCandidateRoot(instance)
    if not instance or not instance:IsDescendantOf(workspace) then
        return nil
    end

    if isInsideAnyCharacter(instance) then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    elseif instance:IsA("Tool") then
        return instance:FindFirstChild("Handle")
            or instance:FindFirstChildWhichIsA("BasePart", true)
    elseif instance:IsA("Model") then
        return instance.PrimaryPart
            or instance:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function droppedGunScore(instance)
    local name = string.lower(instance.Name or "")
    local score = 0

    if name == "gundrop" then
        score += 100
    elseif name == "droppedgun" or name == "sheriffgun" then
        score += 90
    elseif name:find("gundrop", 1, true) then
        score += 80
    elseif name:find("dropped", 1, true) and name:find("gun", 1, true) then
        score += 70
    elseif name == "gun" then
        score += 45
    elseif name:find("gun", 1, true) then
        score += 20
    else
        return -math.huge
    end

    if instance:IsA("Tool") then
        score += 15
    end

    if instance:FindFirstChildOfClass("TouchTransmitter") then
        score += 20
    end

    if instance:FindFirstChildWhichIsA("ProximityPrompt", true) then
        score += 10
    end

    return score
end

local function findDroppedSheriffGun()
    local localCharacter, _, localRoot = getAliveRoot(LocalPlayer)
    if not localRoot then
        return nil, nil
    end

    -- Real MM2 commonly uses workspace.GunDrop. Check this cheaply first.
    local direct = workspace:FindFirstChild("GunDrop")
        or workspace:FindFirstChild("DroppedGun")
        or workspace:FindFirstChild("SheriffGun")

    if direct then
        local directRoot = gunCandidateRoot(direct)
        if directRoot then
            return direct, directRoot
        end
    end

    local bestInstance = nil
    local bestRoot = nil
    local bestScore = -math.huge
    local bestDistance = math.huge

    for _, instance in ipairs(workspace:GetDescendants()) do
        local score = droppedGunScore(instance)

        if score > -math.huge then
            local root = gunCandidateRoot(instance)

            if root then
                local distance = (root.Position - localRoot.Position).Magnitude

                if score > bestScore
                    or (score == bestScore and distance < bestDistance) then

                    bestScore = score
                    bestDistance = distance
                    bestInstance = instance
                    bestRoot = root
                end
            end
        end
    end

    -- Avoid teleporting to weak map-decoration matches.
    if bestScore < 45 then
        return nil, nil
    end

    return bestInstance, bestRoot
end

local function teleportToDroppedSheriffGun(silent)
    if os.clock() - lastGunTeleportAt < 0.6 then
        return false
    end

    local _, gunRoot = findDroppedSheriffGun()
    local _, humanoid, localRoot = getAliveRoot(LocalPlayer)

    if not gunRoot or not localRoot then
        if not silent then
            PuckUI:Notify({
                Title = "Sheriff Gun",
                Content = "No dropped Sheriff gun found yet.",
                Duration = 2,
            })
        end
        return false
    end

    lastGunTeleportAt = os.clock()

    if humanoid then
        humanoid.Sit = false
    end

    localRoot.AssemblyLinearVelocity = Vector3.zero
    localRoot.AssemblyAngularVelocity = Vector3.zero
    localRoot.CFrame = gunRoot.CFrame * CFrame.new(0, 2.5, 0)

    if not silent then
        PuckUI:Notify({
            Title = "Sheriff Gun",
            Content = "Teleported to the dropped gun.",
            Duration = 2,
        })
    end

    return true
end

PlayerTab:CreateButton({
    Name = "TP to Dropped Sheriff Gun",
    Callback = function()
        teleportToDroppedSheriffGun(false)
    end,
})

PlayerTab:CreateToggle({
    Name = "Auto TP When Gun Drops",
    CurrentValue = false,
    Callback = function(value)
        autoTPDroppedGun = value == true

        if autoTPDroppedGun then
            task.defer(function()
                teleportToDroppedSheriffGun(true)
            end)
        end
    end,
})

addConnection(workspace.DescendantAdded:Connect(function(instance)
    if not autoTPDroppedGun then
        return
    end

    if droppedGunScore(instance) < 45 then
        return
    end

    task.delay(0.12, function()
        if not destroyed and autoTPDroppedGun then
            teleportToDroppedSheriffGun(true)
        end
    end)
end))

PlayerTab:CreateSection("Movement")

local flyingEnabled = false
local flySpeed = 50
local flyConnection = nil
local flyBodyVelocity = nil

local noclipEnabled = false
local noclipConnection = nil
local noclipOriginal = setmetatable({}, {__mode = "k"})

local function disconnectFly()
    flyingEnabled = false

    if flyConnection then
        pcall(function()
            flyConnection:Disconnect()
        end)
        flyConnection = nil
    end

    if flyBodyVelocity then
        pcall(function()
            flyBodyVelocity:Destroy()
        end)
        flyBodyVelocity = nil
    end
end

local function startFly()
    disconnectFly()
    flyingEnabled = true

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        flyingEnabled = false
        PuckUI:Notify({
            Title = "Movement",
            Content = "Character/root not ready.",
            Duration = 2,
        })
        return false
    end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "RAINZXDEV_MM2_FlyVelocity"
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.P = 1250
    bodyVelocity.Parent = root
    flyBodyVelocity = bodyVelocity

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyingEnabled then
            return
        end

        local currentCharacter = LocalPlayer.Character
        local currentRoot = currentCharacter
            and currentCharacter:FindFirstChild("HumanoidRootPart")

        if not currentRoot
            or not flyBodyVelocity
            or flyBodyVelocity.Parent ~= currentRoot then

            disconnectFly()
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then
            flyBodyVelocity.Velocity = Vector3.zero
            return
        end

        local look = Vector3.new(
            camera.CFrame.LookVector.X,
            0,
            camera.CFrame.LookVector.Z
        )

        local right = Vector3.new(
            camera.CFrame.RightVector.X,
            0,
            camera.CFrame.RightVector.Z
        )

        if look.Magnitude > 0.001 then
            look = look.Unit
        else
            look = Vector3.new(0, 0, -1)
        end

        if right.Magnitude > 0.001 then
            right = right.Unit
        else
            right = Vector3.new(1, 0, 0)
        end

        local moveDirection = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection += look
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection -= look
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection -= right
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection += right
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection += Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection -= Vector3.new(0, 1, 0)
        end

        if moveDirection.Magnitude > 0.001 then
            moveDirection = moveDirection.Unit
        end

        flyBodyVelocity.Velocity = moveDirection * flySpeed
    end)

    return true
end

local FlyToggle = PlayerTab:CreateToggle({
    Name = "Flying",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startFly()
        else
            disconnectFly()
        end
    end,
})

PlayerTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    CurrentValue = flySpeed,
    Callback = function(value)
        flySpeed = tonumber(value) or 50
    end,
})

local function restoreNoclip()
    noclipEnabled = false

    if noclipConnection then
        pcall(function()
            noclipConnection:Disconnect()
        end)
        noclipConnection = nil
    end

    for part, oldCanCollide in pairs(noclipOriginal) do
        if part and part.Parent and part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = oldCanCollide
            end)
        end
        noclipOriginal[part] = nil
    end
end

local function startNoclip()
    restoreNoclip()
    noclipEnabled = true

    noclipConnection = RunService.Stepped:Connect(function()
        if not noclipEnabled then
            return
        end

        local character = LocalPlayer.Character
        if not character then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipOriginal[part] == nil then
                    noclipOriginal[part] = part.CanCollide
                end

                part.CanCollide = false
            end
        end
    end)
end

local NoclipToggle = PlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startNoclip()
        else
            restoreNoclip()
        end
    end,
})

PlayerTab:CreateLabel("Fly: W/A/S/D · Space up · Ctrl/Shift down")

addConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.35)

    if flyingEnabled then
        if FlyToggle and FlyToggle.Set then
            FlyToggle:Set(false)
        else
            disconnectFly()
        end
    end

    if noclipEnabled then
        restoreNoclip()

        if NoclipToggle and NoclipToggle.Set then
            NoclipToggle:Set(false)
        end
    end
end))

SettingsTab:CreateSection("MM2 Backend")

local SettingsBackendLabel = SettingsTab:CreateLabel(
    type(currentRoundClient) == "table"
        and "Role backend • CurrentRoundClient"
        or (GetCurrentPlayerData and "Role backend • Remote fallback" or "Role backend • Weapon fallback")
)

SettingsTab:CreateButton({
    Name = "Refresh Role Data",
    Callback = function()
        discoverLoadedMM2Tables()
        local ok = refreshRoleCache()

        if SettingsBackendLabel and SettingsBackendLabel.Set then
            SettingsBackendLabel:Set(
                type(currentRoundClient) == "table"
                    and "Role backend • CurrentRoundClient"
                    or (GetCurrentPlayerData and "Role backend • Remote fallback" or "Role backend • Weapon fallback")
            )
        end

        if LocalRoleLabel and LocalRoleLabel.Set then
            LocalRoleLabel:Set("Your role • " .. tostring(getPlayerRole(LocalPlayer)))
        end

        PuckUI:Notify({
            Title = "MM2 Role Data",
            Content = ok and "Role data refreshed." or "Using available fallback role detection.",
            Duration = 2,
        })
    end,
})

SettingsTab:CreateButton({
    Name = "Refresh Profile / Emote Data",
    Callback = function()
        discoverLoadedMM2Tables()
        profileData = safeRequire(ProfileDataModule) or profileData
        local ok = refreshProfileData()

        if EmoteDropdown and EmoteDropdown.Refresh then
            local options = buildEmoteOptions()
            EmoteDropdown:Refresh(options)
        end

        PuckUI:Notify({
            Title = "MM2 Profile Data",
            Content = ok and "Profile/emote data refreshed." or "Profile data is currently unavailable.",
            Duration = 2,
        })
    end,
})

SettingsTab:CreateSection("Overlay")

SettingsTab:CreateButton({
    Name = "Reset Overlay Positions",
    Callback = function()
        MurderFrame.Position = UDim2.new(1, -16, 0, 70)
        PreviewFrame.Position = UDim2.new(1, -16, 1, -16)

        PuckUI:Notify({
            Title = "MM2",
            Content = "Overlay positions reset.",
            Duration = 2,
        })
    end,
})

SettingsTab:CreateButton({
    Name = "Hide Murderer Cam",
    Callback = function()
        Settings.MurderCam.Enabled = false
        MurderFrame.Visible = false
    end,
})

SettingsTab:CreateSection("Session")

local cleanup

SettingsTab:CreateButton({
    Name = "Unload MM2",
    Callback = function()
        if cleanup then
            cleanup()
        end
    end,
})

-- ============================================================================
-- Runtime
-- ============================================================================

local roleRefreshAccumulator = 0
local roleTargetAccumulator = 0
local espAccumulator = 0
local murderAccumulator = 0

addConnection(RunService.RenderStepped:Connect(function(dt)
    if destroyed then
        return
    end

    roleRefreshAccumulator = roleRefreshAccumulator + dt
    roleTargetAccumulator = roleTargetAccumulator + dt
    espAccumulator = espAccumulator + dt
    murderAccumulator = murderAccumulator + dt

    if roleRefreshAccumulator >= 0.75 then
        roleRefreshAccumulator = 0
        refreshRoleCache()

        if LocalRoleLabel and LocalRoleLabel.Set then
            LocalRoleLabel:Set("Your role • " .. tostring(getPlayerRole(LocalPlayer)))
        end
    end

    if roleTargetAccumulator >= 0.50 then
        roleTargetAccumulator = 0
        refreshRoleTargetLabels()
    end

    if espAccumulator >= 0.08 then
        espAccumulator = 0

        for _, player in ipairs(Players:GetPlayers()) do
            updatePlayerESP(player)
        end

        for player in pairs(espObjects) do
            if player.Parent ~= Players then
                destroyESP(player)
            end
        end
    end

    local targetFPS = math.max(Settings.MurderCam.FPS, 1)
    if murderAccumulator >= (1 / targetFPS) then
        murderAccumulator = 0
        updateMurderCamera()
    end
end))

addConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end))

addConnection(Players.PlayerRemoving:Connect(function(player)
    destroyESP(player)

    if murderTarget == player then
        clearMurderClone()
    end
end))

-- ============================================================================
-- Cleanup
-- ============================================================================

cleanup = function()
    if destroyed then
        return
    end

    destroyed = true
    autoTPDroppedGun = false

    pcall(disconnectFly)
    pcall(restoreNoclip)
    pcall(stopAntiFling)
    pcall(stopExactIYFling)

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)

    for player in pairs(espObjects) do
        destroyESP(player)
    end

    restoreAuditOwnership()
    clearMurderClone()
    clearEnvironment()
    stopEmotePreview()

    pcall(function()
        ESPWorldFolder:Destroy()
    end)

    pcall(function()
        ESPGui:Destroy()
    end)

    pcall(function()
        OverlayGui:Destroy()
    end)

    pcall(function()
        Window:Destroy()
    end)

    if ENV.__rainzxdev_MM2_CLEANUP == cleanup then
        ENV.__rainzxdev_MM2_CLEANUP = nil
    end
end

ENV.__rainzxdev_MM2_CLEANUP = cleanup

Window:SetCloseCallback(function()
    cleanup()
end)

PuckUI:Notify({
    Title = "Murder Mystery 2",
    Content = "Role ESP + Murderer Cam + Emote Preview loaded [PUBLIC BUILD]",
    Duration = 3,
})

print("[RAINZXDEV Hub · MM2] Role ESP / Murderer Cam / Emotes loaded [PUBLIC BUILD]")
