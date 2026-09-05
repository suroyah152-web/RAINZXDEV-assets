--[[
    RAINZXDEV - Build a Gun Army Autofarm v3.0

    Inspected game architecture:
      - 6 plots, ownership via Plot:GetAttribute("OwnerUserId")
      - Waves via ReplicatedStorage.RemoteEvents.WaveControl("Start")
      - 42 weapon units (7 rarities x 6), 4 tiers:
            Normal x1, Shiny x2, Electric x5, Cosmic x15
      - Weapon roll state is exposed on Plot.WeaponBox.RolledWeapon:
            unitName, unitTier, Cost, DPS, Damage
      - Purchased weapon state is exposed on LocalPlayer:
            PendingWeapon, PendingWeaponTier
      - Placement is performed through the matching unit's WeaponProxPrompt
      - Loot visuals for the local plot are created in workspace.LootSpawnedClient
      - Normal free pickup uses player proximity; this farm uses movement to
        those visuals instead of spoofing the paid AutoLoot entitlement
      - Rebirth uses the normal RebirthButtonPress remote; SkipRebirth and
        Robux force-buy/dev-product paths are deliberately not used
      - Paid gamepass toggles are only enabled when OwnsGP_* is already true

    No gamepass ownership attributes are changed or spoofed.
]]

local ENV = _G

if type(getgenv) == "function" then
    pcall(function()
        local candidate = getgenv()
        if type(candidate) == "table" then
            ENV = candidate
        end
    end)
end

if ENV.__rainzxdev_BUILD_GUN_ARMY_CLEANUP then
    pcall(ENV.__rainzxdev_BUILD_GUN_ARMY_CLEANUP)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager =
        game:GetService("VirtualInputManager")
end)

local LocalPlayer = Players.LocalPlayer

local Runtime = {
    Running = true,
    Connections = {},
    Moving = false,
    LastWave = 0,
    LastWaveStart = 0,
    LastRebirth = 0,
    LastRewardCollect = 0,
    LastWeaponAction = 0,
    LastPassCheck = 0,
    LastStatus = 0,
    LastError = "",
    LastDecision = "waiting",
    LastEconomy = "waiting",
    LastPromptMethod = "none",
    LastPromptResult = "none",
    InteractionState = "Idle",
    InteractionTarget = "none",
    InteractionAttempt = 0,
    InteractionPathStatus = "none",
    InteractionDistance = 0,
    InteractionPromptEnabled = false,

    ActionOwner = nil,
    ActionStartedAt = 0,

    ShownPrompts = setmetatable({}, {__mode = "k"}),

    LastGroupCheck = 0,
    LastOfflineCheck = 0,

    CurrencySample = nil,
    CurrencySampleAt = nil,
    IncomePerSecond = 0,
    TotalObservedIncome = 0,
    IncomeSamples = {},
    LastPositiveIncomeAt = 0,

    RollHoldModel = nil,
    RollHoldSince = 0,

    FastLootSupport = nil,
    FastLootTesting = false,
    FastLootFailures = 0,
    LastFastLootTest = 0,
    LastFastLootBatch = 0,
    FastLootCollected = 0,

    Window = nil,
    Plot = nil,
}

local Settings = {
    Master = false,

    AutoStartWaves = true,
    SmartWeapons = true,
    CollectLoot = true,
    AutoRebirthFailed = true,
    AutoRebirthThreshold = false,
    RebirthWave = 80,
    CollectRewards = true,
    UseOwnedGamepasses = true,
    AntiAFK = true,

    WaitForAffordableUpgrade = true,

    Strategy = "Balanced",
    AutoDuplicateXP = true,
    DuplicateSpendPercent = 18,
    DuplicateStrongWeaponShare = 0.07,
    NearLevelThreshold = 0.72,

    ProtectUnownedRolls = true,
    NewGunBaseHoldSeconds = 75,
    FutureGunReserve = true,
    FutureReservePercent = 70,
    MaxUpgradePaybackSeconds = 90,
    StrategicReserveBreak = true,

    LuckMilestoneHold = true,
    MilestoneHoldWaves = 4,
    BossReserveWaves = 2,

    FastLootAutoDetect = true,
    FastLootBatchSize = 45,

    LootMoveDelay = 0.08,
    MaxLootPerPass = 16,

    TweenMovement = true,
    TweenSpeed = 38,
    TweenMinDuration = 0.10,
    TweenMaxDuration = 1.35,

    GroundFollow = true,
    GroundRayHeight = 70,
    GroundRayDepth = 180,
    GroundClearance = 0.12,
    GroundYSmoothing = 18,

    PromptPathfinding = true,
    PromptRingSamples = 14,
    PromptMinRadius = 2.75,
    PromptMaxRadius = 7.5,
    PromptClearanceRadius = 1.5,
    PromptPathAgentRadius = 1.65,
    PromptPathAgentHeight = 5,

    PromptSettleTime = 0.26,
    PromptInputRetries = 3,
    PromptRetryDelay = 0.18,
    PromptExtraHold = 0.12,
    PromptReadyTimeout = 0.85,
    PromptOutcomeTimeout = 1.20,
    PromptAlternatePositions = 5,
    PromptReleaseBeforeInput = true,

    TweenReturn = true,
    RestorePosition = true,
}

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local function addConnection(connection)
    table.insert(Runtime.Connections, connection)
    return connection
end

local function safeDisconnect(connection)
    pcall(function()
        connection:Disconnect()
    end)
end


local function silentInGameNotice(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "RAINZXDEV"),
            Text = tostring(text or ""),
            Duration = 5,
        })
    end)
end

local function abortBeforeWindow(message)
    ENV.__rainzxdev_BUILD_GUN_ARMY_LAST_ERROR = tostring(message or "Unknown startup error")

    for _, connection in ipairs(Runtime.Connections) do
        safeDisconnect(connection)
    end

    table.clear(Runtime.Connections)

    silentInGameNotice(
        "Build a Gun Army",
        ENV.__rainzxdev_BUILD_GUN_ARMY_LAST_ERROR
    )
end

local function beginAction(owner)
    owner = tostring(owner or "action")

    if Runtime.ActionOwner ~= nil then
        return false
    end

    Runtime.ActionOwner = owner
    Runtime.ActionStartedAt = os.clock()
    Runtime.Moving = true
    return true
end

local function endAction(owner)
    if owner == nil
        or Runtime.ActionOwner == owner then
        Runtime.ActionOwner = nil
        Runtime.ActionStartedAt = 0
        Runtime.Moving = false
    end
end

local function setInteractionState(state, target, attempt, pathStatus)
    Runtime.InteractionState = tostring(state or "Idle")

    if target ~= nil then
        Runtime.InteractionTarget = tostring(target)
    end

    if attempt ~= nil then
        Runtime.InteractionAttempt = tonumber(attempt) or 0
    end

    if pathStatus ~= nil then
        Runtime.InteractionPathStatus = tostring(pathStatus)
    end
end

addConnection(ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt then
        Runtime.ShownPrompts[prompt] = true
    end
end))

addConnection(ProximityPromptService.PromptHidden:Connect(function(prompt)
    if prompt then
        Runtime.ShownPrompts[prompt] = nil
    end
end))

local function findPlayersPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model")
            and plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
    end

    return nil
end

local function getPlot()
    if Runtime.Plot
        and Runtime.Plot.Parent
        and Runtime.Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
        return Runtime.Plot
    end

    Runtime.Plot = findPlayersPlot()
    return Runtime.Plot
end

local function getCharacterRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function waitForRoot(timeout)
    local started = os.clock()

    repeat
        local root = getCharacterRoot()
        if root then
            return root
        end

        task.wait(0.1)
    until not Runtime.Running
        or os.clock() - started >= (timeout or 5)

    return nil
end

local function getTargetPosition(object)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object.Position
    end

    if object:IsA("Model") then
        local part = object.PrimaryPart
            or object:FindFirstChildWhichIsA("BasePart", true)

        if part then
            return part.Position
        end
    end

    return nil
end

local function getCharacterGroundOffset(root)
    if not root then
        return 3
    end

    local character = root.Parent

    if character and character:IsA("Model") then
        local ok, boxCFrame, boxSize = pcall(
            character.GetBoundingBox,
            character
        )

        if ok and boxCFrame and boxSize then
            local bottomY =
                boxCFrame.Position.Y - boxSize.Y * 0.5

            local offset = root.Position.Y - bottomY

            if offset > 0.75 and offset < 7 then
                return offset
            end
        end

        local humanoid =
            character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            local offset =
                humanoid.HipHeight + root.Size.Y * 0.5

            if offset > 0.75 and offset < 7 then
                return offset
            end
        end
    end

    return math.max(root.Size.Y * 0.5 + 1.5, 2.5)
end

local function makeGroundRayParams(root, ignoredObject)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = false

    local excludes = {}

    if root and root.Parent then
        table.insert(excludes, root.Parent)
    end

    if ignoredObject
        and typeof(ignoredObject) == "Instance" then
        table.insert(excludes, ignoredObject)
    end

    params.FilterDescendantsInstances = excludes

    return params
end

local function sampleGroundY(root, x, z, ignoredObject, fallbackY)
    if not Settings.GroundFollow then
        return fallbackY
    end

    local rayHeight =
        math.max(tonumber(Settings.GroundRayHeight) or 70, 20)

    local rayDepth =
        math.max(tonumber(Settings.GroundRayDepth) or 180, rayHeight + 40)

    local originY =
        math.max(
            root and root.Position.Y or 0,
            tonumber(fallbackY) or 0
        )
        + rayHeight

    local params =
        makeGroundRayParams(root, ignoredObject)

    local result = workspace:Raycast(
        Vector3.new(x, originY, z),
        Vector3.new(0, -rayDepth, 0),
        params
    )

    if result then
        return result.Position.Y
    end

    return fallbackY
end

local function getStandingY(root, x, z, ignoredObject, fallbackRootY)
    local groundY = sampleGroundY(
        root,
        x,
        z,
        ignoredObject,
        fallbackRootY
    )

    if groundY == nil then
        return fallbackRootY
    end

    local offset = getCharacterGroundOffset(root)

    return groundY
        + offset
        + math.max(
            tonumber(Settings.GroundClearance) or 0.12,
            0
        )
end

local function acquireMovementLock(root)
    if not root or not root.Parent then
        return nil
    end

    local character = root.Parent
    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    local lock = {
        Root = root,
        WasAnchored = root.Anchored,
        Humanoid = humanoid,
        AutoRotate = humanoid and humanoid.AutoRotate or nil,
    }

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true
    end)

    if humanoid then
        pcall(function()
            humanoid.AutoRotate = false
        end)
    end

    return lock
end

local function releaseMovementLock(lock)
    if not lock then
        return
    end

    local root = lock.Root

    if root and root.Parent then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = lock.WasAnchored == true
        end)
    end

    if lock.Humanoid and lock.Humanoid.Parent then
        pcall(function()
            if lock.AutoRotate ~= nil then
                lock.Humanoid.AutoRotate = lock.AutoRotate
            end
        end)
    end
end

local function groundFollowTween(
    root,
    worldPosition,
    ignoredObject,
    speedOverride
)
    if not root
        or not root.Parent
        or not worldPosition then
        return false
    end

    local startPosition = root.Position
    local startRotation = root.CFrame.Rotation

    local targetY = getStandingY(
        root,
        worldPosition.X,
        worldPosition.Z,
        ignoredObject,
        worldPosition.Y
    )

    local targetPosition = Vector3.new(
        worldPosition.X,
        targetY,
        worldPosition.Z
    )

    local horizontalDistance = (
        Vector2.new(startPosition.X, startPosition.Z)
        - Vector2.new(targetPosition.X, targetPosition.Z)
    ).Magnitude

    local verticalDistance =
        math.abs(targetPosition.Y - startPosition.Y)

    local distance =
        math.max(
            horizontalDistance,
            verticalDistance * 0.35
        )

    if distance <= 0.12 then
        root.CFrame =
            CFrame.new(targetPosition) * startRotation
        return true
    end

    if Settings.TweenMovement ~= true then
        root.CFrame =
            CFrame.new(targetPosition) * startRotation
        return true
    end

    local speed =
        math.max(
            tonumber(speedOverride)
                or tonumber(Settings.TweenSpeed)
                or 38,
            5
        )

    local duration = math.clamp(
        distance / speed,
        Settings.TweenMinDuration,
        Settings.TweenMaxDuration
    )

    local alpha = Instance.new("NumberValue")
    alpha.Value = 0

    local tween = TweenService:Create(
        alpha,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        ),
        {
            Value = 1,
        }
    )

    tween:Play()

    local started = os.clock()
    local lastY = startPosition.Y

    while Runtime.Running
        and root.Parent
        and alpha.Value < 0.999
        and os.clock() - started <= duration + 0.45 do

        local dt = RunService.Heartbeat:Wait()
        local t = math.clamp(alpha.Value, 0, 1)

        local x =
            startPosition.X
            + (targetPosition.X - startPosition.X) * t

        local z =
            startPosition.Z
            + (targetPosition.Z - startPosition.Z) * t

        local linearY =
            startPosition.Y
            + (targetPosition.Y - startPosition.Y) * t

        local desiredY = getStandingY(
            root,
            x,
            z,
            ignoredObject,
            linearY
        )

        if desiredY == nil then
            desiredY = linearY
        end

        -- Going upward snaps to the safe standing height immediately so the
        -- character never enters rising terrain. Going downward is smoothed,
        -- which removes the camera jitter caused by tiny floor-height changes.
        if desiredY >= lastY then
            lastY = desiredY
        else
            local response =
                math.clamp(
                    dt * (
                        tonumber(Settings.GroundYSmoothing)
                        or 18
                    ),
                    0,
                    1
                )

            lastY =
                lastY
                + (desiredY - lastY) * response
        end

        root.CFrame =
            CFrame.new(x, lastY, z) * startRotation
    end

    pcall(function()
        tween:Cancel()
        alpha:Destroy()
    end)

    if root.Parent then
        local finalY = getStandingY(
            root,
            targetPosition.X,
            targetPosition.Z,
            ignoredObject,
            targetPosition.Y
        ) or targetPosition.Y

        root.CFrame =
            CFrame.new(
                targetPosition.X,
                finalY,
                targetPosition.Z
            ) * startRotation

        return true
    end

    return false
end

local function moveRootGroundSafe(
    root,
    worldPosition,
    ignoredObject,
    speedOverride
)
    return groundFollowTween(
        root,
        worldPosition,
        ignoredObject,
        speedOverride
    )
end

local function restoreRootPosition(
    root,
    originalCFrame,
    speedOverride
)
    if not Settings.RestorePosition
        or not root
        or not root.Parent
        or not originalCFrame then
        return
    end

    if Settings.TweenReturn then
        groundFollowTween(
            root,
            originalCFrame.Position,
            nil,
            speedOverride
        )

        -- Preserve the exact original facing direction after arriving.
        local finalPosition = root.Position
        root.CFrame =
            CFrame.new(finalPosition)
            * originalCFrame.Rotation
    else
        root.CFrame = originalCFrame
    end
end

local function withTemporaryPosition(object, dwell, callback)
    local owner = "temporary:" .. tostring(object and object:GetFullName() or "nil")

    if not beginAction(owner) then
        return false
    end

    local root = waitForRoot(2)
    local targetPosition = getTargetPosition(object)

    if not root or not targetPosition then
        endAction(owner)
        return false
    end

    local original = root.CFrame
    local lock = nil
    local succeeded = false

    local ok, err = pcall(function()
        lock = acquireMovementLock(root)

        local moved =
            moveRootGroundSafe(
                root,
                targetPosition,
                object
            )

        if not moved then
            return
        end

        task.wait(0.05)

        if callback then
            callback(root)
        end

        task.wait(dwell or 0.08)

        restoreRootPosition(root, original)
        succeeded = true
    end)

    if lock then
        releaseMovementLock(lock)
        lock = nil
    end

    endAction(owner)

    if not ok then
        Runtime.LastError = tostring(err)
        return false
    end

    return succeeded
end

local function getPromptWorldPosition(prompt)
    if not prompt or not prompt.Parent then
        return nil
    end

    local parent = prompt.Parent

    if parent:IsA("Attachment") then
        return parent.WorldPosition
    elseif parent:IsA("BasePart") then
        return parent.Position
    elseif parent:IsA("Model") then
        local part = parent.PrimaryPart
            or parent:FindFirstChildWhichIsA("BasePart", true)

        return part and part.Position or nil
    end

    return nil
end

local function getPromptTargetModel(prompt)
    if not prompt or not prompt.Parent then
        return nil
    end

    local current = prompt.Parent

    while current
        and current ~= workspace do

        if current:IsA("Model")
            and (
                current.Name:match("^Unit%d+$")
                or current.Name == "WeaponBox"
            ) then
            return current
        end

        current = current.Parent
    end

    return nil
end

local function makePromptOverlapParams(root, ignoredModel)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local excludes = {}

    if root and root.Parent then
        table.insert(excludes, root.Parent)
    end

    if ignoredModel
        and typeof(ignoredModel) == "Instance" then
        table.insert(excludes, ignoredModel)
    end

    params.FilterDescendantsInstances = excludes
    params.MaxParts = 30

    return params
end

local function interactionPointIsClear(root, point, ignoredModel)
    if not root or not point then
        return false
    end

    local radius =
        math.max(
            tonumber(Settings.PromptClearanceRadius) or 1.5,
            0.8
        )

    local size = Vector3.new(
        radius * 2,
        4.2,
        radius * 2
    )

    local params = makePromptOverlapParams(root, ignoredModel)

    local parts = workspace:GetPartBoundsInBox(
        CFrame.new(point),
        size,
        params
    )

    for _, part in ipairs(parts) do
        if part:IsA("BasePart")
            and part.CanCollide then

            -- Ignore ground directly underneath the standing character.
            local topY = part.Position.Y + part.Size.Y * 0.5

            if topY > point.Y - 2.15 then
                return false
            end
        end
    end

    return true
end

local function promptHasLineOfSight(root, point, prompt, targetModel)
    if not prompt or prompt.RequiresLineOfSight ~= true then
        return true
    end

    local target = getPromptWorldPosition(prompt)

    if not target then
        return true
    end

    local origin =
        point + Vector3.new(0, 1.2, 0)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local excludes = {}

    if root and root.Parent then
        table.insert(excludes, root.Parent)
    end

    -- The prompt belongs to the target gun. Ignore that gun's own decorative
    -- geometry; neighboring guns are still allowed to block this candidate.
    if targetModel then
        table.insert(excludes, targetModel)
    end

    params.FilterDescendantsInstances = excludes
    params.IgnoreWater = true

    local direction = target - origin
    local result = workspace:Raycast(
        origin,
        direction,
        params
    )

    return result == nil
end

local function computePromptPath(root, destination)
    if not root or not destination then
        return nil
    end

    if not Settings.PromptPathfinding then
        return {
            {
                Position = destination,
                Action = Enum.PathWaypointAction.Walk,
            },
        }
    end

    local path = PathfindingService:CreatePath({
        AgentRadius =
            math.max(
                tonumber(Settings.PromptPathAgentRadius) or 1.65,
                1
            ),
        AgentHeight =
            math.max(
                tonumber(Settings.PromptPathAgentHeight) or 5,
                3
            ),
        AgentCanJump = false,
        AgentCanClimb = false,
        WaypointSpacing = 3,
    })

    local ok = pcall(function()
        path:ComputeAsync(
            root.Position,
            destination
        )
    end)

    if not ok
        or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    local waypoints = path:GetWaypoints()

    if #waypoints == 0 then
        return nil
    end

    return waypoints
end

local function getPathLength(startPosition, waypoints)
    local previous = startPosition
    local total = 0

    for _, waypoint in ipairs(waypoints or {}) do
        total =
            total
            + (waypoint.Position - previous).Magnitude

        previous = waypoint.Position
    end

    return total
end

local function buildPromptInteractionCandidates(root, prompt)
    local target = getPromptWorldPosition(prompt)

    if not root or not target then
        return {}
    end

    local targetModel =
        getPromptTargetModel(prompt)

    local maxDistance =
        math.max(
            tonumber(prompt.MaxActivationDistance) or 10,
            2
        )

    local maxRadius =
        math.min(
            Settings.PromptMaxRadius,
            math.max(maxDistance * 0.65, 2.2)
        )

    local minRadius =
        math.min(
            Settings.PromptMinRadius,
            maxRadius
        )

    local sampleCount =
        math.max(
            math.floor(
                tonumber(Settings.PromptRingSamples)
                or 14
            ),
            8
        )

    local fromTarget =
        Vector2.new(
            root.Position.X - target.X,
            root.Position.Z - target.Z
        )

    local startAngle =
        fromTarget.Magnitude > 0.1
        and math.atan2(fromTarget.Y, fromTarget.X)
        or 0

    local radii = {
        minRadius,
        (minRadius + maxRadius) * 0.5,
        maxRadius,
    }

    local candidates = {}

    for ringIndex, radius in ipairs(radii) do
        for sample = 0, sampleCount - 1 do
            local angle =
                startAngle
                + (sample / sampleCount)
                    * math.pi
                    * 2

            local x =
                target.X + math.cos(angle) * radius

            local z =
                target.Z + math.sin(angle) * radius

            local y =
                getStandingY(
                    root,
                    x,
                    z,
                    targetModel,
                    target.Y
                )

            if y then
                local point = Vector3.new(x, y, z)
                local distanceToPrompt =
                    (point - target).Magnitude

                if distanceToPrompt
                    <= maxDistance * 0.88
                    and interactionPointIsClear(root, point, targetModel)
                    and promptHasLineOfSight(
                        root,
                        point,
                        prompt,
                        targetModel
                    ) then

                    local path =
                        computePromptPath(root, point)

                    if path then
                        local length =
                            getPathLength(
                                root.Position,
                                path
                            )

                        table.insert(candidates, {
                            Point = point,
                            Path = path,
                            Distance = distanceToPrompt,
                            Score =
                                length
                                + ringIndex * 0.3
                                + distanceToPrompt * 0.04,
                        })
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.Score < b.Score
    end)

    return candidates
end

local function findPromptInteractionRoute(root, prompt)
    local candidates =
        buildPromptInteractionCandidates(root, prompt)

    local best = candidates[1]

    if best then
        return best.Point, best.Path
    end

    return nil, nil
end

local function followPromptPath(
    root,
    waypoints,
    targetModel
)
    if not root or not waypoints then
        return false
    end

    for index, waypoint in ipairs(waypoints) do
        if not Runtime.Running
            or not root.Parent then
            return false
        end

        -- Skip a waypoint essentially identical to our current location.
        if (root.Position - waypoint.Position).Magnitude > 0.35 then
            local moved =
                groundFollowTween(
                    root,
                    waypoint.Position,
                    targetModel,
                    Settings.TweenSpeed
                )

            if not moved then
                return false
            end
        end
    end

    return true
end

local function moveIntoPromptRange(root, prompt)
    if not root or not prompt then
        return false
    end

    local target = getPromptWorldPosition(prompt)

    if not target then
        return false
    end

    local maxDistance =
        tonumber(prompt.MaxActivationDistance) or 10

    if (root.Position - target).Magnitude
        <= maxDistance * 0.82 then
        return true
    end

    local point, route =
        findPromptInteractionRoute(
            root,
            prompt
        )

    if point and route then
        local targetModel =
            getPromptTargetModel(prompt)

        if followPromptPath(
            root,
            route,
            targetModel
        ) then
            local finalDistance =
                (root.Position - target).Magnitude

            if finalDistance <= maxDistance * 0.95 then
                return true
            end
        end
    end

    -- Fallback: try a point on the near side of the prompt rather than the
    -- prompt's center. This still avoids intentionally entering the gun model.
    local horizontal =
        Vector3.new(
            root.Position.X - target.X,
            0,
            root.Position.Z - target.Z
        )

    if horizontal.Magnitude < 0.1 then
        horizontal = Vector3.new(1, 0, 0)
    else
        horizontal = horizontal.Unit
    end

    local fallbackRadius =
        math.min(
            math.max(maxDistance * 0.55, 2.5),
            Settings.PromptMaxRadius
        )

    local fallbackXZ =
        target + horizontal * fallbackRadius

    local fallbackY =
        getStandingY(
            root,
            fallbackXZ.X,
            fallbackXZ.Z,
            getPromptTargetModel(prompt),
            target.Y
        )

    if not fallbackY then
        return false
    end

    local fallbackPoint =
        Vector3.new(
            fallbackXZ.X,
            fallbackY,
            fallbackXZ.Z
        )

    if not interactionPointIsClear(
        root,
        fallbackPoint,
        getPromptTargetModel(prompt)
    ) then
        return false
    end

    return groundFollowTween(
        root,
        fallbackPoint,
        getPromptTargetModel(prompt),
        Settings.TweenSpeed
    )
end


local function getPromptKeyboardKey(prompt)
    if prompt
        and prompt.KeyboardKeyCode
        and prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then
        return prompt.KeyboardKeyCode
    end

    return Enum.KeyCode.E
end

local function getExecutorVirtualKey(keyCode)
    if not keyCode then
        return nil
    end

    local name = keyCode.Name

    if #name == 1 then
        local byte = string.byte(string.upper(name))

        if byte then
            return byte
        end
    end

    local known = {
        Space = 0x20,
        Return = 0x0D,
        Enter = 0x0D,
        Tab = 0x09,
        LeftShift = 0x10,
        RightShift = 0x10,
        LeftControl = 0x11,
        RightControl = 0x11,
    }

    return known[name]
end

local function readPromptUnitState(unit)
    local result = {
        Placed = unit and unit:GetAttribute("Placed") or nil,
        TierText = "",
        LevelText = "",
        XPScale = nil,
        DPSText = "",
    }

    if not unit then
        return result
    end

    local billboard =
        unit:FindFirstChild("WeaponBillboardGui")
        or unit:FindFirstChildWhichIsA("BillboardGui")

    local frame =
        billboard
        and billboard:FindFirstChild("WeaponBillboardFrame")

    if not frame then
        return result
    end

    local tierLabel = frame:FindFirstChild("UnitTextTier")
    local levelLabel = frame:FindFirstChild("LevelText")
    local dpsLabel = frame:FindFirstChild("UnitTextDPS")
    local xpBar = frame:FindFirstChild("XPBar")
    local xpFill = xpBar and xpBar:FindFirstChild("XPBarFill")

    if tierLabel and tierLabel:IsA("GuiObject") then
        pcall(function()
            result.TierText = tostring(tierLabel.Text or "")
        end)
    end

    if levelLabel and levelLabel:IsA("GuiObject") then
        pcall(function()
            result.LevelText = tostring(levelLabel.Text or "")
        end)
    end

    if dpsLabel and dpsLabel:IsA("GuiObject") then
        pcall(function()
            result.DPSText = tostring(dpsLabel.Text or "")
        end)
    end

    if xpFill and xpFill:IsA("GuiObject") then
        pcall(function()
            result.XPScale = xpFill.Size.X.Scale
        end)
    end

    return result
end

local function getWeaponBoxRolledDirect(plot)
    local box = plot and plot:FindFirstChild("WeaponBox")
    local rolled = box and box:FindFirstChild("RolledWeapon")

    if rolled and rolled:IsA("Model") then
        return rolled
    end

    return nil
end

local function capturePromptState(prompt)
    if not prompt then
        return nil
    end

    local state = {
        Enabled = prompt.Enabled,
        ActionText = tostring(prompt.ActionText or ""),
        ObjectText = tostring(prompt.ObjectText or ""),
        TotalDPS =
            tonumber(LocalPlayer:GetAttribute("TotalDPS")) or 0,
    }

    if prompt.Name == "WeaponProxPrompt" then
        local unit = getPromptTargetModel(prompt)
        local unitState = readPromptUnitState(unit)

        state.Kind = "WeaponPlacement"
        state.PendingWeapon =
            LocalPlayer:GetAttribute("PendingWeapon")
        state.PendingTier =
            LocalPlayer:GetAttribute("PendingWeaponTier")
        state.Placed = unitState.Placed
        state.TierText = unitState.TierText
        state.LevelText = unitState.LevelText
        state.XPScale = unitState.XPScale
        state.DPSText = unitState.DPSText
    elseif prompt.Name == "WeaponBoxPrompt" then
        local plot = getPlot()

        state.Kind = "WeaponBox"
        state.Rolled = getWeaponBoxRolledDirect(plot)
        state.PendingWeapon =
            LocalPlayer:GetAttribute("PendingWeapon")
    else
        state.Kind = "Generic"
    end

    return state
end

local function promptStateChanged(before, prompt)
    if not before then
        return false
    end

    -- Prompt can be destroyed/disabled as the result of a successful action.
    if not prompt or not prompt.Parent then
        return true
    end

    local after = capturePromptState(prompt)

    if not after then
        return false
    end

    if before.Kind == "WeaponPlacement" then
        if after.PendingWeapon ~= before.PendingWeapon
            or after.PendingTier ~= before.PendingTier
            or after.Placed ~= before.Placed
            or after.TierText ~= before.TierText
            or after.LevelText ~= before.LevelText
            or after.XPScale ~= before.XPScale
            or after.DPSText ~= before.DPSText
            or after.TotalDPS ~= before.TotalDPS then
            return true
        end
    elseif before.Kind == "WeaponBox" then
        if after.Rolled ~= before.Rolled
            or after.PendingWeapon ~= before.PendingWeapon
            or after.ActionText ~= before.ActionText then
            return true
        end
    else
        if after.Enabled ~= before.Enabled
            or after.ActionText ~= before.ActionText
            or after.ObjectText ~= before.ObjectText then
            return true
        end
    end

    return false
end

local function facePrompt(root, prompt)
    local target = getPromptWorldPosition(prompt)

    if not root or not target then
        return
    end

    local flatTarget =
        Vector3.new(
            target.X,
            root.Position.Y,
            target.Z
        )

    if (flatTarget - root.Position).Magnitude <= 0.05 then
        return
    end

    pcall(function()
        root.CFrame =
            CFrame.lookAt(
                root.Position,
                flatTarget
            )
    end)
end

local function updatePromptDiagnostics(root, prompt)
    local target = getPromptWorldPosition(prompt)

    Runtime.InteractionPromptEnabled =
        prompt and prompt.Enabled == true or false

    if root and target then
        Runtime.InteractionDistance =
            (root.Position - target).Magnitude
    else
        Runtime.InteractionDistance = 0
    end
end

local function waitForPromptReady(root, prompt, timeout)
    local started = os.clock()
    local maxDistance =
        tonumber(prompt and prompt.MaxActivationDistance) or 10

    repeat
        if not Runtime.Running
            or not root
            or not root.Parent
            or not prompt
            or not prompt.Parent
            or not prompt.Enabled then
            return false, "prompt unavailable"
        end

        updatePromptDiagnostics(root, prompt)

        local target = getPromptWorldPosition(prompt)
        local distance =
            target
            and (root.Position - target).Magnitude
            or math.huge

        if distance <= maxDistance * 0.94 then
            -- A shown prompt is best evidence for real keyboard input. Some
            -- executors do not surface PromptShown reliably, so after the
            -- settle period distance/enabled/LOS are enough to continue.
            if Runtime.ShownPrompts[prompt]
                or os.clock() - started >= Settings.PromptSettleTime then
                return true, "ready"
            end
        end

        RunService.Heartbeat:Wait()
    until os.clock() - started >= (timeout or Settings.PromptReadyTimeout)

    return false, "prompt never became ready"
end

local function sendVirtualInputKey(prompt)
    if not VirtualInputManager then
        return false
    end

    local keyCode = getPromptKeyboardKey(prompt)
    local holdTime =
        math.max(tonumber(prompt.HoldDuration) or 0, 0)
        + Settings.PromptExtraHold

    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(
            true,
            keyCode,
            false,
            game
        )

        task.wait(math.max(holdTime, 0.10))

        VirtualInputManager:SendKeyEvent(
            false,
            keyCode,
            false,
            game
        )
    end)

    if ok then
        Runtime.LastPromptMethod =
            "VirtualInput " .. keyCode.Name
    end

    return ok
end

local function sendExecutorKey(prompt)
    local keyCode = getPromptKeyboardKey(prompt)
    local virtualKey = getExecutorVirtualKey(keyCode)

    if not virtualKey then
        return false
    end

    local down =
        type(keypress) == "function"
        and keypress
        or (
            type(key_press) == "function"
            and key_press
            or nil
        )

    local up =
        type(keyrelease) == "function"
        and keyrelease
        or (
            type(key_release) == "function"
            and key_release
            or nil
        )

    if not down or not up then
        return false
    end

    local holdTime =
        math.max(tonumber(prompt.HoldDuration) or 0, 0)
        + Settings.PromptExtraHold

    local ok = pcall(function()
        down(virtualKey)
        task.wait(math.max(holdTime, 0.10))
        up(virtualKey)
    end)

    if ok then
        Runtime.LastPromptMethod =
            "Executor key " .. keyCode.Name
    end

    return ok
end

local function sendFireProximityPrompt(prompt)
    if type(fireproximityprompt) ~= "function" then
        return false
    end

    local hold =
        math.max(tonumber(prompt.HoldDuration) or 0, 0)

    local ok = pcall(function()
        local callOk = pcall(
            fireproximityprompt,
            prompt,
            hold
        )

        if not callOk then
            fireproximityprompt(prompt)
        end
    end)

    if ok then
        Runtime.LastPromptMethod = "fireproximityprompt"
    end

    return ok
end

local function sendInputHold(prompt)
    local hold =
        math.max(tonumber(prompt.HoldDuration) or 0, 0)
        + Settings.PromptExtraHold

    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(hold, 0.10))
        prompt:InputHoldEnd()
    end)

    if ok then
        Runtime.LastPromptMethod = "InputHoldBegin/End"
    end

    return ok
end

local function waitForPromptOutcome(prompt, before, triggeredState, timeout)
    local started = os.clock()

    repeat
        if triggeredState.Value then
            return true, "Triggered event"
        end

        if promptStateChanged(before, prompt) then
            return true, "replicated state changed"
        end

        task.wait(0.04)
    until not Runtime.Running
        or os.clock() - started >= (timeout or Settings.PromptOutcomeTimeout)

    return false, "no state change"
end

local function activatePromptVerified(root, prompt)
    local before = capturePromptState(prompt)

    if not before then
        return false, "could not capture pre-state"
    end

    local triggeredState = {Value = false}
    local triggeredConnection = nil

    pcall(function()
        triggeredConnection =
            prompt.Triggered:Connect(function(player)
                if player == nil or player == LocalPlayer then
                    triggeredState.Value = true
                end
            end)
    end)

    local methods = {
        sendVirtualInputKey,
        sendExecutorKey,
        sendFireProximityPrompt,
        sendInputHold,
    }

    local retries =
        math.max(
            math.floor(
                tonumber(Settings.PromptInputRetries) or 3
            ),
            1
        )

    for attempt = 1, retries do
        Runtime.InteractionAttempt = attempt

        if not Runtime.Running
            or not prompt.Parent
            or not prompt.Enabled then
            break
        end

        facePrompt(root, prompt)

        local ready, readyReason =
            waitForPromptReady(
                root,
                prompt,
                Settings.PromptReadyTimeout
            )

        if not ready then
            Runtime.LastPromptResult = readyReason
            break
        end

        for _, method in ipairs(methods) do
            if not Runtime.Running then
                break
            end

            setInteractionState("Activate")

            local sent = method(prompt)

            if sent then
                setInteractionState("VerifyResult")

                local success, reason =
                    waitForPromptOutcome(
                        prompt,
                        before,
                        triggeredState,
                        Settings.PromptOutcomeTimeout
                    )

                if success then
                    Runtime.LastPromptResult =
                        "success · " .. tostring(reason)

                    if triggeredConnection then
                        triggeredConnection:Disconnect()
                    end

                    return true, reason
                end
            end

            task.wait(0.07)
        end

        Runtime.LastPromptResult =
            "retry " .. tostring(attempt)

        task.wait(
            math.max(
                tonumber(Settings.PromptRetryDelay) or 0.18,
                0.05
            )
        )
    end

    if triggeredConnection then
        triggeredConnection:Disconnect()
    end

    return false, Runtime.LastPromptResult
end

local function triggerPrompt(prompt)
    if not prompt
        or not prompt:IsA("ProximityPrompt")
        or not prompt.Enabled then
        return false
    end

    local owner = "prompt:" .. tostring(prompt:GetFullName())

    if not beginAction(owner) then
        return false
    end

    local root = waitForRoot(2)

    if not root then
        endAction(owner)
        return false
    end

    local original = root.CFrame
    local movementLock = nil
    local activated = false
    local failureReason = "unknown"

    Runtime.InteractionTarget = prompt:GetFullName()
    Runtime.InteractionAttempt = 0
    Runtime.LastPromptMethod = "none"
    Runtime.LastPromptResult = "starting"

    local ok, err = pcall(function()
        local candidates =
            buildPromptInteractionCandidates(
                root,
                prompt
            )

        local maxCandidates =
            math.max(
                math.floor(
                    tonumber(Settings.PromptAlternatePositions)
                    or 5
                ),
                1
            )

        if #candidates == 0 then
            -- Fallback route from the old near-side logic.
            local point, route =
                findPromptInteractionRoute(root, prompt)

            if point and route then
                candidates = {{
                    Point = point,
                    Path = route,
                    Score = 0,
                }}
            end
        end

        if #candidates == 0 then
            failureReason = "no clear interaction position"
            setInteractionState(
                "Failed",
                Runtime.InteractionTarget,
                0,
                failureReason
            )
            return
        end

        for candidateIndex = 1, math.min(#candidates, maxCandidates) do
            if not Runtime.Running
                or not prompt.Parent
                or not prompt.Enabled then
                failureReason = "prompt disappeared"
                break
            end

            local candidate = candidates[candidateIndex]

            setInteractionState(
                "RouteToTarget",
                Runtime.InteractionTarget,
                candidateIndex,
                "candidate " .. tostring(candidateIndex)
            )

            movementLock = acquireMovementLock(root)

            local currentRoute =
                computePromptPath(
                    root,
                    candidate.Point
                )
                or candidate.Path

            local moved =
                followPromptPath(
                    root,
                    currentRoute,
                    getPromptTargetModel(prompt)
                )

            if movementLock then
                releaseMovementLock(movementLock)
                movementLock = nil
            end

            if not moved then
                failureReason = "route failed"
                setInteractionState(
                    "RetryAlternatePosition",
                    nil,
                    candidateIndex,
                    failureReason
                )
                task.wait(0.08)
            else
                -- IMPORTANT: keyboard/proximity interaction happens while the
                -- character is unanchored and physically settled. This avoids
                -- the Roblox prompt system ignoring an HRP that was moved while
                -- anchored.
                setInteractionState("Arrive")

                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)

                facePrompt(root, prompt)
                setInteractionState("Settle")

                local settleStarted = os.clock()

                while Runtime.Running
                    and root.Parent
                    and os.clock() - settleStarted
                        < math.max(Settings.PromptSettleTime, 0.05) do
                    RunService.Heartbeat:Wait()
                end

                setInteractionState("VerifyPrompt")

                local ready, readyReason =
                    waitForPromptReady(
                        root,
                        prompt,
                        Settings.PromptReadyTimeout
                    )

                if not ready then
                    failureReason = readyReason
                    setInteractionState(
                        "RetryAlternatePosition",
                        nil,
                        candidateIndex,
                        readyReason
                    )
                    task.wait(0.08)
                else
                    local success, activationReason =
                        activatePromptVerified(
                            root,
                            prompt
                        )

                    if success then
                        activated = true
                        failureReason = activationReason or "success"
                        setInteractionState(
                            "Success",
                            nil,
                            candidateIndex,
                            failureReason
                        )
                        break
                    else
                        failureReason =
                            activationReason or "activation failed"

                        setInteractionState(
                            "RetryAlternatePosition",
                            nil,
                            candidateIndex,
                            failureReason
                        )

                        task.wait(0.10)
                    end
                end
            end
        end

        if not activated then
            setInteractionState(
                "Failed",
                nil,
                Runtime.InteractionAttempt,
                failureReason
            )
            Runtime.LastDecision =
                "Prompt failed · " .. tostring(failureReason)
        end

        if root.Parent and Settings.RestorePosition then
            movementLock = acquireMovementLock(root)

            restoreRootPosition(
                root,
                original,
                Settings.TweenSpeed
            )

            if movementLock then
                releaseMovementLock(movementLock)
                movementLock = nil
            end
        end
    end)

    if movementLock then
        releaseMovementLock(movementLock)
        movementLock = nil
    end

    endAction(owner)

    if not ok then
        Runtime.LastError = tostring(err)
        Runtime.LastPromptResult = "exception"
        setInteractionState(
            "Failed",
            nil,
            Runtime.InteractionAttempt,
            "exception"
        )
        return false
    end

    if activated then
        task.defer(function()
            task.wait(0.15)

            if Runtime.InteractionState == "Success" then
                setInteractionState("Idle", "none", 0, "none")
            end
        end)
    end

    return activated
end

local function touchPart(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    return withTemporaryPosition(part, 0.12, function(root)
        if type(firetouchinterest) == "function" then
            pcall(firetouchinterest, root, part, 0)
            task.wait()
            pcall(firetouchinterest, root, part, 1)
        end
    end)
end

local function parseUnitNumber(unitName)
    if type(unitName) ~= "string" then
        return nil
    end

    return tonumber(string.match(unitName, "^Unit(%d+)$"))
end

local RARITY_NAMES = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Secret",
}

local TIER_NAMES = {
    [1] = "Normal",
    [2] = "Shiny",
    [3] = "Electric",
    [4] = "Cosmic",
}

local TIER_TEXT_TO_NUMBER = {
    [""] = 1,
    ["Normal"] = 1,
    ["Shiny"] = 2,
    ["Electric"] = 3,
    ["Cosmic"] = 4,
}


local TIER_DPS_MULTIPLIER = {
    [1] = 1,
    [2] = 2,
    [3] = 5,
    [4] = 15,
}

local TIER_COST_MULTIPLIER = {
    [1] = 1,
    [2] = 12,
    [3] = 180,
    [4] = 3000,
}

-- Exact BaseCost values from the inspected WeaponConfigModule.
local WEAPON_BASE_COST = {
    [1] = 20,
    [2] = 29.2,
    [3] = 42.6,
    [4] = 62.2,
    [5] = 90.9,
    [6] = 133,

    [7] = 840,
    [8] = 1230,
    [9] = 1790,
    [10] = 2610,
    [11] = 3820,
    [12] = 5570,

    [13] = 28600,
    [14] = 41700,
    [15] = 60900,
    [16] = 88900,
    [17] = 130000,
    [18] = 189000,

    [19] = 942000,
    [20] = 1380000,
    [21] = 2010000,
    [22] = 2930000,
    [23] = 4280000,
    [24] = 6250000,

    [25] = 30200000,
    [26] = 44000000,
    [27] = 64300000,
    [28] = 93900000,
    [29] = 137000000,
    [30] = 200000000,

    [31] = 995000000,
    [32] = 1450000000,
    [33] = 2120000000,
    [34] = 3100000000,
    [35] = 4520000000,
    [36] = 6600000000,

    [37] = 33800000000,
    [38] = 49400000000,
    [39] = 72100000000,
    [40] = 105000000000,
    [41] = 154000000000,
    [42] = 224000000000,
}

-- Rare rolls deserve longer observation/hold windows before being discarded.
-- Index matches the game's seven rarity groups.
local RARITY_HOLD_MULTIPLIER = {
    [1] = 0.30,
    [2] = 0.55,
    [3] = 1.00,
    [4] = 1.70,
    [5] = 2.70,
    [6] = 4.50,
    [7] = 8.00,
}


-- Exact WeaponConfigModule milestones from the inspected game.
local LUCK_MILESTONES = {
    {Wave = 0, Luck = 1},
    {Wave = 10, Luck = 1.5},
    {Wave = 15, Luck = 2.1},
    {Wave = 20, Luck = 3.1},
    {Wave = 30, Luck = 3.8},
    {Wave = 35, Luck = 4.6},
    {Wave = 40, Luck = 6},
    {Wave = 50, Luck = 6.9},
    {Wave = 55, Luck = 7.7},
    {Wave = 60, Luck = 9.3},
    {Wave = 70, Luck = 10.3},
    {Wave = 75, Luck = 11.2},
    {Wave = 80, Luck = 13},
    {Wave = 90, Luck = 13.9},
    {Wave = 95, Luck = 14.9},
    {Wave = 100, Luck = 16.8},
    {Wave = 110, Luck = 17.8},
    {Wave = 115, Luck = 18.8},
    {Wave = 120, Luck = 20.9},
    {Wave = 130, Luck = 21.9},
    {Wave = 135, Luck = 23},
    {Wave = 140, Luck = 25.1},
}

local function displayLuck(baseLuck)
    local value = math.max(tonumber(baseLuck) or 1, 0)
    return math.floor((value ^ 1.7) * 10 + 0.5) / 10
end

local function getLuckMilestoneInfo(wave)
    wave = math.max(math.floor(tonumber(wave) or 0), 0)

    local current = LUCK_MILESTONES[1]
    local nextMilestone = nil

    for _, milestone in ipairs(LUCK_MILESTONES) do
        if milestone.Wave <= wave then
            current = milestone
        elseif not nextMilestone then
            nextMilestone = milestone
            break
        end
    end

    return current, nextMilestone
end

local function getStrategyWave(plot)
    local current = plot and tonumber(plot:GetAttribute("CurrentWave"))

    if current then
        return math.max(math.floor(current), 0)
    end

    return math.max(math.floor(Runtime.LastWave or 0), 0)
end

local function getBossDistance(wave)
    wave = math.max(math.floor(tonumber(wave) or 0), 0)

    if wave <= 0 then
        return 20
    end

    local remainder = wave % 20

    if remainder == 0 then
        return 0
    end

    return 20 - remainder
end

local function shouldReserveForProgression(plot)
    local wave = getStrategyWave(plot)
    local _, nextMilestone = getLuckMilestoneInfo(wave)

    local nearLuck =
        Settings.LuckMilestoneHold
        and nextMilestone
        and nextMilestone.Wave - wave <= Settings.MilestoneHoldWaves

    local bossDistance = getBossDistance(wave)
    local nearBoss =
        bossDistance > 0
        and bossDistance <= Settings.BossReserveWaves

    return nearLuck == true, nearBoss == true, nextMilestone
end

local function getUnitRarity(unitName)
    local number = parseUnitNumber(unitName)
    if not number then
        return 1
    end

    return math.clamp(math.ceil(number / 6), 1, 7)
end


local function compactNumber(value)
    value = tonumber(value) or 0
    local absValue = math.abs(value)

    if absValue >= 1e12 then
        return string.format("%.2fT", value / 1e12)
    elseif absValue >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif absValue >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif absValue >= 1e3 then
        return string.format("%.1fK", value / 1e3)
    end

    return tostring(math.floor(value + 0.5))
end

local function recomputeIncomeRate()
    local samples = {}

    for _, value in ipairs(Runtime.IncomeSamples) do
        if type(value) == "number"
            and value >= 0
            and value < math.huge then
            table.insert(samples, value)
        end
    end

    if #samples == 0 then
        Runtime.IncomePerSecond = 0
        return
    end

    table.sort(samples)

    local trim = 0

    if #samples >= 8 then
        trim = math.max(math.floor(#samples * 0.18), 1)
    end

    local first = 1 + trim
    local last = #samples - trim

    if first > last then
        first = 1
        last = #samples
    end

    local total = 0
    local count = 0

    for index = first, last do
        total = total + samples[index]
        count = count + 1
    end

    Runtime.IncomePerSecond =
        count > 0 and total / count or 0
end

local function updateIncomeTracker()
    local now = os.clock()
    local currency =
        tonumber(LocalPlayer:GetAttribute("currency")) or 0

    if Runtime.CurrencySample == nil
        or Runtime.CurrencySampleAt == nil then
        Runtime.CurrencySample = currency
        Runtime.CurrencySampleAt = now
        return
    end

    local dt = now - Runtime.CurrencySampleAt

    if dt < 0.35 then
        return
    end

    local delta = currency - Runtime.CurrencySample

    if delta > 0 then
        local rate = delta / math.max(dt, 0.01)

        -- Very large one-off rewards are retained but capped relative to the
        -- current robust rate so Offline/Group rewards cannot make a rare roll
        -- look affordable in a few seconds when normal farming is much slower.
        if Runtime.IncomePerSecond > 0 then
            rate = math.min(
                rate,
                Runtime.IncomePerSecond * 6 + 25
            )
        end

        table.insert(Runtime.IncomeSamples, rate)

        while #Runtime.IncomeSamples > 24 do
            table.remove(Runtime.IncomeSamples, 1)
        end

        Runtime.LastPositiveIncomeAt = now
        Runtime.TotalObservedIncome =
            Runtime.TotalObservedIncome + delta

        recomputeIncomeRate()
    elseif now - Runtime.LastPositiveIncomeAt > 7 then
        -- Slowly decay an old estimate during a genuine stall.
        Runtime.IncomePerSecond =
            Runtime.IncomePerSecond * 0.94
    end

    Runtime.CurrencySample = currency
    Runtime.CurrencySampleAt = now
end

local function getSpawnedEnemyGuaranteedIncome(plot)
    local folder =
        plot and plot:FindFirstChild("SpawnedEnemies")

    if not folder then
        return 0
    end

    local total = 0

    for _, enemy in ipairs(folder:GetChildren()) do
        if enemy:IsA("Model")
            and enemy:GetAttribute("Dead") ~= true then

            local value =
                tonumber(enemy:GetAttribute("LootValue"))

            if value and value > 0 then
                total = total + value
            end
        end
    end

    return total
end

local function getDroppedGuaranteedIncome(plot)
    local folder =
        plot and plot:FindFirstChild("LootSpawned")

    if not folder then
        return 0
    end

    local total = 0

    for _, loot in ipairs(folder:GetChildren()) do
        local value =
            tonumber(loot:GetAttribute("LootValue"))
            or tonumber(loot:GetAttribute("CurrencyValue"))
            or tonumber(loot:GetAttribute("Value"))
            or tonumber(loot:GetAttribute("Amount"))

        -- Only count explicit currency-value attributes. StackSize is not
        -- treated as money because the dump does not prove that equivalence.
        if value and value > 0 then
            total = total + value
        end
    end

    return total
end

local function getGuaranteedIncome(plot)
    return getSpawnedEnemyGuaranteedIncome(plot)
        + getDroppedGuaranteedIncome(plot)
end


local function getWeaponBillboardFrame(model)
    if not model then
        return nil
    end

    local billboard = model:FindFirstChild("WeaponBillboardGui")
        or model:FindFirstChildWhichIsA("BillboardGui")

    if not billboard then
        return nil
    end

    return billboard:FindFirstChild("WeaponBillboardFrame")
end

local function parseFirstNumber(text)
    text = tostring(text or "")
    text = text:gsub(",", "")

    local value = text:match("[-+]?%d+%.?%d*")
    return tonumber(value)
end

local function getWeaponLevel(unit)
    local frame = getWeaponBillboardFrame(unit)
    local label = frame and frame:FindFirstChild("LevelText")

    if label and (
        label:IsA("TextLabel")
        or label:IsA("TextButton")
    ) then
        return math.max(
            math.floor(parseFirstNumber(label.Text) or 1),
            1
        )
    end

    return 1
end

local function getWeaponXPProgress(unit)
    local frame = getWeaponBillboardFrame(unit)
    local bar = frame and frame:FindFirstChild("XPBar")
    local fill = bar and bar:FindFirstChild("XPBarFill")

    if not bar or not fill
        or not bar:IsA("GuiObject")
        or not fill:IsA("GuiObject") then
        return nil
    end

    local scale = fill.Size.X.Scale

    if type(scale) == "number"
        and scale >= 0
        and scale <= 1.05 then
        return math.clamp(scale, 0, 1)
    end

    if bar.AbsoluteSize.X > 0 then
        return math.clamp(
            fill.AbsoluteSize.X / bar.AbsoluteSize.X,
            0,
            1
        )
    end

    return nil
end

local function getWeaponDisplayedDPS(unit)
    local attr = tonumber(unit and unit:GetAttribute("DPS"))

    if attr and attr > 0 then
        return attr
    end

    local frame = getWeaponBillboardFrame(unit)
    local label = frame and frame:FindFirstChild("UnitTextDPS")

    if label and (
        label:IsA("TextLabel")
        or label:IsA("TextButton")
    ) then
        return parseFirstNumber(label.Text) or 0
    end

    return 0
end

local function getRolledDuplicateXP(model)
    local frame = getWeaponBillboardFrame(model)
    local newText = frame and frame:FindFirstChild("NewText")

    if not newText
        or not (
            newText:IsA("TextLabel")
            or newText:IsA("TextButton")
        ) then
        return 0
    end

    local text = tostring(newText.Text or "")
    local amount = text:match("%+%s*(%d+)%s*[Xx][Pp]")

    return tonumber(amount) or 0
end

local function getPlacedUnitTier(unit)
    if not unit or not unit:IsA("Model") then
        return 0
    end

    if unit:GetAttribute("Placed") ~= true then
        return 0
    end

    local billboard = unit:FindFirstChild("WeaponBillboardGui")
    local frame = billboard and billboard:FindFirstChild("WeaponBillboardFrame")
    local label = frame and frame:FindFirstChild("UnitTextTier")

    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        local tier = TIER_TEXT_TO_NUMBER[tostring(label.Text or "")]
        if tier then
            return tier
        end
    end

    -- A placed unit without a replicated tier label is at least tier 1.
    return 1
end

local function getPlacedWeaponInfo(unit)
    return {
        Tier = getPlacedUnitTier(unit),
        Level = getWeaponLevel(unit),
        XPProgress = getWeaponXPProgress(unit),
        DPS = getWeaponDisplayedDPS(unit),
    }
end


local function getNextUnownedGun(plot, ignoreUnitName)
    local units = plot and plot:FindFirstChild("Units")

    if not units then
        return nil
    end

    local best = nil

    for number = 1, 42 do
        local name = "Unit" .. tostring(number)

        if name ~= ignoreUnitName then
            local unit = units:FindFirstChild(name)

            if unit and getPlacedUnitTier(unit) <= 0 then
                local cost = WEAPON_BASE_COST[number]

                if cost and (
                    not best
                    or cost < best.Cost
                ) then
                    best = {
                        Name = name,
                        Number = number,
                        Cost = cost,
                        Rarity = getUnitRarity(name),
                    }
                end
            end
        end
    end

    return best
end

local function getFutureGunReserve(plot, ignoreUnitName)
    if not Settings.FutureGunReserve then
        return 0, nil
    end

    local target =
        getNextUnownedGun(plot, ignoreUnitName)

    if not target then
        return 0, nil
    end

    local reserve =
        target.Cost
        * math.clamp(
            Settings.FutureReservePercent,
            0,
            100
        )
        / 100

    return reserve, target
end

local function getRollHoldAge(rolled)
    if not rolled or not rolled.Model then
        Runtime.RollHoldModel = nil
        Runtime.RollHoldSince = 0
        return 0
    end

    if Runtime.RollHoldModel ~= rolled.Model then
        Runtime.RollHoldModel = rolled.Model
        Runtime.RollHoldSince = os.clock()
    end

    return math.max(
        os.clock() - Runtime.RollHoldSince,
        0
    )
end

local function estimateSecondsToAfford(
    plot,
    requiredCost,
    currentCurrency
)
    local guaranteed = getGuaranteedIncome(plot)
    local projected = currentCurrency + guaranteed
    local deficit = math.max(requiredCost - projected, 0)

    if deficit <= 0 then
        return 0, guaranteed, projected
    end

    local incomeRate =
        math.max(Runtime.IncomePerSecond or 0, 0)

    if incomeRate <= 0.01 then
        return math.huge, guaranteed, projected
    end

    return deficit / incomeRate,
        guaranteed,
        projected
end

local function getNewRollProtectionDecision(plot, rolled)
    local currency =
        tonumber(LocalPlayer:GetAttribute("currency")) or 0

    if currency >= rolled.Cost then
        return "buy", "New gun affordable", "new"
    end

    if not Settings.ProtectUnownedRolls then
        return "discard",
            "New gun unaffordable · protection off",
            "new"
    end

    local rarity = getUnitRarity(rolled.Name)

    local holdLimit =
        Settings.NewGunBaseHoldSeconds
        * (
            RARITY_HOLD_MULTIPLIER[rarity]
            or 1
        )

    local holdAge = getRollHoldAge(rolled)

    local eta, guaranteed, projected =
        estimateSecondsToAfford(
            plot,
            rolled.Cost,
            currency
        )

    local deficit =
        math.max(rolled.Cost - currency, 0)

    if projected >= rolled.Cost then
        Runtime.LastEconomy =
            string.format(
                "SAVE %s · cash %s + guaranteed %s >= %s",
                RARITY_NAMES[rarity] or "new",
                compactNumber(currency),
                compactNumber(guaranteed),
                compactNumber(rolled.Cost)
            )

        return "wait",
            "Saving · guaranteed live income covers roll",
            "new"
    end

    if eta <= holdLimit then
        Runtime.LastEconomy =
            string.format(
                "SAVE %s · need %s · ETA %.1fs / %.0fs",
                RARITY_NAMES[rarity] or "new",
                compactNumber(deficit),
                eta,
                holdLimit
            )

        return "wait",
            string.format(
                "Saving for %s · ETA %.1fs",
                RARITY_NAMES[rarity] or "new gun",
                eta
            ),
            "new"
    end

    -- Always observe a newly rolled gun briefly so the income estimator gets
    -- enough samples before deciding it is economically unreachable.
    local minimumObserve =
        math.min(12, holdLimit * 0.25)

    if holdAge < minimumObserve then
        Runtime.LastEconomy =
            string.format(
                "OBSERVE %s · deficit %s · income %.1f/s",
                RARITY_NAMES[rarity] or "new",
                compactNumber(deficit),
                Runtime.IncomePerSecond or 0
            )

        return "wait",
            "Measuring income before deciding",
            "new"
    end

    -- High rarities are protected more aggressively if meaningful progress
    -- toward the price already exists.
    local fundedRatio =
        currency / math.max(rolled.Cost, 1)

    if rarity >= 5
        and fundedRatio >= 0.20
        and holdAge < holdLimit * 1.5 then

        Runtime.LastEconomy =
            string.format(
                "HOLD %s · %.0f%% funded",
                RARITY_NAMES[rarity] or "high rarity",
                fundedRatio * 100
            )

        return "wait",
            string.format(
                "Protecting %s roll · %.0f%% funded",
                RARITY_NAMES[rarity] or "rare",
                fundedRatio * 100
            ),
            "new"
    end

    Runtime.LastEconomy =
        string.format(
            "DISCARD %s · ETA too long (%s)",
            RARITY_NAMES[rarity] or "new",
            eta == math.huge
                and "unknown"
                or string.format("%.1fs", eta)
        )

    return "discard",
        "Cannot fund new gun soon enough",
        "new"
end

local function estimateTierUpgradeGain(existing, newTier)
    local oldMult =
        TIER_DPS_MULTIPLIER[existing.Tier] or 1

    local newMult =
        TIER_DPS_MULTIPLIER[newTier] or oldMult

    if newMult <= oldMult then
        return 0
    end

    -- Weapon level is separate from tier in the replicated presentation. Use
    -- current displayed DPS and scale it by the exact tier multiplier ratio.
    return existing.DPS
        * (newMult / oldMult - 1)
end

local function getUpgradePaybackSeconds(
    upgradeCost,
    dpsGain,
    totalDPS
)
    if upgradeCost <= 0
        or dpsGain <= 0
        or totalDPS <= 0
        or Runtime.IncomePerSecond <= 0.01 then
        return math.huge
    end

    local proportionalIncomeGain =
        Runtime.IncomePerSecond
        * (dpsGain / totalDPS)

    if proportionalIncomeGain <= 0.01 then
        return math.huge
    end

    return upgradeCost / proportionalIncomeGain
end

local function getRawRolledWeapon(plot)
    local box = plot and plot:FindFirstChild("WeaponBox")
    local rolled = box and box:FindFirstChild("RolledWeapon")

    if rolled and rolled:IsA("Model") then
        return rolled
    end

    return nil
end

local function getRolledWeapon(plot)
    local rolled = getRawRolledWeapon(plot)

    if not rolled then
        return nil
    end

    local unitName = rolled:GetAttribute("unitName")
    local tier = tonumber(rolled:GetAttribute("unitTier"))
    local cost = tonumber(rolled:GetAttribute("Cost"))

    if type(unitName) ~= "string"
        or not tier
        or not cost then
        return nil
    end

    return {
        Model = rolled,
        Name = unitName,
        Tier = math.clamp(math.floor(tier + 0.5), 1, 4),
        Cost = math.max(cost, 0),
        DPS = tonumber(rolled:GetAttribute("DPS")) or 0,
        Damage = tonumber(rolled:GetAttribute("Damage")) or 0,
        DuplicateXP = getRolledDuplicateXP(rolled),
    }
end

local function getWeaponDecision(plot, rolled)
    if not plot or not rolled then
        return "wait", "No valid roll", "none"
    end

    local units = plot:FindFirstChild("Units")
    local unit = units and units:FindFirstChild(rolled.Name)

    if not unit or not unit:IsA("Model") then
        return "wait", "Unit template unavailable", "none"
    end

    local existing = getPlacedWeaponInfo(unit)
    local currency =
        tonumber(LocalPlayer:GetAttribute("currency")) or 0

    local totalDPS =
        tonumber(LocalPlayer:GetAttribute("TotalDPS")) or 0

    -- Highest priority: a genuinely new/unowned gun currently sitting in the
    -- station. It receives an explicit affordability/ETA decision.
    if existing.Tier <= 0 then
        return getNewRollProtectionDecision(
            plot,
            rolled
        )
    end

    local reserve, reserveTarget =
        getFutureGunReserve(plot, nil)

    local postPurchaseCash =
        currency - rolled.Cost

    local keepsReserve =
        postPurchaseCash >= reserve

    local dpsShare =
        existing.DPS > 0
        and totalDPS > 0
        and existing.DPS / totalDPS
        or 0

    local strongWeapon =
        dpsShare >= Settings.DuplicateStrongWeaponShare

    local nearLevel =
        existing.XPProgress ~= nil
        and existing.XPProgress >= Settings.NearLevelThreshold

    local nearLuck, nearBoss, nextMilestone =
        shouldReserveForProgression(plot)

    -- Existing gun tier upgrade. Estimate its gain using the exact tier
    -- multipliers while preserving the gun's current level contribution.
    if rolled.Tier > existing.Tier then
        if currency < rolled.Cost then
            local eta, guaranteed =
                estimateSecondsToAfford(
                    plot,
                    rolled.Cost,
                    currency
                )

            local important =
                strongWeapon
                or rolled.Tier - existing.Tier >= 2

            local maxWait =
                important
                and Settings.NewGunBaseHoldSeconds
                or Settings.NewGunBaseHoldSeconds * 0.45

            if eta <= maxWait
                or currency + guaranteed >= rolled.Cost then

                Runtime.LastEconomy =
                    string.format(
                        "SAVE upgrade %s -> %s · ETA %s",
                        TIER_NAMES[existing.Tier] or "?",
                        TIER_NAMES[rolled.Tier] or "?",
                        eta == math.huge
                            and "?"
                            or string.format("%.1fs", eta)
                    )

                return "wait",
                    "Saving for worthwhile tier upgrade",
                    "tier"
            end

            return "discard",
                "Tier upgrade too expensive right now",
                "tier"
        end

        local gain =
            estimateTierUpgradeGain(
                existing,
                rolled.Tier
            )

        local payback =
            getUpgradePaybackSeconds(
                rolled.Cost,
                gain,
                totalDPS
            )

        local majorUpgrade =
            rolled.Tier - existing.Tier >= 2

        local efficient =
            payback <= Settings.MaxUpgradePaybackSeconds

        local reserveBreakAllowed =
            Settings.StrategicReserveBreak
            and (
                majorUpgrade
                or strongWeapon
                or efficient
            )

        if keepsReserve or reserveBreakAllowed then
            Runtime.LastEconomy =
                string.format(
                    "BUY tier · +%s DPS est · payback %s · reserve %s",
                    compactNumber(gain),
                    payback == math.huge
                        and "?"
                        or string.format("%.1fs", payback),
                    compactNumber(reserve)
                )

            return "buy",
                string.format(
                    "Tier %s→%s · +%s DPS est",
                    TIER_NAMES[existing.Tier] or tostring(existing.Tier),
                    TIER_NAMES[rolled.Tier] or tostring(rolled.Tier),
                    compactNumber(gain)
                ),
                "tier"
        end

        Runtime.LastEconomy =
            string.format(
                "SKIP tier · protects %s reserve for %s",
                compactNumber(reserve),
                reserveTarget and reserveTarget.Name or "next gun"
            )

        return "discard",
            "Tier upgrade would consume next-gun reserve",
            "tier"
    end

    local duplicateXP =
        tonumber(rolled.DuplicateXP) or 0

    if duplicateXP <= 0
        or not Settings.AutoDuplicateXP then
        return "discard",
            "No useful upgrade",
            "duplicate"
    end

    if currency < rolled.Cost then
        return "discard",
            "XP duplicate not affordable",
            "xp"
    end

    local spendLimit =
        currency
        * math.clamp(
            Settings.DuplicateSpendPercent,
            0,
            100
        )
        / 100

    local withinBudget =
        rolled.Cost <= spendLimit

    if Settings.Strategy == "Luck Rush"
        and nearLuck
        and not nearLevel then

        return "discard",
            "Saving for wave "
            .. tostring(
                nextMilestone
                and nextMilestone.Wave
                or "?"
            )
            .. " luck",
            "xp"
    end

    if nearBoss
        and not nearLevel
        and not strongWeapon then

        return "discard",
            "Boss reserve",
            "xp"
    end

    -- Duplicate XP is optional spending. Protect the expected normal-price
    -- reserve for the next unowned gun unless this duplicate is unusually
    -- valuable (near level + important weapon).
    local exceptionalXP =
        nearLevel and strongWeapon

    if Settings.FutureGunReserve
        and not keepsReserve
        and not (
            Settings.StrategicReserveBreak
            and exceptionalXP
        ) then

        Runtime.LastEconomy =
            string.format(
                "SKIP XP · cash after %s < next-gun reserve %s",
                compactNumber(postPurchaseCash),
                compactNumber(reserve)
            )

        return "discard",
            "Protecting cash for next unowned gun",
            "xp"
    end

    if Settings.Strategy == "XP Focus" then
        Runtime.LastEconomy =
            string.format(
                "BUY XP · +%d XP · L%d · reserve %s",
                duplicateXP,
                existing.Level,
                compactNumber(reserve)
            )

        return "buy",
            string.format(
                "+%d XP · Level %d",
                duplicateXP,
                existing.Level
            ),
            "xp"
    end

    if nearLevel then
        Runtime.LastEconomy =
            string.format(
                "BUY XP · %.0f%% to level · %s DPS share",
                (existing.XPProgress or 0) * 100,
                string.format("%.1f%%", dpsShare * 100)
            )

        return "buy",
            string.format(
                "+%d XP · %.0f%% to level",
                duplicateXP,
                (existing.XPProgress or 0) * 100
            ),
            "xp"
    end

    if strongWeapon and withinBudget then
        Runtime.LastEconomy =
            string.format(
                "BUY XP · strong gun %.1f%% DPS",
                dpsShare * 100
            )

        return "buy",
            string.format(
                "+%d XP · strong gun %.1f%% DPS",
                duplicateXP,
                dpsShare * 100
            ),
            "xp"
    end

    if Settings.Strategy == "Balanced"
        and withinBudget
        and keepsReserve then

        return "buy",
            string.format(
                "+%d XP · reserve preserved",
                duplicateXP
            ),
            "xp"
    end

    if Settings.Strategy == "Collection" then
        return "discard",
            "Collection mode: save for unowned gun",
            "xp"
    end

    return "discard",
        "XP duplicate not efficient enough",
        "xp"
end

local function moveIntoWeaponBoxZone(plot, callback)
    local box = plot and plot:FindFirstChild("WeaponBox")
    local zone = box and box:FindFirstChild("Zone")

    if not zone or not zone:IsA("BasePart") then
        return false
    end

    return withTemporaryPosition(zone, 0.12, callback)
end

local function findWeaponPlacementPrompt(unit)
    if not unit then
        return nil
    end

    local weaponBase =
        unit:FindFirstChild("WeaponBasePart", true)

    local exact =
        weaponBase
        and weaponBase:FindFirstChild("WeaponProxPrompt")

    if exact and exact:IsA("ProximityPrompt") then
        return exact
    end

    local best = nil

    for _, descendant in ipairs(unit:GetDescendants()) do
        if descendant:IsA("ProximityPrompt")
            and descendant.Name == "WeaponProxPrompt" then
            if descendant.Enabled then
                return descendant
            end

            best = best or descendant
        end
    end

    return best
end

local function placePendingWeapon(plot)
    local pending =
        LocalPlayer:GetAttribute("PendingWeapon")

    if type(pending) ~= "string" or pending == "" then
        return false
    end

    local units = plot and plot:FindFirstChild("Units")
    local unit = units and units:FindFirstChild(pending)

    if not unit then
        Runtime.LastDecision =
            "Pending " .. tostring(pending) .. " · waiting for unit"
        return false
    end

    local prompt = findWeaponPlacementPrompt(unit)

    if not prompt then
        Runtime.LastDecision =
            "Pending " .. tostring(pending) .. " · prompt missing"
        return false
    end

    if not prompt.Enabled then
        local started = os.clock()

        repeat
            RunService.Heartbeat:Wait()
            prompt = findWeaponPlacementPrompt(unit)
        until not Runtime.Running
            or not prompt
            or prompt.Enabled
            or os.clock() - started >= 1.5
    end

    if not prompt or not prompt.Enabled then
        Runtime.LastDecision =
            "Pending " .. tostring(pending) .. " · prompt disabled"
        return false
    end

    -- Recheck immediately before the trip so a previous server response cannot
    -- make us interact with a stale unit.
    if LocalPlayer:GetAttribute("PendingWeapon") ~= pending then
        return false
    end

    Runtime.LastWeaponAction = os.clock()
    Runtime.InteractionTarget =
        tostring(pending) .. " / WeaponProxPrompt"

    return triggerPrompt(prompt)
end

local function openWeaponBox(plot)
    if getRawRolledWeapon(plot) then
        return false
    end

    local box = plot and plot:FindFirstChild("WeaponBox")
    local promptPart = box and box:FindFirstChild("ProxPromptPart")
    local prompt = promptPart
        and promptPart:FindFirstChild("WeaponBoxPrompt")

    if not prompt
        or not prompt:IsA("ProximityPrompt")
        or not prompt.Enabled then
        return false
    end

    Runtime.LastWeaponAction = os.clock()
    return triggerPrompt(prompt)
end

local function processWeapons(plot)
    if not Settings.SmartWeapons then
        return
    end

    if os.clock() - Runtime.LastWeaponAction < 0.35 then
        return
    end

    local pending = LocalPlayer:GetAttribute("PendingWeapon")

    if type(pending) == "string" and pending ~= "" then
        placePendingWeapon(plot)
        return
    end

    local rawRolled = getRawRolledWeapon(plot)
    local rolled = getRolledWeapon(plot)

    -- The server/client can parent RolledWeapon before its attributes finish
    -- replicating. Never press Open again while that object already exists.
    if rawRolled and not rolled then
        return
    end

    if not rawRolled then
        Runtime.RollHoldModel = nil
        Runtime.RollHoldSince = 0
    end

    if rolled then
        local decision, reason, kind =
            getWeaponDecision(plot, rolled)

        Runtime.LastDecision = reason or "waiting"

        if decision == "buy" then
            local currency =
                tonumber(LocalPlayer:GetAttribute("currency")) or 0

            if currency < rolled.Cost then
                -- XP duplicates should never freeze the whole roll loop waiting
                -- for money. New guns / higher tiers can optionally wait.
                if kind == "xp" then
                    decision = "discard"
                    Runtime.LastDecision =
                        "Discard unaffordable XP duplicate"
                elseif Settings.WaitForAffordableUpgrade then
                    return
                else
                    -- Never use the game's Robux force-buy product.
                    decision = "discard"
                end
            end
        end

        if decision == "buy" then
            Runtime.LastWeaponAction = os.clock()

            moveIntoWeaponBoxZone(plot, function()
                local stillPending =
                    LocalPlayer:GetAttribute("PendingWeapon")

                local current = getRolledWeapon(plot)

                if (type(stillPending) ~= "string" or stillPending == "")
                    and current
                    and current.Model == rolled.Model then
                    RemoteEvents.WeaponBoxBuy:FireServer()
                end
            end)

            return
        end

        if decision == "discard" then
            Runtime.LastWeaponAction = os.clock()

            moveIntoWeaponBoxZone(plot, function()
                local current = getRolledWeapon(plot)

                if current and current.Model == rolled.Model then
                    RemoteEvents.WeaponBoxDiscard:FireServer()
                end
            end)

            return
        end

        return
    end

    -- If the player owns and has enabled the real AutoRoll gamepass, let the
    -- game's own system manage rolling rather than racing it.
    if LocalPlayer:GetAttribute("GP_AutoRoll") == true then
        return
    end

    openWeaponBox(plot)
end

local function startWaveIfReady(plot)
    if not Settings.AutoStartWaves then
        return
    end

    local wave = plot:GetAttribute("CurrentWave")

    if type(wave) == "number" then
        Runtime.LastWave = math.max(Runtime.LastWave, wave)
        return
    end

    local dps = tonumber(LocalPlayer:GetAttribute("TotalDPS")) or 0

    if dps <= 0 then
        return
    end

    if os.clock() - Runtime.LastWaveStart < 1.2 then
        return
    end

    Runtime.LastWaveStart = os.clock()
    RemoteEvents.WaveControl:FireServer("Start")
end

local function shouldRebirth(plot)
    local currentWave =
        tonumber(plot:GetAttribute("CurrentWave"))

    if currentWave then
        Runtime.LastWave =
            math.max(Runtime.LastWave, currentWave)
    end

    local failed =
        LocalPlayer:GetAttribute("CurrentRunWaveFailed") == true
        or plot:GetAttribute("RunFailed") == true

    if Settings.AutoRebirthFailed
        and failed
        and Runtime.LastWave > 20 then
        -- A failed run cannot reach another milestone without resetting.
        return true
    end

    if Settings.AutoRebirthThreshold
        and currentWave
        and currentWave >= math.max(Settings.RebirthWave, 21)
        and plot:GetAttribute("RebirthRequested") ~= true then

        local nearLuck, _, nextMilestone =
            shouldReserveForProgression(plot)

        if nearLuck
            and nextMilestone
            and currentWave < nextMilestone.Wave then
            return false
        end

        return true
    end

    return false
end

local function processRebirth(plot)
    if not shouldRebirth(plot) then
        return
    end

    if os.clock() - Runtime.LastRebirth < 4 then
        return
    end

    Runtime.LastRebirth = os.clock()

    -- Normal in-game rebirth only.
    RemoteEvents.RebirthButtonPress:FireServer()
end

local function ensureOwnedPass(name)
    if not Settings.UseOwnedGamepasses then
        return
    end

    local owns = LocalPlayer:GetAttribute("OwnsGP_" .. name)
    local active = LocalPlayer:GetAttribute("GP_" .. name)

    if owns == true and active ~= true then
        RemoteEvents.ToggleGamePass:FireServer(name)
        task.wait(0.1)
    end
end

local function processOwnedPasses()
    if not Settings.UseOwnedGamepasses then
        return
    end

    if os.clock() - Runtime.LastPassCheck < 4 then
        return
    end

    Runtime.LastPassCheck = os.clock()

    ensureOwnedPass("DoubleSpeed")
    ensureOwnedPass("AutoLoot")
    ensureOwnedPass("AutoRoll")
end

local function getServerLootFolder(plot)
    local folder = plot and plot:FindFirstChild("LootSpawned")

    if folder and folder:IsA("Folder") then
        return folder
    end

    return folder
end

local function getServerLootNames(plot, limit)
    local folder = getServerLootFolder(plot)

    if not folder then
        return {}
    end

    local names = {}
    local seen = {}

    for _, loot in ipairs(folder:GetChildren()) do
        local name = tostring(loot.Name or "")

        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(names, name)

            if #names >= (limit or math.huge) then
                break
            end
        end
    end

    return names
end

local function testFastLootSupport(plot)
    if Runtime.FastLootTesting
        or Runtime.FastLootSupport ~= nil
        or not Settings.FastLootAutoDetect then
        return
    end

    if os.clock() - Runtime.LastFastLootTest < 2 then
        return
    end

    local folder = getServerLootFolder(plot)
    local loot = folder and folder:GetChildren()[1]

    if not loot then
        return
    end

    Runtime.FastLootTesting = true
    Runtime.LastFastLootTest = os.clock()

    task.spawn(function()
        local name = loot.Name
        local beforeCurrency =
            tonumber(LocalPlayer:GetAttribute("currency")) or 0

        local ok = pcall(function()
            RemoteEvents.CurrencyPickup:FireServer({name})
        end)

        if not ok then
            Runtime.FastLootFailures =
                Runtime.FastLootFailures + 1
            Runtime.FastLootTesting = false

            if Runtime.FastLootFailures >= 2 then
                Runtime.FastLootSupport = false
            end

            return
        end

        local accepted = false
        local started = os.clock()

        while Runtime.Running
            and os.clock() - started < 0.8 do

            local nowCurrency =
                tonumber(LocalPlayer:GetAttribute("currency")) or 0

            if not loot.Parent
                or not folder:FindFirstChild(name)
                or nowCurrency > beforeCurrency then
                accepted = true
                break
            end

            task.wait(0.05)
        end

        if accepted then
            Runtime.FastLootSupport = true
            Runtime.FastLootFailures = 0
            Runtime.LastDecision =
                "Fast own-plot loot batching verified"
        else
            Runtime.FastLootFailures =
                Runtime.FastLootFailures + 1

            if Runtime.FastLootFailures >= 2 then
                Runtime.FastLootSupport = false
                Runtime.LastDecision =
                    "Fast loot rejected · movement fallback"
            end
        end

        Runtime.FastLootTesting = false
    end)
end

local function collectLootFast(plot)
    if not Settings.CollectLoot
        or not Settings.FastLootAutoDetect
        or LocalPlayer:GetAttribute("GP_AutoLoot") == true then
        return false
    end

    if Runtime.FastLootSupport == nil then
        testFastLootSupport(plot)
        return Runtime.FastLootTesting
    end

    if Runtime.FastLootSupport ~= true then
        return false
    end

    if os.clock() - Runtime.LastFastLootBatch < 0.22 then
        return true
    end

    local names =
        getServerLootNames(
            plot,
            math.max(Settings.FastLootBatchSize, 1)
        )

    if #names == 0 then
        return true
    end

    Runtime.LastFastLootBatch = os.clock()

    local ok = pcall(function()
        RemoteEvents.CurrencyPickup:FireServer(names)
    end)

    if ok then
        Runtime.FastLootCollected =
            Runtime.FastLootCollected + #names
        return true
    end

    Runtime.FastLootSupport = false
    Runtime.LastDecision =
        "Fast loot errored · movement fallback"

    return false
end

local function collectLootMovement()
    if not Settings.CollectLoot then
        return
    end

    if LocalPlayer:GetAttribute("GP_AutoLoot") == true then
        return
    end

    local owner = "loot-route"

    if not beginAction(owner) then
        return
    end

    local folder = workspace:FindFirstChild("LootSpawnedClient")
    local root = getCharacterRoot()

    if not folder or not root then
        endAction(owner)
        return
    end

    local candidates = {}

    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model")
            and model:GetAttribute("isLootVisual") == true then

            local part = model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart", true)

            if part then
                table.insert(candidates, {
                    Model = model,
                    Part = part,
                    Distance = (part.Position - root.Position).Magnitude,
                })
            end
        end
    end

    if #candidates == 0 then
        endAction(owner)
        return
    end

    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)

    local original = root.CFrame
    local lock = nil
    local ok, err = pcall(function()
        lock = acquireMovementLock(root)

        local limit =
            math.min(#candidates, Settings.MaxLootPerPass)

        for index = 1, limit do
            if not Runtime.Running
                or not Settings.Master
                or not Settings.CollectLoot then
                break
            end

            local item = candidates[index]

            if item.Model.Parent
                and item.Part.Parent
                and root.Parent then

                local moved =
                    moveRootGroundSafe(
                        root,
                        item.Part.Position,
                        item.Model,
                        Settings.TweenSpeed
                    )

                if moved then
                    task.wait(Settings.LootMoveDelay)
                end
            end
        end

        if root.Parent and Settings.RestorePosition then
            restoreRootPosition(
                root,
                original,
                Settings.TweenSpeed
            )
        end
    end)

    if lock then
        releaseMovementLock(lock)
        lock = nil
    end

    endAction(owner)

    if not ok then
        Runtime.LastError = tostring(err)
    end
end

local function groupRewardLooksReady(groupReward)
    if not groupReward then
        return false
    end

    local sawTimer = false
    local sawReady = false

    for _, object in ipairs(groupReward:GetDescendants()) do
        if object:IsA("TextLabel")
            or object:IsA("TextButton") then

            local text =
                string.lower(tostring(object.Text or ""))

            if text:match("%d+:%d%d") then
                sawTimer = true
            end

            if text:find("ready", 1, true)
                or text:find("claim", 1, true)
                or text:find("collect!", 1, true) then
                sawReady = true
            end
        end
    end

    if sawReady then
        return true
    end

    if sawTimer then
        return false
    end

    -- UI layouts can vary. Server still validates eligibility, so a slow
    -- fallback attempt is harmless.
    return os.clock() - Runtime.LastGroupCheck >= 60
end

local function collectBaseRewards(plot)
    if not Settings.CollectRewards then
        return
    end

    local now = os.clock()

    local offline = plot:FindFirstChild("OfflineIncome")
    local offlinePart =
        offline and offline:FindFirstChild("CollectPart")

    if offlinePart
        and offlinePart:IsA("BasePart")
        and now - Runtime.LastOfflineCheck >= 120 then

        Runtime.LastOfflineCheck = now
        touchPart(offlinePart)
    end

    local groupReward = plot:FindFirstChild("GroupReward")

    if groupReward
        and now - Runtime.LastGroupCheck >= 3
        and groupRewardLooksReady(groupReward) then

        Runtime.LastGroupCheck = now

        local collectButton =
            groupReward:FindFirstChild("CollectButton")

        local buttonPart =
            collectButton
            and (
                collectButton:FindFirstChild("Button")
                or collectButton:FindFirstChild("Base")
                or collectButton:FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )
            )

        if buttonPart and buttonPart:IsA("BasePart") then
            touchPart(buttonPart)
        end
    end
end

local function getEconomyStatus(plot)
    local currency =
        tonumber(LocalPlayer:GetAttribute("currency")) or 0

    local guaranteed =
        getGuaranteedIncome(plot)

    local reserve, target =
        getFutureGunReserve(plot, nil)

    local reserveText =
        target
        and (
            target.Name
            .. " "
            .. compactNumber(reserve)
        )
        or "none"

    return string.format(
        "Income %.1f/s · cash %s · guaranteed %s · reserve %s",
        Runtime.IncomePerSecond or 0,
        compactNumber(currency),
        compactNumber(guaranteed),
        reserveText
    )
end

local function getRebirthPointReward(wave)
    wave = math.max(tonumber(wave) or 0, 0)
    return math.floor(((wave * 0.2) ^ 2.25) + 0.5)
end

local function getRebirthCashReward(wave)
    wave = math.max(tonumber(wave) or 0, 0)
    return math.floor((1.14 ^ wave) * 1500 + 0.5)
end

local function getProgressionStatus(plot)
    local wave = getStrategyWave(plot)
    local currentLuck, nextLuck =
        getLuckMilestoneInfo(wave)

    local bossDistance = getBossDistance(wave)

    local luckText =
        string.format(
            "Luck %.1fx",
            displayLuck(currentLuck.Luck)
        )

    if nextLuck then
        luckText =
            luckText
            .. " · next W"
            .. tostring(nextLuck.Wave)
            .. " = "
            .. string.format(
                "%.1fx",
                displayLuck(nextLuck.Luck)
            )
    else
        luckText = luckText .. " · max milestone"
    end

    local bossText =
        bossDistance == 0
        and "Boss wave"
        or ("Boss in " .. tostring(bossDistance))

    local rebirthText =
        wave > 20
        and (
            " · rebirth "
            .. compactNumber(getRebirthPointReward(wave))
            .. " pts / "
            .. compactNumber(getRebirthCashReward(wave))
            .. " cash"
        )
        or ""

    return luckText .. " · " .. bossText .. rebirthText
end

local function getRollStatus(plot)
    local pending = LocalPlayer:GetAttribute("PendingWeapon")

    if type(pending) == "string" and pending ~= "" then
        local tier =
            tonumber(LocalPlayer:GetAttribute("PendingWeaponTier")) or 1

        return string.format(
            "Pending %s %s",
            TIER_NAMES[math.clamp(math.floor(tier), 1, 4)] or ("T" .. tostring(tier)),
            pending
        )
    end

    local rawRolled = getRawRolledWeapon(plot)
    local rolled = getRolledWeapon(plot)

    if rawRolled and not rolled then
        return "Roll is replicating..."
    end

    if rolled then
        local decision, reason = getWeaponDecision(plot, rolled)
        local rarity = RARITY_NAMES[getUnitRarity(rolled.Name)] or "Unknown"

        local xpText =
            rolled.DuplicateXP > 0
            and (" · +" .. tostring(rolled.DuplicateXP) .. " XP")
            or ""

        return string.format(
            "%s %s · %s · $%s%s · %s",
            TIER_NAMES[rolled.Tier] or ("T" .. tostring(rolled.Tier)),
            rarity,
            rolled.Name,
            tostring(math.floor(rolled.Cost + 0.5)),
            xpText,
            reason
        )
    end

    return "No pending roll · " .. tostring(Runtime.LastDecision)
end

-- ============================================================================
-- Executor-compatible PuckUI loader
-- ============================================================================

local Compat = {}

function Compat.getCompiler()
    if type(loadstring) == "function" then
        return loadstring, "loadstring"
    end

    if type(load) == "function" then
        return load, "load"
    end

    return nil, "none"
end

function Compat.httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if ok and type(body) == "string" and #body > 100 then
        return body, "game:HttpGet"
    end

    local requesters = {}

    if type(request) == "function" then
        table.insert(requesters, {"request", request})
    end

    if type(http_request) == "function" then
        table.insert(requesters, {"http_request", http_request})
    end

    if type(syn) == "table" and type(syn.request) == "function" then
        table.insert(requesters, {"syn.request", syn.request})
    end

    if type(http) == "table" and type(http.request) == "function" then
        table.insert(requesters, {"http.request", http.request})
    end

    for _, item in ipairs(requesters) do
        local success, response = pcall(item[2], {
            Url = url,
            Method = "GET",
        })

        if success and type(response) == "table" then
            local responseBody = response.Body or response.body
            local status =
                tonumber(response.StatusCode or response.Status or 200) or 200

            if status >= 200
                and status < 300
                and type(responseBody) == "string"
                and #responseBody > 100 then
                return responseBody, item[1]
            end
        end
    end

    return nil, "unavailable"
end

local compiler, compilerName = Compat.getCompiler()

if not compiler then
    abortBeforeWindow("No loadstring/load compiler available.")
    return
end

local uiSource, httpName = Compat.httpGet(
    "https://raw.githubusercontent.com/RAINZXDEV/Puck-Loader/main/ui/PuckUI.lua"
)

if not uiSource then
    abortBeforeWindow("Could not download PuckUI.")
    return
end

-- Compatibility normalization for stricter executor parsers.
uiSource = uiSource:gsub("column%s*%+=%s*1", "column = column + 1")
uiSource = uiSource:gsub("row%s*%+=%s*1", "row = row + 1")
uiSource = uiSource:gsub("suffix%s*%+=%s*1", "suffix = suffix + 1")

local compileOk, chunk, compileError = pcall(
    compiler,
    uiSource,
    "@RAINZXDEV/PuckUI.lua"
)

if not compileOk or type(chunk) ~= "function" then
    abortBeforeWindow("PuckUI compile failed: " .. tostring(chunk or compileError))
    return
end

local uiOk, PuckUI = pcall(chunk)

if not uiOk
    or type(PuckUI) ~= "table"
    or type(PuckUI.CreateWindow) ~= "function" then
    abortBeforeWindow("PuckUI execution failed: " .. tostring(PuckUI))
    return
end

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV Hub · Build a Gun Army",
    GuiName = "RAINZXDEV_BuildAGunArmy",
    ConfigId = "BuildAGunArmy",
    Width = 520,
    Height = 590,
})

Runtime.Window = Window

local FarmTab = Window:CreateTab("Autofarm")
local WeaponsTab = Window:CreateTab("Weapons")
local ProgressTab = Window:CreateTab("Progression")
local SettingsTab = Window:CreateTab("Settings")

FarmTab:CreateSection("Main Farm")

FarmTab:CreateToggle({
    Name = "Master Autofarm",
    CurrentValue = Settings.Master,
    Flag = "MasterAutofarm",
    Callback = function(value)
        Settings.Master = value == true
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Start Waves",
    CurrentValue = Settings.AutoStartWaves,
    Flag = "AutoStartWaves",
    Callback = function(value)
        Settings.AutoStartWaves = value == true
    end,
})

FarmTab:CreateToggle({
    Name = "Movement Loot Collector",
    CurrentValue = Settings.CollectLoot,
    Flag = "MovementLoot",
    Callback = function(value)
        Settings.CollectLoot = value == true
    end,
})


FarmTab:CreateToggle({
    Name = "Auto-Test Fast Own-Plot Loot",
    CurrentValue = Settings.FastLootAutoDetect,
    Flag = "FastLootAutoDetect",
    Callback = function(value)
        Settings.FastLootAutoDetect = value == true

        if not Settings.FastLootAutoDetect then
            Runtime.FastLootSupport = false
        elseif Runtime.FastLootFailures < 2 then
            Runtime.FastLootSupport = nil
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Fast Loot Batch Size",
    Range = {5, 100},
    Increment = 5,
    CurrentValue = Settings.FastLootBatchSize,
    Flag = "FastLootBatchSize",
    Callback = function(value)
        Settings.FastLootBatchSize =
            math.max(math.floor(value), 5)
    end,
})

FarmTab:CreateLabel(
    "Fast loot only sends real loot IDs from your own Plot.LootSpawned. It auto-tests one ID first; rejected servers fall back to movement collection."
)

FarmTab:CreateToggle({
    Name = "Collect Offline / Group Rewards",
    CurrentValue = Settings.CollectRewards,
    Flag = "CollectRewards",
    Callback = function(value)
        Settings.CollectRewards = value == true
    end,
})

FarmTab:CreateToggle({
    Name = "Use Owned Gamepass Toggles",
    CurrentValue = Settings.UseOwnedGamepasses,
    Flag = "UseOwnedGamepasses",
    Callback = function(value)
        Settings.UseOwnedGamepasses = value == true
    end,
})

FarmTab:CreateLabel(
    "Paid ownership is never spoofed. Owned DoubleSpeed / AutoLoot / AutoRoll can only be toggled if OwnsGP_* is already true."
)

FarmTab:CreateSection("Live Status")

local PlotLabel = FarmTab:CreateLabel("Plot • searching...")
local WaveLabel = FarmTab:CreateLabel("Wave • -")
local DPSLabel = FarmTab:CreateLabel("DPS • -")
local CashLabel = FarmTab:CreateLabel("Cash • -")
local FarmStatusLabel = FarmTab:CreateLabel("Farm • idle")
local LootModeLabel = FarmTab:CreateLabel("Loot mode • detecting")
local DecisionLabel = FarmTab:CreateLabel("Decision • waiting")

WeaponsTab:CreateSection("Smart Weapon Progression")

WeaponsTab:CreateDropdown({
    Name = "Farm Strategy",
    Options = {"Balanced", "Luck Rush", "XP Focus", "Collection"},
    CurrentOption = {Settings.Strategy},
    Flag = "FarmStrategy",
    Callback = function(option)
        local value =
            type(option) == "table" and option[1] or option

        if value then
            Settings.Strategy = tostring(value)
        end
    end,
})

WeaponsTab:CreateToggle({
    Name = "Smart Roll / Buy / Place",
    CurrentValue = Settings.SmartWeapons,
    Flag = "SmartWeapons",
    Callback = function(value)
        Settings.SmartWeapons = value == true
    end,
})

WeaponsTab:CreateToggle({
    Name = "Wait For Affordable Upgrade",
    CurrentValue = Settings.WaitForAffordableUpgrade,
    Flag = "WaitAffordableUpgrade",
    Callback = function(value)
        Settings.WaitForAffordableUpgrade = value == true
    end,
})


WeaponsTab:CreateToggle({
    Name = "Buy Useful Duplicate XP",
    CurrentValue = Settings.AutoDuplicateXP,
    Flag = "AutoDuplicateXP",
    Callback = function(value)
        Settings.AutoDuplicateXP = value == true
    end,
})

WeaponsTab:CreateSlider({
    Name = "Duplicate XP Cash Budget",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = Settings.DuplicateSpendPercent,
    Suffix = "%",
    Flag = "DuplicateSpendPercent",
    Callback = function(value)
        Settings.DuplicateSpendPercent =
            math.clamp(tonumber(value) or 18, 1, 100)
    end,
})

WeaponsTab:CreateSlider({
    Name = "Near-Level XP Priority",
    Range = {25, 95},
    Increment = 5,
    CurrentValue = Settings.NearLevelThreshold * 100,
    Suffix = "%",
    Flag = "NearLevelThreshold",
    Callback = function(value)
        Settings.NearLevelThreshold =
            math.clamp((tonumber(value) or 72) / 100, 0.25, 0.95)
    end,
})

WeaponsTab:CreateLabel(
    "New guns and higher tiers are always priority. Duplicate rolls are valued from the game's real +XP text, current level, XP bar, DPS share, cash budget, boss distance and luck milestone."
)

local RollLabel = WeaponsTab:CreateLabel("Weapon box • waiting for plot")

WeaponsTab:CreateSection("Economy Planner")

WeaponsTab:CreateToggle({
    Name = "Protect Unowned Gun Rolls",
    CurrentValue = Settings.ProtectUnownedRolls,
    Flag = "ProtectUnownedRolls",
    Callback = function(value)
        Settings.ProtectUnownedRolls = value == true
    end,
})

WeaponsTab:CreateSlider({
    Name = "Rare Roll Base Hold Time",
    Range = {20, 180},
    Increment = 5,
    CurrentValue = Settings.NewGunBaseHoldSeconds,
    Suffix = " s",
    Flag = "NewGunBaseHoldSeconds",
    Callback = function(value)
        Settings.NewGunBaseHoldSeconds =
            math.clamp(
                tonumber(value) or 75,
                20,
                180
            )
    end,
})

WeaponsTab:CreateToggle({
    Name = "Reserve Cash For Next Unowned Gun",
    CurrentValue = Settings.FutureGunReserve,
    Flag = "FutureGunReserve",
    Callback = function(value)
        Settings.FutureGunReserve = value == true
    end,
})

WeaponsTab:CreateSlider({
    Name = "Next Gun Reserve",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = Settings.FutureReservePercent,
    Suffix = "%",
    Flag = "FutureReservePercent",
    Callback = function(value)
        Settings.FutureReservePercent =
            math.clamp(
                tonumber(value) or 70,
                0,
                100
            )
    end,
})

WeaponsTab:CreateSlider({
    Name = "Max Tier Upgrade Payback",
    Range = {20, 240},
    Increment = 10,
    CurrentValue = Settings.MaxUpgradePaybackSeconds,
    Suffix = " s",
    Flag = "MaxUpgradePaybackSeconds",
    Callback = function(value)
        Settings.MaxUpgradePaybackSeconds =
            math.clamp(
                tonumber(value) or 90,
                20,
                240
            )
    end,
})

WeaponsTab:CreateToggle({
    Name = "Break Reserve For Major Upgrade",
    CurrentValue = Settings.StrategicReserveBreak,
    Flag = "StrategicReserveBreak",
    Callback = function(value)
        Settings.StrategicReserveBreak = value == true
    end,
})

local EconomyLabel =
    WeaponsTab:CreateLabel("Economy • waiting for plot")

local EconomyDecisionLabel =
    WeaponsTab:CreateLabel("Plan • waiting")

WeaponsTab:CreateLabel(
    "New/unowned station rolls are protected using current cash, guaranteed live enemy loot and measured income/sec. Existing tier upgrades use estimated DPS gain/payback; duplicate XP normally cannot consume the next-gun reserve."
)

WeaponsTab:CreateSection("Detected Gun System")

WeaponsTab:CreateLabel("42 guns · 7 rarities · 6 guns per rarity")
WeaponsTab:CreateLabel("Tier DPS: Normal x1 · Shiny x2 · Electric x5 · Cosmic x15")
WeaponsTab:CreateLabel("Tier costs: x1 · x12 · x180 · x3000")

ProgressTab:CreateSection("Rebirth")

ProgressTab:CreateToggle({
    Name = "Auto Rebirth On Failed Run",
    CurrentValue = Settings.AutoRebirthFailed,
    Flag = "AutoRebirthFailed",
    Callback = function(value)
        Settings.AutoRebirthFailed = value == true
    end,
})

ProgressTab:CreateToggle({
    Name = "Request Rebirth At Wave",
    CurrentValue = Settings.AutoRebirthThreshold,
    Flag = "AutoRebirthThreshold",
    Callback = function(value)
        Settings.AutoRebirthThreshold = value == true
    end,
})

ProgressTab:CreateSlider({
    Name = "Rebirth Wave",
    Range = {21, 200},
    Increment = 1,
    CurrentValue = Settings.RebirthWave,
    Flag = "RebirthWave",
    Callback = function(value)
        Settings.RebirthWave = math.max(math.floor(value), 21)
    end,
})

ProgressTab:CreateLabel(
    "Uses only RebirthButtonPress. The Robux skip-rebirth and force-buy paths are not used."
)

ProgressTab:CreateSection("Luck / Boss Strategy")

ProgressTab:CreateToggle({
    Name = "Hold Rebirth Near Luck Milestone",
    CurrentValue = Settings.LuckMilestoneHold,
    Flag = "LuckMilestoneHold",
    Callback = function(value)
        Settings.LuckMilestoneHold = value == true
    end,
})

ProgressTab:CreateSlider({
    Name = "Luck Milestone Hold Distance",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = Settings.MilestoneHoldWaves,
    Suffix = " waves",
    Flag = "MilestoneHoldWaves",
    Callback = function(value)
        Settings.MilestoneHoldWaves =
            math.max(math.floor(value), 1)
    end,
})

ProgressTab:CreateSlider({
    Name = "Boss Cash Reserve Distance",
    Range = {0, 5},
    Increment = 1,
    CurrentValue = Settings.BossReserveWaves,
    Suffix = " waves",
    Flag = "BossReserveWaves",
    Callback = function(value)
        Settings.BossReserveWaves =
            math.max(math.floor(value), 0)
    end,
})

local ProgressionLabel =
    ProgressTab:CreateLabel("Luck / boss • waiting for plot")

ProgressTab:CreateSection("Wave Information")

ProgressTab:CreateLabel("Boss every 20 waves")
ProgressTab:CreateLabel("Rebirth minimum: after wave 20")
ProgressTab:CreateLabel("Each rebirth point adds +2% coin value")

SettingsTab:CreateSection("Movement")

SettingsTab:CreateToggle({
    Name = "Tween Movement",
    CurrentValue = Settings.TweenMovement,
    Flag = "TweenMovement",
    Callback = function(value)
        Settings.TweenMovement = value == true
    end,
})

SettingsTab:CreateSlider({
    Name = "Tween Speed",
    Range = {10, 80},
    Increment = 1,
    CurrentValue = Settings.TweenSpeed,
    Suffix = " studs/s",
    Flag = "TweenSpeed",
    Callback = function(value)
        Settings.TweenSpeed =
            math.clamp(tonumber(value) or 38, 10, 80)
    end,
})

SettingsTab:CreateToggle({
    Name = "Follow Ground Height",
    CurrentValue = Settings.GroundFollow,
    Flag = "GroundFollow",
    Callback = function(value)
        Settings.GroundFollow = value == true
    end,
})

SettingsTab:CreateSlider({
    Name = "Ground Clearance",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = Settings.GroundClearance,
    Suffix = " studs",
    Flag = "GroundClearance",
    Callback = function(value)
        Settings.GroundClearance =
            math.clamp(
                tonumber(value) or 0.12,
                0,
                1
            )
    end,
})

SettingsTab:CreateSlider({
    Name = "Downhill Height Smoothing",
    Range = {6, 30},
    Increment = 1,
    CurrentValue = Settings.GroundYSmoothing,
    Flag = "GroundYSmoothing",
    Callback = function(value)
        Settings.GroundYSmoothing =
            math.clamp(
                tonumber(value) or 18,
                6,
                30
            )
    end,
})

SettingsTab:CreateSection("Gun Placement Navigation")

SettingsTab:CreateToggle({
    Name = "Pathfind Around Other Guns",
    CurrentValue = Settings.PromptPathfinding,
    Flag = "PromptPathfinding",
    Callback = function(value)
        Settings.PromptPathfinding = value == true
    end,
})

SettingsTab:CreateSlider({
    Name = "Gun Interaction Ring Samples",
    Range = {8, 24},
    Increment = 2,
    CurrentValue = Settings.PromptRingSamples,
    Flag = "PromptRingSamples",
    Callback = function(value)
        Settings.PromptRingSamples =
            math.clamp(
                math.floor(tonumber(value) or 14),
                8,
                24
            )
    end,
})

SettingsTab:CreateSlider({
    Name = "Gun Clearance Radius",
    Range = {1, 2.5},
    Increment = 0.1,
    CurrentValue = Settings.PromptClearanceRadius,
    Suffix = " studs",
    Flag = "PromptClearanceRadius",
    Callback = function(value)
        Settings.PromptClearanceRadius =
            math.clamp(
                tonumber(value) or 1.5,
                1,
                2.5
            )
    end,
})

SettingsTab:CreateLabel(
    "Gun placement/upgrades stop at a clear point around the selected gun, inside the prompt's real activation distance. Pathfinding routes around neighboring placed guns instead of trying to tween through them."
)


SettingsTab:CreateSlider({
    Name = "Prompt Settle Time",
    Range = {0.05, 0.60},
    Increment = 0.05,
    CurrentValue = Settings.PromptSettleTime,
    Suffix = " s",
    Flag = "PromptSettleTime",
    Callback = function(value)
        Settings.PromptSettleTime =
            math.clamp(
                tonumber(value) or 0.22,
                0.05,
                0.60
            )
    end,
})

SettingsTab:CreateSlider({
    Name = "Prompt Input Retries",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = Settings.PromptInputRetries,
    Flag = "PromptInputRetries",
    Callback = function(value)
        Settings.PromptInputRetries =
            math.clamp(
                math.floor(tonumber(value) or 3),
                1,
                5
            )
    end,
})

SettingsTab:CreateSlider({
    Name = "Alternate Gun Positions",
    Range = {1, 8},
    Increment = 1,
    CurrentValue = Settings.PromptAlternatePositions,
    Flag = "PromptAlternatePositions",
    Callback = function(value)
        Settings.PromptAlternatePositions =
            math.clamp(
                math.floor(tonumber(value) or 5),
                1,
                8
            )
    end,
})

SettingsTab:CreateSlider({
    Name = "Prompt Ready Timeout",
    Range = {0.3, 1.5},
    Increment = 0.05,
    CurrentValue = Settings.PromptReadyTimeout,
    Suffix = " s",
    Flag = "PromptReadyTimeout",
    Callback = function(value)
        Settings.PromptReadyTimeout =
            math.clamp(
                tonumber(value) or 0.85,
                0.3,
                1.5
            )
    end,
})

local PromptInputLabel =
    SettingsTab:CreateLabel(
        "Prompt input • waiting"
    )


local InteractionLabel =
    SettingsTab:CreateLabel(
        "Interaction • Idle"
    )

local InteractionDetailLabel =
    SettingsTab:CreateLabel(
        "Target • none"
    )

SettingsTab:CreateToggle({
    Name = "Tween Back After Action",
    CurrentValue = Settings.TweenReturn,
    Flag = "TweenReturn",
    Callback = function(value)
        Settings.TweenReturn = value == true
    end,
})

SettingsTab:CreateLabel(
    "Ground-follow tween raycasts below every travel point and keeps the HumanoidRootPart at the character's real standing height. The root is temporarily anchored during travel so Humanoid physics cannot fight the tween or shake the camera."
)

SettingsTab:CreateSlider({
    Name = "Loot Move Delay",
    Range = {0.05, 0.30},
    Increment = 0.01,
    CurrentValue = Settings.LootMoveDelay,
    Suffix = " s",
    Flag = "LootMoveDelay",
    Callback = function(value)
        Settings.LootMoveDelay = math.max(tonumber(value) or 0.08, 0.05)
    end,
})

SettingsTab:CreateSlider({
    Name = "Loot Per Pass",
    Range = {1, 40},
    Increment = 1,
    CurrentValue = Settings.MaxLootPerPass,
    Flag = "LootPerPass",
    Callback = function(value)
        Settings.MaxLootPerPass = math.max(math.floor(value), 1)
    end,
})

SettingsTab:CreateToggle({
    Name = "Restore Position After Actions",
    CurrentValue = Settings.RestorePosition,
    Flag = "RestorePosition",
    Callback = function(value)
        Settings.RestorePosition = value == true
    end,
})

SettingsTab:CreateSection("Runtime")

SettingsTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = Settings.AntiAFK,
    Flag = "AntiAFK",
    Callback = function(value)
        Settings.AntiAFK = value == true
    end,
})

SettingsTab:CreateLabel(
    "Executor • compiler "
    .. tostring(compilerName)
    .. " · HTTP "
    .. tostring(httpName)
)

SettingsTab:CreateButton({
    Name = "Refresh Plot",
    Callback = function()
        Runtime.Plot = nil
        getPlot()
    end,
})

local ErrorLabel = SettingsTab:CreateLabel("Last error • none")

local cleanup

cleanup = function()
    if not Runtime.Running then
        return
    end

    Runtime.Running = false

    local cleanupRoot = getCharacterRoot()

    if cleanupRoot and cleanupRoot.Parent then
        pcall(function()
            cleanupRoot.Anchored = false
            cleanupRoot.AssemblyLinearVelocity = Vector3.zero
            cleanupRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    Runtime.ActionOwner = nil
    Runtime.ActionStartedAt = 0
    Runtime.Moving = false

    for _, connection in ipairs(Runtime.Connections) do
        safeDisconnect(connection)
    end

    table.clear(Runtime.Connections)

    if ENV.__rainzxdev_BUILD_GUN_ARMY_CLEANUP == cleanup then
        ENV.__rainzxdev_BUILD_GUN_ARMY_CLEANUP = nil
    end

    if Runtime.Window then
        local window = Runtime.Window
        Runtime.Window = nil

        pcall(function()
            window:Destroy()
        end)
    end
end

ENV.__rainzxdev_BUILD_GUN_ARMY_CLEANUP = cleanup

Window:SetCloseCallback(function()
    cleanup()
end)

SettingsTab:CreateButton({
    Name = "Unload Build a Gun Army",
    Callback = function()
        cleanup()
    end,
})

-- ============================================================================
-- Workers
-- ============================================================================

addConnection(LocalPlayer.CharacterAdded:Connect(function()
    Runtime.ActionOwner = nil
    Runtime.ActionStartedAt = 0
    Runtime.Moving = false
    setInteractionState("Idle", "none", 0, "respawn")
end))

addConnection(LocalPlayer.Idled:Connect(function()
    if not Settings.AntiAFK then
        return
    end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(
            Vector2.new(0, 0),
            workspace.CurrentCamera.CFrame
        )
        task.wait(0.1)
        VirtualUser:Button2Up(
            Vector2.new(0, 0),
            workspace.CurrentCamera.CFrame
        )
    end)
end))

task.spawn(function()
    while Runtime.Running do
        if Runtime.ActionOwner
            and Runtime.ActionStartedAt > 0
            and os.clock() - Runtime.ActionStartedAt > 18 then

            local root = getCharacterRoot()

            if root and root.Parent and root.Anchored then
                pcall(function()
                    root.Anchored = false
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
            end

            Runtime.LastError =
                "Recovered stale action lock: "
                .. tostring(Runtime.ActionOwner)

            Runtime.ActionOwner = nil
            Runtime.ActionStartedAt = 0
            Runtime.Moving = false
            setInteractionState("Idle", "none", 0, "watchdog recovery")
        end

        task.wait(1)
    end
end)

task.spawn(function()
    while Runtime.Running do
        local plot = getPlot()

        if Settings.Master and plot then
            local ok, err = pcall(function()
                processOwnedPasses()
                processRebirth(plot)
                startWaveIfReady(plot)
                processWeapons(plot)
                collectBaseRewards(plot)
            end)

            if not ok then
                Runtime.LastError = tostring(err)
            end
        end

        task.wait(0.18)
    end
end)

task.spawn(function()
    while Runtime.Running do
        if Settings.Master then
            local plot = getPlot()

            local ok, err = pcall(function()
                local handledFast =
                    plot and collectLootFast(plot)

                if not handledFast then
                    collectLootMovement()
                end
            end)

            if not ok then
                Runtime.LastError = tostring(err)
            end
        end

        task.wait(0.12)
    end
end)

task.spawn(function()
    while Runtime.Running do
        if os.clock() - Runtime.LastStatus >= 0.5 then
            Runtime.LastStatus = os.clock()
            updateIncomeTracker()

            local plot = getPlot()

            if plot then
                local currentWave = plot:GetAttribute("CurrentWave")
                local waveText =
                    type(currentWave) == "number"
                    and tostring(math.floor(currentWave))
                    or "between runs"

                local currency =
                    tonumber(LocalPlayer:GetAttribute("currency")) or 0

                local dps =
                    tonumber(LocalPlayer:GetAttribute("TotalDPS")) or 0

                pcall(function()
                    PlotLabel:Set("Plot • " .. tostring(plot.Name))
                    WaveLabel:Set(
                        "Wave • "
                        .. waveText
                        .. " · progress "
                        .. string.format(
                            "%.0f%%",
                            (tonumber(plot:GetAttribute("WaveProgress")) or 0) * 100
                        )
                    )
                    DPSLabel:Set("DPS • " .. tostring(math.floor(dps + 0.5)))
                    CashLabel:Set("Cash • " .. tostring(math.floor(currency + 0.5)))
                    RollLabel:Set("Weapon box • " .. getRollStatus(plot))
                    EconomyLabel:Set(
                        "Economy • "
                        .. getEconomyStatus(plot)
                    )
                    EconomyDecisionLabel:Set(
                        "Plan • "
                        .. tostring(Runtime.LastEconomy)
                    )
                    ProgressionLabel:Set(
                        "Luck / boss • "
                        .. getProgressionStatus(plot)
                    )

                    local lootMode =
                        LocalPlayer:GetAttribute("GP_AutoLoot") == true
                        and "owned AutoLoot"
                        or (
                            Runtime.FastLootSupport == true
                            and "fast own-plot batch"
                            or (
                                Runtime.FastLootTesting
                                and "testing fast batch"
                                or (
                                    Runtime.FastLootSupport == false
                                    and "movement fallback"
                                    or "waiting to test"
                                )
                            )
                        )

                    LootModeLabel:Set(
                        "Loot mode • "
                        .. lootMode
                        .. " · batched "
                        .. tostring(Runtime.FastLootCollected)
                    )

                    DecisionLabel:Set(
                        "Decision • "
                        .. tostring(Runtime.LastDecision)
                    )

                    FarmStatusLabel:Set(
                        "Farm • "
                        .. (
                            Settings.Master
                            and "running"
                            or "stopped"
                        )
                        .. " · strategy "
                        .. tostring(Settings.Strategy)
                        .. " · loot "
                        .. tostring(
                            workspace:FindFirstChild("LootSpawnedClient")
                            and #workspace.LootSpawnedClient:GetChildren()
                            or 0
                        )
                    )
                end)
            else
                pcall(function()
                    PlotLabel:Set("Plot • searching...")
                    FarmStatusLabel:Set("Farm • waiting for owned plot")
                end)
            end

            pcall(function()
                PromptInputLabel:Set(
                    "Prompt input • "
                    .. tostring(Runtime.LastPromptMethod)
                    .. " · "
                    .. tostring(Runtime.LastPromptResult)
                )

                InteractionLabel:Set(
                    "Interaction • "
                    .. tostring(Runtime.InteractionState)
                    .. " · attempt "
                    .. tostring(Runtime.InteractionAttempt)
                    .. " · distance "
                    .. string.format(
                        "%.2f",
                        tonumber(Runtime.InteractionDistance) or 0
                    )
                    .. " · enabled "
                    .. tostring(Runtime.InteractionPromptEnabled)
                )

                InteractionDetailLabel:Set(
                    "Target • "
                    .. tostring(Runtime.InteractionTarget)
                    .. " · path "
                    .. tostring(Runtime.InteractionPathStatus)
                    .. " · pending "
                    .. tostring(
                        LocalPlayer:GetAttribute("PendingWeapon")
                        or "none"
                    )
                )

                ErrorLabel:Set(
                    "Last error • "
                    .. (
                        Runtime.LastError ~= ""
                        and Runtime.LastError
                        or "none"
                    )
                )
            end)
        end

        task.wait(0.2)
    end
end)

PuckUI:Notify({
    Title = "Build a Gun Army",
    Content = "Autofarm v3.0 loaded · full interaction state machine and silent console mode enabled.",
    Duration = 3,
})
