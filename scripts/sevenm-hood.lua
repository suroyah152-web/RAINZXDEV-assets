-- RAINZXDEV Hub · Aim / ESP · PuckUI v3.3.1 Edition
-- RAINZXDEV Hub UI + human/model target discovery.

local PuckUI = (function()
    --[[
        PuckUI v3.3 - RAINZXDEV Hub / Global Settings Keybind
        Shared RAINZXDEV game-script UI.
    
        Combined from both supplied PuckUI variants:
          - Uses the fuller v2.2 control/API implementation as the functional base
          - Uses the tighter v3.0 "Exact Replica" palette and visual treatment
          - Keeps notifications, close/minimize, labels, paragraphs, dividers,
            inputs, refreshable dropdowns, setters/getters, and touch support
          - Keeps the compact dark RAINZXDEV Hub presentation
    ]]
    
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local TextService = game:GetService("TextService")
    
    local LocalPlayer = Players.LocalPlayer
    
    local PuckUI = {
        Version = "3.3.1",
        Flags = {},
        Window = nil,
    }
    
    local Theme = {
        -- v3 "Exact Replica" palette
        Main = Color3.fromRGB(12, 12, 12),
        Top = Color3.fromRGB(12, 12, 12),
        Tab = Color3.fromRGB(12, 12, 12),
        Section = Color3.fromRGB(18, 18, 18),
        SectionInner = Color3.fromRGB(18, 18, 18),
        Element = Color3.fromRGB(24, 24, 24),
        ElementHover = Color3.fromRGB(32, 32, 32),
        Border = Color3.fromRGB(45, 45, 45),
        BorderDark = Color3.fromRGB(5, 5, 5),
        Text = Color3.fromRGB(170, 170, 170),
        DimText = Color3.fromRGB(100, 100, 100),
        BrightText = Color3.fromRGB(230, 230, 230),
        Accent = Color3.fromRGB(0, 95, 255),
    
        -- Kept from the fuller build for APIs/notifications that use semantic colors.
        Danger = Color3.fromRGB(180, 58, 64),
        Success = Color3.fromRGB(48, 145, 78),
    }
    
    PuckUI.Theme = Theme
    
    -- One keybind state shared by every RAINZXDEV UI loaded in this Roblox session.
    -- Changing it from any script's Settings tab immediately updates every other
    -- currently-loaded PuckUI window as well.
    local function getSharedEnvironment()
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" then
                return env
            end
        end
    
        return _G
    end
    
    local SharedEnvironment = getSharedEnvironment()
    SharedEnvironment.__rainzxdev_UI_SHARED_STATE =
        SharedEnvironment.__rainzxdev_UI_SHARED_STATE
        or {
            ToggleKeyName = "K",
            Windows = setmetatable({}, {__mode = "k"}),
            CapturingWindow = nil,
            CapturingControl = nil,
            SuppressToggleUntil = 0,
        }
    
    local SharedUIState = SharedEnvironment.__rainzxdev_UI_SHARED_STATE
    SharedUIState.ToggleKeyName = SharedUIState.ToggleKeyName or "K"
    SharedUIState.Windows = SharedUIState.Windows or setmetatable({}, {__mode = "k"})
    SharedUIState.SuppressToggleUntil = SharedUIState.SuppressToggleUntil or 0
    
    local function create(className, properties)
        local object = Instance.new(className)
        for key, value in pairs(properties or {}) do
            object[key] = value
        end
        return object
    end
    
    local function tween(object, duration, properties)
        local animation = TweenService:Create(
            object,
            TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            properties
        )
        animation:Play()
        return animation
    end
    
    local function codeLabel(parent, text, size, color, zIndex)
        return create("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = tostring(text or ""),
            TextColor3 = color or Theme.Text,
            TextSize = size or 12,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = zIndex or 4,
            Parent = parent,
        })
    end
    
    local function getGuiParent(screenGui)
        -- Prefer PlayerGui. Some executor/plugin environments allow the initial
        -- load thread to touch CoreGui/gethui(), but later task.spawn callbacks run
        -- with a lower capability and then fail when updating those descendants.
        -- PlayerGui keeps every UI instance accessible from normal game threads.
        local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui and LocalPlayer then
            playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
        end
    
        if playerGui then
            local ok = pcall(function()
                screenGui.Parent = playerGui
            end)
            if ok and screenGui.Parent == playerGui then
                return playerGui
            end
        end
    
        -- Compatibility fallback only when PlayerGui is genuinely unavailable.
        if type(gethui) == "function" then
            local ok, target = pcall(gethui)
            if ok and target then
                local parented = pcall(function()
                    screenGui.Parent = target
                end)
                if parented then
                    return target
                end
            end
        end
    
        return nil
    end
    
    local function normalizeDropdownValue(value)
        if type(value) == "table" then
            return value[1]
        end
        return value
    end
    
    local function safeCallback(callback, ...)
        if type(callback) == "function" then
            task.spawn(callback, ...)
        end
    end
    
    -- Runtime-safe property update for live labels/paragraphs. This is intentionally
    -- used by public Set() methods because they are often called from farm worker
    -- threads long after the UI was created.
    local function safeSet(instance, property, value)
        if not instance then
            return false
        end
    
        local ok = pcall(function()
            instance[property] = value
        end)
        return ok
    end
    
    local function setHover(button, normal, hover)
        button.MouseEnter:Connect(function()
            if button.Parent then
                tween(button, 0.08, {BackgroundColor3 = hover})
            end
        end)
        button.MouseLeave:Connect(function()
            if button.Parent then
                tween(button, 0.08, {BackgroundColor3 = normal})
            end
        end)
    end
    
    local function getCurrentSection(tab)
        if tab._currentSection then
            return tab._currentSection
        end
        return tab:CreateSection("Main")
    end
    
    function PuckUI:SetAccent(color)
        if typeof(color) ~= "Color3" then
            return
        end
    
        Theme.Accent = color
    
        local window = self.Window
        if not window then
            return
        end
    
        for _, object in ipairs(window.AccentObjects or {}) do
            if object and object.Parent then
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    object.TextColor3 = color
                elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                    object.ImageColor3 = color
                elseif object:IsA("GuiObject") then
                    object.BackgroundColor3 = color
                end
            end
        end
    
        if window.CurrentTab and window.CurrentTab.Highlight then
            window.CurrentTab.Highlight.BackgroundColor3 = color
        end
    end
    
    function PuckUI:Notify(data)
        local window = self.Window
        if not window or not window.ScreenGui or not window.ScreenGui.Parent then
            return
        end
    
        data = data or {}
    
        local toast = create("Frame", {
            Size = UDim2.fromOffset(280, 56),
            BackgroundColor3 = Theme.Section,
            BorderColor3 = Theme.Border,
            BorderSizePixel = 1,
            ZIndex = 700,
            Parent = window.NotificationHolder,
        })
    
        create("Frame", {
            Position = UDim2.fromOffset(1, 1),
            Size = UDim2.new(1, -2, 1, -2),
            BackgroundTransparency = 1,
            BorderColor3 = Theme.BorderDark,
            BorderSizePixel = 1,
            ZIndex = 701,
            Parent = toast,
        })
    
        local accent = create("Frame", {
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.new(0, 2, 1, -8),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 702,
            Parent = toast,
        })
        table.insert(window.AccentObjects, accent)
    
        local title = codeLabel(toast, data.Title or "RAINZXDEV", 12, Theme.BrightText, 703)
        title.Position = UDim2.fromOffset(12, 5)
        title.Size = UDim2.new(1, -18, 0, 18)
    
        local content = codeLabel(toast, data.Content or "", 11, Theme.DimText, 703)
        content.Position = UDim2.fromOffset(12, 22)
        content.Size = UDim2.new(1, -18, 0, 28)
        content.TextWrapped = true
        content.TextYAlignment = Enum.TextYAlignment.Top
    
        toast.BackgroundTransparency = 1
        title.TextTransparency = 1
        content.TextTransparency = 1
        accent.BackgroundTransparency = 1
    
        tween(toast, 0.12, {BackgroundTransparency = 0})
        tween(title, 0.12, {TextTransparency = 0})
        tween(content, 0.12, {TextTransparency = 0})
        tween(accent, 0.12, {BackgroundTransparency = 0})
    
        task.delay(tonumber(data.Duration) or 3, function()
            if not toast.Parent then return end
            tween(toast, 0.12, {BackgroundTransparency = 1})
            tween(title, 0.12, {TextTransparency = 1})
            tween(content, 0.12, {TextTransparency = 1})
            tween(accent, 0.12, {BackgroundTransparency = 1})
            task.wait(0.14)
            if toast.Parent then
                toast:Destroy()
            end
        end)
    end
    
    function PuckUI:CreateWindow(settings)
        settings = settings or {}
    
        if self.Window and self.Window.ScreenGui then
            pcall(function()
                self.Window.ScreenGui:Destroy()
            end)
        end
    
        local width = tonumber(settings.Width) or 480
        local height = tonumber(settings.Height) or 540
        width = math.max(360, width)
        height = math.max(360, height)
    
        local screen = create("ScreenGui", {
            Name = settings.GuiName or "RAINZXDEV_UI",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 10000,
        })
        getGuiParent(screen)
    
        local shadow = create("Frame", {
            Name = "Shadow",
            Position = UDim2.new(0.5, -math.floor(width / 2) + 4, 0.5, -math.floor(height / 2) + 4),
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 1,
            Parent = screen,
        })
    
        local main = create("Frame", {
            Name = "Main",
            Position = UDim2.new(0.5, -math.floor(width / 2), 0.5, -math.floor(height / 2)),
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = Theme.Main,
            BorderColor3 = Theme.BorderDark,
            BorderSizePixel = 1,
            Active = true,
            ZIndex = 2,
            Parent = screen,
        })
    
        -- Clean RAINZXDEV Hub background treatment.
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.Main),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 8)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0.08),
            }),
            Parent = main,
        })

        create("Frame", {
            Name = "InnerBorder",
            Position = UDim2.fromOffset(1, 1),
            Size = UDim2.new(1, -2, 1, -2),
            BackgroundTransparency = 1,
            BorderColor3 = Theme.Border,
            BorderSizePixel = 1,
            ZIndex = 4,
            Parent = main,
        })
    
        local titleBar = create("Frame", {
            Name = "TitleBar",
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 0, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 8,
            Parent = main,
        })
    
        local titleLabel = codeLabel(titleBar, settings.Name or settings.Title or "RAINZXDEV Hub", 13, Theme.BrightText, 11)
        titleLabel.Position = UDim2.fromOffset(6, 0)
        titleLabel.Size = UDim2.new(1, -52, 1, 0)
    
        local close = create("TextButton", {
            Name = "Close",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -2, 0, 2),
            Size = UDim2.fromOffset(18, 19),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Code,
            Text = "x",
            TextSize = 12,
            TextColor3 = Theme.DimText,
            ZIndex = 15,
            Parent = titleBar,
        })
    
        local minimize = create("TextButton", {
            Name = "Minimize",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -20, 0, 2),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Code,
            Text = "-",
            TextSize = 12,
            TextColor3 = Theme.DimText,
            ZIndex = 15,
            Parent = titleBar,
        })
    
        local dragHandle = create("TextButton", {
            Name = "DragHandle",
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, -42, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Active = true,
            ZIndex = 14,
            Parent = titleBar,
        })
    
        local accentTop = create("Frame", {
            Name = "AccentTop",
            Position = UDim2.fromOffset(2, 26),
            Size = UDim2.new(1, -4, 0, 1),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 9,
            Parent = main,
        })
    
        local tabBar = create("ScrollingFrame", {
            Name = "TabBar",
            Position = UDim2.fromOffset(2, 27),
            Size = UDim2.new(1, -4, 0, 22),
            BackgroundColor3 = Theme.Tab,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.X,
            ScrollingDirection = Enum.ScrollingDirection.X,
            ScrollBarThickness = 0,
            ElasticBehavior = Enum.ElasticBehavior.Never,
            ZIndex = 8,
            Parent = main,
        })
    
        local tabLayout = create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 12),
            Parent = tabBar,
        })
    
        -- Separator under the tab row. Keeping this separate from the active-tab
        -- highlight prevents the header from looking broken when only one tab exists.
        create("Frame", {
            Name = "TabSeparatorDark",
            Position = UDim2.fromOffset(2, 49),
            Size = UDim2.new(1, -4, 0, 1),
            BackgroundColor3 = Theme.BorderDark,
            BorderSizePixel = 0,
            ZIndex = 8,
            Parent = main,
        })
    
        create("Frame", {
            Name = "TabSeparator",
            Position = UDim2.fromOffset(2, 50),
            Size = UDim2.new(1, -4, 0, 1),
            BackgroundColor3 = Theme.Border,
            BackgroundTransparency = 0.45,
            BorderSizePixel = 0,
            ZIndex = 8,
            Parent = main,
        })
    
        local columnsHost = create("Frame", {
            Name = "ColumnsHost",
            Position = UDim2.fromOffset(8, 57),
            Size = UDim2.new(1, -16, 1, -65),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 4,
            Parent = main,
        })
    
        local popupLayer = create("Frame", {
            Name = "PopupLayer",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 500,
            Parent = screen,
        })
    
        local notificationHolder = create("Frame", {
            Name = "Notifications",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 10),
            Size = UDim2.fromOffset(290, 450),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 690,
            Parent = screen,
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
            Parent = notificationHolder,
        })
    
        local window = {
            ScreenGui = screen,
            Main = main,
            TitleBar = titleBar,
            TitleLabel = titleLabel,
            TabBar = tabBar,
            ColumnsHost = columnsHost,
            PopupLayer = popupLayer,
            NotificationHolder = notificationHolder,
            AccentObjects = {accentTop},
            Tabs = {},
            CurrentTab = nil,
            OpenPopup = nil,
            CloseCallback = nil,
            Minimized = false,
            Visible = true,
            FullSize = UDim2.fromOffset(width, height),
            ToggleKeyName = tostring(SharedUIState.ToggleKeyName or "K"),
            ToggleKeyCode = Enum.KeyCode.K,
            KeybindDisplays = {},
        }
    
        self.Window = window
        SharedUIState.Windows[window] = true
    
        ------------------------------------------------------------------------
        -- Reliable dragging
        ------------------------------------------------------------------------
        local dragging = false
        local dragInput = nil
        local closeOpenPopup = function() end
        local dragStart = nil
        local startPosition = nil
    
        local function updateDrag(input)
            if not dragging or not dragStart or not startPosition then
                return
            end
    
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
            main.Position = newPos
            shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset + 4, newPos.Y.Scale, newPos.Y.Offset + 4)
        end
    
        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
    
                closeOpenPopup()
                dragging = true
                dragStart = input.Position
                startPosition = main.Position
    
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
    
        dragHandle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
    
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input == dragInput then
                updateDrag(input)
            end
        end)
    
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    
        ------------------------------------------------------------------------
        -- Popup management
        ------------------------------------------------------------------------
        function window:ClosePopup()
            local popup = self.OpenPopup
            self.OpenPopup = nil
            if popup and popup.Close then
                popup:Close()
            end
        end
    
        closeOpenPopup = function()
            window:ClosePopup()
        end
    
        function window:SetCloseCallback(callback)
            self.CloseCallback = callback
        end
    
        function window:SetTitle(text)
            self.TitleLabel.Text = tostring(text or "")
        end
    
        function window:SetVisible(state)
            local visible = state == true
            self.Visible = visible
            safeSet(self.Main, "Visible", visible)
            if shadow then
                safeSet(shadow, "Visible", visible)
            end
            if not visible then
                self:ClosePopup()
            end
        end
    
        function window:Toggle()
            self:SetVisible(not self.Visible)
        end
    
        function window:_ApplyToggleKey(key)
            local keyCode
    
            if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
                keyCode = key
            else
                keyCode = Enum.KeyCode[tostring(key or "")]
            end
    
            if not keyCode or keyCode == Enum.KeyCode.Unknown then
                return false
            end
    
            self.ToggleKeyCode = keyCode
            self.ToggleKeyName = keyCode.Name
    
            for _, control in ipairs(self.KeybindDisplays or {}) do
                if control and control._SetKeyName then
                    control:_SetKeyName(self.ToggleKeyName)
                end
            end
    
            return true
        end
    
        function window:SetToggleKey(key)
            local keyCode
    
            if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
                keyCode = key
            else
                keyCode = Enum.KeyCode[tostring(key or "")]
            end
    
            if not keyCode or keyCode == Enum.KeyCode.Unknown then
                return false
            end
    
            SharedUIState.ToggleKeyName = keyCode.Name
    
            -- Broadcast the new key to every RAINZXDEV window currently loaded.
            for otherWindow in pairs(SharedUIState.Windows) do
                if otherWindow and otherWindow._ApplyToggleKey then
                    otherWindow:_ApplyToggleKey(keyCode)
                end
            end
    
            return true
        end
    
        function window:GetToggleKey()
            return self.ToggleKeyName
        end
    
        function window:Destroy()
            self:ClosePopup()
            SharedUIState.Windows[self] = nil
    
            if SharedUIState.CapturingWindow == self then
                SharedUIState.CapturingWindow = nil
                SharedUIState.CapturingControl = nil
            end
    
            if self.ScreenGui then
                self.ScreenGui:Destroy()
            end
        end
    
        function window:SelectTab(tab)
            if self.CurrentTab == tab then
                return
            end
    
            self:ClosePopup()
    
            if self.CurrentTab then
                self.CurrentTab.Container.Visible = false
                self.CurrentTab.Button.TextColor3 = Theme.Text
                self.CurrentTab.Highlight.Visible = false
            end
    
            self.CurrentTab = tab
            tab.Container.Visible = true
            tab.Button.TextColor3 = Theme.Accent
            tab.Highlight.BackgroundColor3 = Theme.Accent
            tab.Highlight.Visible = true
    
            task.defer(function()
                if not tab.Button.Parent then return end
                local buttonLeft = tab.Button.AbsolutePosition.X - tabBar.AbsolutePosition.X + tabBar.CanvasPosition.X
                local buttonRight = buttonLeft + tab.Button.AbsoluteSize.X
                local visibleLeft = tabBar.CanvasPosition.X
                local visibleRight = visibleLeft + tabBar.AbsoluteSize.X
    
                if buttonLeft < visibleLeft then
                    tabBar.CanvasPosition = Vector2.new(math.max(0, buttonLeft - 4), 0)
                elseif buttonRight > visibleRight then
                    tabBar.CanvasPosition = Vector2.new(
                        math.max(0, buttonRight - tabBar.AbsoluteSize.X + 4),
                        0
                    )
                end
            end)
        end
    
        -- Resolve this window to the current shared UI key.
        if not window:_ApplyToggleKey(SharedUIState.ToggleKeyName) then
            window:_ApplyToggleKey("K")
        end
    
        ------------------------------------------------------------------------
        -- Tabs and controls
        ------------------------------------------------------------------------
        function window:CreateTab(tabName, _icon)
            local tab = {
                Name = tostring(tabName),
                Window = self,
                Sections = {},
                _nextColumn = 1,
                _currentSection = nil,
            }
    
            local textSize = TextService:GetTextSize(tab.Name, 13, Enum.Font.Code, Vector2.new(1000, 18))
            local buttonWidth = math.max(38, textSize.X + 10)
    
            -- New tabs always begin from the left edge. This also clears stale
            -- CanvasPosition values left over by some executor/Studio UI states.
            if #self.Tabs == 0 then
                tabBar.CanvasPosition = Vector2.new(0, 0)
            end
    
            local button = create("TextButton", {
                Name = "Tab_" .. tab.Name,
                LayoutOrder = #self.Tabs + 1,
                Size = UDim2.fromOffset(buttonWidth, 22),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Font = Enum.Font.Code,
                Text = tab.Name,
                TextSize = 13,
                TextColor3 = Theme.Text,
                ZIndex = 10,
                Parent = tabBar,
            })
    
            -- RAINZXDEV active-tab highlight
            local highlight = create("Frame", {
                Position = UDim2.new(0, 0, 1, -1),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 11,
                Parent = button,
            })
            table.insert(window.AccentObjects, highlight)
    
            local container = create("Frame", {
                Name = "Content_" .. tab.Name,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ClipsDescendants = false,
                Visible = false,
                ZIndex = 4,
                Parent = columnsHost,
            })
    
            local columns = {}
            local columnLayouts = {}
    
            local function updateColumnCanvas(index)
                local scroll = columns[index]
                local layout = columnLayouts[index]
                if not scroll or not layout then
                    return
                end
    
                -- Manual CanvasSize is more reliable than nested AutomaticCanvasSize
                -- when this library is used through Studio/executor environments.
                local contentHeight = math.max(0, layout.AbsoluteContentSize.Y + 14)
                scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
            end
    
            for index = 1, 2 do
                local leftSide = index == 1
                local scroll = create("ScrollingFrame", {
                    Name = "Column" .. tostring(index),
                    Position = UDim2.new(leftSide and 0 or 0.5, leftSide and 0 or 4, 0, 0),
                    Size = UDim2.new(0.5, -4, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(),
                    AutomaticCanvasSize = Enum.AutomaticSize.None,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    ElasticBehavior = Enum.ElasticBehavior.Never,
                    ClipsDescendants = true,
                    ZIndex = 4,
                    Parent = container,
                })
    
                local layout = create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 8),
                    Parent = scroll,
                })
    
                create("UIPadding", {
                    PaddingTop = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, leftSide and 3 or 0),
                    PaddingBottom = UDim.new(0, 6),
                    Parent = scroll,
                })
    
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    updateColumnCanvas(index)
                end)
    
                scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                    if window.OpenPopup then
                        window:ClosePopup()
                    end
                end)
    
                columns[index] = scroll
                columnLayouts[index] = layout
            end
    
            tab.Button = button
            tab.Highlight = highlight
            tab.Container = container
            tab.Columns = columns
    
            -- Reflow rules:
            --   1 section  -> one full-width column (fixes the giant empty right side)
            --   2+ sections -> stable two-column alternating layout
            -- We do not use AbsoluteContentSize to choose a column at creation time,
            -- because Roblox may not update it until a later render step.
            local function reflowSections()
                local count = #tab.Sections
    
                if count <= 1 then
                    columns[1].Visible = true
                    columns[1].Position = UDim2.new(0, 0, 0, 0)
                    columns[1].Size = UDim2.new(1, 0, 1, 0)
                    columns[2].Visible = false
                    columns[2].CanvasPosition = Vector2.new(0, 0)
    
                    if count == 1 and tab.Sections[1].Frame.Parent ~= columns[1] then
                        tab.Sections[1].Frame.Parent = columns[1]
                    end
                else
                    columns[1].Visible = true
                    columns[2].Visible = true
                    columns[1].Position = UDim2.new(0, 0, 0, 0)
                    columns[1].Size = UDim2.new(0.5, -4, 1, 0)
                    columns[2].Position = UDim2.new(0.5, 4, 0, 0)
                    columns[2].Size = UDim2.new(0.5, -4, 1, 0)
    
                    for sectionIndex, existingSection in ipairs(tab.Sections) do
                        local targetColumn = ((sectionIndex - 1) % 2) + 1
                        if existingSection.Frame.Parent ~= columns[targetColumn] then
                            existingSection.Frame.Parent = columns[targetColumn]
                        end
                    end
                end
    
                task.defer(function()
                    updateColumnCanvas(1)
                    updateColumnCanvas(2)
                end)
            end
    
            function tab:CreateSection(sectionName)
                local section = {
                    Name = tostring(sectionName or "Section"),
                    Tab = self,
                }
    
                local frame = create("Frame", {
                    Name = "Section_" .. section.Name,
                    Size = UDim2.new(1, -2, 0, 24),
                    BackgroundColor3 = Theme.SectionInner,
                    BackgroundTransparency = 0.5,
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    ClipsDescendants = false,
                    ZIndex = 5,
                    Parent = columns[1],
                })
    
                create("UIStroke", {
                    Color = Theme.Border,
                    Thickness = 1,
                    Parent = frame,
                })
    
                local topAccentLine = create("Frame", {
                    Position = UDim2.fromOffset(0, 0),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 6,
                    Parent = frame,
                })
                table.insert(window.AccentObjects, topAccentLine)
    
                local titleWidth = TextService:GetTextSize(section.Name, 12, Enum.Font.Code, Vector2.new(1000, 16)).X + 12
    
                local headerPatch = create("Frame", {
                    Position = UDim2.fromOffset(12, -7),
                    Size = UDim2.fromOffset(titleWidth, 14),
                    BackgroundColor3 = Theme.Main,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = frame,
                })
    
                local header = codeLabel(headerPatch, section.Name, 12, Theme.Text, 8)
                header.Position = UDim2.fromOffset(0, 0)
                header.Size = UDim2.new(1, 0, 1, 0)
                header.TextXAlignment = Enum.TextXAlignment.Center
    
                local body = create("Frame", {
                    Name = "Body",
                    Position = UDim2.fromOffset(8, 14),
                    Size = UDim2.new(1, -16, 0, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ClipsDescendants = false,
                    ZIndex = 6,
                    Parent = frame,
                })
    
                local bodyLayout = create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 4),
                    Parent = body,
                })
    
                create("UIPadding", {
                    PaddingBottom = UDim.new(0, 8),
                    Parent = body,
                })
    
                local function updateSectionSize()
                    local bodyHeight = math.max(0, bodyLayout.AbsoluteContentSize.Y + 8)
                    body.Size = UDim2.new(1, -16, 0, bodyHeight)
                    frame.Size = UDim2.new(1, -2, 0, math.max(28, 14 + bodyHeight))
                end
    
                bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    updateSectionSize()
                    task.defer(function()
                        updateColumnCanvas(1)
                        updateColumnCanvas(2)
                    end)
                end)
    
                section.Frame = frame
                section.Body = body
    
                function section:Set(newName)
                    self.Name = tostring(newName or "")
                    header.Text = self.Name
                    local newWidth = TextService:GetTextSize(self.Name, 12, Enum.Font.Code, Vector2.new(1000, 16)).X + 12
                    headerPatch.Size = UDim2.fromOffset(newWidth, 14)
                end
    
                table.insert(self.Sections, section)
                self._currentSection = section
                reflowSections()
    
                task.defer(updateSectionSize)
                return section
            end
    
            local function addControlFrame(height)
                local section = getCurrentSection(tab)
                return create("Frame", {
                    Size = UDim2.new(1, 0, 0, height),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ClipsDescendants = false,
                    ZIndex = 6,
                    Parent = section.Body,
                })
            end
    
            function tab:CreateDivider()
                local row = addControlFrame(9)
                local divider = create("Frame", {
                    Position = UDim2.fromOffset(0, 4),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Theme.Border,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = row,
                })
    
                local object = {}
                function object:Set(visible)
                    divider.Visible = visible ~= false
                end
                return object
            end
    
            function tab:CreateLabel(text, _icon, color)
                local row = addControlFrame(17)
                local label = codeLabel(row, text, 11, color or Theme.DimText, 7)
                label.Size = UDim2.fromScale(1, 1)
                label.TextTruncate = Enum.TextTruncate.AtEnd
    
                local object = {
                    Label = label,
                }
    
                function object:Set(value, _newIcon, newColor)
                    safeSet(label, "Text", tostring(value or ""))
                    if typeof(newColor) == "Color3" then
                        safeSet(label, "TextColor3", newColor)
                    end
                end
    
                return object
            end
    
            function tab:CreateParagraph(data)
                data = data or {}
    
                local contentText = tostring(data.Content or "")
                local rowHeight = tonumber(data.Height) or 50
                if #contentText > 140 then
                    rowHeight = 68
                elseif #contentText > 75 then
                    rowHeight = 58
                end
    
                local row = addControlFrame(rowHeight)
    
                local title = codeLabel(row, data.Title or "", 12, Theme.BrightText, 7)
                title.Position = UDim2.fromOffset(0, 0)
                title.Size = UDim2.new(1, 0, 0, 16)
    
                local body = codeLabel(row, contentText, 11, Theme.DimText, 7)
                body.Position = UDim2.fromOffset(0, 16)
                body.Size = UDim2.new(1, 0, 1, -16)
                body.TextWrapped = true
                body.TextYAlignment = Enum.TextYAlignment.Top
    
                local object = {}
                function object:Set(nextData)
                    if type(nextData) == "table" then
                        if nextData.Title ~= nil then
                            safeSet(title, "Text", tostring(nextData.Title))
                        end
                        if nextData.Content ~= nil then
                            safeSet(body, "Text", tostring(nextData.Content))
                        end
                    else
                        safeSet(body, "Text", tostring(nextData or ""))
                    end
                end
    
                return object
            end
    
            function tab:CreateButton(data)
                data = data or {}
    
                -- Legacy scripts used dedicated Hide UI buttons. The UI keybind in
                -- Settings replaces them, so suppress those buttons automatically.
                local requestedName = tostring(data.Name or data.Text or "Button")
                local normalizedName = string.lower(requestedName)
                normalizedName = normalizedName:gsub("%s+", " ")
    
                local legacyUIButtons = {
                    ["hide ui"] = true,
                    ["toggle ui"] = true,
                    ["hide/show ui"] = true,
                    ["show/hide ui"] = true,
                    ["hide / show ui"] = true,
                    ["show / hide ui"] = true,
                }
    
                if legacyUIButtons[normalizedName] then
                    local hiddenObject = {}
                    function hiddenObject:Set(_value) end
                    function hiddenObject:SetText(_value) end
                    function hiddenObject:Get() return false end
                    return hiddenObject
                end
    
                local row = addControlFrame(24)
    
                local buttonControl = create("TextButton", {
                    Position = UDim2.fromOffset(0, 1),
                    Size = UDim2.new(1, 0, 1, -2),
                    BackgroundColor3 = Theme.Element,
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    AutoButtonColor = false,
                    Font = Enum.Font.Code,
                    Text = tostring(data.Name or data.Text or "Button"),
                    TextColor3 = Theme.Text,
                    TextSize = 11,
                    ZIndex = 7,
                    Parent = row,
                })
                setHover(buttonControl, Theme.Element, Theme.ElementHover)
    
                buttonControl.MouseButton1Click:Connect(function()
                    safeCallback(data.Callback)
                end)
    
                local object = {
                    Button = buttonControl,
                }
    
                function object:Set(value)
                    buttonControl.Text = tostring(value or "")
                end
    
                function object:SetText(value)
                    buttonControl.Text = tostring(value or "")
                end
    
                return object
            end
    
            function tab:CreateToggle(data)
                data = data or {}
    
                local row = addControlFrame(18)
                local state = data.CurrentValue == true
                local flag = data.Flag
    
                local hit = create("TextButton", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 9,
                    Parent = row,
                })
    
                local box = create("Frame", {
                    Position = UDim2.fromOffset(2, 3),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    ZIndex = 7,
                    Parent = row,
                })
                create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = box })
    
                local fill = create("Frame", {
                    Position = UDim2.fromOffset(2, 2),
                    Size = UDim2.new(1, -4, 1, -4),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    Visible = state,
                    ZIndex = 9,
                    Parent = box,
                })
                table.insert(window.AccentObjects, fill)
    
                local label = codeLabel(row, data.Name or data.Text or "Toggle", 12, state and Theme.BrightText or Theme.DimText, 7)
                label.Position = UDim2.fromOffset(22, 0)
                label.Size = UDim2.new(1, -22, 1, 0)
                label.TextTruncate = Enum.TextTruncate.AtEnd
    
                local object = {}
    
                local function apply(value, invokeCallback)
                    state = value == true
                    fill.Visible = state
                    label.TextColor3 = state and Theme.BrightText or Theme.DimText
    
                    if flag then
                        PuckUI.Flags[flag] = state
                    end
    
                    if invokeCallback then
                        safeCallback(data.Callback, state)
                    end
                end
    
                function object:Set(value)
                    apply(value, true)
                end
    
                function object:Get()
                    return state
                end
    
                hit.MouseButton1Click:Connect(function()
                    apply(not state, true)
                end)
    
                if flag then
                    PuckUI.Flags[flag] = state
                end
    
                return object
            end
    
            function tab:CreateDropdown(data)
                data = data or {}
    
                local row = addControlFrame(40)
                local label = codeLabel(row, data.Name or "Dropdown", 12, Theme.Text, 7)
                label.Size = UDim2.new(1, 0, 0, 16)
    
                local options = {}
                for _, option in ipairs(data.Options or {}) do
                    table.insert(options, option)
                end
    
                local current = normalizeDropdownValue(data.CurrentOption)
                if current == nil then
                    current = options[1]
                end
    
                local selector = create("TextButton", {
                    Position = UDim2.fromOffset(0, 18),
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = Theme.Element,
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    AutoButtonColor = false,
                    Font = Enum.Font.Code,
                    Text = "  " .. tostring(current or "Select..."),
                    TextColor3 = Theme.Text,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                    Parent = row,
                })
                setHover(selector, Theme.Element, Theme.ElementHover)
    
                local arrow = codeLabel(selector, "v", 10, Theme.DimText, 9)
                arrow.AnchorPoint = Vector2.new(1, 0)
                arrow.Position = UDim2.new(1, -3, 0, 0)
                arrow.Size = UDim2.fromOffset(12, 20)
                arrow.TextXAlignment = Enum.TextXAlignment.Center
    
                local object = {}
                local flag = data.Flag
                local popup = nil
                local blocker = nil
    
                local function apply(value, invokeCallback)
                    if value == nil then
                        return
                    end
    
                    current = value
                    selector.Text = "  " .. tostring(current)
    
                    if flag then
                        PuckUI.Flags[flag] = current
                    end
    
                    if invokeCallback then
                        safeCallback(data.Callback, {current})
                    end
                end
    
                local function closePopup()
                    if popup then
                        popup:Destroy()
                        popup = nil
                    end
                    if blocker then
                        blocker:Destroy()
                        blocker = nil
                    end
                    arrow.Text = "v"
    
                    if window.OpenPopup == object then
                        window.OpenPopup = nil
                    end
                end
    
                function object:Close()
                    closePopup()
                end
    
                local function openPopup()
                    if window.OpenPopup and window.OpenPopup ~= object then
                        window.OpenPopup:Close()
                    end
    
                    closePopup()
    
                    local selectorPosition = selector.AbsolutePosition
                    local selectorSize = selector.AbsoluteSize
                    local itemHeight = 20
                    local maxVisible = tonumber(data.MaxVisible) or 8
                    local visibleCount = math.min(#options, maxVisible)
                    local menuHeight = math.max(itemHeight + 2, visibleCount * itemHeight + 2)
    
                    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
                    local menuY = selectorPosition.Y + selectorSize.Y + 1
    
                    if menuY + menuHeight > viewport.Y - 6 then
                        menuY = selectorPosition.Y - menuHeight - 1
                    end
    
                    blocker = create("TextButton", {
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Text = "",
                        ZIndex = 501,
                        Parent = popupLayer,
                    })
    
                    blocker.MouseButton1Click:Connect(closePopup)
    
                    popup = create("ScrollingFrame", {
                        Position = UDim2.fromOffset(selectorPosition.X, menuY),
                        Size = UDim2.fromOffset(math.max(80, selectorSize.X), menuHeight),
                        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
                        BorderColor3 = Theme.Border,
                        BorderSizePixel = 1,
                        CanvasSize = UDim2.new(),
                        AutomaticCanvasSize = Enum.AutomaticSize.Y,
                        ScrollBarThickness = #options > maxVisible and 3 or 0,
                        ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90),
                        ScrollingDirection = Enum.ScrollingDirection.Y,
                        ElasticBehavior = Enum.ElasticBehavior.Never,
                        ClipsDescendants = true,
                        ZIndex = 510,
                        Parent = popupLayer,
                    })
    
                    create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 0),
                        Parent = popup,
                    })
    
                    for index, value in ipairs(options) do
                        local optionButton = create("TextButton", {
                            LayoutOrder = index,
                            Size = UDim2.new(1, 0, 0, itemHeight),
                            BackgroundColor3 = value == current and Color3.fromRGB(38, 38, 38) or Color3.fromRGB(25, 25, 25),
                            BorderSizePixel = 0,
                            AutoButtonColor = false,
                            Font = Enum.Font.Code,
                            Text = "  " .. tostring(value),
                            TextColor3 = value == current and Theme.BrightText or Theme.Text,
                            TextSize = 11,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 512,
                            Parent = popup,
                        })
    
                        setHover(
                            optionButton,
                            value == current and Color3.fromRGB(38, 38, 38) or Color3.fromRGB(25, 25, 25),
                            Theme.Element
                        )
    
                        optionButton.MouseButton1Click:Connect(function()
                            apply(value, true)
                            closePopup()
                        end)
                    end
    
                    arrow.Text = "^"
                    window.OpenPopup = object
                end
    
                selector.MouseButton1Click:Connect(function()
                    if window.OpenPopup == object then
                        closePopup()
                    else
                        openPopup()
                    end
                end)
    
                function object:Set(value)
                    apply(normalizeDropdownValue(value), true)
                end
    
                function object:Get()
                    return current
                end
    
                function object:Refresh(newOptions)
                    closePopup()
    
                    options = {}
                    for _, option in ipairs(newOptions or {}) do
                        table.insert(options, option)
                    end
    
                    if current == nil or not table.find(options, current) then
                        current = options[1]
                        selector.Text = "  " .. tostring(current or "Select...")
                        if flag then
                            PuckUI.Flags[flag] = current
                        end
                    end
                end
    
                if flag and current ~= nil then
                    PuckUI.Flags[flag] = current
                end
    
                return object
            end
    
            function tab:CreateSlider(data)
                data = data or {}
    
                -- RAINZXDEV slider format: thicker bar with value inside.
                local row = addControlFrame(34)
                local minimum = tonumber(data.Range and data.Range[1] or data.Min) or 0
                local maximum = tonumber(data.Range and data.Range[2] or data.Max) or 100
                local increment = tonumber(data.Increment) or 1
                local suffix = tostring(data.Suffix or "")
    
                local value = tonumber(data.CurrentValue or data.Value) or minimum
                value = math.clamp(value, minimum, maximum)
    
                local label = codeLabel(row, data.Name or "Slider", 11, Theme.DimText, 7)
                label.Size = UDim2.new(1, 0, 0, 14)
    
                local rail = create("Frame", {
                    Position = UDim2.fromOffset(0, 18),
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundColor3 = Theme.Element,
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    Active = true,
                    ZIndex = 7,
                    Parent = row,
                })
    
                local fill = create("Frame", {
                    Size = UDim2.new((value - minimum) / math.max(maximum - minimum, 1), 0, 1, 0),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = rail,
                })
                table.insert(window.AccentObjects, fill)
    
                -- The value label is placed inside the rail for a compact layout.
                local valueLabel = codeLabel(rail, tostring(value) .. suffix, 11, Theme.BrightText, 9)
                valueLabel.Size = UDim2.fromScale(1, 1)
                valueLabel.TextXAlignment = Enum.TextXAlignment.Center
    
                local draggingSlider = false
                local flag = data.Flag
                local object = {}
    
                local function apply(nextValue, invokeCallback)
                    nextValue = tonumber(nextValue)
                    if not nextValue then
                        return
                    end
    
                    nextValue = math.clamp(nextValue, minimum, maximum)
                    nextValue = math.floor(nextValue / increment + 0.5) * increment
    
                    if increment < 1 then
                        local decimals = math.max(0, math.ceil(-math.log10(increment)))
                        local factor = 10 ^ decimals
                        nextValue = math.floor(nextValue * factor + 0.5) / factor
                    end
    
                    value = nextValue
                    valueLabel.Text = tostring(value) .. suffix
                    fill.Size = UDim2.new(
                        (value - minimum) / math.max(maximum - minimum, 1),
                        0,
                        1,
                        0
                    )
    
                    if flag then
                        PuckUI.Flags[flag] = value
                    end
    
                    if invokeCallback then
                        safeCallback(data.Callback, value)
                    end
                end
    
                local function fromPosition(x)
                    local alpha = math.clamp(
                        (x - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1),
                        0,
                        1
                    )
                    apply(minimum + (maximum - minimum) * alpha, true)
                end
    
                rail.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSlider = true
                        fromPosition(input.Position.X)
                    end
                end)
    
                UserInputService.InputChanged:Connect(function(input)
                    if draggingSlider and (
                        input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch
                    ) then
                        fromPosition(input.Position.X)
                    end
                end)
    
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSlider = false
                    end
                end)
    
                function object:Set(nextValue)
                    apply(nextValue, true)
                end
    
                function object:Get()
                    return value
                end
    
                if flag then
                    PuckUI.Flags[flag] = value
                end
    
                return object
            end
    
            function tab:CreateInput(data)
                data = data or {}
    
                local row = addControlFrame(40)
    
                local label = codeLabel(row, data.Name or "Input", 11, Theme.Text, 7)
                label.Size = UDim2.new(1, 0, 0, 16)
    
                local box = create("TextBox", {
                    Position = UDim2.fromOffset(0, 18),
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = Theme.Element,
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    ClearTextOnFocus = false,
                    Font = Enum.Font.Code,
                    Text = tostring(data.CurrentValue or ""),
                    PlaceholderText = tostring(data.PlaceholderText or ""),
                    TextColor3 = Theme.Text,
                    PlaceholderColor3 = Theme.DimText,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                    Parent = row,
                })
    
                create("UIPadding", {
                    PaddingLeft = UDim.new(0, 6),
                    PaddingRight = UDim.new(0, 6),
                    Parent = box,
                })
    
                local current = box.Text
                local flag = data.Flag
                local object = {}
    
                local function apply(value, invokeCallback)
                    current = tostring(value or "")
                    box.Text = current
    
                    if flag then
                        PuckUI.Flags[flag] = current
                    end
    
                    if invokeCallback then
                        safeCallback(data.Callback, current)
                    end
                end
    
                box.FocusLost:Connect(function()
                    current = box.Text
    
                    if flag then
                        PuckUI.Flags[flag] = current
                    end
    
                    safeCallback(data.Callback, current)
    
                    if data.RemoveTextAfterFocusLost then
                        box.Text = ""
                    end
                end)
    
                function object:Set(value)
                    apply(value, true)
                end
    
                function object:Get()
                    return current
                end
    
                if flag then
                    PuckUI.Flags[flag] = current
                end
    
                return object
            end
    
            function tab:CreateKeybind(data)
                data = data or {}
    
                local row = addControlFrame(40)
    
                local label = codeLabel(row, data.Name or "UI Toggle Keybind", 11, Theme.Text, 7)
                label.Size = UDim2.new(1, 0, 0, 16)
    
                local bindButton = create("TextButton", {
                    Position = UDim2.fromOffset(0, 18),
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = Theme.Element,
                    BorderColor3 = Theme.BorderDark,
                    BorderSizePixel = 1,
                    AutoButtonColor = false,
                    Font = Enum.Font.Code,
                    Text = "",
                    TextColor3 = Theme.Text,
                    TextSize = 11,
                    ZIndex = 8,
                    Parent = row,
                })
                create("UIStroke", {Color = Theme.Border, Thickness = 1, Parent = bindButton})
                setHover(bindButton, Theme.Element, Theme.ElementHover)
    
                local object = {
                    Button = bindButton,
                    Callback = data.Callback,
                    CurrentKey = window.ToggleKeyName,
                    Capturing = false,
                }
    
                function object:_SetKeyName(keyName)
                    self.CurrentKey = tostring(keyName or "K")
                    self.Capturing = false
                    bindButton.Text = "[ " .. self.CurrentKey .. " ]"
                    bindButton.TextColor3 = Theme.Text
                end
    
                function object:Set(value)
                    local previous = window.ToggleKeyName
                    if window:SetToggleKey(value) then
                        self:_SetKeyName(window.ToggleKeyName)
                        if previous ~= window.ToggleKeyName then
                            safeCallback(self.Callback, window.ToggleKeyName)
                        end
                        return true
                    end
                    return false
                end
    
                function object:Get()
                    return window.ToggleKeyName
                end
    
                function object:CancelCapture()
                    if SharedUIState.CapturingControl == self then
                        SharedUIState.CapturingControl = nil
                        SharedUIState.CapturingWindow = nil
                    end
                    self:_SetKeyName(window.ToggleKeyName)
                end
    
                bindButton.MouseButton1Click:Connect(function()
                    local previousControl = SharedUIState.CapturingControl
                    if previousControl and previousControl ~= object and previousControl.CancelCapture then
                        previousControl:CancelCapture()
                    end
    
                    window:ClosePopup()
                    SharedUIState.CapturingWindow = window
                    SharedUIState.CapturingControl = object
                    object.Capturing = true
                    bindButton.Text = "[ press a key... ]"
                    bindButton.TextColor3 = Theme.Accent
                end)
    
                object:_SetKeyName(window.ToggleKeyName)
                table.insert(window.KeybindDisplays, object)
    
                return object
            end
    
            button.MouseButton1Click:Connect(function()
                window:SelectTab(tab)
            end)
    
            table.insert(self.Tabs, tab)
    
            -- Every current and future RAINZXDEV script gets the UI keybind in its
            -- Settings tab automatically. No per-game Hide UI button is needed.
            if string.lower(tab.Name) == "settings"
                and settings.DisableBuiltInUIKeybind ~= true then
    
                tab:CreateSection("Interface")
                tab:CreateKeybind({
                    Name = "UI Toggle Keybind",
                    Callback = function(keyName)
                        PuckUI:Notify({
                            Title = "UI Keybind",
                            Content = "All RAINZXDEV UIs now use " .. tostring(keyName),
                            Duration = 2.5,
                        })
                    end,
                })
                tab:CreateLabel("Click the box, then press any key. Escape cancels.")
            end
    
            if #self.Tabs == 1 then
                task.defer(function()
                    if button.Parent then
                        tabBar.CanvasPosition = Vector2.new(0, 0)
                        self:SelectTab(tab)
                    end
                end)
            end
    
            return tab
        end
    
        close.MouseButton1Click:Connect(function()
            if window.CloseCallback then
                window.CloseCallback()
            else
                window:Destroy()
            end
        end)
    
        minimize.MouseButton1Click:Connect(function()
            window:ClosePopup()
            window.Minimized = not window.Minimized
    
            tabBar.Visible = not window.Minimized
            accentTop.Visible = not window.Minimized
            columnsHost.Visible = not window.Minimized
    
            if window.Minimized then
                main.Size = UDim2.fromOffset(width, 27)
                shadow.Size = UDim2.fromOffset(width, 27)
                minimize.Text = "+"
            else
                main.Size = window.FullSize
                shadow.Size = window.FullSize
                minimize.Text = "-"
            end
        end)
    
        -- Dynamic key capture + hide/show handling.
        UserInputService.InputBegan:Connect(function(input, processed)
            local capturingWindow = SharedUIState.CapturingWindow
    
            if capturingWindow then
                -- Only the window that owns the active capture consumes the key.
                if capturingWindow ~= window then
                    return
                end
    
                if input.UserInputType ~= Enum.UserInputType.Keyboard then
                    return
                end
    
                local control = SharedUIState.CapturingControl
    
                if input.KeyCode == Enum.KeyCode.Escape then
                    SharedUIState.SuppressToggleUntil = os.clock() + 0.25
                    SharedUIState.CapturingWindow = nil
                    SharedUIState.CapturingControl = nil
    
                    if control and control.CancelCapture then
                        control:CancelCapture()
                    end
                    return
                end
    
                if input.KeyCode ~= Enum.KeyCode.Unknown then
                    local keyName = input.KeyCode.Name
    
                    -- Prevent this same keypress being treated as the newly-set
                    -- hide/show shortcut by another loaded PuckUI callback.
                    SharedUIState.SuppressToggleUntil = os.clock() + 0.30
                    SharedUIState.CapturingWindow = nil
                    SharedUIState.CapturingControl = nil
    
                    window:SetToggleKey(input.KeyCode)
    
                    if control then
                        control:_SetKeyName(keyName)
                        safeCallback(control.Callback, keyName)
                    end
                end
    
                return
            end
    
            if os.clock() < (SharedUIState.SuppressToggleUntil or 0) then
                return
            end
    
            if processed then
                return
            end
    
            if input.UserInputType == Enum.UserInputType.Keyboard
                and input.KeyCode == window.ToggleKeyCode then
                window:Toggle()
            end
        end)
    
        return window
    end
    
    return PuckUI
end)()

-- [[ RAINZXDEV Hub - Aim / ESP ]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ===== SETTINGS (ALL OFF BY DEFAULT) =====
local Settings = {
    -- Combat (ALL OFF)
    Aimbot = false,
    TeamCheck = true,
    WallCheck = true,
    FOVCircle = false,
    LockFOV = true,
    TargetPart = "Head",
    FOVRadius = 100,
    Prediction = 0.07,
    MaxDistance = 3000,
    AimPlayers = true,
    AimCustomModels = true,
    AimTaggedModels = true,
    Triggerbot = false,
    TriggerDelay = 0,
    -- Visuals (ALL OFF)
    ESPEnabled = false,
    ESPName = true,
    ESPDistance = true,
    SkeletonESP = false,
    RainbowESP = false,
    -- Player
    Spectate = false,
    SelectedPlayer = "",
    RainbowSpeed = 1,
}

local function saveSettings()
    pcall(function()
        local data = game:GetService("HttpService"):JSONEncode(Settings)
        LocalPlayer:SetAttribute("RAINZXDEVHubSettings", data)
    end)
end

local function loadSettings()
    pcall(function()
        local data = LocalPlayer:GetAttribute("RAINZXDEVHubSettings")
        if data then
            local loaded = game:GetService("HttpService"):JSONDecode(data)
            for k, v in pairs(loaded) do
                Settings[k] = v
            end
        end
    end)
end
loadSettings()

local rainbowHue = 0

-- ===== FOV CIRCLE =====
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 2
fovCircle.NumSides = 100
fovCircle.Radius = Settings.FOVRadius
fovCircle.Filled = false
fovCircle.Visible = false

-- ============================================================
-- ===== SKELETON ESP =====
-- ============================================================

local bonesR15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local bonesR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local skeletonData = {}

local function createSkeletonLines()
    local lines = {}
    for i = 1, 14 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Transparency = 1
        line.Visible = false
        table.insert(lines, line)
    end
    return lines
end

local function createSkeleton(player)
    if player == LocalPlayer or skeletonData[player] then return end
    skeletonData[player] = createSkeletonLines()
end

local skeletonVisibilityParams = RaycastParams.new()
skeletonVisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
skeletonVisibilityParams.IgnoreWater = true

local function isSkeletonVisible(character)
    Camera = Workspace.CurrentCamera or Camera

    if not Camera or not character then
        return false
    end

    local targetPart =
        character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")

    if not targetPart or not targetPart:IsA("BasePart") then
        return false
    end

    local filter = {}
    if LocalPlayer.Character then
        table.insert(filter, LocalPlayer.Character)
    end
    table.insert(filter, character)

    skeletonVisibilityParams.FilterDescendantsInstances = filter

    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local result = Workspace:Raycast(
        origin,
        direction,
        skeletonVisibilityParams
    )

    return result == nil
end

local function updateSkeletonESP()
    for player, lines in pairs(skeletonData) do
        repeat
            if not Settings.SkeletonESP then
                for _, line in pairs(lines) do
                    line.Visible = false
                end
                break
            end

            local char = player.Character
            if not char then
                for _, line in pairs(lines) do
                    line.Visible = false
                end
                break
            end

            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then
                for _, line in pairs(lines) do
                    line.Visible = false
                end
                break
            end

            -- Visibility skeleton colours:
            -- green = clear line of sight
            -- red   = blocked / behind geometry
            local visibleToCamera = isSkeletonVisible(char)
            local color

            if visibleToCamera then
                color = Color3.fromRGB(0, 255, 100)
            else
                color = Color3.fromRGB(255, 60, 60)
            end

            local useBones = bonesR15
            if char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso") then
                useBones = bonesR6
            end

            for i, bone in pairs(useBones) do
                local p1 = char:FindFirstChild(bone[1])
                local p2 = char:FindFirstChild(bone[2])

                if p1 and p2 and lines[i] then
                    local pos1, on1 = Camera:WorldToViewportPoint(p1.Position)
                    local pos2, on2 = Camera:WorldToViewportPoint(p2.Position)

                    if on1 and on2 then
                        lines[i].From = Vector2.new(pos1.X, pos1.Y)
                        lines[i].To = Vector2.new(pos2.X, pos2.Y)
                        lines[i].Color = color
                        lines[i].Visible = true
                    else
                        lines[i].Visible = false
                    end
                elseif lines[i] then
                    lines[i].Visible = false
                end
            end
        until true
    end
end

local function removeSkeleton(player)
    if skeletonData[player] then
        for _, line in pairs(skeletonData[player]) do
            line:Remove()
        end
        skeletonData[player] = nil
    end
end

-- ============================================================
-- ===== COMBAT LOGIC - rainzxdev TARGETING =====
-- ============================================================

local function GetPart(model, name)
    if not model then return nil end

    if name == "Left Arm" then
        return model:FindFirstChild("Left Arm", true)
            or model:FindFirstChild("LeftHand", true)
            or model:FindFirstChild("LeftUpperArm", true)
    elseif name == "Right Arm" then
        return model:FindFirstChild("Right Arm", true)
            or model:FindFirstChild("RightHand", true)
            or model:FindFirstChild("RightUpperArm", true)
    elseif name == "Neck" then
        return model:FindFirstChild("Neck", true)
            or model:FindFirstChild("Head", true)
            or model:FindFirstChild("UpperTorso", true)
            or model:FindFirstChild("Torso", true)
    elseif name == "Torso" then
        return model:FindFirstChild("UpperTorso", true)
            or model:FindFirstChild("Torso", true)
            or model:FindFirstChild("LowerTorso", true)
            or model:FindFirstChild("HumanoidRootPart", true)
    end

    return model:FindFirstChild(name, true)
end

local function IsAliveModel(model)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function IsVisible(part, model)
    if not Settings.WallCheck then return true end
    if not part then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
        model
    }
    params.IgnoreWater = true

    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    return Workspace:Raycast(origin, direction, params) == nil
end

local AimState = {
    Active = false,
    TargetModel = nil,
    TargetPart = nil,
}

local AIM_PART_NAMES = {
    "AimPart",
    "Head",
    "HeadHitbox",
    "HeadBox",
    "Face",
    "HumanoidRootPart",
    "RootPart",
    "Root",
    "UpperTorso",
    "Torso",
    "LowerTorso",
    "Body",
    "Chest",
}

local ROOT_PART_NAMES = {
    "HumanoidRootPart",
    "RootPart",
    "Root",
    "UpperTorso",
    "Torso",
    "LowerTorso",
    "Body",
    "Chest",
    "Head",
    "AimPart",
}

local function FindNamedPart(model, names)
    if not model then
        return nil
    end

    for _, name in ipairs(names) do
        local part = model:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end

local function FindAimPart(model)
    if not model then
        return nil
    end

    local customName = model:GetAttribute("AimPart")
    if type(customName) == "string" and customName ~= "" then
        local custom = model:FindFirstChild(customName, true)
        if custom and custom:IsA("BasePart") then
            return custom
        end
    end

    local named = FindNamedPart(model, AIM_PART_NAMES)
    if named then
        return named
    end

    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end

    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function FindRootPart(model)
    if not model then
        return nil
    end

    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end

    local named = FindNamedPart(model, ROOT_PART_NAMES)
    if named then
        return named
    end

    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function ModelMarkedTarget(model)
    if not model then
        return false
    end

    if model:GetAttribute("AimTarget") == true
        or model:GetAttribute("Targetable") == true
        or model:GetAttribute("Enemy") == true then
        return true
    end

    return CollectionService:HasTag(model, "AimTarget")
        or CollectionService:HasTag(model, "Targetable")
        or CollectionService:HasTag(model, "Enemy")
end

local function ModelAlive(model)
    if not model or not model.Parent then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health > 0
    end

    local healthValue = model:FindFirstChild("Health")
    if healthValue and (
        healthValue:IsA("NumberValue")
        or healthValue:IsA("IntValue")
    ) then
        return healthValue.Value > 0
    end

    local healthAttribute = model:GetAttribute("Health")
    if type(healthAttribute) == "number" then
        return healthAttribute > 0
    end

    return ModelMarkedTarget(model)
end

local function TargetRecord(model, player)
    if not model or model == LocalPlayer.Character then
        return nil
    end

    local aimPart = FindAimPart(model)
    local root = FindRootPart(model)

    if not aimPart or not root then
        return nil
    end

    return {
        Key = model,
        Model = model,
        Player = player,
        Name = player and player.DisplayName or model.Name,
        Humanoid = model:FindFirstChildOfClass("Humanoid"),
        Root = root,
        AimPart = aimPart,
    }
end

local CustomModels = {}

local function RegisterCustomModel(model)
    if not Settings.AimCustomModels and not Settings.AimTaggedModels then
        return
    end

    if not model
        or not model:IsA("Model")
        or model == LocalPlayer.Character then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then
            return
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local marked = ModelMarkedTarget(model)

    if (Settings.AimCustomModels and humanoid)
        or (Settings.AimTaggedModels and marked) then
        CustomModels[model] = true
    end
end

local function UnregisterCustomModel(model)
    CustomModels[model] = nil

    if AimState
        and AimState.TargetModel == model then
        AimState.TargetModel = nil
        AimState.TargetPart = nil
    end
end

-- Same initial human/model discovery style as the reference.
task.spawn(function()
    local descendants = Workspace:GetDescendants()

    for index, object in ipairs(descendants) do
        if object:IsA("Model") then
            RegisterCustomModel(object)
        elseif object:IsA("Humanoid")
            and object.Parent
            and object.Parent:IsA("Model") then
            RegisterCustomModel(object.Parent)
        end

        if index % 400 == 0 then
            task.wait()
        end
    end
end)

Workspace.DescendantAdded:Connect(function(object)
    if object:IsA("Model") then
        task.defer(RegisterCustomModel, object)
    elseif object:IsA("Humanoid")
        and object.Parent
        and object.Parent:IsA("Model") then
        task.defer(RegisterCustomModel, object.Parent)
    end
end)

Workspace.DescendantRemoving:Connect(function(object)
    if object:IsA("Model") and CustomModels[object] then
        UnregisterCustomModel(object)
    end
end)

for _, tag in ipairs({"AimTarget", "Targetable", "Enemy"}) do
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(object)
        if object:IsA("Model") then
            RegisterCustomModel(object)
        elseif object:IsA("BasePart") then
            local model = object:FindFirstAncestorOfClass("Model")
            if model then
                RegisterCustomModel(model)
            end
        end
    end)

    CollectionService:GetInstanceRemovedSignal(tag):Connect(function(object)
        local model = nil

        if object:IsA("Model") then
            model = object
        elseif object:IsA("BasePart") then
            model = object:FindFirstAncestorOfClass("Model")
        end

        if model
            and not ModelMarkedTarget(model)
            and not model:FindFirstChildOfClass("Humanoid") then
            UnregisterCustomModel(model)
        end
    end)
end

local function GetTargets()
    local list = {}
    local seen = {}

    if Settings.AimPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer
                and player.Character
                and ModelAlive(player.Character) then

                local record = TargetRecord(player.Character, player)
                if record then
                    seen[record.Model] = true
                    table.insert(list, record)
                end
            end
        end
    end

    for model in pairs(CustomModels) do
        if model and model.Parent and not seen[model] then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local marked = ModelMarkedTarget(model)

            local allowed =
                (Settings.AimCustomModels and humanoid ~= nil)
                or (Settings.AimTaggedModels and marked)

            if allowed and ModelAlive(model) then
                local record = TargetRecord(model, nil)
                if record then
                    seen[model] = true
                    table.insert(list, record)
                end
            end
        end
    end

    return list
end

local function CanSee(targetPos, targetModel)
    if not Settings.WallCheck then
        return true
    end

    local cam = Workspace.CurrentCamera
    if not cam then
        return true
    end

    local origin = cam.CFrame.Position
    local direction = targetPos - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = LocalPlayer.Character
        and {LocalPlayer.Character}
        or {}
    params.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction, params)

    if not result then
        return true
    end

    if targetModel
        and result.Instance
        and result.Instance:IsDescendantOf(targetModel) then
        return true
    end

    return false
end

local function ScoreTarget(target)
    local cam = Workspace.CurrentCamera
    if not cam
        or not target
        or not target.Model
        or not ModelAlive(target.Model) then
        return nil
    end

    local part = FindAimPart(target.Model)
    local root = FindRootPart(target.Model)

    if not part or not root then
        return nil
    end

    target.AimPart = part
    target.Root = root
    target.Humanoid = target.Model:FindFirstChildOfClass("Humanoid")

    local owner = target.Player
    if owner
        and Settings.TeamCheck
        and owner.Team ~= nil
        and owner.Team == LocalPlayer.Team then
        return nil
    end

    local worldDist = (root.Position - cam.CFrame.Position).Magnitude
    if worldDist > Settings.MaxDistance then
        return nil
    end

    local sp, onScreen = cam:WorldToViewportPoint(part.Position)
    if not onScreen or sp.Z <= 0 then
        return nil
    end

    local center
    if Settings.LockFOV then
        center = Vector2.new(
            cam.ViewportSize.X / 2,
            cam.ViewportSize.Y / 2
        )
    else
        center = UserInputService:GetMouseLocation()
    end

    local dx = sp.X - center.X
    local dy = sp.Y - center.Y
    local screenDist = math.sqrt(dx * dx + dy * dy)

    if screenDist > Settings.FOVRadius then
        return nil
    end

    if Settings.WallCheck and not CanSee(part.Position, target.Model) then
        return nil
    end

    return screenDist
end

local function BestTarget()
    local best = nil
    local bestDist = math.huge
    local targets = GetTargets()

    for _, target in ipairs(targets) do
        local dist = ScoreTarget(target)
        if dist and dist < bestDist then
            best = target
            bestDist = dist
        end
    end

    return best
end

local function GetClosestTarget()
    local target = BestTarget()
    if target then
        return target.Model, target.AimPart
    end

    return nil, nil
end


-- ===== FOV CIRCLE UPDATE =====
RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera or Camera
    if not Camera then return end

    fovCircle.Visible = Settings.FOVCircle
    fovCircle.Radius = Settings.FOVRadius
    if AimState.Active and AimState.TargetModel then
        fovCircle.Color = Color3.fromRGB(255, 80, 80)
    else
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    if Settings.LockFOV then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        fovCircle.Position = UserInputService:GetMouseLocation()
    end
end)

-- ===== AIMBOT =====
-- RAINZXDEV target-lock behavior:
-- when enabled it automatically picks the closest valid target inside the FOV.
-- Prediction and custom-model support are built in.
local cachedAimModel = nil
local cachedAimPart = nil
local aimScanAccumulator = 0
local AIM_SCAN_INTERVAL = 1 / 30

local function TargetStillValid(model, part)
    if not model or not model.Parent or not part or not part.Parent then
        return false
    end

    if not ModelAlive(model) then
        return false
    end

    local player = nil
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.Character == model then
            player = candidate
            break
        end
    end

    local record = TargetRecord(model, player)
    if not record then
        return false
    end

    return ScoreTarget(record) ~= nil
end

local function RestoreAutoRotate()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = true
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        AimState.Active = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        AimState.Active = false
        AimState.TargetModel = nil
        AimState.TargetPart = nil
        cachedAimModel = nil
        cachedAimPart = nil
        RestoreAutoRotate()
    end
end)

RunService:BindToRenderStep(
    "RAINZXDEV_Aim",
    Enum.RenderPriority.Camera.Value + 2,
    function(dt)
        if not Settings.Aimbot or not AimState.Active then
            AimState.TargetModel = nil
            AimState.TargetPart = nil
            cachedAimModel = nil
            cachedAimPart = nil
            aimScanAccumulator = 0
            RestoreAutoRotate()
            return
        end

        Camera = Workspace.CurrentCamera or Camera
        if not Camera then
            return
        end

        local currentModel = AimState.TargetModel
        local currentPart = AimState.TargetPart

        if not TargetStillValid(currentModel, currentPart) then
            aimScanAccumulator = aimScanAccumulator + dt

            if aimScanAccumulator >= AIM_SCAN_INTERVAL
                or not currentPart
                or not currentPart.Parent then

                aimScanAccumulator = 0
                cachedAimModel, cachedAimPart = GetClosestTarget()
                AimState.TargetModel = cachedAimModel
                AimState.TargetPart = cachedAimPart
            end
        end

        local model = AimState.TargetModel
        local part = model and FindAimPart(model) or nil
        AimState.TargetPart = part

        if not model or not part then
            return
        end

        if not TargetStillValid(model, part) then
            AimState.TargetModel = nil
            AimState.TargetPart = nil
            cachedAimModel = nil
            cachedAimPart = nil
            return
        end

        local velocity = part.AssemblyLinearVelocity
        local targetPos = part.Position + (velocity * Settings.Prediction)

        local cameraPosition = Camera.CFrame.Position
        local cameraDelta = targetPos - cameraPosition
        if cameraDelta.Magnitude <= 0.001 then
            return
        end

        -- Reference-style instant aim:
        -- keep camera position, snap look direction directly to target.
        Camera.CFrame = CFrame.lookAt(cameraPosition, targetPos)

        -- Reference-style first-person / shift-lock body follow.
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if root and root:IsA("BasePart") then
            local flatTarget = Vector3.new(
                targetPos.X,
                root.Position.Y,
                targetPos.Z
            )

            local flatDelta = flatTarget - root.Position
            if flatDelta.Magnitude > 0.001 then
                root.CFrame = CFrame.lookAt(root.Position, flatTarget)
            end
        end

        if humanoid then
            humanoid.AutoRotate = false
        end
    end
)

-- ===== TRIGGERBOT =====
-- Studio-safe detector. It exposes a BindableEvent named RAINZXDEVTrigger
-- instead of relying on executor-only mouse1click().
local triggerEvent = Instance.new("BindableEvent")
triggerEvent.Name = "RAINZXDEVTrigger"
do
    local oldTrigger = game:GetService("CoreGui"):FindFirstChild("RAINZXDEV_Trigger")
    if oldTrigger then
        oldTrigger:Destroy()
    end
    triggerEvent.Name = "RAINZXDEV_Trigger"
    triggerEvent.Parent = game:GetService("CoreGui")
end

local lastTrigger = 0
local triggerAccumulator = 0
local TRIGGER_INTERVAL = 1 / 30

local triggerRayParams = RaycastParams.new()
triggerRayParams.FilterType = Enum.RaycastFilterType.Exclude
triggerRayParams.IgnoreWater = true

RunService.RenderStepped:Connect(function(dt)
    if not Settings.Triggerbot or not Camera then
        triggerAccumulator = 0
        return
    end

    triggerAccumulator = triggerAccumulator + dt
    if triggerAccumulator < TRIGGER_INTERVAL then
        return
    end
    triggerAccumulator = 0

    triggerRayParams.FilterDescendantsInstances = {LocalPlayer.Character}

    local center = Camera.ViewportSize / 2
    local ray = Camera:ViewportPointToRay(center.X, center.Y)
    local result = Workspace:Raycast(
        ray.Origin,
        ray.Direction * Settings.MaxDistance,
        triggerRayParams
    )

    if not result then
        return
    end

    local model = result.Instance:FindFirstAncestorOfClass("Model")
    if not IsAliveModel(model) or model == LocalPlayer.Character then
        return
    end

    local owner = GetOwnerPlayer(model)
    if owner
        and Settings.TeamCheck
        and owner.Team ~= nil
        and owner.Team == LocalPlayer.Team then
        return
    end

    local now = os.clock()
    if now - lastTrigger >= (Settings.TriggerDelay / 1000) then
        lastTrigger = now
        triggerEvent:Fire(model, result.Instance)
    end
end)

-- ============================================================
-- ===== ESP (Names + Distance) =====
-- ============================================================

local espData = {}

local function createESP(player)
    if player == LocalPlayer or espData[player] then return end
    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = true
    text.Outline = true
    text.OutlineColor = Color3.fromRGB(0, 0, 0)
    text.Color = Color3.fromRGB(255, 255, 255)
    text.Visible = false
    espData[player] = text
end

local function updateESP()
    for player, text in pairs(espData) do
        repeat
            if not Settings.ESPEnabled then
                text.Visible = false
                break
            end

            local char = player.Character
            if not char then
                text.Visible = false
                break
            end

            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then
                text.Visible = false
                break
            end

            local pos, vis = Camera:WorldToViewportPoint(root.Position)
            if not vis then
                text.Visible = false
                break
            end

            local label = ""
            if Settings.ESPName then
                label = player.Name .. " "
            end

            if Settings.ESPDistance and LocalPlayer.Character then
                local lroot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if lroot then
                    local dist = (lroot.Position - root.Position).Magnitude
                    label = label .. "[" .. math.floor(dist) .. "m]"
                end
            end

            text.Text = label
            text.Position = Vector2.new(pos.X, pos.Y - 30)
            text.Visible = true
        until true
    end
end

local function removeESP(player)
    if espData[player] then
        espData[player]:Remove()
        espData[player] = nil
    end
end

local function onPlayerAdded(player)
    if player == LocalPlayer then return end
    createESP(player)
    createSkeleton(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        removeESP(player)
        removeSkeleton(player)
        createESP(player)
        createSkeleton(player)
    end)
end

for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    removeSkeleton(player)
end)

local espAccumulator = 0
local skeletonAccumulator = 0
local ESP_INTERVAL = 1 / 30
local SKELETON_INTERVAL = 1 / 20

RunService.RenderStepped:Connect(function(dt)
    espAccumulator = espAccumulator + dt
    skeletonAccumulator = skeletonAccumulator + dt

    if espAccumulator >= ESP_INTERVAL then
        espAccumulator = 0
        updateESP()
    end

    if skeletonAccumulator >= SKELETON_INTERVAL then
        skeletonAccumulator = 0
        updateSkeletonESP()
    end

    if Settings.RainbowESP then
        rainbowHue = (
            rainbowHue + (dt * Settings.RainbowSpeed * 0.5)
        ) % 1
    end
end)

-- ============================================================
-- ===== PLAYER TAB LOGIC =====
-- ============================================================

local function getPlayersList()
    local list = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.Name)
        end
    end
    return list
end

local function getSelectedPlayer()
    return Players:FindFirstChild(Settings.SelectedPlayer)
end

-- ============================================================================
-- RAINZXDEV PuckUI v3.3.1 interface
-- ============================================================================

local Window = PuckUI:CreateWindow({
    Name = "RAINZXDEV Hub",
    GuiName = "RAINZXDEV_AimESP",
    Width = 500,
    Height = 560,
})

local CombatTab = Window:CreateTab("Combat")
local VisualTab = Window:CreateTab("Visuals")
local PlayerTab = Window:CreateTab("Player")
local SettingsTab = Window:CreateTab("Settings")

-- ============================================================================
-- Combat
-- ============================================================================

CombatTab:CreateSection("Aim Assist")

CombatTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = Settings.Aimbot,
    Callback = function(value)
        Settings.Aimbot = value
        if not value then
            AimState.Active = false
            AimState.TargetModel = nil
            AimState.TargetPart = nil
            cachedAimModel = nil
            cachedAimPart = nil
            RestoreAutoRotate()
        end
        saveSettings()
    end,
})

CombatTab:CreateLabel("Hold RMB while Aimbot is enabled.")

CombatTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = Settings.TeamCheck,
    Callback = function(value)
        Settings.TeamCheck = value
        saveSettings()
    end,
})

CombatTab:CreateToggle({
    Name = "Wall / Visibility Check",
    CurrentValue = Settings.WallCheck,
    Callback = function(value)
        Settings.WallCheck = value
        saveSettings()
    end,
})

CombatTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Settings.FOVCircle,
    Callback = function(value)
        Settings.FOVCircle = value
        saveSettings()
    end,
})

CombatTab:CreateToggle({
    Name = "Lock FOV To Screen Center",
    CurrentValue = Settings.LockFOV,
    Callback = function(value)
        Settings.LockFOV = value
        saveSettings()
    end,
})

CombatTab:CreateSection("Targets")

CombatTab:CreateToggle({
    Name = "Target Players",
    CurrentValue = Settings.AimPlayers,
    Callback = function(value)
        Settings.AimPlayers = value
        saveSettings()
    end,
})

CombatTab:CreateToggle({
    Name = "Target Custom / NPC Models",
    CurrentValue = Settings.AimCustomModels,
    Callback = function(value)
        Settings.AimCustomModels = value
        saveSettings()
    end,
})

CombatTab:CreateToggle({
    Name = "Target Tagged Models",
    CurrentValue = Settings.AimTaggedModels,
    Callback = function(value)
        Settings.AimTaggedModels = value
        saveSettings()
    end,
})

CombatTab:CreateDropdown({
    Name = "Target Part",
    Options = {
        "Head",
        "Neck",
        "Torso",
        "HumanoidRootPart",
        "Left Arm",
        "Right Arm",
    },
    CurrentOption = Settings.TargetPart,
    Callback = function(value)
        Settings.TargetPart = value
        AimState.TargetModel = nil
        AimState.TargetPart = nil
        cachedAimModel = nil
        cachedAimPart = nil
        saveSettings()
    end,
})

CombatTab:CreateSection("FOV / Ballistics")

CombatTab:CreateSlider({
    Name = "FOV Radius",
    Range = {0, 500},
    Increment = 1,
    CurrentValue = Settings.FOVRadius,
    Suffix = " px",
    Callback = function(value)
        Settings.FOVRadius = value
        fovCircle.Radius = value
        saveSettings()
    end,
})

CombatTab:CreateSlider({
    Name = "Prediction",
    Range = {0, 30},
    Increment = 1,
    CurrentValue = math.floor(Settings.Prediction * 100 + 0.5),
    Suffix = "/100s",
    Callback = function(value)
        Settings.Prediction = value / 100
        saveSettings()
    end,
})

CombatTab:CreateSlider({
    Name = "Max Distance",
    Range = {100, 5000},
    Increment = 50,
    CurrentValue = Settings.MaxDistance,
    Suffix = " studs",
    Callback = function(value)
        Settings.MaxDistance = value
        saveSettings()
    end,
})

CombatTab:CreateSection("Extra Combat")

CombatTab:CreateToggle({
    Name = "Triggerbot Detector",
    CurrentValue = Settings.Triggerbot,
    Callback = function(value)
        Settings.Triggerbot = value
        saveSettings()
    end,
})

CombatTab:CreateSlider({
    Name = "Trigger Delay",
    Range = {0, 500},
    Increment = 5,
    CurrentValue = Settings.TriggerDelay,
    Suffix = " ms",
    Callback = function(value)
        Settings.TriggerDelay = value
        saveSettings()
    end,
})

-- ============================================================================
-- Visuals
-- ============================================================================

VisualTab:CreateSection("ESP")

VisualTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Settings.ESPEnabled,
    Callback = function(value)
        Settings.ESPEnabled = value
        saveSettings()
    end,
})

VisualTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = Settings.ESPName,
    Callback = function(value)
        Settings.ESPName = value
        saveSettings()
    end,
})

VisualTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = Settings.ESPDistance,
    Callback = function(value)
        Settings.ESPDistance = value
        saveSettings()
    end,
})

VisualTab:CreateToggle({
    Name = "Skeleton ESP",
    CurrentValue = Settings.SkeletonESP,
    Callback = function(value)
        Settings.SkeletonESP = value
        saveSettings()
    end,
})

VisualTab:CreateLabel("Skeleton: green = visible · red = occluded")


VisualTab:CreateToggle({
    Name = "Rainbow ESP",
    CurrentValue = Settings.RainbowESP,
    Callback = function(value)
        Settings.RainbowESP = value
        saveSettings()
    end,
})

VisualTab:CreateSlider({
    Name = "Rainbow Speed",
    Range = {1, 30},
    Increment = 1,
    CurrentValue = math.floor(Settings.RainbowSpeed * 10 + 0.5),
    Suffix = "/10",
    Callback = function(value)
        Settings.RainbowSpeed = value / 10
        saveSettings()
    end,
})

-- ============================================================================
-- Player
-- ============================================================================

PlayerTab:CreateSection("Player Selection")

local function getPlayerOptions()
    local list = getPlayersList()
    if #list == 0 then
        return {"No players"}
    end
    return list
end

local initialPlayers = getPlayerOptions()
if Settings.SelectedPlayer == ""
    or not Players:FindFirstChild(Settings.SelectedPlayer) then
    if initialPlayers[1] ~= "No players" then
        Settings.SelectedPlayer = initialPlayers[1]
    end
end

local PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "Selected Player",
    Options = initialPlayers,
    CurrentOption = Settings.SelectedPlayer ~= ""
        and Settings.SelectedPlayer
        or initialPlayers[1],
    Callback = function(value)
        if value ~= "No players" then
            Settings.SelectedPlayer = value
            saveSettings()
        end
    end,
})

PlayerTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local options = getPlayerOptions()

        if PlayerDropdown.Refresh then
            PlayerDropdown:Refresh(options)
        elseif PlayerDropdown.SetOptions then
            PlayerDropdown:SetOptions(options)
        end

        if options[1] ~= "No players"
            and not Players:FindFirstChild(Settings.SelectedPlayer) then
            Settings.SelectedPlayer = options[1]
            if PlayerDropdown.Set then
                PlayerDropdown:Set(options[1])
            end
            saveSettings()
        end

        PuckUI:Notify({
            Title = "RAINZXDEV Hub",
            Content = "Player list refreshed.",
            Duration = 2,
        })
    end,
})

PlayerTab:CreateToggle({
    Name = "Spectate Player",
    CurrentValue = Settings.Spectate,
    Callback = function(value)
        Settings.Spectate = value
        saveSettings()
    end,
})

-- Spectate does not need a render-frame loop.
local spectateAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
    spectateAccumulator = spectateAccumulator + dt
    if spectateAccumulator < 0.10 then
        return
    end
    spectateAccumulator = 0

    Camera = Workspace.CurrentCamera or Camera
    if not Camera then
        return
    end

    if Settings.Spectate then
        local target = getSelectedPlayer()
        if target and target.Character then
            local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and Camera.CameraSubject ~= humanoid then
                Camera.CameraSubject = humanoid
            end
        end
    elseif LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and Camera.CameraSubject ~= humanoid then
            Camera.CameraSubject = humanoid
        end
    end
end)

-- ============================================================================
-- Settings
-- ============================================================================

SettingsTab:CreateSection("Interface")

SettingsTab:CreateLabel("RAINZXDEV Hub UI · v3.3.1")
SettingsTab:CreateLabel("Shared RAINZXDEV UI keybind is configured below.")

SettingsTab:CreateParagraph({
    Title = "Aim Controls",
    Content =
        "Enable Aimbot in Combat, then hold RMB. "
        .. "Target discovery uses players, Humanoid/custom models, "
        .. "and AimTarget / Targetable / Enemy tagged models.",
})

PuckUI:Notify({
    Title = "RAINZXDEV Hub",
    Content = "Aim / ESP loaded.",
    Duration = 3,
})

Window:SetCloseCallback(function()
    pcall(function()
        RunService:UnbindFromRenderStep("RAINZXDEV_Aim")
    end)

    AimState.Active = false
    AimState.TargetModel = nil
    AimState.TargetPart = nil
    RestoreAutoRotate()

    fovCircle.Visible = false

    for _, data in pairs(skeletonData) do
        for _, line in pairs(data) do
            pcall(function()
                line:Remove()
            end)
        end
    end

    for _, drawing in pairs(espData) do
        pcall(function()
            drawing:Remove()
        end)
    end

    if triggerEvent then
        pcall(function()
            triggerEvent:Destroy()
        end)
    end

    Window:Destroy()
end)

print("RAINZXDEV Hub - Aim / ESP loaded")
print("Features: Aimbot | Trigger Detector | ESP | Skeleton | Rainbow | Spectate")
