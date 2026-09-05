--[[
    ModernUI Library
    Structure inspired by Linoria (Window -> Tabs -> Sections -> Elements),
    reskinned with a flatter/modern look: rounded corners, soft strokes,
    accent-based highlights, and tween-driven animations.

    USAGE EXAMPLE (bottom of file, commented out):
        local Library = loadstring(readfile("ModernUILibrary.lua"))()
        local Window = Library:CreateWindow("Modern UI")
        local Tab = Window:CreateTab("Main")
        local Section = Tab:CreateSection("General")
        Section:AddToggle("Example Toggle", false, function(v) print(v) end)
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Theme
local Theme = {
    Background   = Color3.fromRGB(20, 20, 24),
    Panel        = Color3.fromRGB(27, 27, 32),
    Elevated     = Color3.fromRGB(34, 34, 40),
    Accent       = Color3.fromRGB(130, 100, 255),
    AccentDim    = Color3.fromRGB(90, 70, 190),
    Text         = Color3.fromRGB(235, 235, 240),
    SubText      = Color3.fromRGB(145, 145, 158),
    Stroke       = Color3.fromRGB(48, 48, 56),
    Good         = Color3.fromRGB(90, 210, 140),
    Bad          = Color3.fromRGB(230, 90, 100),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

--// Helpers
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function tween(obj, props, time, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        Parent = parent,
    })
end

local function pad(parent, x, y)
    y = y or x
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, x),
        PaddingRight = UDim.new(0, x),
        PaddingTop = UDim.new(0, y),
        PaddingBottom = UDim.new(0, y),
        Parent = parent,
    })
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--// Library
local Library = {}
Library.__index = Library
Library.OpenFrames = {}

function Library:CreateWindow(title, opts)
    opts = opts or {}
    local ScreenGui = new("ScreenGui", {
        Name = "ModernUI_" .. tostring(math.random(1, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })

    local WINDOW_W, WINDOW_H = 560, 380

    -- Ambient glow: several stacked, oversized, semi-transparent accent-colored
    -- frames behind the window. Cheap and asset-free, and it breathes (pulses)
    -- via a looping tween so the whole window feels "alive".
    local GlowHolder = new("Frame", {
        Name = "GlowHolder",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = ScreenGui,
    })

    local GlowLayers = {}
    for i = 1, 4 do
        local grow = i * 10
        local layer = new("Frame", {
            Size = UDim2.new(1, grow * 2, 1, grow * 2),
            Position = UDim2.new(0, -grow, 0, -grow),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1 - (0.05 / i),
            ZIndex = 0,
            Parent = GlowHolder,
        })
        corner(layer, 16 + grow)
        table.insert(GlowLayers, layer)
    end

    local Main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = false,
        ZIndex = 1,
        Parent = ScreenGui,
    })
    corner(Main, 12)
    local MainStroke = stroke(Main, Theme.Accent, 1.5, 0.4)

    -- breathing glow + stroke pulse loop
    task.spawn(function()
        while Main.Parent do
            tween(MainStroke, { Transparency = 0.75 }, 1.4, Enum.EasingStyle.Sine)
            for i, layer in ipairs(GlowLayers) do
                tween(layer, { BackgroundTransparency = 1 - (0.03 / i) }, 1.4, Enum.EasingStyle.Sine)
            end
            task.wait(1.4)
            if not Main.Parent then break end
            tween(MainStroke, { Transparency = 0.35 }, 1.4, Enum.EasingStyle.Sine)
            for i, layer in ipairs(GlowLayers) do
                tween(layer, { BackgroundTransparency = 1 - (0.07 / i) }, 1.4, Enum.EasingStyle.Sine)
            end
            task.wait(1.4)
        end
    end)

    -- open animation: scale + fade in from center
    Main.Size = UDim2.new(0, WINDOW_W, 0, 0)
    Main.Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, 0)
    GlowHolder.Visible = false
    tween(Main, {
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
    }, 0.35, Enum.EasingStyle.Back)
    task.delay(0.35, function() GlowHolder.Visible = true end)

    -- subtle drop shadow via ImageLabel
    new("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        Size = UDim2.new(1, 60, 1, 60),
        Position = UDim2.new(0, -30, 0, -30),
        ZIndex = 0,
        Parent = Main,
    })

    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.Panel,
        Parent = Main,
    })
    corner(TopBar, 12)
    -- mask bottom corners of topbar square
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    local Accent = new("Frame", {
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, 14, 0.5, -9),
        BackgroundColor3 = Theme.Accent,
        Parent = TopBar,
    })
    corner(Accent, 2)

    new("TextLabel", {
        Text = title or "Modern UI",
        Font = FONT_BOLD,
        TextSize = 15,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 26, 0, 0),
        Size = UDim2.new(1, -100, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local CloseBtn = new("TextButton", {
        Text = "✕",
        Font = FONT_BOLD,
        TextSize = 14,
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 36, 1, 0),
        Position = UDim2.new(1, -36, 0, 0),
        Parent = TopBar,
    })
    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, { TextColor3 = Theme.Bad }, 0.15) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, { TextColor3 = Theme.SubText }, 0.15) end)
    CloseBtn.MouseButton1Click:Connect(function()
        tween(Main, { Size = UDim2.new(0, 560, 0, 0) }, 0.2)
        task.wait(0.2)
        ScreenGui:Destroy()
    end)

    makeDraggable(TopBar, Main)
    Main:GetPropertyChangedSignal("Position"):Connect(function()
        GlowHolder.Position = Main.Position
    end)

    local TabHolder = new("Frame", {
        Name = "TabHolder",
        Size = UDim2.new(0, 140, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundColor3 = Theme.Panel,
        Parent = Main,
    })
    corner(TabHolder, 10)

    local TabList = new("UIListLayout", {
        Padding = UDim.new(0, 6),
        Parent = TabHolder,
    })
    pad(TabHolder, 8)

    local PageHolder = new("Frame", {
        Name = "PageHolder",
        Size = UDim2.new(1, -160, 1, -50),
        Position = UDim2.new(0, 152, 0, 50),
        BackgroundTransparency = 1,
        Parent = Main,
    })

    -- toggle UI visibility keybind
    local visible = true
    local toggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == toggleKey then
            visible = not visible
            GlowHolder.Visible = visible
            tween(Main, { Size = visible and UDim2.new(0, WINDOW_W, 0, WINDOW_H) or UDim2.new(0, WINDOW_W, 0, 0) }, 0.22)
        end
    end)

    local Window = setmetatable({
        ScreenGui = ScreenGui,
        Main = Main,
        TabHolder = TabHolder,
        PageHolder = PageHolder,
        Tabs = {},
    }, { __index = {} })

    function Window:CreateTab(name)
        local TabBtn = new("TextButton", {
            Text = name,
            Font = FONT,
            TextSize = 13,
            TextColor3 = Theme.SubText,
            BackgroundColor3 = Theme.Elevated,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            Parent = TabHolder,
        })
        corner(TabBtn, 8)

        local Page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = PageHolder,
        })
        local PageLayout = new("UIListLayout", {
            Padding = UDim.new(0, 10),
            Parent = Page,
        })

        local function selectTab()
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                tween(t.Btn, { BackgroundTransparency = 1, TextColor3 = Theme.SubText }, 0.15)
            end
            Page.Visible = true
            tween(TabBtn, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, 0.15)
        end

        TabBtn.MouseButton1Click:Connect(selectTab)

        local TabObj = { Btn = TabBtn, Page = Page }
        table.insert(Window.Tabs, TabObj)
        if #Window.Tabs == 1 then selectTab() end

        function TabObj:CreateSection(sectionName)
            local Section = new("Frame", {
                Size = UDim2.new(1, -6, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel,
                Parent = Page,
            })
            corner(Section, 10)
            stroke(Section, Theme.Stroke, 1)
            local Layout = new("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = Section,
            })
            pad(Section, 12)

            new("TextLabel", {
                Text = sectionName,
                Font = FONT_BOLD,
                TextSize = 13,
                TextColor3 = Theme.Text,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 0,
                Parent = Section,
            })

            local SectionObj = {}

            function SectionObj:AddLabel(text)
                new("TextLabel", {
                    Text = text,
                    Font = FONT,
                    TextSize = 12,
                    TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Section,
                })
            end

            function SectionObj:AddButton(text, callback)
                local Btn = new("TextButton", {
                    Text = text,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Elevated,
                    Size = UDim2.new(1, 0, 0, 32),
                    Parent = Section,
                })
                corner(Btn, 8)
                Btn.MouseEnter:Connect(function() tween(Btn, { BackgroundColor3 = Theme.AccentDim }, 0.15) end)
                Btn.MouseLeave:Connect(function() tween(Btn, { BackgroundColor3 = Theme.Elevated }, 0.15) end)
                Btn.MouseButton1Click:Connect(function()
                    if callback then callback() end
                end)
                return Btn
            end

            function SectionObj:AddToggle(text, default, callback)
                local state = default or false
                local Holder = new("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundColor3 = Theme.Elevated,
                    Size = UDim2.new(1, 0, 0, 32),
                    Parent = Section,
                })
                corner(Holder, 8)

                new("TextLabel", {
                    Text = text,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -60, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Holder,
                })

                local Switch = new("Frame", {
                    Size = UDim2.new(0, 36, 0, 18),
                    Position = UDim2.new(1, -46, 0.5, -9),
                    BackgroundColor3 = state and Theme.Accent or Theme.Stroke,
                    Parent = Holder,
                })
                corner(Switch, 9)

                local Knob = new("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                    BackgroundColor3 = Theme.Text,
                    Parent = Switch,
                })
                corner(Knob, 7)

                local function set(newState, fire)
                    state = newState
                    tween(Switch, { BackgroundColor3 = state and Theme.Accent or Theme.Stroke }, 0.18)
                    tween(Knob, { Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }, 0.18)
                    if fire ~= false and callback then callback(state) end
                end

                Holder.MouseButton1Click:Connect(function() set(not state) end)
                if default then set(default, false) end

                return { Set = set, Get = function() return state end }
            end

            function SectionObj:AddSlider(text, min, max, default, callback)
                min, max = min or 0, max or 100
                local value = default or min

                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 42),
                    BackgroundTransparency = 1,
                    Parent = Section,
                })

                new("TextLabel", {
                    Text = text,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -50, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Holder,
                })

                local ValueLabel = new("TextLabel", {
                    Text = tostring(value),
                    Font = FONT,
                    TextSize = 12,
                    TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -50, 0, 0),
                    Size = UDim2.new(0, 50, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Holder,
                })

                local Track = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 24),
                    Size = UDim2.new(1, 0, 0, 8),
                    BackgroundColor3 = Theme.Elevated,
                    Parent = Holder,
                })
                corner(Track, 4)

                local Fill = new("Frame", {
                    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = Theme.Accent,
                    Parent = Track,
                })
                corner(Fill, 4)

                local dragging = false
                local function updateFromInput(input)
                    local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                    value = math.floor(min + (max - min) * rel)
                    ValueLabel.Text = tostring(value)
                    tween(Fill, { Size = UDim2.new(rel, 0, 1, 0) }, 0.08)
                    if callback then callback(value) end
                end

                Track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        updateFromInput(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromInput(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)

                return { Set = function(v) value = v; callback(v) end, Get = function() return value end }
            end

            function SectionObj:AddDropdown(text, options, default, callback)
                options = options or {}
                local selected = default or options[1]
                local open = false

                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundColor3 = Theme.Elevated,
                    ClipsDescendants = true,
                    Parent = Section,
                })
                corner(Holder, 8)

                new("TextLabel", {
                    Text = text,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(0.5, 0, 0, 32),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Holder,
                })

                local SelectedLabel = new("TextLabel", {
                    Text = tostring(selected),
                    Font = FONT,
                    TextSize = 12,
                    TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Size = UDim2.new(0.5, -30, 0, 32),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Holder,
                })

                local ClickArea = new("TextButton", {
                    Text = "",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    Parent = Holder,
                })

                local OptionList = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 34),
                    Size = UDim2.new(1, 0, 0, #options * 26),
                    BackgroundTransparency = 1,
                    Parent = Holder,
                })
                new("UIListLayout", { Padding = UDim.new(0, 2), Parent = OptionList })

                for _, opt in ipairs(options) do
                    local OptBtn = new("TextButton", {
                        Text = tostring(opt),
                        Font = FONT,
                        TextSize = 12,
                        TextColor3 = Theme.SubText,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 24),
                        Parent = OptionList,
                    })
                    OptBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        SelectedLabel.Text = tostring(opt)
                        if callback then callback(opt) end
                        open = false
                        tween(Holder, { Size = UDim2.new(1, 0, 0, 32) }, 0.18)
                    end)
                end

                ClickArea.MouseButton1Click:Connect(function()
                    open = not open
                    tween(Holder, { Size = open and UDim2.new(1, 0, 0, 34 + #options * 26) or UDim2.new(1, 0, 0, 32) }, 0.18)
                end)

                return { Get = function() return selected end }
            end

            function SectionObj:AddInput(text, placeholder, callback)
                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundColor3 = Theme.Elevated,
                    Parent = Section,
                })
                corner(Holder, 8)

                new("TextLabel", {
                    Text = text,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(0.4, 0, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Holder,
                })

                local Box = new("TextBox", {
                    PlaceholderText = placeholder or "",
                    Text = "",
                    Font = FONT,
                    TextSize = 12,
                    TextColor3 = Theme.Text,
                    PlaceholderColor3 = Theme.SubText,
                    ClearTextOnFocus = false,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.4, 0, 0, 0),
                    Size = UDim2.new(0.6, -10, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Holder,
                })

                Box.FocusLost:Connect(function(enterPressed)
                    if callback then callback(Box.Text, enterPressed) end
                end)

                return { Get = function() return Box.Text end }
            end

            function SectionObj:AddKeybind(text, default, callback)
                local key = default or Enum.KeyCode.Unknown
                local listening = false

                local Holder = new("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundColor3 = Theme.Elevated,
                    Size = UDim2.new(1, 0, 0, 32),
                    Parent = Section,
                })
                corner(Holder, 8)

                new("TextLabel", {
                    Text = text,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -90, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Holder,
                })

                local KeyLabel = new("TextLabel", {
                    Text = key.Name,
                    Font = FONT,
                    TextSize = 12,
                    TextColor3 = Theme.Accent,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -80, 0, 0),
                    Size = UDim2.new(0, 70, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Holder,
                })

                Holder.MouseButton1Click:Connect(function()
                    listening = true
                    KeyLabel.Text = "..."
                end)

                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        KeyLabel.Text = key.Name
                        listening = false
                    elseif not gpe and input.KeyCode == key and callback then
                        callback(key)
                    end
                end)

                return { Get = function() return key end }
            end

            return SectionObj
        end

        return TabObj
    end

    function Window:Notify(text, duration)
        duration = duration or 3
        local Notif = new("Frame", {
            Size = UDim2.new(0, 260, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.new(1, -280, 1, -20),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = Theme.Panel,
            Parent = ScreenGui,
        })
        corner(Notif, 10)
        stroke(Notif, Theme.Stroke, 1)
        pad(Notif, 12)

        new("TextLabel", {
            Text = text,
            Font = FONT,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextWrapped = true,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = Notif,
        })

        Notif.BackgroundTransparency = 1
        Notif.Position = UDim2.new(1, 20, 1, -20)
        tween(Notif, { Position = UDim2.new(1, -280, 1, -20), BackgroundTransparency = 0 }, 0.25)

        task.delay(duration, function()
            tween(Notif, { Position = UDim2.new(1, 20, 1, -20), BackgroundTransparency = 1 }, 0.25)
            task.wait(0.25)
            Notif:Destroy()
        end)
    end

    return Window
end

return Library

--[[
    EXAMPLE:

    local Library = loadstring(readfile("ModernUILibrary.lua"))()
    local Window = Library:CreateWindow("Modern UI Demo")

    local MainTab = Window:CreateTab("Main")
    local Combat = MainTab:CreateSection("Combat")
    Combat:AddToggle("Enabled", false, function(v) print("toggle:", v) end)
    Combat:AddSlider("Speed", 0, 100, 50, function(v) print("speed:", v) end)
    Combat:AddDropdown("Mode", {"Easy","Medium","Hard"}, "Easy", function(v) print("mode:", v) end)
    Combat:AddButton("Do Thing", function() Window:Notify("Button pressed!") end)

    local Settings = MainTab:CreateSection("Settings")
    Settings:AddKeybind("Toggle UI", Enum.KeyCode.RightControl, function() end)
    Settings:AddInput("Username", "Enter name...", function(text) print(text) end)
]]
