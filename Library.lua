--[[
    Koi UI Library
    Compact dark utility-style Roblox UI

    Features:
    - Window
    - Tabs
    - Sections
    - Buttons
    - Toggles
    - Sliders
    - Dropdowns
    - Textboxes
    - Keybinds
    - Labels
    - Notifications
    - Window dragging
    - UI toggle key
    - Element keybinds
    - Destroy
]]

local Library = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local COLORS = {
    Background = Color3.fromRGB(13, 13, 15),
    Main = Color3.fromRGB(17, 17, 19),
    Secondary = Color3.fromRGB(20, 20, 23),
    Element = Color3.fromRGB(24, 24, 27),

    Border = Color3.fromRGB(58, 58, 63),
    BorderDark = Color3.fromRGB(7, 7, 8),

    Text = Color3.fromRGB(220, 220, 220),
    SubText = Color3.fromRGB(135, 135, 140),
    Disabled = Color3.fromRGB(80, 80, 85),

    Accent = Color3.fromRGB(154, 102, 190),
    AccentDark = Color3.fromRGB(105, 70, 135),

    White = Color3.fromRGB(240, 240, 240),
}

local FONT = Enum.Font.Code

--------------------------------------------------
-- UTILITIES
--------------------------------------------------

local function Create(class, properties)
    local object = Instance.new(class)

    for property, value in pairs(properties or {}) do
        object[property] = value
    end

    return object
end

local function Corner(parent, radius)
    local corner = Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 2),
        Parent = parent
    })

    return corner
end

local function Stroke(parent, color, thickness)
    local stroke = Create("UIStroke", {
        Color = color or COLORS.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })

    return stroke
end

local function Padding(parent, left, right, top, bottom)
    return Create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent
    })
end

local function Tween(object, properties, duration)
    local info = TweenInfo.new(
        duration or 0.15,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )

    return TweenService:Create(object, info, properties)
end

local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

--------------------------------------------------
-- WINDOW
--------------------------------------------------

function Library:CreateWindow(options)

    options = options or {}

    local Window = {}

    Window.Title = options.Title or "Koi"
    Window.SubTitle = options.SubTitle or "build: beta"
    Window.ToggleKey = options.ToggleKey or Enum.KeyCode.Insert
    Window.Visible = true
    Window.Tabs = {}
    Window.Elements = {}

    --------------------------------------------------
    -- SCREEN GUI
    --------------------------------------------------

    local ScreenGui = Create("ScreenGui", {
        Name = "KoiUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    pcall(function()
        ScreenGui.Parent = game:GetService("CoreGui")
    end)

    if not ScreenGui.Parent then
        ScreenGui.Parent = Player:WaitForChild("PlayerGui")
    end

    Window.ScreenGui = ScreenGui

    --------------------------------------------------
    -- MAIN WINDOW
    --------------------------------------------------

    local Main = Create("Frame", {
        Name = "Main",
        Size = options.Size or UDim2.fromOffset(650, 430),
        Position = UDim2.new(0.5, -325, 0.5, -215),
        BackgroundColor3 = COLORS.Main,
        BorderSizePixel = 0,
        Parent = ScreenGui
    })

    Stroke(Main, COLORS.Border, 1)

    Window.Main = Main

    --------------------------------------------------
    -- TOP BAR
    --------------------------------------------------

    local TopBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        Parent = Main
    })

    Stroke(TopBar, COLORS.BorderDark, 1)

    local Title = Create("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(9, 4),
        Size = UDim2.new(0.6, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = Window.Title,
        TextColor3 = COLORS.White,
        TextSize = 13,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar
    })

    local SubTitle = Create("TextLabel", {
        Name = "SubTitle",
        Position = UDim2.fromOffset(9, 20),
        Size = UDim2.new(0.6, 0, 0, 13),
        BackgroundTransparency = 1,
        Text = Window.SubTitle,
        TextColor3 = COLORS.SubText,
        TextSize = 10,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar
    })

    --------------------------------------------------
    -- DRAGGING
    --------------------------------------------------

    local dragging = false
    local dragStart
    local startPosition

    TopBar.InputBegan:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end

    end)

    UserInputService.InputChanged:Connect(function(input)

        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

    end)

    --------------------------------------------------
    -- TAB BAR
    --------------------------------------------------

    local TabBar = Create("Frame", {
        Name = "Tabs",
        Position = UDim2.fromOffset(0, 38),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        Parent = Main
    })

    Stroke(TabBar, COLORS.BorderDark, 1)

    local TabLayout = Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
        Parent = TabBar
    })

    --------------------------------------------------
    -- CONTENT
    --------------------------------------------------

    local Content = Create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(0, 70),
        Size = UDim2.new(1, 0, 1, -70),
        BackgroundTransparency = 1,
        Parent = Main
    })

    --------------------------------------------------
    -- VISIBILITY
    --------------------------------------------------

    function Window:SetVisible(value)
        Window.Visible = value
        Main.Visible = value
    end

    function Window:Toggle()
        Window:SetVisible(not Window.Visible)
    end

    --------------------------------------------------
    -- NOTIFICATIONS
    --------------------------------------------------

    local NotificationHolder = Create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -15, 1, -15),
        Size = UDim2.fromOffset(260, 400),
        BackgroundTransparency = 1,
        Parent = ScreenGui
    })

    local NotificationLayout = Create("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        Parent = NotificationHolder
    })

    function Window:Notify(title, message, duration)

        duration = duration or 3

        local Notification = Create("Frame", {
            Size = UDim2.fromOffset(250, 58),
            BackgroundColor3 = COLORS.Main,
            BorderSizePixel = 0,
            Parent = NotificationHolder
        })

        Stroke(Notification, COLORS.Border, 1)
        Corner(Notification, 2)

        local Accent = Create("Frame", {
            Size = UDim2.fromOffset(3, 58),
            BackgroundColor3 = COLORS.Accent,
            BorderSizePixel = 0,
            Parent = Notification
        })

        local NTitle = Create("TextLabel", {
            Position = UDim2.fromOffset(12, 7),
            Size = UDim2.new(1, -18, 0, 16),
            BackgroundTransparency = 1,
            Text = title or "Notification",
            TextColor3 = COLORS.White,
            TextSize = 12,
            Font = FONT,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Notification
        })

        local NMessage = Create("TextLabel", {
            Position = UDim2.fromOffset(12, 25),
            Size = UDim2.new(1, -18, 0, 25),
            BackgroundTransparency = 1,
            Text = message or "",
            TextColor3 = COLORS.SubText,
            TextSize = 10,
            Font = FONT,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Notification
        })

        Notification.Position = UDim2.new(1, 20, 0, 0)

        Tween(Notification, {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()

        task.delay(duration, function()

            if Notification and Notification.Parent then

                local animation = Tween(Notification, {
                    Position = UDim2.new(1, 20, 0, 0)
                })

                animation:Play()

                animation.Completed:Wait()

                Notification:Destroy()

            end

        end)

    end

    --------------------------------------------------
    -- CREATE TAB
    --------------------------------------------------

    function Window:CreateTab(name)

        local Tab = {}

        Tab.Name = name
        Tab.Sections = {}

        --------------------------------------------------
        -- TAB BUTTON
        --------------------------------------------------

        local Button = Create("TextButton", {
            Name = name,
            Size = UDim2.fromOffset(100, 32),
            BackgroundColor3 = COLORS.Background,
            BorderSizePixel = 0,
            Text = name,
            TextColor3 = COLORS.SubText,
            TextSize = 11,
            Font = FONT,
            AutoButtonColor = false,
            Parent = TabBar
        })

        local TabIndicator = Create("Frame", {
            Position = UDim2.new(0, 0, 1, -2),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = COLORS.Accent,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Button
        })

        --------------------------------------------------
        -- TAB PAGE
        --------------------------------------------------

        local Page = Create("ScrollingFrame", {
            Name = name .. "_Page",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = COLORS.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            Parent = Content
        })

        Padding(Page, 7, 7, 7, 7)

        local PageLayout = Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 7),
            Parent = Page
        })

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()

            Page.CanvasSize = UDim2.fromOffset(
                0,
                PageLayout.AbsoluteContentSize.Y + 14
            )

        end)

        Tab.Button = Button
        Tab.Page = Page
        Tab.Layout = PageLayout

        --------------------------------------------------
        -- ACTIVATE
        --------------------------------------------------

        function Tab:Activate()

            for _, other in pairs(Window.Tabs) do

                other.Page.Visible = false
                other.Button.TextColor3 = COLORS.SubText
                other.Indicator.Visible = false

            end

            Page.Visible = true
            Button.TextColor3 = COLORS.White
            TabIndicator.Visible = true

            Window.ActiveTab = Tab

        end

        Tab.Indicator = TabIndicator

        --------------------------------------------------
        -- CLICK
        --------------------------------------------------

        Button.MouseButton1Click:Connect(function()
            Tab:Activate()
        end)

        --------------------------------------------------
        -- SECTION
        --------------------------------------------------

        function Tab:CreateSection(sectionName)

            local Section = {}

            local Frame = Create("Frame", {
                Name = sectionName,
                Size = UDim2.new(1, 0, 0, 100),
                BackgroundColor3 = COLORS.Main,
                BorderSizePixel = 0,
                Parent = Page
            })

            Stroke(Frame, COLORS.Border, 1)

            local Header = Create("TextLabel", {
                Position = UDim2.fromOffset(8, 5),
                Size = UDim2.new(1, -16, 0, 18),
                BackgroundTransparency = 1,
                Text = sectionName,
                TextColor3 = COLORS.White,
                TextSize = 11,
                Font = FONT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Frame
            })

            local Divider = Create("Frame", {
                Position = UDim2.fromOffset(7, 26),
                Size = UDim2.new(1, -14, 0, 1),
                BackgroundColor3 = COLORS.BorderDark,
                BorderSizePixel = 0,
                Parent = Frame
            })

            local Elements = Create("Frame", {
                Position = UDim2.fromOffset(7, 32),
                Size = UDim2.new(1, -14, 0, 0),
                BackgroundTransparency = 1,
                Parent = Frame
            })

            local ElementLayout = Create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = Elements
            })

            ElementLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()

                local height = ElementLayout.AbsoluteContentSize.Y + 39

                Frame.Size = UDim2.new(
                    1,
                    0,
                    0,
                    height
                )

            end)

            Section.Frame = Frame
            Section.Elements = Elements

            --------------------------------------------------
            -- LABEL
            --------------------------------------------------

            function Section:CreateLabel(text)

                local Label = Create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    Text = text,
                    TextColor3 = COLORS.SubText,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Elements
                })

                Padding(Label, 4, 4, 0, 0)

                return Label

            end

            --------------------------------------------------
            -- BUTTON
            --------------------------------------------------

            function Section:CreateButton(options)

                options = options or {}

                local Button = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = COLORS.Element,
                    BorderSizePixel = 0,
                    Text = options.Name or "Button",
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = FONT,
                    AutoButtonColor = false,
                    Parent = Elements
                })

                Stroke(Button, COLORS.BorderDark, 1)

                Button.MouseEnter:Connect(function()

                    Tween(Button, {
                        BackgroundColor3 = Color3.fromRGB(29, 29, 32)
                    }):Play()

                end)

                Button.MouseLeave:Connect(function()

                    Tween(Button, {
                        BackgroundColor3 = COLORS.Element
                    }):Play()

                end)

                Button.MouseButton1Click:Connect(function()

                    if options.Callback then
                        task.spawn(options.Callback)
                    end

                end)

                return Button

            end

            --------------------------------------------------
            -- TOGGLE
            --------------------------------------------------

            function Section:CreateToggle(options)

                options = options or {}

                local Value = options.Default or false

                local Container = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundTransparency = 1,
                    Parent = Elements
                })

                local Button = Create("TextButton", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Parent = Container
                })

                local Box = Create("Frame", {
                    Position = UDim2.fromOffset(2, 5),
                    Size = UDim2.fromOffset(15, 15),
                    BackgroundColor3 = COLORS.Background,
                    BorderSizePixel = 0,
                    Parent = Container
                })

                Stroke(Box, COLORS.Border, 1)

                local Check = Create("Frame", {
                    Position = UDim2.fromOffset(3, 3),
                    Size = UDim2.new(1, -6, 1, -6),
                    BackgroundColor3 = COLORS.Accent,
                    BorderSizePixel = 0,
                    Visible = Value,
                    Parent = Box
                })

                local Text = Create("TextLabel", {
                    Position = UDim2.fromOffset(25, 0),
                    Size = UDim2.new(1, -100, 1, 0),
                    BackgroundTransparency = 1,
                    Text = options.Name or "Toggle",
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Container
                })

                local KeyLabel = Create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -4, 0, 5),
                    Size = UDim2.fromOffset(55, 16),
                    BackgroundTransparency = 1,
                    Text = "",
                    TextColor3 = COLORS.SubText,
                    TextSize = 9,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Container
                })

                local Toggle = {}

                function Toggle:Set(value)

                    Value = value == true

                    Check.Visible = Value

                    if options.Callback then
                        task.spawn(options.Callback, Value)
                    end

                end

                function Toggle:Get()
                    return Value
                end

                Button.MouseButton1Click:Connect(function()
                    Toggle:Set(not Value)
                end)

                --------------------------------------------------
                -- TOGGLE KEYBIND
                --------------------------------------------------

                if options.Keybind then

                    KeyLabel.Text = "[" .. options.Keybind.Name .. "]"

                    UserInputService.InputBegan:Connect(function(input, processed)

                        if processed then
                            return
                        end

                        if input.KeyCode == options.Keybind then
                            Toggle:Set(not Value)
                        end

                    end)

                end

                Toggle:Set(Value)

                return Toggle

            end

            --------------------------------------------------
            -- SLIDER
            --------------------------------------------------

            function Section:CreateSlider(options)

                options = options or {}

                local Minimum = options.Min or 0
                local Maximum = options.Max or 100
                local Value = Clamp(
                    options.Default or Minimum,
                    Minimum,
                    Maximum
                )

                local Decimals = options.Decimals or 0

                local Container = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 42),
                    BackgroundTransparency = 1,
                    Parent = Elements
                })

                local Name = Create("TextLabel", {
                    Position = UDim2.fromOffset(3, 0),
                    Size = UDim2.new(0.6, 0, 0, 17),
                    BackgroundTransparency = 1,
                    Text = options.Name or "Slider",
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Container
                })

                local ValueLabel = Create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -3, 0, 0),
                    Size = UDim2.fromOffset(80, 17),
                    BackgroundTransparency = 1,
                    TextColor3 = COLORS.SubText,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Container
                })

                local Bar = Create("Frame", {
                    Position = UDim2.fromOffset(3, 21),
                    Size = UDim2.new(1, -6, 0, 8),
                    BackgroundColor3 = COLORS.Background,
                    BorderSizePixel = 0,
                    Parent = Container
                })

                Stroke(Bar, COLORS.BorderDark, 1)

                local Fill = Create("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = COLORS.Accent,
                    BorderSizePixel = 0,
                    Parent = Bar
                })

                local Slider = {}
                local Sliding = false

                local function SetSlider(value)

                    Value = Clamp(value, Minimum, Maximum)

                    local percent =
                        (Value - Minimum) /
                        (Maximum - Minimum)

                    Fill.Size = UDim2.new(
                        percent,
                        0,
                        1,
                        0
                    )

                    ValueLabel.Text = tostring(
                        Round(Value, Decimals)
                    )

                    if options.Callback then
                        task.spawn(
                            options.Callback,
                            Round(Value, Decimals)
                        )
                    end

                end

                Bar.InputBegan:Connect(function(input)

                    if input.UserInputType == Enum.UserInputType.MouseButton1 then

                        Sliding = true

                        local percent =
                            (input.Position.X - Bar.AbsolutePosition.X)
                            / Bar.AbsoluteSize.X

                        SetSlider(
                            Minimum +
                            (Maximum - Minimum) *
                            Clamp(percent, 0, 1)
                        )

                    end

                end)

                UserInputService.InputChanged:Connect(function(input)

                    if not Sliding then
                        return
                    end

                    if input.UserInputType == Enum.UserInputType.MouseMovement then

                        local percent =
                            (input.Position.X - Bar.AbsolutePosition.X)
                            / Bar.AbsoluteSize.X

                        SetSlider(
                            Minimum +
                            (Maximum - Minimum) *
                            Clamp(percent, 0, 1)
                        )

                    end

                end)

                UserInputService.InputEnded:Connect(function(input)

                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Sliding = false
                    end

                end)

                function Slider:Set(value)
                    SetSlider(value)
                end

                function Slider:Get()
                    return Value
                end

                SetSlider(Value)

                return Slider

            end

            --------------------------------------------------
            -- DROPDOWN
            --------------------------------------------------

            function Section:CreateDropdown(options)

                options = options or {}

                local Options = options.Options or {}
                local Current = options.Default or Options[1]

                local Open = false

                local Container = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                    Parent = Elements
                })

                local MainButton = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = COLORS.Element,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    Parent = Container
                })

                Stroke(MainButton, COLORS.BorderDark, 1)

                local Name = Create("TextLabel", {
                    Position = UDim2.fromOffset(7, 0),
                    Size = UDim2.new(0.5, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = options.Name or "Dropdown",
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = MainButton
                })

                local CurrentLabel = Create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -20, 0, 0),
                    Size = UDim2.fromOffset(130, 26),
                    BackgroundTransparency = 1,
                    Text = tostring(Current or ""),
                    TextColor3 = COLORS.SubText,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = MainButton
                })

                local Arrow = Create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -5, 0, 0),
                    Size = UDim2.fromOffset(12, 26),
                    BackgroundTransparency = 1,
                    Text = "+",
                    TextColor3 = COLORS.SubText,
                    TextSize = 11,
                    Font = FONT,
                    Parent = MainButton
                })

                local List = Create("Frame", {
                    Position = UDim2.fromOffset(0, 29),
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundColor3 = COLORS.Main,
                    BorderSizePixel = 0,
                    Visible = false,
                    ZIndex = 20,
                    Parent = Container
                })

                Stroke(List, COLORS.Border, 1)

                local ListLayout = Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = List
                })

                local Dropdown = {}

                local function RefreshSize()

                    local height =
                        ListLayout.AbsoluteContentSize.Y

                    List.Size = UDim2.new(
                        1,
                        0,
                        0,
                        height
                    )

                end

                for _, option in ipairs(Options) do

                    local OptionButton = Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundColor3 = COLORS.Main,
                        BorderSizePixel = 0,
                        Text = tostring(option),
                        TextColor3 = COLORS.SubText,
                        TextSize = 10,
                        Font = FONT,
                        AutoButtonColor = false,
                        ZIndex = 21,
                        Parent = List
                    })

                    OptionButton.MouseEnter:Connect(function()

                        OptionButton.BackgroundColor3 =
                            COLORS.Element

                    end)

                    OptionButton.MouseLeave:Connect(function()

                        OptionButton.BackgroundColor3 =
                            COLORS.Main

                    end)

                    OptionButton.MouseButton1Click:Connect(function()

                        Current = option

                        CurrentLabel.Text = tostring(option)

                        if options.Callback then
                            task.spawn(
                                options.Callback,
                                option
                            )
                        end

                        Open = false
                        List.Visible = false
                        Arrow.Text = "+"

                        Container.Size =
                            UDim2.new(1, 0, 0, 28)

                    end)

                end

                MainButton.MouseButton1Click:Connect(function()

                    Open = not Open

                    List.Visible = Open

                    if Open then
                        Arrow.Text = "-"
                        RefreshSize()

                        Container.Size = UDim2.new(
                            1,
                            0,
                            0,
                            28 + List.AbsoluteSize.Y
                        )
                    else
                        Arrow.Text = "+"
                        Container.Size =
                            UDim2.new(1, 0, 0, 28)
                    end

                end)

                function Dropdown:Set(value)

                    for _, option in ipairs(Options) do

                        if option == value then

                            Current = value
                            CurrentLabel.Text =
                                tostring(value)

                            if options.Callback then
                                task.spawn(
                                    options.Callback,
                                    value
                                )
                            end

                            break
                        end

                    end

                end

                function Dropdown:Get()
                    return Current
                end

                return Dropdown

            end

            --------------------------------------------------
            -- TEXTBOX
            --------------------------------------------------

            function Section:CreateTextbox(options)

                options = options or {}

                local Container = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 27),
                    BackgroundTransparency = 1,
                    Parent = Elements
                })

                local Box = Create("TextBox", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = COLORS.Element,
                    BorderSizePixel = 0,
                    Text = options.Default or "",
                    PlaceholderText = options.Placeholder or "Enter text...",
                    PlaceholderColor3 = COLORS.Disabled,
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = FONT,
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Container
                })

                Stroke(Box, COLORS.BorderDark, 1)

                Padding(Box, 7, 7, 0, 0)

                Box.FocusLost:Connect(function(enterPressed)

                    if options.Callback then

                        task.spawn(
                            options.Callback,
                            Box.Text,
                            enterPressed
                        )

                    end

                end)

                return Box

            end

            --------------------------------------------------
            -- KEYBIND
            --------------------------------------------------

            function Section:CreateKeybind(options)

                options = options or {}

                local CurrentKey =
                    options.Default or Enum.KeyCode.Unknown

                local Listening = false

                local Container = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 27),
                    BackgroundTransparency = 1,
                    Parent = Elements
                })

                local Name = Create("TextLabel", {
                    Position = UDim2.fromOffset(3, 0),
                    Size = UDim2.new(0.5, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = options.Name or "Keybind",
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = FONT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Container
                })

                local Button = Create("TextButton", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.fromOffset(90, 25),
                    BackgroundColor3 = COLORS.Element,
                    BorderSizePixel = 0,
                    Text = CurrentKey.Name,
                    TextColor3 = COLORS.SubText,
                    TextSize = 9,
                    Font = FONT,
                    AutoButtonColor = false,
                    Parent = Container
                })

                Stroke(Button, COLORS.BorderDark, 1)

                local Keybind = {}

                Button.MouseButton1Click:Connect(function()

                    Listening = true
                    Button.Text = "press key..."

                end)

                UserInputService.InputBegan:Connect(function(input, processed)

                    if not Listening then
                        return
                    end

                    if input.UserInputType == Enum.UserInputType.Keyboard then

                        CurrentKey = input.KeyCode

                        Button.Text = CurrentKey.Name

                        Listening = false

                        if options.Callback then
                            task.spawn(
                                options.Callback,
                                CurrentKey
                            )
                        end

                    end

                end)

                function Keybind:Set(key)

                    CurrentKey = key
                    Button.Text = key.Name

                    if options.Callback then
                        task.spawn(
                            options.Callback,
                            CurrentKey
                        )
                    end

                end

                function Keybind:Get()
                    return CurrentKey
                end

                return Keybind

            end

            table.insert(Tab.Sections, Section)

            return Section

        end

        table.insert(Window.Tabs, Tab)

        if #Window.Tabs == 1 then
            Tab:Activate()
        end

        return Tab

    end

    --------------------------------------------------
    -- TOGGLE WINDOW KEY
    --------------------------------------------------

    UserInputService.InputBegan:Connect(function(input, processed)

        if processed then
            return
        end

        if input.KeyCode == Window.ToggleKey then
            Window:Toggle()
        end

    end)

    --------------------------------------------------
    -- CHANGE TOGGLE KEY
    --------------------------------------------------

    function Window:SetToggleKey(key)
        Window.ToggleKey = key
    end

    --------------------------------------------------
    -- GET GUI
    --------------------------------------------------

    function Window:GetGui()
        return ScreenGui
    end

    --------------------------------------------------
    -- DESTROY
    --------------------------------------------------

    function Window:Destroy()

        if ScreenGui then
            ScreenGui:Destroy()
        end

        Window.Tabs = {}
        Window.Elements = {}

    end

    --------------------------------------------------
    -- FOCUS
    --------------------------------------------------

    function Window:Focus()

        Main.Visible = true
        Window.Visible = true

        Main.ZIndex = 100

    end

    return Window
end

return Library
